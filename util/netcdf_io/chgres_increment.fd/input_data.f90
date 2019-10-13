 module input_data

 use utils
 use setup
 use netcdf 

 implicit none

 private

 integer, public                              :: ij_input, kgds_input(200)
 integer, public                              :: i_input, j_input, lev
 integer, public                              :: idate(6)
 integer, public                              :: icldamt, iicmr,  &
                                                 idelz,idpres,idzdt, &
                                                 irwmr,isnmr,igrle


 real, allocatable, public                    :: vcoord(:,:)
 real, allocatable, public                    :: clwmr_input(:,:)
 real, allocatable, public                    :: dzdt_input(:,:)
 real, allocatable, public                    :: grle_input(:,:)
 real, allocatable, public                    :: cldamt_input(:,:) 
 real, allocatable, public                    :: icmr_input(:,:)
 real, allocatable, public                    :: o3mr_input(:,:)
 real, allocatable, public                    :: rwmr_input(:,:)
 real, allocatable, public                    :: snmr_input(:,:)
 real, allocatable, public                    :: spfh_input(:,:)
 real, allocatable, public                    :: tmp_input(:,:)
 real, allocatable, public                    :: ugrd_input(:,:)
 real, allocatable, public                    :: vgrd_input(:,:)
 real  :: missing_value=1.e30

 public                                       :: read_input_data
 public                                       :: read_vcoord_info

 contains

 subroutine read_input_data

!-------------------------------------------------------------------------------------
! Read input grid data from a netcdf file.
!-------------------------------------------------------------------------------------

 implicit none

 integer :: vlev
 real, allocatable                            :: work2d(:,:),work3d(:,:,:)
 real, allocatable                            :: work1d(:), work1d1(:)
 integer :: ncid,dimid,varid

 print*
 print*,"OPEN INPUT FILE: ",trim(input_file)
 call nccheck(nf90_open(trim(input_file),NF90_NOWRITE,ncid))

 print*,"GET INPUT FILE HEADER"
 call nccheck(nf90_inq_dimid(ncid, 'lon', dimid))
 call nccheck(nf90_inquire_dimension(ncid, dimid, len=i_input))
 call nccheck(nf90_inq_dimid(ncid, 'lat', dimid))
 call nccheck(nf90_inquire_dimension(ncid, dimid, len=j_input))
 call nccheck(nf90_inq_dimid(ncid, 'pfull', dimid))
 call nccheck(nf90_inquire_dimension(ncid, dimid, len=lev))
 
 print*,'DIMENSIONS OF DATA ARE: ', i_input, j_input, lev

 ij_input = i_input * j_input

 allocate(work2d(lon,lat))
 allocate(work3d(lon,lat,lev))

 print*
 print*,"READ LAT"

 print*
 print*,"READ LON"

 print*
 print*,"READ LEV VARS"

 print*
 print*,"READ U WIND INCREMENT"
 allocate(ugrd_input(ij_input,lev))
 call nccheck(nf90_inq_varid(ncid, 'u_inc', varid))
 call nccheck(nf90_get_var(ncid, varid, work3d))
 do vlev = 1, lev
   ugrd_input(:,vlev) = reshape(work3d(:,:,vlev),(/ij_input/)) 
   print*,'MAX/MIN U WIND INCREMENT AT LEVEL ',vlev, "IS: ", maxval(ugrd_input(:,vlev)), minval(ugrd_input(:,vlev))
 enddo

 print*
 print*,"READ V WIND INCREMENT"
 allocate(vgrd_input(ij_input,lev))
 call nccheck(nf90_inq_varid(ncid, 'v_inc', varid))
 call nccheck(nf90_get_var(ncid, varid, work3d))
 do vlev = 1, lev
   vgrd_input(:,vlev) = reshape(work3d(:,:,vlev),(/ij_input/)) 
   print*,'MAX/MIN V WIND INCREMENT AT LEVEL ', vlev, "IS: ", maxval(vgrd_input(:,vlev)), minval(vgrd_input(:,vlev))
 enddo

 print*
 print*,"READ TEMPERATURE INCREMENT"
 allocate(tmp_input(ij_input,lev))
 call nccheck(nf90_inq_varid(ncid, 't_inc', varid))
 call nccheck(nf90_get_var(ncid, varid, work3d))
 do vlev = 1, lev
   tmp_input(:,vlev) = reshape(work3d(:,:,rlev),(/ij_input/)) 
   print*,'MAX/MIN TEMPERATURE INCREMENT AT LEVEL ', vlev, 'IS: ', maxval(tmp_input(:,vlev)), minval(tmp_input(:,vlev))
 enddo

 print*
 print*,"READ SPECIFIC HUMIDITY"
 allocate(spfh_input(ij_input,lev))
 call read_vardata(indset, 'spfh', work3d)
 do vlev = 1, lev
   rvlev = lev+1-vlev
   spfh_input(:,vlev) = reshape(work3d(:,:,rvlev),(/ij_input/)) 
   print*,'MAX/MIN SPECIFIC HUMIDITY AT LEVEL ', vlev, 'IS: ', maxval(spfh_input(:,vlev)), minval(spfh_input(:,vlev))
 enddo

 print*
 print*,"READ CLOUD LIQUID WATER"
 allocate(clwmr_input(ij_input,lev))
 call read_vardata(indset, 'clwmr', work3d)
 do vlev = 1, lev
   rvlev = lev+1-vlev
   clwmr_input(:,vlev) = reshape(work3d(:,:,rvlev),(/ij_input/)) 
   print*,'MAX/MIN CLOUD LIQUID WATER AT LEVEL ', vlev, 'IS: ', maxval(clwmr_input(:,vlev)), minval(clwmr_input(:,vlev))
 enddo

 print*
 print*,"READ OZONE"
 allocate(o3mr_input(ij_input,lev))
 call read_vardata(indset, 'o3mr', work3d)
 do vlev = 1, lev
   rvlev = lev+1-vlev
   o3mr_input(:,vlev) = reshape(work3d(:,:,rvlev),(/ij_input/))
   print*,'MAX/MIN OZONE AT LEVEL ', vlev, 'IS: ', maxval(o3mr_input(:,vlev)), minval(o3mr_input(:,vlev))
 enddo

 print*
 print*,"READ DZDT"
 allocate(dzdt_input(ij_input,lev))
 call read_vardata(indset, 'dzdt', work3d, errcode=iret)
 if (iret == 0) then
    do vlev = 1, lev
      rvlev = lev+1-vlev
      dzdt_input(:,vlev) = reshape(work3d(:,:,rvlev),(/ij_input/))
      print*,'MAX/MIN DZDT AT LEVEL ', vlev, 'IS: ', maxval(dzdt_input(:,vlev)), minval(dzdt_input(:,vlev))
    enddo
    idzdt = 1
 else
    dzdt_input = missing_value
    print*,'DZDT NOT IN INPUT FILE'
    idzdt = 0 
 endif


 print*
 print*,"READ RWMR"
 allocate(rwmr_input(ij_input,lev))
 call read_vardata(indset, 'rwmr', work3d, errcode=iret)
 if (iret == 0) then
    do vlev = 1, lev
      rvlev = lev+1-vlev
      rwmr_input(:,vlev) = reshape(work3d(:,:,rvlev),(/ij_input/))
      print*,'MAX/MIN RWMR AT LEVEL ', vlev, 'IS: ', maxval(rwmr_input(:,vlev)), minval(rwmr_input(:,vlev))
    enddo
    irwmr = 1
 else
    rwmr_input = missing_value
    print*,'RWMR NOT IN INPUT FILE'
    irwmr = 0 
 endif

 print*
 print*,"READ ICMR"
 allocate(icmr_input(ij_input,lev))
 call read_vardata(indset, 'icmr', work3d, errcode=iret)
 if (iret == 0) then
    do vlev = 1, lev
      rvlev = lev+1-vlev
      icmr_input(:,vlev) = reshape(work3d(:,:,rvlev),(/ij_input/)) 
      print*,'MAX/MIN ICMR AT LEVEL ', vlev, 'IS: ', maxval(icmr_input(:,vlev)), minval(icmr_input(:,vlev))
    enddo
    iicmr = 1
 else
    icmr_input = missing_value
    print*,'ICMR NOT IN INPUT FILE'
    iicmr = 0 
 endif

 print*
 print*,"READ SNMR"
 allocate(snmr_input(ij_input,lev))
 call read_vardata(indset, 'snmr', work3d, errcode=iret)
 if (iret == 0) then
    do vlev = 1, lev
      rvlev = lev+1-vlev
      snmr_input(:,vlev) = reshape(work3d(:,:,rvlev),(/ij_input/)) 
      print*,'MAX/MIN SNMR AT LEVEL ', vlev, 'IS: ', maxval(snmr_input(:,vlev)), minval(snmr_input(:,vlev))
    enddo
    isnmr = 1
 else
    snmr_input = missing_value
    print*,'SNMR NOT IN INPUT FILE'
    isnmr = 0 
 endif

 print*
 print*,"READ GRLE"
 allocate(grle_input(ij_input,lev))
 call read_vardata(indset, 'grle', work3d, errcode=iret)
 if (iret == 0) then
    do vlev = 1, lev
      rvlev = lev+1-vlev
      grle_input(:,vlev) = reshape(work3d(:,:,rvlev),(/ij_input/)) 
      print*,'MAX/MIN GRLE AT LEVEL ', vlev, 'IS: ', maxval(grle_input(:,vlev)), minval(grle_input(:,vlev))
    enddo
    igrle = 1
 else
    grle_input = missing_value
    print*,'GRLE NOT IN INPUT FILE'
    igrle = 0 
 endif

 print*
 print*,"READ CLD_AMT"
 allocate(cldamt_input(ij_input,lev))
 call read_vardata(indset, 'cld_amt', work3d, errcode=iret)
 if (iret == 0) then
    do vlev = 1, lev
      rvlev = lev+1-vlev
      cldamt_input(:,vlev) = reshape(work3d(:,:,rvlev),(/ij_input/))
      print*,'MAX/MIN CLD_AMT AT LEVEL ', vlev, 'IS: ', maxval(cldamt_input(:,vlev)), minval(cldamt_input(:,vlev))
    enddo
    icldamt = 1
 else
    cldamt_input = missing_value
    print*,'CLDAMT NOT IN INPUT FILE'
    icldamt = 0 
 endif

 call read_vardata(indset, 'dpres', work3d, errcode=iret)
 if (iret == 0) then
    idpres = 1
 else
    idpres = 0
 endif
 call read_vardata(indset, 'delz', work3d, errcode=iret)
 if (iret == 0) then
    idelz = 1
 else
    idelz = 0
 endif

 print*,"CLOSE FILE"
 call close_dataset(indset)
 deallocate(work2d,work3d)

!---------------------------------------------------------------------------------------
! Set the grib 1 grid description array need by the NCEP IPOLATES library.
!---------------------------------------------------------------------------------------

 call calc_kgds(i_input, j_input, kgds_input)

 return

 end subroutine read_input_data

 subroutine read_vcoord_info

!---------------------------------------------------------------------------------
! Read vertical coordinate information.
!---------------------------------------------------------------------------------

 implicit none

 integer                    :: istat, levs_vcoord, n, k

 print*
 print*,"OPEN VERTICAL COORD FILE: ", trim(vcoord_file)
 open(14, file=trim(vcoord_file), form='formatted', iostat=istat)
 if (istat /= 0) then
   print*,"FATAL ERROR OPENING FILE. ISTAT IS: ", istat
   call errexit(4)
 endif

 read(14, *, iostat=istat) nvcoord, levs_vcoord
 if (istat /= 0) then
   print*,"FATAL ERROR READING FILE HEADER. ISTAT IS: ",istat
   call errexit(5)
 endif

!---------------------------------------------------------------------------------
! The last value in the file is not used for the fv3 core.  Only read the first 
! (lev + 1) values.
!---------------------------------------------------------------------------------

 allocate(vcoord(lev+1, nvcoord))
 read(14, *, iostat=istat) ((vcoord(n,k), k=1,nvcoord), n=1,lev+1)
 if (istat /= 0) then
   print*,"FATAL ERROR READING FILE. ISTAT IS: ",istat
   call errexit(6)
 endif

 print*
 do k = 1, (lev+1)
   print*,'VCOORD FOR LEV ', k, 'IS: ', vcoord(k,:)
 enddo

 close(14)

 end subroutine read_vcoord_info

 subroutine nccheck(status)
   integer, intent (in) :: status
   if (status /= nf90_noerr) then
      print *, "netCDF error", trim(nf90_strerror(status))
      call stop(999)
   end if
 end subroutine nccheck

 end module input_data
