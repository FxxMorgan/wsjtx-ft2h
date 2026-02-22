subroutine sync_ft2h(cd0,i0,ctwk,itwk,sync,isshort)

! Compute sync power for FT2H signal
! For standard frame: correlate with two 8-symbol Costas arrays
! For short frame: correlate with one 8-symbol Costas array

  include 'ft2h_params.f90'
  parameter (NSS=NSPS/NDOWN)           !32 samples per symbol after downsample
  complex cd0(0:*)
  complex ctwk(2*NSS)                  !Tweak function for fine freq
  integer itwk                         !0=no tweak, 1=apply tweak
  integer, intent(in) :: isshort
  real sync

  ! Costas arrays (must match genft2h.f90)
  integer icos8a(8),icos8b(8),icos8s(8)
  data icos8a/2,5,6,0,4,1,3,7/
  data icos8b/4,7,2,3,0,6,1,5/
  data icos8s/1,3,7,2,5,0,6,4/

  complex csync_a, csync_b, csync_s
  real p_sync, p_data

  if(isshort.eq.0) then
! ==========================================
! Standard frame sync
! ==========================================
     ! Two sync arrays at positions 1 and 38 (1-indexed after ramp)
     ! Frame: r1 + s8(pos 2-9) + d29(pos 10-38) + s8(pos 39-46) + d29(pos 47-75) + r1
     ! After ramp removal, sync at symbol offsets 1 and 38

     p_sync=0.0
     do i=1,8
        ! First Costas array (position 1..8 after ramp)
        k1=i0 + i*NSS
        if(itwk.eq.1) then
           p_sync=p_sync + abs(sum(cd0(k1:k1+NSS-1)*conjg(ctwk(1:NSS))))**2
        else
           p_sync=p_sync + abs(sum(cd0(k1:k1+NSS-1)))**2
        endif
     enddo
     do i=1,8
        ! Second Costas array (position 38..45 after ramp)
        k2=i0 + (37+i)*NSS
        if(itwk.eq.1) then
           p_sync=p_sync + abs(sum(cd0(k2:k2+NSS-1)*conjg(ctwk(1:NSS))))**2
        else
           p_sync=p_sync + abs(sum(cd0(k2:k2+NSS-1)))**2
        endif
     enddo

     ! Data power for normalization
     p_data=0.0
     do i=1,29
        k=i0 + (8+i)*NSS       !First data block (offsets 9-37)
        p_data=p_data + abs(sum(cd0(k:k+NSS-1)))**2
     enddo
     do i=1,29
        k=i0 + (45+i)*NSS      !Second data block (offsets 46-74)
        p_data=p_data + abs(sum(cd0(k:k+NSS-1)))**2
     enddo

     if(p_data.gt.0.0) then
        sync = p_sync / (p_data/58.0 * 16.0)
     else
        sync = 0.0
     endif

  else
! ==========================================
! Short frame sync
! ==========================================
     ! One sync array at position 1 (after ramp)
     ! Frame: r1 + s8(pos 2-9) + d22(pos 10-31) + r1

     p_sync=0.0
     do i=1,8
        k1=i0 + i*NSS
        if(itwk.eq.1) then
           p_sync=p_sync + abs(sum(cd0(k1:k1+NSS-1)*conjg(ctwk(1:NSS))))**2
        else
           p_sync=p_sync + abs(sum(cd0(k1:k1+NSS-1)))**2
        endif
     enddo

     p_data=0.0
     do i=1,22
        k=i0 + (8+i)*NSS       !Data block (offsets 9-30)
        p_data=p_data + abs(sum(cd0(k:k+NSS-1)))**2
     enddo

     if(p_data.gt.0.0) then
        sync = p_sync / (p_data/22.0 * 8.0)
     else
        sync = 0.0
     endif

  endif

  return
end subroutine sync_ft2h
