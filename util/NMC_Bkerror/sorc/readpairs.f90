subroutine readpairs(npe,mype,numcases,numaodcases)
!   2017-10-25  Gael Descombes (NCAR) - capability to read nemsio files
  use variables, only: nlat,nlon,nsig,ak5,bk5,ck5,&
      na,nb,filename,hybrid,db_prec,zero,one,fv,&
      idpsfc5,idthrm5,cp5,ntrac5,idvc5,idvm5,lat1,lon1,&
      iglobal,ijn_s,displs_s,filunit1,filunit2,&
      ird_s,irc_s,displs_g, ijn,&
      naoda,naodb,aodfilename,aodfilunit1,aodfilunit2,calc_aod
  use variables, only: use_gfs_nemsio
  use specgrid, only: sptez_s,nc,ncin,factvml,&
      factsml,enn1,ncd2,jcaptrans,jcap,jcapin,unload_grid,&
      sptezv_s
  use sigio_module, only: sigio_intkind,sigio_head,sigio_data,&
      sigio_srohdc,sigio_axdata,sigio_sclose
  use comm_mod, only: levs_id,nvar_id,grid2sub,nsig1o,spec_send,&
      disp_spec,create_task_info
  use kinds, only: r_kind,r_single,r_double
  use nemsio_module, only: nemsio_gfile,nemsio_open,nemsio_close,&
                           nemsio_getfilehead,nemsio_getheadvar,&
                           nemsio_readrecv,nemsio_init,nemsio_realkind

  implicit none
  include 'mpif.h'

  integer npe,mype,numcases,ierror,mpi_rtype,iret,iret2
  integer numaodcases
  integer mm1,kk,proc1,proc2
  integer i,j,k,m,n,inges,inge2,i2,i2m1
  integer k1,k2,k3,k4,k5,k6,jj
  integer nfields, icount
  integer, allocatable :: taskid(:)

  real(r_kind),dimension(lat1,lon1,nsig):: sf1,sf2,vp1,vp2,t1,t2,&
       rh1,rh2,oz1,oz2,cw1,cw2,q1,q2,ts1,ts2,qs1,qs2
  real(r_kind),dimension(lat1,lon1):: ps1,ps2
  real(r_kind),dimension(lat1,lon1):: aod1,aod2
  real(r_kind),dimension(lat1,lon1,nsig,ntrac5):: trac1,trac2
  real(r_kind),dimension(lat1,lon1,nsig):: p3d1, p3d2
  real(r_kind),dimension(lat1,lon1,nsig):: q3d1, q3d2

  real(r_kind),dimension(nc):: z,z2
!  real(r_single),dimension(ncin,nsig1o):: z41,z42
!  real(r_single),dimension(ncin,6*nsig+1):: z4all, z4all2
  real(r_kind),dimension(ncin,nsig1o):: z41,z42
  real(r_kind),dimension(ncin,6*nsig+2):: z4all, z4all2

  real(r_kind),dimension(nlon,nlat-2):: grid1,grid2
  real(r_kind),dimension(iglobal,nsig1o):: work1,work2
  real(r_kind),dimension(nlat,nlon):: wk1, wk2

  type(sigio_head):: sighead1,sighead2
  type(sigio_data):: sigdata1,sigdata2

  type(nemsio_gfile) :: gfile1
  type(nemsio_gfile) :: gfile2
  real(nemsio_realkind),dimension((nlat-2)*nlon):: nems_wk
  real(nemsio_realkind),dimension((nlat-2)*nlon):: aod_wk

  logical ice
  if (db_prec) then
    mpi_rtype=mpi_real8
  else
    mpi_rtype=mpi_real4
  end if

  inges=50
  inge2=51
  mm1=mype+1
  proc1=0
  proc2=npe-1

  z4all  = 0.0
  z4all2 = 0.0

  nfields = 1+5*nsig !ps, (u,v), t, q, oz, cw
  allocate(taskid(nfields))
  call create_task_info(nfields, npe, taskid)

  filunit1=(10000+(mype+1))
  filunit2=(20000+(mype+1))

! Each mpi task will carry two files, which contains all variables, for each of the time levels
  open(filunit1,form='unformatted',action='write')
  rewind(filunit1)
  open(filunit2,form='unformatted',action='write')
  rewind(filunit2)

  call nemsio_init(iret=iret)
  if(iret/=0) then
     write(6,*)'readpairs: problem with nemsio_init, iret=',iret
     stop
  end if

  do n=1,numcases
  if ( use_gfs_nemsio ) then
     if (mype==0)  write(6,*)'reading from', trim(filename(na(n)))
     call nemsio_open(gfile1,trim(adjustl(filename(na(n)))),'read',iret=iret)
     if (iret/=0) then
        write(6,*)'readpairs_1: problem with nemsio_open, mype, iret=',mype,iret
        stop
     endif
     if (mype==0)  write(6,*)'reading from', trim(filename(nb(n)))
     call nemsio_open(gfile2,trim(adjustl(filename(nb(n)))),'read',iret=iret)
     if (iret/=0) then
        write(6,*)'readpairs_2: problem with nemsio_open, mype, iret=',mype,iret
        stop
     endif

     ! convert from grid to wave
     icount = 0
     icount = icount + 1
     !ps
     if ( mype == taskid(icount) ) then
        call nemsio_readrecv(gfile1,'pres','sfc',lev=1,data=nems_wk(:),iret=iret)
        nems_wk(:) = nems_wk(:)*0.001 !Pa to cbar
        grid1 = reshape(nems_wk(:),(/nlon,nlat-2/))
        call nemsio_readrecv(gfile2,'pres','sfc',lev=1,data=nems_wk(:),iret=iret)
        nems_wk(:) = nems_wk(:)*0.001 !Pa to cbar
        grid2 = reshape(nems_wk(:),(/nlon,nlat-2/))
        call sptez_s(z4all (:,6*nsig+1),grid1,-1)
        call sptez_s(z4all2(:,6*nsig+1),grid2,-1)
     end if
     !t
     do k=1,nsig
        icount = icount + 1
        if ( mype == taskid(icount) ) then
           call nemsio_readrecv(gfile1,'tmp','mid layer',lev=k,data=nems_wk(:),iret=iret)
           grid1 = reshape(nems_wk(:),(/nlon,nlat-2/))
           call nemsio_readrecv(gfile2,'tmp','mid layer',lev=k,data=nems_wk(:),iret=iret)
           grid2 = reshape(nems_wk(:),(/nlon,nlat-2/))
           call sptez_s(z4all (:,2*nsig+k),grid1,-1)
           call sptez_s(z4all2(:,2*nsig+k),grid2,-1)
        end if
     end do
     !q
     do k=1,nsig
        icount = icount + 1
        if ( mype == taskid(icount) ) then
           call nemsio_readrecv(gfile1,'spfh','mid layer',lev=k,data=nems_wk(:),iret=iret)
           grid1 = reshape(nems_wk(:),(/nlon,nlat-2/))
           call nemsio_readrecv(gfile2,'spfh','mid layer',lev=k,data=nems_wk(:),iret=iret)
           grid2 = reshape(nems_wk(:),(/nlon,nlat-2/))
           call sptez_s(z4all (:,3*nsig+k),grid1,-1)
           call sptez_s(z4all2(:,3*nsig+k),grid2,-1)
        end if
     end do
     !oz
     do k=1,nsig
        icount = icount + 1
        if ( mype == taskid(icount) ) then
           call nemsio_readrecv(gfile1,'o3mr','mid layer',lev=k,data=nems_wk(:),iret=iret)
           grid1 = reshape(nems_wk(:),(/nlon,nlat-2/))
           call nemsio_readrecv(gfile2,'o3mr','mid layer',lev=k,data=nems_wk(:),iret=iret)
           grid2 = reshape(nems_wk(:),(/nlon,nlat-2/))
           call sptez_s(z4all (:,4*nsig+k),grid1,-1)
           call sptez_s(z4all2(:,4*nsig+k),grid2,-1)
        end if
     end do

    !cw
     do k=1,nsig
        icount = icount + 1
        if ( mype == taskid(icount) ) then
           call nemsio_readrecv(gfile1,'clwmr','mid layer',lev=k,data=nems_wk(:),iret=iret)
           grid1 = reshape(nems_wk(:),(/nlon,nlat-2/))
           call nemsio_readrecv(gfile2,'clwmr','mid layer',lev=k,data=nems_wk(:),iret=iret)
           grid2 = reshape(nems_wk(:),(/nlon,nlat-2/))
           call sptez_s(z4all (:,5*nsig+k),grid1,-1)
           call sptez_s(z4all2(:,5*nsig+k),grid2,-1)
        end if
     end do
     ! u,v to div,vor
     do k=1,nsig
        icount = icount + 1
        if ( mype == taskid(icount) ) then
           call nemsio_readrecv(gfile1,'ugrd','mid layer',lev=k,data=nems_wk(:),iret=iret)
           grid1 = reshape(nems_wk(:),(/nlon,nlat-2/)) !ugrd of file1
           call nemsio_readrecv(gfile1,'vgrd','mid layer',lev=k,data=nems_wk(:),iret=iret)
           grid2 = reshape(nems_wk(:),(/nlon,nlat-2/)) !vgrd of file1
           call sptezv_s(z4all(:,nsig+k),z4all(:,k),grid1,grid2,-1)
           call nemsio_readrecv(gfile2,'ugrd','mid layer',lev=k,data=nems_wk(:),iret=iret)
           grid1 = reshape(nems_wk(:),(/nlon,nlat-2/)) !ugrd of file2
           call nemsio_readrecv(gfile2,'vgrd','mid layer',lev=k,data=nems_wk(:),iret=iret)
           grid2 = reshape(nems_wk(:),(/nlon,nlat-2/)) !vgrd of file2
           call sptezv_s(z4all2(:,nsig+k),z4all2(:,k),grid1,grid2,-1)
        end if
     end do

     ! need to improve in the future
     ! broadcast the data on various processors to all processors
     icount = 0
     icount = icount + 1
     !ps
     call mpi_bcast(z4all(:,6*nsig+1),ncin,mpi_rtype,taskid(icount), &
                & mpi_comm_world,ierror)
     call mpi_bcast(z4all2(:,6*nsig+1),ncin,mpi_rtype,taskid(icount), &
                & mpi_comm_world,ierror)
     do k=1,nsig
        icount = icount + 1
        !t
        call mpi_bcast(z4all(:,2*nsig+k),ncin,mpi_rtype,taskid(icount), &
                      & mpi_comm_world,ierror)
        call mpi_bcast(z4all2(:,2*nsig+k),ncin,mpi_rtype,taskid(icount), &
                      & mpi_comm_world,ierror)
     end do
     do k=1,nsig
        icount = icount + 1
        !q
        call mpi_bcast(z4all(:,3*nsig+k),ncin,mpi_rtype,taskid(icount), &
                      & mpi_comm_world,ierror)
        call mpi_bcast(z4all2(:,3*nsig+k),ncin,mpi_rtype,taskid(icount), &
                      & mpi_comm_world,ierror)
     end do
     do k=1,nsig
        icount = icount + 1
        !oz
        call mpi_bcast(z4all(:,4*nsig+k),ncin,mpi_rtype,taskid(icount), &
                      & mpi_comm_world,ierror)
        call mpi_bcast(z4all2(:,4*nsig+k),ncin,mpi_rtype,taskid(icount), &
                      & mpi_comm_world,ierror)
     end do
     do k=1,nsig
        icount = icount + 1
        !cw
        call mpi_bcast(z4all(:,5*nsig+k),ncin,mpi_rtype,taskid(icount), &
                      & mpi_comm_world,ierror)
        call mpi_bcast(z4all2(:,5*nsig+k),ncin,mpi_rtype,taskid(icount), &
                      & mpi_comm_world,ierror)
     end do
     do k=1,nsig
        icount = icount + 1
        !z (vor)
        call mpi_bcast(z4all(:,k),ncin,mpi_rtype,taskid(icount), &
                      & mpi_comm_world,ierror)
        call mpi_bcast(z4all2(:,k),ncin,mpi_rtype,taskid(icount), &
                      & mpi_comm_world,ierror)
        !d (div)
        call mpi_bcast(z4all(:,nsig+k),ncin,mpi_rtype,taskid(icount), &
                      & mpi_comm_world,ierror)
        call mpi_bcast(z4all2(:,nsig+k),ncin,mpi_rtype,taskid(icount), &
                      & mpi_comm_world,ierror)
     end do
     call mpi_scatterv(z4all,spec_send,disp_spec,mpi_rtype,&
        z41,spec_send(mm1),mpi_rtype,0,mpi_comm_world,ierror)
     call mpi_scatterv(z4all2,spec_send,disp_spec,mpi_rtype,&
        z42,spec_send(mm1),mpi_rtype,0,mpi_comm_world,ierror)

     call mpi_barrier(mpi_comm_world,iret2)

     ! 3D pressure
     wk1 = zero; wk2 = zero
     p3d1 = zero; p3d2 = zero
     do k = 1, nsig
        call nemsio_readrecv(gfile1,'pres','mid layer',lev=k,data=nems_wk(:),iret=iret)
        nems_wk(:) = nems_wk(:)*0.001 !Pa to cbar
        grid1 = reshape(nems_wk(:),(/nlon,nlat-2/))
        call unload_grid(grid1,wk1) !grid1(nlon,nlat-2), wk1(nlat,nlon)
        call mpi_scatterv(wk1,ijn,displs_g,mpi_rtype,&
           p3d1(1,1,k),ijn(mm1),mpi_rtype,0,mpi_comm_world,ierror)
        if ( ierror /= 0 ) write(6,*) 'error scatter p3d1'
        call nemsio_readrecv(gfile2,'pres','mid layer',lev=k,data=nems_wk(:),iret=iret)
        nems_wk(:) = nems_wk(:)*0.001 !Pa to cbar
        grid2 = reshape(nems_wk(:),(/nlon,nlat-2/))
        call unload_grid(grid2,wk2)
        call mpi_scatterv(wk2,ijn,displs_g,mpi_rtype,&
           p3d2(1,1,k),ijn(mm1),mpi_rtype,0,mpi_comm_world,ierror)
        if ( ierror /= 0 ) write(6,*) 'error scatter p3d2'
     end do

     ! specific humidity
     wk1 = zero; wk2 = zero
     q3d1 = zero; q3d2 = zero
     do k = 1, nsig
        call nemsio_readrecv(gfile1,'spfh','mid layer',lev=k,data=nems_wk(:),iret=iret)
        grid1 = reshape(nems_wk(:),(/nlon,nlat-2/))
        call unload_grid(grid1,wk1) !grid1(nlon,nlat-2), wk1(nlat,nlon)
        call mpi_scatterv(wk1,ijn,displs_g,mpi_rtype,&
           q3d1(1,1,k),ijn(mm1),mpi_rtype,0,mpi_comm_world,ierror)
        if ( ierror /= 0 ) write(6,*) 'error scatter q3d1'
        call nemsio_readrecv(gfile2,'spfh','mid layer',lev=k,data=nems_wk(:),iret=iret)
        grid2 = reshape(nems_wk(:),(/nlon,nlat-2/))
        call unload_grid(grid2,wk2)
        call mpi_scatterv(wk2,ijn,displs_g,mpi_rtype,&
           q3d2(1,1,k),ijn(mm1),mpi_rtype,0,mpi_comm_world,ierror)
        if ( ierror /= 0 ) write(6,*) 'error scatter q3d2'
     end do

     call nemsio_close(gfile1,iret=iret)
     call nemsio_close(gfile2,iret=iret)
  else !if not use_gfs_nemsio
     if (mype==0)  write(6,*)'opening=', inges,filename(na(n))
     if (mype==0)  write(6,*)'opening=', inge2,filename(nb(n))

     ! Get spectral information from
     if (mype==proc1)   call sigio_srohdc(inges,filename(na(n)),sighead1,sigdata1,iret)
     if (mype==proc2)   call sigio_srohdc(inge2,filename(nb(n)),sighead1,sigdata1,iret)
     call mpi_barrier(mpi_comm_world,iret2)

     if (mype==proc1 .or. mype==proc2) then
        do k=1,nsig
           k1=nsig
           k2=2*nsig
           k3=3*nsig
           k4=4*nsig
           k5=5*nsig
           do i=1,ncin
              z4all(i,k)=sigdata1%z(i,k)
              z4all(i,k1+k)=sigdata1%d(i,k)
              z4all(i,k2+k)=sigdata1%t(i,k)
              z4all(i,k3+k)=sigdata1%q(i,k,1)
              z4all(i,k4+k)=sigdata1%q(i,k,2)
              z4all(i,k5+k)=sigdata1%q(i,k,3)
           end do
        end do
        k6=6*nsig
        do i=1,ncin
           z4all(i,k6+1)=sigdata1%ps(i)
        end do
     end if

     call mpi_scatterv(z4all,spec_send,disp_spec,mpi_rtype,&
        z41,spec_send(mm1),mpi_rtype,proc1,mpi_comm_world,ierror)
     call mpi_scatterv(z4all,spec_send,disp_spec,mpi_rtype,&
        z42,spec_send(mm1),mpi_rtype,proc2,mpi_comm_world,ierror)

  end if ! use_gfs_nemsio

  call mpi_barrier(mpi_comm_world,iret2)

  work1=zero ; work2=zero

  do k=1,nsig1o
     ! Check: Streamfunction level?
     if(nvar_id(k).eq.1) then ! SF
        kk=levs_id(k)
        if (kk.gt.0 .and. kk.le.nsig) then
           call jcaptrans(z,factvml,z41(1,k))
           call jcaptrans(z2,factvml,z42(1,k))

           call splaplac(0,jcap,enn1,z,z,-1)
           call splaplac(0,jcap,enn1,z2,z2,-1)
           z(1:2)=zero
           z2(1:2)=zero
           call sptez_s(z,grid1,1)
           call sptez_s(z2,grid2,1)
           call unload_grid(grid1,work1(1,k))
           call unload_grid(grid2,work2(1,k))
        end if  !end if kk check

     ! Check: Velocity Potential level?
     else if(nvar_id(k).eq.2) then
        kk=levs_id(k)
        if (kk.gt.0 .and. kk.le.nsig) then
           call jcaptrans(z,factvml,z41(1,k))
           call jcaptrans(z2,factvml,z42(1,k))

           call splaplac(0,jcap,enn1,z,z,-1)
           call splaplac(0,jcap,enn1,z2,z2,-1)
           z(1:2)=zero
           z2(1:2)=zero
           call sptez_s(z,grid1,1)
           call sptez_s(z2,grid2,1)
           call unload_grid(grid1,work1(1,k))
           call unload_grid(grid2,work2(1,k))
        end if  !end if kk check

     ! Check: Temperature Level?
     else if(nvar_id(k).eq.3) then ! SF
        kk=levs_id(k)
        if (kk.gt.0 .and. kk.le.nsig) then
           call jcaptrans(z,factsml,z41(1,k))
           call jcaptrans(z2,factsml,z42(1,k))
           call sptez_s(z,grid1,1)
           call unload_grid(grid1,work1(1,k))
           call sptez_s(z2,grid2,1)
           call unload_grid(grid2,work2(1,k))
        end if

     ! Check: Relative Humidity level?
     else if(nvar_id(k).eq.4) then ! Q
        kk=levs_id(k)
        if (kk.gt.0 .and. kk.le.nsig) then
           call jcaptrans(z,factsml,z41(1,k))
           call jcaptrans(z2,factsml,z42(1,k))
           call sptez_s(z,grid1,1)
           call unload_grid(grid1,work1(1,k))
           call sptez_s(z2,grid2,1)
           call unload_grid(grid2,work2(1,k))
        end if

     ! Check: Ozone Level?
     else if(nvar_id(k).eq.5) then ! SF
        kk=levs_id(k)
        if (kk.gt.0 .and. kk.le.nsig) then
           call jcaptrans(z,factsml,z41(1,k))
           call jcaptrans(z2,factsml,z42(1,k))
           call sptez_s(z,grid1,1)
           call unload_grid(grid1,work1(1,k))
           call sptez_s(z2,grid2,1)
           call unload_grid(grid2,work2(1,k))
        end if

     ! Check: Cloud Water Level?
     else if(nvar_id(k).eq.6) then ! SF
        kk=levs_id(k)
        if (kk.gt.0 .and. kk.le.nsig) then
           call jcaptrans(z,factsml,z41(1,k))
           call jcaptrans(z2,factsml,z42(1,k))
           call sptez_s(z,grid1,1)
           call unload_grid(grid1,work1(1,k))
           call sptez_s(z2,grid2,1)
           call unload_grid(grid2,work2(1,k))
        end if

     ! Check: Surface pressure level ?
     else if(nvar_id(k).eq.7) then ! PS
        kk=levs_id(k)
        if (kk.eq.1) then
           call jcaptrans(z,factsml,z41(1,k))
           call jcaptrans(z2,factsml,z42(1,k))
           call sptez_s(z,grid1,1)
           call sptez_s(z2,grid2,1)
           call unload_grid(grid1,work1(1,k))
           call unload_grid(grid2,work2(1,k))
        end if
     else ! No nsig1o level to process
        !write(6,*) 'READPAIRS:  No Level to process, k,mype,levs_id,nvar_id = ',k,mype,levs_id(k),nvar_id(k)
     endif
  end do  !End do nsig1o levs

! CALL GRID2SUB HERE
    call grid2sub(work1,sf1,vp1,t1,q1,oz1,cw1,ps1,aod1)
    call grid2sub(work2,sf2,vp2,t2,q2,oz2,cw2,ps2,aod2)

    if ( use_gfs_nemsio ) then
       !replace with original grid values from nemsio file
       q1 = q3d1
       q2 = q3d2
    end if !use_gfs_nemsio

    if (idpsfc5 /=2) then
     do j=1,lon1
        do i=1,lat1
          ps1(i,j)=exp(ps1(i,j))
          ps2(i,j)=exp(ps2(i,j))
        end do
      end do
    end if

    if (idthrm5==2 .or. idthrm5==3) then
!            SIGIO has three possible thermodynamic variables
!            Variable idthrm5 indicates the type
!               idthrm5 = 0,1 = virtual temperature (Tv)
!               idthrm5 = 2   = sensible (dry) temperature (T)
!               idthrm5 = 3   = enthalpy (h=CpT)
!            The GSI analysis variable is Tv
      if ( .not. use_gfs_nemsio ) then
         do k=1,nsig
            do j=1,lon1
               do i=1,lat1
                  trac1(i,j,k,1)=q1(i,j,k)
                  trac1(i,j,k,2)=oz1(i,j,k)
                  trac1(i,j,k,3)=cw1(i,j,k)
                  trac2(i,j,k,1)=q2(i,j,k)
                  trac2(i,j,k,2)=oz2(i,j,k)
                  trac2(i,j,k,3)=cw2(i,j,k)
               end do
            end do
         end do
! Convert input thermodynamic variable to dry temperature
         call sigio_cnvtdv2(lat1*lon1,lat1*lon1,nsig,idvc5,&
            idvm5,ntrac5,iret,t1,trac1,cp5,1)
         call sigio_cnvtdv2(lat1*lon1,lat1*lon1,nsig,idvc5,&
            idvm5,ntrac5,iret,t2,trac2,cp5,1)
      end if ! not use_gfs_nemsio
      if ( use_gfs_nemsio ) then
         ! the nemsio t is t sensible
         ts1 = t1
         ts2 = t2
      end if

! Make sure we have Virtual Temperature
       do k=1,nsig
          do j=1,lon1
             do i=1,lat1
                t1(i,j,k) = t1(i,j,k)*(one+fv*q1(i,j,k))
                t2(i,j,k) = t2(i,j,k)*(one+fv*q2(i,j,k))
             end do
          end do
       end do
    end if  ! END IF CHECK ON THERMO VARIABLE


! CONVERT Q to RH
! Q, Tv, and Ps are available now, so convert q-rh1
    do k=1,nsig
      do j=1,lon1
        do i=1,lat1
           if ( .not. use_gfs_nemsio ) then
!  create sensible temperature for qsat calculations
              ts1(i,j,k)=t1(i,j,k)/(one+fv*max(zero,q1(i,j,k)))
              ts2(i,j,k)=t2(i,j,k)/(one+fv*max(zero,q2(i,j,k)))
           end if !not use_gfs_nemsio
           qs1(i,j,k)=q1(i,j,k)
           qs2(i,j,k)=q2(i,j,k)
        end do
      end do
    end do
    !ice=.true.
    ice=.false.
    if ( use_gfs_nemsio ) then
       call genqsat_nemsio(ts1,qs1,lat1,lon1,&
            ps1,ice,p3d1)
       call genqsat_nemsio(ts2,qs2,lat1,lon1,&
            ps2,ice,p3d2)
    else
       call genqsat(ts1,qs1,lat1,lon1,&
            ps1,ice,ak5,bk5,ck5)
       call genqsat(ts2,qs2,lat1,lon1,&
            ps2,ice,ak5,bk5,ck5)
    end if

    do k=1,nsig
      do j=1,lon1
        do i=1,lat1
! divide by saturation value for q
! THIS IS Q=Q/Qs
          rh1(i,j,k)=q1(i,j,k)/qs1(i,j,k)
          rh2(i,j,k)=q2(i,j,k)/qs2(i,j,k)

!     restrict gridq to be between -0.25 and 1.25
          rh1(i,j,k) = max(rh1(i,j,k),-0.25_r_kind)
          rh2(i,j,k) = max(rh2(i,j,k),-0.25_r_kind)
          rh1(i,j,k) = min(rh1(i,j,k),1.25_r_kind)
          rh2(i,j,k) = min(rh2(i,j,k),1.25_r_kind)
        end do
      end do
    end do


! Write out the grids
    write(filunit1) sf1,vp1,t1,rh1,oz1,cw1,ps1
    write(filunit2) sf2,vp2,t2,rh2,oz2,cw2,ps2

    call mpi_barrier(mpi_comm_world,iret2)

  end do   ! END DO LOOP OVER CASES
  close(filunit1)
  close(filunit2)

  call mpi_barrier(mpi_comm_world,iret2)

  ! now read in AOD pairs, which is a separate list
  if (calc_aod) then
    aodfilunit1=(100000+(mype+1))
    aodfilunit2=(200000+(mype+1))

    ! Each mpi task will carry two files, which contains all variables, for each of the time levels
    open(aodfilunit1,form='unformatted',action='write')
    rewind(aodfilunit1)
    open(aodfilunit2,form='unformatted',action='write')
    rewind(aodfilunit2)

    call nemsio_init(iret=iret)
    if(iret/=0) then
       write(6,*)'readpairs: problem with nemsio_init, iret=',iret
       stop
    end if

    do n=1,numaodcases
      if (mype==0)  write(6,*)'reading from', trim(aodfilename(naoda(n)))
      call nemsio_open(gfile1,trim(adjustl(aodfilename(naoda(n)))),'read',iret=iret)
      if (iret/=0) then
        write(6,*)'readpairs_1: problem with nemsio_open, mype, iret=',mype,iret
        stop
      endif
      if (mype==0)  write(6,*)'reading from', trim(aodfilename(naodb(n)))
      call nemsio_open(gfile2,trim(adjustl(aodfilename(naodb(n)))),'read',iret=iret)
      if (iret/=0) then
        write(6,*)'readpairs_2: problem with nemsio_open, mype, iret=',mype,iret
        stop
      endif

      ! convert from grid to wave
      icount = 0
      icount = icount + 1
      !aod
      if ( mype == taskid(icount) ) then
         ! CRM - these aer diagnostic files have column mass per species/type,
         ! so we need to sum them up 
         aod_wk(:) = 0
         call nemsio_readrecv(gfile1,'ducmass',lev=1,data=nems_wk(:),iret=iret) ! dust
         aod_wk(:) = aod_wk(:) + nems_wk(:)
         call nemsio_readrecv(gfile1,'sscmass',lev=1,data=nems_wk(:),iret=iret) ! sea salt
         aod_wk(:) = aod_wk(:) + nems_wk(:)
         call nemsio_readrecv(gfile1,'bccmass',lev=1,data=nems_wk(:),iret=iret) ! black C
         aod_wk(:) = aod_wk(:) + nems_wk(:)
         call nemsio_readrecv(gfile1,'occmass',lev=1,data=nems_wk(:),iret=iret) ! organic C
         aod_wk(:) = aod_wk(:) + nems_wk(:)
         call nemsio_readrecv(gfile1,'sucmass',lev=1,data=nems_wk(:),iret=iret) ! sulfate
         aod_wk(:) = aod_wk(:) + nems_wk(:)
         grid1 = reshape(aod_wk(:),(/nlon,nlat-2/))
         aod_wk(:) = 0
         call nemsio_readrecv(gfile2,'ducmass','atmos col',lev=1,data=nems_wk(:),iret=iret) ! dust
         aod_wk(:) = aod_wk(:) + nems_wk(:)
         call nemsio_readrecv(gfile2,'sscmass',lev=1,data=nems_wk(:),iret=iret) ! sea salt
         aod_wk(:) = aod_wk(:) + nems_wk(:)
         call nemsio_readrecv(gfile2,'bccmass',lev=1,data=nems_wk(:),iret=iret) ! black C
         aod_wk(:) = aod_wk(:) + nems_wk(:)
         call nemsio_readrecv(gfile2,'occmass',lev=1,data=nems_wk(:),iret=iret) ! organic C
         aod_wk(:) = aod_wk(:) + nems_wk(:)
         call nemsio_readrecv(gfile2,'sucmass',lev=1,data=nems_wk(:),iret=iret) ! sulfate
         aod_wk(:) = aod_wk(:) + nems_wk(:)
         grid2 = reshape(aod_wk(:),(/nlon,nlat-2/))
         !call nemsio_readrecv(gfile2,'ducmassacol','entire_atmosphere',lev=1,data=nems_wk(:),iret=iret)
         grid2 = reshape(nems_wk(:),(/nlon,nlat-2/))
         call sptez_s(z4all (:,6*nsig+2),grid1,-1)
         call sptez_s(z4all2(:,6*nsig+2),grid2,-1)
         print *, 'grid2(aod)',grid2
      end if


      call mpi_bcast(z4all(:,6*nsig+2),ncin,mpi_rtype,taskid(icount), &
                & mpi_comm_world,ierror)
      call mpi_bcast(z4all2(:,6*nsig+2),ncin,mpi_rtype,taskid(icount), &
                & mpi_comm_world,ierror)

      call mpi_scatterv(z4all,spec_send,disp_spec,mpi_rtype,&
         z41,spec_send(mm1),mpi_rtype,0,mpi_comm_world,ierror)
      call mpi_scatterv(z4all2,spec_send,disp_spec,mpi_rtype,&
         z42,spec_send(mm1),mpi_rtype,0,mpi_comm_world,ierror)
      call mpi_barrier(mpi_comm_world,iret2)
 
      call nemsio_close(gfile1,iret=iret)
      call nemsio_close(gfile2,iret=iret)

     do k=1,nsig1o
        if(nvar_id(k).eq.8) then ! AOD 
           kk=levs_id(k)
           if (kk.eq.1) then
              call jcaptrans(z,factsml,z41(1,k))
              call jcaptrans(z2,factsml,z42(1,k))
              call sptez_s(z,grid1,1)
              call sptez_s(z2,grid2,1)
              call unload_grid(grid1,work1(1,k))
              call unload_grid(grid2,work2(1,k))
           end if
        endif
      end do  !End do nsig1o levs


      call grid2sub(work1,sf1,vp1,t1,q1,oz1,cw1,ps1,aod1)
      call grid2sub(work2,sf2,vp2,t2,q2,oz2,cw2,ps2,aod2)

      print *,'aodout',aod1
      write(aodfilunit1) aod1
      write(aodfilunit2) aod2

      call mpi_barrier(mpi_comm_world,iret2)

    end do ! end loop over numaodcases

    close(aodfilunit1)
    close(aodfilunit2)

    call mpi_barrier(mpi_comm_world,iret2)

  end if ! end AOD pairs

  deallocate(taskid)

  return
end subroutine readpairs


subroutine reload(work_in,work_out)
  use kinds, only: r_kind,i_kind
  use variables, only: lat1,lon1,nsig
  implicit none

! Input
  real(r_kind),dimension(lat1*lon1,nsig),intent(in):: work_in   ! 2-d array
! Output
  real(r_kind),dimension(lat1,lon1,nsig),intent(out) :: work_out  ! 3-d array
  integer(i_kind) i,j,k,ij

  do k=1,nsig
     ij=0
     do j=1,lon1
        do i=1,lat1
           ij=ij+1
           work_out(i,j,k)=work_in(ij,k)
        end do
     end do
  end do

  return
end subroutine reload


  subroutine sigio_cnvtdv2(im,ix,km,idvc,idvm,ntrac,iret,t,q,cpi,cnflg)
    use kinds, only: r_kind
    use variables, only: zero,one,fv
    implicit none
    integer,intent(in):: im,ix,km,ntrac,cnflg,idvc,idvm
    integer,intent(out):: iret
    real(r_kind),intent(in)          :: q(ix,km,ntrac), cpi(0:ntrac)
    real(r_kind),intent(inout)       :: t(ix,km)
    integer                  :: thermodyn_id, n
    real(r_kind)                     :: xcp(ix,km), sumq(ix,km)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    thermodyn_id = mod(IDVM/10,10)
!
    iret = 0

    if (thermodyn_id == 3 .and. idvc == 3) then
      xcp(1:im,:)  = zero
      sumq(1:im,:) = zero
      do n=1,NTRAC
        if( cpi(n) .ne. zero) then
           xcp(1:im,:)  = xcp(1:im,:)  + q(1:im,:,n) * cpi(n)
           sumq(1:im,:) = sumq(1:im,:) + q(1:im,:,n)
        endif
      enddo
      xcp(1:im,:)  = (one-sumq(1:im,:))*cpi(0) + xcp(1:im,:)   ! Mean Cp
!
    else
      xcp(1:im,:) = one + fv*Q(1:im,:,1)        ! Virt factor
    endif
    if (cnflg > 0) then
      t(1:im,:) = t(1:im,:) / xcp(1:im,:)
    else
      t(1:im,:) = t(1:im,:) * xcp(1:im,:)
    endif
!
    return
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  end subroutine sigio_cnvtdv2
