"""Shared helpers for the cross-implementation vectors of the sealed mailbox (docs/06-PRIVACY-SECURITY.md section 3).

This file is deliberately written from the specification, not from the page's TypeScript: the point of the vectors is
that an implementation that shares no code with the page agrees with it. HPKE itself is `pyhpke` (a different library
from the page's `hpke-js`), and the X25519 key arithmetic is `cryptography` (OpenSSL).
"""
from __future__ import annotations

import base64
import hashlib
import json
from typing import Any

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey
from pyhpke import AEADId, CipherSuite, KDFId, KEMId, OpenError

SUITE_NAME = "hpke-x25519-hkdf-sha256-chacha20poly1305"
INFO = b"bellohub/inbox/v1"


def b64u(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def b64u_decode(text: str) -> bytes:
    return base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))


def suite() -> CipherSuite:
    # mode base, DHKEM(X25519, HKDF-SHA256) 0x0020, HKDF-SHA256 0x0001, ChaCha20-Poly1305 0x0003
    return CipherSuite.new(KEMId.DHKEM_X25519_HKDF_SHA256, KDFId.HKDF_SHA256, AEADId.CHACHA20_POLY1305)


def public_from_seed(seed: bytes) -> bytes:
    key = X25519PrivateKey.from_private_bytes(seed)
    return key.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)


def key_id(public_key: bytes) -> str:
    """keyId = base64url(SHA-256(pub)[0..<8])."""
    return b64u(hashlib.sha256(public_key).digest()[:8])


def aad_for(kind: str, item_id: str, key_id_text: str) -> bytes:
    return f"bellohub/v1|{kind}|{item_id}|{key_id_text}".encode("utf-8")


def serialize(payload: dict[str, Any]) -> str:
    """JSON the way JSON.stringify writes it: no spaces, non-ASCII kept as is, keys in insertion order."""
    return json.dumps(payload, separators=(",", ":"), ensure_ascii=False)


def pad_payload(payload: dict[str, Any], unit: int) -> str:
    """The plaintext framing: the payload plus a trailing `_pad` of ASCII zeros so the UTF-8 length is a multiple of `unit`."""
    base = {**{k: v for k, v in payload.items() if k != "_pad"}, "_pad": ""}
    length = len(serialize(base).encode("utf-8"))
    fill = (unit - length % unit) % unit
    base["_pad"] = "0" * fill
    return serialize(base)


def padding_unit(kind: str, has_photo: bool) -> int:
    return 16 * 1024 if kind == "checkin" and has_photo else 1024


def seal(recipient_public: bytes, plaintext: bytes, aad: bytes, ikm_e: bytes) -> tuple[bytes, bytes]:
    """Seals with a deterministic ephemeral key (RFC 9180 `ikmE`), so the vector is reproducible."""
    hpke = suite()
    pkr = hpke.kem.deserialize_public_key(recipient_public)
    ephemeral = hpke.kem.derive_key_pair(ikm_e)
    enc, sender = hpke.create_sender_context(pkr, info=INFO, eks=ephemeral)
    return enc, sender.seal(plaintext, aad=aad)


def open_envelope(envelope: dict[str, Any], recipient_private: bytes) -> bytes:
    """Opens an envelope the way the iPhone will: AAD from the envelope's own kind, item id and key id.

    Raises OpenError (or ValueError for a malformed field) when the envelope must be rejected.
    """
    if envelope.get("v") != 1:
        raise ValueError("unsupported envelope version")
    if envelope.get("suite") != SUITE_NAME:
        raise ValueError("unsupported suite")
    enc = b64u_decode(envelope["enc"])
    ct = b64u_decode(envelope["ct"])
    aad = aad_for(envelope["kind"], envelope["itemId"], envelope["keyId"])
    hpke = suite()
    skr = hpke.kem.deserialize_private_key(recipient_private)
    context = hpke.create_recipient_context(enc, skr, info=INFO)
    return context.open(ct, aad=aad)


__all__ = [
    "INFO",
    "OpenError",
    "SUITE_NAME",
    "aad_for",
    "b64u",
    "b64u_decode",
    "key_id",
    "open_envelope",
    "pad_payload",
    "padding_unit",
    "public_from_seed",
    "seal",
    "serialize",
    "suite",
]
