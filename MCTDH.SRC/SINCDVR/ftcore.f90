
!! myrank is 1:nprocs

module ftoutmod
  implicit none
  integer :: ftoutflag=0
  integer :: ftfileptr=6
end module ftoutmod

subroutine ftset(inoutflag,infileptr)
  use ftoutmod
  integer, intent(in) :: inoutflag,infileptr
  ftoutflag=inoutflag; ftfileptr=infileptr
end subroutine ftset


#ifdef FFTWFLAG

!! Old version myzfft1d() for intel, should not be needed; see myzfft1d_not() below

recursive subroutine myzfft1d(in,out,dim,howmany)
  use ftoutmod
  use, intrinsic :: iso_c_binding
  implicit none
  include "fftw3.f03"
  integer, intent(in) :: dim,howmany
  complex*16 :: in(dim,howmany)    !! cannot be declared intent(in)...hmmm...
  complex*16, intent(out) :: out(dim,howmany)
  integer, parameter :: maxplans=3
  type(C_PTR),save :: plans(maxplans)
  integer, save :: plandims(maxplans)=-999, planhowmany(maxplans)=-999
  integer,save :: icalleds(maxplans)=0, numplans=0
  integer :: ostride,istride,onembed(1),inembed(1),idist,odist, dims(1),iplan,thisplan

  inembed(1)=dim; onembed(1)=dim; idist=dim; odist=dim; istride=1; ostride=1; dims(1)=dim

  if (numplans.eq.0) then
     numplans=1
     thisplan=1
     plandims(thisplan)=dim; planhowmany(thisplan)=howmany
  else
     thisplan= -99
     do iplan=1,numplans
        if (plandims(iplan).eq.dim.and.planhowmany(iplan).eq.howmany) then
           if (icalleds(iplan).eq.0) then
              print *, "ERROR, plan not done ",iplan,dim,howmany; call mpistop()
           endif
           thisplan=iplan
           exit
        endif
     enddo
     if (thisplan.eq.-99) then
        if (numplans.eq.maxplans) then
           print *,  "all plans taken!", maxplans; call mpistop()
        endif
        numplans=numplans+1
        thisplan=numplans
        plandims(thisplan)=dim; planhowmany(thisplan)=howmany
     endif
  endif
  if (icalleds(thisplan).eq.0) then
     if (ftoutflag.ne.0) then
        print *, "       Making a 1D FFT plan ", thisplan, dims, howmany
     endif
     plans(thisplan) = fftw_plan_many_dft(1,dims,howmany,in,inembed,istride,idist,out,onembed,ostride,odist,FFTW_FORWARD,FFTW_EXHAUSTIVE) 
     if (ftoutflag.ne.0) then
        print *, "       Done making a 1D FFT plan ", thisplan, dims, howmany
     endif
  endif
  icalleds(thisplan)=1    

!  if (ftoutflag.ne.0) then
!     print *, "       Doing a 1D FFT ", thisplan
!  endif

  call fftw_execute_dft(plans(thisplan), in,out)

!  if (ftoutflag.ne.0) then
!     print *, "          Done with a 1D FFT ", thisplan
!  endif

end subroutine myzfft1d


!! Not sure why this didn't work.  Old version myzfft1d() for intel, above, should not be needed

subroutine myzfft1d_not(in,out,dim,howmany)
  use, intrinsic :: iso_c_binding
  implicit none
  include "fftw3.f03"
  integer, intent(in) :: dim,howmany
  complex*16,intent(in) :: in(dim,howmany)
  complex*16, intent(out) :: out(dim,howmany)
  call myzfft1d0(1,in,out,dim,howmany)
end subroutine myzfft1d_not


subroutine myzfft1d_slowindex_local(in,out,dim1,dim2,howmany)
  implicit none
  integer, intent(in) :: dim1,dim2,howmany
  complex*16, intent(in) :: in(dim1,dim2,howmany)
  complex*16, intent(out) :: out(dim1,dim2,howmany)
  call myzfft1d0(dim1,in,out,dim2,howmany)
end subroutine myzfft1d_slowindex_local


recursive subroutine myzfft1d0(blockdim,in,out,dim,howmany)
  use ftoutmod
  use, intrinsic :: iso_c_binding
  implicit none
  include "fftw3.f03"
  integer, intent(in) :: dim,howmany,blockdim
  complex*16 :: in(blockdim,dim,howmany)    !! cannot be declared intent(in)...hmmm...
  complex*16, intent(out) :: out(blockdim,dim,howmany)
  integer, parameter :: maxplans=3
  type(C_PTR),save :: plans(maxplans)
  integer, save :: plandims(maxplans)=-999, planhowmany(maxplans)=-999,&
       planblockdim(maxplans)=-999
  integer,save :: icalleds(maxplans)=0, numplans=0
  integer :: ostride,istride,onembed(1),inembed(1),idist,odist, dims(1),iplan,thisplan

!!$  KEEPME           EITHER WORK BLOCKDIM=1            KEEPME
!!$
!!$  inembed(1)=dim; onembed(1)=dim; idist=dim; odist=dim; istride=1; ostride=1; dims(1)=dim
!!$  inembed(1)=dim; onembed(1)=dim; idist=1; odist=1; istride=1; ostride=1; dims(1)=dim
!!$

  inembed(1)=dim; onembed(1)=dim; idist=1; odist=1; istride=blockdim; ostride=blockdim; dims(1)=dim

  if (numplans.eq.0) then
     numplans=1
     thisplan=1
     plandims(thisplan)=dim; planhowmany(thisplan)=howmany;
     planblockdim(thisplan)=blockdim
  else
     thisplan= -99
     do iplan=1,numplans
        if (plandims(iplan).eq.dim.and.planhowmany(iplan).eq.howmany&
             .and.planblockdim(iplan).eq.blockdim) then
           if (icalleds(iplan).eq.0) then
              print *, "ERROR, plan not done ",iplan,dim,howmany; call mpistop()
           endif
           thisplan=iplan
           exit
        endif
     enddo
     if (thisplan.eq.-99) then
        if (numplans.eq.maxplans) then
           print *,  "all plans taken!", maxplans; call mpistop()
        endif
        numplans=numplans+1
        thisplan=numplans
        plandims(thisplan)=dim; planhowmany(thisplan)=howmany;
        planblockdim(thisplan)=blockdim
     endif
  endif
  if (icalleds(thisplan).eq.0) then
     if (ftoutflag.ne.0) then
        print *, "       Making a 1D FFT plan! ", thisplan,  howmany, blockdim
        print *, "       ", dims
     endif
     plans(thisplan) = fftw_plan_many_dft(1,dims,howmany*blockdim,in,inembed,istride,idist,out,onembed,ostride,odist,FFTW_FORWARD,FFTW_EXHAUSTIVE) 
     if (ftoutflag.ne.0) then
        print *, "       Done making a 1D FFT plan! ", thisplan,  howmany, blockdim
     endif
  endif
  icalleds(thisplan)=1    

!  if (ftoutflag.ne.0) then
!     print *, "       Doing a 1D FFT! ", thisplan
!  endif

  call fftw_execute_dft(plans(thisplan), in,out)

!  if (ftoutflag.ne.0) then
!     print *, "          Done with a 1D FFT! ", thisplan
!  endif

end subroutine myzfft1d0


recursive subroutine myzfft3d(in,out,dim1,dim2,dim3,howmany)
  use ftoutmod
  use, intrinsic :: iso_c_binding
  implicit none
  include "fftw3.f03"
  integer, intent(in) :: dim1,dim2,dim3,howmany
  complex*16 :: in(dim1,dim2,dim3,howmany)  !! cannot be declared intent(in)...hmmm...
  complex*16, intent(out) :: out(dim1,dim2,dim3,howmany)
  integer, parameter :: maxplans=3
  type(C_PTR),save :: plans(maxplans)
  integer, save :: plandims(3,maxplans)=-999, planhowmany(maxplans)=-999
  integer,save :: icalleds(maxplans)=0, numplans=0
  integer :: ostride,istride,onembed(3),inembed(3),idist,odist, dims(3),iplan,thisplan

  dims(:)=(/dim3,dim2,dim1/)
  inembed(:)=dims(:); onembed(:)=dims(:); idist=dim1*dim2*dim3; odist=dim1*dim2*dim3; istride=1; ostride=1; 

  if (numplans.eq.0) then
     numplans=1
     thisplan=1
     plandims(:,thisplan)=dims(:); planhowmany(thisplan)=howmany
  else
     thisplan= -99
     do iplan=1,numplans
        if (plandims(1,iplan).eq.dims(1).and.&
             plandims(2,iplan).eq.dims(2).and.&
             plandims(3,iplan).eq.dims(3).and.&
             planhowmany(iplan).eq.howmany) then
           if (icalleds(iplan).eq.0) then
              print *, "ERROR, plan not done ",iplan,dims(:),howmany; call mpistop()
           endif
           thisplan=iplan
           exit
        endif
     enddo
     if (thisplan.eq.-99) then
        if (numplans.eq.maxplans) then
           print *,  "all plans taken!", maxplans; call mpistop()
        endif
        numplans=numplans+1
        thisplan=numplans
        plandims(:,thisplan)=dims(:); planhowmany(thisplan)=howmany
     endif
  endif
  if (icalleds(thisplan).eq.0) then
     if (ftoutflag.ne.0) then
        print *, "       Making a 3D fft plan ", thisplan, dims, howmany
     endif
     plans(thisplan) = fftw_plan_many_dft(3,dims,howmany,in,inembed,istride,idist,out,onembed,ostride,odist,FFTW_FORWARD,FFTW_EXHAUSTIVE) 
     if (ftoutflag.ne.0) then
        print *, "        ...ok, made a 3D fft plan ", thisplan, dims, howmany
     endif
  endif
  icalleds(thisplan)=1    

!  if (ftoutflag.ne.0) then
!     print *, "       Doing a 3D fft ", thisplan
!  endif
  call fftw_execute_dft(plans(thisplan), in,out)
!  if (ftoutflag.ne.0) then
!     print *, "          Done with a 3D fft ", thisplan
!  endif

end subroutine myzfft3d


#else


recursive subroutine myzfft1d(in,out,dim,howmany)
  implicit none
  integer, intent(in) :: dim,howmany
  integer :: k
  complex*16, intent(in) :: in(dim,howmany)
  complex*16, intent(out) :: out(dim,howmany)
  complex*16 :: wsave(4*dim+15,howmany)   ! MAKE BIGGER IF SEGFAULT... iffy
  out(:,:)=in(:,:)
!$OMP PARALLEL DEFAULT(PRIVATE) SHARED(in,out,dim,howmany,wsave)
!$OMP DO SCHEDULE(STATIC)
  do k=1,howmany
     call zffti(dim,wsave(:,k))
     call zfftf(dim,out(:,k),wsave(:,k))
  enddo
!$OMP END DO
!$OMP END PARALLEL
end subroutine myzfft1d


!! OBVIOUSLY UNSATISFACTORY WITH DFFTPACK ROUTINES
!! OBVIOUSLY UNSATISFACTORY WITH DFFTPACK ROUTINES
!! OBVIOUSLY UNSATISFACTORY WITH DFFTPACK ROUTINES USED CURRENTLY:

subroutine myzfft1d_slowindex_local(in,out,dim1,dim2,howmany)
  implicit none
  integer, intent(in) :: dim1,dim2,howmany
  complex*16, intent(in) :: in(dim1,dim2,howmany)
  complex*16, intent(out) :: out(dim1,dim2,howmany)
  complex*16 :: intrans(dim2,dim1,howmany),outtrans(dim2,dim1,howmany)
  integer :: ii
  do ii=1,howmany
     intrans(:,:,ii)=TRANSPOSE(in(:,:,ii))
  enddo
  call myzfft1d(intrans,outtrans,dim2,dim1*howmany)
  do ii=1,howmany
     out(:,:,ii)=TRANSPOSE(outtrans(:,:,ii))
  enddo
end subroutine myzfft1d_slowindex_local


recursive subroutine myzfft3d(in,out,dim1,dim2,dim3,howmany)
  implicit none
  integer :: dim1,dim2,dim3,howmany
  complex*16, intent(in) :: in(dim1,dim2,dim3,howmany)
  complex*16, intent(out) :: out(dim1,dim2,dim3,howmany)
  out(:,:,:,:)=in(:,:,:,:)
  call fftblock_withtranspose(out,dim1,dim2,dim3,howmany)
  call fftblock_withtranspose(out,dim2,dim3,dim1,howmany)
  call fftblock_withtranspose(out,dim3,dim1,dim2,howmany)
end subroutine myzfft3d


recursive subroutine fftblock_withtranspose(inout,dim1,dim2,dim3,howmany)
  implicit none
  integer :: dim1,dim2,dim3,howmany
!!!!  is dimensioned (dim1,dim2,dim3) on input. !!!!
  complex*16,intent(inout) :: inout(dim2,dim3,dim1,howmany) 
  complex*16 :: work1(dim1,dim2,dim3,howmany)  !! AUTOMATIC
  integer :: i
  call myzfft1d(inout,work1,dim1,dim2*dim3*howmany)
  do i=1,dim1
     inout(:,:,i,:)=work1(i,:,:,:)
  enddo
end subroutine fftblock_withtranspose

#endif


#ifdef MPIFLAG

!! times(1) = transpose   times(2) = mpi  times(3) = copy
!!   (123) -> (231)

module mytransposemod
contains
  recursive subroutine mytranspose(in,out,blocksize,howmany,times,nprocs)
  implicit none
  integer,intent(in) :: blocksize,howmany,nprocs
  integer,intent(inout) :: times(3)
  complex*16,intent(in) :: in(nprocs*blocksize,nprocs*blocksize,blocksize,howmany)
  complex*16,intent(out) :: out(nprocs*blocksize,nprocs*blocksize,blocksize,howmany)
  integer :: atime,btime,i,count,ii,iproc,j
  complex*16 :: intranspose(nprocs*blocksize,blocksize,blocksize,howmany,nprocs)  !!AUTOMATIC
  complex*16 :: outtemp(nprocs*blocksize,blocksize,blocksize,howmany,nprocs)      !!AUTOMATIC
  complex*16 :: outone(nprocs*blocksize,blocksize,blocksize,nprocs)               !!AUTOMATIC
  complex*16 :: inchop(blocksize,nprocs*blocksize,blocksize,howmany)              !!AUTOMATIC

!!! QQQQ

!  if (nprocs1.ne.nprocs2) then
!     print *, "doogsnatch"; call mpistop()
!  endif


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!    (123)->(231)    !!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  
  call myclock(atime)

  intranspose(:,:,:,:,:)=0d0

!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(ii,i)    !! IPROC IS SHARED (GOES WITH BARRIER, INCHOP SHARED)

  do iproc=1,nprocs


     inchop(:,:,:,:)=in((iproc-1)*blocksize+1:iproc*blocksize,:,:,:)


!$OMP DO SCHEDULE(STATIC) COLLAPSE(2)
     do ii=1,howmany
        do i=1,blocksize

           intranspose(:,:,i,ii,iproc)=inchop(i,:,:,ii)

        enddo
     enddo
!$OMP END DO
!! *** OMP BARRIER *** !!   if inchop & iproc are shared
!$OMP BARRIER
  enddo

!$OMP END PARALLEL

  call myclock(btime); times(1)=times(1)+btime-atime; atime=btime

  outtemp(:,:,:,:,:)=0d0
  
  count=blocksize**3 * nprocs * howmany
  
  call mympialltoall_complex(intranspose,outtemp,count)
  call myclock(btime); times(2)=times(2)+btime-atime; atime=btime

!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(i,j)  !! ii IS SHARED (OUTTEMP IS SHARED; BARRIER)
  do ii=1,howmany

     outone(:,:,:,:)=outtemp(:,:,:,ii,:)
!$OMP DO SCHEDULE(STATIC) COLLAPSE(2)

     do i=1,blocksize
        do j=1,nprocs*blocksize

           out(j,:,i,ii)=RESHAPE(outone(j,:,i,:),(/nprocs*blocksize/))

        enddo
     enddo

!$OMP END DO
!! *** OMP BARRIER *** !!   if outone & ii are shared
!$OMP BARRIER

  enddo
!$OMP END PARALLEL

  call myclock(btime); times(3)=times(3)+btime-atime;

end subroutine mytranspose
end module  
  

subroutine checkdivisible(number,divisor)
  implicit none
  integer :: number,divisor
  if ((number/divisor)*divisor.ne.number) then
     print *, "ACK NOT DIVISIBLE",number,divisor; call mpistop()
  endif
end subroutine checkdivisible


recursive subroutine myzfft3d_mpiwrap_forward(in,out,dim,howmany,placeopt)
  implicit none
  integer, intent(in) :: dim,howmany,placeopt
  complex*16, intent(in) :: in(*)
  complex*16, intent(out) :: out(*)
  call myzfft3d_mpiwrap0(in,out,dim,howmany,1,placeopt)
end subroutine myzfft3d_mpiwrap_forward

recursive subroutine myzfft3d_mpiwrap_backward(in,out,dim,howmany,placeopt)
  implicit none
  integer, intent(in) :: dim,howmany,placeopt
  complex*16, intent(in) :: in(*)
  complex*16, intent(out) :: out(*)
  call myzfft3d_mpiwrap0(in,out,dim,howmany,-1,placeopt)
end subroutine myzfft3d_mpiwrap_backward

recursive subroutine myzfft3d_mpiwrap0(in,out,dim,howmany,direction,placeopt)
  implicit none
  integer :: dim,nulltimes(10),howmany,ii,direction,placeopt
  complex*16, intent(in) :: in(dim**3,howmany)
  complex*16, intent(out) :: out(dim**3,howmany)
  complex*16,allocatable :: inlocal(:,:),outgather(:,:,:),outlocal(:,:)
  integer :: mystart, myend, mysize, myrank,nprocs

  call getmyranknprocs(myrank,nprocs)
  call checkdivisible(dim**3,nprocs)

  mystart=dim**3/nprocs*(myrank-1)+1
  myend=dim**3/nprocs*myrank
  mysize=dim**3/nprocs

  allocate(inlocal(mystart:myend,howmany), outlocal(mystart:myend,howmany),&
       outgather(mystart:myend,howmany,nprocs))

  inlocal(:,:)=in(mystart:myend,:)


  select case(direction)
  case(-1)
     if (placeopt.ne.1) then
!!$        call ctdim(3)

!! QQQQQ

        call cooleytukey_outofplace_backward_mpi(inlocal,outlocal,dim,dim,dim/nprocs,howmany)
     else
        call myzfft3d_par_backward(inlocal,outlocal,dim,nulltimes,howmany)
     endif
  case(1)
     if (placeopt.ne.1) then
!!$        call ctdim(3)

!! QQQQQQ

        call cooleytukey_outofplace_forward_mpi(inlocal,outlocal,dim,dim,dim/nprocs,howmany)
     else
        call myzfft3d_par_forward(inlocal,outlocal,dim,nulltimes,howmany)
     endif
  case default
     print *, "ACK DIRECTION!!!!", direction; call mpistop()
  end select
  
  call simpleallgather_complex(outlocal,outgather,dim**3/nprocs*howmany)
  do ii=1,howmany
     out(:,ii)=RESHAPE(outgather(:,ii,:),(/dim**3/))
  enddo
  deallocate(inlocal,outlocal,outgather)

end subroutine myzfft3d_mpiwrap0


recursive subroutine myzfft3d_par_forward(in,out,dim,times,howmany)
  use pmpimod
  implicit none
  integer, intent(in) :: dim,howmany
  complex*16, intent(in) :: in(*)
  complex*16, intent(out) :: out(*)
  integer, intent(inout) :: times(8)
  select case(orbparlevel)
  case(3)
     call myzfft3d_par0(in,out,dim,times,howmany,nprocs,1,1,orbparlevel)
  case(2)
     call myzfft3d_par0(in,out,dim,times,howmany,sqnprocs,sqnprocs,1,orbparlevel)
  case default
     print *, "ORBPARLEVEL NOT SUP", orbparlevel; call mpistop()
  end select
end subroutine myzfft3d_par_forward

recursive subroutine myzfft3d_par_backward(in,out,dim,times,howmany)
  use pmpimod
  implicit none
  integer, intent(in) :: dim,howmany
  complex*16, intent(in) :: in(*)
  complex*16, intent(out) :: out(*)
  integer, intent(inout) :: times(8)
  select case(orbparlevel)
  case(3)
     call myzfft3d_par0(in,out,dim,times,howmany,nprocs,1,-1,orbparlevel)
  case (2)
     call myzfft3d_par0(in,out,dim,times,howmany,sqnprocs,sqnprocs,-1,orbparlevel)
  case default
     print *,  "ORBPARLEVEL NOT SUP", orbparlevel; call mpistop()
  end select

end subroutine myzfft3d_par_backward


!!! adds to times

!!! times(1) = copy  times(2) = conjg  times(3) = ft
!!! from mytranspose times(4) = transpose   times(5) = mpi  times(6) = copy

recursive subroutine myzfft3d_par0(in,out,dim,times,howmany,nprocs1,nprocs2,direction,oplevel)
  use mytransposemod
  implicit none
  integer, intent(in) :: dim,howmany,nprocs1,nprocs2,direction,oplevel
  complex*16, intent(in) :: in(dim**3/nprocs1/nprocs2,howmany)
  complex*16, intent(out) :: out(dim**3/nprocs1/nprocs2,howmany)
  integer, intent(inout) :: times(8)
  integer :: ii,atime,btime
  complex*16 :: mywork(dim**3/nprocs1/nprocs2,howmany) !! AUTOMATIC

  if (oplevel.ne.2.and.oplevel.ne.3) then
     print *, "OPLEVEL NOT SUP",oplevel; call mpistop()
  endif


  call myclock(atime)
  select case(direction)
  case(-1)
     out(:,:)=CONJG(in(:,:))
     call myclock(btime); times(2)=times(2)+btime-atime;
  case(1)
     out(:,:)=in(:,:)
     call myclock(btime); times(1)=times(1)+btime-atime;
  case default
     print *, "ACK PAR0 DIRECTION=",direction; call mpistop()
  end select

  do ii=1,3
     call myclock(atime)
     call myzfft1d( out, mywork, dim, dim**2/nprocs1/nprocs2*howmany)
     call myclock(btime); times(3)=times(3)+btime-atime
     
!!! from mytranspose times(4) = transpose   times(5) = mpi  times(6) = copy

!! QQQQQ
     if (oplevel.ne.3) then
        print *, "NOOOT SUP", oplevel; call mpistop()
     endif

     call mytranspose(&
          mywork,  &
          out,  &
          dim/nprocs1, &
          howmany,times(4:),nprocs1)

  enddo

  call myclock(atime)
  select case(direction)
  case(-1)
     out(:,:)=CONJG(out(:,:))
     call myclock(btime); times(2)=times(2)+btime-atime
  case(1)
  case default
     print *, "ACK PAR0 DIRECTION=",direction; call mpistop()
  end select

end subroutine myzfft3d_par0

#endif
