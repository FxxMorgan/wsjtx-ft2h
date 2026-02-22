subroutine ft2h_get_bitmetrics(cd,isshort,dt0,llr)

! Extract soft bit metrics from downsampled complex baseband signal
! for FT2H standard frame (8-GFSK, 174 coded bits → 58 data symbols)

  include 'ft2h_params.f90'
  parameter (NSS=NSPS/NDOWN)           !32 samples per symbol
  parameter (NDMAX=NMAX/NDOWN)

  complex cd(0:NDMAX-1)
  real, intent(in) :: dt0
  integer, intent(in) :: isshort
  real, intent(out) :: llr(174)

  complex cs(0:7,58)                   !8-tone spectra for 58 data symbols
  real s2(0:7)
  real bmet(174)

  ! Gray demapping table (inverse of graymap8)
  ! graymap8: 0→0, 1→1, 2→3, 3→2, 4→7, 5→6, 6→4, 7→5
  ! Bit patterns: 000,001,010,011,100,101,110,111  
  integer igray(0:7,0:2)              !igray(tone, bit_position) = bit_value
  data igray/ &
       0,0,0,0,1,1,1,1, &            !Bit 0 (MSB)
       0,0,1,1,1,1,0,0, &            !Bit 1
       0,1,1,0,0,1,1,0/              !Bit 2 (LSB)

  baud=12000.0/real(NSPS)
  dt_sym=real(NSS)

  ! Compute 8-point DFT for each data symbol to extract tone powers
  i0_sample = nint(dt0 * 12000.0 / NDOWN)

  ! Standard frame data symbol positions (after Costas sync arrays):
  ! Symbols 9-37 (data block 1) and 46-74 (data block 2), 0-indexed

  do isym=1,58
     if(isym.le.29) then
        jsym = 8 + isym              !Data block 1 (offsets 9-37)
     else
        jsym = 16 + isym             !Data block 2 (offsets 46-74)
     endif

     k0 = i0_sample + jsym*NSS

     ! 8-point DFT at tone frequencies
     do itone=0,7
        cs(itone,isym)=cmplx(0.0,0.0)
        do i=0,NSS-1
           k=k0+i
           if(k.ge.0 .and. k.lt.NDMAX) then
              phase=8.0*atan(1.0)*itone*i/real(NSS)
              cs(itone,isym)=cs(itone,isym) + cd(k)*cmplx(cos(phase),-sin(phase))
           endif
        enddo
     enddo
  enddo

  ! Compute soft bit metrics using max-log approximation
  do isym=1,58
     do itone=0,7
        s2(itone)=abs(cs(itone,isym))**2
     enddo

     i0bit=(isym-1)*3
     do ibit=0,2
        ! LLR = max(s2 where bit=0) - max(s2 where bit=1)
        smax0=-1e30
        smax1=-1e30
        do itone=0,7
           if(igray(itone,ibit).eq.0) then
              if(s2(itone).gt.smax0) smax0=s2(itone)
           else
              if(s2(itone).gt.smax1) smax1=s2(itone)
           endif
        enddo
        bmet(i0bit+ibit+1) = smax0 - smax1  !Positive = bit is 0
     enddo
  enddo

  ! Normalize bit metrics
  call normalizebmet(bmet,174)

  ! Scale to approximate LLR
  scalefac=2.83
  llr = scalefac * bmet

  return
end subroutine ft2h_get_bitmetrics

! ==========================================
! Short frame bit metrics extraction
! ==========================================
subroutine ft2h_get_bitmetrics_short(cd,dt0,llr_s)

  include 'ft2h_params.f90'
  parameter (NSS=NSPS/NDOWN)
  parameter (NDMAX_S=NMAX_S/NDOWN)

  complex cd(0:NDMAX_S-1)
  real, intent(in) :: dt0
  real, intent(out) :: llr_s(64)

  complex cs(0:7)
  real s2(0:7)
  real bmet(64)

  integer igray(0:7,0:2)
  data igray/ &
       0,0,0,0,1,1,1,1, &
       0,0,1,1,1,1,0,0, &
       0,1,1,0,0,1,1,0/

  i0_sample = nint(dt0 * 12000.0 / NDOWN)

  ! Short frame: data symbols at positions 9-30 (0-indexed), 22 symbols
  do isym=1,22
     jsym = 8 + isym                   !After sync array (offsets 9-30)
     k0 = i0_sample + jsym*NSS

     do itone=0,7
        cs(itone)=cmplx(0.0,0.0)
        do i=0,NSS-1
           k=k0+i
           if(k.ge.0 .and. k.lt.NDMAX_S) then
              phase=8.0*atan(1.0)*itone*i/real(NSS)
              cs(itone)=cs(itone) + cd(k)*cmplx(cos(phase),-sin(phase))
           endif
        enddo
     enddo

     do itone=0,7
        s2(itone)=abs(cs(itone))**2
     enddo

     ! Map to bits (3 bits per symbol, except last symbol)
     nbits_this = 3
     if(isym.eq.22) nbits_this = 1    !Last symbol: only 1 bit (bit 64)

     i0bit = (isym-1)*3
     do ibit=0,nbits_this-1
        smax0=-1e30
        smax1=-1e30
        do itone=0,7
           if(igray(itone,ibit).eq.0) then
              if(s2(itone).gt.smax0) smax0=s2(itone)
           else
              if(s2(itone).gt.smax1) smax1=s2(itone)
           endif
        enddo
        if(i0bit+ibit+1.le.64) then
           bmet(i0bit+ibit+1) = smax0 - smax1
        endif
     enddo
  enddo

  call normalizebmet(bmet,64)
  scalefac=2.83
  llr_s = scalefac * bmet

  return
end subroutine ft2h_get_bitmetrics_short
