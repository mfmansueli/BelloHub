#!/usr/bin/env python3
"""Generates web/test/vectors/inbox-v1.json with an implementation that shares no code with the page.

    cd web/test/vectors/generate
    python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
    .venv/bin/python generate.py            # writes ../inbox-v1.json
    .venv/bin/python generate.py --check    # fails if the committed file is not what this script produces

Everything is deterministic (fixed recipient seeds, fixed ephemeral key material per case, fixed item ids), so the
output is stable and the page can be asked to reproduce it byte for byte.
"""
from __future__ import annotations

import base64
import copy
import hashlib
import json
import sys
import uuid
from pathlib import Path
from typing import Any

from sealed_common import (
    INFO,
    OpenError,
    SUITE_NAME,
    aad_for,
    b64u,
    b64u_decode,
    key_id,
    open_envelope,
    pad_payload,
    padding_unit,
    public_from_seed,
    seal,
    suite,
)

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / "inbox-v1.json"
RFC = HERE.parent / "rfc9180-vectors.json"


def digest(label: str) -> bytes:
    return hashlib.sha256(label.encode("utf-8")).digest()


def item_id(name: str) -> str:
    """A fixed UUID v4 per case (the browser generates a random one)."""
    raw = bytearray(digest(f"bellohub/vectors/item/{name}")[:16])
    raw[6] = (raw[6] & 0x0F) | 0x40
    raw[8] = (raw[8] & 0x3F) | 0x80
    return str(uuid.UUID(bytes=bytes(raw)))


def filler(label: str, size: int) -> str:
    """Deterministic base64 text standing in for a PNG or a JPEG (`size` raw bytes)."""
    out = bytearray()
    counter = 0
    while len(out) < size:
        out += digest(f"{label}/{counter}")
        counter += 1
    return base64.b64encode(bytes(out[:size])).decode("ascii")


def recipient(index: int) -> dict[str, str]:
    seed = digest(f"bellohub/vectors/recipient/{index}")
    public = public_from_seed(seed)
    return {"privateKey": b64u(seed), "publicKey": b64u(public), "keyId": key_id(public)}


RECIPIENTS = {"r1": recipient(1), "r2": recipient(2)}

SUBMITTED = "2026-10-08T14:03:21.000Z"


def intake(**overrides: Any) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "schema": 1,
        "bookingId": "bk_7Hq2xkP9",
        "clientName": "Helena Duarte",
        "localeId": "pt-BR",
        "formVersion": "2026-10.1",
        "answers": {
            "allergies": ["fragrance", "latex"],
            "medication": False,
            "pregnantOrBreastfeeding": False,
            "skinCondition": True,
            "isotretinoinOrPeel": False,
            "anythingElse": "Pele sensível a fragrâncias; fiz um peeling há duas semanas.",
        },
        "isForMinor": False,
        "consent": {
            "textVersion": "2026-10",
            "textLocaleId": "pt-BR",
            "acceptedAt": SUBMITTED,
            "typedSignature": "Helena Duarte",
        },
        "submittedAt": SUBMITTED,
    }
    payload.update(overrides)
    return payload


def boundary_note() -> str:
    """A note that makes the unpadded JSON exactly a multiple of 1 KiB, so the `_pad` is empty."""
    for size in range(1, 4096):
        candidate = intake(answers={"anythingElse": "a" * size})
        base = {**candidate, "_pad": ""}
        if len(json.dumps(base, separators=(",", ":"), ensure_ascii=False).encode("utf-8")) % 1024 == 0:
            return "a" * size
    raise RuntimeError("no boundary found")


def positive_cases() -> list[dict[str, Any]]:
    cases: list[tuple[str, str, dict[str, Any], bool]] = [
        ("intake-adult-pt-br", "intake", intake(), False),
        (
            "intake-minor-arabic",
            "intake",
            intake(
                clientName="مريم الحارثي",
                localeId="ar",
                answers={"allergies": ["latex"], "medication": True, "anythingElse": "حساسية من العطور. تناولت دواءً قبل أسبوع."},
                isForMinor=True,
                minorName="لينا الحارثي",
                guardianName="مريم الحارثي",
                consent={
                    "textVersion": "2026-10",
                    "textLocaleId": "ar",
                    "acceptedAt": SUBMITTED,
                    "typedSignature": "مريم الحارثي",
                    "photos": False,
                },
            ),
            False,
        ),
        (
            "intake-hindi-emoji",
            "intake",
            intake(
                clientName="प्रिया शर्मा",
                localeId="hi",
                answers={"allergies": ["none"], "anythingElse": "त्वचा संवेदनशील है 🌿 और धूप से लाल हो जाती है।"},
            ),
            False,
        ),
        (
            "intake-with-signature",
            "intake",
            intake(signaturePng=filler("signature", 40_000)),
            False,
        ),
        ("intake-block-boundary", "intake", intake(answers={"anythingElse": boundary_note()}), False),
        (
            "checkin-with-photo",
            "checkin",
            {
                "schema": 1,
                "bookingId": "bk_7Hq2xkP9",
                "feeling": "irritated",
                "note": "Bochechas vermelhas desde a manhã.",
                "photoJpeg": filler("photo", 15_000),
                "submittedAt": SUBMITTED,
            },
            True,
        ),
        (
            "checkin-no-photo",
            "checkin",
            {"schema": 1, "bookingId": "bk_7Hq2xkP9", "feeling": "good", "submittedAt": SUBMITTED},
            False,
        ),
        (
            "datarequest-delete",
            "datarequest",
            {
                "schema": 1,
                "request": "delete",
                "name": "Helena Duarte",
                "phone": "+5511987654321",
                "submittedAt": SUBMITTED,
            },
            False,
        ),
        (
            "datarequest-copy-note",
            "datarequest",
            {
                "schema": 1,
                "request": "copy",
                "name": "José Ñandú",
                "phone": "+34612345678",
                "note": "Prefiero un PDF, gracias.",
                "submittedAt": SUBMITTED,
            },
            False,
        ),
    ]
    out: list[dict[str, Any]] = []
    for name, kind, payload, has_photo in cases:
        plaintext = pad_payload(payload, padding_unit(kind, has_photo))
        item = item_id(name)
        who = RECIPIENTS["r1"]
        ikm_e = digest(f"bellohub/vectors/ikmE/{name}")
        aad = aad_for(kind, item, who["keyId"])
        enc, ct = seal(b64u_decode(who["publicKey"]), plaintext.encode("utf-8"), aad, ikm_e)
        out.append(
            {
                "name": name,
                "recipient": "r1",
                "kind": kind,
                "hasPhoto": has_photo,
                "itemId": item,
                "ikmE": b64u(ikm_e),
                "payload": payload,
                "plaintext": plaintext,
                "aad": aad.decode("utf-8"),
                "envelope": {
                    "v": 1,
                    "suite": SUITE_NAME,
                    "keyId": who["keyId"],
                    "kind": kind,
                    "itemId": item,
                    "enc": b64u(enc),
                    "ct": b64u(ct),
                },
            }
        )
    return out


def flip(text: str, position: int) -> str:
    raw = bytearray(b64u_decode(text))
    raw[position % len(raw)] ^= 0x01
    return b64u(bytes(raw))


def negative_cases(positives: list[dict[str, Any]]) -> list[dict[str, Any]]:
    base = copy.deepcopy(positives[0])
    other = copy.deepcopy(positives[2])
    envelope = base["envelope"]

    def variant(name: str, description: str, change: dict[str, Any], recipient_id: str = "r1", expect: str = "open-fails") -> dict[str, Any]:
        return {
            "name": name,
            "description": description,
            "recipient": recipient_id,
            "expect": expect,
            "envelope": {**envelope, **change},
        }

    return [
        variant("tampered-ciphertext", "one bit of the ciphertext flipped", {"ct": flip(envelope["ct"], 5)}),
        variant("tampered-tag", "one bit of the 16-byte tag flipped", {"ct": flip(envelope["ct"], len(b64u_decode(envelope["ct"])) - 3)}),
        variant("tampered-enc", "one bit of the encapsulated key flipped", {"enc": flip(envelope["enc"], 7)}),
        variant("truncated-ciphertext", "shorter than the tag", {"ct": b64u(b64u_decode(envelope["ct"])[:10])}),
        variant("empty-ciphertext", "no ciphertext at all", {"ct": ""}),
        variant("wrong-kind", "kind changed after sealing: the AAD no longer matches", {"kind": "checkin"}),
        variant("wrong-item-id", "item id swapped: replay of another item", {"itemId": item_id("some-other-item")}),
        variant("wrong-key-id-field", "key id in the envelope changed: the AAD no longer matches", {"keyId": RECIPIENTS["r2"]["keyId"]}),
        variant("wrong-recipient-key", "opened with another inbox private key", {}, recipient_id="r2"),
        variant("enc-swapped-from-other-envelope", "encapsulated key of another envelope", {"enc": other["envelope"]["enc"]}),
        variant("unsupported-version", "envelope version 2 must be rejected before opening", {"v": 2}, expect="reject-before-open"),
        variant("unsupported-suite", "unknown suite must be rejected before opening", {"suite": "hpke-p256-hkdf-sha256-aes128gcm"}, expect="reject-before-open"),
    ]


def build() -> dict[str, Any]:
    positives = positive_cases()
    return {
        "schema": 1,
        "description": (
            "Cross-implementation vectors for the sealed mailbox (docs/06-PRIVACY-SECURITY.md section 3). "
            "Generated by an implementation independent of the page (pyhpke + cryptography). "
            "Positive cases are deterministic: sealing `payload` with `recipient`, `itemId` and `ikmE` as the RFC 9180 "
            "ephemeral input must give exactly `envelope`; opening `envelope` must give exactly `plaintext`. "
            "Negative cases must fail to open (or be rejected before opening)."
        ),
        "generator": "web/test/vectors/generate/generate.py (pyhpke 0.6.3, cryptography 46.0.7)",
        "suite": {
            "name": SUITE_NAME,
            "mode": "base",
            "kem": {"name": "DHKEM(X25519, HKDF-SHA256)", "id": "0x0020"},
            "kdf": {"name": "HKDF-SHA256", "id": "0x0001"},
            "aead": {"name": "ChaCha20-Poly1305", "id": "0x0003"},
        },
        "info": INFO.decode("utf-8"),
        "aadFormat": "bellohub/v1|<kind>|<itemId>|<keyId>",
        "paddingBlocks": {"intake": 1024, "datarequest": 1024, "checkin": 1024, "checkinWithPhoto": 16384},
        "binaryEncoding": "base64url without padding",
        "recipients": RECIPIENTS,
        "positive": positives,
        "negative": negative_cases(positives),
    }


def self_check(document: dict[str, Any]) -> None:
    """The independent implementation must agree with the RFC 9180 test vector and with itself."""
    rfc = json.loads(RFC.read_text(encoding="utf-8"))
    hpke = suite()
    vector = rfc["vector"]
    info = bytes.fromhex(vector["info"])
    skr = hpke.kem.deserialize_private_key(bytes.fromhex(vector["skRm"]))
    ephemeral = hpke.kem.derive_key_pair(bytes.fromhex(vector["ikmE"]))
    pkr = hpke.kem.deserialize_public_key(bytes.fromhex(vector["pkRm"]))
    enc, sender = hpke.create_sender_context(pkr, info=info, eks=ephemeral)
    assert enc.hex() == vector["enc"], "RFC 9180 enc mismatch"
    recipient_context = hpke.create_recipient_context(enc, skr, info=info)
    for item in vector["encryptions"]:
        ct = sender.seal(bytes.fromhex(item["pt"]), aad=bytes.fromhex(item["aad"]))
        assert ct.hex() == item["ct"], "RFC 9180 ciphertext mismatch"
        assert recipient_context.open(ct, aad=bytes.fromhex(item["aad"])).hex() == item["pt"]
    for case in document["positive"]:
        opened = open_envelope(case["envelope"], b64u_decode(document["recipients"][case["recipient"]]["privateKey"]))
        assert opened.decode("utf-8") == case["plaintext"], f"round trip failed for {case['name']}"
        framed = pad_payload(case["payload"], padding_unit(case["kind"], case["hasPhoto"]))
        assert framed == case["plaintext"], f"padding mismatch for {case['name']}"
        assert len(framed.encode("utf-8")) % padding_unit(case["kind"], case["hasPhoto"]) == 0
    for case in document["negative"]:
        try:
            open_envelope(case["envelope"], b64u_decode(document["recipients"][case["recipient"]]["privateKey"]))
        except (OpenError, ValueError, KeyError):
            continue
        raise AssertionError(f"negative case opened: {case['name']}")


def main(argv: list[str]) -> int:
    document = build()
    self_check(document)
    text = json.dumps(document, indent=2, ensure_ascii=False) + "\n"
    if "--check" in argv:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print("error: inbox-v1.json is out of date; run generate.py", file=sys.stderr)
            return 1
        print("inbox-v1.json is up to date")
        return 0
    OUT.write_text(text, encoding="utf-8")
    print(f"wrote {OUT} ({len(document['positive'])} positive, {len(document['negative'])} negative)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
