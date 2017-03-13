subroutine read_ahi(mype,val_img,ithin,rmesh,jsatid,gstime,&
     infile,lunout,obstype,nread,ndata,nodata,twind,sis, &
     mype_root,mype_sub,npe_sub,mpi_comm_sub,nobs)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    read_ahi                    read himawari-8 ahi data
!   prgmmr: zaizhong ma     org: np23                date: 2014-11-19
!
! abstract:  This routine reads Himawari8 AHI radiance (brightness
!            temperature) files.  Optionally, the data are thinned to
!            a specified resolution using simple quality control checks.
!
!            When running the gsi in regional mode, the code only
!            retains those observations that fall within the regional
!            domain
!
! program history log:
!   2014-11-19 zaizhong began developping with the proxy data from JMA
!   2014-12-12 zaizhong done the first version of this subroutine
!   2014-12-23 zaizhong cleaned up and finalized with the proxy data
!   2015-03-23 zaizhong cleaned up and finalized with the real sample data
!   2015-09-17 Thomas   add l4densvar and thin4d to data selection procedure
!   2016-03-11 j. guo   Fixed {dlat,dlon}_earth_deg in the obs data stream
!
!   input argument list:
!     mype     - mpi task id
!     val_img  - weighting factor applied to super obs
!     ithin    - flag to thin data
!     rmesh    - thinning mesh size (km)
!     jsatid   - satellite to read
!     gstime   - analysis time in minutes from reference date
!     infile   - unit from which to read BUFR data
!     lunout   - unit to which to write data for further processing
!     obstype  - observation type to process
!     twind    - input group time window (hours)
!     sis      - satellite/instrument/sensor indicator
!
!   output argument list:
!     nread    - number of BUFR GOES imager observations read
!     ndata    - number of BUFR GOES imager profiles retained for further processing
!     nodata   - number of BUFR GOES imager observations retained for further processing
!     nobs     - array of observations on each subdomain for each processor
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use kinds, only: r_kind,r_double,i_kind
  use satthin, only: super_val,itxmax,makegrids,map2tgrid,destroygrids, &
      checkob,finalcheck,score_crit
  use gridmod, only: diagnostic_reg,regional,nlat,nlon,txy2ll,tll2xy,rlats,rlons
  use constants, only: deg2rad,zero,one,rad2deg,r60inv,r60
  use radinfo, only: iuse_rad,jpch_rad,nusis
  use gsi_4dvar, only: l4dvar,iwinbgn,winlen,l4densvar,thin4d
  use deter_sfc_mod, only: deter_sfc
  use gsi_nstcouplermod, only: nst_gsi,nstinfo
  use gsi_nstcouplermod, only: gsi_nstcoupler_skindepth, gsi_nstcoupler_deter
  use file_utility, only : get_lun     
  use mpimod, only: npe
  implicit none

! Declare passed variables
  character(len=*),intent(in   ) :: infile,obstype,jsatid
  character(len=*),intent(in  ) :: sis
  integer(i_kind) ,intent(in   ) :: mype,lunout,ithin
  integer(i_kind),dimension(npe)  ,intent(inout) :: nobs
  integer(i_kind) ,intent(inout) :: ndata,nodata
  integer(i_kind) ,intent(inout) :: nread
  real(r_kind)    ,intent(in   ) :: rmesh,gstime,twind
  real(r_kind)    ,intent(inout) :: val_img
  integer(i_kind) ,intent(in   ) :: mype_root
  integer(i_kind) ,intent(in   ) :: mype_sub
  integer(i_kind) ,intent(in   ) :: npe_sub
  integer(i_kind) ,intent(in   ) :: mpi_comm_sub

! Declare local parameters
  integer(i_kind),parameter:: nimghdr=13
  integer(i_kind),parameter:: maxinfo=33
  integer(i_kind),parameter:: maxchanl=11
  real(r_kind),parameter:: r360=360.0_r_kind
  real(r_kind),parameter:: r180=180.0_r_kind
  real(r_kind),parameter:: tbmin=50.0_r_kind
  real(r_kind),parameter:: tbmax=550.0_r_kind
  character(80),parameter:: hdrh8  = &            ! Himawari-8 AHI header
              'SAID YEAR MNTH DAYS HOUR MINU SECW CLATH CLONH SAZA SOZA BEARAZ SOLAZI'

! Declare local variables
  logical outside,iuse,assim

  character(8) subset

  integer(i_kind) nchanl,ilath,ilonh,ilzah,iszah,irec,next
  integer(i_kind) nmind,lnbufr,idate,ilat,ilon
  integer(i_kind) ireadmg,ireadsb,iret,nreal,nele,itt
  integer(i_kind) itx,i,k,isflg,kidsat,n,iscan,idomsfc
  integer(i_kind) idate5(5)
  integer(i_kind),allocatable,dimension(:)::nrec

  real(r_kind) dg2ew,sstime,tdiff,t4dv,sfcr
  real(r_kind) dlon,dlat,timedif,crit1,dist1
  real(r_kind) dlon_earth,dlat_earth
  real(r_kind) dlon_earth_deg,dlat_earth_deg
  real(r_kind) pred
  real(r_kind),dimension(0:3):: sfcpct
  real(r_kind),dimension(0:3):: ts
  real(r_kind) :: tsavg,vty,vfr,sty,stp,sm,sn,zz,ff10
  real(r_kind) :: zob,tref,dtw,dtc,tz_tr
  real(r_kind),allocatable,dimension(:,:):: data_all

  real(r_double),dimension(nimghdr) :: hdrh8arr       !   Himawari8 AHI data
  real(r_double),dimension(3,12) :: dataahi              !   Himawari8 AHI data

!--start-- variables for AHI cloud detection
  real(r_kind)                        :: ts_coef0
  real(r_kind), dimension(4)          :: ts_coef
  integer(i_kind), dimension(2)       :: ts_ichan
  real(r_kind)                        :: seca, dbt_ts
  real(r_kind)                        :: dts_thresh = 330.0_r_kind
  integer(i_kind)                     :: qc_thresh = 1
  real(r_kind), dimension(2)          :: bt_ts
  !---regression sst from split window test
  real(r_kind)                        :: ts_reg
  !---difference between sst from regression and surface
  real(r_kind)                        :: sst_test
!-end--- variables for AHI cloud detection

  real(r_kind) disterr,disterrmax,dlon00,dlat00
  integer(i_kind) ntest

!**************************************************************************
! Initialize variables
  lnbufr = 10
  disterrmax=zero
  ntest=0
  dg2ew = r360*deg2rad

  ilon=3
  ilat=4

  if (nst_gsi > 0 ) then
     call gsi_nstcoupler_skindepth(obstype, zob)         ! get penetration depth (zob) for the obstype
  endif

  ndata=0
  nodata=0
  nchanl=10       ! the channel number
  ilath=8        ! the position of latitude in the header
  ilonh=9        ! the position of longitude in the header
  ilzah=10       ! satellite zenith angle
  iszah=11       ! solar zenith angle

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
  if (.not.assim) val_img=zero


! Make thinning grids
  call makegrids(rmesh,ithin)


! Open bufr file.
  call closbf(lnbufr)
  open(lnbufr,file=trim(infile),form='unformatted')
  call openbf(lnbufr,'IN',lnbufr)
  call datelen(10)
  if(jsatid == 'himawari8') kidsat = 173

! Allocate arrays to hold all data for given satellite
  nreal = maxinfo + nstinfo
  nele  = nreal   + nchanl
  allocate(data_all(nele,itxmax),nrec(itxmax))

  next=0
  nrec=999999
  irec=0

!---regression coefficients trained in clear simulation
  !   using CRTM v2.1.3 AHI and ECMWF
  ts_coef    = (/1.16778_r_kind, -1.27133_r_kind, 0.416716_r_kind, &
                 2.16380_r_kind/)
  ts_coef0   = -51.0104_r_kind
  !---should be channels 11.2 and 12.38 microns
  ts_ichan   = (/10,11/) ! (8,9) offset by two for bands 5 and 6 of AHI
  !---threshold for difference in regression from tsavg
  !   COAT used 1.25 so we may need to make this smaller.
  dts_thresh = 2.00
  !---currently not used
  qc_thresh  = -1

! Big loop over bufr file
  do while(IREADMG(lnbufr,subset,idate) >= 0)
     irec=irec+1
     next=next+1
     if(next == npe_sub)next=0
     if(next /= mype_sub)cycle
     read_loop: do while (IREADSB(lnbufr) == 0)

!       Read through each reacord
        call ufbint(lnbufr,hdrh8arr,nimghdr,1,iret,hdrh8)
        if(hdrh8arr(1) /= kidsat) cycle read_loop
        call ufbrep(lnbufr,dataahi,3,12,iret,'TMBR CHNM CHWL')
        nread=nread+nchanl

!      first step QC filter out data with less clear sky fraction
        if (hdrh8arr(ilzah) >r60) cycle read_loop
        if (hdrh8arr(iszah) >= r180) cycle read_loop

!       Compare relative obs time with window.  If obs 
!       falls outside of window, don't use this obs
        idate5(1) = hdrh8arr(2)     !year
        idate5(2) = hdrh8arr(3)     ! month
        idate5(3) = hdrh8arr(4)     ! day
        idate5(4) = hdrh8arr(5)     ! hours
        idate5(5) = hdrh8arr(6)     ! minutes
        call w3fs21(idate5,nmind)
        t4dv = (real((nmind-iwinbgn),r_kind) + real(hdrh8arr(7),r_kind)*r60inv)*r60inv
        sstime = real(nmind,r_kind) + real(hdrh8arr(7),r_kind)*r60inv
        tdiff=(sstime-gstime)*r60inv
        if (l4dvar.or.l4densvar) then
           if (t4dv<zero .OR. t4dv>winlen) cycle read_loop
        else
           if (abs(tdiff)>twind) cycle read_loop
        endif

!       Convert obs location from degrees to radians
        if (hdrh8arr(ilonh)>=r360) hdrh8arr(ilonh)=hdrh8arr(ilonh)-r360
        if (hdrh8arr(ilonh)< zero) hdrh8arr(ilonh)=hdrh8arr(ilonh)+r360

        dlon_earth_deg = hdrh8arr(ilonh)
        dlat_earth_deg = hdrh8arr(ilath)
        dlon_earth=hdrh8arr(ilonh)*deg2rad
        dlat_earth=hdrh8arr(ilath)*deg2rad

!       If regional, map obs lat,lon to rotated grid.
        if(regional)then

!          Convert to rotated coordinate.  dlon centered on 180 (pi), 
!          so always positive for limited area
           call tll2xy(dlon_earth,dlat_earth,dlon,dlat,outside)

           if(diagnostic_reg) then
              call txy2ll(dlon,dlat,dlon00,dlat00)
              ntest=ntest+1
              disterr=acos(sin(dlat_earth)*sin(dlat00)+cos(dlat_earth)*cos(dlat00)* &
                   (sin(dlon_earth)*sin(dlon00)+cos(dlon_earth)*cos(dlon00)))*rad2deg
              disterrmax=max(disterrmax,disterr)
           end if

!          Check to see if in domain.  outside=.true. if dlon_earth,
!          dlat_earth outside domain, =.false. if inside
           if(outside) cycle read_loop

!       Global case
        else
           dlon=dlon_earth
           dlat=dlat_earth
           call grdcrd1(dlat,rlats,nlat,1)
           call grdcrd1(dlon,rlons,nlon,1)
        endif

        if (thin4d) then
           crit1=0.01_r_kind
        else
           timedif = 6.0_r_kind*abs(tdiff)        ! range:  0 to 18
           crit1=0.01_r_kind+timedif
        endif
        call map2tgrid(dlat_earth,dlon_earth,dist1,crit1,itx,ithin,itt,iuse,sis)
        if(.not. iuse)cycle read_loop


!       Locate the observation on the analysis grid.  Get sst and land/sea/ice
!       mask.  

!     isflg    - surface flag
!                0 sea
!                1 land
!                2 sea ice
!                3 snow
!                4 mixed                         


        call deter_sfc(dlat,dlon,dlat_earth,dlon_earth,t4dv,isflg,idomsfc,sfcpct, &
            ts,tsavg,vty,vfr,sty,stp,sm,sn,zz,ff10,sfcr)

        if (isflg >= 1) cycle read_loop   !!!test ocean only

!       Set common predictor parameters

!! comment the following line to add the clear filter for Himawari-8 AHI !!
!start by ZZMA

        !---secant of the sensor zenith angle  
        seca = 1.0_r_kind / COS( hdrh8arr(ilzah) * deg2rad )
        !---brightness temperature of channels used for regression
        bt_ts   = dataahi(1,ts_ichan)
         
        !---difference in BTs water-window or window-water 
        !  (depends on channel selection)
        dbt_ts  = bt_ts(2)-bt_ts(1)

        !---calculate regression surface temperature using 
        !   empirical relation
        ts_reg = &
             ts_coef0 + ts_coef(1)*bt_ts(2) + ts_coef(2)*dbt_ts + &
             ts_coef(3)*dbt_ts*dbt_ts + ts_coef(4) * seca
        !---automatically reject freezing regression temperatures
        if ( ts_reg <= 273.00_r_kind) ts_reg = -10.
        
        !---two options with the split window test
        ! 1.) throw out observations with large SST_reg - SST_detersfc
        ! 2.) use thinning routines from satthin.F90 module :: checkob () 
        !     to pick "best" observation in thinning box

        !---Option 1.)
        ! the following line will through out any observation 
        ! with delta.ts > dts_threshold
        !  tsavg from deter_sfc
        sst_test = tsavg-ts_reg
        if (abs(sst_test) >= dts_thresh) cycle read_loop

        !---Option 2.)
        !---or we can do this --use sathin module to select best pixels
        !   in thinning box
        !---larger values are bad
        ! sst_test = max(zero,sst_test)
        !---or i would prefer -- larger values still bad for whatever reason
        sst_test = ABS(sst_test)
        pred  = 15._r_kind*sst_test
        
        crit1 = crit1 + pred
!end by ZZMA
        call checkob(dist1,crit1,itx,iuse)
        if(.not. iuse)cycle read_loop

!       Compute "score" for observation.  All scores>=0.0.  Lowest score is "best"
        call finalcheck(dist1,crit1,itx,iuse)
        if(.not. iuse) cycle read_loop

!       Map obs to grids
        iscan = nint(hdrh8arr(ilzah))+1.001_r_kind ! integer scan position
!
!       interpolate NSST variables to Obs. location and get dtw, dtc, tz_tr
!
        if ( nst_gsi > 0 ) then
           tref  = ts(0)
           dtw   = zero
           dtc   = zero
           tz_tr = one
           if ( sfcpct(0) > zero ) then
              call gsi_nstcoupler_deter(dlat_earth,dlon_earth,t4dv,zob,tref,dtw,dtc,tz_tr)
           endif
        endif

!       Transfer information to work array
        data_all( 1,itx) = hdrh8arr(1)                ! satellite id
        data_all( 2,itx) = t4dv                       ! analysis relative time
        data_all( 3,itx) = dlon                       ! grid relative longitude
        data_all( 4,itx) = dlat                       ! grid relative latitude
        data_all( 5,itx) = hdrh8arr(ilzah)*deg2rad    ! satellite zenith angle (radians)
        data_all( 6,itx) = hdrh8arr(12)               ! satellite azimuth angle (radians)
!ZZ        data_all( 7,itx) = dataahi(2,1)               ! clear sky amount
        data_all( 8,itx) = iscan                      ! integer scan position
        data_all( 9,itx) = hdrh8arr(iszah)            ! solar zenith angle
        data_all(10,itx) = hdrh8arr(13)               ! solar azimuth angle
        data_all(11,itx) = sfcpct(0)                  ! sea percentage of
        data_all(12,itx) = sfcpct(1)                  ! land percentage
        data_all(13,itx) = sfcpct(2)                  ! sea ice percentage
        data_all(14,itx) = sfcpct(3)                  ! snow percentage
        data_all(15,itx)= ts(0)                       ! ocean skin temperature
        data_all(16,itx)= ts(1)                       ! land skin temperature
        data_all(17,itx)= ts(2)                       ! ice skin temperature
        data_all(18,itx)= ts(3)                       ! snow skin temperature
        data_all(19,itx)= tsavg                       ! average skin temperature
        data_all(20,itx)= vty                         ! vegetation type
        data_all(21,itx)= vfr                         ! vegetation fraction
        data_all(22,itx)= sty                         ! soil type
        data_all(23,itx)= stp                         ! soil temperature
        data_all(24,itx)= sm                          ! soil moisture
        data_all(25,itx)= sn                          ! snow depth
        data_all(26,itx)= zz                          ! surface height
        data_all(27,itx)= idomsfc + 0.001_r_kind      ! dominate surface type
        data_all(28,itx)= sfcr                        ! surface roughness
        data_all(29,itx)= ff10                        ! ten meter wind factor
        data_all(30,itx)= dlon_earth_deg              ! earth relative longitude (degrees)
        data_all(31,itx)= dlat_earth_deg              ! earth relative latitude (degrees)
        data_all(32,itx) = val_img
        data_all(33,itx) = itt

        if ( nst_gsi > 0 ) then
           data_all(maxinfo+1,itx) = tref         ! foundation temperature
           data_all(maxinfo+2,itx) = dtw          ! dt_warm at zob
           data_all(maxinfo+3,itx) = dtc          ! dt_cool at zob
           data_all(maxinfo+4,itx) = tz_tr        ! d(Tz)/d(Tr)
        endif

!       Transfer observation location and other data to local arrays

        do k=1,nchanl
           data_all(k+nreal,itx)=dataahi(1,k+2)   ! test only for AHI channels:7-16
        end do

        nrec(itx)=irec

     enddo read_loop
  enddo

  call combine_radobs(mype_sub,mype_root,npe_sub,mpi_comm_sub,&
     nele,itxmax,nread,ndata,data_all,score_crit,nrec)

! If no observations read, jump to end of routine.
  do n=1,ndata
     do k=1,nchanl
        if(data_all(k+nreal,n) > tbmin .and. &
           data_all(k+nreal,n) < tbmax)nodata=nodata+1
    end do
    itt=nint(data_all(maxinfo,n))
    super_val(itt)=super_val(itt)+val_img
  end do

! Write final set of "best" observations to output file
  call count_obs(ndata,nele,ilat,ilon,data_all,nobs)
  write(lunout) obstype,sis,nreal,nchanl,ilat,ilon
  write(lunout) ((data_all(k,n),k=1,nele),n=1,ndata)

! Deallocate local arrays
  deallocate(data_all,nrec)

! Deallocate satthin arrays
900 continue
  call destroygrids
  call closbf(lnbufr)

  if(diagnostic_reg.and.ntest>0) write(6,*)'READ_AHI:  ',&
     'mype,ntest,disterrmax=',mype,ntest,disterrmax

  return
end subroutine read_ahi
