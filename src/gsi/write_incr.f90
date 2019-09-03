module write_incr
!$$$ module documentation block
!           .      .    .                                       .
! module:   write_incr 
!   prgmmr: Martin       org:                 date: 2019-09-04
!
! abstract: This module contains routines which write out  
!           the atmospheric increment rather than analysis
!
! program history log:
!   2019-09-04 Martin    Initial version.  Based on ncepnems_io
!
! Subroutines Included:
!   sub write_fv3_increment - writes netCDF increment for FV3 global model
!
!$$$ end documentation block

  implicit none
  private
  public write_fv3_increment

  interface write_fv3_increment
     module procedure write_fv3_inc_
  end interface

contains

  subroutine write_fv3_inc_ (grd,sp_a,filename,mype_out,gfs_bundle,ibin)

!$$$  subprogram documentation block
!                .      .    .
! subprogram:    write_fv3_increment
!
!   prgmmr: Martin            org:                 date: 2019-09-04
!
! abstract: This routine takes GSI analysis increments and writes
!           to a netCDF file on the analysis resolution for use by FV3-GFS
!
! program history log:
!   2019-09-04  martin  Initial version. Based on write_atm_nemsio 
!
!   input argument list:
!     filename  - file to open and write to
!     mype_out  - mpi task to write output file
!    gfs_bundle - bundle containing fields on subdomains
!     ibin      - time bin
!
!   output argument list:
!
! attributes:
!   language: f90
!   machines: ibm RS/6000 SP; SGI Origin 2000; Compaq HP
!
!$$$ end documentation block

! !USES:
    use netcdf
    use kinds, only: r_kind,i_kind

    use mpimod, only: mpi_rtype
    use mpimod, only: mpi_comm_world
    use mpimod, only: ierror
    use mpimod, only: mype

    implicit none

! !INPUT PARAMETERS:

    type(sub2grid_info), intent(in) :: grd
    type(spec_vars),     intent(in) :: sp_a
    character(len=24),   intent(in) :: filename  ! file to open and write to
    integer(i_kind),     intent(in) :: mype_out  ! mpi task to write output file
    type(gsi_bundle),    intent(in) :: gfs_bundle
    integer(i_kind),     intent(in) :: ibin      ! time bin

!-------------------------------------------------------------------------

    character(len=120) :: my_name = 'WRITE_FV3INCR'

    real(r_kind),pointer,dimension(:,:) :: sub_ps
    real(r_kind),pointer,dimension(:,:,:) :: sub_u,sub_v,sub_tv
    real(r_kind),pointer,dimension(:,:,:) :: sub_q,sub_oz,sub_cwmr

    real(r_kind),dimension(grd%lat2,grd%lon2,grd%nsig) :: sub_dzb,sub_dza
    real(r_kind),dimension(grd%lat2,grd%lon2,grd%nsig) :: sub_prsl
    real(r_kind),dimension(grd%lat2,grd%lon2,grd%nsig+1) :: sub_prsi
    real(r_kind),dimension(grd%lat2,grd%lon2,grd%nsig+1,ibin) :: ges_geopi

    real(r_kind),dimension(grd%lat1*grd%lon1)     :: psm
    real(r_kind),dimension(grd%lat2,grd%lon2,grd%nsig):: sub_dp
    real(r_kind),dimension(grd%lat1*grd%lon1,grd%nsig):: tvsm,prslm, usm, vsm
    real(r_kind),dimension(grd%lat1*grd%lon1,grd%nsig):: dpsm, qsm, ozsm
    real(r_kind),dimension(grd%lat1*grd%lon1,grd%nsig):: cwsm, dzsm
    real(r_kind),dimension(max(grd%iglobal,grd%itotsub)) :: work1,work2
    real(r_kind),dimension(grd%nlon,grd%nlat-2):: grid

    integer(i_kind) :: mm1, k
    integer(i_kind) :: iret, istatus 
    integer(i_kind) :: ncid_out, lon_dimid, lat_dimid, lev_dimid, ilev_dimid
    integer(i_kind) :: o3varid
    integer(i_kind) :: dimids3(3),nccount(3),ncstart(3)

!*************************************************************************
!   Initialize local variables
    mm1=mype+1
    nlatm2=grd%nlat-2

    istatus=0
    call gsi_bundlegetpointer(gfs_bundle,'ps', sub_ps,  iret); istatus=istatus+iret
    call gsi_bundlegetpointer(gfs_bundle,'u',  sub_u,   iret); istatus=istatus+iret
    call gsi_bundlegetpointer(gfs_bundle,'v',  sub_v,   iret); istatus=istatus+iret
    call gsi_bundlegetpointer(gfs_bundle,'tv', sub_tv,  iret); istatus=istatus+iret
    call gsi_bundlegetpointer(gfs_bundle,'q',  sub_q,   iret); istatus=istatus+iret
    call gsi_bundlegetpointer(gfs_bundle,'oz', sub_oz,  iret); istatus=istatus+iret
    call gsi_bundlegetpointer(gfs_bundle,'cw', sub_cwmr,iret); istatus=istatus+iret
    if ( istatus /= 0 ) then
       if ( mype == 0 ) then
         write(6,*) 'write_fv3_incr_: ERROR'
         write(6,*) 'Missing some of the required fields'
         write(6,*) 'Aborting ... '
      endif
      call stop2(999)
    end if
    
    ! Single task writes increment to file
    if ( mype == mype_out ) then
      ! create the output netCDF file
      call nccheck_incr(nf90_create(trim(filename), nf90_clobber, ncid_out))
      ! create dimensions based on analysis resolution, not guess
      call nccheck_incr(nf90_def_dim(ncid_out, "lon", grd%nlon, lon_dimid))
      call nccheck_incr(nf90_def_dim(ncid_out, "lat", grd%nlat, lat_dimid))
      call nccheck_incr(nf90_def_dim(ncid_out, "lev", grd%nsig, lev_dimid))
      call nccheck_incr(nf90_def_dim(ncid_out, "ilev", grd%nsig+1, ilev_dimid))
      ! place global attributes to parallel calc_increment output
      call nccheck_incr(nf90_put_attr(ncid_out, nf90_global, "source", "GSI"))
      call nccheck_incr(nf90_put_attr(ncid_out, nf90_global, "comment", &
                                      "global analysis increment from write_fv3_increment"))
      dimids3 = (/ lon_dimid, lat_dimid, lev_dimid /)
      ! create variables
      call nccheck_incr(nf90_def_var(ncid_out, "o3mr_inc", nf90_real, dimids3, o3varid)) 
      call nccheck_incr(nf90_enddef(ncid_out))
    end if

    ! Strip off boundary points from subdomains
    call strip(sub_ps  ,psm)
    call strip(sub_tv  ,tvsm  ,grd%nsig)
    call strip(sub_q   ,qsm   ,grd%nsig)
    call strip(sub_oz  ,ozsm  ,grd%nsig)
    call strip(sub_cwmr,cwsm  ,grd%nsig)
    call strip(sub_dp  ,dpsm  ,grd%nsig)
    call strip(sub_prsl,prslm ,grd%nsig)
    call strip(sub_u   ,usm   ,grd%nsig)
    call strip(sub_v   ,vsm   ,grd%nsig)
    if (lupp) call strip(sub_dza ,dzsm  ,grd%nsig)

    nccount = (/ grd%nlon, grd%nlat, 1 /)
    ! ozone increment
    ncstart = (/ 1, 1, grd%nsig /)
    do k=1,grd%nsig
       call mpi_gatherv(ozsm(1,k),grd%ijn(mm1),mpi_rtype,&
            work1,grd%ijn,grd%displs_g,mpi_rtype,&
            mype_out,mpi_comm_world,ierror)
       if (mype == mype_out) then
          call load_grid(work1,grid)
          ! write to file
          call nccheck_incr(nf90_put_var(ncid_out, o3varid, grid, &
                            start = ncstart, count = nccount))
       endif
       ncstart(3) = grd%nsig-k
    end do

   ! cleanup and exit
   if ( mype == mype_out ) then
      call nccheck_incr(nf90_close(ncid_out))
      write(6,*) "FV3 netCDF increment written, file=",filename


  end subroutine write_fv3_inc_

  subroutine nccheck_incr(status)
    use netcdf
    integer, intent (in   ) :: status
    if (status /= nf90_noerr) then
      print *, "fv3_increment netCDF error", trim(nf90_strerror(status))
      stop2(999)
    end if
  end subroutine nccheck_incr

end module write_incr