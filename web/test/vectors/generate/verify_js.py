#!/usr/bin/env python3
"""Opens what the page sealed, with an implementation that is not the page's.

    .venv/bin/python verify_js.py <file.json>

The file has `recipients` (id -> privateKey, publicKey, keyId) and `cases`, each with `name`, `recipient`,
`envelope` and `plaintext`. Exit code 0 only if every envelope opens to exactly its plaintext, its padding block is
right, and its AAD fields are the envelope's own.
"""
from __future__ import annotations

import json
import sys

from sealed_common import b64u_decode, key_id, open_envelope, padding_unit


def main(path: str) -> int:
    with open(path, encoding="utf-8") as handle:
        document = json.load(handle)
    failures = 0
    for case in document["cases"]:
        name = case["name"]
        recipient = document["recipients"][case["recipient"]]
        envelope = case["envelope"]
        try:
            if key_id(b64u_decode(recipient["publicKey"])) != envelope["keyId"]:
                raise AssertionError("keyId is not the hash of the recipient's public key")
            opened = open_envelope(envelope, b64u_decode(recipient["privateKey"])).decode("utf-8")
            if opened != case["plaintext"]:
                raise AssertionError("plaintext differs")
            payload = json.loads(opened)
            unit = padding_unit(envelope["kind"], "photoJpeg" in payload)
            if len(opened.encode("utf-8")) % unit != 0:
                raise AssertionError(f"plaintext is not a multiple of {unit} bytes")
            if "_pad" not in payload or set(payload["_pad"]) - {"0"}:
                raise AssertionError("missing or non-zero padding field")
            print(f"ok    {name}")
        except Exception as error:  # noqa: BLE001 - report every failing case, then exit non-zero
            failures += 1
            print(f"FAIL  {name}: {error}")
    print(f"{len(document['cases']) - failures}/{len(document['cases'])} envelopes opened")
    return 1 if failures else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: verify_js.py <file.json>", file=sys.stderr)
        raise SystemExit(2)
    raise SystemExit(main(sys.argv[1]))
