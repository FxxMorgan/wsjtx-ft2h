subroutine ft2h_downsample(dd,isshort,newdat,f0,cd)

! Downsample FT2H signal by factor NDOWN=18
! Input: dd(NMAX) or dd(NMAX_S) at 12000 S/s
! Output: cd(0:NDMAX-1) complex baseband at 12000/18 = 666.67 S/s

  include 'ft2h_params.f90'
  parameter (NDMAX=NMAX/NDOWN)         !Standard frame downsampled length
  parameter (NDMAX_S=NMAX_S/NDOWN)     !Short frame downsampled length

  real dd(NMAX)
  complex cd(0:NDMAX-1)
  complex cx(0:NMAX/2)
  complex c1(0:NDMAX-1)
  real x(NMAX)
  equivalence (x,cx)
  integer, intent(in) :: isshort
  logical, intent(in) :: newdat
  real, intent(in) :: f0

  logical first
  data first/.true./
  save first

  baud=12000.0/real(NSPS)              !20.833 Bd
  df=12000.0/NMAX

  ! Copy input and perform forward real-to-complex FFT
  ! Using equivalence, x and cx share the same storage
  x(1:NMAX) = dd(1:NMAX)
  call four2a(cx,NMAX,1,-1,0)         !r2c FFT to freq domain

  if(isshort.eq.0) then
     ndout = NDMAX
  else
     ndout = NDMAX_S
  endif

  ! Shift to baseband and downsample via spectral method
  i0 = nint(f0/df)
  c1 = cmplx(0.0,0.0)

  if(i0.ge.0 .and. i0.le.NMAX/2) c1(0)=cx(i0)
  do i=1,ndout/2
     if(i0+i.ge.0 .and. i0+i.le.NMAX/2) c1(i)=cx(i0+i)
     if(i0-i.ge.0 .and. i0-i.le.NMAX/2) c1(ndout-i)=cx(i0-i)
  enddo

  ! Normalize and inverse FFT
  c1 = c1 / real(ndout)
  call four2a(c1,ndout,1,1,1)          !c2c FFT back to time domain
  cd(0:ndout-1) = c1(0:ndout-1)

  return
end subroutine ft2h_downsample
