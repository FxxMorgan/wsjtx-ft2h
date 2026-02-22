subroutine genft2h(msg0,ichk,msgsent,msgbits,i4tone,isshort)

! Encode an FT2H message (Hybrid mode)
! Input:
!   - msg0      requested message to be transmitted
!   - ichk      if ichk=1, return only msgsent
!   - isshort   0=standard frame (77-bit), 1=short frame (16-bit confirmations)
! Output:
!   - msgsent   message as it will be decoded
!   - msgbits   77 message bits (standard) or 16 message bits (short)
!   - i4tone    array of audio tone values, {0..7}

! Standard frame structure (76 symbols total):
!   r1 + s8 + d29 + s8 + d29 + r1
!   where s8 = Costas 8-tone sync array, d29 = 29 data symbols, r1 = ramp

! Short frame structure (32 symbols total):
!   r1 + s8 + d22 + r1
!   where s8 = Costas 8-tone sync, d22 = 22 data symbols

! Standard: TX duration = 76 * 576/12000 = 3.648 s within 4.0 s cycle
! Short:    TX duration = 32 * 576/12000 = 1.536 s within 1.5 s cycle

  use packjt77
  include 'ft2h_params.f90'
  character*37 msg0
  character*37 message
  character*37 msgsent
  character*77 c77
  integer*4 i4tone(NN2)               !Max size (standard frame)
  integer*4 itmp_std(ND)              !58 data symbols for standard
  integer*4 itmp_short(ND_S)          !22 data symbols for short
  integer*1 codeword(174)             !Standard LDPC codeword
  integer*1 codeword_s(64)            !Short LDPC codeword
  integer*1 msgbits(77)
  integer*1 msgbits_short(16)
  integer*1 rvec(77)
  integer, intent(in) :: isshort
  logical unpk77_success

  ! Costas 8-symbol sync arrays for standard frame (two arrays, different patterns)
  integer icos8a(8),icos8b(8)
  data icos8a/2,5,6,0,4,1,3,7/       !First 8-tone Costas array
  data icos8b/4,7,2,3,0,6,1,5/       !Second 8-tone Costas array

  ! Costas 8-symbol sync array for short frame (one array)
  integer icos8s(8)
  data icos8s/1,3,7,2,5,0,6,4/       !Short frame sync array

  ! Scrambling vector (same as FT4 for compatibility)
  data rvec/0,1,0,0,1,0,1,0,0,1,0,1,1,1,1,0,1,0,0,0,1,0,0,1,1,0,1,1,0, &
            1,0,0,1,0,1,1,0,0,0,0,1,0,0,0,1,0,1,0,0,1,1,1,1,0,0,1,0,1, &
            0,1,0,1,0,1,1,0,1,1,1,1,1,0,0,0,1,0,1/

  ! Gray mapping for 8-GFSK (3 bits → tone 0..7)
  integer graymap8(0:7)
  data graymap8/0,1,3,2,7,6,4,5/     !Standard Gray code for 8 levels

  message=msg0

  do i=1, 37
     if(ichar(message(i:i)).eq.0) then
        message(i:37)=' '
        exit
     endif
  enddo
  do i=1,37
     if(message(1:1).ne.' ') exit
     message=message(i+1:)
  enddo

  if(isshort.eq.0) then
! ==========================================
! STANDARD FRAME (77-bit message, LDPC 174,91)
! ==========================================
     i3=-1
     n3=-1
     call pack77(message,i3,n3,c77)
     call unpack77(c77,0,msgsent,unpk77_success)

     if(ichk.eq.1) go to 999
     read(c77,'(77i1)',err=1) msgbits
     if(unpk77_success) go to 2
1    msgbits=0
     i4tone=0
     msgsent='*** bad message ***                  '
     go to 999

2    msgbits=mod(msgbits+rvec,2)       !Apply scrambling
     call encode174_91(msgbits,codeword)

     ! Map coded bits to 8-GFSK symbols using Gray mapping
     ! 3 bits per symbol: 174 bits → 58 symbols
     do i=1,ND
        is=codeword(3*i-2)*4 + codeword(3*i-1)*2 + codeword(3*i)
        itmp_std(i)=graymap8(is)
     enddo

     ! Assemble standard frame: r1 + s8 + d29 + s8 + d29 + r1
     i4tone(1)=0                       !Ramp up
     i4tone(2:9)=icos8a                !First Costas sync (8 symbols)
     i4tone(10:38)=itmp_std(1:29)      !First data block (29 symbols)
     i4tone(39:46)=icos8b              !Second Costas sync (8 symbols)
     i4tone(47:75)=itmp_std(30:58)     !Second data block (29 symbols)
     i4tone(76)=0                      !Ramp down

  else
! ==========================================
! SHORT FRAME (16-bit message, LDPC 64,32)
! ==========================================
     ! For short messages: encode 16-bit payload
     ! The short message carries confirmation codes:
     !   RR73 = 0x0001, 73 = 0x0002, RRR = 0x0003, etc.
     call pack_ft2h_short(message,msgbits_short,msgsent)

     if(ichk.eq.1) go to 999

     call encode_64_32(msgbits_short,codeword_s)

     ! Map coded bits to 8-GFSK symbols using Gray mapping
     ! 64 bits → ceil(64/3) = 22 symbols (last symbol uses 1 bit, padded)
     do i=1,21
        is=codeword_s(3*i-2)*4 + codeword_s(3*i-1)*2 + codeword_s(3*i)
        itmp_short(i)=graymap8(is)
     enddo
     ! Last symbol: only 1 remaining bit (bit 64), pad with zeros
     is=codeword_s(64)*4
     itmp_short(22)=graymap8(is)

     ! Assemble short frame: r1 + s8 + d22 + r1
     i4tone(1)=0                       !Ramp up
     i4tone(2:9)=icos8s               !Costas sync (8 symbols)
     i4tone(10:31)=itmp_short(1:22)   !Data symbols
     i4tone(32)=0                      !Ramp down

  endif

999 return
end subroutine genft2h

! ==========================================
! Helper: pack short confirmation messages
! ==========================================
subroutine pack_ft2h_short(msg0,msgbits,msgsent)
  character*37 msg0, msgsent
  integer*1 msgbits(16)
  character*37 message
  integer icode

  message=msg0
  ! Trim and uppercase
  do i=1,37
     if(ichar(message(i:i)).ge.97 .and. ichar(message(i:i)).le.122) then
        message(i:i)=char(ichar(message(i:i))-32)
     endif
  enddo

  icode=0
  if(index(message,'RR73').gt.0) then
     icode=1
     msgsent='RR73                                 '
  else if(index(message,' 73').gt.0 .or. message(1:2).eq.'73') then
     icode=2
     msgsent='73                                   '
  else if(index(message,'RRR').gt.0) then
     icode=3
     msgsent='RRR                                  '
  else
     ! Generic short message: encode first 16 bits as binary
     icode=0
     msgsent='*** short msg ***                    '
  endif

  ! Pack icode into 16 bits (little-endian)
  do i=1,16
     msgbits(i)=iand(ishft(icode,-(16-i)),1)
  enddo

  return
end subroutine pack_ft2h_short
