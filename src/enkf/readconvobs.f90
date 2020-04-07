module readconvobs
!$$$  module documentation block
!
! module: readconvobs                  read data from diag_conv* files
!
! prgmmr: whitaker         org: esrl/psd               date: 2009-02-23
!
! abstract: read data from diag_conv* files (containing prepbufr data) written
! out
!  by GSI forward operator code.
!
! Public Subroutines:
!  get_num_convobs: determine the number of observations to read.
!  get_convobs_data: read the data and calculate H(x) for ensemble members.
!  write_convobs_data: output diag file with spread
!
! Public Variables: None
!
! program history log:
!   2009-02-23  Initial version.
!   2016-11-29  shlyaeva - updated read routine to calculate linearized H(x)
!                          added write_convobs_data to output ensemble spread
!   2017-05-12  Y. Wang and X. Wang - add to read dbz and rw for radar
!                       reflectivity and radial velocity assimilation. POC: xuguang.wang@ou.edu
!   2017-12-13  shlyaeva - added netcdf diag read/write capability
!
! attributes:
!   language: f95
!
!$$$

use kinds, only: r_kind,i_kind,r_single,r_double
use constants, only: one,zero,deg2rad
implicit none

private
public :: get_num_convobs, get_convobs_data, write_convobs_data


!> observation types to read from netcdf files
integer(i_kind), parameter :: nobtype = 11
character(len=3), dimension(nobtype), parameter :: obtypes = (/'  t', '  q', ' ps', ' uv', 'tcp', &
                                                               'gps', 'spd', ' pw', ' dw', ' rw', 'dbz' /)

contains

! get number of conventional observations from netcdf file
subroutine get_num_convobs(obspath,datestring,num_obs_tot,num_obs_totdiag,id)
  use nc_diag_read_mod, only: nc_diag_read_get_var
  use nc_diag_read_mod, only: nc_diag_read_get_dim
  use nc_diag_read_mod, only: nc_diag_read_init, nc_diag_read_close
  implicit none

  character(len=500), intent(in)  :: obspath
  character(len=10),  intent(in)  :: datestring
  character(len=10),  intent(in)  :: id
  integer(i_kind),    intent(out) :: num_obs_tot, num_obs_totdiag

  character(len=500) :: obsfile
  character(len=3) :: obtype
  integer(i_kind) :: iunit, itype, i, nobs_curr
  integer(i_kind),dimension(nobtype,2) :: nobs
  real(r_kind) :: errorlimit,errorlimit2,error,pres,obmax
  real(r_kind) :: errorlimit2_obs,errorlimit2_bnd
  logical :: fexist

  real(r_single), allocatable, dimension (:) :: Pressure
  real(r_single), allocatable, dimension (:) :: Analysis_Use_Flag
  real(r_single), allocatable, dimension (:) :: Errinv_Final, GPS_Type
  real(r_single), allocatable, dimension (:) :: Observation, v_Observation
  real(r_single), allocatable, dimension (:) :: Forecast_Saturation_Spec_Hum

    ! If ob error > errorlimit or < errorlimit2, skip it.
    errorlimit = 1._r_kind/sqrt(1.e9_r_kind)
    errorlimit2_obs = 1._r_kind/sqrt(1.e-6_r_kind)
    errorlimit2_bnd = 1.e3_r_kind*errorlimit2_obs
    num_obs_tot = 0
    num_obs_totdiag = 0
    nobs = 0

    obtypeloop: do itype=1, nobtype

     obtype = obtypes(itype)
        ! read diag file (concatenated pe* files)
        obsfile = trim(adjustl(obspath))//"diag_conv_"//trim(adjustl(obtype))//"_ges."//datestring//'_'//trim(adjustl(id))//'.nc4'
        inquire(file=obsfile,exist=fexist)
        if (.not. fexist .or. datestring .eq. '0000000000') &
           obsfile = trim(adjustl(obspath))//"diag_conv_"//trim(adjustl(obtype))//"_ges."//trim(adjustl(id))//'.nc4'
        inquire(file=obsfile,exist=fexist)
        if (.not. fexist) cycle

        call nc_diag_read_init(obsfile, iunit)

        nobs_curr = nc_diag_read_get_dim(iunit,'nobs')

        if (nobs_curr <= 0) then
           call nc_diag_read_close(obsfile)
           cycle
        endif

        allocate(Pressure(nobs_curr), Analysis_Use_Flag(nobs_curr),     &
                 Errinv_Final(nobs_curr), Observation(nobs_curr))
        call nc_diag_read_get_var(iunit, 'Pressure', Pressure)
        call nc_diag_read_get_var(iunit, 'Analysis_Use_Flag', Analysis_Use_Flag)
        call nc_diag_read_get_var(iunit, 'Errinv_Final', Errinv_Final)

        if (obtype == ' uv') then
           call nc_diag_read_get_var(iunit, 'u_Observation', Observation)
           allocate(v_Observation(nobs_curr))
           call nc_diag_read_get_var(iunit, 'v_Observation', v_Observation)
        else
           call nc_diag_read_get_var(iunit, 'Observation', Observation)
        endif
        if (obtype == 'gps') then
           allocate(GPS_Type(nobs_curr))
           call nc_diag_read_get_var(iunit, 'GPS_Type', GPS_Type)
        endif
        if (obtype == '  q') then
           allocate(Forecast_Saturation_Spec_Hum(nobs_curr))
           call nc_diag_read_get_var(iunit, 'Forecast_Saturation_Spec_Hum', Forecast_Saturation_Spec_Hum)
        endif

        call nc_diag_read_close(obsfile)


        num_obs_totdiag = num_obs_totdiag + nobs_curr
        do i = 1, nobs_curr

           errorlimit2=errorlimit2_obs

           if (obtype == 'gps' .and. GPS_Type(i)==1) errorlimit2=errorlimit2_bnd

           ! for q, normalize by qsatges
           if (obtype == '  q') then
              obmax     = abs(Observation(i) / Forecast_Saturation_Spec_Hum(i))
              error     = Errinv_Final(i) * Forecast_Saturation_Spec_Hum(i)
           else
              obmax     = abs(Observation(i))
              error     = Errinv_Final(i)
           endif
           if (obtype == ' uv') then
              obmax = max(abs(Observation(i)), abs(v_Observation(i)))
           endif
           if (obtype == ' ps' .or. obtype == 'tcp') then
              pres = Observation(i)
           else
              pres = Pressure(i)
           endif
           if (Analysis_Use_Flag(i) < zero) cycle


           nobs(itype,1) = nobs(itype,1) + 1
           if (obtype == ' uv') then
              nobs(itype,1) = nobs(itype,1) + 1
           endif
           if (error < errorlimit .or. error > errorlimit2 .or.  &
               abs(obmax) > 1.e9_r_kind) cycle
           ! skipping sst obs since ENKF does not how how to handle them yet.
           nobs(itype,2) = nobs(itype,2) + 1
           if (obtype == ' uv') then
              nobs(itype,2) = nobs(itype,2) + 1
           endif
           if (obtype == 'sst') cycle

           num_obs_tot = num_obs_tot + 1
           if (obtype == ' uv') then
             num_obs_tot = num_obs_tot + 1
           endif
        end do

        deallocate(Pressure, Analysis_Use_Flag, Errinv_Final, Observation)

        if (obtype == ' uv') then
           deallocate(v_Observation)
        endif
        if (obtype == 'gps') then
           deallocate(GPS_Type)
        endif
        if (obtype == '  q') then
           deallocate(Forecast_Saturation_Spec_Hum)
        endif

  enddo obtypeloop

  print *,num_obs_tot,' obs in diag_conv_ges file, ', num_obs_totdiag, ' total obs in diag_conv_ges file'
  write(6,*)'columns below obtype,nread, nkeep'
  do i = 1, nobtype
     write(6,100) obtypes(i), nobs(i,1), nobs(i,2)
  enddo
100       format(2x,a3,2x,i9,2x,i9)


end subroutine get_num_convobs

! read conventional observations from netcdf file
subroutine get_convobs_data(obspath, datestring, nobs_max, nobs_maxdiag,   &
                            hx_mean, hx, hx_modens, x_obs, x_err,       &
                            x_lon, x_lat, x_press, x_time, x_code,         &
                            x_errorig, x_type, x_used, id, nanal, nmem)
  use sparsearr, only: sparr, sparr2, new, delete, assignment(=), init_raggedarr, raggedarr
  use params, only: nanals, neigv, vlocal_evecs
  use statevec, only: state_d
  use mpisetup, only: nproc, mpi_wtime
  use observer_enkf, only: calc_linhx,calc_linhx_modens,setup_linhx
  use nc_diag_read_mod, only: nc_diag_read_get_var
  use nc_diag_read_mod, only: nc_diag_read_get_dim, nc_diag_read_get_global_attr
  use nc_diag_read_mod, only: nc_diag_read_init, nc_diag_read_close

  implicit none

  character*500,   intent(in) :: obspath
  character*10,    intent(in) :: datestring
  integer(i_kind), intent(in) :: nobs_max, nobs_maxdiag

  real(r_single), dimension(nobs_max), intent(out)    :: hx_mean
  real(r_single), dimension(nobs_max), intent(out)    :: hx
  ! hx_modens holds modulated ensemble in ob space (zero size and not referenced if neigv=0)
  real(r_single), dimension(neigv,nobs_max), intent(out) :: hx_modens

  real(r_single), dimension(nobs_max), intent(out)    :: x_obs
  real(r_single), dimension(nobs_max), intent(out)    :: x_err, x_errorig
  real(r_single), dimension(nobs_max), intent(out)    :: x_lon, x_lat
  real(r_single), dimension(nobs_max), intent(out)    :: x_press, x_time
  integer(i_kind), dimension(nobs_max), intent(out)   :: x_code
  character(len=20), dimension(nobs_max), intent(out) :: x_type
  integer(i_kind), dimension(nobs_maxdiag), intent(out) :: x_used

  character(len=10), intent(in) :: id
  integer, intent(in)           :: nanal, nmem

  real(r_double) t1,t2,tsum
  character*500 obsfile, obsfile2

  type(sparr2)    :: dhx_dx_read
  type(sparr)     :: dhx_dx
  type(raggedarr) :: hxpert

  character(len=3) :: obtype

  integer(i_kind) :: iunit, iunit2, itype
  integer(i_kind) :: nobs, nobdiag, i, nob, nnz, nind
  real(r_kind) :: errorlimit,errorlimit2,error,errororig
  real(r_kind) :: obmax, pres
  real(r_kind) :: errorlimit2_obs,errorlimit2_bnd
  logical fexist
  real(r_single), allocatable, dimension (:) :: Latitude, Longitude, Pressure, Time
  integer(i_kind), allocatable, dimension (:) :: Observation_Type
  real(r_single), allocatable, dimension (:) :: Errinv_Input, Errinv_Final, Analysis_Use_Flag, GPS_Type
  real(r_single), allocatable, dimension (:) :: Observation, v_Observation
  real(r_single), allocatable, dimension (:) :: Obs_Minus_Forecast_adjusted, v_Obs_Minus_Forecast_adjusted
  real(r_single), allocatable, dimension (:) :: Obs_Minus_Forecast_unadjusted, v_Obs_Minus_Forecast_unadjusted
  real(r_single), allocatable, dimension (:) :: Forecast_Saturation_Spec_Hum
  integer(i_kind), allocatable, dimension (:,:) :: Observation_Operator_Jacobian_stind, v_Observation_Operator_Jacobian_stind
  integer(i_kind), allocatable, dimension (:,:) :: Observation_Operator_Jacobian_endind, v_Observation_Operator_Jacobian_endind
  real(r_single), allocatable, dimension (:,:) :: Observation_Operator_Jacobian_val, v_Observation_Operator_Jacobian_val

  integer(i_kind) :: ix, iy, it, ixp, iyp, itp, nprof
  real(r_kind) :: delx, dely, delxp, delyp, delt, deltp
  real(r_single) :: rlat,rlon,rtim,rlat_prev,rlon_prev,rtim_prev,eps
! Error limit is made consistent with screenobs routine
  errorlimit = 1._r_kind/sqrt(1.e9_r_kind)
  errorlimit2_obs = 1._r_kind/sqrt(1.e-6_r_kind)
  errorlimit2_bnd = 1.e3_r_kind*errorlimit2_obs
  eps = 1.e-3

  tsum = 0

  nob  = 0
  rlat_prev = -1.e30; rlon_prev=-1.e30; rtim_prev = -1.e30
  nobdiag = 0
  x_used = 0
  nprof = 0

  hx = zero

  obtypeloop: do itype=1, nobtype

     obtype = obtypes(itype)
        ! read diag file (concatenated pe* files)
        obsfile = trim(adjustl(obspath))//"diag_conv_"//trim(adjustl(obtype))//"_ges."//datestring//'_'//trim(adjustl(id))//'.nc4'
        inquire(file=obsfile,exist=fexist)
        if (.not. fexist .or. datestring .eq. '0000000000') &
           obsfile = trim(adjustl(obspath))//"diag_conv_"//trim(adjustl(obtype))//"_ges."//trim(adjustl(id))//'.nc4'

        inquire(file=obsfile,exist=fexist)
        if (.not. fexist) cycle

        call nc_diag_read_init(obsfile, iunit)

        nobs = nc_diag_read_get_dim(iunit,'nobs')

        if (nobs <= 0) then
           call nc_diag_read_close(obsfile)
           cycle
        endif

        allocate(Latitude(nobs), Longitude(nobs), Pressure(nobs), Time(nobs), &
                 Analysis_Use_Flag(nobs), Errinv_Input(nobs), Errinv_Final(nobs), &
                 Observation_Type(nobs), Observation(nobs), &
                 Obs_Minus_Forecast_adjusted(nobs), Obs_Minus_Forecast_unadjusted(nobs))
        call nc_diag_read_get_var(iunit, 'Latitude', Latitude)
        call nc_diag_read_get_var(iunit, 'Longitude', Longitude)
        call nc_diag_read_get_var(iunit, 'Pressure', Pressure)
        call nc_diag_read_get_var(iunit, 'Time', Time)
        call nc_diag_read_get_var(iunit, 'Analysis_Use_Flag', Analysis_Use_Flag)
        call nc_diag_read_get_var(iunit, 'Errinv_Input', Errinv_Input)
        call nc_diag_read_get_var(iunit, 'Errinv_Final', Errinv_Final)
        call nc_diag_read_get_var(iunit, 'Observation_Type', Observation_Type)

        if (obtype == ' uv') then
           call nc_diag_read_get_var(iunit, 'u_Observation', Observation)
           call nc_diag_read_get_var(iunit, 'u_Obs_Minus_Forecast_adjusted', Obs_Minus_Forecast_adjusted)
           call nc_diag_read_get_var(iunit, 'u_Obs_Minus_Forecast_unadjusted', Obs_Minus_Forecast_unadjusted)
           allocate(v_Observation(nobs), v_Obs_Minus_Forecast_adjusted(nobs), &
                    v_Obs_Minus_Forecast_unadjusted(nobs))
           call nc_diag_read_get_var(iunit, 'v_Observation', v_Observation)
           call nc_diag_read_get_var(iunit, 'v_Obs_Minus_Forecast_adjusted', v_Obs_Minus_Forecast_adjusted)
           call nc_diag_read_get_var(iunit, 'v_Obs_Minus_Forecast_unadjusted', v_Obs_Minus_Forecast_unadjusted)
        else
           call nc_diag_read_get_var(iunit, 'Observation', Observation)
           call nc_diag_read_get_var(iunit, 'Obs_Minus_Forecast_adjusted', Obs_Minus_Forecast_adjusted)
           call nc_diag_read_get_var(iunit, 'Obs_Minus_Forecast_unadjusted', Obs_Minus_Forecast_unadjusted)
        endif
        if (obtype == 'gps') then
           allocate(GPS_Type(nobs))
           call nc_diag_read_get_var(iunit, 'GPS_Type', GPS_Type)
        endif
        if (obtype == '  q') then
           allocate(Forecast_Saturation_Spec_Hum(nobs))
           call nc_diag_read_get_var(iunit, 'Forecast_Saturation_Spec_Hum', Forecast_Saturation_Spec_Hum)
        endif

        call nc_diag_read_get_global_attr(iunit, "jac_nnz", nnz)
        call nc_diag_read_get_global_attr(iunit, "jac_nind", nind)
        allocate(Observation_Operator_Jacobian_stind(nind, nobs))
        allocate(Observation_Operator_Jacobian_endind(nind, nobs))
        allocate(Observation_Operator_Jacobian_val(nnz, nobs))
        if (obtype == ' uv') then
          allocate(v_Observation_Operator_Jacobian_stind(nind, nobs))
          allocate(v_Observation_Operator_Jacobian_endind(nind, nobs))
          allocate(v_Observation_Operator_Jacobian_val(nnz, nobs))
          call nc_diag_read_get_var(iunit, 'u_Observation_Operator_Jacobian_stind', Observation_Operator_Jacobian_stind)
          call nc_diag_read_get_var(iunit, 'u_Observation_Operator_Jacobian_endind', Observation_Operator_Jacobian_endind)
          call nc_diag_read_get_var(iunit, 'u_Observation_Operator_Jacobian_val', Observation_Operator_Jacobian_val)
          call nc_diag_read_get_var(iunit, 'v_Observation_Operator_Jacobian_stind', v_Observation_Operator_Jacobian_stind)
          call nc_diag_read_get_var(iunit, 'v_Observation_Operator_Jacobian_endind', v_Observation_Operator_Jacobian_endind)
          call nc_diag_read_get_var(iunit, 'v_Observation_Operator_Jacobian_val',v_Observation_Operator_Jacobian_val)
        else
          call nc_diag_read_get_var(iunit, 'Observation_Operator_Jacobian_stind', Observation_Operator_Jacobian_stind)
          call nc_diag_read_get_var(iunit, 'Observation_Operator_Jacobian_endind', Observation_Operator_Jacobian_endind)
          call nc_diag_read_get_var(iunit, 'Observation_Operator_Jacobian_val', Observation_Operator_Jacobian_val)
        endif


        call nc_diag_read_close(obsfile)

        errorlimit2=errorlimit2_obs

        do i = 1, nobs
           nobdiag = nobdiag + 1
           ! special handling for error limits for GPS bend angle
           if (obtype == 'gps' .and. GPS_Type(i)==1) errorlimit2=errorlimit2_bnd

           ! for q, normalize by qsatges
           if (obtype == '  q') then
              obmax     = abs(real(Observation(i),r_single) / real(Forecast_Saturation_Spec_Hum(i),r_single))
              errororig = real(Errinv_Input(i),r_single) * real(Forecast_Saturation_Spec_Hum(i),r_single)
              error     = real(Errinv_Final(i),r_single) * real(Forecast_Saturation_Spec_Hum(i),r_single)
           else
              obmax     = abs(Observation(i))
              errororig = Errinv_Input(i)
              error     = Errinv_Final(i)
           endif
           if (obtype == ' uv') then
              obmax = max(abs(Observation(i)), abs(v_Observation(i)))
           endif
           if (obtype == ' ps' .or. obtype == 'tcp') then
              pres = Observation(i)
           else
              pres = Pressure(i)
           endif
           if (Analysis_Use_Flag(i) < zero .or.                  &
               error < errorlimit .or. error > errorlimit2 .or.  &
               abs(obmax) > 1.e9_r_kind) cycle
           ! skipping sst obs since ENKF does not how how to handle them yet.
           if (obtype == 'sst') cycle

           x_used(nobdiag) = 1
           nob = nob + 1
           x_code(nob)  = Observation_Type(i)

           ! observation location and time
           x_lat(nob)   = Latitude(i)
           x_lon(nob)   = Longitude(i)
           x_press(nob) = pres
           x_time(nob)  = Time(i)

           ! observation errors
           if (errororig > 1.e-5_r_kind) then
              x_errorig(nob) = (one/errororig)**2
           else
              x_errorig(nob) = 1.e10_r_kind
           endif
           x_err(nob)   = (one/error)**2
           ! special handling of gps error
           if (obtype == 'gps' .and. x_errorig(nob) .gt. 1.e9) x_errorig(nob)=x_err(nob)

           ! observation
           x_obs(nob)   = Observation(i)

           ! hx and hxnobc
           hx_mean(nob) = Observation(i) - Obs_Minus_Forecast_adjusted(i)
           !hx_mean_nobc(nob) = Observation(i) - Obs_Minus_Forecast_unadjusted(i)
          ! whether that's reasonable
           if (obtype == '  q' .or. obtype == 'spd' .or. obtype == ' dw' .or. &
               obtype == ' pw') then
              !hx_mean_nobc(nob) = hx_mean(nob)
           endif

           ! observation type
           x_type(nob)  = obtype
           if (x_type(nob) == ' uv')  x_type(nob) = '  u'
           if (x_type(nob) == 'tcp')  x_type(nob) = ' ps'
           if (x_type(nob) == ' rw')  x_type(nob) = ' rw'
           if (x_type(nob) == 'dbz')  x_type(nob) = 'dbz'

           ! get Hx
           if (nanal <= nanals) then
              ! read the linearized Hx
              call new(dhx_dx_read, nnz, nind)
              dhx_dx_read%st_ind = Observation_Operator_Jacobian_stind(:,i)
              dhx_dx_read%end_ind = Observation_Operator_Jacobian_endind(:,i)
              dhx_dx_read%val = Observation_Operator_Jacobian_val(:,i)
              dhx_dx = dhx_dx_read
              t1 = mpi_wtime()
              rlat = x_lat(nob)*deg2rad
              rlon = x_lon(nob)*deg2rad
              rtim = x_time(nob)
              if (nob > 1) then
                 rlat_prev = x_lat(nob-1)*deg2rad
                 rlon_prev = x_lon(nob-1)*deg2rad
                 rtim_prev = x_time(nob-1)
              endif
              if (abs(rlat-rlat_prev) > eps .or. &
                 abs(rlon-rlon_prev) > eps .or. &
                 abs(rtim-rtim_prev) > eps) then
                 call setup_linhx(rlat,rlon,rtim,              &
                               ix, delx, ixp, delxp, iy, dely,  &
                               iyp, delyp, it, delt, itp, deltp)
              else
                 nprof = nprof + 1
              endif
              call init_raggedarr(hxpert, dhx_dx%nnz)
              call calc_linhx(hx_mean(nob), state_d(:,:,:,nmem),&
                              dhx_dx, hxpert, hx(nob),          &
                              ix, delx, ixp, delxp, iy, dely,   &
                              iyp, delyp, it, delt, itp, deltp)
              ! compute modulated ensemble in obs space
              if (neigv>0) call calc_linhx_modens(hx_mean(nob),dhx_dx,hxpert,hx_modens(:,nob),vlocal_evecs)

              t2 = mpi_wtime()
              tsum = tsum + t2-t1

              call delete(dhx_dx)
              call delete(dhx_dx_read)

              ! normalize q by qsatges
              if (obtype == '  q') then
                 hx(nob) = hx(nob) / Forecast_Saturation_Spec_Hum(i)
              endif
           endif

           ! normalize q by qsatges
           if (obtype == '  q') then
              x_obs(nob)   = x_obs(nob) /Forecast_Saturation_Spec_Hum(i)
              hx_mean(nob)     = hx_mean(nob) /Forecast_Saturation_Spec_Hum(i)
              !hx_mean_nobc(nob) = hx_mean_nobc(nob) /Forecast_Saturation_Spec_Hum(i)
           endif

           ! for wind, also read v-component
           if (obtype == ' uv') then
              nob = nob + 1
              x_code(nob)  = Observation_Type(i)

              ! observation location and time
              x_lat(nob)   = Latitude(i)
              x_lon(nob)   = Longitude(i)
              x_press(nob) = pres
              x_time(nob)  = Time(i)

              ! observation errors
              if (errororig > 1.e-5_r_kind) then
                 x_errorig(nob) = (one/errororig)**2
              else
                 x_errorig(nob) = 1.e10_r_kind
              endif
              x_err(nob)   = (one/error)**2

              ! observation
              x_obs(nob)   = v_Observation(i)

              ! hx and hxnobc
              hx_mean(nob)     = v_Observation(i) - v_Obs_Minus_Forecast_adjusted(i)
              !hx_mean_nobc(nob) = v_Observation(i) - v_Obs_Minus_Forecast_unadjusted(i)

              ! observation type
              x_type(nob)  = '  v'

              ! run linearized hx
              if (nanal <= nanals) then
                 ! read linearized Hx
                 t1 = mpi_wtime()
                 call new(dhx_dx_read, nnz, nind)
                 dhx_dx_read%st_ind = v_Observation_Operator_Jacobian_stind(:,i)
                 dhx_dx_read%end_ind = v_Observation_Operator_Jacobian_endind(:,i)
                 dhx_dx_read%val = v_Observation_Operator_Jacobian_val(:,i)
                 dhx_dx = dhx_dx_read
                 ! don't need this since we know ob location is the same?
                 rlat = x_lat(nob)*deg2rad
                 rlon = x_lon(nob)*deg2rad
                 rtim = x_time(nob)
                 if (nob > 1) then
                    rlat_prev = x_lat(nob-1)*deg2rad
                    rlon_prev = x_lon(nob-1)*deg2rad
                    rtim_prev = x_time(nob-1)
                 endif
                 if (abs(rlat-rlat_prev) > eps .or. &
                    abs(rlon-rlon_prev) > eps .or. &
                    abs(rtim-rtim_prev) > eps) then
                    call setup_linhx(rlat,rlon,rtim,              &
                                  ix, delx, ixp, delxp, iy, dely,  &
                                  iyp, delyp, it, delt, itp, deltp)
                 endif
                 call init_raggedarr(hxpert, dhx_dx%nnz)
                 call calc_linhx(hx_mean(nob), state_d(:,:,:,nmem),    &
                                 dhx_dx, hxpert, hx(nob),              &
                                 ix, delx, ixp, delxp, iy, dely,   &
                                 iyp, delyp, it, delt, itp, deltp)
                 ! compute modulated ensemble in obs space
                 if (neigv>0) call calc_linhx_modens(hx_mean(nob),dhx_dx,hxpert,hx_modens(:,nob),vlocal_evecs)
                 t2 = mpi_wtime()
                 tsum = tsum + t2-t1
                 call delete(dhx_dx)
                 call delete(dhx_dx_read)
              endif
           endif
        enddo

        deallocate(Latitude, Longitude, Pressure, Time, Analysis_Use_Flag,  &
                   Errinv_Input, Errinv_Final, Observation_Type, &
                   Observation, Obs_Minus_Forecast_adjusted, Obs_Minus_Forecast_unadjusted)

        if (obtype == ' uv') then
           deallocate(v_Observation, v_Obs_Minus_Forecast_adjusted, &
                      v_Obs_Minus_Forecast_unadjusted)
        endif

        if (obtype == 'gps') then
           deallocate(GPS_Type)
        endif

        if (obtype == '  q') then
           deallocate(Forecast_Saturation_Spec_Hum)
        endif

        deallocate(Observation_Operator_Jacobian_stind)
        deallocate(Observation_Operator_Jacobian_endind)
        deallocate(Observation_Operator_Jacobian_val)
        if (obtype == ' uv') then
           deallocate(v_Observation_Operator_Jacobian_stind)
           deallocate(v_Observation_Operator_Jacobian_endind)
           deallocate(v_Observation_Operator_Jacobian_val)
        endif

  enddo obtypeloop

  if (nanal == nanals) then
     print *,'conv ob profiles, total obs',nprof,nob
     print *,'time in calc_linhx for conv obs on proc',nproc,' =',tsum
  endif 
  if (nob .ne. nobs_max) then
      print *,'nc: number of obs not what expected in get_convobs_data',nob,nobs_max
      call stop2(94)
  end if
  if (nobdiag /= nobs_maxdiag) then
      print *,'number of total obs in diag not what expected in get_convobs_data',nobdiag, nobs_maxdiag
      call stop2(94)
  endif

end subroutine get_convobs_data

! writing spread diagnostics to netcdf file
subroutine write_convobs_data(obspath, datestring, nobs_max, nobs_maxdiag, &
                                 x_fit, x_sprd, x_used, id, gesid)
  use netcdf, only: nf90_inq_dimid, nf90_open, nf90_close, NF90_NETCDF4, &
                    nf90_inquire_dimension, NF90_WRITE, nf90_create, nf90_def_dim
  use ncdw_climsg, only: nclayer_check

  use constants, only: r_missing
  implicit none

  character*500, intent(in) :: obspath
  character*10, intent(in) :: datestring

  integer(i_kind), intent(in) :: nobs_max, nobs_maxdiag

  real(r_single), dimension(nobs_max), intent(in)      :: x_fit, x_sprd
  integer(i_kind), dimension(nobs_maxdiag), intent(in) :: x_used

  character(len=10), intent(in) :: id, gesid

  character*500 obsfile, obsfile2

  character(len=3) :: obtype
  integer(i_kind) :: iunit, nobsid
  integer(i_kind) :: nob, nobdiag, nobs, i, itype
  integer(i_kind), dimension(:), allocatable :: enkf_use_flag, enkf_use_flag_v
  real(r_single),  dimension(:), allocatable :: enkf_fit, enkf_fit_v
  real(r_single),  dimension(:), allocatable :: enkf_sprd, enkf_sprd_v
  logical :: fexist

  nob  = 0
  nobdiag = 0


  obtypeloop: do itype=1, nobtype

     obtype = obtypes(itype)
        ! read diag file (concatenated pe* files)
        obsfile = trim(adjustl(obspath))//"diag_conv_"//trim(adjustl(obtype))//"_ges."//datestring//'_'//trim(adjustl(id))//'.nc4'
        obsfile2 = trim(adjustl(obspath))//"diag_conv_"//trim(adjustl(obtype))//"_ges."//datestring//'_'//trim(adjustl(id))//'_spread.nc4'
        inquire(file=obsfile,exist=fexist)
        if (.not. fexist .or. datestring .eq. '0000000000') &
           obsfile = trim(adjustl(obspath))//"diag_conv_"//trim(adjustl(obtype))//"_ges."//trim(adjustl(id))//'.nc4'
        obsfile2 = trim(adjustl(obspath))//"diag_conv_"//trim(adjustl(obtype))//"_ges."//trim(adjustl(id))//'_spread.nc4'

        inquire(file=obsfile,exist=fexist)
        if (.not. fexist) cycle

        call nclayer_check(nf90_open(obsfile, NF90_WRITE, iunit, cache_size = 2147483647))
        call nclayer_check(nf90_inq_dimid(iunit, "nobs", nobsid))
        call nclayer_check(nf90_inquire_dimension(iunit, nobsid, len = nobs))
        call nclayer_check(nf90_close(iunit))

        if (nobs <= 0) cycle

        allocate(enkf_use_flag(nobs), enkf_fit(nobs), enkf_sprd(nobs))

        if (obtype == ' uv') then
           allocate(enkf_use_flag_v(nobs), enkf_fit_v(nobs), enkf_sprd_v(nobs))
        endif


        do i = 1, nobs
           nobdiag = nobdiag + 1

           ! skip if not used in EnKF
           if (x_used(nobdiag) == 1) then
              ! update if it is used in EnKF
              nob = nob + 1
              enkf_use_flag(i) = 1
              enkf_fit(i)  = x_fit(nob)
              enkf_sprd(i) = x_sprd(nob)
              if (obtype== ' uv') then
                 nob = nob + 1
                 enkf_use_flag_v(i) = 1
                 enkf_fit_v(i)  = x_fit(nob)
                 enkf_sprd_v(i) = x_sprd(nob)
              endif
           else
              enkf_use_flag(i) = -1
              enkf_fit(i)  = r_missing
              enkf_sprd(i) = r_missing
              if (obtype== ' uv') then
                 enkf_use_flag_v(i) = -1
                 enkf_fit_v(i)  = r_missing
                 enkf_sprd_v(i) = r_missing
              endif

           endif
        enddo
        
        inquire(file=obsfile2,exist=fexist)
        if (.not. fexist) then
           call nclayer_check(nf90_create(trim(obsfile2), NF90_NETCDF4, &
                              iunit))
           call nclayer_check(nf90_def_dim(iunit, "nobs", nobs, nobsid))
        else
           call nclayer_check(nf90_open(obsfile2, NF90_WRITE, iunit))
           call nclayer_check(nf90_inq_dimid(iunit, "nobs", nobsid))
        endif

        if (obtype == ' uv')  then
           call write_ncvar_int(iunit, nobsid, "u_EnKF_use_flag", enkf_use_flag)
           call write_ncvar_int(iunit, nobsid, "v_EnKF_use_flag", enkf_use_flag_v)
           deallocate(enkf_use_flag, enkf_use_flag_v)
           call write_ncvar_single(iunit, nobsid, "u_EnKF_fit_"//trim(gesid), enkf_fit)
           call write_ncvar_single(iunit, nobsid, "v_EnKF_fit_"//trim(gesid), enkf_fit_v)
           deallocate(enkf_fit, enkf_fit_v)
           call write_ncvar_single(iunit, nobsid, "u_EnKF_spread_"//trim(gesid), enkf_sprd)
           call write_ncvar_single(iunit, nobsid, "v_EnKF_spread_"//trim(gesid), enkf_sprd_v)
           deallocate(enkf_sprd, enkf_sprd_v)
        else
           call write_ncvar_int(iunit, nobsid, "EnKF_use_flag", enkf_use_flag)
           deallocate(enkf_use_flag)
           call write_ncvar_single(iunit, nobsid, "EnKF_fit_"//trim(gesid), enkf_fit)
           deallocate(enkf_fit)
           call write_ncvar_single(iunit, nobsid, "EnKF_spread_"//trim(gesid), enkf_sprd)
           deallocate(enkf_sprd)
        endif
        
        call nclayer_check(nf90_close(iunit))

  enddo obtypeloop

  if (nob .ne. nobs_max) then
      print *,'number of obs not what expected in write_convobs_data',nob,nobs_max
      call stop2(94)
  end if
  if (nobdiag /= nobs_maxdiag) then
      print *,'number of total obs in diag not what expected in write_convobs_data',nobdiag, nobs_maxdiag
      call stop2(94)
  endif

  contains
  subroutine write_ncvar_single(iunit, dimid, varname, field)
    use netcdf, only: nf90_def_var, nf90_put_var, nf90_inq_varid,  &
                      nf90_def_var_deflate,NF90_FLOAT, NF90_ENOTVAR
    use ncdw_climsg, only: nclayer_check
    use ncdw_types, only: NLAYER_COMPRESSION
    implicit none
    integer(i_kind), intent(in)  :: iunit, dimid
    character(*), intent(in)     :: varname
    real(r_single), dimension(:), allocatable :: field

    integer :: ierr, varid

    ierr = nf90_inq_varid(iunit, varname, varid)
    if (ierr == NF90_ENOTVAR) then
       call nclayer_check(nf90_def_var(iunit, varname, NF90_FLOAT, dimid, varid))
       call nclayer_check(nf90_def_var_deflate(iunit, varid, 1, 1, int(NLAYER_COMPRESSION)))
    endif
    call nclayer_check(nf90_put_var(iunit, varid, field))
  end subroutine write_ncvar_single

  subroutine write_ncvar_int(iunit, dimid, varname, field)
    use netcdf, only: nf90_def_var, nf90_put_var, nf90_inq_varid,  &
                      nf90_def_var_deflate,NF90_INT, NF90_ENOTVAR
    use ncdw_climsg, only: nclayer_check
    use ncdw_types, only: NLAYER_COMPRESSION
    implicit none
    integer(i_kind), intent(in)  :: iunit, dimid
    character(*), intent(in)     :: varname
    integer(i_kind), dimension(:), allocatable :: field

    integer :: ierr, varid

    ierr = nf90_inq_varid(iunit, varname, varid)
    if (ierr == NF90_ENOTVAR) then
       call nclayer_check(nf90_def_var(iunit, varname, NF90_INT, dimid, varid))
       call nclayer_check(nf90_def_var_deflate(iunit, varid, 1, 1, int(NLAYER_COMPRESSION)))
    endif
    call nclayer_check(nf90_put_var(iunit, varid, field))
  end subroutine write_ncvar_int

end subroutine write_convobs_data

end module readconvobs


