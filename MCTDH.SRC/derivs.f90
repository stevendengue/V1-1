
!! OPERATION OF MEAN FIELD ON ORBITALS : "DERIVS" ARE DERIVATIVES
!!  OF ORBITALS WRT TIME.  SPF_LINEAR_DERIVS IS MAIN GUY
!!  (DOES LMF -- QMF ETC PROBABLY BROKEN)
!! 
!! IF YOU WANT TO OPERATE WITH REDUCED HAMILTONIAN YOURSELF,
!!  USE ACTREDUCED.

#include "Definitions.INC"

module derivtimingmod
  implicit none
  integer :: times(20)=0,numcalledhere=0
end module derivtimingmod


!! WITH TIMEFAC

subroutine getconmat(thistime,ireduced,conmat)
  use parameters
  use xxxmod
  implicit none
  integer, intent(in) :: ireduced
  real*8, intent(in) ::  thistime 
  DATATYPE, intent(out) :: conmat(nspf,nspf)
  DATATYPE :: pots(3)

  if (constraintflag.eq.0) then
     conmat(:,:)=0d0
     return
  endif

  conmat(:,:) =   yyy%cptr(ireduced)%xconmatel(:,:) * timefac
  if (tdflag.ne.0) then
     call vectdpot(thistime,velflag,pots,-1)
     conmat(:,:) =   conmat(:,:) + &
          yyy%cptr(ireduced)%xconmatelxx(:,:) *pots(1) * timefac + &
          yyy%cptr(ireduced)%xconmatelyy(:,:) *pots(2) * timefac + &
          yyy%cptr(ireduced)%xconmatelzz(:,:) *pots(3) * timefac
  endif

end subroutine getconmat


module derivativemod
contains

!! for derivative of PROJECTOR using derivative of spfs.     
!!      on call inspfs is for example jacvectout

  subroutine derproject00(lowspf,highspf,inspfs, outspfs, prospfs, prospfderivs)
    use parameters
    use jactimingmod
    implicit none
    integer,intent(in) :: lowspf,highspf
    DATATYPE, intent(in) :: inspfs(spfsize, lowspf:highspf), &
         prospfs(spfsize, nspf),  prospfderivs(spfsize, nspf)
    DATATYPE, intent(out) :: outspfs(spfsize, lowspf:highspf)
    DATATYPE :: csum
    DATATYPE :: mydot(nspf,lowspf:highspf+1), prodot(nspf,nspf), &
         derdot(nspf,lowspf:highspf+1) !! AUTOMATIC
    integer :: i,j,numspf,itime,jtime

    numspf=highspf-lowspf+1

    if (numspf.gt.0) then
       outspfs(:,:)=0.d0
    endif

    call system_clock(itime)

    mydot(:,:)=0d0; derdot(:,:)=0d0

!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(i,j)
!$OMP DO SCHEDULE(STATIC) COLLAPSE(2)
    do i=lowspf,highspf
       do j=1,nspf
          mydot(j,i) = dot(prospfs(:,j),inspfs(:,i),spfsize)
          derdot(j,i) = dot(prospfderivs(:,j),inspfs(:,i),spfsize)
       enddo
    enddo
!$OMP END DO
!$OMP END PARALLEL

    call system_clock(jtime); times(3)=times(3)+jtime-itime;     itime=jtime

    if (parorbsplit.eq.3) then
       call mympireduce(mydot,nspf**2)
       call mympireduce(derdot,nspf**2)
    endif

    call system_clock(jtime); times(4)=times(4)+jtime-itime;     itime=jtime

    if (numspf.gt.0) then
       call MYGEMM('N','N',spfsize,numspf,nspf,DATAONE,prospfs,spfsize,&
            derdot(:,lowspf:highspf),nspf,DATAONE,outspfs,spfsize)
       call MYGEMM('N','N',spfsize,numspf,nspf,DATAONE,prospfderivs,spfsize,&
            mydot(:,lowspf:highspf), nspf,DATAONE,outspfs,spfsize)
    endif

    call system_clock(jtime); times(3)=times(3)+jtime-itime;

    if (jacprojorth.ne.0) then

       call system_clock(itime)

!! Proj in always-orthogonal-derivative form,
!!
!!  P = sum_ij | prospf_i > (S^-1)_ij < prospf_j |
!!
!!  where S=delta_ij = <jacvect_i | jacvect_j>
!!
!!  (dS)_ij = <dphi_i | jacvect_j> + <jacvect_i | dphi_j>
!!
!!  (dS^-1)_ij = - <dphi_i | jacvect_j> - <jacvect_i | dphi_j>  at S=1
!!

!        prodot is     (pro/proder,pro/proder)

! need all nspf^2 even if parorbsplit.eq.1

       prodot(:,:)=0d0

!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(i,j,csum)
!$OMP DO SCHEDULE(STATIC) COLLAPSE(2)
       do i=lowspf,highspf
          do j=1,nspf
             csum = dot(prospfs(:,j),prospfderivs(:,i),spfsize) + &
                  dot(prospfderivs(:,j),prospfs(:,i),spfsize)
             prodot(j,i) = csum
          enddo
       enddo
!$OMP END DO
!$OMP END PARALLEL

       call system_clock(jtime); times(3)=times(3)+jtime-itime;     itime=jtime

       if (parorbsplit.eq.1) then
          call mpiorbgather(prodot,nspf)
       endif
       if (parorbsplit.eq.3) then
          call mympireduce(prodot,nspf**2)
       endif

       call system_clock(jtime); times(4)=times(4)+jtime-itime;     itime=jtime

       if (numspf.gt.0) then
          call MYGEMM('N', 'N', nspf, numspf, nspf, DATAONE, prodot, nspf, &
               mydot(:,lowspf:highspf), nspf, DATAZERO, derdot(:,lowspf:highspf), nspf)
          
          call MYGEMM('N', 'N', spfsize, numspf, nspf, DATANEGONE, prospfs, spfsize, &
               derdot(:,lowspf:highspf), nspf, DATAONE, outspfs, spfsize)
       endif

       call system_clock(jtime); times(3)=times(3)+jtime-itime

    endif

  end subroutine derproject00

!! subroutine derproject not used currently only derproject00

  subroutine derproject(inspfs, outspfs, prospfs, prospfderivs)
    use parameters
    implicit none
    DATATYPE, intent(in) :: inspfs(spfsize, nspf), prospfs(spfsize, nspf),&
         prospfderivs(spfsize, nspf)
    DATATYPE, intent(out) :: outspfs(spfsize, nspf)
    integer :: lowspf,highspf

    lowspf=1; highspf=nspf
    if (parorbsplit.eq.1) then
       call getOrbSetRange(lowspf,highspf)
    endif

!! always call derproject00
    call derproject00(lowspf,highspf,inspfs(:,min(lowspf,nspf):highspf),&
         outspfs(:,min(lowspf,nspf):highspf),prospfs,prospfderivs)

    if (parorbsplit.eq.1) then
       call mpiorbgather(outspfs,spfsize)
    endif

  end subroutine derproject

  subroutine der_gmat00(lowspf,highspf,inspfs, outspfs, &
       ireduced,thistime,prospfs, prospfderivs)
    use parameters
    implicit none
    integer, intent(in) :: ireduced,lowspf,highspf
    real*8, intent(in) :: thistime
    DATATYPE, intent(in) :: inspfs(spfsize, nspf), prospfs(spfsize, nspf),  &
         prospfderivs(spfsize, nspf)
    DATATYPE, intent(out) :: outspfs(spfsize, lowspf:highspf)
    integer :: i,j,numspf
    DATATYPE :: mydot(nspf,lowspf:highspf+1), &
         derdot(nspf,lowspf:highspf+1), &            !!  AUTOMATIC
         mydot0(nspf,lowspf:highspf+1), &
         derdot0(nspf,lowspf:highspf+1), conmat(nspf,nspf)

    numspf=highspf-lowspf+1

    if (numspf.gt.0) then
       outspfs(:,:)=0.d0
    endif

    if (constraintflag.eq.0) then
       return
    endif

    mydot0(:,:)=0d0; derdot0(:,:)=0d0

!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(i,j)
!$OMP DO SCHEDULE(STATIC) COLLAPSE(2)
    do i=lowspf,highspf
       do j=1,nspf
          mydot0(j,i) = dot(prospfs(:,j),inspfs(:,i),spfsize)
          derdot0(j,i) = dot(prospfderivs(:,j),inspfs(:,i),spfsize)
       enddo
    enddo
!$OMP END DO
!$OMP END PARALLEL

    if (parorbsplit.eq.3) then
       call mympireduce(mydot0,nspf**2)
       call mympireduce(derdot0,nspf**2)
    endif

    call getconmat(thistime,ireduced,conmat)
    
    if (numspf.gt.0) then
       call MYGEMM('N','N',nspf,numspf,nspf,DATAONE,conmat,nspf,&
            mydot0(:,lowspf:highspf),nspf,DATAZERO,mydot(:,lowspf:highspf),nspf)
       call MYGEMM('N','N',nspf,numspf,nspf,DATAONE,conmat,nspf,&
            derdot0(:,lowspf:highspf),nspf,DATAZERO,derdot(:,lowspf:highspf),nspf)

       call MYGEMM('N','N',spfsize,numspf,nspf,DATAONE,prospfs,     spfsize,&
            derdot(:,lowspf:highspf),nspf,DATAZERO,outspfs,spfsize)
       call MYGEMM('N','N',spfsize,numspf,nspf,DATAONE,prospfderivs,spfsize,&
            mydot(:,lowspf:highspf), nspf,DATAONE,outspfs,spfsize)
    endif

  end subroutine der_gmat00

  subroutine der_gmat(inspfs, outspfs, ireduced,thistime,prospfs, prospfderivs)
    use parameters
    implicit none
    integer, intent(in) :: ireduced
    real*8, intent(in) :: thistime
    DATATYPE, intent(in) :: inspfs(spfsize, nspf), prospfs(spfsize, nspf),  &
         prospfderivs(spfsize, nspf)
    DATATYPE, intent(out) :: outspfs(spfsize, nspf)
    integer :: lowspf,highspf,numspf
    
    lowspf=1; highspf=nspf
    if (parorbsplit.eq.1) then
       call getOrbSetRange(lowspf,highspf)
    endif

    numspf=highspf-lowspf+1

    if (numspf.gt.0) then
       call der_gmat00(lowspf,highspf,inspfs,outspfs(:,lowspf:highspf),&
            ireduced,thistime,prospfs,prospfderivs)
    endif

    if (parorbsplit.eq.1) then
       call mpiorbgather(outspfs,spfsize)
    endif

  end subroutine der_gmat

!! WITH TIMEFAC

  subroutine op_gmat_firstorder00(lowspf,highspf,inspfs, outspfs, ireduced,thistime)
    use parameters
    implicit none
    integer,intent(in) :: lowspf,highspf,ireduced
    real*8, intent(in) ::  thistime 
    DATATYPE, intent(in) :: inspfs(spfsize,nspf)
    DATATYPE, intent(out) :: outspfs(spfsize,lowspf:highspf)
    DATATYPE :: conmat(nspf,nspf)        !! AUTOMATIC
    integer :: numspf

    numspf=highspf-lowspf+1

    if (constraintflag.eq.0) then
       if (numspf.gt.0) then
          outspfs(:,:)=0d0
       endif
       return
    endif

!! with timefac
    call getconmat(thistime,ireduced,conmat)

    if (numspf.gt.0) then
       call MYGEMM('N','N',spfsize,numspf,nspf,DATAONE,inspfs,&
            spfsize,conmat(:,lowspf:highspf),&
            nspf,DATAZERO,outspfs(:,lowspf:highspf),spfsize)
    endif

  end subroutine op_gmat_firstorder00

  subroutine op_gmat_thirdorder00(lowspf,highspf,inspfs, outspfs, &
       ireduced,thistime,projspfs)
    use parameters
    implicit none
    integer,intent(in) :: lowspf,highspf,ireduced
    real*8, intent(in) ::  thistime 
    DATATYPE, intent(in) :: inspfs(spfsize,nspf), projspfs(spfsize,nspf)
    DATATYPE, intent(out) :: outspfs(spfsize,lowspf:highspf)
    DATATYPE :: conmat(nspf,nspf), mydot(nspf,nspf), mymat(nspf,nspf)    !! AUTOMATIC
    integer :: i,j,numspf

    numspf=highspf-lowspf+1

    if (constraintflag.eq.0) then
       if (numspf.gt.0) then
          outspfs(:,:)=0d0
       endif
       return
    endif

    mydot(:,:)=0d0

!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(i,j)
!$OMP DO SCHEDULE(STATIC) COLLAPSE(2)
    do i=1,lowspf,highspf
       do j=1,nspf
          mydot(j,i)=dot(projspfs(:,j),inspfs(:,i),spfsize)
       enddo
    enddo
!$OMP END DO
!$OMP END PARALLEL

    if (parorbsplit.eq.3) then
       call mympireduce(mydot,nspf**2)
    endif

!! with timefac
    call getconmat(thistime,ireduced,conmat)

    if (numspf.gt.0) then
       call MYGEMM('N','N',nspf,numspf,nspf,DATAONE,conmat,nspf,&
            mydot(:,lowspf:highspf),nspf,DATAZERO,mymat(:,lowspf:highspf),nspf)

       call MYGEMM('N','N',spfsize,numspf,nspf,DATAONE,projspfs,spfsize,&
            mymat(:,lowspf:highspf),nspf,DATAZERO,outspfs(:,lowspf:highspf),&
            spfsize)
    endif

  end subroutine op_gmat_thirdorder00

  subroutine op_gmat00(lowspf,highspf,inspfs, outspfs, ireduced,thistime,projspfs)
    use parameters
    implicit none
    integer, intent(in) :: lowspf,highspf,ireduced
    real*8, intent(in) ::  thistime 
    DATATYPE, intent(in) :: inspfs(spfsize,nspf), projspfs(spfsize,nspf)
    DATATYPE, intent(out) :: outspfs(spfsize,lowspf:highspf)

    if (jacgmatthird.eq.0) then
       call op_gmat_firstorder00(lowspf,highspf,inspfs, outspfs, ireduced, thistime)
    else
       call op_gmat_thirdorder00(lowspf,highspf,inspfs, outspfs, &
            ireduced, thistime,projspfs)
    endif

  end subroutine op_gmat00

!! WITH TIMEFAC

  subroutine op_gmat(inspfs, outspfs, ireduced,thistime,projspfs)
    use parameters
    implicit none
    integer, intent(in) :: ireduced
    real*8, intent(in) ::  thistime 
    DATATYPE, intent(in) :: inspfs(spfsize,nspf), projspfs(spfsize,nspf)
    DATATYPE, intent(out) :: outspfs(spfsize,nspf)
    integer :: lowspf,highspf,numspf

    lowspf=1; highspf=nspf
    if (parorbsplit.eq.1) then
       call getOrbSetRange(lowspf,highspf)
    endif
    
    numspf=highspf-lowspf+1
    if (numspf.gt.0) then
       call op_gmat00(lowspf,highspf,inspfs, outspfs(:,lowspf:highspf), &
            ireduced,thistime,projspfs)
    endif

    if (parorbsplit.eq.1) then
       call mpiorbgather(outspfs,spfsize)
    endif

  end subroutine op_gmat

  subroutine wmult00(lowspf,highspf,inspfs, outspfs, ireduced)
    use parameters
    use xxxmod
    implicit none
    integer,intent(in) :: lowspf,highspf,ireduced
    DATATYPE, intent(in) :: inspfs(spfsize,nspf)
    DATATYPE, intent(out) :: outspfs(spfsize,lowspf:highspf)
    DATATYPE :: workmult(spfsize,lowspf:highspf+1), &
         spfinvr( spfsize,lowspf:highspf+1 ),&  !! AUTOMATIC
         spfinvrsq(  spfsize,lowspf:highspf+1), &
         spfproderiv(  spfsize,lowspf:highspf+1 )
    integer :: numspf

    numspf=highspf-lowspf+1

!! sum over fast index reduced matrices, because doing spfinvrsq= reducedinvrsq * inspfs 
!! BUT 1) store in transposed order and 2) have to reverse the call in BLAS

    if (numspf.gt.0) then

       call MYGEMM('N', 'N', spfsize,numspf,nspf,DATAONE, inspfs, spfsize, &
            yyy%reducedinvrsq(:,lowspf:highspf,ireduced),&
            nspf,DATAZERO, spfinvrsq(:,lowspf:highspf), spfsize)
       call MYGEMM('N', 'N', spfsize,numspf,nspf,DATAONE, inspfs, spfsize, &
            yyy%reducedinvr(:,lowspf:highspf,ireduced),&
            nspf, DATAZERO, spfinvr(:,lowspf:highspf), spfsize)
       if ((nonuc_checkflag.eq.0)) then
          call MYGEMM('N', 'N', spfsize,numspf,nspf,DATAONE, inspfs, spfsize, &
               yyy%reducedproderiv(:,lowspf:highspf,ireduced),&
               nspf, DATAZERO, spfproderiv(:,lowspf:highspf), spfsize)
       endif
  
       outspfs(:,:)=0.d0

       call mult_ke(spfinvrsq(:,lowspf:highspf),outspfs(:,lowspf:highspf),&
            numspf,timingdir,notiming)

       call mult_pot(numspf,spfinvr(:,lowspf:highspf),workmult(:,lowspf:highspf))
       outspfs(:,lowspf:highspf)=outspfs(:,lowspf:highspf)+workmult(:,lowspf:highspf)

       if ((nonuc_checkflag.eq.0)) then
          call op_yderiv(numspf,spfproderiv(:,lowspf:highspf),workmult(:,lowspf:highspf))
          outspfs(:,lowspf:highspf)=outspfs(:,lowspf:highspf) + workmult(:,lowspf:highspf)
       endif

       call mult_reducedpot(lowspf,highspf,inspfs(:,lowspf:highspf),&
            workmult(:,lowspf:highspf),yyy%reducedpot(:,:,:,ireduced))
       outspfs(:,lowspf:highspf)=outspfs(:,lowspf:highspf)+workmult(:,lowspf:highspf)

    endif

  end subroutine wmult00

  subroutine wmult(inspfs, outspfs, ireduced)
    use parameters
    implicit none
    DATATYPE, intent(in) :: inspfs(spfsize,nspf)
    DATATYPE, intent(out) :: outspfs(spfsize,nspf)
    integer,intent(in) :: ireduced
    integer :: lowspf,highspf,numspf

    lowspf=1; highspf=nspf
    if (parorbsplit.eq.1) then
       call getOrbSetRange(lowspf,highspf)
    endif

    numspf=highspf-lowspf+1
    if (numspf.gt.0) then
       call wmult00(lowspf,highspf,inspfs, outspfs(:,lowspf:highspf), ireduced)
    endif

    if (parorbsplit.eq.1) then
       call mpiorbgather(outspfs,spfsize)
    endif

  end subroutine wmult

  subroutine denmult00(lowspf,highspf,inspfs, outspfs, ireduced)
    use parameters
    use xxxmod
    implicit none
    integer,intent(in) :: lowspf,highspf,ireduced
    DATATYPE,intent(in) :: inspfs(spfsize,nspf)
    DATATYPE,intent(out) :: outspfs(spfsize,lowspf:highspf)
    integer :: numspf

    numspf=highspf-lowspf+1

    if (numspf.gt.0) then
       call MYGEMM('N','N', spfsize,numspf,nspf,DATAONE, inspfs,spfsize, &
            yyy%denmat(:,lowspf:highspf,ireduced), nspf, DATAZERO, outspfs, &
            spfsize) 
       outspfs=outspfs/numelec
    endif

  end subroutine denmult00

  subroutine denmult(inspfs, outspfs, ireduced)
    use parameters
    implicit none
    DATATYPE, intent(in) :: inspfs(spfsize,nspf)
    DATATYPE, intent(out) :: outspfs(spfsize,nspf)
    integer,intent(in) :: ireduced
    integer :: lowspf,highspf,numspf

    lowspf=1; highspf=nspf
    if (parorbsplit.eq.1) then
       call getOrbSetRange(lowspf,highspf)
    endif

    numspf=highspf-lowspf+1
    if (numspf.gt.0) then
       call denmult00(lowspf,highspf,inspfs, outspfs(:,lowspf:highspf), ireduced)
    endif

    if (parorbsplit.eq.1) then
       call mpiorbgather(outspfs,spfsize)
    endif

  end subroutine denmult

  subroutine actreduced00(lowspf,highspf,dentimeflag,thistime,inspfs, projspfs, &
       outspfs, ireduced, projflag,conflag)
    use parameters
    use mpimod
    use xxxmod
    use derivtimingmod
    use orbprojectmod
    implicit none
    integer, intent(in) :: lowspf,highspf,dentimeflag,ireduced,projflag,conflag
    real*8, intent(in) :: thistime
    DATATYPE, intent(in) :: inspfs(spfsize, nspf), projspfs(spfsize,nspf)
    DATATYPE,intent(out) :: outspfs(spfsize,lowspf:highspf)
    integer :: itime, jtime, getlen,numspf,myiostat
    DATATYPE :: myxtdpot=0,  myytdpot=0, myztdpot=0, pots(3)=0d0
    DATATYPE :: spfmult(spfsize,nspf),workmult(spfsize,lowspf:highspf+1), &  !! AUTOMATIC
         spfinvr( spfsize,lowspf:highspf+1), spfr( spfsize,lowspf:highspf+1 ),  &
         spfinvrsq(  spfsize,lowspf:highspf+1),spfproderiv(  spfsize,lowspf:highspf+1 )
  
    numspf=highspf-lowspf+1

    if (tdflag.ne.0) then
       call vectdpot(thistime,velflag,pots,-1)
       myxtdpot=pots(1);  myytdpot=pots(2);  myztdpot=pots(3);
    endif

    numcalledhere=numcalledhere+1

    spfmult(:,:)=0.d0

    if (numspf.ne.0) then

!! sum over fast index reduced matrices, because doing spfinvrsq= reducedinvrsq * inspfs 
!!   BUT 1) store in transposed order and 2) have to reverse the call in BLAS
       call system_clock(itime)
       if (numr.eq.1) then
          call MYGEMM('N', 'N', spfsize,numspf,nspf,DATAONE, inspfs, spfsize, &
               yyy%denmat(:,lowspf:highspf,ireduced),nspf, DATAZERO, &
               spfinvrsq(:,lowspf:highspf), spfsize)

          spfinvr(:,lowspf:highspf)=spfinvrsq(:,lowspf:highspf)/bondpoints(1)

          if (tdflag.ne.0) then
             spfr(:,lowspf:highspf)=spfinvrsq(:,lowspf:highspf)*bondpoints(1)
          endif

          if (nonuc_checkflag.eq.0) then
             spfproderiv(:,lowspf:highspf)=spfinvrsq(:,lowspf:highspf)*bondpoints(1)
          endif

          spfinvrsq(:,lowspf:highspf)=spfinvrsq(:,lowspf:highspf)/bondpoints(1)**2

       else
          call MYGEMM('N', 'N', spfsize,numspf,nspf,DATAONE, inspfs, spfsize, &
               yyy%reducedinvrsq(:,lowspf:highspf,ireduced),&
               nspf, DATAZERO, spfinvrsq(:,lowspf:highspf), spfsize)
          call MYGEMM('N', 'N', spfsize,numspf,nspf,DATAONE, inspfs, spfsize, &
               yyy%reducedinvr(:,lowspf:highspf,ireduced),&
               nspf, DATAZERO, spfinvr(:,lowspf:highspf), spfsize)
        
          if (tdflag.ne.0) then
             call MYGEMM('N', 'N', spfsize,numspf,nspf,DATAONE, inspfs, spfsize, &
                  yyy%reducedr(:,lowspf:highspf,ireduced),&
                  nspf, DATAZERO, spfr(:,lowspf:highspf), spfsize)
          endif
     
          if (nonuc_checkflag.eq.0) then
             call MYGEMM('N', 'N', spfsize,numspf,nspf,DATAONE, inspfs, spfsize, &
                  yyy%reducedproderiv(:,lowspf:highspf,ireduced),nspf, DATAZERO, &
                  spfproderiv(:,lowspf:highspf), spfsize)
          endif
       endif
       call system_clock(jtime);  times(1)=times(1)+jtime-itime; itime=jtime

       call mult_ke(spfinvrsq(:,lowspf:highspf),workmult(:,lowspf:highspf),&
            numspf,timingdir,notiming)
       spfmult(:,lowspf:highspf) = spfmult(:,lowspf:highspf) + workmult(:,lowspf:highspf)
       call system_clock(jtime);  times(2)=times(2)+jtime-itime;      itime=jtime

       call mult_pot(numspf,spfinvr(:,lowspf:highspf),workmult(:,lowspf:highspf))
       spfmult(:,lowspf:highspf) = spfmult(:,lowspf:highspf) + workmult(:,lowspf:highspf)
       call hatom_op(numspf,spfinvr(:,lowspf:highspf),workmult(:,lowspf:highspf))
       spfmult(:,lowspf:highspf)=spfmult(:,lowspf:highspf)+workmult(:,lowspf:highspf)

       if (numfrozen.gt.0) then
!! DIRECT ONLY in linear operator actreduced.  Exchange treated like driving term.
          call op_frozenreduced(numspf,spfinvr(:,lowspf:highspf),workmult(:,lowspf:highspf))
          spfmult(:,lowspf:highspf)=spfmult(:,lowspf:highspf)+workmult(:,lowspf:highspf)
       endif
       call system_clock(jtime);     times(3)=times(3)+jtime-itime;      itime=jtime

       if (tdflag.ne.0) then
          select case (velflag)
          case (0)
             call lenmultiply(numspf,spfr(:,lowspf:highspf),workmult(:,lowspf:highspf), &
                  myxtdpot,myytdpot,myztdpot)
             spfmult(:,lowspf:highspf)=spfmult(:,lowspf:highspf)+workmult(:,lowspf:highspf)
          case default
             call velmultiply(numspf,spfinvr(:,lowspf:highspf),workmult(:,lowspf:highspf), &
                  myxtdpot,myytdpot,myztdpot)
             spfmult(:,lowspf:highspf)=spfmult(:,lowspf:highspf)+workmult(:,lowspf:highspf)
          end select
       endif  !! tdpot
       call system_clock(jtime);        times(4)=times(4)+jtime-itime;        itime=jtime
  
       if (nonuc_checkflag.eq.0) then
          call op_yderiv(numspf,spfproderiv(:,lowspf:highspf),workmult(:,lowspf:highspf))
          spfmult(:,lowspf:highspf)=spfmult(:,lowspf:highspf)+workmult(:,lowspf:highspf)
       endif
       call system_clock(jtime);     times(5)=times(5)+jtime-itime;         itime=jtime

       call mult_reducedpot(lowspf,highspf,inspfs,workmult(:,lowspf:highspf),&
            yyy%reducedpot(:,:,:,ireduced))
       spfmult(:,lowspf:highspf)=spfmult(:,lowspf:highspf) + workmult(:,lowspf:highspf)
       call system_clock(jtime);  times(6)=times(6)+jtime-itime;  

    endif

!! WITH TIMEFAC
    if (dentimeflag.ne.0) then
       call system_clock(itime)
       if (parorbsplit.eq.1) then
          call mpiorbgather(spfmult,spfsize)
       endif
       call system_clock(jtime);        times(10)=times(10)+jtime-itime;      itime=jtime
       if (numspf.gt.0) then
          call MYGEMM('N','N', spfsize,numspf,nspf,timefac, spfmult,spfsize, &
               yyy%invdenmat(:,lowspf:highspf,ireduced), nspf, DATAZERO, workmult, spfsize)
          spfmult(:,lowspf:highspf)=workmult(:,lowspf:highspf)
       endif
       call system_clock(jtime);  times(7)=times(7)+jtime-itime
    elseif (numspf.gt.0) then
       spfmult(:,lowspf:highspf) = spfmult(:,lowspf:highspf) * (-1)
    endif

    if (projflag==1) then
       call system_clock(itime)
       if (parorbsplit.eq.1) then
          call mpiorbgather(spfmult,spfsize)
       endif
       call system_clock(jtime);  times(10)=times(10)+jtime-itime;    itime=jtime
       if (numspf.gt.0) then
          call project00(lowspf,highspf,spfmult(:,lowspf:highspf), workmult, projspfs)
          outspfs(:,:) = spfmult(:,lowspf:highspf) - workmult(:,lowspf:highspf)
       endif
       call system_clock(jtime);     times(8)=times(8)+jtime-itime;      
    elseif (numspf.gt.0) then
       outspfs(:,:)=spfmult(:,lowspf:highspf)
    endif
     
    if (constraintflag/=0.and.conflag.ne.0.and.numspf.gt.0) then
       call system_clock(itime)
       call op_gmat00(lowspf,highspf,inspfs,workmult,ireduced,thistime,projspfs)
       outspfs(:,:)=outspfs(:,:)+workmult(:,lowspf:highspf)
       call system_clock(jtime);        times(9)=times(9)+jtime-itime
    endif

    if ((myrank.eq.1).and.(notiming.eq.0)) then
       if (numcalledhere==1) then
          open(853, file=timingdir(1:getlen(timingdir)-1)//"/actreduced.time.dat", &
               status="unknown",iostat=myiostat)
          call checkiostat(myiostat,"opening actreduced timing file")
          write(853,'(T16,100A9)',iostat=myiostat) &
               " rmult ",&     !   (1)
               " ke ",&        !   (2)
               " pot ",&       !   (3)
               " pulse",&       !   (4)
               " nuc ",&       !   (5)
               " twoe ",&      !   (6)
               " invdenmat ",& !   (7)
               " project ", &  !   (8)
               " constrain ", &!   (9)
               " MPI "         !  (10)
          close(853)
          call checkiostat(myiostat,"writing actreduced timing file")
       endif

       if (mod(numcalledhere,timingout).eq.0) then
          open(853, file=timingdir(1:getlen(timingdir)-1)//"/actreduced.time.dat", &
               status="unknown", position="append",iostat=myiostat)
          call checkiostat(myiostat,"opening actreduced timing file")
          write(853,'(A3,F12.4,15I9)',iostat=myiostat) "T= ", thistime,  times(1:10)/1000
          call checkiostat(myiostat,"writing actreduced timing file")
          close(853)
       endif
    endif

  end subroutine actreduced00

!! MAIN ROUTINE TO OPERATE WITH REDUCED HAMILTONIAN (TIMES TIMEFAC!)
!!
!!  outspfs = (1-P) H inspfs
!! where P is projector onto opspfs
!! H is inverse denmat times reducedham

  subroutine actreduced0(dentimeflag,thistime,inspfs, projspfs, &
       outspfs, ireduced, projflag,conflag)
    use parameters
    use derivtimingmod
    implicit none
    integer, intent(in) :: dentimeflag,ireduced,projflag,conflag
    real*8, intent(in) :: thistime
    DATATYPE, intent(in) :: inspfs(spfsize, nspf), projspfs(spfsize,nspf)
    DATATYPE,intent(out) :: outspfs(spfsize,nspf)
    integer :: lowspf,highspf,itime,jtime

    lowspf=1; highspf=nspf
    if (parorbsplit.eq.1) then
       call getOrbSetRange(lowspf,highspf)
    endif

!! call always even if numspf=0
    call actreduced00(lowspf,highspf,dentimeflag,thistime,inspfs, projspfs, &
         outspfs(:,min(nspf,lowspf):highspf), ireduced, projflag,conflag)

    if (parorbsplit.eq.1) then
       call system_clock(itime)
       call mpiorbgather(outspfs,spfsize)
       call system_clock(jtime);        times(10)=times(10)+jtime-itime
    endif

  end subroutine actreduced0

!! only used for relax ; time not needed    
!!     this is actually the conjugate-transpose of the operator, even if cmctdh
!!     (not used)

  subroutine actreducedconjg0(thistime,inspfs, projspfs, outspfs, &
       ireduced, projflag,conflag)
    use parameters
    implicit none
    DATATYPE, intent(in) :: inspfs(spfsize,nspf),projspfs(spfsize,nspf)
    DATATYPE, intent(out) ::  outspfs(spfsize,nspf)
    integer,intent(in) :: ireduced,projflag,conflag
    real*8,intent(in) :: thistime
    DATATYPE :: ttempspfs(spfsize,nspf) !! AUTOMATIC

    ttempspfs(:,:)=ALLCON(inspfs(:,:))
    call actreduced0(1,thistime,ttempspfs, projspfs, outspfs, &
         ireduced, projflag,conflag)
    outspfs=ALLCON(outspfs)

  end subroutine actreducedconjg0

end module derivativemod



module orbdermod
  use derivativemod
contains

!! FOR ODEX PROPAGATION (NOT DEFAULT)

  subroutine gbs_derivs(notusedint,thistime,psi,psip,notuseddbl,notusedint2)
    use parameters
    implicit none
    integer,intent(in) :: notusedint,notusedint2
    real*8,intent(in) :: thistime,notuseddbl
    DATATYPE,intent(in) :: psi(tot_adim*mcscfnum+totspfdim)
    DATATYPE,intent(out) :: psip(tot_adim*mcscfnum+totspfdim)
    call all_derivs(thistime,psi,psip)
  end subroutine gbs_derivs


!! VMF SUBROUTINE (possibly broken, not used for a while)
  subroutine all_derivs(thistime,in_xpsi, out_xpsip)
    use parameters
    use mpimod
    use configmod
    use xxxmod
    use sparsemultmod
    implicit none
    DATATYPE,intent(in) :: in_xpsi(tot_adim*mcscfnum+totspfdim)
    DATATYPE,intent(out) :: out_xpsip(tot_adim*mcscfnum+totspfdim)
    DATATYPE :: xspfs(totspfdim),xavec(tot_adim,mcscfnum),&
         xspfsp(totspfdim),xavecp(tot_adim,mcscfnum)
    DATATYPE :: avector(tot_adim)   !! AUTOMATIC
    real*8 :: thistime
    integer :: itime,jtime,getlen,myiostat,spfstart,spfend
    integer, save :: times(20)=0, numcalledhere=0,imc

    numcalledhere=numcalledhere+1

    if (tot_adim.gt.0) then
       xavec(:,:)=RESHAPE(in_xpsi(1:tot_adim*mcscfnum),(/tot_adim,mcscfnum/))
       yyy%cmfavec(:,:,0)=xavec(:,:)
    endif

    spfstart=tot_adim*mcscfnum+1;     spfend=tot_adim*mcscfnum+totspfdim

    xspfs(:)=in_xpsi(spfstart:spfend)
    yyy%cmfspfs(:,0)=xspfs(:)

    call get_stuff0(thistime,times)

    xspfsp(:)=0d0
    if (tot_adim.gt.0) then
       xavecp(:,:)=0d0
    endif

!! ireduced should be zero right   07-2015

    if (spf_flag.ne.0) then
       call system_clock(itime)
       call actreduced0(1,thistime,xspfs,xspfs,xspfsp,0,1,1)
       call system_clock(jtime);     times(5)=times(5)+jtime-itime
    endif

  !! AVECTOR PART.

    if (avector_flag.ne.0) then
       call system_clock(itime)
       do imc=1,mcscfnum
          if (tot_adim.gt.0) then
             avector(:)=xavec(:,imc)
          endif
          call basis_project(www,numr,avector)
          call sparseconfigmult(www,avector,xavecp(:,imc),&
               yyy%cptr(0),yyy%sptr(0),1,1,1,1,thistime,imc)
          call basis_project(www,numr,xavecp(:,imc))
       enddo
    endif

    if (tot_adim.gt.0) then
       xavecp(:,:)=xavecp(:,:)*timefac
    endif

    call system_clock(jtime);  times(6)=times(6)+jtime-itime
  
    if ((myrank.eq.1).and.(notiming.eq.0)) then
       if (numcalledhere==1) then
          open(853, file=timingdir(1:getlen(timingdir)-1)//"/all_deriv.time.dat", &
               status="unknown",iostat=myiostat)
          call checkiostat(myiostat,"opening all_deriv timing file")
          write(853,'( T16, 100A15)') " init ", " matel ", " denmat ", " getredham ", &
               " actreduced ", " amult "
          close(853)
       endif
       if (mod(numcalledhere,timingout).eq.0) then
          open(853, file=timingdir(1:getlen(timingdir)-1)//"/all_deriv.time.dat", &
               status="unknown", position="append",iostat=myiostat)
          call checkiostat(myiostat,"writing all_deriv timing file")
          write(853,'(A3,F12.3,100I15)') "T= ", thistime,  times(1:6)/1000
          close(853)
       endif
    endif


    out_xpsip(spfstart:spfend)=xspfsp(:)
    out_xpsip(1:tot_adim*mcscfnum)=RESHAPE(xavecp(:,:),(/tot_adim*mcscfnum/))

  end subroutine all_derivs


!! MAIN DERIVATIVE ROUTINE FOR ODEX

  subroutine gbs_linear_derivs(notusedint,thistime,spfsin,spfsout,&
       notuseddbl,notusedint2)
    use parameters
    implicit none
    DATATYPE,intent(in) :: spfsin(spfsize, nspf)
    DATATYPE,intent(out) :: spfsout(spfsize, nspf)
    integer,intent(in) :: notusedint,notusedint2
    real*8,intent(in) :: thistime,notuseddbl
    call spf_linear_derivs(thistime,spfsin,spfsout)
  end subroutine gbs_linear_derivs


!! MAIN DERIVATIVE ROUTINE FOR RK, EXPO

  subroutine spf_linear_derivs(thistime,spfsin,spfsout)
    use parameters
    use linearmod   !! effective_cmf_linearflag
    implicit none
    DATATYPE,intent(in) :: spfsin(spfsize, nspf)
    DATATYPE,intent(out) :: spfsout(spfsize, nspf)
    real*8,intent(in) :: thistime
    call spf_linear_derivs0(effective_cmf_linearflag,1,thistime,spfsin,spfsout,1,1)
  end subroutine spf_linear_derivs


  subroutine spf_linear_derivs0(inlinearflag,dentimeflag,thistime,spfsin,&
       spfsout, projflag,conflag)
    use derivtimingmod
    use parameters
    use linearmod    !! firsttime,lasttime
    use xxxmod  !! frozenexchange and driving orbs
    use orbprojectmod
    implicit none
    integer,intent(in) :: inlinearflag,dentimeflag,projflag,conflag
    real*8,intent(in) :: thistime
    DATATYPE,intent(in) :: spfsin(spfsize, nspf)
    DATATYPE,intent(out) :: spfsout(spfsize, nspf)
    DATATYPE :: facs(0:1),csum,pots(3)
    DATATYPE,allocatable :: tempspfs(:,:),workspfs(:,:)
    real*8 :: rsum
    integer ::  jjj, ibot,lowspf,highspf,numspf,itime,jtime

!!  times(:)=0       !! zeroing this now here in spf_linear_derivs0.

    if (inlinearflag.eq.1) then
       ibot=0;     
       facs(0)=(thistime-firsttime)/(lasttime-firsttime); 
       facs(1)=1d0-facs(0)
    else
       ibot=1;     facs(0)=0d0;     facs(1)=1d0
    endif

    lowspf=1; highspf=nspf
    if (parorbsplit.eq.1) then
       call getOrbSetRange(lowspf,highspf)
    endif
    numspf=highspf-lowspf+1

    allocate(tempspfs(spfsize,lowspf:highspf+1), workspfs(spfsize,lowspf:highspf+1))

    spfsout(:,:)=0d0; tempspfs(:,:)=0d0; workspfs(:,:)=0d0

    do jjj=ibot,1
       call actreduced00(lowspf,highspf,dentimeflag,thistime,spfsin,spfsin,&
            workspfs,jjj, projflag,conflag)
       if (numspf.gt.0) then
          spfsout(:,lowspf:highspf)=spfsout(:,lowspf:highspf) + &
               workspfs(:,lowspf:highspf)*facs(jjj)
       endif
    enddo

!! EXCHANGE IS TREATED AS A DRIVING TERM.  DOES NOT GO IN LINEAR OPERATOR ACTREDUCED.
!!  (it is prohibitive to call op_frozen_exchange repeatedly)
!! EXCHANGE AND DRIVING CONTRIBUTE TO JACOBIAN (jacoperate) via projector.

    if (numfrozen.gt.0.and.numspf.gt.0) then
       call system_clock(itime)
       do jjj=ibot,1
          if (dentimeflag.ne.0) then
!! TIMEFAC and facs HERE
             csum=timefac*facs(jjj)
             call MYGEMM('N','N', spfsize,numspf,nspf,csum, &
                  yyy%frozenexchinvr(:,:,jjj),spfsize, &
                  yyy%invdenmat(:,lowspf:highspf,jjj), nspf, DATAZERO, &
                  tempspfs(:,lowspf:highspf), spfsize)
          else
             tempspfs(:,lowspf:highspf)=(-1)* &
                  yyy%frozenexchinvr(:,lowspf:highspf,jjj)*facs(jjj) !! factor (-1)
          endif
       enddo
       call system_clock(jtime);    times(7)=times(7)+jtime-itime;     itime=jtime
       if (projflag.ne.0) then
          call project00(lowspf,highspf,tempspfs(:,lowspf:highspf),&
               workspfs(:,lowspf:highspf),spfsin)
          spfsout(:,lowspf:highspf)=spfsout(:,lowspf:highspf) + &
               tempspfs(:,lowspf:highspf)-workspfs(:,lowspf:highspf)
       else
          spfsout(:,lowspf:highspf)=spfsout(:,lowspf:highspf) + &
               tempspfs(:,lowspf:highspf)
       endif
       call system_clock(jtime);        times(8)=times(8)+jtime-itime
    endif

!! DRIVING (PSI-PRIME)

    if (drivingflag.ne.0.and.numspf.gt.0) then
       if (dentimeflag.eq.0) then
          OFLWR "Error, no drivingflag for quad"; CFLST !! invdenmat already in drivingorbs
       endif
       call vectdpot(thistime,velflag,pots,-1)
       rsum=0
       do jjj=1,3
          rsum=rsum+abs(pots(jjj))**2
       enddo
       if (rsum.ne.0d0) then
          tempspfs(:,:)=0d0
          do jjj=ibot,1
             tempspfs(:,lowspf:highspf)=tempspfs(:,lowspf:highspf)+ ( &
                  yyy%drivingorbsxx(:,lowspf:highspf,jjj) * pots(1) + &
                  yyy%drivingorbsyy(:,lowspf:highspf,jjj) * pots(2) + &
                  yyy%drivingorbszz(:,lowspf:highspf,jjj) * pots(3) ) &
                  *facs(jjj) * timefac                             !! WITH TIMEFAC
          enddo
          call system_clock(itime)
          if (projflag.ne.0) then
             call project00(lowspf,highspf,tempspfs(:,lowspf:highspf),&
                  workspfs(:,lowspf:highspf),spfsin)
             spfsout(:,lowspf:highspf)=spfsout(:,lowspf:highspf)+&
                  tempspfs(:,lowspf:highspf)-workspfs(:,lowspf:highspf)
          else
             spfsout(:,lowspf:highspf)=spfsout(:,lowspf:highspf) + &
                  tempspfs(:,lowspf:highspf)
          endif
          call system_clock(jtime);        times(8)=times(8)+jtime-itime
       endif
    endif

    deallocate(tempspfs,workspfs)

    if (parorbsplit.eq.1) then
       call system_clock(itime)
       call mpiorbgather(spfsout,spfsize)
       call system_clock(jtime);        times(10)=times(10)+jtime-itime
    endif

  end subroutine spf_linear_derivs0

end module orbdermod


