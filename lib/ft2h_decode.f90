module ft2h_decode

! FT2H decoder module — Hybrid variable-length digital mode
! Supports both standard (77-bit) and short (16-bit) frames
! Standard: LDPC(174,91) + 8-GFSK at 20.83 Bd
! Short:    LDPC(64,32)  + 8-GFSK at 20.83 Bd

   type :: ft2h_decoder
      procedure(ft2h_decode_callback), pointer :: callback
   contains
      procedure :: decode
   end type ft2h_decoder

   abstract interface
      subroutine ft2h_decode_callback(this,sync,snr,dt,freq,decoded,nap,qual)
         import ft2h_decoder
         implicit none
         class(ft2h_decoder), intent(inout) :: this
         real, intent(in) :: sync
         integer, intent(in) :: snr
         real, intent(in) :: dt
         real, intent(in) :: freq
         character(len=37), intent(in) :: decoded
         integer, intent(in) :: nap
         real, intent(in) :: qual
      end subroutine ft2h_decode_callback
   end interface

contains

   subroutine decode(this,callback,iwave,nQSOProgress,nfqso,    &
      nfa,nfb,ndepth,lapcqonly,ncontest,mycall,hiscall)
      use timer_module, only: timer
      use packjt77
      include 'ft2h/ft2h_params.f90'
      parameter (MAXCAND=100)
      class(ft2h_decoder), intent(inout) :: this
      procedure(ft2h_decode_callback) :: callback
      parameter (NSS=NSPS/NDOWN,NDMAX=NMAX/NDOWN)
      character message*37,msgsent*37
      character c77*77
      character*37 decodes(100)
      character*12 mycall,hiscall

      complex cd(0:NDMAX-1)                   !Complex baseband waveform
      complex ctwk(2*NSS)

      real a(5)
      real bitmetrics(2*NN,3)
      real dd(NMAX)
      real llr(174),llra(174),llrb(174)
      real llr_s(64)
      real candidate(3,MAXCAND)                !freq, dt, sync
      real savg(NH1),sbase(NH1)

      integer*2 iwave(NMAX)                   !Raw received data
      integer*1 message77(77),apmask(174),cw(174)
      integer*1 message91(91)
      integer*1 decoded_s(32)
      integer*1 hbits(2*NN)
      integer i4tone(NN2)

      logical unpk77_success
      logical, intent(in) :: lapcqonly
      logical newdat, first

      ! Scrambling vector (must match genft2h.f90)
      integer*1 rvec(77)
      data rvec/0,1,0,0,1,0,1,0,0,1,0,1,1,1,1,0,1,0,0,0,1,0,0,1,1,0,1,1,0, &
                1,0,0,1,0,1,1,0,0,0,0,1,0,0,0,1,0,1,0,0,1,1,1,1,0,0,1,0,1, &
                0,1,0,1,0,1,1,0,1,1,1,1,1,0,0,0,1,0,1/

      data first/.true./
      save first

      ndecodes=0

      ! Convert integer*2 samples to real
      dd=0.0
      do i=1,NMAX
         dd(i)=iwave(i)
      enddo

      ! ==========================================
      ! 1. Try STANDARD frame decoding first
      ! ==========================================

      ! Compute symbol spectra and find candidates
      call ft2h_getcandidates(dd,0,candidate,ncand,MAXCAND)

      ! Try to decode each candidate
      do icand=1,ncand
         f0=candidate(1,icand)
         dt0=candidate(2,icand)
         sync0=candidate(3,icand)

         if(sync0.lt.1.0) cycle        !Skip weak sync

         ! Downsample to baseband
         call ft2h_downsample(dd,0,.true.,f0,cd)

         ! Extract soft symbols and compute LLR
         call ft2h_get_bitmetrics(cd,0,dt0,llr)

         ! Attempt LDPC decode
         Keff=91
         maxosd=2
         norder=2
         apmask=0
         call decode174_91(llr,Keff,maxosd,norder,apmask,message91,cw, &
              ntype,nharderrors,dmin)

         if(nharderrors.ge.0) then
            ! Successful decode
            message77=message91(1:77)
            ! Undo scrambling (same rvec as in genft2h)
            message77=mod(message77+rvec,2)
            write(c77,'(77i1)') message77
            call unpack77(c77,0,message,unpk77_success)
            if(unpk77_success) then
               ! Check for duplicate
               do id=1,ndecodes
                  if(decodes(id).eq.message) go to 100
               enddo
               ndecodes=ndecodes+1
               decodes(ndecodes)=message

               ! Estimate SNR
               snr_est = 10.0*log10(sync0) - 14.8
               nsnr = nint(max(-30.0,min(30.0,snr_est)))

               ! Report decode
               qual=1.0
               nap=0
               call callback(this,sync0,nsnr,dt0,f0,message,nap,qual)
            endif
100         continue
         endif
      enddo

      ! ==========================================
      ! 2. Try SHORT frame decoding
      ! ==========================================

      ! Compute candidates for short frame
      call ft2h_getcandidates(dd,1,candidate,ncand_s,MAXCAND)

      do icand=1,ncand_s
         f0=candidate(1,icand)
         dt0=candidate(2,icand)
         sync0=candidate(3,icand)

         if(sync0.lt.1.2) cycle        !Higher threshold for short frames

         ! Downsample
         call ft2h_downsample(dd,1,.true.,f0,cd)

         ! Extract soft symbols for short frame
         call ft2h_get_bitmetrics_short(cd,dt0,llr_s)

         ! Attempt short LDPC decode
         call decode_64_32(llr_s,30,decoded_s,nharderrors_s)

         if(nharderrors_s.ge.0) then
            ! Successful short decode — reconstruct message
            call unpack_ft2h_short(decoded_s,message)

            ! Check for duplicate
            do id=1,ndecodes
               if(decodes(id).eq.message) go to 200
            enddo
            ndecodes=ndecodes+1
            decodes(ndecodes)=message

            snr_est = 10.0*log10(sync0) - 8.0
            nsnr = nint(max(-30.0,min(30.0,snr_est)))

            qual=1.0
            nap=0
            call callback(this,sync0,nsnr,dt0,f0,message,nap,qual)
200         continue
         endif
      enddo

      return
   end subroutine decode

end module ft2h_decode
