
!!! MAIN SUBROUTINE FOR READING NAMELIST INPUT AND COMMAND LINE OPTIONS
  
#include "Definitions.INC"
  
function getlen(buffer)
  implicit none
  character buffer*(*)
  integer :: j, getlen, mylen
  mylen=LEN(buffer)
  j=1
  do while ((j.lt.mylen).and..not.(buffer(j:j) .eq. " "))
     j=j+1
  enddo
  getlen=j
end function getlen
 

subroutine getinpfile()
  use parameters
  use mpimod
  implicit none

  integer :: nargs, getlen, i, len
#ifdef PGFFLAG
  integer :: myiargc
#endif
  character (len=200) :: buffer

#ifdef PGFFLAG
  nargs=myiargc()
#else
  nargs=iargc()
#endif
  do i=1,nargs
     buffer=nullbuff;     call getarg(i,buffer);     len=getlen(buffer)
     if (buffer(1:4) .eq. 'Inp=') then
        inpfile=nullbuff;        inpfile(1:len-4)=buffer(5:len)
        OFLWR "Inpfile is ", inpfile(1:len-4+1); CFL
     endif
  enddo
end subroutine getinpfile

subroutine getparams()
  use parameters
  use denreg_parameters
  use bio_parameters
  use constraint_parameters
  use lan_parameters
  use output_parameters
  use mpimod
  use orblabelmod
  implicit none

  integer :: nargs, getlen, i, len,  ishell, ispf,j, myiostat, iiflag,needpulse
#ifdef PGFFLAG
  integer :: myiargc
#endif
  character (len=200) :: buffer
  integer :: shelltop(100)=-1            !! greater than zero: not full CI.  Number of orbitals in core shell.  Must be even.
  integer :: avectorhole(1000)=-1001
  integer :: avectorexcitefrom(1000)=-1001
  integer :: avectorexciteto(1000)=-1001
  real*8 :: tempreal

!! DUMMIES
  integer :: restrictms=0
  integer :: dfrestrictflag=0
  integer :: allspinproject=1

  NAMELIST/parinp/  noftflag, biodim,biotol,biocomplex, rdenflag,cdenflag, notiming, littlesteps, &
       expotol, eground,  ceground, maxexpodim, numloadfrozen, numholecombo, numholes, excitations, &
       excitecombos, jacsymflag, jacprojorth,jacgmatthird,  fluxoptype, timefac, threshflag, &
       timefacforce, avectoroutfile, spfoutfile,  autopermthresh, messamount, numshells,   &
       lanthresh, lanczosorder,  lioreg, &   !! rcond
       autonormthresh,  saveflag, save_every, &
       mrestrictflag, mrestrictval, fluxtimestep, autotimestep,  nucfluxflag, &
       nosparseforce,  allspinproject,  numfluxfiles,  verletnum, &
       constraintflag, dfrestrictflag, improvedrelaxflag, mcscfnum,  improvednatflag, avectorfile, spffile, &
       quadprecon,  improvedquadflag, quadtol,  &
       plotxyrange,plotrange,plotskip,pm3d, plotterm, plotmodulus,plotpause, numfluxcurves,  & 
       plotres, nspf ,  spfrestrictflag,  spfmvals, spfugvals, spfugrestrict, ugrestrictflag, ugrestrictval, &
       restrictflag,  restrictms,   loadspfflag,  loadavectorflag,  avectorhole, &
       par_timestep,  stopthresh ,  cmf_flag,  intopt, timedepexpect,  avector_flag, &
       numelec,  relerr,  myrelerr,  spf_flag,  denreg,  timingout, tdflag, finaltime, actions, numactions, &
       messflag,  sparseconfigflag,  aorder, maxaorder, aerror, shelltop, numexcite, povres, povrange,&
       numpovranges, povsparse,  povmult, vexcite, plotnum,lancheckstep,  plotview1, plotview2, &
       computeFlux, FluxInterval, FluxSkipMult, &
       numfrozen, nucfluxopt, natplotbin, spfplotbin, denplotbin, denprojplotbin, &
       natprojplotbin, rnatplotbin, dendatfile, denrotfile, rdendatfile,   avectorexcitefrom, avectorexciteto,&
       numovlfiles, ovlavectorfiles, ovlspffiles, outovl,fluxmofile,fluxafile, spifile, astoptol,  &
       zdftfile,zdipfile,ydftfile,ydipfile,xdftfile,xdipfile, dipolewindowpower, diffdipoleflag,  &
       diptime, fluxafile2,fluxmofile2, minocc,maxocc, corrdatfile,corrftfile,numavectorfiles,projfluxfile, &
       expodim,timingdir, hanningflag, numspffiles, condamp,conway, &
       mrestrictmin,mrestrictmax,lntol,invtol,psistatsfile, psistatfreq, configlistfile, &
       parorbsplit,maxbiodim, nkeproj,keprojminenergy,keprojenergystep,keprojminrad,keprojmaxrad, &
       debugflag, drivingflag,drivingproportion, drivingmethod, eigprintflag, &
       avecloadskip,nonsparsepropmode,sparseopt,lanprintflag,dipmodtime,conprop,&
       orbcompact,spin_restrictval,mshift,numskiporbs,orbskip,debugfac,denmatfciflag,&
       walkwriteflag,iprintconfiglist,timestepfac,max_timestep,expostepfac, maxquadnorm,quadstarttime,&
       reinterp_orbflag,spf_gridshift,load_avector_product,projspifile,readfullvector,walksinturn,&
       turnbatchsize,energyshift, pulseft_estep, finalstatsfile, projgtaufile,gtaufile,&
       sparsedfflag,sparseprime,sparsesummaflag, par_consplit


  OFL
  write(mpifileptr, *)
  write(mpifileptr, *) " *************************  COMMAND LINE OPTIONS  ***************************"
  write(mpifileptr, *) 
  CFL
#ifdef PGFFLAG
  nargs=myiargc()
#else
  nargs=iargc()
#endif

  numfluxcurves=0;  numfluxcurves(1)=1

#ifdef REALGO
  conway=0
#else
  conway=3
#endif


  open(971,file=inpfile, status="old", iostat=myiostat)
  if (myiostat/=0) then
     OFLWR "No Input.Inp found for parinp, iostat=",myiostat; CFL
  else
     OFLWR "Reading ",inpfile; CFL
     read(971,nml=parinp)
     restrict_ms=restrictms
     all_spinproject=allspinproject
     df_restrictflag=dfrestrictflag

!! input dependent defaults

!     if (constraintflag.eq.2) then
!        lioreg=1d-4
!     endif

     if (improvedrelaxflag.ne.0) then
        maxexpodim=max(300,maxexpodim)
        expodim=max(40,expodim)
     endif

     if (intopt.eq.4) then
        expotol=min(1d-9,expotol)
     endif

     if (improvedrelaxflag.ne.0) then
        expotol=min(expotol,1d-9)
     endif

     if (spin_restrictval.lt.abs(restrictms)) then
        spin_restrictval=abs(restrictms)
     endif

     if (improvedrelaxflag.ne.0) then    !! not good.  reprogram this whole thing later.  Defaults here should
        denreg=1.d-9                     !!   go after a first parinp AND command line argument parse; then repeat
     endif
     if (improvedrelaxflag.ne.0) then
        aorder=max(300,aorder)
        maxaorder=max(aorder,maxaorder)
     endif
     close(971);     open(971,file=inpfile, status="old");     read(971,nml=parinp)
  endif
  close(971)

  
!  if (num_skip_orbs.gt.10) then
!     OFLWR " Redimension skip orbs arrays in parameters.f90."; CFLST
!  endif

  !!   ************************************************************************************************************************
  !!
  !!    Coord-Dependent Namelist Input and Command Line Options are SUBSERVIENT to MCTDHF Options  (but bo_checkflag=1 
  !!        sets nonuc_checkflag=1)
  !!
  !!   ************************************************************************************************************************


!! These are options that cannot be superceded in geth2opts (including in mcloop)
  do i=1,nargs
     buffer=nullbuff;    call getarg(i,buffer);     len=getlen(buffer)

     if (buffer(1:5) .eq. 'Nspf=') then
        read(buffer(6:len),*) nspf;   
        OFLWR "Nspf set to  ", nspf, " by command line option."; CFL
     endif
  enddo

  !!   NOW TAKE MCTDHF NAMELIST AND COMMAND LINE INPUT

  call openfile()

  !! NOTE THAT LBIG IS NOT A COMMAND LINE OPTION; IS IN LOOP IN GETH2OPTS.  So as of now it is set.  change later.

  do i=1,nargs
     buffer=nullbuff;     call getarg(i,buffer);     len=getlen(buffer)

     if (buffer(1:9) .eq. 'NoTiming=') then
        read(buffer(10:len),*) notiming
        write(mpifileptr, *) "notiming variable set to ",notiming," by command line input."
     endif
     if (buffer(1:7) .eq. 'Timing=') then
        read(buffer(8:len),*) j
        notiming=2-j
        write(mpifileptr, *) "notiming variable set to ",notiming," by command line input."
     endif
     if (buffer(1:4) .eq. 'Rel=') then
        read(buffer(5:len),*) relerr
        write(mpifileptr, *) "Relative error for spf prop set to ", relerr, " by command line option."
     endif
     if (buffer(1:9) .eq. 'FluxSkip=') then
        read(buffer(10:len),*) fluxskipmult
        write(mpifileptr, *) "Fluxskipmult set to ", fluxskipmult, " by command line option."
     endif
     if (buffer(1:6) .eq. 'Myrel=') then
        read(buffer(7:len),*) myrelerr
        write(mpifileptr, *) "Absolute error (myrelerr) for spf prop set to ", myrelerr, " by command line option."
     endif
     if (buffer(1:9) .eq. 'PovRange=') then
        read(buffer(10:len),*) tempreal
        write(mpifileptr, *) "Povrange set to ", tempreal
        povrange=tempreal  !! all of them
     endif
     if (buffer(1:2) .eq. 'M=') then
        mrestrictflag=1
        read(buffer(3:len),*) mrestrictval
        write(mpifileptr, *) "Restricting configs to ", mrestrictval, " by command line option."
     endif
     if (buffer(1:5) .eq. 'Debug') then
        if (.not.buffer(1:6) .eq. 'Debug=') then
           WRFL "Please specify debug flag option N with command line Debug=N not just Debug"; CFLST
        endif
        read(buffer(7:len),*) debugflag
        write(mpifileptr, *) "Debugflag set to ",debugflag," by command line option"
     endif
     if (buffer(1:5) .eq. 'Walks') then
        walkwriteflag=1
        write(mpifileptr, *) "Walks will be written by command line option"
     endif
     if (buffer(1:7) .eq. 'NoWalks') then
        walkwriteflag=0
        write(mpifileptr, *) "Walks will not be written by command line option"
     endif
     if (buffer(1:2) .eq. 'A=') then
        avectorfile(:)=nullbuff
        avectorfile(:)(1:len-2)=buffer(3:len)
        write(mpifileptr, *) "Avector file is ", avectorfile(1)(1:len-2+1)
        write(mpifileptr, *) "    Loadavectorflag turned on."
        loadavectorflag=1
     endif
     if (buffer(1:4) .eq. 'Spf=') then
        spffile=nullbuff
        spffile(:)(1:len-4)=buffer(5:len)
        write(mpifileptr, *) "Spf file is ", spffile(1)(1:len-4+1)
        write(mpifileptr, *) "    Loadspfflag turned on."
        loadspfflag=1
     endif
     if (buffer(1:5) .eq. 'Pulse') then
        write(mpifileptr, *) "Turning pulse on by command line option."
        tdflag=1
     endif
     if (buffer(1:6) .eq. 'SaveOn') then
        write(mpifileptr, *) "Saving wave function by command line option."
        saveflag=1
     endif
     if (buffer(1:7) .eq. 'SaveOff') then
        write(mpifileptr, *) "NOT Saving wave function by command line option."
        saveflag=0
     endif
#ifndef REALGO
     if (buffer(1:4) .eq. 'Prop') then
        write(mpifileptr, *) "  Forcing propagation in real time by command line option."
        improvedrelaxflag=0
     endif
#endif
     if (buffer(1:6) .eq. 'Relax=') then
        read(buffer(7:len),*) improvedrelaxflag
        write(mpifileptr, *) "  Forcing improved relaxation by command line option.  Relaxing to state ", improvedrelaxflag
     else
        if (buffer(1:5) .eq. 'Relax') then
           write(mpifileptr, *) "  Forcing improved relaxation to ground state by command line option."
           improvedrelaxflag=max(1,improvedrelaxflag)
        endif
     endif

! so you can input numactions=0 but specify the actions you would want in the input file, and then turn them on with:

     if (buffer(1:5) .eq. 'Noact') then
        numactions=0        
     endif
     if (buffer(1:6) .eq. 'Allact') then
        do while (actions(numactions+1).ne.0)
           numactions=numactions+1
        enddo
        write(mpifileptr,*) " Setting all specified actions on: they are ", actions(1:numactions)
     endif
     if (buffer(1:4) .eq. 'Act=') then
        numactions=numactions+1;        read(buffer(5:len),*) actions(numactions)
     endif
     if (buffer(1:4) .eq. 'Mess') then
        messflag=1;        messamount=1.d-3
        if (buffer(1:5) .eq. 'Mess=') then
           read(buffer(6:len),*) messamount
        endif
     endif
     if (buffer(1:9) .eq. 'Autoperm=') then
        read(buffer(10:len),*) autopermthresh
        write(mpifileptr,*) "Permutation threshold for autocorr set to ", autopermthresh
     endif

     if (buffer(1:3) .eq. 'VMF') then
        cmf_flag=0;        write(mpifileptr, *) "VMF set by command line option"
     endif

     if (buffer(1:5) .eq. 'Step=') then
        read(buffer(6:len),*) par_timestep
        write(mpifileptr, *) "Timestep set to  ", par_timestep, " by command line option."
     endif

     if (buffer(1:10) .eq. 'Numfrozen=') then
        numshells=2
        read(buffer(11:len),*) shelltop(1)
        shelltop(2)=nspf
        write(mpifileptr, *) "Numshells set to 2 with  ", shelltop(1), " in the first shell by command line option."
     endif
     if (buffer(1:10) .eq. 'Numexcite=') then
        read(buffer(11:len),*) numexcite(1)
        write(mpifileptr, *) "Numexcite for first shell set to  ", numexcite(1), " by command line option."
     endif

     if (buffer(1:9) .eq. 'PlotSkip=') then
        read(buffer(10:len),*) plotskip
        write(mpifileptr, *) "Plotskip set to ", plotskip, " by command line option."
     endif
     if (buffer(1:7) .eq. 'PlotXY=') then
        read(buffer(8:len),*) plotxyrange
        write(mpifileptr, *) "Plot xy-range set to ", plotxyrange, " bohr by command line option."
     endif

     if (buffer(1:4) .eq. 'PM3D') then
        pm3d=1;        write(mpifileptr, *) "PM3D set to on."
     endif
     if (buffer(1:6) .eq. 'PlotZ=') then
        read(buffer(7:len),*) plotrange
        write(mpifileptr, *) "Plot z-range set to ", plotrange, " bohr by command line option."
     endif
     if (buffer(1:8) .eq. 'PlotNum=') then
        read(buffer(9:len),*) plotnum
        write(mpifileptr, *) "Plotnum set to ", plotnum, " bohr by command line option."
     endif
     if (buffer(1:8) .eq. 'PlotRes=') then
        read(buffer(9:len),*) plotres
        write(mpifileptr, *) "Plot resolution set to ", plotres, " bohr by command line option."
     endif
     if (buffer(1:10) .eq. 'PlotPause=') then
        read(buffer(11:len),*) plotpause
        write(mpifileptr, *) "Plotpause set to ", plotpause, " seconds by command line option."
     endif
     if (buffer(1:11) .eq. 'Stopthresh=') then
        read(buffer(12:len),*) stopthresh
        write(mpifileptr, *) "Stopthresh set to  ", stopthresh, " by command line option."
     endif
     if (buffer(1:6) .eq. 'Sparse') then
        write(mpifileptr, *) "Sparseconfigflag turned on by command line option."
        sparseconfigflag=1
     endif
     if (buffer(1:8) .eq. 'NoSparse') then
        write(mpifileptr, *) "Sparseconfigflag turned OFF by command line option."
        sparseconfigflag=0
     endif
     if (buffer(1:7) .eq. 'Denreg=') then
        read(buffer(8:len),*) denreg
        write(mpifileptr, *) "Denreg set by command line option to ", denreg
     endif
     if (buffer(1:3) .eq. 'GBS') then
        intopt=1
        write(mpifileptr, *) "GBS integration set by command line option."
     endif
     if (buffer(1:2) .eq. 'RK') then
        intopt=0
        write(mpifileptr, *) "RK integration set by command line option."
     endif
     if (buffer(1:8) .eq. 'Eground=') then
        read(buffer(9:len),*) eground
        write(mpifileptr, *) "Eground for autoft set to  ", eground, " by command line option."
     endif
     
  enddo
  write(mpifileptr, *) " ****************************************************************************"     
  write(mpifileptr,*);  call closefile()
  
!  if (lioreg.lt.1d-13) then    !! really needs to be 1d-11 or greater for stability, at least dfcon
!     lioreg=1d-13
!  endif

  if (constraintflag > 2) then
     OFLWR "Constraintflag not supported: ", constraintflag;     CFLST
  endif
  
  if (improvedrelaxflag.ne.0.and.constraintflag.eq.1) then
     OFLWR "FOR DEN CONSTRAINT, USE IMPROVEDNATFLAG FOR RELAX, NO CONSTRAINTFLAG."; CFLST
  endif
  if (improvedrelaxflag.ne.0.and.constraintflag.eq.2.and.improvedquadflag.ne.3.and.improvedquadflag.ne.1) then  
     OFLWR "FOR DF CONSTRAINT, DO NOT DIAGONALIZE FOR A-VECTOR - GET WRONG ANSWER"; CFLST
  endif
  
  if ((sparseconfigflag.ne.0).and.(stopthresh.lt.lanthresh).and.(improvedquadflag.eq.0.or.improvedquadflag.eq.2)) then
     OFLWR "Enforcing lanthresh.le.stopthresh"
     lanthresh=stopthresh
     write(mpifileptr,*) "    --> lanthresh now  ", lanthresh; CFL
  endif
  if (intopt.eq.4) then
     if ((constraintflag.ne.0)) then
        OFLWR "Verlet not available with pulse nor constraint yet."; CFLST
     endif
  endif
  if ((intopt.eq.3).or.(intopt.eq.4)) then  
     OFLWR "Enforcing CMF defaults for Verlet or EXPO."; CFL;     cmf_flag=1
  endif

  if (timefacforce.eq.0) then
     timefac=(0.0d0, -1.0d0)
  endif
  if (improvedrelaxflag.ne.0) then
     threshflag=1
  endif
  if (threshflag.ne.0) then
     if (timefacforce.eq.0) then
        timefac=(-1.0d0, 0.0d0)
     endif
  endif

  if (constraintflag==1) then
     if (real(timefac,8).ne.0.d0) then
        OFLWR "denmat Constraint flag only available for real time propagation. use improvednatflag."; CFLST
     endif
  endif

  if (numshells.lt.1) then
     OFLWR "Shell error ", numshells; CFLST
  endif

  allshelltop(0)=0;  allshelltop(numshells)=nspf
  allshelltop(1:numshells-1)=shelltop(1:numshells-1)
  do ishell=1,numshells
     if (allshelltop(ishell).gt.nspf) then
        allshelltop(ishell)=nspf
     endif
  enddo
  do ishell=numshells,2,-1
     if (allshelltop(ishell).le.allshelltop(ishell-1)) then
        numshells=numshells-1
        allshelltop(ishell:numshells)=allshelltop(ishell+1:numshells+1)
        numexcite(ishell:numshells)=numexcite(ishell+1:numshells+1)
     endif
  enddo
  liosize=nspf*(nspf-1)

  do i=1,numshells
     if (allshelltop(i).le.allshelltop(i-1)) then
        OFLWR "allShell error ", allshelltop(i), allshelltop(i-1); CFLST
     endif
  enddo

  do i=2,numshells
     if (numexcite(i).lt.numexcite(i-1)) then
        OFLWR "numexcite error ", numexcite(i), numexcite(i-1); CFLST
     endif
  enddo

  !! define shells

  ishell=1
  do ispf=1,nspf
     shells(ispf)=ishell
     if (ispf.eq.allshelltop(ishell)) then
        ishell=ishell+1
     endif
  enddo

!! 092010 PUT ACTIONS HERE...

  skipflag=0
  do j=1,numactions
     if (((actions(j).gt.7).and.(actions(j).lt.13)).or.(actions(j).eq.14).or.(actions(j).eq.18)) then
        skipflag=2
     endif
     if ((actions(j).eq.16).or.(actions(j).eq.17).or.(actions(j).eq.23)) then   !! KVL FLUX CALC
        skipflag=1
     endif
  enddo

  !! turn off all other actions if computing KVL flux
  i=0;  j=0

  do while (i.lt.numactions)
     i=i+1
     if (actions(i).eq.16) then
        j=j+1;        actions(j)=16
     endif
     if (actions(i).eq.17) then
        j=j+1;        actions(j)=17
     endif
     if (actions(i).eq.23) then
        j=j+1;        actions(j)=23
     endif
     if(j.ne.0) numactions=j
  enddo

  !! turn off writing routines if we are analyzing

  if (skipflag.ne.0) then
     i=0
     do while (i.lt.numactions)
        i=i+1
        if (((actions(i).lt.8).and.(actions(i).ge.1)).or.(actions(i).eq.13).or.(actions(i).eq.15)) then
           actions(i:numactions-1)=actions(i+1:numactions)
           numactions=numactions-1
           i=i-1
        endif
     enddo
  endif

  !! make sure no duplicates
  i=0
  do while (i.lt.numactions)
     i=i+1;     j=i
     do while ( j.lt. numactions)
        j=j+1
        if (actions(i)==actions(j)) then
           actions(j:numactions-1)=actions(j+1:numactions);           numactions=numactions-1
           j=j-1
        endif
     enddo
  enddo


  needpulse=0
  if (tdflag.eq.1) then
     needpulse=1
  else 
     if (noftflag.eq.0) then
        do j=1,numactions
           if ( (actions(j).eq.14).or.&
                (actions(j).eq.16).or.&
                (actions(j).eq.17)) then
              needpulse=1
           endif
        enddo
     endif
  endif

  if (needpulse.ne.0) then
     call getpulse(0)
  endif
  do i=1,nargs
     buffer=nullbuff
     !!     call mygetarg(i,buffer)
     call getarg(i,buffer)
     len=getlen(buffer)
     if (buffer(1:2) .eq. 'T=') then
        read(buffer(3:len),*) finaltime 
        OFLWR "Finaltime set by command line option to ", finaltime
        numpropsteps=floor((finaltime+0.0000000001d0)/par_timestep) +1
        finaltime=numpropsteps*par_timestep
        write(mpifileptr, *) "     numpropsteps now   ", numpropsteps
        write(mpifileptr, *) "     finaltime    now   ", finaltime;        call closefile()
     endif
  enddo

  numpropsteps=floor((finaltime+0.0000000001d0)/par_timestep)

!  call openfile()
!  if (numpropsteps*par_timestep - 0.000000001d0 .gt. finaltime) then
!     write(mpifileptr, *) "Resetting numpropsteps to agree with finaltime"
!     numpropsteps=floor((finaltime+0.0000000001d0)/par_timestep)
!  else if (numpropsteps*par_timestep + 0.000000001d0 .lt. finaltime) then
!     write(mpifileptr, *) "Resetting finaltime to agree with numpropsteps"
!     finaltime = numpropsteps*par_timestep
!  endif
!  call closefile()

  autosteps=floor(max(1.d0,autotimestep/par_timestep));  autosize=numpropsteps/autosteps+1
  fluxsteps=floor(max(1.d0,fluxtimestep/par_timestep));  fluxtimestep=par_timestep*fluxsteps

  do i=1,nargs
     buffer=nullbuff;     call getarg(i,buffer)
     len=getlen(buffer)
     if (buffer(1:12) .eq. 'PlotModulus=') then
        read(buffer(13:len),*) plotmodulus
        write(mpifileptr, *) "Plotmodulus set to ", plotmodulus, " steps by command line option."
     endif
  enddo

  ndof=2*numelec

  !! make it convenient - turn on nonuc_checkflag if numr=1
  !! THIS IS BAD.  makes default improved adiabatic hamiltonian.

  if (stopthresh.lt.1.d-12) then
     OFLWR "Error, stopthresh cannot be less than 1d-12"; CFLST  !! then would send hgram 1d-14
  endif

  if (constraintflag.eq.1.and.improvedrelaxflag.ne.0) then 
     OFLWR " Removing denmat constraint for relaxation. Not allowed."; CFL
     constraintflag=0
  endif
  if (spfrestrictflag.eq.0) then
     mrestrictflag=0
  endif
  if (ceground.eq.(0d0,0d0)) then
     ceground=eground
  endif


! no, turning this on in quadspfs.
!  if (improvedquadflag.gt.1.and.jacsymflag.eq.0) then
!     jacsymflag=1
!     OFLWR "enforcing jacsymflag=1 for improved quad orbitals"; CFL
!  endif


!! 121912
!! if numholes or numexcite is not set, define from avectorhole etc. input for backwards compatibility

  if (numholes.eq.0) then
     if (numholecombo.ne.1) then
        OFLWR "If setting numholecombo, set numholes."; CFLST
     endif
     do while (avectorhole(numholes+1).ne.-1001)
        numholes=numholes+1
     enddo
     if (numholes.ne.0) then
        OFLWR "You did not set numholes; I am setting it to ", numholes; CFL
     endif
  endif
  if (excitations.eq.0) then
     if (excitecombos.ne.1) then
        OFLWR "If setting excitecombos, set excitations."; CFLST
     endif
     do while (avectorexcitefrom(excitations+1).ne.-1001)
        print *, "blah ",excitations,avectorexcitefrom(excitations+1)
        excitations=excitations+1
     enddo
     if (excitations.ne.0) then
        OFLWR "You did not set excitations; I am setting it to ", excitations; CFL
     endif
  endif
  if (numholes.gt.0) then
     excitations=0
     allocate(myavectorhole(numholes,numholecombo,mcscfnum))
     myavectorhole=RESHAPE(avectorhole(1:numholecombo*numholes*mcscfnum),(/ numholes,numholecombo,mcscfnum/))
  else
     allocate(myavectorhole(1,1,1))
  endif
  if (excitations.gt.0) then
     numholes=0
     allocate(myavectorexcitefrom(excitations,excitecombos,mcscfnum))
     myavectorexcitefrom=RESHAPE(avectorexcitefrom(1:excitations*excitecombos*mcscfnum),(/excitations,excitecombos,mcscfnum/))
     allocate(myavectorexciteto(excitations,excitecombos,mcscfnum))
     myavectorexciteto=RESHAPE(avectorexciteto(1:excitations*excitecombos*mcscfnum),(/excitations,excitecombos,mcscfnum/))
  else
     allocate(myavectorexcitefrom(1,1,1), myavectorexciteto(1,1,1))
  endif


  if (sparseconfigflag.eq.0) then
     sparseopt=0
  endif

  if (numavectorfiles.gt.MXF.or.numspffiles.gt.MXF) then
     OFLWR "PROGRAMMER REDIM littleparmod",numavectorfiles,numspffiles,MXF; CFLST
  endif

  call openfile()
  write(mpifileptr, *)
  write(mpifileptr, *) " ****************************************************************************"     
  write(mpifileptr, *) "*****************************************************************************"
  write(mpifileptr, *) 
  write(mpifileptr, *) "Number of states in propagation=", mcscfnum
  write(mpifileptr, *)
  write(mpifileptr, *) " Parameters: electronic"
  write(mpifileptr, *)
  write(mpifileptr,'(A40,I5,2F10.5)') "Number of electrons ", numelec
  write(mpifileptr,'(A40,3I5)') "Nuclear KE flag (nonuc_checkflag):     ",  nonuc_checkflag
  write(mpifileptr, *)
  
  call printmyopts()
     
  write(mpifileptr, *)
  write(mpifileptr, *) "************************   Parameters: config/spf    ************************   "
  write(mpifileptr, *)
  
  if (numshells.eq.1) then
     write(mpifileptr, *) "Doing full CI: numshells=1.  Shells:"
  else
     write(mpifileptr, *) "Shells:"
  endif
  do ishell=1,numshells
     if (ishell.eq.numshells) then
        write(mpifileptr,*) "Shell ", ishell
     else
        write(mpifileptr,*) "Shell ", ishell,   "Excitation level: ", numexcite(ishell)
     endif
     write(mpifileptr,'(12A6)')  (orblabel(i),i=allshelltop(ishell-1)*2+1,allshelltop(ishell)*2)
  enddo
  if (vexcite.ge.numelec.and.numshells.gt.1) then
     write(mpifileptr,*) "No restriction on occupancy of final shell (CISDQT+++)"
  else
     write(mpifileptr,*)  " Final shell occupancy level vexcite=",vexcite
  endif
  if (df_restrictflag.gt.0) then
     write(mpifileptr,*) " DF restrictflag is on for constraintflag=2 or other purposes = ",df_restrictflag
  endif
  write(mpifileptr, *) 
  write(mpifileptr,'(A30,I5)')    "   Number of unfrozen spfs:  ", nspf
  write(mpifileptr,'(A30,I5)')    "   Number of frozen spfs:    ", numfrozen
  write(mpifileptr,'(A30,100I4)') "   Spfs start in m=  ", spfmvals(1:nspf)
  write(mpifileptr, *) 
  if (spfrestrictflag.eq.1) then
     write(mpifileptr, *) "Spfs will be restricted to their original m-values."
  endif
  if (spfugrestrict.eq.1) then
     write(mpifileptr, *) "Spfs will be restricted to their original parity values."
  endif
  if (mrestrictflag==1) then
     write(mpifileptr, *) "Configurations will be restricted to total M= ", mrestrictval
  endif
  if (ugrestrictflag==1) then
     write(mpifileptr, *) "Configurations will be restricted to total parity= ", ugrestrictval
  endif
  if (restrictflag.eq.1) then
     write(mpifileptr, *) "Configurations will be restricted to spin projection", restrictms, "/2"
  endif
  if (all_spinproject.ne.0) then
     write(mpifileptr,*) " Configurations will be restricted to spin ",spin_restrictval 
  endif
  write(mpifileptr, *) 
  write(mpifileptr, *) "***********************    Initial state      ***********************   "
  write(mpifileptr, *) 
  if (loadspfflag.eq.1) then
     write(mpifileptr, *) "Spfs will be loaded from files "
  else
     write(mpifileptr, *) "Spfs will be one-electron eigfuncts."
!     if (num_skip_orbs.gt.0) then
!        write(mpifileptr,*) "Skipping orbitals.  Orbital indices and m values:", (orb_skip(i),orb_skip_mvalue(i),i=1,num_skip_orbs)
!     endif
  endif
  write(mpifileptr, *) 
  if (threshflag.ne.0) then

     if (improvedquadflag.gt.1) then
        write(mpifileptr,*) "Spf Quad flag is ON (quadflag>1).  Start time ", quadstarttime
     else
        write(mpifileptr,*) "Sfp Quad flag is OFF."
     endif
     if (improvednatflag.ne.0) then
        write(mpifileptr,*) "Improvednatflag is ON."
     else
        write(mpifileptr,*) "Improvednatflag is OFF."
     endif
     write(mpifileptr, *) 
     if (improvedquadflag.eq.1.or.improvedquadflag.eq.3) then
        write(mpifileptr,*) "Avector Quad flag is ON (quadflag=1,3)."
     else
        write(mpifileptr,*) "Avector Quad flag is OFF."
     endif
  end if
  if (loadavectorflag.eq.1) then
     write(mpifileptr, *) "Avector will be loaded from files.  Number of files= ",numavectorfiles
     if (numholes.gt.0) then
        OFLWR; WRFL "We have holes:", numholes, " concurrent holes with ", numholecombo," wfns combined "; WRFL; CFL
        excitations=0
     endif
     if (excitations.gt.0) then
        OFLWR; WRFL "We have exitations: ",excitations, " concurrent excitations with ", excitecombos," wfns combined "; WRFL; CFL
     endif
  else
     write(mpifileptr, *) "Avector will be obtained from diagonalization."
  endif
  write(mpifileptr, *) 
  write(mpifileptr, *) "***********************    Parameters: propagation    ***********************   "
  write(mpifileptr, *)
!  write(mpifileptr, *) " CMFMODE : ", cmfmode
  write(mpifileptr,*)  " PAR_TIMESTEP IS ", par_timestep, " LITTLESTEPS IS ", littlesteps
  write(mpifileptr,*)
  if (messflag.ne.0) then
     write(mpifileptr,*) "MESSFLAG is on -- messing with spfs.  Messamount=", messamount; write(mpifileptr,*)
  endif
  if (spf_flag /= 1) then
     write(mpifileptr, *) "Spfs will be held CONSTANT. (except for constraint)";    write(mpifileptr,*)
  endif

  if (threshflag.eq.1) then
     write(mpifileptr, *) "Calculation will be stopped with threshold ", stopthresh, "; timestep is ", par_timestep
  else
     write(mpifileptr,'(A40,I10,2F24.8)') "# of steps, final time:",   numpropsteps,  finaltime
  endif

  write(mpifileptr,*);  write(mpifileptr,*)
  if (cmf_flag.ne.0) then
     write(mpifileptr, *) "*******  USING POLYNOMIAL MEAN FIELDS/MAGNUS A-VECTOR PREDICTOR/CORRECTOR   *******  "
     write(mpifileptr,*)
  else
     write(mpifileptr, *) "*************   Variable mean fields    *************   "
     write(mpifileptr,*)
  endif
  if (sparseconfigflag==1) then
     write(mpifileptr, *)  "    Will use sparse configuration routines."
     write(mpifileptr,*)   "          Lanczosorder is ", lanczosorder
     write(mpifileptr,*)   "          Lanthresh is    ", lanthresh
     write(mpifileptr,*)   "          Aorder is       ", aorder
     write(mpifileptr,*)   "          Maxaorder is    ", maxaorder
     write(mpifileptr,*)   "          Aerror is       ", aerror
  else
     write(mpifileptr,*)   "    Using nonsparse configuration routines."
  endif
  iiflag=0

  write(mpifileptr,*) " Jacobian options:"
  write(mpifileptr,*) "    Jacprojorth=", jacprojorth
  write(mpifileptr,*) "    Jacsymflag=", jacsymflag
  if (constraintflag.ne.0) then
     write(mpifileptr,*) "    Jacgmatthird=", jacgmatthird
  endif

  select case (intopt)
  case(4)
     write(mpifileptr,*) " Using VERLET integration, expo first step."
     write(mpifileptr,*) "     Verletnum= ", verletnum
     iiflag=1
  case(3)
     write(mpifileptr,*) " Using EXPONENTIAL integration."
     write(mpifileptr,*) "    Expotol    =", expotol
     write(mpifileptr,*) "    Maxexpodim=", maxexpodim
  case(0)
     write(mpifileptr, *) "RK integration.  Recommend errors 1.d-8"
     write(mpifileptr, *) "Myrelerr=", myrelerr;      iiflag=1
  case(1)
     write(mpifileptr, *) "GBS integration.  Recommend errors 1.d-8";     iiflag=1
  case(2)
     write(mpifileptr, *) "DLSODPK integration.  Recommend errors 1.d-10";  iiflag=1
  case default
     write(mpifileptr,*) "Intopt not recognized: ", intopt; CFLST
  end select
!  if (iiflag==1) then
!     write(mpifileptr,*) "Relative and (scaled to norm) absolute errors relerr, myrelerr: "
!     write(mpifileptr,*) "      Relerr=", relerr, 
!  endif
  write(mpifileptr,*) 
  write(mpifileptr, '(A40, E10.3)') " Density matrix regularized with denreg= ", denreg
  write(mpifileptr,*) 

  if (constraintflag.ne.0) then
     select case (constraintflag)
     case(1)
        write(mpifileptr, *) "Using constraintflag=1, density matrices with full lioville solve (assume full, constant off-block diagonal)."
     case(2)
        OFLWR "Using true Dirac-Frenkel equation for constraint."
        WRFL "     dfrestrictflag = ", df_restrictflag;      
        select case(conway)
        case(0)
           WRFL "McLachlan constraint"
        case(1)
           WRFL "50/50 SVD"
        case(2)
           WRFL "Lagrangian constraint"
        case(3)
           WRFL "Lagrangian with epsilon times McLachlan.  epsilon=conprop=",conprop
        case default
           WRFL "Conway not supported ", conway; CFLST
        end select
     case(0)
        write(mpifileptr, *) "Using zero constraint, constraintflag=0"
     case default
        write(mpifileptr,*) "Constraintflag error ", constraintflag;     call mpistop()
     end select
     if (lioreg.le.0.d0) then
        write(mpifileptr,*) "No regularization of lioville solve."
     else
        write(mpifileptr,*) "Lioville solve regularized with lioreg=", lioreg
     endif
  endif
  

  write(mpifileptr, *)
  write(mpifileptr, *) "****************************************************************************"
  write(mpifileptr, *)
  write(mpifileptr,*) "Autosteps is ", autosteps," Autosize is ", autosize, " Numpropsteps is ", numpropsteps
  write(mpifileptr,*) "Fluxsteps is ", fluxsteps," Fluxtimestep is ", fluxtimestep
  write(mpifileptr, *)
  write(mpifileptr, *) "*****************************************************************************"
  write(mpifileptr, *)
  if (skipflag.ne.0) then
     write(mpifileptr,*) "   ****************************************"
     write(mpifileptr,*) "     SKIPPING CALCULATION!  Doing analysis."
     write(mpifileptr,*) "   ****************************************"
  endif
  write(mpifileptr,*) ;  call closefile()
  call write_actions()
  
  lanagain = (-1)




end subroutine getparams

subroutine getpulse(no_error_exit_flag)   !! if flag is 0, will exit if &pulse is not read
  use parameters
  use mpimod
  implicit none

  NAMELIST /pulse/ omega,pulsestart,pulsestrength, velflag, omega2,phaseshift,intensity,pulsetype, &
       pulsetheta,pulsephi, longstep, numpulses, minpulsetime, maxpulsetime, chirp, ramp
  real*8 ::  time,   lastfinish, fac, pulse_end, estep
  DATATYPE :: pots1(3),pots2(3),pots3(3), pots4(3), pots5(3), csumx,csumy,csumz
  integer :: i, myiostat, ipulse,no_error_exit_flag
  character (len=12) :: line
  real*8, parameter :: epsilon=1d-4
  integer, parameter :: neflux=10000
  complex*16 :: lenpot(0:neflux,3),velpot(0:neflux,3)
  real*8 :: pulseftsq(0:neflux), vpulseftsq(0:neflux)

  open(971,file=inpfile, status="old", iostat=myiostat)
  if (myiostat/=0) then
     OFLWR "No Input.Inp found, not reading pulse. iostat=",myiostat; CFL
  else
     read(971,nml=pulse,iostat=myiostat)
     if (myiostat.ne.0.and.no_error_exit_flag.eq.0) then
        OFLWR "Need &pulse namelist input!!"; CFLST
     endif
  endif
  close(971)
  call openfile()
  if (tdflag.ne.0) then
     line="PULSE IS ON:"
  else
     line="READ PULSE: "
  endif
  select case (velflag)
  case (0)
     write(mpifileptr, *) line,"   length."
  case(1)
     write(mpifileptr, *) line,"   velocity, usual way."
  case(2)
     write(mpifileptr, *) line,"   velocity, DJH way."
  end select
  if (no_error_exit_flag.ne.0) then    !! mcscf.  just need velflag.
     return
  endif
  write(mpifileptr, *) ;  write(mpifileptr, *) "NUMBER OF PULSES:  ", numpulses;  write(mpifileptr, *) 

  lastfinish=0.d0
  do ipulse=1,numpulses
     if (pulsephi(ipulse).ne.0d0) then
        offaxispulseflag=1
     endif

     write(mpifileptr, *) "    -----> Pulse ", ipulse," : "

     if (pulsetype(ipulse).eq.1) then
        fac=omega(ipulse)
     else
        fac=omega2(ipulse)
     endif
     if (intensity(ipulse).ne.-1.d0) then !! overrides pulsestrength
        pulsestrength(ipulse) = sqrt(intensity(ipulse)/3.51)/fac
     else
        intensity(ipulse) = (fac*pulsestrength(ipulse))**2 * 3.51  !! just output
     endif
     select case (pulsetype(ipulse))
     case (1)
        write(mpifileptr,*) "Pulse type is 1: single sine squared envelope"
        write(mpifileptr, *) "Omega, pulsestart, pulsefinish, pulsestrength:"
        write(mpifileptr, '(8F18.12)') omega(ipulse), pulsestart(ipulse), pulsestart(ipulse) + pi/omega(ipulse), pulsestrength(ipulse)
     case (2,3)
        write(mpifileptr,*) "Pulse type is 2 or 3: envelope with carrier"
        write(mpifileptr, *) "   chirp:           ", chirp(ipulse)
        write(mpifileptr, *) "   ramp:           ", ramp(ipulse), " Hartree"
        write(mpifileptr, *) "   Envelope omega:  ", omega(ipulse)
        write(mpifileptr, *) "   Pulse omega:     ", omega2(ipulse)
        write(mpifileptr, *) "   Pulsestart:      ",pulsestart(ipulse)
        write(mpifileptr, *) "   Pulsestrength:   ",pulsestrength(ipulse)
        write(mpifileptr, *) "   Intensity:       ",intensity(ipulse), " x 10^16 W cm^-2"
        write(mpifileptr, *) "   Pulsetheta:      ",pulsetheta(ipulse)
        write(mpifileptr, *) "   Pulsephi:      ",pulsephi(ipulse)
        write(mpifileptr, *) "   Pulsefinish:     ",pulsestart(ipulse) + pi/omega(ipulse)
        if (pulsetype(ipulse).eq.3) then
           write(mpifileptr,*) "---> Pulsetype 3; longstep = ", longstep(ipulse)
        else if (pulsetype(ipulse).eq.2) then
           write(mpifileptr,*) "---> Pulsetype 2."
        endif
     case (4)
        WRFL "Pulse type is 4, cw"
        write(mpifileptr, *) "   Duration omega:  ", omega(ipulse)
        write(mpifileptr, *) "   Pulse omega:     ", omega2(ipulse)
        write(mpifileptr, *) "   Pulsestrength:   ",pulsestrength(ipulse)
        write(mpifileptr, *) "   Intensity:       ",intensity(ipulse), " x 10^16 W cm^-2"
        write(mpifileptr, *) "   Pulsetheta:      ",pulsetheta(ipulse)
        write(mpifileptr, *) "   Pulsephi:      ",pulsephi(ipulse)

     end select
     if (lastfinish.lt.pulsestart(ipulse)+pi/omega(ipulse)) then
        lastfinish=pulsestart(ipulse)+pi/omega(ipulse)
     endif
  end do
  
#ifdef REALGO
  write(mpifileptr,*) "Pulse not available with real prop.";  call closefile();  call mpistop
#endif

  if (tdflag.ne.0) then
     finaltime=lastfinish+par_timestep*4

!! I think this is right

     pulse_end = 2*pi/(pulseft_estep*(neflux+1)/neflux)

     if (pulse_end.lt.finaltime) then
        pulse_end=finaltime
     endif

     estep = 2*pi/(pulse_end*(neflux+1)/neflux)

     if (finaltime.lt.minpulsetime) then
        write(mpifileptr,*) " Enforcing minpulsetime =        ", minpulsetime
        finaltime=minpulsetime
     endif
     if (finaltime.gt.maxpulsetime) then
        write(mpifileptr,*) " Enforcing maxpulsetime =        ", maxpulsetime
        finaltime=maxpulsetime
     endif
     numpropsteps=floor((finaltime+0.0000000001d0)/par_timestep) +1
     finaltime=numpropsteps*par_timestep
     write(mpifileptr, *) "    ---> Resetting finaltime to ", finaltime
     write(mpifileptr, *) "                numpropsteps to ", numpropsteps
     write(mpifileptr, *) "   ... Writing pulse to file"
     CFL

     if (myrank.eq.1) then
        open(886, file="Dat/Pulse.Datx", status="unknown")
        open(887, file="Dat/Pulse.Daty", status="unknown")
        open(888, file="Dat/Pulse.Datz", status="unknown")

        csumx=0; csumy=0; csumz=0
        do i=0,neflux
           time=i*pulse_end/neflux

!! checking that E(t) = d/dt A(t)   and  A(t) = integral E(t)

           call vectdpot(time,                  0,pots1)
           call vectdpot(time,                  1,pots2)
           call vectdpot(time-epsilon,          1,pots3)
           call vectdpot(time+epsilon,          1,pots4)
           call vectdpot(time+pulse_end/neflux ,0,pots5)

           lenpot(i,:)=pots1(:)
           velpot(i,:)=pots2(:)

           write(886,'(100F15.10)') time, pots1(1), pots2(1), (pots4(1)-pots3(1))/2/epsilon, csumx
           write(887,'(100F15.10)') time, pots1(2), pots2(2), (pots4(2)-pots3(2))/2/epsilon, csumy
           write(888,'(100F15.10)') time, pots1(3), pots2(3), (pots4(3)-pots3(3))/2/epsilon, csumz

           csumx=csumx+ pulse_end/neflux * pots5(1)
           csumy=csumy+ pulse_end/neflux * pots5(2)
           csumz=csumz+ pulse_end/neflux * pots5(3)
        enddo
        close(886);    close(887); close(888)

        do i=1,3
           call zfftf_wrap(neflux+1,lenpot(:,i))
           call zfftf_wrap(neflux+1,velpot(:,i))
        enddo

        lenpot(:,:)=lenpot(:,:)*pulse_end/neflux

        velpot(:,:)=velpot(:,:)*pulse_end/neflux

        pulseftsq(:)=abs(lenpot(:,1)**2)+abs(lenpot(:,2)**2)+abs(lenpot(:,3)**2)

        vpulseftsq(:)=abs(velpot(:,1)**2)+abs(velpot(:,2)**2)+abs(velpot(:,3)**2)

        open(885, file="Dat/Pulseftsq.Dat", status="unknown")
        open(886, file="Dat/Pulseft.Datx", status="unknown")
        open(887, file="Dat/Pulseft.Daty", status="unknown")
        open(888, file="Dat/Pulseft.Datz", status="unknown")

!! PREVIOUS OUTPUT IN Pulseft.Dat was vpulseftsq / 4

        do i=0,neflux
           write(885,'(100F30.12)') i*estep, pulseftsq(i), vpulseftsq(i)
           write(886,'(100F30.12)') i*estep, lenpot(i,1),velpot(i,1)
           write(887,'(100F30.12)') i*estep, lenpot(i,2),velpot(i,2)
           write(888,'(100F30.12)') i*estep, lenpot(i,3),velpot(i,3)
        enddo

        close(885);   close(886);   close(887);   close(888)

     endif

     call mpibarrier()

     OFLWR "       ... done Writing pulse to file"; CFL

  endif


end subroutine getpulse
