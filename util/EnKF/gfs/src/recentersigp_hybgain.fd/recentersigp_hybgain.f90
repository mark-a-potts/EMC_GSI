program recentersigp_hybgain
!$$$  main program documentation block
!
! program:  recentersigp               recenter
!
! prgmmr: whitaker         org: esrl/psd               date: 2009-02-23
!
! abstract:  Recenter nemsio ensemble analysis files about 
!            new mean, computed from blended 3DVar and EnKF increments.
!
! program history log:
!   2019-02-10  Initial version.
!
! usage:
!   input files:
!
!   output files:
!
! attributes:
!   language: f95
!
!
!$$$

  use nemsio_module, only:  nemsio_init,nemsio_open,nemsio_close
  use nemsio_module, only:  nemsio_gfile,nemsio_getfilehead,nemsio_readrec,&
       nemsio_writerec,nemsio_readrecv,nemsio_writerecv,nemsio_getrechead

  implicit none

  include "mpif.h"

  character*500 filename_fg,filename_anal1,filename_anal2,filenamein,filenameout,filename_anal
  character*3 charnanal
  character(len=4) charnin
  character(16),dimension(:),allocatable:: fieldname_anal1,fieldname_anal2,fieldname_fg
  character(16),dimension(:),allocatable:: fieldlevtyp_anal1,fieldlevtyp_anal2,fieldlevtyp_fg
  integer,dimension(:),allocatable:: fieldlevel_anal1,fieldlevel_anal2,fieldlevel_fg,order_anal1,order_anal2
  integer iret,mype,mype1,npe,nanals,ierr,ialpha,ibeta
  integer:: nrec,nlats,nlons,nlevs,npts,n,i,k,nn
  real alpha,beta
  real,allocatable,dimension(:,:) :: rwork_anal1,rwork_anal2,rwork_fg,rwork_anal

  type(nemsio_gfile) :: gfilei, gfileo, gfile_anal, gfile_fg, gfile_anal1, gfile_anal2

! Initialize mpi
  call MPI_Init(ierr)

! mype is process number, npe is total number of processes.
  call MPI_Comm_rank(MPI_COMM_WORLD,mype,ierr)
  call MPI_Comm_size(MPI_COMM_WORLD,npe,ierr)

  if (mype==0) call w3tagb('RECENTERSIGP_HYBGAIN',2011,0319,0055,'NP25')

  call getarg(1,filename_fg)    ! first guess ensmean background nemsio file
  call getarg(2,filename_anal1) ! 3dvar analysis
  call getarg(3,filename_anal2) ! enkf mean analysis
  call getarg(4,filename_anal)  ! blended analysis (to recenter ensemble around)
  call getarg(5,filenamein) ! prefix for input ens member files (append _mem###)
  call getarg(6,filenameout) ! prefix for output ens member files (append _mem###)
! blending coefficients
  call getarg(7,charnin)
  read(charnin,'(i4)') ialpha ! wt for anal1 (3dvar)
  alpha = ialpha/1000.
  call getarg(8,charnin)
  read(charnin,'(i4)') ibeta ! wt for anal2 (enkf)
  beta = ibeta/1000.
! new_anal = fg + alpha*(anal1-fg) + beta(anal2-fg)
!          = (1.-alpha-beta)*fg + alpha*anal1 + beta*anal2
! how many ensemble members to process
  call getarg(9,charnin)
  read(charnin,'(i4)') nanals

  if (mype==0) then
     write(6,*)'RECENTERSIGP_HYBGAIN:  PROCESS ',nanals,' ENSEMBLE MEMBERS'
     write(6,*)'ens mean background in ',trim(filename_fg)
     write(6,*)'3dvar analysis in ',trim(filename_anal1)
     write(6,*)'EnKF mean analysis in',trim(filename_anal2)
     write(6,*)'Blended mean analysis to be written to ',trim(filename_anal)
     write(6,*)'Prefix for member input files ',trim(filenameout)
     write(6,*)'Prefix for member output files ',trim(filenameout)
     write(6,*)'3dvar weight, EnKF weight =',alpha,beta
  endif

  mype1 = mype+1
  if (mype1 <= nanals) then
     call nemsio_init(iret=iret)
     call nemsio_open(gfile_fg,trim(filename_fg),'READ',iret=iret)
     if (iret == 0 ) then
        write(6,*)'Read nemsio ',trim(filename_fg),' iret=',iret
        call nemsio_getfilehead(gfile_fg, nrec=nrec, dimx=nlons, dimy=nlats, dimz=nlevs, iret=iret)
        write(6,*)' nlons=',nlons,' nlats=',nlats,' nlevs=',nlevs,' nrec=',nrec
     else
        write(6,*)'***ERROR*** ',trim(filename_fg),' contains unrecognized format.  ABORT'
     endif

     ! readin in 3dvar, enkf analyses, plus ens mean background, blend
     call nemsio_open(gfile_anal1,trim(filename_anal1),'READ',iret=iret)
     if (iret .ne. 0) then
       print *,'error opening ',trim(filename_anal1)
       call MPI_Abort(MPI_COMM_WORLD,98,iret)
       stop
     endif
     call nemsio_open(gfile_anal2,trim(filename_anal2),'READ',iret=iret)
     if (iret .ne. 0) then
       print *,'error opening ',trim(filename_anal2)
       call MPI_Abort(MPI_COMM_WORLD,98,iret)
       stop
     endif
     gfile_anal=gfile_anal2 ! use header for enkf analysis
     call nemsio_open(gfile_anal,trim(filename_anal),'WRITE',iret=iret)
     if (iret .ne. 0) then
       print *,'error opening ',trim(filename_anal)
       call MPI_Abort(MPI_COMM_WORLD,98,iret)
       stop
     endif

     npts=nlons*nlats
     allocate(rwork_anal1(npts,nrec),rwork_anal2(npts,nrec),rwork_fg(npts,nrec),rwork_anal(npts,nrec))

     allocate(fieldname_anal1(nrec), fieldlevtyp_anal1(nrec),fieldlevel_anal1(nrec))
     allocate(fieldname_anal2(nrec), fieldlevtyp_anal2(nrec),fieldlevel_anal2(nrec))
     allocate(fieldname_fg(nrec), fieldlevtyp_fg(nrec),fieldlevel_fg(nrec))
     allocate(order_anal1(nrec))
     allocate(order_anal2(nrec))

     do n=1,nrec
        call nemsio_readrec(gfile_fg,n,rwork_fg(:,n),iret=iret) ! member analysis
        if (iret .ne. 0) then
          print *,'error reading rec ',n,trim(filename_fg)
          call MPI_Abort(MPI_COMM_WORLD,98,iret)
          stop
        endif
        call nemsio_getrechead(gfile_fg,n,fieldname_fg(n),fieldlevtyp_fg(n),fieldlevel_fg(n),iret=iret)
     end do
     do n=1,nrec
        call nemsio_readrec(gfile_anal1,n,rwork_anal1(:,n),iret=iret) ! member analysis
        if (iret .ne. 0) then
          print *,'error reading rec ',n,trim(filename_anal1)
          call MPI_Abort(MPI_COMM_WORLD,98,iret)
          stop
        endif
        call nemsio_getrechead(gfile_anal1,n,fieldname_anal1(n),fieldlevtyp_anal1(n),fieldlevel_anal1(n),iret=iret)
     end do
     do n=1,nrec
        call nemsio_readrec(gfile_anal2,n,rwork_anal2(:,n),iret=iret) ! member analysis
        if (iret .ne. 0) then
          print *,'error reading rec ',n,trim(filename_anal2)
          call MPI_Abort(MPI_COMM_WORLD,98,iret)
          stop
        endif
        call nemsio_getrechead(gfile_anal2,n,fieldname_anal2(n),fieldlevtyp_anal2(n),fieldlevel_anal2(n),iret=iret)
     end do
     call getorder(fieldname_fg,fieldname_anal1,fieldlevtyp_fg,fieldlevtyp_anal1,fieldlevel_fg,fieldlevel_anal1,nrec,order_anal1)
     call getorder(fieldname_fg,fieldname_anal2,fieldlevtyp_fg,fieldlevtyp_anal2,fieldlevel_fg,fieldlevel_anal2,nrec,order_anal2)

     do n=1,nrec
!     print *,n,order_anal1(n),order_anal2(n),minval(rwork_anal1(:,order_anal1(n))),&
!     maxval(rwork_anal1(:,order_anal1(n))),minval(rwork_anal2(:,order_anal2(n))),&
!     maxval(rwork_anal2(:,order_anal2(n)))
        do i=1,npts
          rwork_anal(i,n) = (1.-alpha-beta)*rwork_fg(i,n) + &
                            alpha*rwork_anal1(i,order_anal1(n)) + &
                            beta*rwork_anal2(i,order_anal2(n))
        end do
     end do
   
     ! write out blended analysis on root task.
     if (mype .eq. 0) then
        do n=1,nrec
           call nemsio_writerec(gfile_anal,n,rwork_anal(:,n),iret=iret)
           if (iret .ne. 0) then
             print *,'error writing rec ',n,trim(filename_anal)
             call MPI_Abort(MPI_COMM_WORLD,98,iret)
             stop
           endif
        end do
     endif
   
     call nemsio_close(gfile_fg,iret=iret)
     call nemsio_close(gfile_anal1,iret=iret)
     call nemsio_close(gfile_anal2,iret=iret)
   
     if (iret .ne. 0) then
       print *,'error getting header info from ',trim(filename_fg)
       call MPI_Abort(MPI_COMM_WORLD,98,iret)
       stop
     endif


     call nemsio_open(gfilei,trim(filenamein)//"_mem"//charnanal,'READ',iret=iret)
     gfileo=gfile_anal
     call nemsio_open(gfileo,trim(filenameout)//"_mem"//charnanal,'WRITE',iret=iret)

     ! fill *_anal1 with 'old' ens members
     do n=1,nrec
        call nemsio_readrec(gfilei, n,rwork_anal1(:,n),iret=iret) ! member analysis
        call nemsio_getrechead(gfilei,n,fieldname_anal1(n),fieldlevtyp_anal1(n),fieldlevel_anal1(n),iret=iret)
     end do
     call getorder(fieldname_fg,fieldname_anal1,fieldlevtyp_fg,fieldlevtyp_anal1,fieldlevel_fg,fieldlevel_anal1,nrec,order_anal1)
     ! *_anal2 already contains old enkf mean
     ! *_anal contains new enkf mean
     ! use ordering of fields from ens mean background

!    Recenter ensemble member about new mean 
     do n=1,nrec
        do i=1,npts
           rwork_fg(i,n) = rwork_anal1(i,order_anal1(n)) - rwork_anal2(i,order_anal2(n)) + rwork_anal(i,n)
        end do
     end do

!    Write recentered member analysies using ordering of first guess ensmean fields.
     do n=1,nrec
        call nemsio_writerec(gfileo,n,rwork_fg(:,n),iret=iret)
        if (iret .ne. 0) then
          print *,'error writing rec ',n,trim(filename_anal)
          call MPI_Abort(MPI_COMM_WORLD,98,iret)
          stop
        endif
     end do
     deallocate(rwork_anal1,rwork_anal2,rwork_fg,rwork_anal)
     deallocate(fieldname_anal1, fieldlevtyp_anal1,fieldlevel_anal1)
     deallocate(fieldname_anal2, fieldlevtyp_anal2,fieldlevel_anal2)
     deallocate(fieldname_fg, fieldlevtyp_fg,fieldlevel_fg)
     deallocate(order_anal1,order_anal2)

     call nemsio_close(gfile_anal,iret=iret)
     call nemsio_close(gfilei,iret=iret)
     call nemsio_close(gfileo,iret=iret)
     write(6,*)'task mype=',mype,' process ',trim(filenameout)//"_mem"//charnanal,' iret=',iret

! Jump here if more mpi processors than files to process
  else
     write (6,*) 'no files to process for mpi task = ',mype
  end if  ! end if mype

100 continue
  call MPI_Barrier(MPI_COMM_WORLD,ierr)

  if (mype==0) call w3tage('RECENTERSIGP_HYBGAIN')

  call MPI_Finalize(ierr)
  if (mype .eq. 0 .and. ierr .ne. 0) then
     print *, 'MPI_Finalize error status = ',ierr
  end if

END program recentersigp_hybgain

subroutine getorder(flnm1,flnm2,fllevtyp1,fllevtyp2,fllev1,fllev2,nrec,order)
  integer nrec
  character(16):: flnm1(nrec),flnm2(nrec),fllevtyp1(nrec),fllevtyp2(nrec)
  integer ::  fllev1(nrec),fllev2(nrec)
  integer, intent(out) ::  order(nrec)

  integer i,j

  order=0
  do i=1,nrec
     doloopj: do j=1,nrec
        if(flnm1(i)==flnm2(j).and.fllevtyp1(i)==fllevtyp2(j).and.fllev1(i)==fllev2(j)) then
           order(i)=j
           exit doloopj
        endif
     enddo doloopj
  enddo

end subroutine getorder
