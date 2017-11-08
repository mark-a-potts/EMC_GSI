subroutine read_nc4tovs(mype,val_tovs,ithin,isfcalc,&
     rmesh,jsatid,gstime,infile,lunout,obstype,&
     nread,ndata,nodata,twind,sis, &
     mype_root,mype_sub,npe_sub,mpi_comm_sub, nobs, &
     nrec_start,nrec_start_ears,nrec_start_db,dval_use,radmod)
!$$$  subprogram documentation block
!                .      .    .                                       .
! C. Draper: temporary reader for nc4 input files, based directly on
! read_bufrtovs routine. NOT OPTIMAL! Nov 8. 2017. 
! To use nc4 files, append "_nc4" to dfile in OBS_INPUT namelist
! (eg amsua_n19_nc4). Also need to update run script to link 
! the nc4 file to the updated dfile.
!
!
!
! subprogram:    read_nc4tovs                  read bufr tovs 1b data
! 
!   prgmmr: treadon          org: np23                date: 2003-09-13
!
! abstract:  This routine reads BUFR format TOVS 1b radiance 
!            (brightness temperature) files.  Optionally, the data 
!            are thinned to a specified resolution using simple 
!            quality control checks.
!
!            When running the gsi in regional mode, the code only
!            retains those observations that fall within the regional
!            domain
!
!
!   input argument list:
!     mype     - mpi task id
!     val_tovs - weighting factor applied to super obs
!     ithin    - flag to thin data
!     isfcalc  - method to calculate surface fields within FOV
!                when one, calculate accounting for size/shape of FOV.
!                otherwise, use bilinear interpolation.
!     rmesh    - thinning mesh size (km)
!     jsatid   - satellite to read
!     gstime   - analysis time in minutes from reference date
!     infile   - unit from which to read BUFR data
!     lunout   - unit to which to write data for further processing
!     obstype  - observation type to process
!     twind    - input group time window(hours)
!     sis      - sensor/instrument/satellite indicator
!     mype_root - "root" task for sub-communicator
!     mype_sub - mpi task id within sub-communicator
!     npe_sub  - number of data read tasks
!     mpi_comm_sub - sub-communicator for data read
!     dval_use - logical for using dval
!     nrec_start - first subset with useful information
!     nrec_start_ears - first ears subset with useful information
!     nrec_start_db - first db subset with useful information
!
!   output argument list:
!     nread    - number of BUFR TOVS 1b observations read
!     ndata    - number of BUFR TOVS 1b profiles retained for further processing
!     nodata   - number of BUFR TOVS 1b observations retained for further processing
!     nobs     - array of observations on each subdomain for each processor
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use kinds, only: r_kind,r_double,i_kind
  use satthin, only: super_val,itxmax,makegrids,destroygrids,checkob, &
      finalcheck,map2tgrid,score_crit
  use radinfo, only: iuse_rad,newchn,cbias,predx,nusis,jpch_rad,air_rad,ang_rad, &
      use_edges,radedge1, radedge2, radstart,radstep,newpc4pred
  use radinfo, only: crtm_coeffs_path,adp_anglebc
  use gridmod, only: diagnostic_reg,regional,nlat,nlon,tll2xy,txy2ll,rlats,rlons
  use constants, only: deg2rad,zero,one,two,three,five,rad2deg,r60inv,r1000,h300,r100
  use crtm_module, only: success, &
      crtm_kind => fp, &
      MAX_SENSOR_ZENITH_ANGLE
  use crtm_spccoeff, only: sc,crtm_spccoeff_load,crtm_spccoeff_destroy
  use calc_fov_crosstrk, only : instrument_init, fov_cleanup, fov_check
  use gsi_4dvar, only: l4dvar,l4densvar,iwinbgn,winlen,thin4d
  use antcorr_application, only: remove_antcorr
  use mpeu_util, only: getindex, die, perr
  use deter_sfc_mod, only: deter_sfc_fov,deter_sfc
  use gsi_nstcouplermod, only: nst_gsi,nstinfo
  use gsi_nstcouplermod, only: gsi_nstcoupler_skindepth, gsi_nstcoupler_deter
  use mpimod, only: npe
  use radiance_mod, only: rad_obs_type
  use netcdf, only : nf90_strerror, nf90_noerr, nf90_nowrite
  use netcdf, only : nf90_open, nf90_close, nf90_inq_varid, nf90_inquire_variable
  use netcdf, only : nf90_inq_dimid, nf90_inquire_dimension, nf90_get_var
  use netcdf_mod, only: nc_check
  implicit none

! Declare passed variables
  character(len=*),intent(in   ) :: infile,obstype,jsatid
  character(len=20),intent(in  ) :: sis
  integer(i_kind) ,intent(in   ) :: mype,lunout,ithin
  integer(i_kind) ,intent(in   ) :: nrec_start,nrec_start_ears,nrec_start_db
  integer(i_kind) ,intent(inout) :: isfcalc
  integer(i_kind) ,intent(inout) :: nread
  integer(i_kind),dimension(npe) ,intent(inout) :: nobs
  integer(i_kind) ,intent(  out) :: ndata,nodata
  real(r_kind)    ,intent(in   ) :: rmesh,gstime,twind
  real(r_kind)    ,intent(inout) :: val_tovs
  integer(i_kind) ,intent(in   ) :: mype_root
  integer(i_kind) ,intent(in   ) :: mype_sub
  integer(i_kind) ,intent(in   ) :: npe_sub
  integer(i_kind) ,intent(in   ) :: mpi_comm_sub
  logical,         intent(in   ) :: dval_use
  type(rad_obs_type),intent(in ) :: radmod

! Declare local parameters

  character(8),parameter:: fov_flag="crosstrk"
  integer(i_kind),parameter:: n1bhdr=13
  integer(i_kind),parameter:: n2bhdr=4
  real(r_kind),parameter:: r360=360.0_r_kind
  real(r_kind),parameter:: tbmin=50.0_r_kind
  real(r_kind),parameter:: tbmax=550.0_r_kind

  integer(i_kind), parameter :: nhdr_nc4=10
  integer(i_kind), parameter :: nhdr_nc4_int=6

! Declare local variables
  logical hirs,msu,amsua,amsub,mhs,hirs4,hirs3,hirs2,ssu
  logical outside,iuse,assim,valid

  character(len=40):: infile2
  character(len=8) :: subset
  !character(len=80):: hdr1b,hdr2b
  character(len=10),dimension(nhdr_nc4) :: hdrXnc4 
  character(len=10),dimension(nhdr_nc4_int) :: hdrXnc4_int

  integer(i_kind) ireadsb,ireadmg,irec,next,nrec_startx
  integer(i_kind) i,j,k,ifov,ntest,llll
  integer(i_kind) iret,idate,nchanl,n,idomsfc(1)
  integer(i_kind) ich1,ich2,ich8,ich15,ich16,ich17
  integer(i_kind) kidsat,instrument,maxinfo
  integer(i_kind) nmind,itx,nreal,nele,itt,ninstruments
  integer(i_kind) iskip,ichan2,ichan1,ichan15
  integer(i_kind) lnbufr,ksatid,ichan8,isflg,ichan3,ich3,ich4,ich6
  integer(i_kind) ilat,ilon,ifovmod
  integer(i_kind),dimension(5):: idate5
  integer(i_kind) instr,ichan
  integer(i_kind) error_status,irecx,ierr
  integer(i_kind) radedge_min, radedge_max
  integer(i_kind),allocatable,dimension(:)::nrec
  character(len=20),dimension(1):: sensorlist

  real(r_kind) cosza,sfcr
  real(r_kind) ch1,ch2,ch3,ch8,d0,d1,d2,ch15,qval
  real(r_kind) ch1flg
  real(r_kind) expansion
  real(r_kind),dimension(0:3):: sfcpct
  real(r_kind),dimension(0:3):: ts
  real(r_kind) :: tsavg,vty,vfr,sty,stp,sm,sn,zz,ff10
  real(r_kind) :: zob,tref,dtw,dtc,tz_tr

  real(r_kind) pred, pred_water, pred_not_water
  real(r_kind) rsat,dlat,panglr,dlon,rato,sstime,tdiff,t4dv
  real(r_kind) dlon_earth_deg,dlat_earth_deg,sat_aziang
  real(r_kind) dlon_earth,dlat_earth,r01
  real(r_kind) crit1,step,start,ch8flg,dist1
  real(r_kind) terrain,timedif,lza,df2,tt,lzaest
  real(r_kind),dimension(0:4):: rlndsea
  real(r_kind),allocatable,dimension(:,:):: data_all

  real(crtm_kind),allocatable,dimension(:):: data1b4
  real(r_double),allocatable,dimension(:):: data1b8,data1b8x
  !real(r_double),dimension(n1bhdr):: bfr1bhdr
  !real(r_double),dimension(n2bhdr):: bfr2bhdr

  real(r_double), allocatable, dimension(:,:) :: nc4_bfrXbhdr
  real(i_kind), allocatable, dimension(:,:) :: nc4_bfrXbhdr_int
  real(r_double), allocatable, dimension(:,:) :: nc4_data1b8 

  real(r_kind) disterr,disterrmax,cdist,dlon00,dlat00

  logical :: critical_channels_missing

  integer :: ncid, varid, dimid, f_rec, stat 
  !integer*8, allocatable, dimension(:) :: nc4_idate
  integer :: f_start, f_count, f_stride, n_count, n_start, len
  integer, parameter :: n_count_max=1000 ! not sure what this should be

  integer, dimension(2) :: dimids
  integer :: nind 
 
  character(14) :: cdate
  character(12) :: Iam='read_nc4tovs'
  character(20) :: obstype_tmp

!**************************************************************************
! Initialize variables

  write(6,*)'READ_NC4TOVS: entered '//trim(infile)//' on ', mype_root,' ', mype_sub

  nind=1 ! additional indexes, for saving obs in the input file
  maxinfo=31 + nind
  lnbufr = 15
  disterrmax=zero
  ntest=0
  ndata  = 0
  nodata  = 0
  nread  = 0

  ilon=3
  ilat=4

  if(nst_gsi>0) then
     call gsi_nstcoupler_skindepth(obstype, zob)         ! get penetration depth (zob) for the obstype
  endif

! Make thinning grids
  call makegrids(rmesh,ithin)

! Set various variables depending on type of data to be read

  hirs2 =    obstype == 'hirs2'
  hirs3 =    obstype == 'hirs3'
  hirs4 =    obstype == 'hirs4'
  hirs  =    hirs2 .or. hirs3 .or. hirs4
  msu   =    obstype == 'msu'
  amsua =    obstype == 'amsua'
  amsub =    obstype == 'amsub'
  mhs   =    obstype == 'mhs'
  ssu   =    obstype == 'ssu'

!  instrument specific variables
  d1 =  0.754_r_kind
  d2 = -2.265_r_kind 
  r01 = 0.01_r_kind
  ich1   = 1   !1
  ich2   = 2   !2
  ich3   = 3   !3
  ich4   = 4   !4
  ich6   = 6   !6
  ich8   = 8   !8
  ich15  = 15  !15
  ich16  = 16  !16
  ich17  = 17  !17
! Set array index for surface-sensing channels
  ichan1  = newchn(sis,ich1)
  ichan2  = newchn(sis,ich2)
  ichan3  = newchn(sis,ich3)
  if (hirs) then
     ichan8  = newchn(sis,ich8)
  endif
  if (amsua) ichan15 = newchn(sis,ich15)

  if(jsatid == 'n05')kidsat=705
  if(jsatid == 'n06')kidsat=706
  if(jsatid == 'n07')kidsat=707
  if(jsatid == 'tirosn')kidsat=708
  if(jsatid == 'n08')kidsat=200
  if(jsatid == 'n09')kidsat=201
  if(jsatid == 'n10')kidsat=202
  if(jsatid == 'n11')kidsat=203
  if(jsatid == 'n12')kidsat=204

  if(jsatid == 'n14')kidsat=205
  if(jsatid == 'n15')kidsat=206
  if(jsatid == 'n16')kidsat=207
  if(jsatid == 'n17')kidsat=208
  if(jsatid == 'n18')kidsat=209
  if(jsatid == 'n19')kidsat=223
  if(jsatid == 'metop-a')kidsat=4
  if(jsatid == 'metop-b')kidsat=3
  if(jsatid == 'metop-c')kidsat=5
  if(jsatid == 'npp')kidsat=224

  radedge_min = 0
  radedge_max = 1000
  do i=1,jpch_rad
     if (trim(nusis(i))==trim(sis)) then
        step  = radstep(i)
        start = radstart(i)
        if (radedge1(i)/=-1 .and. radedge2(i)/=-1) then
           radedge_min=radedge1(i)
           radedge_max=radedge2(i)
        end if
        exit 
     endif
  end do 

  rato=1.1363987_r_kind
  if ( hirs ) then
     nchanl=19
!   Set rlndsea for types we would prefer selecting
     rlndsea(0) = zero
     rlndsea(1) = 15._r_kind
     rlndsea(2) = 10._r_kind
     rlndsea(3) = 15._r_kind
     rlndsea(4) = 30._r_kind
     if (isfcalc == 1) then
        expansion=one  ! use one for ir sensors
        ichan=-999  ! not used for hirs
        if (hirs2) then
           if(kidsat==203.or.kidsat==205)then
              instr=5 ! hirs-2i on noaa 11 and 14
           elseif(kidsat==708.or.kidsat==706.or.kidsat==707.or. &
                  kidsat==200.or.kidsat==201.or.kidsat==202.or. &
                  kidsat==204)then
              instr=4 ! hirs-2 on tiros-n,noaa6-10,noaa12
           else  ! sensor/sat mismatch
              write(6,*) 'READ_NC4TOVS:  *** WARNING: HIRS2 SENSOR/SAT MISMATCH'
              instr=5 ! set to something to prevent abort
           endif
        elseif (hirs4) then
           instr=8
        elseif (hirs3) then
           if(kidsat==206) then
              instr=6   ! noaa 15
           elseif(kidsat==207.or.kidsat==208)then
              instr=7   ! noaa 16/17
           else
              write(6,*) 'READ_NC4TOVS:  *** WARNING: HIRS3 SENSOR/SAT MISMATCH'
              instr=7
           endif
        endif
     endif  ! isfcalc == 1
  else if ( msu ) then
     nchanl=4
     if (isfcalc==1) then
        instr=10
        ichan=-999
        expansion=2.9_r_kind
     endif
!   Set rlndsea for types we would prefer selecting
     rlndsea(0) = zero
     rlndsea(1) = 20._r_kind
     rlndsea(2) = 15._r_kind
     rlndsea(3) = 20._r_kind
     rlndsea(4) = 100._r_kind
  else if ( amsua ) then
     nchanl=15
     if (isfcalc==1) then
        instr=11
        ichan=15  ! pick a surface sens. channel
        expansion=2.9_r_kind ! use almost three for microwave sensors.
     endif
!   Set rlndsea for types we would prefer selecting
     rlndsea(0) = zero
     rlndsea(1) = 15._r_kind
     rlndsea(2) = 10._r_kind
     rlndsea(3) = 15._r_kind
     rlndsea(4) = 100._r_kind
  else if ( amsub )  then
     nchanl=5
     if (isfcalc==1) then
        instr=12
        ichan=-999
        expansion=2.9_r_kind
     endif
!   Set rlndsea for types we would prefer selecting
     rlndsea(0) = zero
     rlndsea(1) = 15._r_kind
     rlndsea(2) = 20._r_kind
     rlndsea(3) = 15._r_kind
     rlndsea(4) = 100._r_kind
  else if ( mhs )  then
     nchanl=5
     if (isfcalc==1) then
        instr=13
        ichan=1  ! all channels give similar result.
        expansion=2.9_r_kind
     endif
!   Set rlndsea for types we would prefer selecting
     rlndsea(0) = zero
     rlndsea(1) = 15._r_kind
     rlndsea(2) = 20._r_kind
     rlndsea(3) = 15._r_kind
     rlndsea(4) = 100._r_kind
  else if ( ssu ) then
     nchanl=3
     if (isfcalc==1) then
        instr=9
        ichan=-999  ! not used for this sensor
        expansion=one
     endif
!   Set rlndsea for types we would prefer selecting
     rlndsea(0) = zero
     rlndsea(1) = 15._r_kind
     rlndsea(2) = 10._r_kind
     rlndsea(3) = 15._r_kind
     rlndsea(4) = 30._r_kind
  end if

! If all channels of a given sensor are set to monitor or not
! assimilate mode (iuse_rad<1), reset relative weight to zero.
! We do not want such observations affecting the relative
! weighting between observations within a given thinning group.

  assim=.false.
  search: do i=1,jpch_rad
     if ((nusis(i)==sis) .and. (iuse_rad(i)>0)) then
        assim=.true.
        exit search
     endif
  end do search
  if (.not.assim) val_tovs=zero

! Initialize variables for use by FOV-based surface code.
  if (isfcalc == 1) then
     call instrument_init(instr,jsatid,expansion,valid)
     if (.not. valid) then
       if (assim) then
         write(6,*)'READ_NC4TOVS:  ***ERROR*** IN SETUP OF FOV-SFC CODE. STOP'
         call stop2(71)
       else
         call fov_cleanup
         isfcalc = 0
         write(6,*)'READ_NC4TOVS:  ***ERROR*** IN SETUP OF FOV-SFC CODE'
       endif
     endif
  endif

  if (isfcalc==1) then
    if (amsub.or.mhs)then
      rlndsea(4) = max(rlndsea(0),rlndsea(1),rlndsea(2),rlndsea(3))
    else
      rlndsea=0
    endif
  endif

! Allocate arrays to hold all data for given satellite
  
  if(dval_use) maxinfo=maxinfo+2
  nreal = maxinfo + nstinfo 
  nele  = nreal   + nchanl 
  !hdr1b ='SAID FOVN YEAR MNTH DAYS HOUR MINU SECO CLAT CLON CLATH CLONH HOLS'
  !hdr2b ='SAZA SOZA BEARAZ SOLAZI'

  hdrXnc4 = (/'FOVN', 'CLAT', 'CLON', 'CLATH', 'CLONH', 'HOLS', 'SAZA', 'SOZA', 'BEARAZ', 'SOLAZI'/)
  hdrXnc4_int = (/'YEAR','MNTH','DAYS','HOUR','MINU','SECO'/)

  allocate(data_all(nele,itxmax),data1b8(nchanl),data1b4(nchanl),nrec(itxmax))

!  next=0
  irec=0
! Big loop over standard data feed and possible ears/db data
! llll=1 is normal feed, llll=2 EARS/RARS data, llll=3 DB/UW data)

  ears_db_loop: do llll= 1, 3

     if(llll == 1)then
        nrec_startx=nrec_start
        infile2=trim(infile)         ! Set bufr subset names based on type of data to read
     elseif(llll == 2) then
        nrec_startx=nrec_start_ears
        infile2=trim(infile)//'ears' ! Set bufr subset names based on type of data to read
        if(amsua .and. kidsat >= 200 .and. kidsat <= 207) cycle ears_db_loop
     elseif(llll == 3) then
        nrec_startx=nrec_start_db
        infile2=trim(infile)//'_db'  ! Set bufr subset names based on type of data to read
        if(amsua .and. kidsat >= 200 .and. kidsat <= 207) cycle ears_db_loop
     end if

!     call closbf(lnbufr)
!     open(lnbufr,file=trim(infile2),form='unformatted',status = 'old',iostat=ierr)
!     if(ierr /= 0) cycle ears_db_loop

!     call openbf(lnbufr,'IN',lnbufr)

     ierr = nf90_open(trim(infile2), NF90_NOWRITE, ncid)
     if(ierr /= nf90_noerr) cycle ears_db_loop

     if(llll >= 2 .and. (amsua .or. amsub .or. mhs))then
        allocate(data1b8x(nchanl))
        sensorlist(1)=sis
        if( crtm_coeffs_path /= "" ) then
           if(mype_sub==mype_root) write(6,*)'READ_NC4TOVS: crtm_spccoeff_load() on path "'//trim(crtm_coeffs_path)//'"'
           error_status = crtm_spccoeff_load(sensorlist,&
              File_Path = crtm_coeffs_path )
           else
              error_status = crtm_spccoeff_load(sensorlist)
           endif
           if (error_status /= success) then
              write(6,*)'READ_NC4TOVS:  ***ERROR*** crtm_spccoeff_load error_status=',error_status,&
                 '   TERMINATE PROGRAM EXECUTION'
           call stop2(71)
        endif
        ninstruments = size(sc)
        instrument_loop: do n=1,ninstruments
           if(sis == sc(n)%sensor_id)then
              instrument=n
              exit instrument_loop
           end if
        end do instrument_loop
        if(instrument == 0)then
           write(6,*)' failure to find instrument in read_bufrtovs ',sis
        end if
     end if

!    Read from nc4 file  (opened above)

!     get indexes for parallel read 
!    f_rec: # of records in the bufr file (one record includes all chanels)
 
      call nc_check(nf90_inq_dimid(ncid,'nobs_bufr', dimid), Iam,'nf90_inq_dimid')
      call nc_check(nf90_inquire_dimension(ncid, dimid,len=f_rec), Iam,'nf90_inquire_dimension')

      ! f_start, f_stride, and f_count are file indexes to be read in by this task
      f_start = nrec_startx+npe_sub-1-mype_sub
      f_stride = npe_sub 
      f_count = (f_rec - f_start)/f_stride + 1 ! integer divide rounds down

      allocate(nc4_bfrXbhdr(nhdr_nc4,min(f_count, n_count_max)))
      allocate(nc4_bfrXbhdr_int(nhdr_nc4_int,min(f_count, n_count_max)))
      allocate(nc4_data1b8(nchanl,min(f_count,n_count_max)))

      ! n_start, n_count are read indexes for this loop
      n_start=f_start  
      nreadmax_loop: do while (n_start<f_rec+1) 
      n_count=min(n_count_max, (f_rec-n_start)/f_stride+1) 

      ! holds: FOVN, CLAT, CLON, CLATH, CLONTH, HOLS, SAZA, SOZA, BEARAZ, SOLAZI 
      !        1     2     3     4      5       6     7     8     9       10    
      !        bfr1bhdr                             , bfr2bhdr
      ! 

      ! read in header info 
      do  n=1,nhdr_nc4

             stat = nf90_inq_varid(ncid, trim(hdrXnc4(n)) , varid)
             if(stat /= nf90_noerr) then 
                if ( (n>=2) .AND. (n<=5) ) then    ! CLATH/CLONH may not be present
                    nc4_bfrXbhdr(n,1:n_count) = -9999.9
                else 
                    call perr('nf90_inq_varid',trim(Iam),trim(nf90_strerror(stat)))
                    call die('nf90_inq_varid')
                end if 
             else 
                call nc_check(nf90_get_var(ncid, varid,nc4_bfrXbhdr(n,1:n_count), &
                  start=(/n_start/), count = (/n_count/), stride=(/f_stride/) ), &
                         Iam, 'nf90_get_var')
             end if  
      end do

      ! read in date info (integers)
      do  n=1,nhdr_nc4_int
             call nc_check(nf90_inq_varid(ncid, trim(hdrXnc4_int(n)) , varid),Iam,'nf90_inq_varid')
             call nc_check(nf90_get_var(ncid, varid,nc4_bfrXbhdr_int(n,1:n_count), &
                  start=(/n_start/), count = (/n_count/), stride=(/f_stride/) ), &
                         Iam, 'nf90_get_var')
      end do

      ! read in data 

     if (llll == 1) then
         call nc_check(nf90_inq_varid(ncid, 'TMBR' , varid),Iam,'nf90_inq_varid')

         ! check dimension order for TMBR array
          call nc_check(nf90_inquire_variable(ncid, varid, dimids = dimids), Iam,'nf90_inquire_variable')
          call nc_check( nf90_inquire_dimension(ncid, dimids(2),len=len), Iam,'nf90_inquire_dimension')
          if (len .NE. f_rec)call die('check nc4 TMBR dimension order')

          call nc_check(nf90_get_var(ncid, varid,nc4_data1b8(:,1:n_count), &
              start=(/1,n_start/), count = (/nchanl,n_count/), stride=(/1,f_stride/) ), &
                     Iam, 'nf90_get_var')
     else     ! EARS / DB
         call nc_check(nf90_inq_varid(ncid, 'TMBRST' , varid),Iam,'nf90_inq_varid')
         call nc_check(nf90_get_var(ncid, varid,nc4_data1b8(:,1:n_count), &
              start=(/n_start,1/), count = (/n_count,nchanl/), stride=(/f_stride,1/) ), &
                     Iam, 'nf90_get_var')
     end if 

! TEMPORARY UNTIL FILE IS FIXED 
  
!      nc4_bfrXbhdr(4,:)=999.9 
!      nc4_bfrXbhdr(5,:)=999.9 

      ! Obs_Time

!      call nc_check(nf90_inq_varid(ncid, 'Obs_Time', varid),Iam,'nf90_inq_varid')
!      call nc_check(nf90_get_var(ncid, varid,nc4_idate(1:n_count), & 
!                    start=(/n_start/), count = (/n_count/), stride=(/f_stride/) ), & 
!                    Iam, 'nf90_get_var')

     read_loop: do  while(irec<n_count) 
!    Loop to read bufr file
!     irecx=0
!     read_subset: do while(ireadmg(lnbufr,subset,idate)>=0)
!        irecx=irecx+1
!        if(irecx < nrec_startx) cycle read_subset
        irec=irec+1
!        next=next+1
!        if(next == npe_sub)next=0
!        if(next/=mype_sub)cycle read_subset
 !       read_loop: do while (ireadsb(lnbufr)==0)

!          Read header record.  (llll=1 is normal feed, 2=EARS data, 3=DB data)
           !call ufbint(lnbufr,bfr1bhdr,n1bhdr,1,iret,hdr1b)

! nc4 files have only one sat. 
!          Extract satellite id.  If not the one we want, read next record
!           ksatid=nint(bfr1bhdr(1))
!           if(ksatid /= kidsat) cycle read_subset
!           rsat=bfr1bhdr(1) 
           rsat=kidsat

!          If msu, drop obs from first (1) and last (11) scan positions
!           ifov = nint(bfr1bhdr(2))
           ifov = nint(nc4_bfrXbhdr(1,irec) ) 
           if (use_edges) then 
              if (msu .and. (ifov==1 .or. ifov==11)) cycle read_loop
           else if ((ifov < radedge_min .OR. ifov > radedge_max )) then
              cycle read_loop
           end if

           ! Check that ifov is not out of range of cbias dimension
           if (ifov < 1 .OR. ifov > 90) cycle read_loop

! CSD-TODO: set FillValue Attribute for CLAT, CLATH, etc 
! the read it in
! is currently -9999., but attribute not set 
!          Extract observation location and other required information
!           if(abs(bfr1bhdr(11)) <= 90._r_kind .and. abs(bfr1bhdr(12)) <= r360)then
            if(abs(nc4_bfrXbhdr(4,irec)) <= 90._r_kind .and. abs(nc4_bfrXbhdr(5,irec)) <= r360)then
              dlat_earth = nc4_bfrXbhdr(4,irec)
              dlon_earth = nc4_bfrXbhdr(5,irec)
!           elseif(abs(bfr1bhdr(9)) <= 90._r_kind .and. abs(bfr1bhdr(10)) <= r360)then
           elseif(abs(nc4_bfrXbhdr(2,irec)) <= 90._r_kind .and. abs(nc4_bfrXbhdr(3,irec)) <= r360)then
              dlat_earth = nc4_bfrXbhdr(2,irec)
              dlon_earth = nc4_bfrXbhdr(3,irec)
           else
              cycle read_loop
           end if
           if(dlon_earth<zero)  dlon_earth = dlon_earth+r360
           if(dlon_earth>=r360) dlon_earth = dlon_earth-r360
           dlat_earth_deg = dlat_earth
           dlon_earth_deg = dlon_earth
           dlat_earth = dlat_earth*deg2rad
           dlon_earth = dlon_earth*deg2rad

!          Regional case
           if(regional)then
              call tll2xy(dlon_earth,dlat_earth,dlon,dlat,outside)
              if(diagnostic_reg) then
                 call txy2ll(dlon,dlat,dlon00,dlat00)
                 ntest=ntest+1
                 cdist=sin(dlat_earth)*sin(dlat00)+cos(dlat_earth)*cos(dlat00)* &
                      (sin(dlon_earth)*sin(dlon00)+cos(dlon_earth)*cos(dlon00))
                 cdist=max(-one,min(cdist,one))
                 disterr=acos(cdist)*rad2deg
                 disterrmax=max(disterrmax,disterr)
              end if
              
!             Check to see if in domain
              if(outside) cycle read_loop

!          Global case
           else
              dlat=dlat_earth
              dlon=dlon_earth
              call grdcrd1(dlat,rlats,nlat,1)
              call grdcrd1(dlon,rlons,nlon,1)
           endif

!          Extract date information.  If time outside window, skip this obs
!           idate5(1) = bfr1bhdr(3) !year
!           idate5(2) = bfr1bhdr(4) !month
!           idate5(3) = bfr1bhdr(5) !day
!           idate5(4) = bfr1bhdr(6) !hour
!           idate5(5) = bfr1bhdr(7) !minute      

            idate5(1) = nc4_bfrXbhdr_int(1,irec) !year
            idate5(2) = nc4_bfrXbhdr_int(2,irec) !month
            idate5(3) = nc4_bfrXbhdr_int(3,irec) !day
            idate5(4) = nc4_bfrXbhdr_int(4,irec) !hour
            idate5(5) = nc4_bfrXbhdr_int(5,irec) !minute      

           call w3fs21(idate5,nmind)
!           t4dv= (real((nmind-iwinbgn),r_kind) + bfr1bhdr(8)*r60inv)*r60inv    ! add in seconds
!           sstime= real(nmind,r_kind) + bfr1bhdr(8)*r60inv    ! add in seconds

           t4dv= (real((nmind-iwinbgn),r_kind) + nc4_bfrXbhdr_int(6,irec)*r60inv)*r60inv    ! add in seconds
           sstime= real(nmind,r_kind) + nc4_bfrXbhdr_int(6,irec)*r60inv    ! add in seconds
           tdiff=(sstime-gstime)*r60inv
           if (l4dvar.or.l4densvar) then
              if (t4dv<zero .OR. t4dv>winlen) cycle read_loop
           else
              if(abs(tdiff) > twind) cycle read_loop
           endif

           nread=nread+nchanl

           if (thin4d) then
              timedif = zero
           else
              timedif = two*abs(tdiff)        ! range:  0 to 6
           endif

           terrain = 50._r_kind
!           if(llll == 1)terrain = 0.01_r_kind*abs(bfr1bhdr(13))                   
           if(llll == 1)terrain = 0.01_r_kind*abs(nc4_bfrXbhdr(6,irec))  
           crit1 = 0.01_r_kind + terrain + timedif
           if (llll >  1 ) crit1 = crit1 + r100 * float(llll)
           call map2tgrid(dlat_earth,dlon_earth,dist1,crit1,itx,ithin,itt,iuse,sis)
           if(.not. iuse)cycle read_loop

!           call ufbint(lnbufr,bfr2bhdr,n2bhdr,1,iret,hdr2b)

!          Set common predictor parameters
           ifovmod=ifov

!          Account for assymetry due to satellite build error
           if(hirs .and. ((jsatid == 'n16') .or. (jsatid == 'n17'))) &
              ifovmod=ifovmod+1

           panglr=(start+float(ifovmod-1)*step)*deg2rad
           lzaest = asin(rato*sin(panglr))
           if( msu .or. hirs2 .or. ssu)then
              lza = lzaest
           else
!              lza = bfr2bhdr(1)*deg2rad      ! local zenith angle
              lza = nc4_bfrXbhdr(7,irec)*deg2rad      ! local zenith angle
              if((amsua .and. ifovmod <= 15) .or.        &
                 (amsub .and. ifovmod <= 45) .or.        &
                 (mhs   .and. ifovmod <= 45) .or.        &
                 (hirs  .and. ifovmod <= 28) )   lza=-lza
           end if

!  Check for errors in satellite zenith angles 
           if(abs(lzaest-lza)*rad2deg > one) then
              write(6,*)' READ_NC4TOVS WARNING uncertainty in lza ', &
                 lza*rad2deg,lzaest*rad2deg,sis,ifovmod,start,step
              cycle read_loop
           end if

           if(abs(lza)*rad2deg > MAX_SENSOR_ZENITH_ANGLE) then
              write(6,*)'READ_NC4TOVS WARNING lza error ',nc4_bfrXbhdr(7,irec),panglr
              cycle read_loop
           end if

!           sat_aziang=bfr2bhdr(3)
           sat_aziang=nc4_bfrXbhdr(9,irec)
           if (abs(sat_aziang) > r360) then
              sat_aziang=zero
!_RT              write(6,*) 'READ_NC4TOVS: bad azimuth angle ',sat_aziang
!_RT              cycle read_loop
           endif

!          Read data record.  Increment data counter
!          TMBR is actually the antenna temperature for most microwave 
!          sounders.
           data1b8=nc4_data1b8(:,irec) ! contains TMBR or TMBRST, read above
           !if (llll == 1) then
!              call ufbrep(lnbufr,data1b8,1,nchanl,iret,'TMBR')
!           else     ! EARS / DB
!              call ufbrep(lnbufr,data1b8,1,nchanl,iret,'TMBRST')
!              if ( amsua .or. amsub .or. mhs )then
            if ( (llll >= 2)  .and. (amsua .or. amsub .or. mhs ) ) then 
                 data1b8x=data1b8
                 data1b4=data1b8
                 call remove_antcorr(sc(instrument)%ac,ifov,data1b4)
                 data1b8=data1b4
                 do j=1,nchanl
                    if(data1b8x(j) > r1000)data1b8(j) = 1000000._r_kind
                 end do
              end if
!           end if

!          Transfer observed brightness temperature to work array.  If any
!          temperature exceeds limits, reset observation to "bad" value
           iskip=0 
           critical_channels_missing = .false.
           do j=1,nchanl
              if (data1b8(j) < tbmin .or. data1b8(j) > tbmax) then
                 iskip = iskip + 1

!                Flag profiles where key channels are bad  
                 if(( msu  .and.  j == ich1) .or.                                 &
                    (amsua .and. (j == ich1 .or. j == ich2 .or. j == ich3 .or.    &
                                  j == ich4 .or. j == ich6 .or. j == ich15 )) .or.&
                    (hirs  .and. (j == ich8 )) .or.                               &
                    (amsub .and.  j == ich1) .or.                                 &
                    (mhs   .and. (j == ich1 .or. j == ich2)) ) critical_channels_missing = .true.
              endif
           end do
           if (iskip >= nchanl) cycle read_loop
!          Map obs to thinning grid
           crit1 = crit1 + 10._r_kind*float(iskip)
           call checkob(dist1,crit1,itx,iuse)
           if(.not. iuse)cycle read_loop

!          Determine surface properties based on 
!          sst and land/sea/ice mask   
!
!          isflg    - surface flag
!                     0 sea
!                     1 land
!                     2 sea ice
!                     3 snow
!                     4 mixed                       

!          FOV-based surface code requires fov number.  if out-of-range, then
!          skip this ob.

           if (isfcalc == 1) then
              call fov_check(ifov,instr,ichan,valid)
              if (.not. valid) cycle read_loop

!          When isfcalc is one, calculate surface fields based on size/shape of fov.
!          Otherwise, use bilinear method.

              call deter_sfc_fov(fov_flag,ifov,instr,ichan,sat_aziang,dlat_earth_deg,&
                 dlon_earth_deg,expansion,t4dv,isflg,idomsfc(1), &
                 sfcpct,vfr,sty,vty,stp,sm,ff10,sfcr,zz,sn,ts,tsavg)
           else
              call deter_sfc(dlat,dlon,dlat_earth,dlon_earth,t4dv,isflg, &
                 idomsfc(1),sfcpct,ts,tsavg,vty,vfr,sty,stp,sm,sn,zz,ff10,sfcr)
           endif


           crit1 = crit1 + rlndsea(isflg) 
           call checkob(dist1,crit1,itx,iuse)
           if(.not. iuse)cycle read_loop


           if (critical_channels_missing) then

             pred=1.0e8_r_kind

           else

!             Set data quality predictor
              if (msu) then
                 if (newpc4pred) then
                    ch1 = data1b8(ich1)-ang_rad(ichan1)*cbias(ifov,ichan1)- &
                         predx(1,ichan1)*air_rad(ichan1)
                 else
                    ch1 = data1b8(ich1)-ang_rad(ichan1)*cbias(ifov,ichan1)- &
                         r01*predx(1,ichan1)*air_rad(ichan1)
                 end if
                 ch1flg = tsavg-ch1
                 if(isflg == 0)then
                    pred = 100._r_kind-min(ch1flg,100.0_r_kind)
                 else
                    pred = abs(ch1flg)
                 end if
              else if (hirs) then
                 if (newpc4pred) then
                    ch8 = data1b8(ich8) -ang_rad(ichan8)*cbias(ifov,ichan8)- &
                         predx(1,ichan8)*air_rad(ichan8)
                 else
                    ch8 = data1b8(ich8) -ang_rad(ichan8)*cbias(ifov,ichan8)- &
                         r01*predx(1,ichan8)*air_rad(ichan8)
                 end if
                 ch8flg = tsavg-ch8
                 pred   = 10.0_r_kind*max(zero,ch8flg)
              else if (amsua) then
!                Remove angle dependent pattern (not mean)
                 if (adp_anglebc .and. newpc4pred) then
                    ch1 = data1b8(ich1)-ang_rad(ichan1)*cbias(ifov,ichan1) 
                    ch2 = data1b8(ich2)-ang_rad(ichan2)*cbias(ifov,ichan2) 
                    ch15= data1b8(ich15)-ang_rad(ichan15)*cbias(ifov,ichan15)
                 else
                    ch1 = data1b8(ich1)-ang_rad(ichan1)*cbias(ifov,ichan1)+ &
                         air_rad(ichan1)*cbias(15,ichan1)
                    ch2 = data1b8(ich2)-ang_rad(ichan2)*cbias(ifov,ichan2)+ &
                         air_rad(ichan2)*cbias(15,ichan2)   
                    ch15= data1b8(ich15)-ang_rad(ichan15)*cbias(ifov,ichan15)
                 end if
                 if (isflg == 0 .and. ch1<285.0_r_kind .and. ch2<285.0_r_kind) then
                    cosza = cos(lza)
                    d0    = 8.24_r_kind - 2.622_r_kind*cosza + 1.846_r_kind*cosza*cosza                                 
                    qval=cosza*(d0+d1*log(285.0_r_kind-ch1)+d2*log(285.0_r_kind-ch2))
                    if (radmod%lcloud_fwd) then
                       ! no preference in selecting clouds/precipitation
                       ! qval=zero 
                       ! favor non-precipitating clouds                                                   
                       qval=-113.2_r_kind+(2.41_r_kind-0.0049_r_kind*ch1)*ch1 +  &         
                            0.454_r_kind*ch2-ch15   
                       if (qval>=9.0_r_kind) then
                          qval=1000.0_r_kind*qval
                       else
                          qval=zero
                       end if
                       ! favor thinner clouds
                       ! cosza = cos(lza)
                       ! d0= 8.24_r_kind - 2.622_r_kind*cosza + 1.846_r_kind*cosza*cosza
                       ! qval=cosza*(d0+d1*log(285.0_r_kind-ch1)+d2*log(285.0_r_kind-ch2))
                       ! if (qval>0.2_r_kind) then
                       !    qval=1000.0_r_kind*qval
                       ! else
                       !    qval=zero
                       ! end if
                    end if
                    pred  = max(zero,qval)*100.0_r_kind
                 else
                    if (adp_anglebc .and. newpc4pred) then
                       ch3 = data1b8(ich3)-ang_rad(ichan3)*cbias(ifov,ichan3) 
                       ch15 = data1b8(ich15)-ang_rad(ichan15)*cbias(ifov,ichan15) 
                    else
                       ch3  = data1b8(ich3)-ang_rad(ichan3)*cbias(ifov,ichan3)+ &
                            air_rad(ichan3)*cbias(15,ichan3)   
                       ch15 = data1b8(ich15)-ang_rad(ichan15)*cbias(ifov,ichan15)+ &
                            air_rad(ichan15)*cbias(15,ichan15)
                    end if
                    pred = abs(ch1-ch15)
                    if(ch1-ch15 >= three) then
                       df2  = 5.10_r_kind +0.78_r_kind*ch1-0.96_r_kind*ch3
                       tt   = 168._r_kind-0.49_r_kind*ch15
                       if(ch1 > 261._r_kind .or. ch1 >= tt .or. & 
                            (ch15 <= 273._r_kind .and. df2 >= 0.6_r_kind))then
                          pred = 100._r_kind
                       end if
                    end if
                 endif
                 
!                 sval=-113.2_r_kind+(2.41_r_kind-0.0049_r_kind*ch1)*ch1 +  &
!                 0.454_r_kind*ch2-ch15
                 
              else if (amsub .or. mhs) then
                 if (newpc4pred) then
                    ch1 = data1b8(ich1)-ang_rad(ichan1)*cbias(ifov,ichan1)- &
                         predx(1,ichan1)*air_rad(ichan1)
                    ch2 = data1b8(ich2)-ang_rad(ichan2)*cbias(ifov,ichan2)- &
                         predx(1,ichan2)*air_rad(ichan2)
                 else
                    ch1 = data1b8(ich1)-ang_rad(ichan1)*cbias(ifov,ichan1)- &
                         r01*predx(1,ichan1)*air_rad(ichan1)
                    ch2 = data1b8(ich2)-ang_rad(ichan2)*cbias(ifov,ichan2)- &
                         r01*predx(1,ichan2)*air_rad(ichan2)
                 end if
                 pred_water = zero
                 if(sfcpct(0) > zero)then
                    cosza = cos(lza)
                    if(ch2 < h300)then 
                       pred_water = (0.13_r_kind*(ch1+33.58_r_kind*log(h300-ch2)- &
                            341.17_r_kind))*five
                    else
                       pred_water = 100._r_kind
                    end if
                 end if
                 pred_not_water = 42.72_r_kind + 0.85_r_kind*ch1-ch2
                 pred = (sfcpct(0)*pred_water) + ((one-sfcpct(0))*pred_not_water)
                 pred = max(zero,pred)
                 
              endif
              
           end if

!          Compute "score" for observation.  All scores>=0.0.  Lowest score is "best"
           crit1 = crit1+pred 
           call finalcheck(dist1,crit1,itx,iuse)
           if(.not. iuse)cycle read_loop

!          interpolate NSST variables to Obs. location and get dtw, dtc, tz_tr
           if(nst_gsi>0) then
              tref  = ts(0)
              dtw   = zero
              dtc   = zero
              tz_tr = one
              if(sfcpct(0)>zero) then
                 call gsi_nstcoupler_deter(dlat_earth,dlon_earth,t4dv,zob,tref,dtw,dtc,tz_tr)
              endif
           endif

!          Load selected observation into data array
              
           data_all(1 ,itx)= rsat                      ! satellite ID
           data_all(2 ,itx)= t4dv                      ! time
           data_all(3 ,itx)= dlon                      ! grid relative longitude
           data_all(4 ,itx)= dlat                      ! grid relative latitude
           data_all(5 ,itx)= lza                       ! local zenith angle
!           data_all(6 ,itx)= bfr2bhdr(3)               ! local azimuth angle
            data_all(6 ,itx)= nc4_bfrXbhdr(9,irec)     ! local azimuth angle
           data_all(7 ,itx)= panglr                    ! look angle
           data_all(8 ,itx)= ifov                      ! scan position
!           data_all(9 ,itx)= bfr2bhdr(2)               ! solar zenith angle
           data_all(9 ,itx)= nc4_bfrXbhdr(8,irec)      ! solar zenith angle
!           data_all(10,itx)= bfr2bhdr(4)               ! solar azimuth angle
           data_all(10,itx)= nc4_bfrXbhdr(10,irec)     ! solar azimuth angle
           data_all(11,itx) = sfcpct(0)                ! sea percentage of
           data_all(12,itx) = sfcpct(1)                ! land percentage
           data_all(13,itx) = sfcpct(2)                ! sea ice percentage
           data_all(14,itx) = sfcpct(3)                ! snow percentage
           data_all(15,itx)= ts(0)                     ! ocean skin temperature
           data_all(16,itx)= ts(1)                     ! land skin temperature
           data_all(17,itx)= ts(2)                     ! ice skin temperature
           data_all(18,itx)= ts(3)                     ! snow skin temperature
           data_all(19,itx)= tsavg                     ! average skin temperature
           data_all(20,itx)= vty                       ! vegetation type
           data_all(21,itx)= vfr                       ! vegetation fraction
           data_all(22,itx)= sty                       ! soil type
           data_all(23,itx)= stp                       ! soil temperature
           data_all(24,itx)= sm                        ! soil moisture
           data_all(25,itx)= sn                        ! snow depth
           data_all(26,itx)= zz                        ! surface height
           data_all(27,itx)= idomsfc(1) + 0.001_r_kind ! dominate surface type
           data_all(28,itx)= sfcr                      ! surface roughness
           data_all(29,itx)= ff10                      ! ten meter wind factor
           data_all(30,itx) = dlon_earth_deg           ! earth relative longitude (deg)
           data_all(31,itx) = dlat_earth_deg           ! earth relative latitude (deg)

           if (nind==1) then 
           data_all(32,itx) = n_start+(irec-1)*f_stride ! record number in nc4 file
           end if 

           if(dval_use) then
              !data_all(32,itx)= val_tovs
              !data_all(33,itx)= itt
              data_all(32+nind,itx)= val_tovs
              data_all(33+nind,itx)= itt
           end if

           if(nst_gsi>0) then
              data_all(maxinfo+1,itx) = tref            ! foundation temperature
              data_all(maxinfo+2,itx) = dtw             ! dt_warm at zob
              data_all(maxinfo+3,itx) = dtc             ! dt_cool at zob
              data_all(maxinfo+4,itx) = tz_tr           ! d(Tz)/d(Tr)
           endif

           ! if line is to replace no data in nc4 file with value 
           ! from BUFR (allows zero diff)
           do i=1,nchanl
              data_all(i+nreal,itx)=data1b8(i)
           end do
! for parallel read in read_bufrtovs, irec is index in file 
! here it is index in array read in from file: 
! (irec differs anyway, as the bufr file has additional obs)
!           nrec(itx)=irec
            nrec(itx)=n_start+(irec-1)*f_stride

!       End of bufr read loops
        enddo read_loop

        irec=0 
        n_start=n_start+f_stride*n_count
        
      enddo nreadmax_loop
!     enddo read_subset
!     call closbf(lnbufr)

       ! deallocate nc4 vars
      deallocate(nc4_bfrXbhdr)
      deallocate(nc4_bfrXbhdr_int)
      deallocate(nc4_data1b8) 

     if(llll > 1 .and. (amsua .or. amsub .or. mhs))then
        deallocate(data1b8x)

!       deallocate crtm info
        error_status = crtm_spccoeff_destroy()
        if (error_status /= success) &
           write(6,*)'OBSERVER:  ***ERROR*** crtm_spccoeff_destroy error_status=',error_status
     end if

       call nc_check(nf90_close(ncid),Iam,'nf90_close')

  end do ears_db_loop
  deallocate(data1b8,data1b4)

  call combine_radobs(mype_sub,mype_root,npe_sub,mpi_comm_sub,&
     nele,itxmax,nread,ndata,data_all,score_crit,nrec)
  
  if(mype_sub==mype_root)then
     do n=1,ndata
        do i=1,nchanl
           if(data_all(i+nreal,n) > tbmin .and. &
              data_all(i+nreal,n) < tbmax)nodata=nodata+1
        end do
     end do
     if(dval_use .and. assim)then
        do n=1,ndata
           itt=nint(data_all(33,n))
           super_val(itt)=super_val(itt)+val_tovs
        end do
     end if

!    Write final set of "best" observations to output file
     call count_obs(ndata,nele,ilat,ilon,data_all,nobs)
! Temporary change to obstype to allow tracking of extra index in data_all
    
     ! causing crash. 
     !obstype_tmp=obstype
     !if (nind==1) then  
     !   obstype_tmp=trim(obstype)//'nc4' 
     !else
     !   obstype_tmp=trim(obstype)
     !endif
     write(lunout) obstype,sis,nreal,nchanl,ilat,ilon
     write(lunout) ((data_all(k,n),k=1,nele),n=1,ndata)

endif 


! Deallocate local arrays
  
  deallocate(data_all,nrec)

! Deallocate satthin arrays
  call destroygrids
 
! Deallocate FOV surface code arrays and nullify pointers.
  if (isfcalc == 1) call fov_cleanup

  if(diagnostic_reg.and.ntest>0) write(6,*)'READ_NC4TOVS:  ',&
     'mype,ntest,disterrmax=',mype,ntest,disterrmax

! End of routine
  return

end subroutine read_nc4tovs
