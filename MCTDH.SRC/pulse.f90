
#include "Definitions.INC"


module pulsesubmod
contains

subroutine vectdpot(myintime,invelflag,tdpotsout,imc)
  use pulse_parameters
  implicit none
  real*8,intent(in) :: myintime
  integer, intent(in) :: invelflag,imc
  DATATYPE,intent(out) :: tdpotsout(3)

  call vectdpot0(myintime,invelflag,tdpotsout,imc,1,numpulses)

end subroutine vectdpot


subroutine vectdpot0(myintime,invelflag,tdpotsout,imc,ilow,ihigh)
  use pulse_parameters
  use fileptrmod
  implicit none
  integer, intent(in) :: invelflag,imc,ilow,ihigh
  real*8,intent(in) :: myintime
  DATATYPE,intent(out) :: tdpotsout(3)

  if (invelflag.eq.0) then
     tdpotsout(1)=tdpotlen0(myintime,1,ilow,ihigh)
     tdpotsout(2)=tdpotlen0(myintime,2,ilow,ihigh)
     tdpotsout(3)=tdpotlen0(myintime,3,ilow,ihigh)
  else
     tdpotsout(1)=tdpotvel0(myintime,1,ilow,ihigh)
     tdpotsout(2)=tdpotvel0(myintime,2,ilow,ihigh)
     tdpotsout(3)=tdpotvel0(myintime,3,ilow,ihigh)
  endif

!  if (conjgpropflag.ne.0) then
!     select case (imc)
!     case(-1)
!        tdpotsout(:)=real(tdpotsout(:),8)
!     case(1)
!     case(2)
!        tdpotsout(:)=ALLCON(tdpotsout(:))
!     case default
!        OFLWR "WHOOPS?? conjgprop",imc; CFLST
!     end select
!  endif

end subroutine vectdpot0


function tdpotlen0(myintime, which,ilow,ihigh)
  use pulse_parameters
  use fileptrmod
  implicit none
  integer,intent(in) :: which,ilow,ihigh
  real*8,intent(in) :: myintime
  integer :: ipulse
  real*8 :: fac
  DATATYPE :: tdpotlen0

  tdpotlen0=0.d0

!!  do ipulse=1,numpulses

  do ipulse=ilow,ihigh

     if (which==3) then !! z component
        fac=cos(pulsetheta(ipulse))
     else if (which==1) then
        fac=sin(pulsetheta(ipulse))*cos(pulsephi(ipulse))
     else if (which==2) then
        fac=sin(pulsetheta(ipulse))*sin(pulsephi(ipulse))
     else 
        OFLWR "ACK which = ",which," not allowed tdpotlen0"; CFLST
        fac=798d0   !! avoid warn unused
     endif

     if (fac.ne.0d0) then
        select case (pulsetype(ipulse))
        case (1)
           tdpotlen0=tdpotlen0+simplepulselen(myintime,ipulse) * fac
        case (2)
           tdpotlen0=tdpotlen0+pulselen(myintime,ipulse) * fac
        case (3)
           tdpotlen0=tdpotlen0+longpulselen(myintime,ipulse) * fac
        case (4)
           tdpotlen0=tdpotlen0+cwpulselen(myintime,ipulse) * fac
        case (5)
           tdpotlen0=tdpotlen0+monopulselen(myintime,ipulse) * fac
        case default
           OFLWR "Pulse type not supported: ", pulsetype(ipulse); CFLST
        end select
     endif
  enddo
  
end function tdpotlen0


function tdpotvel0(myintime,which,ilow,ihigh)
  use pulse_parameters
  use fileptrmod
  implicit none
  integer,intent(in) :: which,ilow,ihigh
  real*8,intent(in) :: myintime
  integer :: ipulse
  real*8 :: fac
  DATATYPE :: tdpotvel0

  tdpotvel0=0.d0

!!  do ipulse=1,numpulses

  do ipulse=ilow,ihigh

     if (which==3) then !! z component
        fac=cos(pulsetheta(ipulse))
     else if (which==1) then
        fac=sin(pulsetheta(ipulse))*cos(pulsephi(ipulse))
     else if (which==2) then
        fac=sin(pulsetheta(ipulse))*sin(pulsephi(ipulse))
     else 
        OFLWR "ACK which = ",which," not allowed tdpotvel0"; CFLST
        fac=798d0   !! avoid warn unused
     endif

     if (fac.ne.0d0) then
        select case (pulsetype(ipulse))
        case (1)
           tdpotvel0=tdpotvel0+simplepulsevel(myintime, ipulse) * fac
        case (2)
           tdpotvel0=tdpotvel0+pulsevel(myintime, ipulse) * fac
        case (3)
           tdpotvel0=tdpotvel0+longpulsevel(myintime, ipulse) * fac
        case (4)
           tdpotvel0=tdpotvel0+cwpulsevel(myintime, ipulse) * fac
        case (5)
           tdpotvel0=tdpotvel0+monopulsevel(myintime, ipulse) * fac
        case default
           OFLWR "Pulse type not supported: ", pulsetype(ipulse); CFLST
        end select
     endif
  enddo

end function tdpotvel0


function simplepulselen(myintime, ipulse)
  use pulse_parameters
  use constant_parameters
  implicit none
  integer,intent(in) :: ipulse
  real*8,intent(in) :: myintime
  real*8 :: time
  DATATYPE :: simplepulselen

  simplepulselen=0.d0

  if (myintime.ge.pulsestart(ipulse)) then
     time=myintime-pulsestart(ipulse)
     if (time.le.pi/omega(ipulse)) then

        simplepulselen = pulsestrength(ipulse) * omega(ipulse) * &
             ( sin(time*omega(ipulse))*cos(time*omega(ipulse) + phaseshift(ipulse)) &
             + sin(time*omega(ipulse) + phaseshift(ipulse))*cos(time*omega(ipulse)) )

     endif
  endif
end function simplepulselen


function simplepulsevel(myintime, ipulse)
  use pulse_parameters
  use constant_parameters
  implicit none
  integer,intent(in) :: ipulse
  real*8,intent(in) :: myintime
  real*8 :: time
  DATATYPE :: simplepulsevel

  simplepulsevel=0.d0

  if (myintime.ge.pulsestart(ipulse)) then
     time=myintime-pulsestart(ipulse)
     if (time.le.pi/omega(ipulse)) then

        simplepulsevel = pulsestrength(ipulse) * &
             sin(time*omega(ipulse)) * sin(time*omega(ipulse) + phaseshift(ipulse) )

     endif
  endif

end function simplepulsevel


function cwpulselen(myintime, ipulse)
  use pulse_parameters
  use constant_parameters
  implicit none
  integer,intent(in) :: ipulse
  real*8,intent(in) :: myintime
  DATATYPE :: cwpulselen

  cwpulselen=0d0
  if (myintime.lt.pi/omega(ipulse)) then
     cwpulselen = pulsestrength(ipulse) * omega2(ipulse) * &
          cos(myintime*omega2(ipulse)+phaseshift(ipulse))
  endif

end function cwpulselen


function cwpulsevel(myintime, ipulse)
  use pulse_parameters
  use constant_parameters
  implicit none
  integer,intent(in) :: ipulse
  real*8,intent(in) :: myintime
  DATATYPE :: cwpulsevel

  cwpulsevel=0.d0
  if (myintime.lt.pi/omega(ipulse)) then
     cwpulsevel = pulsestrength(ipulse) * sin(myintime*omega2(ipulse) + phaseshift(ipulse))
  endif

end function cwpulsevel


function monopulselen(myintime, ipulse)
  use pulse_parameters
  use constant_parameters
  implicit none
  integer,intent(in) :: ipulse
  real*8,intent(in) :: myintime
  real*8 :: pptime
  DATATYPE :: monopulselen

  pptime=myintime*omega(ipulse) - pi/2

  if (pptime.lt.pi/2) then
     monopulselen = pulsestrength(ipulse) * (0.75d0*cos(pptime) + cos(3*pptime)/4d0)
  else
     monopulselen = 0
  end if

end function monopulselen


function monopulsevel(myintime, ipulse)
  use pulse_parameters
  use constant_parameters
  implicit none
  integer,intent(in) :: ipulse
  real*8,intent(in) :: myintime
  real*8 :: pptime
  DATATYPE :: monopulsevel

  pptime=myintime*omega(ipulse) - pi/2

  if (pptime.lt.pi/2) then
     monopulsevel = pulsestrength(ipulse) * (0.75d0*sin(pptime) + sin(3*pptime)/12d0 + 2d0/3d0)
  else
     monopulsevel = pulsestrength(ipulse) * (4d0/3d0)
  endif

end function monopulsevel




function pulselen(myintime, ipulse)
  use pulse_parameters
  use constant_parameters
  use fileptrmod
  implicit none
  integer,intent(in) :: ipulse
  real*8,intent(in) :: myintime
  real*8 :: time
  DATATYPE :: pulselen

  pulselen=0.d0

  if (chirp(ipulse).ne.0d0.or.ramp(ipulse).ne.0d0) then
     OFLWR "Chirp / ramp not supported for length", chirp(ipulse), ipulse; CFLST
  endif
  if (myintime.ge.pulsestart(ipulse)) then
     time=myintime-pulsestart(ipulse)
     if (time.le.pi/omega(ipulse)) then
        pulselen = pulsestrength(ipulse) * ( &
             2*omega(ipulse)*sin(time*omega(ipulse))*cos(time*omega(ipulse)) * &
             sin((time-pi/omega(ipulse)/2)*omega2(ipulse) + phaseshift(ipulse)) &
             + sin(time*omega(ipulse))**2 * omega2(ipulse) * &
             cos((time-pi/omega(ipulse)/2)*omega2(ipulse) + phaseshift(ipulse)) )
     endif
  endif

end function pulselen


function pulsevel(myintime, ipulse)
  use pulse_parameters
  use constant_parameters
  implicit none
  integer,intent(in) :: ipulse
  real*8,intent(in) :: myintime
  real*8 :: time,thisomega2
  DATATYPE :: pulsevel, thisstrength

  pulsevel=0.d0

  if (myintime.ge.pulsestart(ipulse)) then
     time=myintime-pulsestart(ipulse)

!!# notice denominator here , half the total pulse time: energy at start of pulse 
!!# is omega2-chirp; at 1/4 pulse omega2-chirp/2; at 3/4 omega2+chirp/2; end of pulse 
!!# omega2+chirp.  Therefore with given value of chirp, will span this range of 
!!# energies over FWHM.

     thisomega2=omega2(ipulse)+chirp(ipulse)*(time-pi/omega(ipulse)/2)/(pi/omega(ipulse)/2)   /2

     thisstrength=pulsestrength(ipulse)*(1d0+ramp(ipulse) * &
          (time-pi/omega(ipulse)/2)/(pi/omega(ipulse)/2))

     if (time.le.pi/omega(ipulse)) then
        pulsevel = thisstrength * sin(time*omega(ipulse))**2 * &
             sin((time-pi/omega(ipulse)/2)*thisomega2 + phaseshift(ipulse))
     endif
  endif

end function pulsevel


!! wtf with longstep...  why did I do it 2* longstep+1?  So for longstep 0, no constant part of
!!  envelope; for longstep 1, constant part is middle 2/3 of pulse.

function longpulselen(myintime, ipulse)
  use pulse_parameters
  use constant_parameters
  use fileptrmod
  implicit none
  integer,intent(in) :: ipulse
  real*8,intent(in) :: myintime
  real*8 :: time, fac, fac2
  DATATYPE :: longpulselen

  longpulselen=0.d0

  if (chirp(ipulse).ne.0d0.or.ramp(ipulse).ne.0d0) then
     OFLWR "Chirp not supported for length", chirp(ipulse), ipulse; CFLST
  endif
  if (myintime.ge.pulsestart(ipulse)) then
     time=myintime-pulsestart(ipulse)

     if (time.le.pi/omega(ipulse)) then

        if ( (time.le.pi/2.d0/omega(ipulse)/(2*longstep(ipulse)+1)) .or.&
             (time.ge.pi/omega(ipulse) - pi/2.d0/omega(ipulse)/(2*longstep(ipulse)+1)) ) then
           fac=2*omega(ipulse)*(2*longstep(ipulse)+1)*sin(time*omega(ipulse)*(2*longstep(ipulse)+1)) * &
                cos(time*omega(ipulse)*(2*longstep(ipulse)+1))
           fac2=sin(time*omega(ipulse)*(2*longstep(ipulse)+1))**2
        else
           fac=0.d0
           fac2=1.d0
        endif

        longpulselen = pulsestrength(ipulse) * ( &
             fac * sin(time*omega2(ipulse) + phaseshift(ipulse)) &
          + fac2 * omega2(ipulse) * cos(time*omega2(ipulse) + phaseshift(ipulse)) )
     endif
  endif

end function longpulselen


function longpulsevel(myintime, ipulse)
  use pulse_parameters
  use constant_parameters
  implicit none
  integer,intent(in) :: ipulse
  real*8,intent(in) :: myintime
  real*8 :: time, thisomega2
  DATATYPE :: longpulsevel,thisstrength

  longpulsevel=0.d0

  if (myintime.ge.pulsestart(ipulse)) then
     time=myintime-pulsestart(ipulse)

     if (time.le.pi/omega(ipulse)) then

!! this is right I think  goes to chirp/2  when 2*logstep+1 / 4*longstep+2 -way before half time

        thisomega2=omega2(ipulse)+chirp(ipulse)/2 *(time-pi/omega(ipulse)/2)/&
             (pi/omega(ipulse)/2*(2*longstep(ipulse)+1)/(4*longstep(ipulse)+2))
        thisstrength=pulsestrength(ipulse)*(1d0 +ramp(ipulse) * &
             (time-pi/omega(ipulse)/2)/(pi/omega(ipulse)/2))

!!(2*longstep(ipulse)+1)/(4*longstep(ipulse)+2)))

        if ( (time.le.pi/2.d0/omega(ipulse)/(2*longstep(ipulse)+1)) .or. &
             (time.ge.pi/omega(ipulse) - pi/2.d0/omega(ipulse)/(2*longstep(ipulse)+1)) ) then
          longpulsevel = thisstrength  * &
               sin((time-pi/omega(ipulse)/2)*thisomega2 + phaseshift(ipulse)) * &
               sin(time*omega(ipulse)*(2*longstep(ipulse)+1))**2 
        else
           longpulsevel = thisstrength * &
                sin((time-pi/omega(ipulse)/2)*thisomega2 + phaseshift(ipulse))
        endif
     endif
  endif
  
end function longpulsevel


!! not useful because tentmode=1 isn't better than tentmode=0; tentmode=0 default;
!! keeping these subroutines anyway

function get_rtentsum(num,vec)
  use parameters   !! tentmode
  implicit none
  real*8 :: get_rtentsum
  integer,intent(in) :: num
  real*8, intent(in) :: vec(-num:num)
  integer :: itent,jtent

  if (num.lt.0) then
     OFLWR "rtentsumerror", num; CFLST
  elseif (num.eq.0) then
     get_rtentsum=vec(0)
     return
  endif

  if (tentmode.eq.0) then
     itent=0
     jtent=1
  else
     itent=(num+1)/2 * (-1)
     jtent=(num+1)/2
  endif

  get_rtentsum = SUM(vec(-num:itent)) + SUM(vec(jtent:num))

end function get_rtentsum

function get_ctentsum(num,vec)
  use parameters   !! tentmode
  implicit none
  complex*16 :: get_ctentsum
  integer,intent(in) :: num
  complex*16, intent(in) :: vec(-num:num)
  integer :: itent,jtent

  if (num.lt.0) then
     OFLWR "ctentsumerror", num; CFLST
  elseif (num.eq.0) then
     get_ctentsum=vec(0)
     return
  endif

  if (tentmode.eq.0) then
     itent=0
     jtent=1
  else
     itent=(num+1)/2 * (-1)
     jtent=(num+1)/2
  endif

  get_ctentsum = SUM(vec(-num:itent)) + SUM(vec(jtent:num))

end function get_ctentsum
  

end module pulsesubmod
