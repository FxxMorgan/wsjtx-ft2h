subroutine subtractft2h(dd,itone,f0,dt,isshort)

! Subtract a decoded FT2H signal from the raw data
! to enable multi-pass decoding of weaker signals underneath

  include 'ft2h_params.f90'
  real dd(NMAX)
  integer itone(*)
  real, intent(in) :: f0, dt
  integer, intent(in) :: isshort

  real wave(NZ2+100)
  complex cref(NZ2+100)
  real twopi

  twopi=8.0*atan(1.0)

  if(isshort.eq.0) then
     nsym=NN                            !74 channel symbols (gen adds +2 for ramp)
     nwave=NZ2                          !Total waveform samples including ramp
  else
     nsym=NN_S                          !30 channel symbols (gen adds +2 for ramp)
     nwave=NZ2_S                        !Total waveform samples including ramp
  endif
  icmplx=0
  call gen_ft2h_wave(itone,nsym,NSPS,12000.0,f0,cref,wave,icmplx,nwave)

  ! Determine sample offset
  i0=nint(dt*12000.0)

  ! Subtract reference from data
  do i=1,nwave
     j=i+i0
     if(j.ge.1 .and. j.le.NMAX) then
        dd(j)=dd(j)-wave(i)
     endif
  enddo

  return
end subroutine subtractft2h
