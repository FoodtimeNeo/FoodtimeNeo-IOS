#!/usr/bin/env python3
"""Static boundary checks for the single-module Swift app.

This is a guardrail, not a compiler. Separate frameworks/packages can replace it
later; until then it rejects the most common layer violations by import and type
name. Keep the rules close to docs/ARCHITECTURE.md.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "Sources"

# (layer, forbidden imports, forbidden API/type names, explanation)
RULES = {
    "Domain": (
        ("SwiftUI", "UIKit", "Photos", "PhotosUI", "Security", "UserNotifications", "AVFoundation", "WebKit"),
        ("URLSession", "HTTPCookieStorage", "SecItem", "UNUserNotificationCenter", "APIClient", "Remote", "Keychain"),
        "Domain must stay independent of UI, networking, storage and system SDKs",
    ),
    "Data": (
        ("SwiftUI", "UIKit", "Photos", "PhotosUI", "UserNotifications", "AVFoundation", "WebKit"),
        ("View", "Screen", "ViewController", "UNUserNotificationCenter"),
        "Data adapts HTTP/storage and must not import presentation or notification UI",
    ),
    "Platform": (
        ("SwiftUI", "WebKit"),
        ("APIClient", "Remote", "URLSession"),
        "Platform adapts system capabilities and must not own business HTTP",
    ),
    "Features": (
        ("Photos", "PhotosUI", "Security", "UserNotifications", "AVFoundation", "WebKit"),
        ("URLSession", "HTTPCookieStorage", "SecItem", "Keychain", "APIClient", "Remote"),
        "Features must use Domain services and Platform adapters, not HTTP or storage directly",
    ),
    "SharedUI": (
        ("Photos", "PhotosUI", "Security", "UserNotifications", "AVFoundation", "WebKit"),
        ("URLSession", "HTTPCookieStorage", "SecItem", "Keychain", "APIClient", "Remote"),
        "SharedUI must remain presentational; no networking or storage",
    ),
}


def layer_of(path: Path) -> str | None:
    try:
        return path.relative_to(SOURCES).parts[0]
    except (ValueError, IndexError):
        return None


def main() -> int:
    if not SOURCES.is_dir():
        print(f"Architecture check failed: missing {SOURCES}", file=sys.stderr)
        return 1

    violations: list[str] = []
    swift_files = sorted(SOURCES.rglob("*.swift"))
    for file in swift_files:
        layer = layer_of(file)
        if layer not in RULES:
            continue
        text = file.read_text(encoding="utf-8")
        _, forbidden_names, explanation = RULES[layer]
        for name in forbidden_names:
            # Imports: `import Name`; type/API names: whole-token match.
            if any(
                line.strip() == f"import {name}" or line.strip().startswith(f"import {name}.")
                for line in text.splitlines()
            ) or (name.lower() == name and name in text):
                violations.append(f"{file.relative_to(ROOT)}: {layer} cannot use {name} ({explanation})")

        # Check type/API references explicitly so comments and prose do not
        # trigger them. Data owns networking; Platform owns KeychainStore.
        if layer != "Data":
            tokens = ["RemoteRepository", "APIClient", "URLSession(", "HTTPCookieStorage"]
            if layer in {"Domain", "Features", "SharedUI"}:
                tokens.append("KeychainStore")
            for token in tokens:
                if token in text:
                    violations.append(f"{file.relative_to(ROOT)}: {layer} cannot reference {token}")

    if violations:
        print("Architecture violations:", file=sys.stderr)
        for violation in violations:
            print(f" - {violation}", file=sys.stderr)
        return 1

    print(f"Architecture check passed: {len(swift_files)} Swift files scanned.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
