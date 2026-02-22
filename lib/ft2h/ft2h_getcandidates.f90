subroutine ft2h_getcandidates(dd,isshort,candidate,ncand,maxcand)

! Find candidate signals for FT2H decoding
! Computes spectrogram and correlates with Costas sync pattern

  include 'ft2h_params.f90'
  real dd(NMAX)
  real candidate(3,maxcand)            !freq, dt, sync power
  integer, intent(in) :: isshort
  integer, intent(out) :: ncand
  integer, intent(in) :: maxcand

  real s(NH1,NHSYM)                    !Spectrogram
  real savg(NH1)
  complex cx(0:NFFT1/2)
  real x(NFFT1)

  ! Costas arrays (must match genft2h.f90)
  integer icos8a(8),icos8b(8),icos8s(8)
  data icos8a/2,5,6,0,4,1,3,7/
  data icos8b/4,7,2,3,0,6,1,5/
  data icos8s/1,3,7,2,5,0,6,4/

  ncand=0
  df=12000.0/NFFT1                     !Frequency resolution

  ! Compute spectrogram
  savg=0.0
  nhsym_actual=0
  do j=1,NHSYM
     ia=(j-1)*NSTEP + 1
     ib=ia+NFFT1-1
     if(ib.gt.NMAX) exit
     nhsym_actual=j
     x=0.0
     x(1:NFFT1)=dd(ia:ib)
     call four2a(x,NFFT1,1,-1,0)      !FFT
     do i=1,NH1
        s(i,j) = x(2*i-1)**2 + x(2*i)**2
     enddo
     savg = savg + s(:,j)
  enddo

  if(nhsym_actual.lt.10) return
  savg = savg / nhsym_actual

  ! Search for sync pattern
  baud=12000.0/real(NSPS)
  nsteps_per_sym = NSPS/NSTEP          !4 steps per symbol
  tol_freq = 167.0                     !Search bandwidth (Hz)
  itol = nint(tol_freq/df)

  if(isshort.eq.0) then
     ! Standard frame: search for two 8-symbol Costas arrays
     ! Positions: s8 at symbol 2-9 and 39-46 (1-indexed)
     ! In spectrogram steps: (sym-1)*4 + lag

     do ilag=1,nhsym_actual-NN2*nsteps_per_sym
        do ifreq=1,NH1-8*nint(baud/df)
           sync_power=0.0

           ! First Costas array (symbols 2-9)
           do k=1,8
              jsym = ilag + (k)*nsteps_per_sym
              if(jsym.lt.1 .or. jsym.gt.nhsym_actual) cycle
              jf = ifreq + nint(icos8a(k)*baud/df)
              if(jf.ge.1 .and. jf.le.NH1) then
                 sync_power = sync_power + s(jf,jsym)
              endif
           enddo

           ! Second Costas array (symbols 39-46)
           do k=1,8
              jsym = ilag + (37+k)*nsteps_per_sym
              if(jsym.lt.1 .or. jsym.gt.nhsym_actual) cycle
              jf = ifreq + nint(icos8b(k)*baud/df)
              if(jf.ge.1 .and. jf.le.NH1) then
                 sync_power = sync_power + s(jf,jsym)
              endif
           enddo

           ! Normalize by average power
           avg_power = savg(ifreq)
           if(avg_power.gt.0.0) then
              snorm = sync_power / (16.0 * avg_power)
           else
              snorm = 0.0
           endif

           if(snorm.gt.1.2 .and. ncand.lt.maxcand) then
              ncand=ncand+1
              candidate(1,ncand) = (ifreq-1)*df  !Frequency
              candidate(2,ncand) = (ilag-1)*NSTEP/12000.0  !Time offset
              candidate(3,ncand) = snorm           !Sync power
           endif
        enddo
     enddo

  else
     ! Short frame: search for one 8-symbol Costas array
     do ilag=1,nhsym_actual-NN2_S*nsteps_per_sym
        do ifreq=1,NH1-8*nint(baud/df)
           sync_power=0.0

           do k=1,8
              jsym = ilag + k*nsteps_per_sym
              if(jsym.lt.1 .or. jsym.gt.nhsym_actual) cycle
              jf = ifreq + nint(icos8s(k)*baud/df)
              if(jf.ge.1 .and. jf.le.NH1) then
                 sync_power = sync_power + s(jf,jsym)
              endif
           enddo

           avg_power = savg(ifreq)
           if(avg_power.gt.0.0) then
              snorm = sync_power / (8.0 * avg_power)
           else
              snorm = 0.0
           endif

           if(snorm.gt.1.5 .and. ncand.lt.maxcand) then
              ncand=ncand+1
              candidate(1,ncand) = (ifreq-1)*df
              candidate(2,ncand) = (ilag-1)*NSTEP/12000.0
              candidate(3,ncand) = snorm
           endif
        enddo
     enddo
  endif

  return
end subroutine ft2h_getcandidates
