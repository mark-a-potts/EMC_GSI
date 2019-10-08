!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    read_ozndiag                       read ozone diag file
!   prgmmr: hliu           org: np20                date: 2009-04-15
!
! abstract:  This module contains code to process ozone
!            diagnostic files.  The module defines structures
!            to contain information from the ozone
!            diagnostic files and then provides two routines
!            to access contents of the file.
!
! program history log:
!
! contains
!   read_ozndiag_header - read ozone diagnostic file header
!   read_ozndiag_data   - read ozone diagnostic file data
!   set_netcdf_read  - call set_netcdf_read(.true.) to use nc4 hooks,
!                       otherwise read file as binary format
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
!------------------------------------------------------------
!

module read_ozndiag

  ! USE:
  use kinds, only: r_single,i_kind
  use nc_diag_read_mod, only: nc_diag_read_init, nc_diag_read_close

  !--- implicit

  implicit none


  !--- public & private

  private

  public :: diag_header_fix_list
  public :: diag_header_nlev_list
  public :: diag_data_fix_list
  public :: diag_data_nlev_list
  public :: diag_data_extra_list

  public :: open_ozndiag
  public :: close_ozndiag
  public :: read_ozndiag_header
  public :: read_ozndiag_data

  public :: set_netcdf_read


  !--- diagnostic file format - header
  
  type diag_header_fix_list
    sequence
    character(len=20) :: isis           ! sat and sensor type
    character(len=10) :: id             ! sat type
    character(len=10) :: obstype	! observation type
    integer(i_kind)   :: jiter          ! outer loop counter
    integer(i_kind)   :: nlevs		! number of levels (layer amounts + total column) per obs
    integer(i_kind)   :: ianldate	! analysis date in YYYYMMDDHH 
    integer(i_kind)   :: iint		! mpi task number
    integer(i_kind)   :: ireal		! # of real elements in the fix part of a data record
    integer(i_kind)   :: iextra		! # of extra elements for each level
  end type diag_header_fix_list

  type diag_header_nlev_list
    sequence
    real(r_single) :: pob		! SBUV/2,omi and gome-2 obs pressure level
    real(r_single) :: grs		! gross error
    real(r_single) :: err		! observation error
    integer(i_kind):: iouse		! use flag
  end type diag_header_nlev_list

  !--- diagnostic file format - data

  integer,parameter :: IREAL_RESERVE  = 3
  
  type diag_data_fix_list
    sequence
    real(r_single) :: lat            ! latitude (deg)
    real(r_single) :: lon            ! longitude (deg)
    real(r_single) :: obstime        ! observation time relative to analysis
  end type diag_data_fix_list

  type diag_data_nlev_list
    sequence
    real(r_single) :: ozobs              ! ozone (obs)
    real(r_single) :: ozone_inv          ! obs-ges
    real(r_single) :: varinv             ! inverse obs error **2
    real(r_single) :: sza                ! solar zenith angle
    real(r_single) :: fovn               ! scan position (field of view)
    real(r_single) :: toqf               ! omi row anomaly index or MLS o3mr precision
  end type diag_data_nlev_list

  type diag_data_extra_list
  sequence
    real(r_single) :: extra              ! extra information
  end type diag_data_extra_list

  logical,save     ::  netcdf = .false.

  type ncdiag_status
     logical :: nc_read
     integer(i_kind) :: cur_ob_idx
     integer(i_kind) :: num_records
     type(diag_data_fix_list),  allocatable  :: all_data_fix(:)
     type(diag_data_nlev_list), allocatable  :: all_data_nlev(:,:)  ! rad nchan= ozn nlev
     type(diag_data_extra_list), allocatable :: all_data_extra(:,:,:)
  end type ncdiag_status

  integer(i_kind), parameter                            :: MAX_OPEN_NCDIAG = 2
  integer(i_kind), save                                 :: nopen_ncdiag = 0
  integer(i_kind), dimension(MAX_OPEN_NCDIAG), save     :: ncdiag_open_id = (/-1, -1/)
  type(ncdiag_status), dimension(MAX_OPEN_NCDIAG), save :: ncdiag_open_status


 contains

  subroutine open_ozndiag(filename, ftin, istatus)
     character*500,   intent(in) :: filename
     integer(i_kind), intent(inout) :: ftin
     integer(i_kind), intent(out):: istatus

     integer(i_kind) :: i

     write(6,*)'--> open_ozndiag'
     istatus = -999

     if (netcdf) then

        if (nopen_ncdiag >= MAX_OPEN_NCDIAG) then
           write(6,*) 'OPEN_RADIAG:  ***ERROR*** Cannot open more than ', &
                    MAX_OPEN_NCDIAG, ' netcdf diag files.'
!!          call stop2(456)
           istatus = -1
        endif
        call nc_diag_read_init(filename,ftin)
        istatus=0

        do i = 1, MAX_OPEN_NCDIAG
           if (ncdiag_open_id(i) < 0) then
              ncdiag_open_id(i) = ftin
              ncdiag_open_status(i)%nc_read = .false.
              ncdiag_open_status(i)%cur_ob_idx = -9999
              ncdiag_open_status(i)%num_records = -9999
              if (allocated(ncdiag_open_status(i)%all_data_fix)) then
                 deallocate(ncdiag_open_status(i)%all_data_fix)
              endif
              if (allocated(ncdiag_open_status(i)%all_data_nlev)) then
                 deallocate(ncdiag_open_status(i)%all_data_nlev)
              endif
              if (allocated(ncdiag_open_status(i)%all_data_extra)) then
                 deallocate(ncdiag_open_status(i)%all_data_extra)
              endif
              nopen_ncdiag = nopen_ncdiag + 1
              exit
           endif
        enddo

     else
       open(ftin,form="unformatted",file=filename,iostat=istatus)
       rewind(ftin)
     endif

     write(6,*)'<-- open_ozndiag'
  end subroutine open_ozndiag


  subroutine close_ozndiag(filename, ftin)
     character*500,   intent(in) :: filename
     integer(i_kind), intent(inout) :: ftin

     integer(i_kind) :: id

     write(6,*)'--> close_ozndiag'
     if (netcdf) then
        id = find_ncdiag_id(ftin)
        if (id < 0) then
           write(6,*) 'CLOSE_RADIAG:  ***ERROR*** ncdiag file ', filename,   &
                      ' was not opened'
!           call stop2(456)
        endif
        call nc_diag_read_close(filename)
        ncdiag_open_id(id) = -1
        ncdiag_open_status(id)%nc_read = .false.
        ncdiag_open_status(id)%cur_ob_idx = -9999
        ncdiag_open_status(id)%num_records = -9999
        if (allocated(ncdiag_open_status(id)%all_data_fix)) then
           deallocate(ncdiag_open_status(id)%all_data_fix)
        endif
        if (allocated(ncdiag_open_status(id)%all_data_nlev)) then
           deallocate(ncdiag_open_status(id)%all_data_nlev)
        endif
        if (allocated(ncdiag_open_status(id)%all_data_extra)) then
           deallocate(ncdiag_open_status(id)%all_data_extra)
        endif
        nopen_ncdiag = nopen_ncdiag - 1
     else
        close(ftin)
     endif

     write(6,*)'<-- close_ozndiag'
  end subroutine close_ozndiag


  !------------------------------------------------------------
  ! set the use_netcdf flag to read either binary (default) or
  !    netcdf formatted diagnostic files.
  !------------------------------------------------------------
  subroutine set_netcdf_read( use_netcdf )

     logical,intent(in)                     :: use_netcdf

     write(6,*)'--> set_netcdf, use_netcdf = ', use_netcdf
     netcdf = use_netcdf
     write(6,*)'netcdf = ', netcdf
     write(6,*)'<-- set_netcdf'

  end subroutine set_netcdf_read


  !------------------------------------------------------------
  ! Read a header record of a diagnostic file
  !------------------------------------------------------------
  subroutine read_ozndiag_header( ftin, header_fix, header_nlev, new_hdr, istatus )

    !--- interface

    integer                    ,intent(in)  :: ftin
    type(diag_header_fix_list ),intent(out) :: header_fix
    type(diag_header_nlev_list),pointer     :: header_nlev(:)
    logical                                 :: new_hdr
    integer(i_kind),intent(out)             :: istatus

  
    istatus = 0
 
!    if ( netcdf )
!       call read_ozndiag_header_nc( ftin, header_fix, header_nlev, new_hdr, istatus )
!    else
       call read_ozndiag_header_bin( ftin, header_fix, header_nlev, new_hdr, istatus )
!    fi
 
 
  end subroutine read_ozndiag_header


  subroutine read_ozndiag_header_bin( ftin, header_fix, header_nlev, new_hdr, istatus )

    !--- interface

    integer                    ,intent(in)  :: ftin
    type(diag_header_fix_list ),intent(out) :: header_fix
    type(diag_header_nlev_list),pointer     :: header_nlev(:)
    logical                                 :: new_hdr
    integer(i_kind),intent(out)             :: istatus


    !--- variables
    
    integer,save :: nlevs_last = -1
    integer :: ilev,k,ioff0
    character(len=10):: id,obstype
    character(len=20):: isis
    integer(i_kind):: jiter,nlevs,ianldate,iint,ireal,iextra
    integer(i_kind),dimension(:),allocatable:: iouse
    real(r_single),dimension(:),allocatable:: pob,grs,err
    
    istatus = 0
    write(6,*) '--> read_ozndiag_header_bin'

    !--- read header (fix part)
    !--- the new header format contains one additional integer value 
    !
    if ( new_hdr ) then
       read(ftin) isis,id,obstype,jiter,nlevs,ianldate,iint,ireal,iextra,ioff0
       print*,'isis,id,obstype,jiter,nlevs,ianldate,iint,ireal,iextra,ioff0 = ', isis,id,obstype,jiter,nlevs,ianldate,iint,ireal,iextra,ioff0
    else
       read(ftin) isis,id,obstype,jiter,nlevs,ianldate,iint,ireal,iextra
       print*,'isis,id,obstype,jiter,nlevs,ianldate,iint,ireal,iextra= ', isis,id,obstype,jiter,nlevs,ianldate,iint,ireal,iextra
    endif


    header_fix%isis      = isis
    header_fix%id        = id
    header_fix%obstype   = obstype
    header_fix%jiter     = jiter
    header_fix%nlevs     = nlevs
    header_fix%ianldate  = ianldate
    header_fix%iint      = iint
    header_fix%ireal     = ireal
    header_fix%iextra    = iextra


    print*,'header_fix%nlevs  = ', header_fix%nlevs
    print*,'header_fix%iint   = ', header_fix%iint
    print*,'header_fix%ireal  = ', header_fix%ireal
    print*,'header_fix%iextra = ', header_fix%iextra

    !--- check header
    
    if( header_fix%ireal  /= IREAL_RESERVE  ) then

      print *, '### ERROR: UNEXPECTED DATA RECORD FORMAT'
      print *, 'ireal  =', header_fix%ireal  
      stop 99

    endif

    if (header_fix%iextra /= 0) then
       write(6,*)'READ_DIAG_HEADER:  extra diagnostic information available, ',&
            'iextra=',header_fix%iextra
    endif

    !--- allocate if necessary

    if( header_fix%nlevs /= nlevs_last )then
      if( nlevs_last > 0 )then
        deallocate( header_nlev )
      endif
      allocate( header_nlev( header_fix%nlevs ) )
      nlevs_last = header_fix%nlevs
      allocate (pob(header_fix%nlevs))
      allocate (grs(header_fix%nlevs))
      allocate (err(header_fix%nlevs))
      allocate (iouse(header_fix%nlevs))
    endif

    !--- read header (level part)
    
    read(ftin)  pob,grs,err,iouse
    do k=1,header_fix%nlevs
       header_nlev(k)%pob = pob(k)
       header_nlev(k)%grs = grs(k)
       header_nlev(k)%err = err(k)
       header_nlev(k)%iouse = iouse(k)
    end do
    deallocate (pob,grs,err,iouse)


    write(6,*) '<-- read_ozndiag_header_bin'
  end subroutine read_ozndiag_header_bin



  !------------------------------------------------------------
  ! Read a data record of the diagnostic file
  !------------------------------------------------------------

  subroutine read_ozndiag_data( ftin, header_fix, data_fix, data_nlev, data_extra, ntobs, iflag )
  
    !--- interface

    integer                    ,intent(in)  :: ftin
    type(diag_header_fix_list ),intent(in)  :: header_fix

    !--- NOTE:  These pointers are used to build an array numbering
    !           iobs.  So they should be allocated every time this
    !           routine is called and should not be deallocated
    !           here.  The time.f90 could deallocate them at the
    !           very end of the program, I think.
    type(diag_data_fix_list),   pointer     :: data_fix(:)
    type(diag_data_nlev_list)  ,pointer     :: data_nlev(:,:)
    type(diag_data_extra_list) ,pointer     :: data_extra(:,:)
    integer                    ,intent(out) :: iflag
    integer(i_kind)            ,intent(out) :: ntobs
    integer(i_kind)            ,pointer     :: data_mpi(:)
    
    print*, '===> read_ozndiag_data'

!    if ( netcdf ) then
!       call read_ozndiag_data_nc( ftin, header_fix, data_fix, data_nlev, data_extra, ntobs, iflag )
!    else
       call read_ozndiag_data_bin( ftin, header_fix, data_fix, data_nlev, data_extra, ntobs, iflag )
!    fi

    print*, '<=== read_ozndiag_data'
  end subroutine read_ozndiag_data


  subroutine read_ozndiag_data_bin( ftin, header_fix, data_fix, data_nlev, data_extra, ntobs, iflag )
  
    !--- interface

    integer                    ,intent(in)  :: ftin
    type(diag_header_fix_list ),intent(in)  :: header_fix

    !--- NOTE:  These pointers are used to build an array numbering
    !           iobs.  So they should be allocated every time this
    !           routine is called and should not be deallocated
    !           here.  The time.f90 could deallocate them at the
    !           very end of the program, I think.
    type(diag_data_fix_list),   pointer     :: data_fix(:)
    type(diag_data_nlev_list)  ,pointer     :: data_nlev(:,:)
    type(diag_data_extra_list) ,pointer     :: data_extra(:,:)
    integer                    ,intent(out) :: iflag
    integer(i_kind)            ,intent(out) :: ntobs
    integer(i_kind)            ,pointer     :: data_mpi(:)
    
    !--- variables
    integer,save :: nlevs_last = -1
    integer,save :: iextra_last = -1
    integer :: iev,iobs,i,j
    real(r_single),allocatable,dimension(:,:)  :: tmp_fix       ! correct
    real(r_single),allocatable,dimension(:,:,:):: tmp_nlev      ! correct
    real(r_single),allocatable,dimension(:,:)  :: tmp_extra     ! correct

    !--- allocate if necessary
    print*, '===> read_ozndiag_data_bin'
    print*, 'nlevs_last, header_fix%nlevs=',nlevs_last,header_fix%nlevs

    read(ftin,IOSTAT=iflag) ntobs
    print*,'ntobs, iflag =',ntobs, iflag

    if( header_fix%nlevs /= nlevs_last )then
      if( nlevs_last > 0 )then
        print*, 'deallocate array data_nlev, data_mpi and data_fix'
        deallocate( data_nlev )
        deallocate( data_fix )
        deallocate( data_mpi )
      endif

      print*, 'attempt to allocate array data_fix, data_nlev, data_mpi'
      allocate( data_fix( ntobs ) )
      print*, 'data_fix( ntobs ) allocated', ntobs
      allocate( data_mpi( ntobs ) )
      print*, 'data_mpi( ntobs ) allocated', ntobs
      allocate( data_nlev( header_fix%nlevs,ntobs ) )
      print*, 'data_nlev( header_fix%nlevs, ntobs ) allocated', header_fix%nlevs, ntobs
      nlevs_last = header_fix%nlevs
    endif

!------------------------------------------------------------------------
!   looks like this might be the issue:
!     data_extra is dimensioned by iextra and ntobs but is only
!     de/allocated based on not agreeing with the iextra_last value
!     but _obs_ will vary from call to call, so that won't always work.
!------------------------------------------------------------------------
    print*, 'header_fix%iextra, iextra_last =', header_fix%iextra, iextra_last
!    if (header_fix%iextra /= iextra_last) then
       if (iextra_last > 0) then
          deallocate (data_extra)
          print*, 'deallocated data_extra'
       endif
       allocate( data_extra(header_fix%iextra,ntobs) )
       print*, 'allocated data_extra, iextra, ntobs', header_fix%iextra, ntobs
       iextra_last = header_fix%iextra
!    endif

    !--- read a record

    print*, 'iextra=', header_fix%iextra
    allocate( tmp_fix(3,ntobs))
    allocate( tmp_nlev(6,header_fix%nlevs,ntobs))

    if (header_fix%iextra == 0) then
       read(ftin,IOSTAT=iflag) data_mpi, tmp_fix, tmp_nlev
       print*,'iflag = ', iflag
    else
       allocate(  tmp_extra(header_fix%iextra,ntobs) )
       read(ftin,IOSTAT=iflag) data_mpi, tmp_fix, tmp_nlev, tmp_extra
       print*,'iflag =',iflag

       do j=1,ntobs
          do i=1,header_fix%iextra
             data_extra(i,j)%extra=tmp_extra(i,j)
          end do
       end do

       deallocate(tmp_extra)
    endif

    do j=1,ntobs
       data_fix(j)%lat     = tmp_fix(1,j)
       data_fix(j)%lon     = tmp_fix(2,j)
       data_fix(j)%obstime = tmp_fix(3,j)
    end do
    deallocate(tmp_fix)

    do j=1,ntobs
       do i=1,header_fix%nlevs
          data_nlev(i,j)%ozobs  = tmp_nlev(1,i,j)
          data_nlev(i,j)%ozone_inv= tmp_nlev(2,i,j)
          data_nlev(i,j)%varinv = tmp_nlev(3,i,j)
          data_nlev(i,j)%sza    = tmp_nlev(4,i,j)
          data_nlev(i,j)%fovn   = tmp_nlev(5,i,j)
          data_nlev(i,j)%toqf   = tmp_nlev(6,i,j)
       end do
    end do
    deallocate(tmp_nlev)

    nlevs_last = -1

    print*, '<=== read_ozndiag_data_bin'
  end subroutine read_ozndiag_data_bin


  
  integer( i_kind ) function find_ncdiag_id( ftin )
     integer(i_kind), intent(in) :: ftin

     integer(i_kind) :: i

     find_ncdiag_id = -1
     do i = 1, MAX_OPEN_NCDIAG
        if ( ncdiag_open_id(i) == ftin ) then
           find_ncdiag_id = i
           return
        endif
     enddo

     return
  end function find_ncdiag_id


end module read_ozndiag

