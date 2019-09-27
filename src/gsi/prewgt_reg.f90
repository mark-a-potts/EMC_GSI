subroutine prewgt_reg(mype)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    prewgt_reg  setup bkerror
!   prgmmr: wu               org: np22                date: 2000-03-15
!
! abstract: setup smoothing and grid transform for bkerror
!
! program history log:
!   2000-03-15  wu
!   2004-08-03  treadon - add only to module use; add intent in/out;
!                         fix bug in which rdgstat_reg inadvertently
!                         recomputed sigl (s/b done in gridmod)
!   2004-10-26  wu - include factors hzscl in the range of RF table
!   2004-11-16  treadon - add longitude dimension to variance array dssv
!   2004-11-20  derber - modify to make horizontal table more reproducable and
!                        move most of table calculations to berror
!   2005-01-22  parrish - split out balance variables to subroutine prebal_reg
!                         contained in module balmod.f90.  change wlat,
!                         lmin, lmax to rllat, llmin, llmax and add
!                         "use balmod" to connect to rllat,llmin,llmax
!   2005-02-23  wu - setup background variance for qoption=2
!   2005-03-28  wu - replace mlath with mlat and modify dim of corz, corp
!   2005-07-15  wu - remove old print out, add max bound to lp
!   2005-11-29  derber - unify ozone variance calculation
!   2006-01-11  kleist - place upper/lower bounds on qoption=2 variance
!   2006-01-31  treadon - invert hzscl
!   2006-04-17  treadon - use rlsig from call rdgstat_reg; replace sigl
!                         with ges_prslavg/ges_psfcavg
!   2007-05-30  h.liu - remove ozmz
!   2008-04-23  safford - rm unused uses and vars
!   2010-03-12  zhu     - move interpolations of dssv and dssvs into this subroutine
!                       - move varq & factoz to berror_read_wgt_reg
!                       - add changes using nrf* for generalized control variables
!   2010-03-15  zhu     - move the calculation of compute_qvar3d here
!   2010-04-10  parrish - remove rhgues, no longer used
!   2010-04-29  wu      - set up background error for oz
!   2010-05-28  todling - obtain variable id's on the fly (add getindex)
!   2010-06-01  todling - rename as,tsfc_sdv to as2d,as3d,atsfc_sdv (alloc now)
!   2010-06-03  todling - protect dssvs w/ mvars check
!   2010-07-31  parrish - replace mpi_allreduce used for getting ozone background error with
!                          mpl_allreduce, and introduce r_quad arithmetic to remove dependency of
!                          results on number of tasks.  This is the same strategy currently used
!                          in dot_product (see control_vectors.f90).
!   2012-12-15  zhu     - add treatment of dssv for cw for all-sky radiance
!   2013-01-22  parrish - initialize kb=0, in case regional_ozone is false.
!                          (fixes WCOSS debug compile error)
!
!   2013-04-17  wu      - use nnnn1o to deside whether to define B related veriables
!                         avoid undefined input when number of tasks is larger than
!                         that of the total levels of control vectors
!   2013-10-19  todling - all guess variables in met-guess
!   2014-02-03  todling - update interface to berror_read_wgt_reg
!   2016-09-xx  g.zhao  - tuning background error stats for qr/qs/qg to use dbz
!   2017-02-xx  g.zhao  - add temperature-dependent background error for cloud variables
!   2018-10-23  C.Liu   - add w
!
!   input argument list:
!     mype     - pe number
!
!   output argument list:
!
!   other important variables
!     nsig     - number of sigma levels
!     nx       - number of gaussian lats in one hemisphere
!     ny       - number of longitudes
!     dx       - cos of grid latitudes (radians)
!   agv,wgv,bv - balance correlation matrix for t,p,div
!      sli     - scale info for the 3 subdomain
!     alv,dssv - vertical smoother coef.

! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!$$$
  use kinds, only: r_kind,i_kind,r_quad
  use balmod, only: rllat,rllat1,llmin,llmax
  use berror, only: dssvs,&
       bw,ny,nx,dssv,vs,be,ndeg,&
       init_rftable,hzscl,slw,nhscrf,bkgv_write
  use mpimod, only: nvar_id,levs_id,mpi_sum,mpi_comm_world,mpi_rtype
  use jfunc, only: varq,qoption,varcw,cwoption
  use control_vectors, only: cvars2d,cvars3d
  use control_vectors, only: as2d,as3d,atsfc_sdv
  use control_vectors, only: nrf,nc3d,nc2d,nvars,mvars !_RT ,nrf3_loc,nrf2_loc,nrf_var
  use control_vectors, only: cvars => nrf_var
  use gridmod, only: lon2,lat2,nsig,nnnn1o,regional_ozone,&
       region_dx,region_dy,nlon,nlat,istart,jstart,region_lat
  use constants, only: zero,half,one,two,four,rad2deg,zero_quad
  use guess_grids, only: ges_prslavg,ges_psfcavg
  use m_berror_stats_reg, only: berror_get_dims_reg,berror_read_wgt_reg
  use mpeu_util, only: getindex
  use mpl_allreducemod, only: mpl_allreduce
  use gsi_bundlemod, only: gsi_bundlegetpointer
  use gsi_metguess_mod, only: gsi_metguess_bundle
  use mpeu_util, only: die
! --- CAPS ---
  use guess_grids, only: ges_tsen                      ! for t-depn't err vars
  use guess_grids, only: nfldsig
  use caps_radaruse_mod, only: be_sf,hscl_sf, vscl_sf, be_vp,hscl_vp, vscl_vp, &
                               be_t, hscl_t,  vscl_t,  be_q, hscl_q,  vscl_q,&
                               be_qr, be_qs, be_qg, hscl_qx, vscl_qx,&
                               l_set_be_rw, l_set_be_dbz, l_use_log_qx,&
                               l_plt_be_stats, l_be_T_dep,&
                               l_use_rw_caps, l_use_dbz_caps, lvldbg
! --- CAPS ---

  implicit none

! Declare passed variables
  integer(i_kind),intent(in   ) :: mype

! Declare local parameters
! real(r_kind),parameter:: six          = 6.0_r_kind
! real(r_kind),parameter:: eight        = 8.0_r_kind
  real(r_kind),parameter:: r400000      = 400000.0_r_kind
  real(r_kind),parameter:: r800000      = 800000.0_r_kind
  real(r_kind),parameter:: r015         = 0.15_r_kind


! Declare local variables
  integer(i_kind) k,i,ii
  integer(i_kind) n,nn,nsig180
  integer(i_kind) j,k1,loc,kb,mm1,ix,jl,il
  integer(i_kind) inerr,l,lp,l2
  integer(i_kind) msig,mlat              ! stats dimensions
  integer(i_kind),dimension(nnnn1o):: ks
  integer(i_kind) nrf3_oz,nrf2_sst,nrf3_cw,istatus
  integer(i_kind),allocatable,dimension(:) :: nrf3_loc,nrf2_loc

! --- CAPS ---
  integer(i_kind) nrf3_sf,nrf3_vp,nrf3_t,nrf3_q
  integer(i_kind) :: nrf3_ql,nrf3_qi, nrf3_qr,nrf3_qs,nrf3_qg, nrf3_qnr, nrf3_w

  real(r_kind),allocatable,dimension(:,:,:):: vz4plt

  real(r_kind),allocatable,dimension(:):: vz_cld
  real(r_kind),allocatable,dimension(:,:,:):: dsv_cld       ! lon2,nsig,lat2
  real(r_kind),allocatable,dimension(:,:,:,:):: corz_cld    ! lon2,lat2,nsig,3(qr/qs/qg)

  integer(i_kind) :: inerr_out              ! output of berror_var for NCL plotting
  real(r_kind) :: SclHgt
  real(r_kind), parameter :: Tbar=290.0_r_kind
  real(r_kind), parameter :: three_eighths=3.0_r_kind/8.0_r_kind
  real(r_kind) :: tsen
  integer(i_kind) :: mid_mlat
  integer(i_kind) :: mid_nsig

  real(r_kind)      :: corz_sf, corz_vp, corz_t, corz_q
  real(r_kind)      :: max_sf, min_sf, ave_sf
  real(r_kind)      :: max_vp, min_vp, ave_vp

  external          :: berror_qcld_tdep
! --- CAPS ---

  real(r_kind) samp2,dl1,dl2,d
  real(r_kind) samp,hwl,cc
  real(r_kind),dimension(nsig):: rate,dlsig,rlsig
  real(r_kind),dimension(nsig,nsig):: turn
  real(r_kind),dimension(ny,nx)::sl
  real(r_kind) fact,psfc015

  real(r_kind),dimension(lon2,nsig,llmin:llmax):: dsv
  real(r_kind),dimension(lon2,llmin:llmax):: dsvs

  real(r_kind),allocatable,dimension(:,:):: corp, hwllp
  real(r_kind),allocatable,dimension(:,:,:):: corz, hwll, vz
  real(r_kind),allocatable,dimension(:,:,:,:)::sli
  real(r_quad),dimension(180,nsig):: ozmz,cnt
  real(r_quad),dimension(180*nsig):: ozmz0,cnt0
  real(r_kind),dimension(180,nsig):: ozmzt,cntt

  real(r_kind),dimension(:,:,:),pointer::ges_oz=>NULL()

!----------------------------------------------------------------------!
! Initialize local variables
!  do j=1,nx
!     do i=1,ny
!        dx(i,j)=region_dx(i,j)
!        dy(i,j)=region_dy(i,j)
!     end do
!  end do

! Setup sea-land mask
  sl=one
!  do j=1,nx
!     do i=1,ny
!        sl(i,j)=min(max(sl(i,j),zero),one)
!     enddo
!  enddo

! Get required indexes from CV var names
  nrf3_oz  = getindex(cvars3d,'oz')
  nrf3_cw  = getindex(cvars3d,'cw')
  nrf2_sst = getindex(cvars2d,'sst')
  nrf3_sf  = getindex(cvars3d,'sf')
  nrf3_vp  = getindex(cvars3d,'vp')
  nrf3_t   = getindex(cvars3d,'t')
  nrf3_q   = getindex(cvars3d,'q')

!   cloud fields
  nrf3_ql  =getindex(cvars3d,'ql')
  nrf3_qi  =getindex(cvars3d,'qi')
  nrf3_qr  =getindex(cvars3d,'qr')
  nrf3_qs  =getindex(cvars3d,'qs')
  nrf3_qg  =getindex(cvars3d,'qg')
  nrf3_qnr =getindex(cvars3d,'qnr')
  nrf3_w   =getindex(cvars3d,'w')

! Read dimension of stats file
  inerr=22
  call berror_get_dims_reg(msig,mlat,inerr)

! Allocate arrays in stats file
  allocate ( corz(1:mlat,1:nsig,1:nc3d) )
  allocate ( corp(1:mlat,nc2d) )
  allocate ( hwll(0:mlat+1,1:nsig,1:nc3d),hwllp(0:mlat+1,nvars-nc3d) )
  allocate ( vz(1:nsig,0:mlat+1,1:nc3d) )

! --- CAPS ---
! Arrays used for temperature-dependent error variance when assimilation radar dbz obs
  if (l_be_T_dep) then
      allocate ( vz_cld(1:nsig) )                      ; vz_cld   = zero;
      allocate ( dsv_cld(1:lon2, 1:nsig, 1:lat2) )     ; dsv_cld  = zero;
      allocate ( corz_cld(1:lon2, 1:lat2, 1:nsig, 3) ) ; corz_cld = zero;
  end if
! --- CAPS ---

! Read in background error stats and interpolate in vertical to that specified in namelist
  call berror_read_wgt_reg(msig,mlat,corz,corp,hwll,hwllp,vz,rlsig,varq,qoption,varcw,cwoption,mype,inerr)

! find ozmz for background error variance
  kb=0
  if(regional_ozone) then

     call gsi_bundlegetpointer (gsi_metguess_bundle(1),'oz',ges_oz,istatus)
     if(istatus/=0) call die('prewgt_reg',': missing oz in metguess, aborting ',istatus)

     kb_loop: do k=1,nsig
        if(rlsig(k) <  log(0.35_r_kind))then
           kb=k
           exit kb_loop
        endif
     enddo kb_loop
     mm1=mype+1

     ozmz=zero_quad
     cnt=zero_quad
     do k=1,nsig
        do j=2,lon2-1
           jl=j+jstart(mm1)-2
           jl=min0(max0(1,jl),nlon)
           do i=2,lat2-1
              il=i+istart(mm1)-2
              il=min0(max0(1,il),nlat)
              ix=region_lat(il,jl)*rad2deg+half+90._r_kind
              ozmz(ix,k)=ozmz(ix,k)+ges_oz(i,j,k)*ges_oz(i,j,k)
              cnt(ix,k)=cnt(ix,k)+one
           end do
        end do
     end do
     i=0
     do k=1,nsig
        do ix=1,180
           i=i+1
           ozmz0(i)=ozmz(ix,k)
           cnt0(i)=cnt(ix,k)
        end do
     end do
     nsig180=180*nsig
     call mpl_allreduce(nsig180,qpvals=ozmz0)
     call mpl_allreduce(nsig180,qpvals=cnt0)
     i=0
     do k=1,nsig
        do ix=1,180
           i=i+1
           ozmzt(ix,k)=ozmz0(i)
           cntt(ix,k)=cnt0(i)
        end do
     end do
     do k=1,nsig
        do i=1,180
           if(cntt(i,k)>zero) ozmzt(i,k)=sqrt(ozmzt(i,k)/cntt(i,k))
        enddo
     enddo
  endif ! regional_ozone
! Normalize vz with del sigmma and convert to vertical grid units!
  dlsig(1)=rlsig(1)-rlsig(2)
  do k=2,nsig-1
     dlsig(k)=half*(rlsig(k-1)-rlsig(k+1))
  enddo
  dlsig(nsig)=rlsig(nsig-1)-rlsig(nsig)

  do n=1,nc3d
     do j=0,mlat+1
        do k=1,nsig
           vz(k,j,n)=vz(k,j,n)*dlsig(k)
        end do
     end do
  end do

! As used in the code, the horizontal length scale
! parameters are used in an inverted form.  Invert
! the parameter values here.
  do i=1,nhscrf
     if (l_set_be_rw .or. l_set_be_dbz ) hzscl(i) = one  ! CAPS
     hzscl(i)=one/hzscl(i)
  end do

! apply scaling to vertical length scales.  
! note:  parameter vs needs to be inverted
  if (l_set_be_rw .or. l_set_be_dbz) vs = one ! CAPS
  vs=one/vs
  vz=vz*vs

! --- CAPS ---
!------------------------------------------------------------------------------!
! special treatment for hwll(horizontal), vz(vertical scale length)
!         and corz(bkgd err) of u/v/t/q when using radial wind observations of
!         radar
  if ( l_set_be_rw ) then
      do n=1,nc3d
          if (n==nrf3_q) then
              if (mype==0) write(6,*)'PREWGT_REG: tuning BE for q (pe=',mype,')'
              if (    be_q .gt. 0.0_r_kind ) corz(:,:,n) = corz(:,:,n) * be_q ! error stddev for Q
              if (  hscl_q .gt. 0.0_r_kind ) hwll(:,:,n) = hscl_q
              if (  vscl_q .gt. 0.0_r_kind ) vz(  :,:,n) = vscl_q
          end if
          if (n==nrf3_t) then
              if (mype==0) write(6,*)'PREWGT_REG: tuning BE for t (pe=',mype,')'
              if (    be_t .gt. 0.0_r_kind ) corz(:,:,n) = corz(:,:,n) * be_t ! error stddev for t
              if (  hscl_t .gt. 0.0_r_kind ) hwll(:,:,n) = hscl_t
              if (  vscl_t .gt. 0.0_r_kind ) vz(  :,:,n) = vscl_t
          end if
          if (n==nrf3_sf) then
!             be_sf   = 0.2_r_kind    ! with vscl=0.3333_r_kind
!             be_sf   = 0.2_r_kind / 4.5_r_kind   ! 1.5/4.5=0.3333
!             hscl_sf = 20000.0_r_kind
!             vscl_sf = 1.5_r_kind
              max_sf  = maxval(corz(:,:,n))
              min_sf  = minval(corz(:,:,n))
              ave_sf  = sum(corz(:,:,n))/(mlat*nsig)
              if (  be_sf .gt. 0.0_r_kind ) then
                  corz_sf = ave_sf * be_sf
                  corz(:,:,n) = corz_sf                ! error stddev for sf (compensate for change in scale)
!                 corz(:,:,n) = corz(:,:,n) * be_sf    ! error stddev for sf
                  if (mype==0) then
                      write(6,'(1x,A15,I4,A50,4(1x,F15.2),1x,A12)')                         &
                          '(PREWGT_REG:pe=',mype,') stream function err std max min ave:',  &
                          max_sf, min_sf, ave_sf, corz_sf,' (m^2/s^2)'
                      write(6,'(1x,A15,I4,A70,F15.6,A6,I3,1x,A6)')                          &
                          '(PREWGT_REG:pe=',mype,                                           &
                          ') inflate  the pre-fixed err_var of sf (streamfunction) by ',    &
                          be_sf,'   n=', n,cvars3d(n)
                  end if
              end if

              if (mype==0) &
                  write(6,'(1x,A15,I4,A70,F9.1,F9.2,A6,I3,1x,A6)')                          &
                  '(PREWGT_REG:pe=',mype,                                                   &
                  ') re-set the length-scale(hor ver) of sf (stream function): ',           &
                  hscl_sf, vscl_sf,'   n=', n,cvars3d(n)
              if ( hscl_sf .gt. 0.0_r_kind ) hwll(:,:,n) = hscl_sf
              if ( vscl_sf .gt. 0.0_r_kind ) vz(  :,:,n) = vscl_sf
          end if
          if (n==nrf3_vp) then
!             be_vp   = 0.2_r_kind    ! with vscl=0.3333_r_kind
!             be_vp   = 0.2_r_kind / 4.5_r_kind   ! 1.5/4.5=0.3333
!             hscl_vp = 20000.0_r_kind
!             vscl_vp = 1.5_r_kind
              max_vp  = maxval(corz(:,:,n))
              min_vp  = minval(corz(:,:,n))
              ave_vp  = sum(corz(:,:,n))/(mlat*nsig)
              if (  be_vp .gt. 0.0_r_kind ) then
                  corz_vp = ave_vp * be_vp
                  corz(:,:,n) = corz_vp                ! error stddev for vp (compensate for change in scale)
!                 corz(:,:,n) = corz(:,:,n) * be_vp    ! error stddev for vp
                  if (mype == 0) then
                      write(6,'(1x,A15,I4,A50,4(1x,F15.2),1x,A12)')                           &
                          '(PREWGT_REG:pe=',mype,') velocity potential err std max min ave:', &
                          max_vp, min_vp, ave_vp, corz_vp,' (m^2/s^2)'
                      write(6,'(1x,A15,I4,A70,F15.6,A6,I3,1x,A6)')                            &
                          '(PREWGT_REG:pe=',mype,                                             &
                          ') inflate  the pre-fixed err_var of vp (VelPotent) by ',           &
                          be_vp,'   n=', n,cvars3d(n)
                  end if
              end if

              if (mype == 0) &
                  write(6,'(1x,A15,I4,A70,F9.1,F9.2,A6,I3,1x,A6)') &
                  '(PREWGT_REG:pe=',mype, &
                  ') re-set the length-scale(hor ver) of vp (VelPotent): ', &
                  hscl_vp, vscl_vp,'   n=', n,cvars3d(n)
              if ( hscl_vp .gt. 0.0_r_kind ) hwll(:,:,n) = hscl_vp
              if ( vscl_vp .gt. 0.0_r_kind ) vz(  :,:,n) = vscl_vp

          end if
      end do
  else
      if (mype==0) write(6,'(1x,A15,I4,A80)')                                                &
          '(PREWGT_REG:pe=',mype,                                                            &
          ') DO NOT RE-SET the BACKGROUND ERROR for radar wind assimilation.'
  end if

!------------------------------------------------------------------------------!
! special treatment for hwll(horizontal), vz(vertical scale length)
!         and corz(bkgd err) of cloud hydrometers (qr/qs/qg) when using radar reflectivity observations
  if ( l_set_be_dbz ) then
      do n=1,nc3d
          if (n==nrf3_qr ) then
              if (mype==0) &
                  write(6,'(1x,A60,I4)')'PREWGT_REG: user-defined namelist to tune BE for qr on pe:',mype
              if (    be_qr .gt. 0.0_r_kind ) corz(:,:,n) = be_qr
              if (  hscl_qx .gt. 0.0_r_kind ) hwll(:,:,n) = hscl_qx
              if (  vscl_qx .gt. 0.0_r_kind ) vz(  :,:,n) = vscl_qx
          end if
          if (n==nrf3_qs ) then
              if (mype==0) &
                  write(6,'(1x,A60,I4)')'PREWGT_REG: user-defined namelist to tune BE for qs on pe:',mype
              if (    be_qs .gt. 0.0_r_kind ) corz(:,:,n) = be_qs
              if (  hscl_qx .gt. 0.0_r_kind ) hwll(:,:,n) = hscl_qx
              if (  vscl_qx .gt. 0.0_r_kind ) vz(  :,:,n) = vscl_qx
          end if
          if (n==nrf3_qg ) then
              if (mype==0) &
                  write(6,'(1x,A60,I4)')'PREWGT_REG: user-defined namelist to tune BE for qg on pe:',mype
              if (    be_qg .gt. 0.0_r_kind ) corz(:,:,n) = be_qg
              if (  hscl_qx .gt. 0.0_r_kind ) hwll(:,:,n) = hscl_qx
              if (  vscl_qx .gt. 0.0_r_kind ) vz(  :,:,n) = vscl_qx
          end if
          if (n==nrf3_qnr ) then
              if (mype==0) &
                  write(6,'(1x,A60,I4)')'PREWGT_REG: user-defined namelist to tune BE for qnr on pe:',mype
                                              corz(:,:,n) = 100.0_r_kind
              if (  hscl_qx .gt. 0.0_r_kind ) hwll(:,:,n) = hscl_qx
              if (  vscl_qx .gt. 0.0_r_kind ) vz(  :,:,n) = vscl_qx
          end if

          if (n==nrf3_w ) then
              if (mype==0) &
                  write(6,'(1x,A60,I4)')'PREWGT_REG: user-defined namelist to tune BE for w on pe:',mype
                                              corz(:,:,n) = 3.0_r_kind
              if (  hscl_qx .gt. 0.0_r_kind ) hwll(:,:,n) = hscl_qx
              if (  vscl_qx .gt. 0.0_r_kind ) vz(  :,:,n) = vscl_qx
          end if
      end do
  else
      if (mype==0) write(6,'(1x,A15,I4,A80)') &
          '(PREWGT_REG:pe=',mype, &
          ') DO NOT RE-SET the BACKGROUND ERROR for radar dbz assimilation.'
  end if

!------------------------------------------------------------------------------!
! --- CAPS ---

  call rfdpar1(be,rate,ndeg)
  call rfdpar2(be,rate,turn,samp,ndeg)

  allocate(nrf3_loc(nc3d),nrf2_loc(nc2d))
  do ii=1,nc3d
     nrf3_loc(ii)=getindex(cvars,cvars3d(ii))
  enddo
  do ii=1,nc2d
     nrf2_loc(ii)=getindex(cvars,cvars2d(ii))
  enddo

  do n=1,nc3d
     if(n==nrf3_oz .and. regional_ozone)then   ! spetial treament for ozone variance
        loc=nrf3_loc(n)
        vz(:,:,n)=1.5_r_kind   ! ozone vertical scale fixed
        do j=llmin,llmax
           call smoothzo(vz(1,j,n),samp,rate,n,j,dsv(1,1,j))
           do k=1,nsig
              do i=1,lon2
                 dsv(i,k,j)=dsv(i,k,j)*as3d(n)
              end do
           end do
        end do
        do j=1,lon2
           jl=j+jstart(mm1)-2
           jl=min0(max0(1,jl),nlon)
           do i=1,lat2
              il=i+istart(mm1)-2
              il=min0(max0(1,il),nlat)
              d=region_lat(il,jl)*rad2deg+90._r_kind
              l=int(d)
              l2=l+1
              dl2=d-float(l)
              dl1=one-dl2
              do k=1,nsig
                 dssv(i,j,k,n)=(dl1*ozmzt(l,k)+dl2*ozmzt(l2,k))*dsv(1,k,llmin)
              end do
           end do
        end do
! --- CAPS ---
     else if ( n==nrf3_qr .or. n==nrf3_qs .or. n==nrf3_qg ) then

        if ( l_be_T_dep ) then
            if (mype==0) &
                write(6,*)' prewgt_reg(mype=',mype,')',' Temperature-dependent erro vars for Q_cld and as3d= ',as3d(n),' for var:',cvars3d(n)
            loc=nrf3_loc(n)

!           re-define vz_cld on model sigma grid for cloud variabels (not on stats grid)
!           to match the re-dfined corz_cld, which is also defined on model grid
!           because the error variables of cloud variable is modle/background temperature
!           dependent.
!           only initialization of alv in subroutine smoothzo
            do j=llmin,llmax
                call smoothzo(vz(1,j,n),samp,rate,n,j,dsv(1,1,j))
            end do

            do j=1,lat2
                mid_nsig = INT((nsig+1)/2)
!               vz_cld(1:mid_nsig) = three_eighths        ! ~3km
!               vz_cld(1+mid_nsig:nsig) = half            ! ~3km
                mid_mlat = INT((llmin+llmax)/2)
                vz_cld(1:nsig) = vz(1:nsig,mid_mlat,n)    !
!               vz_cld(1:nsig) = vscl_qx                  ! value from namelist for hydrometers
!               vz_cld(1:nsig) = two                      ! two veritcal grids (wrong!)
!               call smoothzo (vz_cld(1,j,n), samp,rate,n,j,dsv_cld(1,1,j))
                call smoothzo1(vz_cld(1:nsig),samp,rate,dsv_cld(1:lon2,1:nsig,j))
                do i=1,lon2
                    do k=1,nsig
                        tsen=ges_tsen(j,i,k,nfldsig)
                        if (n==nrf3_qr) then
                            call berror_qcld_tdep(mype,tsen,1,corz_cld(i,j,k,1))
                            dssv(j,i,k,n)=dsv_cld(i,k,j) * corz_cld(i,j,k,1) * as3d(n)
                        else if (n==nrf3_qs) then
                            call berror_qcld_tdep(mype,tsen,2,corz_cld(i,j,k,2))
                            dssv(j,i,k,n)=dsv_cld(i,k,j) * corz_cld(i,j,k,2) * as3d(n)
                        else if (n==nrf3_qg) then
                            call berror_qcld_tdep(mype,tsen,3,corz_cld(i,j,k,3))
                            dssv(j,i,k,n)=dsv_cld(i,k,j) * corz_cld(i,j,k,3) * as3d(n)
                        else
                            write(6,*) &
                                " prewgt_reg: T-dependent error only for rain/snwo/graupel --> wrong for ",n,cvars3d(n)
                            call stop2(999)
                        end if
                    end do

                end do
            end do

        else             ! if NOT T-dependent background error
            loc=nrf3_loc(n)
            do j=llmin,llmax
                call smoothzo(vz(1,j,n),samp,rate,n,j,dsv(1,1,j))
                do k=1,nsig
                    do i=1,lon2
                        dsv(i,k,j)=dsv(i,k,j)*corz(j,k,n)*as3d(n)
                    end do
                end do
            end do

            do j=1,lat2
                do i=1,lon2
                    l=int(rllat1(j,i))
                    l2=min0(l+1,llmax)
                    dl2=rllat1(j,i)-float(l)
                    dl1=one-dl2
                    do k=1,nsig
                        dssv(j,i,k,n)=dl1*dsv(i,k,l)+dl2*dsv(i,k,l2)
                    enddo
                end do
            end do
        end if
! --- CAPS ---
     else
        loc=nrf3_loc(n)
        do j=llmin,llmax
           call smoothzo(vz(1,j,n),samp,rate,n,j,dsv(1,1,j))
           do k=1,nsig
              do i=1,lon2
                 dsv(i,k,j)=dsv(i,k,j)*corz(j,k,n)*as3d(n)
              end do
           end do
        end do

        do j=1,lat2
           do i=1,lon2
              l=int(rllat1(j,i))
              l2=min0(l+1,llmax)
              dl2=rllat1(j,i)-float(l)
              dl1=one-dl2
              do k=1,nsig
                 dssv(j,i,k,n)=dl1*dsv(i,k,l)+dl2*dsv(i,k,l2)
              enddo
           end do
        end do
     endif
  end do

! --- CAPS ---
! output berror correlation length scales and variances
  if ( l_plt_be_stats ) then
      inerr_out=2117
      if (mype .eq. 0) then
          do n=1,nc3d
              write(6,*)'---- pregwgt_reg(mype=',mype,'): cvars3d(n)=',n,cvars3d(n),'   output corz/hwll/vz for 3D berror.'
          end do
          open(inerr_out,file='./berror_prewgt_reg_vIntrp.dat',form='unformatted')
          write(inerr_out)mlat,nsig,nc3d
          write(inerr_out)cvars3d(1:nc3d)
          write(inerr_out)(((hwll(j,k,n),j=0,mlat+1),k=1,nsig),n=1,nc3d)
          write(6,*),' ---- prewgt_reg(mype=',mype,'   output vz normalized by dlsig to vertical grid units first!'
          write(inerr_out)(((vz(k,j,n),j=0,mlat+1),k=1,nsig),n=1,nc3d)
!     output the original vz which is not normalized by dlsig
          if ( .not. allocated(vz4plt)) allocate (vz4plt(1:nsig,0:mlat+1,1:nc3d) )
          do n=1,nc3d
              do j=0,mlat+1
                  do k=1,nsig
                      vz4plt(k,j,n)=vz(k,j,n)/dlsig(k)
                  end do
              end do
          end do
          write(inerr_out)(((vz4plt(k,j,n),j=0,mlat+1),k=1,nsig),n=1,nc3d)
          deallocate(vz4plt)
          write(inerr_out)(((corz(j,k,n),j=1,mlat),k=1,nsig),n=1,nc3d)
          if (l_be_T_dep) then
              write(6,*),' ---- prewgt_reg(mype=',mype,':output temperature-dependent error for cloud hydrometers'
              write(inerr_out) ((corz_cld(1,1,k,n),k=1,nsig),n=1,3)
          end if
          close(inerr_out)
      end if
  end if
! --- CAPS ---

! Special case of dssv for qoption=2 and cw
  if (qoption==2) call compute_qvar3d

! Background error arrays for sfp, sst, land t, and ice t
  do n=1,nc2d
     loc=nrf2_loc(n)
     do j=llmin,llmax
        do i=1,lon2
           dsvs(i,j)  =corp(j,n)*as2d(n)
        end do
     end do

     do j=1,lat2
        do i=1,lon2
           l=int(rllat1(j,i))
           l2=min0(l+1,llmax)
           dl2=rllat1(j,i)-float(l)
           dl1=one-dl2
           dssvs(j,i,n)=dl1*dsvs(i,l)+dl2*dsvs(i,l2)
           if (mvars>=2.and.n==nrf2_sst) then
              dssvs(j,i,nc2d+1)=atsfc_sdv(1)*as2d(n)  
              dssvs(j,i,nc2d+2)=atsfc_sdv(2)*as2d(n)  
           end if
        end do
     end do
  end do

  if (bkgv_write) call write_bkgvars2_grid

! hybrid sigma level structure calculated in rdgstat_reg   
! ks used to load constant horizontal scales for SF/VP
! above sigma level 0.15
! loop l for diff variable of each PE.

  psfc015=r015*ges_psfcavg
  do l=1,nnnn1o
     ks(l)=nsig+1
     if(cvars(nvar_id(l))=='sf' .or. cvars(nvar_id(l))=='SF'.or. &
        cvars(nvar_id(l))=='vp' .or. cvars(nvar_id(l))=='VP')then
        k_loop: do k=1,nsig
           if (ges_prslavg(k) < psfc015) then
              ks(l)=k
              exit k_loop
           end if
        enddo k_loop
     endif
  end do

  if(nnnn1o > 0)then
     allocate(sli(ny,nx,2,nnnn1o))

! sli in scale  unit (can add in sea-land mask)
     samp2=samp*samp
     do i=1,nx
        do j=1,ny
           fact=one/(one+(one-sl(j,i))*bw)
           slw((i-1)*ny+j,1)=region_dx(j,i)*region_dy(j,i)*fact**2*samp2
           sli(j,i,1,1)=region_dy(j,i)*fact
           sli(j,i,2,1)=region_dx(j,i)*fact
        enddo
     enddo
  endif

! Set up scales


! This first loop for nnnn1o will be if we aren't dealing with
! surface pressure, skin temperature, or ozone
  do k=nnnn1o,1,-1
     k1=levs_id(k)
     n=nvar_id(k)

     nn=-1
     do ii=1,nc3d
        if (nrf3_loc(ii)==n) then 
           nn=ii
           if (nn/=nrf3_oz) then
              if (k1 >= ks(k))then
                 l=int(rllat(ny/2,nx/2))
                 fact=one/hwll(l,k1,nn)
                 do i=1,nx
                    do j=1,ny
                       slw((i-1)*ny+j,k)=slw((i-1)*ny+j,1)*fact**2
                       sli(j,i,1,k)=sli(j,i,1,1)*fact
                       sli(j,i,2,k)=sli(j,i,2,1)*fact
                    enddo
                 enddo
              else
                 do i=1,nx
                    do j=1,ny
                       l=int(rllat(j,i))
                       lp=min0(l+1,llmax)
                       dl2=rllat(j,i)-float(l)
                       dl1=one-dl2
                       fact=one/(dl1*hwll(l,k1,nn)+dl2*hwll(lp,k1,nn))
                       slw((i-1)*ny+j,k)=slw((i-1)*ny+j,1)*fact**2
                       sli(j,i,1,k)=sli(j,i,1,1)*fact
                       sli(j,i,2,k)=sli(j,i,2,1)*fact
                    enddo
                 enddo
              endif
           else
              if (k1 <= kb )then
                 hwl=r400000
              else
                 hwl=r800000-r400000*(nsig-k1)/(nsig-kb)
              endif
              fact=one/hwl
              do i=1,nx
                 do j=1,ny
                    slw((i-1)*ny+j,k)=slw((i-1)*ny+j,1)*fact**2
                    sli(j,i,1,k)=sli(j,i,1,1)*fact
                    sli(j,i,2,k)=sli(j,i,2,1)*fact
                 enddo
              enddo
           end if 
           exit
        end if
     end do

     if (nn==-1) then 
        do ii=1,nc2d
           if (nrf2_loc(ii)==n .or. n>nrf) then 
              nn=ii
              if (n>nrf) nn=n-nc3d
              cc=one 
              if (nn==nrf2_sst) cc=two
              if (nn==nc2d+1 .or. nn==nc2d+2) cc=four
              do i=1,nx
                 do j=1,ny
                    l=int(rllat(j,i))
                    lp=min0(l+1,llmax)
                    dl2=rllat(j,i)-float(l)
                    dl1=one-dl2
                    fact=cc/(dl1*hwllp(l,nn)+dl2*hwllp(lp,nn))
                    slw((i-1)*ny+j,k)=slw((i-1)*ny+j,1)*fact**2
                    sli(j,i,1,k)=sli(j,i,1,1)*fact
                    sli(j,i,2,k)=sli(j,i,2,1)*fact
                 end do
              end do
              exit
           end if
        end do
     end if 

  end do
  deallocate(corz,corp,hwll,hwllp,vz)
  deallocate(nrf3_loc,nrf2_loc)

! --- CAPS ---
  if ( allocated(vz_cld  ) ) deallocate ( vz_cld )
  if ( allocated(dsv_cld ) ) deallocate ( dsv_cld )
  if ( allocated(corz_cld) ) deallocate ( corz_cld )
! --- CAPS ---

! Load tables used in recursive filters
  if(nnnn1o>0) then
     call init_rftable(mype,rate,nnnn1o,sli)
     deallocate( sli) 
  endif

  return
end subroutine prewgt_reg

! --- CAPS ---
subroutine berror_qcld_tdep(mype,tsen,i_cat,q_cld_err)
! temperature dependent error variance
!
! 2016-10-xx g.zhao  CAPS/OU   based on Chengsi Liu and Rong Kong's work
!
  use kinds, only: r_kind,i_kind
  use constants, only: pi
  use caps_radaruse_mod, only: l_use_log_qx

  implicit none

  integer(i_kind), intent(in  ) :: mype            ! pe number
  integer, intent(in  )         :: i_cat           ! cloud hydrometer category
                                                   ! 1: rain water
                                                   ! 2: snow
                                                   ! 3: graupel / hail
  real(r_kind), intent(in   )   :: tsen            ! temperature

  real(r_kind), intent(  out)   :: q_cld_err       ! background error

! define local variables
! qr -- rain
  real(r_kind)            :: Eqrl, Eqrh            ! error @ low-level and high-level
  real(r_kind)            :: Tqrl, Tqrh            ! significant temperature points

! qs -- snow
  real(r_kind)            :: Eqsl, Eqsh            ! error @ low-level and high-level
  real(r_kind)            :: Tqsl, Tqsh            ! significant temperature points

! qg -- graupel
  real(r_kind)            :: Eqgl, Eqgh            ! error @ low-level and high-level
  real(r_kind)            :: Tqgl, Tqgh            ! significant temperature points

!
  real(r_kind) :: Eql, Eqh
  real(r_kind) :: Tql, Tqh

  real(r_kind) :: Delta_T, Delta_E, Mid_E
  real(r_kind) :: dt, de
  real(r_kind) :: a
  integer(i_kind) :: nnqh1

  logical   :: firstcalled
  save firstcalled
  data firstcalled/.true./

  external stop2


! BOP-------------------------------------------------------------------

! significant temperature point for rain water
! Tqrl=278.15_r_kind    ! CSLiu
! Tqrl=273.15_r_kind    ! Mine4
  Tqrl=272.65_r_kind    ! Mine0 / Mine5
  Tqrh=268.15_r_kind    ! CSLiu

! significant temperature point for snow
! Tqsl=278.15_r_kind    ! CSLiu/Mine0
! Tqsl=282.15_r_kind    ! Mine1
  Tqsl=282.65_r_kind    ! Mine5
! Tqsh=243.15_r_kind    ! CSLiu
! Tqsh=275.15_r_kind    ! Mine0
! Tqsh=278.15_r_kind    ! Mine4
  Tqsh=280.15_r_kind    ! Mine1 / Mine5

! significant temperature point for graupel
! Tqgl=278.15_r_kind    ! CSLiu
! Tqgl=280.15_r_kind    ! Mine0
  Tqgl=281.15_r_kind    ! Mine1
! Tqgh=243.15_r_kind    ! CSLiu
! Tqgh=275.15_r_kind    ! Mine0
  Tqgh=279.15_r_kind    ! Mine1

  if ( l_use_log_qx ) then
!
!     Eqrl=0.2877_r_kind
!     Eqrl=0.1133_r_kind
      Eqrl=0.4055_r_kind
      Eqrh=1.0E-6_r_kind

!     Eqsl=0.2877_r_kind
      Eqsl=1.0E-6_r_kind
!     Eqsh=0.2877_r_kind
!     Eqsh=0.1133_r_kind
      Eqsh=0.4055_r_kind

!     Eqgl=0.2231_r_kind
!     Eqgl=0.1133_r_kind
      Eqgl=0.2877_r_kind
!     Eqgh=0.2231_r_kind
!     Eqgh=0.4055_r_kind
      Eqgh=0.2877_r_kind
  else
!     from Chengsi Liu and Rong Kong
!     Tqrl=278.15_r_kind    ! CSLiu
      Tqrl=272.65_r_kind    ! tuning 2
!     Eqrl=8.0E-4_r_kind    ! CSLiu
      Eqrl=1.2E-3_r_kind    ! tuning 2
      Tqrh=268.15_r_kind    ! CSLiu
      Eqrh=1.0E-10_r_kind

!     Tqsl=278.15_r_kind    ! CSLiu
      Tqsl=282.65_r_kind    ! CSLiu
      Eqsl=1.0E-10_r_kind
!     Tqsh=243.15_r_kind    ! CSLiu
!     Tqsh=268.15_r_kind    ! tuning 1 --> Tqrh=268.15_r_kind    ! CSLiu
      Tqsh=280.15_r_kind    ! tuning 2
      Eqsh=1.2E-3_r_kind

      Tqgl=278.15_r_kind    ! CSLiu
!     Eqgl=3.0E-4_r_kind    ! CSLiu
      Eqgl=6.0E-4_r_kind
!     Tqgh=243.15_r_kind    ! CSLiu
      Tqgh=268.15_r_kind    ! tuning 1 --> Tqrh=268.15_r_kind    ! CSLiu
!     Eqgh=6.0E-4_r_kind    ! CSLiu
      Eqgh=1.2E-3_r_kind
  end if

  if (i_cat .eq. 1) then
      Tql = Tqrl
      Tqh = Tqrh
      Eql = Eqrl
      Eqh = Eqrh
  else if (i_cat .eq. 2) then
      Tql = Tqsl
      Tqh = Tqsh
      Eql = Eqsl
      Eqh = Eqsh
  else if (i_cat .eq. 3) then
      Tql = Tqgl
      Tqh = Tqgh
      Eql = Eqgl
      Eqh = Eqgh
  else
      write(6,*) 'sub: berror_qcld_tdep:   unknown category id-->',i_cat
      call stop2(999)
  end if

  if (firstcalled) then
      if (mype==0) then
          write(6,*)'berror_qcld_Tdep: use_logqx->',l_use_log_qx,' i_cat->',i_cat,' mype->',mype
          write(6,*)'be_qcld_Tdep: rain   (Tlow,BElow,Thgh,BEhgh)',Tqrl,Eqrl,Tqrh,Eqrh
          write(6,*)'be_qcld_Tdep: snow   (Tlow,BElow,Thgh,BEhgh)',Tqsl,Eqsl,Tqsh,Eqsh
          write(6,*)'be_qcld_Tdep: graupel(Tlow,BElow,Thgh,BEhgh)',Tqgl,Eqgl,Tqgh,Eqgh
      end if
      firstcalled = .false.
  end if

  if ( tsen > Tql ) then
      q_cld_err = Eql
  else if ( tsen <= Tql .and. tsen >= Tqh ) then
      Delta_T = Tql - Tqh
      Delta_E = Eql - Eqh
      Mid_E = (Eql + Eqh) * 0.5_r_kind
      dt = tsen - Tqh
      a =  pi * dt / Delta_T
      de = -cos(a) * Delta_E * 0.5_r_kind
      q_cld_err =  Mid_E + de
  else
      q_cld_err = Eqh
  end if

  return
! EOP----------

end subroutine berror_qcld_tdep
! --- CAPS ---
