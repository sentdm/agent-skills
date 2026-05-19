#!/usr/bin/env python3
"""Validate a Sent 10DLC compliance packet before it is filed with TCR.

Usage:
    python validate_10dlc_packet.py <path-to-packet.json>

The packet is a JSON object representing the answers a tenant submitted on
Sent's 10DLC compliance form. The validator checks the mechanical things
that are cheap to catch locally and expensive to discover after TCR or a
carrier rejects the submission. Semantic checks (use-case match, content
policy) are out of scope — see references/10dlc-evidence-checklist.md and
references/10dlc-rejection-remediation.md.

Expected shape:

    {
      "legal_name": "Example Corp LLC",
      "ein": "12-3456789",
      "address": "123 Main St, Springfield, IL 62701, US",
      "website": "https://example.com",
      "privacy_policy_url": "https://example.com/privacy",
      "opt_in_mechanism_url": "https://example.com/signup",
      "use_cases": [
        {
          "name": "Order updates",
          "description": "Shipping and delivery updates for orders.",
          "sample_messages": [
            "Example: Your order #1029 has shipped. Reply STOP to opt out."
          ],
          "opt_out_text": "Example: You're unsubscribed. Reply HELP for help."
        }
      ]
    }

Exits 0 with `OK` on success. On failure, prints one issue per line in the
form `<path>: <field>: <reason>` and exits 1.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from typing import Any

# Required top-level keys on the packet.
REQUIRED_TOP_LEVEL = (
    "legal_name",
    "ein",
    "address",
    "website",
    "privacy_policy_url",
    "opt_in_mechanism_url",
    "use_cases",
)

# Required keys on each use case.
REQUIRED_USE_CASE = (
    "name",
    "description",
    "sample_messages",
    "opt_out_text",
)

URL_FIELDS = ("website", "privacy_policy_url", "opt_in_mechanism_url")

# Permissive URL regex: scheme + host + optional path. Catches obvious junk
# (no scheme, internal whitespace, missing host) without trying to be a full
# RFC 3986 validator.
URL_RE = re.compile(r"^https?://[^\s/$.?#].[^\s]*$", re.IGNORECASE)

# EIN: 9 digits, optionally hyphenated after the first two.
EIN_RE = re.compile(r"^\d{2}-?\d{7}$")

# Minimum length of a sample message before reviewers flag it as too generic.
MIN_SAMPLE_LEN = 20


def _is_nonempty_string(value: Any) -> bool:
    return isinstance(value, str) and value.strip() != ""


def validate(packet: dict[str, Any], path: str) -> list[str]:
    """Return a list of issue strings. Empty list means the packet is valid."""
    issues: list[str] = []

    def issue(field: str, reason: str) -> None:
        issues.append(f"{path}: {field}: {reason}")

    if not isinstance(packet, dict):
        issue("<root>", "packet must be a JSON object")
        return issues

    # Top-level required keys (non-empty).
    for key in REQUIRED_TOP_LEVEL:
        if key not in packet:
            issue(key, "missing required field")
        elif key == "use_cases":
            if not isinstance(packet[key], list) or len(packet[key]) == 0:
                issue(key, "must be a non-empty list")
        elif not _is_nonempty_string(packet[key]):
            issue(key, "must be a non-empty string")

    # URL fields.
    for key in URL_FIELDS:
        value = packet.get(key)
        if _is_nonempty_string(value) and not URL_RE.match(value):
            issue(key, f"not a valid URL: {value!r}")

    # EIN format.
    ein = packet.get("ein")
    if _is_nonempty_string(ein) and not EIN_RE.match(ein):
        issue("ein", f"must match ^\\d{{2}}-?\\d{{7}}$ (got {ein!r})")

    # Use cases.
    use_cases = packet.get("use_cases")
    if isinstance(use_cases, list):
        for i, uc in enumerate(use_cases):
            prefix = f"use_cases[{i}]"
            if not isinstance(uc, dict):
                issue(prefix, "must be a JSON object")
                continue

            for key in REQUIRED_USE_CASE:
                if key not in uc:
                    issue(f"{prefix}.{key}", "missing required field")

            name = uc.get("name")
            description = uc.get("description")
            if "name" in uc and not _is_nonempty_string(name):
                issue(f"{prefix}.name", "must be a non-empty string")
            if "description" in uc and not _is_nonempty_string(description):
                issue(f"{prefix}.description", "must be a non-empty string")

            samples = uc.get("sample_messages")
            if "sample_messages" in uc:
                if not isinstance(samples, list) or len(samples) == 0:
                    issue(
                        f"{prefix}.sample_messages",
                        "must be a non-empty list (>=1 sample per use case)",
                    )
                else:
                    for j, sample in enumerate(samples):
                        sprefix = f"{prefix}.sample_messages[{j}]"
                        if not _is_nonempty_string(sample):
                            issue(sprefix, "must be a non-empty string")
                        elif len(sample.strip()) < MIN_SAMPLE_LEN:
                            issue(
                                sprefix,
                                f"sample is {len(sample.strip())} chars; "
                                f"reviewers flag samples under {MIN_SAMPLE_LEN} as too generic",
                            )

            opt_out = uc.get("opt_out_text")
            if "opt_out_text" in uc:
                if not _is_nonempty_string(opt_out):
                    issue(f"{prefix}.opt_out_text", "must be a non-empty string")
                elif "stop" not in opt_out.lower():
                    issue(
                        f"{prefix}.opt_out_text",
                        "must mention 'STOP' (case-insensitive) so recipients can opt out",
                    )

    return issues


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="validate_10dlc_packet.py",
        description=(
            "Validate a Sent 10DLC compliance packet (JSON) before filing "
            "with The Campaign Registry. Checks required fields, URL and EIN "
            "format, sample-message length, and opt-out language. See "
            "references/10dlc-evidence-checklist.md for the field-by-field "
            "rationale."
        ),
    )
    parser.add_argument("packet", help="Path to the packet JSON file")
    args = parser.parse_args(argv)

    path = args.packet

    try:
        with open(path, encoding="utf-8") as f:
            packet = json.load(f)
    except FileNotFoundError:
        print(f"{path}: <file>: not found", file=sys.stderr)
        return 1
    except json.JSONDecodeError as e:
        print(f"{path}: <file>: invalid JSON ({e})", file=sys.stderr)
        return 1
    except OSError as e:
        print(f"{path}: <file>: could not read ({e})", file=sys.stderr)
        return 1

    issues = validate(packet, path)
    if issues:
        for line in issues:
            print(line, file=sys.stderr)
        return 1

    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
