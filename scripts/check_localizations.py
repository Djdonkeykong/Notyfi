#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent

APP_LOCALIZATIONS_ROOT = REPO_ROOT / "Resources"
WIDGET_LOCALIZATIONS_ROOT = REPO_ROOT / "NotyfiWidget"

APP_SOURCE_DIRS = [
    "App",
    "Components",
    "Core",
    "DesignSystem",
    "Features",
    "Models",
    "Services",
    "Shared",
    "ViewModels",
]
WIDGET_SOURCE_DIRS = ["NotyfiWidget"]

STRING_ENTRY_PATTERN = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";\s*$')
NOTYFI_LOCALIZED_PATTERN = re.compile(r'"((?:[^"\\]|\\.)*)"\.notyfiLocalized')
NSLOCALIZED_STRING_PATTERN = re.compile(r'NSLocalizedString\(\s*"((?:[^"\\]|\\.)*)"')


def decode_swift_string(value: str) -> str:
    decoded: list[str] = []
    index = 0

    while index < len(value):
        char = value[index]
        if char != "\\":
            decoded.append(char)
            index += 1
            continue

        index += 1
        if index >= len(value):
            decoded.append("\\")
            break

        escape = value[index]
        index += 1

        simple_escapes = {
            '"': '"',
            "\\": "\\",
            "n": "\n",
            "r": "\r",
            "t": "\t",
        }
        if escape in simple_escapes:
            decoded.append(simple_escapes[escape])
            continue

        if escape in {"u", "U"}:
            hex_length = 4 if escape == "u" else 4
            hex_value = value[index : index + hex_length]
            if len(hex_value) == hex_length and all(c in "0123456789abcdefABCDEF" for c in hex_value):
                decoded.append(chr(int(hex_value, 16)))
                index += hex_length
                continue

        # Preserve unknown or malformed escapes so the checker can keep scanning.
        decoded.append("\\")
        decoded.append(escape)

    return "".join(decoded)


def parse_strings_file(path: Path) -> tuple[dict[str, str], list[str]]:
    entries: dict[str, str] = {}
    duplicates: list[str] = []

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("//") or line.startswith("/*") or line.startswith("*") or line.startswith("*/"):
            continue

        match = STRING_ENTRY_PATTERN.match(raw_line)
        if not match:
            continue

        key = decode_swift_string(match.group(1))
        value = decode_swift_string(match.group(2))

        if key in entries:
            duplicates.append(key)
            continue

        entries[key] = value

    return entries, duplicates


def collect_locale_maps(root: Path) -> tuple[dict[str, dict[str, str]], dict[str, list[str]]]:
    locales: dict[str, dict[str, str]] = {}
    duplicates_by_locale: dict[str, list[str]] = {}

    for locale_dir in sorted(root.glob("*.lproj")):
        strings_path = locale_dir / "Localizable.strings"
        if not strings_path.exists():
            continue

        locale = locale_dir.stem
        entries, duplicates = parse_strings_file(strings_path)
        locales[locale] = entries
        if duplicates:
            duplicates_by_locale[locale] = duplicates

    return locales, duplicates_by_locale


def scan_source_keys(relative_dirs: list[str]) -> set[str]:
    keys: set[str] = set()

    for relative_dir in relative_dirs:
        source_root = REPO_ROOT / relative_dir
        if not source_root.exists():
            continue

        for swift_path in source_root.rglob("*.swift"):
            content = swift_path.read_text(encoding="utf-8")

            for pattern in (NOTYFI_LOCALIZED_PATTERN, NSLOCALIZED_STRING_PATTERN):
                for match in pattern.finditer(content):
                    keys.add(decode_swift_string(match.group(1)))

    return keys


def compare_locales(
    label: str,
    locales: dict[str, dict[str, str]],
    baseline_locale: str,
    referenced_keys: set[str],
) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    baseline = locales.get(baseline_locale)
    if baseline is None:
        errors.append(f"{label}: missing baseline locale '{baseline_locale}'.")
        return errors, warnings

    for key in sorted(referenced_keys - baseline.keys()):
        errors.append(f"{label}: English is missing source key '{key}'.")

    baseline_keys = set(baseline.keys())

    for locale, entries in sorted(locales.items()):
        if locale == baseline_locale:
            continue

        missing_keys = sorted(baseline_keys - entries.keys())
        extra_keys = sorted(entries.keys() - baseline_keys)

        for key in missing_keys:
            warnings.append(f"{label}: locale '{locale}' is missing key '{key}'.")
        for key in extra_keys:
            warnings.append(f"{label}: locale '{locale}' has extra key '{key}' not present in English.")

    return errors, warnings


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    app_locales, app_duplicates = collect_locale_maps(APP_LOCALIZATIONS_ROOT)
    widget_locales, widget_duplicates = collect_locale_maps(WIDGET_LOCALIZATIONS_ROOT)

    for locale, duplicates in sorted(app_duplicates.items()):
        for key in duplicates:
            errors.append(f"App localizations: locale '{locale}' has duplicate key '{key}'.")

    for locale, duplicates in sorted(widget_duplicates.items()):
        for key in duplicates:
            errors.append(f"Widget localizations: locale '{locale}' has duplicate key '{key}'.")

    app_referenced_keys = scan_source_keys(APP_SOURCE_DIRS)
    widget_referenced_keys = scan_source_keys(WIDGET_SOURCE_DIRS)

    app_errors, app_warnings = compare_locales("App localizations", app_locales, "en", app_referenced_keys)
    widget_errors, widget_warnings = compare_locales("Widget localizations", widget_locales, "en", widget_referenced_keys)

    errors.extend(app_errors)
    errors.extend(widget_errors)
    warnings.extend(app_warnings)
    warnings.extend(widget_warnings)

    if errors:
        print("Localization check failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    if warnings:
        print("Localization check warnings:")
        for warning in warnings:
            print(f"- {warning}")

    print("Localization check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
