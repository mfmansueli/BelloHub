#!/usr/bin/env python3
"""Known-answer vectors for the vault key hierarchy (docs/06-PRIVACY-SECURITY.md section 4.1), computed without
CryptoKit: HKDF-SHA256 from the standard library, X25519 as the RFC 7748 Montgomery ladder (checked against the
RFC's own vector), BIP-39 encoding checked against the four published vectors. The Swift tests hard-code these
values; run this script to see where they come from. Never change them without a migration: they pin the keys
that every existing record was encrypted with.

Usage: python3 scripts/vault-vectors.py
"""
import base64
import hashlib
import hmac
import os
import urllib.request

WORDLIST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "bip39-english.txt")
os.makedirs(os.path.dirname(WORDLIST), exist_ok=True)
if not os.path.exists(WORDLIST):
    urllib.request.urlretrieve("https://raw.githubusercontent.com/bitcoin/bips/master/bip-0039/english.txt", WORDLIST)
P = 2**255 - 19
A24 = 121665
def clamp(k):
    b = bytearray(k); b[0] &= 248; b[31] &= 127; b[31] |= 64; return int.from_bytes(b, "little")
def x25519(k, u):  # RFC 7748 Montgomery ladder
    k = clamp(k); x1 = u; x2, z2, x3, z3, swap = 1, 0, u, 1, 0
    for t in reversed(range(255)):
        kt = (k >> t) & 1; swap ^= kt
        if swap: x2, x3, z2, z3 = x3, x2, z3, z2
        swap = kt
        a = (x2 + z2) % P; aa = a * a % P; b = (x2 - z2) % P; bb = b * b % P; e = (aa - bb) % P
        c = (x3 + z3) % P; d = (x3 - z3) % P; da = d * a % P; cb = c * b % P
        x3 = (da + cb) ** 2 % P; z3 = x1 * ((da - cb) ** 2) % P
        x2 = aa * bb % P; z2 = e * (aa + A24 * e) % P
    if swap: x2, x3, z2, z3 = x3, x2, z3, z2
    return (x2 * pow(z2, P - 2, P) % P).to_bytes(32, "little")
def hkdf(ikm, salt, info, length=32):
    prk = hmac.new(salt if salt else b"\x00" * 32, ikm, hashlib.sha256).digest()
    out, t, i = b"", b"", 1
    while len(out) < length:
        t = hmac.new(prk, t + info + bytes([i]), hashlib.sha256).digest(); out += t; i += 1
    return out[:length]
def b64u(b): return base64.urlsafe_b64encode(b).decode().rstrip("=")
with open(WORDLIST) as handle:
    words = handle.read().split()
assert len(words) == 2048
def mnemonic(entropy):
    bits = bin(int.from_bytes(entropy, "big"))[2:].zfill(len(entropy) * 8)
    bits += bin(hashlib.sha256(entropy).digest()[0])[2:].zfill(8)[: len(entropy) * 8 // 32]
    return [words[int(bits[i:i + 11], 2)] for i in range(0, len(bits), 11)]
E = bytes.fromhex("00112233445566778899aabbccddeeff")
master = hkdf(E, b"bellohub.v1", b"master")
vault = hkdf(master, b"", b"bellohub/vault/aes256gcm/v1")
print("entropy      ", E.hex())
print("mnemonic     ", " ".join(mnemonic(E)))
print("masterKey    ", master.hex())
print("vaultKey     ", vault.hex())
for g in (1, 2):
    seed = hkdf(master, b"", f"bellohub/inbox/x25519/v1/g{g}".encode())
    pub = x25519(seed, 9)
    print(f"inboxSeed_g{g}  ", seed.hex()); print(f"inboxPub_g{g}   ", pub.hex()); print(f"keyId_g{g}      ", b64u(hashlib.sha256(pub).digest()[:8]))
# RFC 7748 section 6.1 self-check of the ladder (Alice's public key)
alice = bytes.fromhex("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
assert x25519(alice, 9).hex() == "8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a", "ladder self-check failed"
print("ladder matches RFC 7748 vector")
for h, expect in (("00" * 16, "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"),
                  ("7f" * 16, "legal winner thank year wave sausage worth useful legal winner thank yellow"),
                  ("80" * 16, "letter advice cage absurd amount doctor acoustic avoid letter advice cage above"),
                  ("ff" * 16, "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong")):
    got = " ".join(mnemonic(bytes.fromhex(h))); assert got == expect, (h, got)
print("BIP-39 published vectors match")
print("sha256(english.txt) =", hashlib.sha256(open(WORDLIST, "rb").read()).hexdigest())
