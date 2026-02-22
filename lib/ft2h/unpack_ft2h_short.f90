subroutine unpack_ft2h_short(decoded_bits,message)

! Unpack FT2H short frame decoded bits into human-readable message
! Short frames carry 16-bit payloads for confirmation messages

  integer*1, intent(in) :: decoded_bits(32)
  character*37, intent(out) :: message
  integer*2 icode

  ! Extract 16-bit message code from first 16 bits
  icode=0
  do i=1,16
     icode=ior(ishft(icode,1),int(decoded_bits(i),2))
  enddo

  message='                                     '

  select case(icode)
  case(1)
     message='RR73                                 '
  case(2)
     message='73                                   '
  case(3)
     message='RRR                                  '
  case default
     ! Unknown short code
     write(message,'(a,i5)') '*** short code: ',icode
  end select

  return
end subroutine unpack_ft2h_short
