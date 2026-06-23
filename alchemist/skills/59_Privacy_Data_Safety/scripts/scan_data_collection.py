#!/usr/bin/env python3
"""scan_data_collection.py — Privacy data-collection scanner (skill #59).

Parses a Flutter project's pubspec.yaml (declared dependencies) and
AndroidManifest.xml (granted permissions), matches each against a built-in
knowledge table of data-collecting SDKs/permissions, and emits a list of
detected data-collecting SDKs and their likely Google Play Data Safety
categories. Can also read ios/Runner/Info.plist for usage strings (bonus).

Stdlib only — no network, no third-party packages. No YAML/XML parsers needed
outside the stdlib; the files are simple enough for a tolerant line parser.

Output: a text table, or JSON with --json.

Usage:
  python scan_data_collection.py <project-root>
  python scan_data_collection.py . --json
  python scan_data_collection.py \
      --pubspec pubspec.yaml --manifest android/app/src/main/AndroidManifest.xml
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from typing import Optional

# --------------------------------------------------------------------------- #
# Knowledge table: SDK / permission → Play data category
# --------------------------------------------------------------------------- #
# Each entry: (name, family, play_data_types, collected, shared, purposes,
#              tracking_implied, apple_datatype)
# play_data_types and purposes are joined with "/" in the table;
# tracking_implied means "typically implies NSPrivacyTracking=true".

@dataclass
class SDKEntry:
    name: str
    family: str               # Analytics, Crash, Ads, Auth, Location, Messaging, Payments, Media, StorageUtil, DeviceInfo
    play_data_types: list[str]
    collected: str            # Yes / No / If-sent-off-device
    shared: str               # Yes / No / Depends
    purposes: list[str]
    tracking_implied: bool
    apple_data_type: str      # colon-separated if multiple


@dataclass
class PermissionEntry:
    permission: str            # e.g. "android.permission.ACCESS_FINE_LOCATION"
    play_data_type: str
    collected_condition: str   # question to resolve
    tracking_implied: bool


# --- SDK knowledge table ---
SDK_TABLE: list[SDKEntry] = [
    # Analytics
    SDKEntry("firebase_analytics", "Analytics", ["App activity", "Device or other IDs"],
             "Yes", "No", ["Analytics"], False, "ProductInteraction::DeviceID"),
    SDKEntry("amplitude_flutter", "Analytics", ["App activity", "Device or other IDs"],
             "Yes", "No", ["Analytics"], False, "ProductInteraction::DeviceID"),
    SDKEntry("amplitude", "Analytics", ["App activity", "Device or other IDs"],
             "Yes", "No", ["Analytics"], False, "ProductInteraction::DeviceID"),
    SDKEntry("mixpanel_flutter", "Analytics", ["App activity", "Device or other IDs"],
             "Yes", "No", ["Analytics"], False, "ProductInteraction::DeviceID"),
    SDKEntry("mixpanel", "Analytics", ["App activity", "Device or other IDs"],
             "Yes", "No", ["Analytics"], False, "ProductInteraction::DeviceID"),
    SDKEntry("posthog_flutter", "Analytics", ["App activity", "Device or other IDs"],
             "Yes", "No", ["Analytics"], False, "ProductInteraction::DeviceID"),
    SDKEntry("posthog", "Analytics", ["App activity", "Device or other IDs"],
             "Yes", "No", ["Analytics"], False, "ProductInteraction::DeviceID"),
    SDKEntry("segment", "Analytics", ["App activity", "Device or other IDs"],
             "Yes", "No", ["Analytics"], False, "ProductInteraction::DeviceID"),
    SDKEntry("flutter_segment", "Analytics", ["App activity", "Device or other IDs"],
             "Yes", "No", ["Analytics"], False, "ProductInteraction::DeviceID"),

    # Crash / diagnostics
    SDKEntry("firebase_crashlytics", "Crash", ["App info & performance (Crash logs)", "App info & performance (Diagnostics)"],
             "Yes", "No", ["App functionality", "Analytics"], False, "CrashData"),
    SDKEntry("sentry_flutter", "Crash", ["App info & performance (Crash logs)", "App info & performance (Diagnostics)"],
             "Yes", "No", ["App functionality", "Analytics"], False, "CrashData"),
    SDKEntry("sentry", "Crash", ["App info & performance (Crash logs)", "App info & performance (Diagnostics)"],
             "Yes", "No", ["App functionality", "Analytics"], False, "CrashData"),

    # Performance
    SDKEntry("firebase_performance", "Performance", ["App info & performance"],
             "Yes", "No", ["Analytics", "App functionality"], False, "PerformanceData"),

    # Ads / attribution
    SDKEntry("google_mobile_ads", "Ads", ["Device or other IDs", "Location (Approximate)", "App activity"],
             "Yes", "Yes (shared with ad network)", ["Advertising or marketing", "Analytics"], True, "DeviceID::CoarseLocation::AdvertisingData"),
    SDKEntry("applovin_max", "Ads", ["Device or other IDs", "App activity"],
             "Yes", "Yes (shared)", ["Advertising or marketing"], True, "DeviceID::AdvertisingData"),
    SDKEntry("appsflyer_sdk", "Attribution", ["Device or other IDs", "App activity"],
             "Yes", "Yes (shared)", ["Advertising or marketing", "Analytics"], True, "DeviceID::AdvertisingData"),
    SDKEntry("appsflyer", "Attribution", ["Device or other IDs", "App activity"],
             "Yes", "Yes (shared)", ["Advertising or marketing", "Analytics"], True, "DeviceID::AdvertisingData"),
    SDKEntry("facebook_app_events", "Ads", ["Device or other IDs", "App activity"],
             "Yes", "Yes (shared)", ["Advertising or marketing", "Analytics"], True, "DeviceID::AdvertisingData"),
    SDKEntry("unity_ads", "Ads", ["Device or other IDs", "App activity"],
             "Yes", "Yes (shared)", ["Advertising or marketing"], True, "DeviceID::AdvertisingData"),
    SDKEntry("flutter_unity_ads", "Ads", ["Device or other IDs", "App activity"],
             "Yes", "Yes (shared)", ["Advertising or marketing"], True, "DeviceID::AdvertisingData"),
    SDKEntry("flutter_facebook_sdk", "Ads", ["Device or other IDs", "App activity"],
             "Yes", "Yes (shared)", ["Advertising or marketing", "Analytics"], True, "DeviceID::AdvertisingData"),

    # Auth / identity
    SDKEntry("firebase_auth", "Auth", ["Personal info (Email, Name, User IDs)"],
             "Yes", "No", ["Account management", "App functionality"], False, "EmailAddress::Name::UserID"),
    SDKEntry("google_sign_in", "Auth", ["Personal info (Email, Name)"],
             "Yes", "No", ["Account management"], False, "EmailAddress::Name"),
    SDKEntry("sign_in_with_apple", "Auth", ["Personal info (Email, Name)"],
             "Yes", "No", ["Account management"], False, "EmailAddress::Name"),
    SDKEntry("supabase_flutter", "Auth", ["Personal info (Email, Name, User IDs)"],
             "Yes", "No", ["Account management", "App functionality"], False, "EmailAddress::Name::UserID"),

    # Location
    SDKEntry("geolocator", "Location", ["Location (Precise or Approximate)"],
             "If sent off-device", "Depends", ["App functionality"], False, "PreciseLocation::CoarseLocation"),
    SDKEntry("location", "Location", ["Location (Precise or Approximate)"],
             "If sent off-device", "Depends", ["App functionality"], False, "PreciseLocation::CoarseLocation"),
    SDKEntry("google_maps_flutter", "Location", ["Location (Approximate)"],
             "Yes (sent to Maps API)", "No (Maps API)", ["App functionality"], False, "CoarseLocation"),
    SDKEntry("flutter_map", "Location", ["Location (Approximate)"],
             "If sent off-device", "Depends", ["App functionality"], False, "CoarseLocation"),

    # Messaging / push
    SDKEntry("firebase_messaging", "Messaging", ["Device or other IDs"],
             "Yes", "No", ["App functionality", "Developer communications"], False, "DeviceID"),
    SDKEntry("onesignal_flutter", "Messaging", ["Device or other IDs", "App activity"],
             "Yes", "No", ["App functionality", "Developer communications"], False, "DeviceID"),

    # Payments
    SDKEntry("in_app_purchase", "Payments", ["Financial info (Purchase history)"],
             "Yes", "No (processor)", ["App functionality", "Account management"], False, "PurchaseHistory::PaymentInfo"),
    SDKEntry("flutter_stripe", "Payments", ["Financial info (Payment info, Purchase history)"],
             "Yes", "No (processor)", ["App functionality"], False, "PaymentInfo::PurchaseHistory"),
    SDKEntry("purchases_flutter", "Payments", ["Financial info (Purchase history)"],
             "Yes", "No (processor)", ["App functionality", "Account management"], False, "PurchaseHistory"),
    SDKEntry("revenue_cat", "Payments", ["Financial info (Purchase history)"],
             "Yes", "No (processor)", ["App functionality", "Account management"], False, "PurchaseHistory"),

    # Media / files
    SDKEntry("image_picker", "Media", ["Photos and videos"],
             "Only if uploaded", "No", ["App functionality"], False, "Photos"),
    SDKEntry("camera", "Media", ["Photos and videos"],
             "Only if uploaded", "No", ["App functionality"], False, "Photos"),
    SDKEntry("file_picker", "Media", ["Files and docs"],
             "Only if uploaded", "No", ["App functionality"], False, "OtherUserContent"),

    # Contacts
    SDKEntry("contacts_service", "Contacts", ["Contacts"],
             "Only if uploaded/synced", "Depends", ["App functionality"], False, "Contacts"),
    SDKEntry("flutter_contacts", "Contacts", ["Contacts"],
             "Only if uploaded/synced", "Depends", ["App functionality"], False, "Contacts"),

    # Health / sensors
    SDKEntry("health", "Health", ["Health and fitness"],
             "If sent off-device", "No", ["App functionality"], False, "HealthData"),
    SDKEntry("health_fitness", "Health", ["Health and fitness"],
             "If sent off-device", "No", ["App functionality"], False, "HealthData"),
    SDKEntry("sensors_plus", "Sensors", ["(sensor data — no standard type)"],
             "If sent off-device", "No", ["App functionality"], False, ""),

    # Device info (only collecting if sent)
    SDKEntry("device_info_plus", "DeviceInfo", ["Device or other IDs (if sent)"],
             "If sent", "No", ["Analytics"], False, "DeviceID"),
    SDKEntry("package_info_plus", "DeviceInfo", ["Device or other IDs (if sent)"],
             "If sent", "No", ["Analytics"], False, "DeviceID"),
]

# --- Permission knowledge table ---
PERMISSION_TABLE: list[PermissionEntry] = [
    PermissionEntry("ACCESS_FINE_LOCATION", "Location (Precise)",
                    "Is precise location sent to backend/maps/ads SDK?", False),
    PermissionEntry("ACCESS_COARSE_LOCATION", "Location (Approximate)",
                    "Is approximate location sent to backend/maps/ads SDK?", False),
    PermissionEntry("ACCESS_BACKGROUND_LOCATION", "Location (Background)",
                    "Is background location collected & sent? Requires strong justification.", False),
    PermissionEntry("CAMERA", "Photos and videos",
                    "Are captured photos/videos uploaded off-device or shared?", False),
    PermissionEntry("RECORD_AUDIO", "Audio (Voice or sound recordings)",
                    "Is audio captured and sent off-device?", False),
    PermissionEntry("READ_CONTACTS", "Contacts",
                    "Are contacts uploaded/synced to a server?", False),
    PermissionEntry("READ_EXTERNAL_STORAGE", "Files and docs; Photos and videos",
                    "Are files/photos read from storage and uploaded?", False),
    PermissionEntry("READ_MEDIA_IMAGES", "Photos and videos",
                    "Are photos read from storage and uploaded?", False),
    PermissionEntry("READ_MEDIA_VIDEO", "Photos and videos (Videos)",
                    "Are videos read from storage and uploaded?", False),
    PermissionEntry("READ_MEDIA_AUDIO", "Files and docs (Audio files)",
                    "Are audio files read from storage and uploaded?", False),
    PermissionEntry("READ_PHONE_STATE", "Phone number; Device or other IDs",
                    "Is phone state/device IDs read & sent? Rarely needed — must justify.", False),
    PermissionEntry("BODY_SENSORS", "Health and fitness",
                    "Is body-sensor data sent off-device?", False),
    PermissionEntry("BLUETOOTH_CONNECT", "(context-specific — review manually)",
                    "What data is read & sent over Bluetooth?", False),
    PermissionEntry("POST_NOTIFICATIONS", "(capability only — no data type)",
                    "(no data type)", False),
    PermissionEntry("com.google.android.gms.permission.AD_ID", "Device or other IDs (Advertising ID)",
                    "Ad ID permission present — likely used by an ads/analytics SDK", True),
]

# --- Storage/utility plugins that trigger Apple required-reason APIs ---
REQUIRED_REASON_PLUGINS: dict[str, list[tuple[str, str]]] = {
    "shared_preferences": [("NSPrivacyAccessedAPICategoryUserDefaults", "CA92.1")],
    "path_provider": [("NSPrivacyAccessedAPICategoryFileTimestamp", "C617.1")],
    "sqflite": [("NSPrivacyAccessedAPICategoryFileTimestamp", "C617.1")],
    "hive": [("NSPrivacyAccessedAPICategoryFileTimestamp", "C617.1")],
    "hive_flutter": [("NSPrivacyAccessedAPICategoryFileTimestamp", "C617.1")],
    "device_info_plus": [("NSPrivacyAccessedAPICategorySystemBootTime", "35F9.1")],
    "package_info_plus": [("NSPrivacyAccessedAPICategorySystemBootTime", "35F9.1")],
}


# --------------------------------------------------------------------------- #
# File parsing (tolerant line parsers — no PyYAML)
# --------------------------------------------------------------------------- #
def find_project_root(path: str) -> str:
    """Return the project root given a path (file or directory)."""
    path = os.path.abspath(path)
    if os.path.isfile(path):
        return os.path.dirname(path)
    return path


def parse_dependency_names(pubspec_path: str) -> list[str]:
    """Return all declared dependency names from pubspec.yaml.

    Reads the `dependencies:` and `dev_dependencies:` blocks. Skips flutter SDK
    pseudo-deps and git/path/sdk-sourced entries.
    """
    try:
        with open(pubspec_path, "r", encoding="utf-8") as fh:
            text = fh.read()
    except FileNotFoundError:
        print(f"[warn] pubspec.yaml not found at {pubspec_path}", file=sys.stderr)
        return []
    except OSError as e:
        print(f"[warn] cannot read {pubspec_path}: {e}", file=sys.stderr)
        return []

    names: list[str] = []
    section: Optional[str] = None
    skip = {"flutter", "flutter_test", "flutter_localizations", "flutter_web_plugins"}
    lines = text.splitlines()
    for i, raw in enumerate(lines):
        line = raw.rstrip()
        if not line or line.lstrip().startswith("#"):
            continue
        # top-level key
        if re.match(r"^[A-Za-z_]", line):
            key = line.split(":", 1)[0].strip()
            section = key if key in ("dependencies", "dev_dependencies") else None
            continue
        if section is None:
            continue
        m = re.match(r"^\s{2}([A-Za-z0-9_]+)\s*:(.*)$", raw)
        if not m:
            continue
        name = m.group(1)
        rest = m.group(2).strip()
        if name in skip:
            continue
        # nested git/path/sdk source
        if rest == "" and i + 1 < len(lines):
            nxt = lines[i + 1].strip()
            if nxt.startswith(("git:", "path:", "sdk:", "hosted:")):
                continue
        if rest.startswith(("git", "path", "sdk", "{")):
            continue
        if name not in names:
            names.append(name)
    return names


def _perm_name(full: str) -> str:
    """Return the last segment of a permission name (after the final dot)."""
    return full.rsplit(".", 1)[-1] if "." in full else full


def parse_permissions(manifest_path: str) -> list[str]:
    """Return permission names from AndroidManifest.xml <uses-permission> tags.

    Returns the last-segment short names (e.g. ACCESS_FINE_LOCATION), falling
    back to the full name if unparseable.
    """
    try:
        tree = ET.parse(manifest_path)
        root = tree.getroot()
    except FileNotFoundError:
        print(f"[warn] AndroidManifest.xml not found at {manifest_path}", file=sys.stderr)
        return []
    except ET.ParseError as e:
        print(f"[warn] XML parse error in {manifest_path}: {e}", file=sys.stderr)
        # fallback: regex-based extraction
        try:
            with open(manifest_path, "r", encoding="utf-8") as fh:
                text = fh.read()
            perms = re.findall(
                r'<uses-permission\s+android:name="([^"]+)"',
                text,
                re.IGNORECASE,
            )
            return [p.rsplit(".", 1)[-1] for p in perms]
        except OSError:
            return []
    except OSError as e:
        print(f"[warn] cannot read {manifest_path}: {e}", file=sys.stderr)
        return []

    ns = "http://schemas.android.com/apk/res/android"
    perms: list[str] = []
    for elem in root.iter("uses-permission"):
        full = elem.get(f"{{{ns}}}name", "")
        if full:
            perms.append(full)
    return [_perm_name(p) for p in perms]


# --------------------------------------------------------------------------- #
# Matching
# --------------------------------------------------------------------------- #
@dataclass
class Finding:
    source: str           # "pubspec" or "permission"
    name: str
    family: str           # SDK family or "Permission"
    play_data_types: list[str]
    collected: str
    shared: str
    purposes: list[str]
    tracking_implied: bool
    apple_data_types: list[str] = field(default_factory=list)
    note: str = ""        # for "review manually" or extra context

    def to_dict(self) -> dict:
        return {
            "source": self.source,
            "name": self.name,
            "family": self.family,
            "play_data_types": self.play_data_types,
            "collected": self.collected,
            "shared": self.shared,
            "purposes": self.purposes,
            "tracking_implied": self.tracking_implied,
            "apple_data_types": self.apple_data_types,
            "note": self.note,
        }


def match_sdks(dep_names: list[str]) -> tuple[list[Finding], list[str]]:
    """Match declared deps against SDK_TABLE. Returns (findings, unknown_names)."""
    sdk_lookup: dict[str, SDKEntry] = {e.name: e for e in SDK_TABLE}
    findings: list[Finding] = []
    unknown: list[str] = []

    for name in dep_names:
        entry = sdk_lookup.get(name)
        if entry is None:
            unknown.append(name)
            continue
        findings.append(Finding(
            source="pubspec",
            name=name,
            family=entry.family,
            play_data_types=list(entry.play_data_types),
            collected=entry.collected,
            shared=entry.shared,
            purposes=list(entry.purposes),
            tracking_implied=entry.tracking_implied,
            apple_data_types=entry.apple_data_type.split("::") if entry.apple_data_type else [],
        ))
    return findings, unknown


def match_permissions(perm_names: list[str]) -> tuple[list[Finding], list[str]]:
    """Match permissions against PERMISSION_TABLE."""
    perm_lookup: dict[str, PermissionEntry] = {_perm_name(e.permission): e for e in PERMISSION_TABLE}
    # also index by short-prefix matches
    findings: list[Finding] = []
    unknown: list[str] = []

    for name in perm_names:
        entry = perm_lookup.get(name)
        if entry is None:
            unknown.append(name)
            continue
        findings.append(Finding(
            source="permission",
            name=name,
            family="Permission",
            play_data_types=[entry.play_data_type],
            collected=entry.collected_condition,
            shared="Review — depends on implementation",
            purposes=["App functionality"],
            tracking_implied=entry.tracking_implied,
            note=f"Permission grants capability, not proof of collection. Resolve: {entry.collected_condition}",
        ))
    return findings, unknown


def find_required_reason_apis(dep_names: list[str]) -> dict[str, list[tuple[str, str]]]:
    """Return plugins from dep_names that trigger Apple required-reason APIs."""
    triggered: dict[str, list[tuple[str, str]]] = {}
    for name in dep_names:
        if name in REQUIRED_REASON_PLUGINS:
            triggered[name] = REQUIRED_REASON_PLUGINS[name]
    return triggered


# --------------------------------------------------------------------------- #
# Output formatting
# --------------------------------------------------------------------------- #
def fmt_table(findings: list[Finding], unknown_sdks: list[str],
              unknown_perms: list[str], required_reason: dict,
              pkgs_total: int) -> str:
    """Format findings as a human-readable text table."""
    lines: list[str] = []
    lines.append("=" * 80)
    lines.append("  Data Collection Scanner — Privacy Report (#59)")
    lines.append("=" * 80)
    lines.append(f"  Packages scanned:  {pkgs_total} declared deps")
    lines.append(f"  SDK hits:          {len(findings)} detected data-collecting SDKs/permissions")
    lines.append(f"  Unknown SDKs:      {len(unknown_sdks)} review-manually entries")
    lines.append(f"  Unknown perms:     {len(unknown_perms)} review-manually entries")
    lines.append(f"  Required-reason:   {len(required_reason)} plugins trigger Apple APIs")
    lines.append("")

    if not findings and not unknown_sdks and not unknown_perms:
        lines.append("  No data-collecting SDKs or sensitive permissions detected.")
        lines.append("  Verify: does your code collect data no SDK reveals (forms, file uploads)?")
        return "\n".join(lines)

    lines.append("-" * 80)
    lines.append(f"  {'Name':<28} {'Family':<14} {'Play data type(s)':<42} {'Collected':<24} {'Shared':<12} {'Tracking':>8}")
    lines.append("-" * 80)

    for f in findings:
        data_types = " / ".join(f.play_data_types)
        lines.append(
            f"  {f.name:<28} {f.family:<14} {data_types:<42} {f.collected:<24} {f.shared:<12} {'Yes' if f.tracking_implied else 'No':>8}"
        )

    if unknown_sdks:
        lines.append("")
        lines.append("--- UNKNOWN SDKs (review manually) ---")
        for name in sorted(unknown_sdks):
            lines.append(f"  {name}")

    if unknown_perms:
        lines.append("")
        lines.append("--- UNKNOWN PERMISSIONS (review manually) ---")
        for name in sorted(unknown_perms):
            lines.append(f"  {name}")

    if required_reason:
        lines.append("")
        lines.append("--- APPLE REQUIRED-REASON APIs ---")
        for plugin, apis in sorted(required_reason.items()):
            for cat, reason in apis:
                lines.append(f"  {plugin}  ->  {cat}  (reason: {reason})")

    lines.append("")
    lines.append("  [advisor] Every line is a default prior — verify against real behavior.")
    lines.append("  [advisor] Permissions grant capability, not proof of collection.")
    lines.append("  [advisor] Unknown SDKs: look up vendor data practices; don't assume 'none'.")
    return "\n".join(lines)


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #
def main() -> None:
    parser = argparse.ArgumentParser(
        description="scan_data_collection.py — Privacy data-collection scanner (skill #59)",
    )
    parser.add_argument(
        "root",
        nargs="?",
        default=".",
        help="Project root directory (default .)",
    )
    parser.add_argument(
        "--pubspec",
        default=None,
        help="Path to pubspec.yaml (overrides project-root guess)",
    )
    parser.add_argument(
        "--manifest",
        default=None,
        help="Path to AndroidManifest.xml (overrides project-root guess)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit JSON instead of a text table",
    )
    args = parser.parse_args()

    root = find_project_root(args.root)
    pubspec_path = args.pubspec or os.path.join(root, "pubspec.yaml")
    manifest_path = args.manifest or os.path.join(
        root, "android", "app", "src", "main", "AndroidManifest.xml"
    )

    # Parse
    dep_names = parse_dependency_names(pubspec_path)
    perm_names = parse_permissions(manifest_path)

    # Match
    sdk_findings, unknown_sdks = match_sdks(dep_names)
    perm_findings, unknown_perms = match_permissions(perm_names)
    all_findings = sdk_findings + perm_findings
    rr_apis = find_required_reason_apis(dep_names)

    # Output
    if args.json:
        output = {
            "skill": "59_Privacy_Data_Safety",
            "packages_scanned": len(dep_names),
            "permissions_scanned": len(perm_names),
            "findings": [f.to_dict() for f in all_findings],
            "unknown_sdks": sorted(unknown_sdks),
            "unknown_permissions": sorted(unknown_perms),
            "apple_required_reason_apis": {
                plugin: [{"category": cat, "reason": reason} for cat, reason in apis]
                for plugin, apis in sorted(rr_apis.items())
            },
            "tracking_implied": any(f.tracking_implied for f in all_findings),
        }
        print(json.dumps(output, indent=2))
    else:
        print(fmt_table(all_findings, unknown_sdks, unknown_perms, rr_apis, len(dep_names)))


if __name__ == "__main__":
    main()
