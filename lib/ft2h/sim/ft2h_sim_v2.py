#!/usr/bin/env python3
"""
FT2H Simulator v2 — Uses the ACTUAL WSJT-X LDPC(174,91) code.

Simulates end-to-end:
  1. Message → CRC14 → LDPC(174,91) encode → Scramble → Gray map → 8-GFSK
  2. AWGN channel
  3. 8-GFSK demod → Soft LLR → LDPC BP decode → Descramble → Verify

FT2H Parameters:
  8-GFSK, h=1.0, BT=1.0, 20.833 Bd
  Standard: LDPC(174,91), 76 symbols, 3.648s TX, 4.0s T/R
  Short:    LDPC(64,32),  32 symbols, 1.536s TX, 1.5s T/R

Usage:
  python ft2h_sim_v2.py              # Full simulation
  python ft2h_sim_v2.py --quick      # Quick validation
"""

import numpy as np
from scipy.special import erfc
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import argparse, time, sys

# ============================================================
# Constants
# ============================================================
NSPS = 576
FSAMPLE = 12000.0
BAUD = FSAMPLE / NSPS   # 20.833 Bd
HMOD = 1.0
BT = 1.0
M = 8

ND = 58; NS = 16; NN = 74; NN2 = 76
ND_S = 22; NS_S = 8; NN_S = 30; NN2_S = 32

ICOS8A = np.array([2,5,6,0,4,1,3,7])
ICOS8B = np.array([4,7,2,3,0,6,1,5])
ICOS8S = np.array([1,3,7,2,5,0,6,4])
GRAYMAP8 = np.array([0,1,3,2,7,6,4,5])
GRAY_INV = np.zeros(8, dtype=int)
for _i in range(8):
    GRAY_INV[GRAYMAP8[_i]] = _i

RVEC = np.array([0,1,0,0,1,0,1,0,0,1,0,1,1,1,1,0,1,0,0,0,1,0,0,1,1,0,1,1,0,
                 1,0,0,1,0,1,1,0,0,0,0,1,0,0,0,1,0,1,0,0,1,1,1,1,0,0,1,0,1,
                 0,1,0,1,0,1,1,0,1,1,1,1,1,0,0,0,1,0,1], dtype=np.int8)

# Gray demapping: igray[bit_position, tone] = bit_value (CORRECTED)
IGRAY = np.array([
    [0,0,0,0,1,1,1,1],  # Bit 0 (MSB)
    [0,0,1,1,1,1,0,0],  # Bit 1
    [0,1,1,0,0,1,1,0],  # Bit 2 (LSB) — corrected for graymap8
])

# ============================================================
# LDPC(174,91) — Actual WSJT-X Generator Matrix
# ============================================================
# From ldpc_174_91_c_generator.f90 — 83 rows × 91 columns (systematic)
_G_HEX = [
    "8329ce11bf31eaf509f27fc", "761c264e25c259335493132",
    "dc265902fb277c6410a1bdc", "1b3f417858cd2dd33ec7f62",
    "09fda4fee04195fd034783a", "077cccc11b8873ed5c3d48a",
    "29b62afe3ca036f4fe1a9da", "6054faf5f35d96d3b0c8c3e",
    "e20798e4310eed27884ae90", "775c9c08e80e26ddae56318",
    "b0b811028c2bf997213487c", "18a0c9231fc60adf5c5ea32",
    "76471e8302a0721e01b12b8", "ffbccb80ca8341fafb47b2e",
    "66a72a158f9325a2bf67170", "c4243689fe85b1c51363a18",
    "0dff739414d1a1b34b1c270", "15b48830636c8b99894972e",
    "29a89c0d3de81d665489b0e", "4f126f37fa51cbe61bd6b94",
    "99c47239d0d97d3c84e0940", "1919b75119765621bb4f1e8",
    "09db12d731faee0b86df6b8", "488fc33df43fbdeea4eafb4",
    "827423ee40b675f756eb5fe", "abe197c484cb74757144a9a",
    "2b500e4bc0ec5a6d2bdbdd0", "c474aa53d70218761669360",
    "8eba1a13db3390bd6718cec", "753844673a27782cc42012e",
    "06ff83a145c37035a5c1268", "3b37417858cc2dd33ec3f62",
    "9a4a5a28ee17ca9c324842c", "bc29f465309c977e89610a4",
    "2663ae6ddf8b5ce2bb29488", "46f231efe457034c1814418",
    "3fb2ce85abe9b0c72e06fbe", "de87481f282c153971a0a2e",
    "fcd7ccf23c69fa99bba1412", "f0261447e9490ca8e474cec",
    "4410115818196f95cdd7012", "088fc31df4bfbde2a4eafb4",
    "b8fef1b6307729fb0a078c0", "5afea7acccb77bbc9d99a90",
    "49a7016ac653f65ecdc9076", "1944d085be4e7da8d6cc7d0",
    "251f62adc4032f0ee714002", "56471f8702a0721e00b12b8",
    "2b8e4923f2dd51e2d537fa0", "6b550a40a66f4755de95c26",
    "a18ad28d4e27fe92a4f6c84", "10c2e586388cb82a3d80758",
    "ef34a41817ee02133db2eb0", "7e9c0c54325a9c15836e000",
    "3693e572d1fde4cdf079e86", "bfb2cec5abe1b0c72e07fbe",
    "7ee18230c583cccc57d4b08", "a066cb2fedafc9f52664126",
    "bb23725abc47cc5f4cc4cd2", "ded9dba3bee40c59b5609b4",
    "d9a7016ac653e6decdc9036", "9ad46aed5f707f280ab5fc4",
    "e5921c77822587316d7d3c2", "4f14da8242a8b86dca73352",
    "8b8b507ad467d4441df770e", "22831c9cf1169467ad04b68",
    "213b838fe2ae54c38ee7180", "5d926b6dd71f085181a4e12",
    "66ab79d4b29ee6e69509e56", "958148682d748a38dd68baa",
    "b8ce020cf069c32a723ab14", "f4331d6d461607e95752746",
    "6da23ba424b9596133cf9c8", "a636bcbc7b30c5fbeae67fe",
    "5cb0d86a07df654a9089a20", "f11f106848780fc9ecdd80a",
    "1fbb5364fb8d2c9d730d5ba", "fcb86bc70a50c9d02a5d034",
    "a534433029eac15f322e34c", "c989d9c7c3d3b8c55d75130",
    "7bb38b2f0186d46643ae962", "2644ebadeb44b9467d1f42c",
    "608cc857594bfbb55d69600",
]

def _parse_gen_matrix():
    """Parse the WSJT-X generator matrix hex representation."""
    G = np.zeros((83, 91), dtype=np.int8)
    for i, hexstr in enumerate(_G_HEX):
        # Each hex char = 4 bits, 23 chars = 92 bits, use first 91
        bits = []
        for ch in hexstr:
            val = int(ch, 16)
            bits.extend([(val >> 3) & 1, (val >> 2) & 1, (val >> 1) & 1, val & 1])
        G[i, :] = np.array(bits[:91], dtype=np.int8)
    return G

GEN_174_91 = _parse_gen_matrix()  # 83 × 91

# Parity check matrix connectivity from ldpc_174_91_c_parity.f90
# Mn: for each of 174 bit nodes, 3 connected check nodes
_MN_DATA = [
    16,45,73,25,51,62,33,58,78,1,44,45,2,7,61,3,6,54,4,35,48,5,13,21,
    8,56,79,9,64,69,10,19,66,11,36,60,12,37,58,14,32,43,15,63,80,17,28,77,
    18,74,83,22,53,81,23,30,34,24,31,40,26,41,76,27,57,70,29,49,65,3,38,78,
    5,39,82,46,50,73,51,52,74,55,71,72,44,67,72,43,68,78,1,32,59,2,6,71,
    4,16,54,7,65,67,8,30,42,9,22,31,10,18,76,11,23,82,12,28,61,13,52,79,
    14,50,51,15,81,83,17,29,60,19,33,64,20,26,73,21,34,40,24,27,77,25,55,58,
    35,53,66,36,48,68,37,46,75,38,45,47,39,57,69,41,56,62,20,49,53,46,52,63,
    45,70,75,27,35,80,1,15,30,2,68,80,3,36,51,4,28,51,5,31,56,6,20,37,
    7,40,82,8,60,69,9,10,49,11,44,57,12,39,59,13,24,55,14,21,65,16,71,78,
    17,30,76,18,25,80,19,61,83,22,38,77,23,41,50,7,26,58,29,32,81,33,40,73,
    18,34,48,13,42,64,5,26,43,47,69,72,54,55,70,45,62,68,10,63,67,14,66,72,
    22,60,74,35,39,79,1,46,64,1,24,66,2,5,70,3,31,65,4,49,58,1,4,5,
    6,60,67,7,32,75,8,48,82,9,35,41,10,39,62,11,14,61,12,71,74,13,23,78,
    11,35,55,15,16,79,7,9,16,17,54,63,18,50,57,19,30,47,20,64,80,21,28,69,
    22,25,43,13,22,37,2,47,51,23,54,74,26,34,72,27,36,37,21,36,63,29,40,44,
    19,26,57,3,46,82,14,15,58,33,52,53,30,43,52,6,9,52,27,33,65,25,69,73,
    38,55,83,20,39,77,18,29,56,32,48,71,42,51,59,28,44,79,34,60,62,31,45,61,
    46,68,77,6,24,76,8,10,78,40,41,70,17,50,53,42,66,68,4,22,72,36,64,81,
    13,29,47,2,8,81,56,67,73,5,38,50,12,38,64,59,72,80,3,26,79,45,76,81,
    1,65,74,7,18,77,11,56,59,14,39,54,16,37,66,10,28,55,15,60,70,17,25,82,
    20,30,31,12,67,68,23,75,80,27,32,62,24,69,75,19,21,71,34,53,61,35,46,47,
    33,59,76,40,43,83,41,42,63,49,75,83,20,44,48,42,49,57
]

def _build_parity_check():
    """Build H matrix (83×174) from Mn connectivity data."""
    H = np.zeros((83, 174), dtype=np.int8)
    Mn = np.array(_MN_DATA).reshape(174, 3)
    for bit in range(174):
        for chk_idx in Mn[bit]:
            H[chk_idx - 1, bit] = 1  # 1-indexed → 0-indexed
    return H, Mn

H_174_91, MN = _build_parity_check()

# ============================================================
# CRC-14 (matches WSJT-X crc14)
# ============================================================
def crc14(message77):
    """Compute 14-bit CRC matching WSJT-X crc14()."""
    # Pack 77 bits + 3 zeros into 10 bytes
    bits = np.zeros(80, dtype=np.uint8)
    bits[:77] = message77
    
    # Pack into bytes (MSB first)
    msg_bytes = np.zeros(12, dtype=np.uint8)
    for i in range(10):
        val = 0
        for j in range(8):
            val = (val << 1) | int(bits[i*8 + j])
        msg_bytes[i] = val
    
    # CRC-14 polynomial: x^14 + x^10 + x^9 + x^5 + x + 1 = 0x6757
    # Using byte-wise CRC computation
    crc = 0
    POLY = 0x6757
    for byte in msg_bytes:
        for bit_pos in range(7, -1, -1):
            bit = (byte >> bit_pos) & 1
            fb = ((crc >> 13) & 1) ^ bit
            crc = (crc << 1) & 0x3FFF
            if fb:
                crc ^= POLY
    
    return crc

# ============================================================
# Encoder
# ============================================================
def encode_174_91(msg77):
    """Encode 77-bit message → 174-bit LDPC codeword (systematic).
    Matches encode174_91.f90."""
    msg91 = np.zeros(91, dtype=np.int8)
    msg91[:77] = msg77
    
    # CRC-14
    c = crc14(msg77)
    for i in range(14):
        msg91[77 + i] = (c >> (13 - i)) & 1
    
    # Parity: p = msg91 × G^T (mod 2)
    parity = np.mod(GEN_174_91 @ msg91, 2).astype(np.int8)
    
    codeword = np.zeros(174, dtype=np.int8)
    codeword[:91] = msg91
    codeword[91:] = parity
    
    return codeword

# ============================================================
# BP Decoder (Min-Sum with normalization)
# ============================================================
def bp_decode_174_91(llr, max_iter=50, scale=0.8):
    """Belief Propagation (min-sum) decoder for LDPC(174,91).
    
    Args:
        llr: channel LLR (174,), positive = bit 0
        max_iter: max BP iterations
        scale: min-sum normalization factor
    
    Returns:
        (decoded_91, nhard) on success, (None, -1) on failure
    """
    N = 174
    M_chk = 83
    
    # Build adjacency from Mn (bit → checks) and from H (check → bits)
    bit_to_checks = []
    for bit in range(N):
        bit_to_checks.append(MN[bit] - 1)  # 0-indexed
    
    check_to_bits = []
    for chk in range(M_chk):
        check_to_bits.append(np.where(H_174_91[chk] == 1)[0])
    
    # Initialize messages
    # R[chk][bit] = check-to-bit message
    # Q[chk][bit] = bit-to-check message
    R = {}
    Q = {}
    for chk in range(M_chk):
        for bit in check_to_bits[chk]:
            R[(chk, bit)] = 0.0
            Q[(chk, bit)] = llr[bit]
    
    for iteration in range(max_iter):
        # Check-to-bit update (min-sum)
        for chk in range(M_chk):
            bits = check_to_bits[chk]
            for target_bit in bits:
                # Product of signs × min of magnitudes (excluding target)
                sign = 1
                min_mag = 1e30
                for other_bit in bits:
                    if other_bit != target_bit:
                        q_val = Q[(chk, other_bit)]
                        if q_val < 0:
                            sign *= -1
                        mag = abs(q_val)
                        if mag < min_mag:
                            min_mag = mag
                R[(chk, target_bit)] = sign * min_mag * scale
        
        # Bit-to-check update + tentative decode
        decoded = np.zeros(N, dtype=np.int8)
        for bit in range(N):
            checks = bit_to_checks[bit]
            # Total belief
            total = llr[bit]
            for chk in checks:
                total += R[(chk, bit)]
            
            decoded[bit] = 1 if total < 0 else 0
            
            # Update Q messages
            for chk in checks:
                Q[(chk, bit)] = total - R[(chk, bit)]
        
        # Check syndrome
        syndrome = np.mod(H_174_91 @ decoded, 2)
        if np.sum(syndrome) == 0:
            # Valid codeword — verify CRC
            msg77 = decoded[:77]
            crc_check = crc14(msg77)
            crc_bits = np.zeros(14, dtype=np.int8)
            for i in range(14):
                crc_bits[i] = (crc_check >> (13-i)) & 1
            
            if np.array_equal(decoded[77:91], crc_bits):
                nhard = int(np.sum((llr < 0).astype(int) != decoded))
                return decoded[:91], nhard
            else:
                # Valid codeword but CRC failed (undetectable error pattern)
                pass
    
    return None, -1

# ============================================================
# OSD Decoder (Order-0 with single-bit flips, faster fallback)  
# ============================================================
def osd_decode_174_91(llr, max_flips=40):
    """Ordered Statistics Decoding for LDPC(174,91).
    Faster than BP for high-SNR, good complement."""
    N = 174
    
    # Hard decision
    cw = (llr < 0).astype(np.int8)
    syndrome = np.mod(H_174_91 @ cw, 2)
    
    if np.sum(syndrome) == 0:
        msg77 = cw[:77]
        crc_check = crc14(msg77)
        crc_bits = np.zeros(14, dtype=np.int8)
        for i in range(14):
            crc_bits[i] = (crc_check >> (13-i)) & 1
        if np.array_equal(cw[77:91], crc_bits):
            return cw[:91], 0
    
    # Sort by reliability (ascending)
    reliab = np.abs(llr)
    idx = np.argsort(reliab)
    
    # Try flipping least reliable bits
    for flip in range(min(max_flips, N)):
        test = cw.copy()
        test[idx[flip]] = 1 - test[idx[flip]]
        syndrome = np.mod(H_174_91 @ test, 2)
        if np.sum(syndrome) == 0:
            msg77 = test[:77]
            crc_check = crc14(msg77)
            crc_bits = np.zeros(14, dtype=np.int8)
            for i in range(14):
                crc_bits[i] = (crc_check >> (13-i)) & 1
            if np.array_equal(test[77:91], crc_bits):
                return test[:91], flip + 1
    
    return None, -1

def decode_combined(llr):
    """Try BP first, then OSD as fallback."""
    result, nhard = bp_decode_174_91(llr, max_iter=40)
    if result is not None:
        return result, nhard
    return osd_decode_174_91(llr, max_flips=50)

# ============================================================
# 8-GFSK Modulator
# ============================================================
def gfsk_pulse(bt, t):
    c = np.pi * np.sqrt(2.0 / np.log(2.0))
    return 0.5 * (erfc(c * bt * (t - 0.5)) - erfc(c * bt * (t + 0.5)))

def gen_wave(tones, f0=1500.0):
    """Generate 8-GFSK waveform."""
    nsym = len(tones)
    dt = 1.0 / FSAMPLE
    twopi = 2.0 * np.pi
    
    pulse = np.array([gfsk_pulse(BT, (i - 1.5*NSPS)/NSPS) for i in range(3*NSPS)])
    
    nsamples = (nsym + 2) * NSPS
    dphi = np.zeros(nsamples)
    dphi_peak = twopi * HMOD / NSPS
    
    for j in range(nsym):
        ib = j * NSPS
        ie = ib + 3 * NSPS
        if ie <= nsamples:
            dphi[ib:ie] += dphi_peak * pulse * tones[j]
        else:
            dphi[ib:nsamples] += dphi_peak * pulse[:nsamples-ib] * tones[j]
    
    dphi += twopi * f0 * dt
    phi = np.cumsum(dphi)
    wave = np.sin(phi)
    
    # Ramp up/down
    ramp = (1.0 - np.cos(twopi * np.arange(NSPS) / (2.0*NSPS))) / 2.0
    wave[:NSPS] *= ramp
    k1 = (nsym+1) * NSPS
    if k1 + NSPS <= len(wave):
        wave[k1:k1+NSPS] *= (1.0 + np.cos(twopi * np.arange(NSPS) / (2.0*NSPS))) / 2.0
    
    return wave

# ============================================================
# 8-GFSK Demodulator
# ============================================================
def demod_8gfsk(signal, data_positions, f0=1500.0):
    """Extract soft LLR from received signal at known data positions.
    Note: +1 symbol offset to account for GFSK pulse delay."""
    dt = 1.0 / FSAMPLE
    t = np.arange(NSPS) * dt
    
    # Pre-compute reference tones (no window — GFSK with BT=1.0 has minimal ISI)
    refs = np.zeros((8, NSPS), dtype=complex)
    for tone in range(8):
        refs[tone] = np.exp(-2j * np.pi * (f0 + tone * BAUD) * t)
    
    all_s2 = []
    for pos in data_positions:
        k0 = (pos + 1) * NSPS  # +1 symbol offset for GFSK pulse center
        seg = signal[k0:k0+NSPS]
        if len(seg) < NSPS:
            all_s2.append(np.zeros(8))
            continue
        
        s2 = np.zeros(8)
        for tone in range(8):
            s2[tone] = np.abs(np.sum(seg * refs[tone])) ** 2
        all_s2.append(s2)
    
    all_s2 = np.array(all_s2)  # (n_sym, 8)
    
    # Compute LLR
    llr_list = []
    for i in range(len(data_positions)):
        s2 = all_s2[i]
        for ibit in range(3):
            mask0 = IGRAY[ibit] == 0
            mask1 = IGRAY[ibit] == 1
            smax0 = np.max(s2[mask0])
            smax1 = np.max(s2[mask1])
            llr_list.append(smax0 - smax1)
    
    llr = np.array(llr_list)
    # Normalize to target scale for BP decoder
    mean_abs = np.mean(np.abs(llr))
    if mean_abs > 0:
        llr = llr / mean_abs * 2.83
    
    return llr

# ============================================================
# Frame Assembly
# ============================================================
def make_standard_frame(msg77):
    """Encode 77-bit message into standard FT2H frame (76 tones)."""
    # Scramble
    scrambled = np.mod(msg77 + RVEC, 2).astype(np.int8)
    
    # Build 91-bit message (scrambled 77 + CRC14)
    msg91 = np.zeros(91, dtype=np.int8)
    msg91[:77] = scrambled
    c = crc14(scrambled)  
    for i in range(14):
        msg91[77+i] = (c >> (13-i)) & 1
    
    # LDPC encode  
    parity = np.mod(GEN_174_91 @ msg91, 2).astype(np.int8)
    codeword = np.concatenate([msg91, parity])
    
    # Gray map to tones
    data_syms = np.zeros(ND, dtype=int)
    for i in range(ND):
        val = codeword[3*i]*4 + codeword[3*i+1]*2 + codeword[3*i+2]
        data_syms[i] = GRAYMAP8[val]
    
    # Assemble frame: r1 + s8 + d29 + s8 + d29 + r1
    tones = np.zeros(NN2, dtype=int)
    tones[0] = 0
    tones[1:9] = ICOS8A
    tones[9:38] = data_syms[:29]
    tones[38:46] = ICOS8B
    tones[46:75] = data_syms[29:58]
    tones[75] = 0
    
    return tones, codeword

# ============================================================
# Simulation Engine
# ============================================================
def sim_standard(snr_db, f0=1500.0, ntrials=100):
    """Monte Carlo simulation for standard FT2H frame.
    Uses WSJT-X noise convention: sig = sqrt(BW/fs)*10^(snr/20), noise N(0,1)."""
    sig_fac = np.sqrt(2500.0 / FSAMPLE) * 10.0**(snr_db / 20.0)
    
    n_ok = 0
    n_bit_err = 0
    data_pos = list(range(9, 38)) + list(range(46, 75))
    
    for _ in range(ntrials):
        msg77 = np.random.randint(0, 2, 77).astype(np.int8)
        
        tones, cw = make_standard_frame(msg77)
        wave = gen_wave(tones, f0=f0)
        
        rx = sig_fac * wave + np.random.randn(len(wave))
        
        llr = demod_8gfsk(rx, data_pos, f0=f0)[:174]
        
        decoded_91, nhard = decode_combined(llr)
        
        if decoded_91 is not None:
            # Descramble
            dec_msg = np.mod(decoded_91[:77] + RVEC, 2).astype(np.int8)
            bit_err = int(np.sum(dec_msg != msg77))
            if bit_err == 0:
                n_ok += 1
            else:
                n_bit_err += bit_err
        else:
            n_bit_err += 77
    
    wer = 1.0 - n_ok / ntrials
    ber = n_bit_err / (ntrials * 77)
    return wer, ber, n_ok

# ============================================================
# Main
# ============================================================
def main():
    parser = argparse.ArgumentParser(description='FT2H Simulator v2 (real LDPC)')
    parser.add_argument('--quick', action='store_true')
    args = parser.parse_args()
    
    print("=" * 70)
    print("FT2H Hybrid Mode Simulator v2 — Real LDPC(174,91)")
    print("=" * 70)
    print(f"8-GFSK, h={HMOD}, BT={BT}, {BAUD:.3f} Bd, ~{8*BAUD:.0f} Hz BW")
    print(f"LDPC(174,91) — actual WSJT-X generator matrix")
    print(f"Standard: 76 symbols, 3.648s TX, 4.0s T/R")
    print("=" * 70)
    
    if args.quick:
        snr_range = np.arange(-20, -4, 2)
        ntrials = 30
    else:
        snr_range = np.arange(-22, -2, 1)
        ntrials = 100
    
    print(f"\n{'SNR(dB)':>8} {'WER':>8} {'BER':>10} {'OK':>6}/{ntrials} {'t(s)':>6}")
    print("-" * 48)
    
    results_snr = []
    results_wer = []
    results_ber = []
    
    for snr in snr_range:
        t0 = time.time()
        wer, ber, nok = sim_standard(snr, ntrials=ntrials)
        dt_elapsed = time.time() - t0
        
        results_snr.append(snr)
        results_wer.append(wer)
        results_ber.append(ber)
        
        print(f"{snr:>8.1f} {wer:>8.4f} {ber:>10.6f} {nok:>6}/{ntrials} {dt_elapsed:>6.1f}")
        sys.stdout.flush()
        
        if wer == 0 and snr > -10:
            # Fill remaining with zeros
            for s in snr_range[snr_range > snr]:
                results_snr.append(s)
                results_wer.append(0.0)
                results_ber.append(0.0)
            break
    
    # Find 50% threshold
    wer_arr = np.array(results_wer)
    snr_arr = np.array(results_snr)
    for i in range(len(wer_arr)):
        if wer_arr[i] < 0.5:
            if i > 0:
                snr_50 = snr_arr[i-1] + (snr_arr[i]-snr_arr[i-1]) * \
                          (0.5 - wer_arr[i-1]) / (wer_arr[i] - wer_arr[i-1] + 1e-10)
            else:
                snr_50 = snr_arr[i]
            break
    else:
        snr_50 = snr_arr[-1]
    
    # Plot
    fig, ax = plt.subplots(figsize=(10, 6))
    ax.semilogy(snr_arr, np.clip(wer_arr, 1e-4, 1), 'bo-', lw=2, label='WER (simulador)')
    ax.axvline(-21.0, color='gray', ls=':', alpha=0.7, label='FT8 (-21 dB)')
    ax.axvline(-17.5, color='orange', ls=':', alpha=0.7, label='FT4 (-17.5 dB)')
    ax.axvline(snr_50, color='red', ls='--', alpha=0.8, lw=2, label=f'Simulador ({snr_50:.1f} dB)')
    opt_est = snr_50 - 5.0  # Estimated optimized threshold
    ax.axvline(opt_est, color='green', ls='-.', alpha=0.8, lw=2, 
               label=f'Estimado optimizado ({opt_est:.1f} dB)')
    ax.axhline(0.5, color='gray', ls='-', alpha=0.3)
    ax.set_xlabel('SNR en BW de 2500 Hz (dB) — convenio WSJT-X')
    ax.set_ylabel('Word Error Rate')
    ax.set_title('FT2H Hybrid Mode — Sensibilidad (frame estándar LDPC-174,91)')
    ax.legend(loc='lower left')
    ax.grid(True, alpha=0.3)
    ax.set_ylim(1e-3, 1.1)
    ax.set_xlim(-24, -2)
    plt.tight_layout()
    plt.savefig('ft2h_sim_results.png', dpi=150)
    print(f"\nGráfico: ft2h_sim_results.png")
    
    opt_est = snr_50 - 5.0  # ~5 dB gain from optimized implementation
    
    # Summary
    print(f"\n{'='*70}")
    print(f"RESULTADOS — FT2H Hybrid Mode")
    print(f"{'='*70}")
    print(f"Convenio de ruido: WSJT-X (sig=sqrt(BW/fs)*10^(snr/20), noise N(0,1))")
    print(f"")
    print(f"Umbral 50% decode (simulador):   {snr_50:.1f} dB")
    print(f"Estimado optimizado (*):         {opt_est:.1f} dB")
    print()
    print(f"{'Modo':<10} {'Sensib.':>8} {'Ciclo':>6} {'Throughput':>12} {'BW':>8}")
    print(f"{'─'*52}")
    print(f"{'FT8':<10} {'-21.0':>8} {'15.0s':>6} {'5.1 b/s':>12} {'50 Hz':>8}")
    print(f"{'FT4':<10} {'-17.5':>8} {'7.5s':>6} {'10.3 b/s':>12} {'90 Hz':>8}")
    print(f"{'FT2H sim':<10} {f'{snr_50:.1f}':>8} {'4.0s':>6} {'19.2 b/s':>12} {'167 Hz':>8}")
    print(f"{'FT2H opt*':<10} {f'{opt_est:.1f}':>8} {'4.0s':>6} {'19.2 b/s':>12} {'167 Hz':>8}")
    print()
    print(f"(*) Estimación con demod trellis + sum-product BP + sync iterativo")
    print(f"    Ganancia estimada: ~5 dB sobre el simulador simple")
    print()
    print(f"Velocidad:")
    print(f"  FT2H: 3.8x vs FT8, 1.9x vs FT4")
    print(f"  QSO típico (6 intercambios): FT8 ~90s, FT4 ~45s, FT2H ~24s")
    print()
    print(f"Costo en sensibilidad (simulador / optimizado):")
    print(f"  vs FT8: {snr_50-(-21.0):+.1f} / {opt_est-(-21.0):+.1f} dB")
    print(f"  vs FT4: {snr_50-(-17.5):+.1f} / {opt_est-(-17.5):+.1f} dB")
    print(f"{'='*70}")

if __name__ == '__main__':
    main()
