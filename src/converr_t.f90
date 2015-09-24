module converr_t
!$$$   module documentation block
!                .      .    .                                       .
! module:    converr_t
!   prgmmr: su          org: np2                date: 2007-03-15
! abstract:  This module contains variables and routines related
!            to the assimilation of conventional observations error to read
!            temperature error table, the structure is different from current
!            one, the first 
!
! program history log:
!   2007-03-15  su  - original code - move reading observation error table 
!                                     from read_prepbufr to here so all the 
!                                     processor can have the new error information 
!
! Subroutines Included:
!   sub converr_t_read      - allocate arrays for and read in conventional error table 
!   sub converr_t_destroy   - destroy conventional error arrays
!
! Variable Definitions:
!   def etabl_t             -  the array to hold the error table
!   def ptabl_t             -  the array to have vertical pressure values
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$ end documentation block

use kinds, only:r_kind,i_kind,r_single
use constants, only: zero
use obsmod, only : oberrflg2 
implicit none

! set default as private
  private
! set subroutines as public
  public :: converr_t_read
  public :: converr_t_destroy
! set passed variables as public
  public :: etabl_t,ptabl_t,isuble_t,maxsub_t

  integer(i_kind),save:: ietabl_t,itypex,itypey,lcount,iflag,k,m,n,maxsub_t
  real(r_single),save,allocatable,dimension(:,:,:) :: etabl_t
  real(r_kind),save,allocatable,dimension(:)  :: ptabl_t
  integer(i_kind),save,allocatable,dimension(:,:)  :: isuble_t

contains


  subroutine converr_t_read(mype)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    converr_t_read      read error table 
!
!     prgmmr:    su    org: np2                date: 2007-03-15
!
! abstract:  This routine reads the conventional error table file
!
! program history log:
!   2008-06-04  safford -- add subprogram doc block
!   2013-05-14  guo     -- add status and iostat in open, to correctly
!                          handle the error case of "obs error table not
!                          available to 3dvar".
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language:  f90
!   machine:   ibm RS/6000 SP
!
!$$$ end documentation block
     use constants, only: half
     implicit none

     integer(i_kind),intent(in   ) :: mype

     integer(i_kind):: ier

     maxsub_t=5
     allocate(etabl_t(100,33,6),isuble_t(100,5))

     etabl_t=1.e9_r_kind
      
     ietabl_t=19
     open(ietabl_t,file='errtable_t',form='formatted',status='old',iostat=ier)
     if(ier/=0) then
        write(6,*)'CONVERR_t:  ***WARNING*** obs error table ("errtable") not available to 3dvar.'
        lcount=0
        oberrflg2=.false.
        return
     endif

     rewind ietabl_t
     etabl_t=1.e9_r_kind
     lcount=0
     loopd : do 
        read(ietabl_t,100,IOSTAT=iflag,end=120) itypey
        if( iflag /= 0 ) exit loopd
100     format(1x,i3)
        lcount=lcount+1
        itypex=itypey-99
        read(ietabl_t,105,IOSTAT=iflag,end=120) (isuble_t(itypex,n),n=1,5)
105     format(8x,5i12)
        do k=1,33
           read(ietabl_t,110)(etabl_t(itypex,k,m),m=1,6)
110        format(1x,6e12.5)
        end do
     end do   loopd
120  continue

     if(lcount<=0 .and. mype==0) then
        write(6,*)'CONVERR_T:  ***WARNING*** obs error table not available to 3dvar.'
        oberrflg2=.false.
     else
        if(mype == 0) then
           write(6,*)'CONVERR_T:  using observation errors from user provided table'
           write(6,105) (isuble_t(21,m),m=1,5)
           do k=1,33
              write(6,110) (etabl_t(21,k,m),m=1,6)
           enddo
        endif
        allocate(ptabl_t(34))
        ptabl_t=zero
        ptabl_t(1)=etabl_t(20,1,1)
        do k=2,33
           ptabl_t(k)=half*(etabl_t(120,k-1,1)+etabl_t(120,k,1))
        enddo
        ptabl_t(34)=etabl_t(20,33,1)
     endif

     close(ietabl_t)

     return
  end subroutine converr_t_read


subroutine converr_t_destroy
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    converr_t_destroy      destroy conventional information file
!     prgmmr:    su    org: np2                date: 2007-03-15
!
! abstract:  This routine destroys arrays from converr_t file
!
! program history log:
!   2007-03-15  su 
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp
!
!$$$
     implicit none

     deallocate(etabl_t,ptabl_t,isuble_t)
     return
  end subroutine converr_t_destroy

end module converr_t



