

!! ACTION 21 (emission/absorption) subroutine

#include "Definitions.INC"

module dipolemod
  implicit none
  DATATYPE, allocatable :: dipoleexpects(:,:,:),    dipolenormsq(:)
  integer :: calledflag=0,xcalledflag=0
end module dipolemod

subroutine dipolesub_initial()
  use dipolemod
  use parameters
  use pulse_parameters !! conjgpropflag
  implicit none

  if (conjgpropflag.eq.0) then
     allocate(dipoleexpects(0:autosize,3,1))   !! x,y,z
  else
     allocate(dipoleexpects(0:autosize,3,4))
  endif
  allocate(dipolenormsq(0:autosize))

end subroutine


subroutine dipolesub()
  use dipolemod
  use parameters
  use configmod
  use xxxmod
  use mpisubmod
  use pulse_parameters !! conjgpropflag, numpulses in dipolecall
  implicit none

  DATATYPE :: myexpects(3), mcexpects(3,mcscfnum), dd(mcscfnum),&
       axx(mcscfnum),ayy(mcscfnum),azz(mcscfnum),sxx(mcscfnum),syy(mcscfnum),&
       szz(mcscfnum),drivingoverlap(mcscfnum)
  integer :: imc,sflag,getlen,ii
  integer, save :: lastouttime=0
  real*8 :: thistime
  character(len=2) :: tl(4) = (/ "BA", "AB", "AA", "AB" /)

  myexpects=0;mcexpects=0;axx=0;ayy=0;azz=0;sxx=0;syy=0;szz=0;dd=0;drivingoverlap=0

  if (mod(xcalledflag,autosteps).eq.0) then

     if (conjgpropflag.ne.0) then

        if (mcscfnum.ne.2) then
           OFLWR "Whoot? conjgpropflag mcscfnum",mcscfnum; CFLST
        endif
        if (drivingflag.ne.0) then
           OFLWR "Driving not supported for conjprop yet"; CFLST
        endif
        dipolenormsq(calledflag)=0
        if (tot_adim.gt.0) then
           dipolenormsq(calledflag) = hermdot(yyy%cmfavec(:,2,0),yyy%cmfavec(:,1,0),tot_adim)
        endif
        if (par_consplit.ne.0) then
           call mympireduceone(dipolenormsq(calledflag))
        endif

        call dipolesub_one(www,bwwptr,yyy%cmfavec(:,2,0),yyy%cmfavec(:,1,0), yyy%cmfspfs(:,0), myexpects(:))
        dipoleexpects(calledflag,:,1)=myexpects(:)
        call dipolesub_one(www,bwwptr,yyy%cmfavec(:,1,0),yyy%cmfavec(:,2,0), yyy%cmfspfs(:,0), myexpects(:))
        dipoleexpects(calledflag,:,2)=myexpects(:)
        call dipolesub_one(www,bwwptr,yyy%cmfavec(:,1,0),yyy%cmfavec(:,1,0), yyy%cmfspfs(:,0), myexpects(:))
        dipoleexpects(calledflag,:,3)=myexpects(:)
        call dipolesub_one(www,bwwptr,yyy%cmfavec(:,2,0),yyy%cmfavec(:,2,0), yyy%cmfspfs(:,0), myexpects(:))
        dipoleexpects(calledflag,:,4)=myexpects(:)

     else  !! conjgpropflag complex Domcke

        do imc=1,mcscfnum
           dd(imc)=0
           if (tot_adim.gt.0) then
              dd(imc) = hermdot(yyy%cmfavec(:,imc,0),yyy%cmfavec(:,imc,0),tot_adim)
           endif
           if (par_consplit.ne.0) then
              call mympireduceone(dd(imc))
           endif
           call dipolesub_one(www,bwwptr,yyy%cmfavec(:,imc,0),yyy%cmfavec(:,imc,0),yyy%cmfspfs(:,0),mcexpects(:,imc))

        enddo

        if (drivingflag.ne.0) then
#ifdef CNORMFLAG
           OFLWR "Error, driving with dipole not supported c-norm"; CFLST
#endif
           call dipolesub_driving(axx,ayy,azz,sxx,syy,szz,mcscfnum)
           mcexpects(1,:)=mcexpects(1,:)+axx(:)+CONJUGATE(axx(:))+sxx*drivingproportion**2
           mcexpects(2,:)=mcexpects(2,:)+ayy(:)+CONJUGATE(ayy(:))+syy*drivingproportion**2
           mcexpects(3,:)=mcexpects(3,:)+azz(:)+CONJUGATE(azz(:))+szz*drivingproportion**2

           call getdrivingoverlap(drivingoverlap,mcscfnum)   !! for time slot zero
           dd(:)=dd(:)+drivingproportion**2 + drivingoverlap(:) + &
                CONJUGATE(drivingoverlap(:))
        endif

        dipoleexpects(calledflag,:,1)=0d0
        dipolenormsq(calledflag)=0d0

        do imc=1,mcscfnum

           dipolenormsq(calledflag) = dipolenormsq(calledflag) + dd(imc)

!! 101414 REAL-VALUED FOR HERM.
!! 1-2016 v1.17 should not be necessary with realflag in mult_zdipole(in,out,realflag) etc.
 
#ifndef CNORMFLAG
           dipoleexpects(calledflag,:,1) = dipoleexpects(calledflag,:,1) + real(mcexpects(:,imc),8) / mcscfnum
#else
           dipoleexpects(calledflag,:,1) = dipoleexpects(calledflag,:,1) + mcexpects(:,imc) / mcscfnum
#endif

        enddo

     endif  !! conjgpropflag complex Domcke

     if (mod(calledflag,dipmodtime).eq.0.and.calledflag.gt.0) then

        thistime=calledflag*par_timestep*autosteps
        sflag=0
        if (floor(thistime/diptime).gt.lastouttime) then
           lastouttime=floor(thistime/diptime)
           sflag=1
        endif

        if (conjgpropflag.eq.0) then
           call dipolecall(calledflag, dipoleexpects(:,:,1),   xdipfile(1:getlen(xdipfile)),&
                xdftfile(1:getlen(xdftfile)),            xoworkfile(1:getlen(xoworkfile)),&
                xtworkfile(1:getlen(xtworkfile)),    xophotonfile(1:getlen(xophotonfile)),&
                1,sflag)
           call dipolecall(calledflag, dipoleexpects(:,:,1),   ydipfile(1:getlen(ydipfile)),&
                ydftfile(1:getlen(ydftfile)),            yoworkfile(1:getlen(xoworkfile)),&
                ytworkfile(1:getlen(xtworkfile)),    yophotonfile(1:getlen(xophotonfile)),&
                2,sflag)
           call dipolecall(calledflag, dipoleexpects(:,:,1),   zdipfile(1:getlen(zdipfile)),&
                zdftfile(1:getlen(zdftfile)),            zoworkfile(1:getlen(xoworkfile)),&
                ztworkfile(1:getlen(xtworkfile)),    zophotonfile(1:getlen(xophotonfile)),&
                3,sflag)
           if (act21circ.ne.0) then
              call dipolecall(calledflag, dipoleexpects(:,:,1),  xydipfile(1:getlen(xydipfile)),&
                   xydftfile(1:getlen(xydftfile)),          xyoworkfile(1:getlen(xoworkfile)),&
                   xytworkfile(1:getlen(xtworkfile)),   xyophotonfile(1:getlen(xophotonfile)),&
                   4,sflag)
              call dipolecall(calledflag, dipoleexpects(:,:,1),  xzdipfile(1:getlen(xzdipfile)),&
                   xzdftfile(1:getlen(xzdftfile)),          xzoworkfile(1:getlen(xoworkfile)),&
                   xztworkfile(1:getlen(xtworkfile)),   xzophotonfile(1:getlen(xophotonfile)),&
                   5,sflag)
              call dipolecall(calledflag, dipoleexpects(:,:,1),  yxdipfile(1:getlen(yxdipfile)),&
                   yxdftfile(1:getlen(yxdftfile)),          yxoworkfile(1:getlen(xoworkfile)),&
                   yxtworkfile(1:getlen(xtworkfile)),   yxophotonfile(1:getlen(xophotonfile)),&
                   6,sflag)
              call dipolecall(calledflag, dipoleexpects(:,:,1),  yzdipfile(1:getlen(yzdipfile)),&
                   yzdftfile(1:getlen(yzdftfile)),          yzoworkfile(1:getlen(xoworkfile)),&
                   yztworkfile(1:getlen(xtworkfile)),   yzophotonfile(1:getlen(xophotonfile)),&
                   7,sflag)
              call dipolecall(calledflag, dipoleexpects(:,:,1),  zxdipfile(1:getlen(zxdipfile)),&
                   zxdftfile(1:getlen(zxdftfile)),          zxoworkfile(1:getlen(xoworkfile)),&
                   zxtworkfile(1:getlen(xtworkfile)),   zxophotonfile(1:getlen(xophotonfile)),&
                   8,sflag)
              call dipolecall(calledflag, dipoleexpects(:,:,1),  zydipfile(1:getlen(zydipfile)),&
                   zydftfile(1:getlen(zydftfile)),          zyoworkfile(1:getlen(xoworkfile)),&
                   zytworkfile(1:getlen(xtworkfile)),   zyophotonfile(1:getlen(xophotonfile)),&
                   9,sflag)
           endif
        else
           do ii=1,4
              call dipolecall(calledflag, dipoleexpects(:,:,1),      xdipfile(1:getlen(xdipfile))//tl(ii),&
                   xdftfile(1:getlen(xdftfile))//tl(ii),         xoworkfile(1:getlen(xoworkfile))//tl(ii),&
                   xtworkfile(1:getlen(xtworkfile))//tl(ii),   xophotonfile(1:getlen(xophotonfile))//tl(ii),&
                   1,sflag)
              call dipolecall(calledflag, dipoleexpects(:,:,1),      ydipfile(1:getlen(ydipfile))//tl(ii),&
                   ydftfile(1:getlen(ydftfile))//tl(ii),         yoworkfile(1:getlen(xoworkfile))//tl(ii),&
                   ytworkfile(1:getlen(xtworkfile))//tl(ii),   yophotonfile(1:getlen(xophotonfile))//tl(ii),&
                   2,sflag)
              call dipolecall(calledflag, dipoleexpects(:,:,1),     zdipfile(1:getlen(zdipfile))//tl(ii),&
                   zdftfile(1:getlen(zdftfile))//tl(ii),        zoworkfile(1:getlen(xoworkfile))//tl(ii),&
                   ztworkfile(1:getlen(xtworkfile))//tl(ii),  zophotonfile(1:getlen(xophotonfile))//tl(ii),&
                   3,sflag)
              if (act21circ.ne.0) then
                 call dipolecall(calledflag, dipoleexpects(:,:,1),      xydipfile(1:getlen(xydipfile))//tl(ii),&
                      xydftfile(1:getlen(xydftfile))//tl(ii),       xyoworkfile(1:getlen(xoworkfile))//tl(ii),&
                      xytworkfile(1:getlen(xtworkfile))//tl(ii),  xyophotonfile(1:getlen(xophotonfile))//tl(ii),&
                      4,sflag)
                 call dipolecall(calledflag, dipoleexpects(:,:,1),      xzdipfile(1:getlen(xzdipfile))//tl(ii),&
                      xzdftfile(1:getlen(xzdftfile))//tl(ii),       xzoworkfile(1:getlen(xoworkfile))//tl(ii),&
                      xztworkfile(1:getlen(xtworkfile))//tl(ii),  xzophotonfile(1:getlen(xophotonfile))//tl(ii),&
                      5,sflag)
                 call dipolecall(calledflag, dipoleexpects(:,:,1),      yxdipfile(1:getlen(yxdipfile))//tl(ii),&
                      yxdftfile(1:getlen(yxdftfile))//tl(ii),       yxoworkfile(1:getlen(xoworkfile))//tl(ii),&
                      yxtworkfile(1:getlen(xtworkfile))//tl(ii),  yxophotonfile(1:getlen(xophotonfile))//tl(ii),&
                      6,sflag)
                 call dipolecall(calledflag, dipoleexpects(:,:,1),      yzdipfile(1:getlen(yzdipfile))//tl(ii),&
                      yzdftfile(1:getlen(yzdftfile))//tl(ii),       yzoworkfile(1:getlen(xoworkfile))//tl(ii),&
                      yztworkfile(1:getlen(xtworkfile))//tl(ii),  yzophotonfile(1:getlen(xophotonfile))//tl(ii),&
                      7,sflag)
                 call dipolecall(calledflag, dipoleexpects(:,:,1),      zxdipfile(1:getlen(zxdipfile))//tl(ii),&
                      zxdftfile(1:getlen(zxdftfile))//tl(ii),       zxoworkfile(1:getlen(xoworkfile))//tl(ii),&
                      zxtworkfile(1:getlen(xtworkfile))//tl(ii),  zxophotonfile(1:getlen(xophotonfile))//tl(ii),&
                      8,sflag)
                 call dipolecall(calledflag, dipoleexpects(:,:,1),      zydipfile(1:getlen(zydipfile))//tl(ii),&
                      zydftfile(1:getlen(zydftfile))//tl(ii),       zyoworkfile(1:getlen(xoworkfile))//tl(ii),&
                      zytworkfile(1:getlen(xtworkfile))//tl(ii),  zyophotonfile(1:getlen(xophotonfile))//tl(ii),&
                      9,sflag)
              endif
           enddo
        endif    !! conjgpropflag
     endif       !! calledflag (dipmodtime)

     if (conjgpropflag.ne.0) then
        OFLWR "   complex Domcke - off diagonal norm-squared ", dipolenormsq(calledflag)
     endif

     calledflag=calledflag+1

  endif
  xcalledflag=xcalledflag+1

contains

!! actually have numdata+1 data points in indipolearray
!! which=1,2,3  =  x,y,z   4,5,6,7,8,9 = x+iy, etc. see dipolesub

  subroutine dipolecall(numdata, indipolearrays, outename, outftname, outoworkname, &
       outtworkname, outophotonname, which, sflag)
    use mpimod
    use pulsesubmod
    implicit none
    integer,intent(in) :: numdata, which, sflag
    DATATYPE,intent(in) :: indipolearrays(0:numdata,3)
    character,intent(in) :: outftname*(*), outename*(*), outoworkname*(*), outtworkname*(*),&
         outophotonname*(*)
    complex*16,allocatable ::  fftrans(:),eft(:), all_eft(:,:),dipole_diff(:)
    DATATYPE :: pots(3,numpulses)
    real*8 :: estep, thistime, myenergy,xsecunits, windowfunct
    real*8, allocatable :: worksums(:,:), worksum0(:,:), exsums(:,:), totworksums(:),&
         totworksum0(:), totexsums(:), xsums(:)
    character (len=7) :: number
    integer :: i,getlen,myiostat,ipulse

#ifdef REALGO
    OFLWR "Cant use dipolesub for real valued code."; CFLST
#endif

    pots=0
    allocate(fftrans(0:numdata), eft(0:numdata), all_eft(0:numdata,numpulses),dipole_diff(0:numdata))
    fftrans=0.d0; eft=0d0; all_eft=0d0; dipole_diff=0d0
    allocate(worksums(0:numdata,numpulses), worksum0(0:numdata,numpulses),exsums(0:numdata,numpulses),&
         totworksums(0:numdata), totworksum0(0:numdata),totexsums(0:numdata), xsums(0:numdata))
    worksums=0; worksum0=0; exsums=0; totworksums=0; totworksum0=0; totexsums=0; xsums=0

    do i=0,numdata
       do ipulse=1,numpulses
          call vectdpot0(i*par_timestep*autosteps,0,pots(:,ipulse),-1,ipulse,ipulse) !! LENGTH
       enddo
       select case(which)
       case(1,2,3)
          all_eft(i,:)=pots(which,:)
          fftrans(i) = (indipolearrays(i,which)-indipolearrays(0,which))
       case(4)
          all_eft(i,:)=pots(1,:) + (0d0,1d0) * pots(2,:)
          fftrans(i) = (indipolearrays(i,1)-indipolearrays(0,1)) + (0d0,1d0)*(indipolearrays(i,2)-indipolearrays(0,2))
       case(5)
          all_eft(i,:)=pots(1,:) + (0d0,1d0) * pots(3,:)
          fftrans(i) = (indipolearrays(i,1)-indipolearrays(0,1)) + (0d0,1d0)*(indipolearrays(i,3)-indipolearrays(0,3))
       case(6)
          all_eft(i,:)=pots(2,:) + (0d0,1d0) * pots(1,:)
          fftrans(i) = (indipolearrays(i,2)-indipolearrays(0,2)) + (0d0,1d0)*(indipolearrays(i,1)-indipolearrays(0,1))
       case(7)
          all_eft(i,:)=pots(2,:) + (0d0,1d0) * pots(3,:)
          fftrans(i) = (indipolearrays(i,2)-indipolearrays(0,2)) + (0d0,1d0)*(indipolearrays(i,3)-indipolearrays(0,3))
       case(8)
          all_eft(i,:)=pots(3,:) + (0d0,1d0) * pots(1,:)
          fftrans(i) = (indipolearrays(i,3)-indipolearrays(0,3)) + (0d0,1d0)*(indipolearrays(i,1)-indipolearrays(0,1))
       case(9)
          all_eft(i,:)=pots(3,:) + (0d0,1d0) * pots(2,:)
          fftrans(i) = (indipolearrays(i,3)-indipolearrays(0,3)) + (0d0,1d0)*(indipolearrays(i,2)-indipolearrays(0,2))
       case default
          OFLWR "ACK WHICH DIPOLECALL", which; CFLST
       end select
    enddo

    call mydiff(numdata+1,fftrans(0:),dipole_diff(0:),.false.)
    dipole_diff(:)=dipole_diff(:) / par_timestep / autosteps

!! dividing and multiplying for clarity not math
!! numbers are real-valued which=1,2,3 x,y,z
!! otherwise with which = 4 through 9 take real part with conjugate like below

    worksum0(0,:) = (-1) * real( dipole_diff(0) * conjg(all_eft(0,:)) , 8) * par_timestep * autosteps
    do i=1,numdata
       worksum0(i,:)=worksum0(i-1,:) - real( dipole_diff(i) * conjg(all_eft(i,:)) , 8) * par_timestep * autosteps
    enddo
    totworksum0=0d0
    do i=1,numpulses
       totworksum0(:)=totworksum0(:)+worksum0(:,i)
    enddo

    do i=0,numdata
       fftrans(i) = fftrans(i) * windowfunct(i,numdata)
    enddo

    if (pulsewindowtoo.ne.0) then
       do i=0,numdata
          all_eft(i,:)=all_eft(i,:) * windowfunct(i,numdata)
       enddo
    endif

    eft=0
    do ipulse=1,numpulses
       eft(:)=eft(:)+all_eft(:,ipulse)
    enddo

    if (myrank.eq.1) then
       open(171,file=outename,status="unknown",iostat=myiostat)
       call checkiostat(myiostat,"opening "//outename)
       write(171,*,iostat=myiostat) "#   ", numdata
       call checkiostat(myiostat,"writing "//outename)
       do i=0,numdata
          write(171,'(F18.12, T22, 400E20.8)',iostat=myiostat)  i*par_timestep*autosteps, &
               fftrans(i),eft(i),all_eft(i,:)
       enddo
       call checkiostat(myiostat,"writing "//outename)
       close(171)

       open(171,file=outtworkname,status="unknown",iostat=myiostat)
       call checkiostat(myiostat,"opening "//outtworkname)
       do i=0,numdata
          write(171,'(A25,F10.5,400F15.10)') " EACH PULSE WORK T= ", i*par_timestep*autosteps,&
               totworksum0(i),worksum0(i,:)
       enddo
       close(171)
    endif

    call zfftf_wrap_diff(numdata+1,fftrans(0:),ftdiff)
    call zfftf_wrap(numdata+1,eft(0:))
    do ipulse=1,numpulses
       call zfftf_wrap(numdata+1,all_eft(0:,ipulse))
    enddo

    fftrans(:)=fftrans(:)     * par_timestep * autosteps
    eft(:)=eft(:)             * par_timestep * autosteps
    all_eft(:,:)=all_eft(:,:) * par_timestep * autosteps

    Estep=2*pi/par_timestep/autosteps/(numdata+1)

    thistime=numdata*par_timestep*autosteps

    xsums(0)= 0d0
    exsums(0,:) = Estep * imag(fftrans(0)*conjg(all_eft(0,:))) / PI
    worksums(0,:) = 0d0

    do i=1,numdata
       myenergy=i*Estep

!! xsum sums to N for N electrons
       if (myenergy.ge.dipolesumstart.and.myenergy.le.dipolesumend) then
          xsums(i)=xsums(i-1) + Estep * imag(fftrans(i)*conjg(eft(i))) / abs(eft(i)**2) * myenergy * 2 / PI
          exsums(i,:)  =  exsums(i-1,:) + Estep * imag(fftrans(i)*conjg(all_eft(i,:))) / PI
          worksums(i,:)=worksums(i-1,:) + Estep * imag(fftrans(i)*conjg(all_eft(i,:))) / PI * myenergy
       else
          xsums(i)=xsums(i-1)
          exsums(i,:)  =  exsums(i-1,:)
          worksums(i,:)=worksums(i-1,:)
       endif
    enddo
    totexsums=0
    totworksums=0
    do i=1,numpulses
       totexsums(:)=totexsums(:)+exsums(:,i)
       totworksums(:)=totworksums(:)+worksums(:,i)
    enddo

    if (myrank.eq.1) then
       open(171,file=outftname,status="unknown",iostat=myiostat)
       call checkiostat(myiostat,"opening "//outftname)
       write(171,'(A120)',iostat=myiostat) &
            "## Photon energy (column 1); D(omega) (2,3); E(omega) (4,5); response (6,7); cross sect (9); integrated (10)" 
       call checkiostat(myiostat,"writing "//outftname)
       write(171,'(A120)') "## UNITLESS RESPONSE FUNCTION FOR ABSORPTION/EMISSION 2 omega im(D(omega)E(omega)^*) IN COLUMN 7"
       write(171,'(A120)') "## QUANTUM MECHANICAL PHOTOABSORPTION/EMISSION CROSS SECTION IN MEGABARNS (no factor of 1/3) IN COLUMN NINE"
       write(171,'(A120)') "## INTEGRATED DIFFERENTIAL OSCILLATOR STRENGTH (FOR SUM RULE) IN COLUMN 10"
       write(171,*)
       
       do i=0,numdata
          myenergy=i*Estep

!! LENGTH GAUGE (electric field) WAS FT'ed , OK with usual formula multiply by wfi
!! UNITLESS RESPONSE FUNCTION FOR ABSORPTION/EMISSION 2 omega im(D(omega)E(omega)^*) IN COLUMN 7
!! QUANTUM MECHANICAL PHOTOABSORPTION/EMISSION CROSS SECTION IN MEGABARNS (no factor of 1/3) IN COLUMN NINE
!! INTEGRATED DIFFERENTIAL OSCILLATOR STRENGTH (FOR SUM RULE) IN COLUMN 10

          xsecunits = 5.291772108d0**2 * 4d0 * PI / 1.37036d2 * myenergy

!! NOW FACTOR (2 omega) IN COLUMNS 6,7   v1.16 12-2015

          write(171,'(F18.12, T22, 400E20.8)',iostat=myiostat)  myenergy, &
               fftrans(i), eft(i), fftrans(i)*conjg(eft(i)) * 2 * myenergy, &
               fftrans(i)*conjg(eft(i)) / abs(eft(i)**2) * xsecunits, xsums(i)
       enddo
       call checkiostat(myiostat,"writing "//outftname)
       close(171)

!!  NUMBER OF PHOTONS ABSORBED AND AND WORK DONE BY EACH PULSE
!!  worksum0 the time integral converges right after pulse is finished... others take longer

       open(171,file=outoworkname,status="unknown",iostat=myiostat)
       call checkiostat(myiostat,"opening "//outoworkname)
       do i=0,numdata
          write(171,'(A25,F10.5,400F15.10)') " WORK EACH PULSE E= ", i*Estep, totworksums(i),worksums(i,:)
       enddo
       close(171)

       open(171,file=outophotonname,status="unknown",iostat=myiostat)
       call checkiostat(myiostat,"opening "//outophotonname)
       do i=0,numdata
          write(171,'(A25,F10.5,400F15.10)') "PHOTONS EACH PULSE E= ", i*Estep, totexsums(i),exsums(i,:)
       enddo
       close(171)

       if (sflag.ne.0) then
          write(number,'(I7)') 1000000+floor(thistime)
          open(171,file=outftname(1:getlen(outftname))//number(2:7),status="unknown",iostat=myiostat)
          call checkiostat(myiostat,"opening "//outftname)
          write(171,'(A120)',iostat=myiostat) &
               "## Photon energy (column 1); D(omega) (2,3); E(omega) (4,5); response (6,7); cross sect (9); integrated (10)" 
          call checkiostat(myiostat,"writing "//outftname)
          write(171,'(A120)') "## UNITLESS RESPONSE FUNCTION FOR ABSORPTION/EMISSION 2 omega im(D(omega)E(omega)^*) IN COLUMN 7"
          write(171,'(A120)') "## QUANTUM MECHANICAL PHOTOABSORPTION/EMISSION CROSS SECTION IN MEGABARNS (no factor of 1/3) IN COLUMN NINE"
          write(171,'(A120)') "## INTEGRATED DIFFERENTIAL OSCILLATOR STRENGTH (FOR SUM RULE) IN COLUMN 10"
          write(171,*)

          do i=0,numdata
             myenergy=i*Estep

             xsecunits = 5.291772108d0**2 * 4d0 * PI / 1.37036d2 * myenergy

!! NOW FACTOR (2 omega) IN COLUMNS 6,7   v1.16 12-2015

             write(171,'(F18.12, T22, 400E20.8)',iostat=myiostat)  myenergy, &
                  fftrans(i), eft(i), fftrans(i)*conjg(eft(i)) * 2 * myenergy, &
                  fftrans(i)*conjg(eft(i)) / abs(eft(i)**2) * xsecunits, xsums(i)
          enddo
          call checkiostat(myiostat,"writing "//outftname)
          close(171)
       endif
    endif

    deallocate(fftrans,eft,all_eft,dipole_diff,worksums,worksum0,exsums,totworksums,&
         totworksum0,totexsums,xsums)

  end subroutine dipolecall

end subroutine dipolesub


subroutine checkorbsetrange(checknspf,flag)
  use parameters
  implicit none
  integer,intent(in) :: checknspf
  integer,intent(out) :: flag
  flag=0
  if (nspf.ne.checknspf) then
     flag=1
  endif
end subroutine checkorbsetrange


module dipbiomod
  use biorthotypemod
  implicit none
  type(biorthotype),target :: dipbiovar
end module dipbiomod


subroutine dipolesub_one(www,bioww,in_abra,&    !! ok unused bioww
     in_aket,inspfs,dipole_expects)
  use r_parameters
  use spfsize_parameters
  use walkmod
  use fileptrmod
  use dotmod
  use dipbiomod
  use biorthomod
  use arbitrarymultmod
  use orbgathersubmod
  use mpisubmod
  implicit none
  type(walktype),intent(in) :: www,bioww
  DATATYPE, intent(in) :: inspfs(  spfsize, www%nspf ), &
       in_abra(numr,www%firstconfig:www%lastconfig),&
       in_aket(numr,www%firstconfig:www%lastconfig)
  DATATYPE,intent(out) :: dipole_expects(3)
  DATATYPE,allocatable :: tempvector(:,:),tempspfs(:,:),abra(:,:),workspfs(:,:),&
       aket(:,:)
  DATATYPE :: nullcomplex(1),dipoles(3), dipolemat(www%nspf,www%nspf),csum
  DATAECS :: rvector(numr)
!!$  DATATYPE :: norm   !! datatype in case abra.ne.aket
  integer :: i,lowspf,highspf,numspf
#ifdef CNORMFLAG
  DATATYPE,target :: smo(www%nspf,www%nspf)
#endif

  lowspf=1; highspf=www%nspf
  if (parorbsplit.eq.1) then
     call checkorbsetrange(www%nspf,i)
     if (i.ne.0) then
        OFLWR "error exit, can't do dipolesub parorbsplit.eq.1 with",www%nspf,"orbitals"; CFLST
     endif
     call getOrbSetRange(lowspf,highspf)
  endif
  numspf=highspf-lowspf+1
 
  allocate(tempvector(numr,www%firstconfig:www%lastconfig+1), tempspfs(spfsize,lowspf:highspf+1),&
       abra(numr,www%firstconfig:www%lastconfig+1),workspfs(spfsize,www%nspf),&
       aket(numr,www%firstconfig:www%lastconfig+1))

  tempvector=0; tempspfs=0; workspfs=0; abra=0; aket=0

  if (www%lastconfig.ge.www%firstconfig) then
     abra(:,www%firstconfig:www%lastconfig)=in_abra(:,:)
     aket(:,www%firstconfig:www%lastconfig)=in_aket(:,:)
  endif

#ifndef CNORMFLAG
  workspfs(:,:)=inspfs(:,:)
#else
  call bioset(dipbiovar,smo,numr,bioww)
  dipbiovar%hermonly=.true.
  call biortho(inspfs,inspfs,workspfs,abra,dipbiovar)
  dipbiovar%hermonly=.false.
#endif


!!$  csum=dot(abra,aket,www%totadim)
!!$  if (www%parconsplit.ne.0) then
!!$     call mympireduceone(csum)
!!$  endif
!!$  norm=sqrt(csum)

!! independent of R for now.  multiply by R for prolate  (R set to 1 for atom)
  call nucdipvalue(nullcomplex,dipoles)

  do i=1,numr
     tempvector(i,:)=aket(i,:)*bondpoints(i)
  enddo
  csum=0d0
  if (www%totadim.gt.0) then
     csum=hermdot(abra,tempvector,www%totadim)
  endif
  if (www%parconsplit.ne.0) then
     call mympireduceone(csum)
  endif
  dipoles(:)=dipoles(:)*csum

!! Z DIPOLE

  dipolemat(:,:)=0d0
  if (numspf.gt.0) then
     call mult_zdipole(numspf,inspfs(:,lowspf:highspf),tempspfs(:,lowspf:highspf),1)
     call MYGEMM('C','N',www%nspf,numspf,spfsize,DATAONE, workspfs, spfsize, &
          tempspfs(:,lowspf:highspf), spfsize, DATAZERO, dipolemat(:,lowspf:highspf), www%nspf)
  endif
  if (parorbsplit.eq.1) then
     call mpiorbgather(dipolemat,www%nspf)
  endif
  if (parorbsplit.eq.3) then
     call mympireduce(dipolemat(:,:),www%nspf**2)
  endif

  rvector(:)=bondpoints(:)
  call arbitraryconfig_mult_singles(www,dipolemat,rvector,aket,tempvector,numr)
  dipole_expects(3)=0d0
  if (www%totadim.gt.0) then
     dipole_expects(3)=hermdot(abra,tempvector,www%totadim)
  endif
  if (www%parconsplit.ne.0) then
     call mympireduceone(dipole_expects(3))
  endif
  dipole_expects(3)=dipole_expects(3) + dipoles(3)

!! Y DIPOLE

  dipolemat(:,:)=0d0
  if (numspf.gt.0) then
     call mult_ydipole(numspf,inspfs(:,lowspf:highspf),tempspfs(:,lowspf:highspf),1)

     call MYGEMM('C','N',www%nspf,numspf,spfsize,DATAONE, workspfs, spfsize, &
          tempspfs(:,lowspf:highspf), spfsize, DATAZERO, dipolemat(:,lowspf:highspf), www%nspf)
  endif
  if (parorbsplit.eq.1) then
     call mpiorbgather(dipolemat,www%nspf)
  endif
  if (parorbsplit.eq.3) then
     call mympireduce(dipolemat(:,:),www%nspf**2)
  endif

  rvector(:)=bondpoints(:)
  call arbitraryconfig_mult_singles(www,dipolemat,rvector,aket,tempvector,numr)
  dipole_expects(2)=0d0
  if (www%totadim.gt.0) then
     dipole_expects(2)=hermdot(abra,tempvector,www%totadim)
  endif
  if (www%parconsplit.ne.0) then
     call mympireduceone(dipole_expects(2))
  endif
  dipole_expects(2)=dipole_expects(2) + dipoles(2)

!! X DIPOLE

  dipolemat(:,:)=0d0
  if (numspf.gt.0) then
     call mult_xdipole(numspf,inspfs(:,lowspf:highspf),tempspfs(:,lowspf:highspf),1)

     call MYGEMM('C','N',www%nspf,numspf,spfsize,DATAONE, workspfs, spfsize, &
          tempspfs(:,lowspf:highspf), spfsize, DATAZERO, dipolemat(:,lowspf:highspf), www%nspf)
  endif
  if (parorbsplit.eq.1) then
     call mpiorbgather(dipolemat,www%nspf)
  endif
  if (parorbsplit.eq.3) then
     call mympireduce(dipolemat(:,:),www%nspf**2)
  endif

  rvector(:)=bondpoints(:)
  call arbitraryconfig_mult_singles(www,dipolemat,rvector,aket,tempvector,numr)
  dipole_expects(1)=0d0
  if (www%totadim.gt.0) then
     dipole_expects(1)=hermdot(abra,tempvector,www%totadim)
  endif
  if (www%parconsplit.ne.0) then
     call mympireduceone(dipole_expects(1))
  endif
  dipole_expects(1)=dipole_expects(1) + dipoles(1)

  deallocate(tempvector,tempspfs,abra,aket,workspfs)

!!$#ifdef CNORMFLAG
!!$  dipole_expects(1)=dipole_expects(1)*abs(norm)/norm
!!$  dipole_expects(2)=dipole_expects(2)*abs(norm)/norm
!!$  dipole_expects(3)=dipole_expects(3)*abs(norm)/norm
!!$#endif

end subroutine dipolesub_one


subroutine dipolesub_final()
  use dipolemod
  implicit none
  deallocate( dipoleexpects, dipolenormsq)

end subroutine dipolesub_final


