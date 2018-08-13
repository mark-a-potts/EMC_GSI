module statevec_efsoi
!$$$  module documentation block
!
! module: statevec_efsoi       read ensemble members, ensemble mean forecasts
!                              and verification. Assign and compute forecast 
!                              perturbations and forecast errors from 
!                              information read
!                              
! prgmmr: whitaker         org: esrl/psd               date: 2009-02-23
! prgmmr: groff            org: emc                    date: 2018-05-14
!
! abstract: io needed for efsoi calculations
!
! Public Subroutines:
!  init_statevec_efsoi: read anavinfo table for state vector
!  read_state_efsoi:    read ensemble members, ensemble mean forecasts and
!                       verification.  Assign and compute forecast perturbations
!                       and forecast errors from information read.
!  statevec_efsoi_cleanup: deallocate allocatable arrays.
!
! Public Variables:
!  nanals: (integer scalar) number of ensemble members (from module params)
!  nlevs: number of analysis vertical levels (from module params).
!  nbackgrounds:  number of time levels in background
!
!  nc3d: number of 3D control variables
!  nc2d: number of 2D control variables
!  cvars3d: names of 3D control variables
!  cvars2d: names of 2D control variables
!  ncdim: total number of 2D fields to update (nc3d*nlevs+nc2d)
!  index_pres: an index array with pressure value for given state variable
!   
! Modules Used: mpisetup, params, kinds, gridio, gridinfo_efsoi, mpeu_util, constants
!
! program history log:
!   2009-02-23  Initial version (as statevec).
!   2009-11-28  revamped to improve IO speed
!   2015-06-29  add multiple time levels to background
!   2016-05-02  shlyaeva: Modification for reading state vector from table
!   2016-09-07  shlyaeva: moved distribution of ens members to loadbal 
!   2016-11-29  shlyaeva: module renamed to controlvec (from statevec); gridinfo_efsoi
!               init and cleanup are called from here now
!   2018-05-14  Groff: Adapted from enkf controlvec.f90 to provide
!               corresponding io functionality necessary for efsoi calculations
!
! attributes:
!   language: f95
!
!$$$

use mpisetup
use gridio_efsoi,    only: readgriddata_efsoi, get_weight
use gridinfo_efsoi,  only: getgridinfo_efsoi, gridinfo_cleanup_efsoi,              &
                     npts, vars3d_supported, vars2d_supported, ncdim
use params,    only: nlevs, nbackgrounds, fgfileprefixes, reducedgrid, &
                     nanals, pseudo_rh, use_qsatensmean, nlons, nlats, &
                     evalft, andataname, ft
use kinds,     only: r_kind, i_kind, r_double, r_single
use mpeu_util, only: gettablesize, gettable, getindex
use constants, only: max_varname_length
implicit none

private

public :: read_state_efsoi, statevec_cleanup_efsoi, init_statevec_efsoi
real(r_single), public, allocatable, dimension(:,:,:) :: grdin, grdin2, grdin3
real(r_double), public, allocatable, dimension(:,:,:) :: qsat

integer(i_kind), public :: nc2d, nc3d
character(len=max_varname_length), allocatable, dimension(:), public :: cvars3d
character(len=max_varname_length), allocatable, dimension(:), public :: cvars2d
integer(i_kind), public, allocatable, dimension(:) :: index_pres
integer(i_kind), public, allocatable, dimension(:) :: clevels

contains

subroutine init_statevec_efsoi()
! read table with state vector variables for efsoi
! (code adapted from GSI state_vectors.f90 init_anasv routine
implicit none
character(len=*),parameter:: rcname='anavinfo'
character(len=*),parameter:: tbname='state_vector_efsoi::'
character(len=256),allocatable,dimension(:):: utable
character(len=20) var,source,funcof
integer(i_kind) luin,ii,i,ntot, k, nvars
integer(i_kind) ilev, itracer

! load file
luin=914
open(luin,file=rcname,form='formatted')

! Scan file for desired table first
! and get size of table
call gettablesize(tbname,luin,ntot,nvars)

! Get contents of table
allocate(utable(nvars))
call gettable(tbname,luin,ntot,nvars,utable)

! release file unit
close(luin)

! Retrieve each token of interest from table and define
! variables participating in control vector

! Count variables first
nc2d=0; nc3d=0; ncdim=0;
do ii=1,nvars
   read(utable(ii),*) var, ilev, itracer, source, funcof
   if(ilev==1) then
       nc2d=nc2d+1
       ncdim=ncdim+1
   else
       nc3d=nc3d+1
       ncdim=ncdim+ilev
   endif
enddo

allocate(cvars3d(nc3d),cvars2d(nc2d),clevels(0:nc3d))

! Now load information from table
nc2d=0;nc3d=0
clevels = 0
do ii=1,nvars
   read(utable(ii),*) var, ilev, itracer, source, funcof
   if(ilev==1) then
      nc2d=nc2d+1
      cvars2d(nc2d)=trim(adjustl(var))
   else if (ilev==nlevs .or. ilev==nlevs+1) then
      nc3d=nc3d+1
      cvars3d(nc3d) = trim(adjustl(var))
      clevels(nc3d) = ilev + clevels(nc3d-1)
   else 
      if (nproc .eq. 0) print *,'Error: only ', nlevs, ' and ', nlevs+1,' number of levels is supported in current version, got ',ilev
      call stop2(503)
   endif
enddo

deallocate(utable)

allocate(index_pres(ncdim))
ii=0
do i=1,nc3d
  do k=1,clevels(i)-clevels(i-1)
    ii = ii + 1
    index_pres(ii)=k
  end do
end do
do i = 1,nc2d
  ii = ii + 1
  index_pres(ii) = nlevs+1
enddo

! sanity checks
if (ncdim == 0) then
  if (nproc == 0) print *, 'Error: there are no variables to update.'
  call stop2(501)
endif

do i = 1, nc2d
  if (getindex(vars2d_supported, cvars2d(i))<0) then
    if (nproc .eq. 0) then
      print *,'Error: 2D variable ', cvars2d(i), ' is not supported in current version.'
      print *,'Supported variables: ', vars2d_supported
    endif
    call stop2(502)
  endif
enddo
do i = 1, nc3d
  if (getindex(vars3d_supported, cvars3d(i))<0) then
    if (nproc .eq. 0) then 
       print *,'Error: 3D variable ', cvars3d(i), ' is not supported in current version.'
       print *,'Supported variables: ', vars3d_supported
    endif
    call stop2(502)
  endif
enddo

if (nproc == 0) then 
  print *, '2D control variables: ', cvars2d
  print *, '3D control variables: ', cvars3d
  print *, 'Control levels: ', clevels
  print *, 'nc2d: ', nc2d, ', nc3d: ', nc3d, ', ncdim: ', ncdim
endif

call getgridinfo_efsoi(fgfileprefixes(1), reducedgrid)

! Get grid weights for EFSOI
! calculation and evaluation
call get_weight()

end subroutine init_statevec_efsoi

subroutine read_state_efsoi()
! read ensemble members on IO tasks
implicit none
real(r_double)  :: t1,t2
integer(i_kind) :: nanal,nb,nlev
integer(i_kind) :: q_ind
integer(i_kind) :: ierr

! must at least nanals tasks allocated.
if (numproc < nanals) then
  print *,'need at least nanals =',nanals,'MPI tasks, exiting ...'
  call mpi_barrier(mpi_comm_world,ierr)
  call mpi_finalize(ierr)
end if
if (npts < numproc) then
  print *,'cannot allocate more than npts =',npts,'MPI tasks, exiting ...'
  call mpi_barrier(mpi_comm_world,ierr)
  call mpi_finalize(ierr)
end if

! read in whole control vector on i/o procs - keep in memory
! (needed in write_ensemble)
if (nproc <= nanals-1) then
   allocate(grdin(npts,ncdim,nbackgrounds))
   allocate(grdin2(npts,ncdim,nbackgrounds))
   allocate(grdin3(npts,ncdim,nbackgrounds))
   allocate(qsat(npts,nlevs,nbackgrounds))
   nanal = nproc + 1
   t1 = mpi_wtime()
   ! Read ensemble member forecasts needed to obtain
   ! the forecast perturbations at evaluation forecast time (EFT)
   call readgriddata_efsoi(nanal,cvars3d,cvars2d,nc3d,nc2d,clevels,ncdim,nbackgrounds,1,grdin,ft,qsat=qsat)
   !print *,'min/max qsat',nanal,'=',minval(qsat),maxval(qsat)
   if (use_qsatensmean) then
       ! convert qsat to ensemble mean.
       do nb=1,nbackgrounds
       do nlev=1,nlevs
          call mpi_allreduce(mpi_in_place,qsat(1,nlev,nb),npts,mpi_real8,mpi_sum,mpi_comm_io,ierr)
       enddo
       enddo
       qsat = qsat/real(nanals)
       !print *,'min/max qsat ensmean',nanal,'=',minval(qsat),maxval(qsat)
   endif
   if (nproc == 0) then
     t2 = mpi_wtime()
     print *,'time in readgridata on root',t2-t1,'secs'
   end if
   !print *,'min/max ps ens mem',nanal,'=',&
   !         minval(grdin(:,ncdim,nbackgrounds/2+1)),maxval(grdin(:,ncdim,nbackgrounds/2+1))
   q_ind = getindex(cvars3d, 'q')
   if (pseudo_rh .and. q_ind > 0) then
      do nb=1,nbackgrounds
         ! create normalized humidity analysis variable.
         grdin(:,(q_ind-1)*nlevs+1:q_ind*nlevs,nb) = &
         grdin(:,(q_ind-1)*nlevs+1:q_ind*nlevs,nb)/qsat(:,:,nb)
      enddo
   end if

   ! ------------------------------------------
   ! Read the relevant ensemble mean quantities
   ! ------------------------------------------
   ! Ensemble mean forecast from analysis
   call readgriddata_efsoi(0,cvars3d,cvars2d,nc3d,nc2d,clevels,ncdim,nbackgrounds,0,grdin2,ft,qsat=qsat)
   ! Ensemble mean Forecast from first guess
   call readgriddata_efsoi(0,cvars3d,cvars2d,nc3d,nc2d,clevels,ncdim,nbackgrounds,0,grdin3,ft+6,qsat=qsat)
   ! Compute One half the sum of ensemble mean forecast quantities
   grdin3 = 0.5_r_kind * (grdin2 + grdin)
   ! Verification at evaluation time
   call readgriddata_efsoi(0,cvars3d,cvars2d,nc3d,nc2d,clevels,ncdim,nbackgrounds,1,grdin2,ft,infilename=andataname)
   ! Assign the sum of ensemble mean forecast errors at
   ! the evaluation time by subtracting
   ! verification from the forecast quantities
   grdin3 = (grdin3 - grdin2) / real(nanals-1,r_kind)
   ! Normalize for surface pressure
   grdin3(:,ncdim,nb) = grdin3(:,ncdim,nb) / grdin(:,ncdim,nb)
   ! Analysis at initial time
   call readgriddata_efsoi(0,cvars3d,cvars2d,nc3d,nc2d,clevels,ncdim,nbackgrounds,1,grdin2,0)

end if
   
end subroutine read_state_efsoi

subroutine statevec_cleanup_efsoi()
! deallocate module-level allocatable arrays.
if (allocated(cvars3d)) deallocate(cvars3d)
if (allocated(cvars2d)) deallocate(cvars2d)
if (allocated(clevels)) deallocate(clevels)
if (allocated(index_pres)) deallocate(index_pres)
if (nproc <= nanals-1 .and. allocated(grdin)) deallocate(grdin)
if (nproc <= nanals-1 .and. allocated(grdin2)) deallocate(grdin2)
if (nproc <= nanals-1 .and. allocated(grdin3)) deallocate(grdin3)
if (nproc <= nanals-1 .and. allocated(qsat)) deallocate(qsat)
call gridinfo_cleanup_efsoi()
end subroutine statevec_cleanup_efsoi

end module statevec_efsoi
