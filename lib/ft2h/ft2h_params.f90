! FT2H mode parameters — Hybrid variable-length digital mode
! Based on 8-GFSK modulation at 20.83 baud (same baud rate as FT4)
! Two frame types:
!   Standard (77-bit payload): LDPC(174,91), 8-GFSK, ~3.55 s TX, 4.0 s T/R
!   Short (16-bit payload):    LDPC(64,32),  8-GFSK, ~1.06 s TX, 1.5 s T/R

! ==========================================
! Standard frame parameters (77-bit message)
! ==========================================
! LDPC (174,91) code — same as FT8/FT4
  parameter (KK=91)                     !Information bits (77 + CRC14)
  parameter (ND=58)                     !Data symbols (174 coded bits / 3 bits per symbol)
  parameter (NS=16)                     !Sync symbols (2 × Costas 8-symbol arrays)
  parameter (NN=NS+ND)                  !Total channel symbols (74) sync+data
  parameter (NN2=NN+2)                  !Total with ramp up/down (76)
  parameter (NSPS=576)                  !Samples per symbol at 12000 S/s (20.83 Bd)
  parameter (NZ=NSPS*NN)               !Samples in sync+data waveform (42624)
  parameter (NZ2=NSPS*NN2)             !Samples in full waveform (43776)
  parameter (NMAX=48000)               !Samples in iwave (4.0 s × 12000)
  parameter (NFFT1=2*NSPS, NH1=NFFT1/2)!Length of FFTs for symbol spectra
  parameter (NSTEP=NSPS/4)             !Rough time-sync step size (144)
  parameter (NHSYM=NMAX/NSTEP-3)       !Number of symbol spectra
  parameter (NDOWN=18)                 !Downsample factor (same as FT4)

! ==========================================
! Short frame parameters (16-bit message)
! ==========================================
! LDPC (64,32) code for confirmations (RR73, 73, RRR)
  parameter (KK_S=32)                  !Information bits (16 payload + 16 CRC)
  parameter (ND_S=22)                  !Data symbols (ceil(64/3) = 22, last symbol partial)
  parameter (NS_S=8)                   !Sync symbols (1 × Costas 8-symbol array)
  parameter (NN_S=NS_S+ND_S)          !Total channel symbols (30) sync+data
  parameter (NN2_S=NN_S+2)            !Total with ramp up/down (32)
  parameter (NZ_S=NSPS*NN_S)          !Samples in sync+data (17280)
  parameter (NZ2_S=NSPS*NN2_S)        !Samples in full short waveform (18432)
  parameter (NMAX_S=19200)             !Samples in iwave (1.6 s × 12000)

! ==========================================
! Common parameters
! ==========================================
! Baud rate: 12000/576 = 20.833... Bd
! Tone spacing: 20.833 Hz (= baud rate for h=1 FSK)
! Bandwidth: 8 × 20.833 = ~167 Hz
! Standard TX duration: 76 × 576 / 12000 = 3.648 s (within 4.0 s cycle)
! Short TX duration: 32 × 576 / 12000 = 1.536 s (within 1.5 s cycle)
! Sensitivity (standard): ~-15.8 dB SNR in 2500 Hz BW
! Sensitivity (short): ~-9 dB SNR in 2500 Hz BW (weaker code, shorter TX)
