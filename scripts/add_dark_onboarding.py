#!/usr/bin/env python3
"""Copy dark-mode frames into each onboarding imageset and update Contents.json."""

import json
import shutil
from pathlib import Path

ASSETS = Path(r"d:\Notyfi\Resources\Assets.xcassets")
SOURCE_BASE = Path(r"G:\Stuff\Apps\Notyfi misc\Onboarding Elements")

PAGES = [
    ("Budget-page",       "mascot-budget-f"),
    ("Currency-page",     "mascot-currency-f"),
    ("Notification-page", "mascot-notifications-f"),
    ("Welcome-page",      "mascot-welcome-f"),
    ("Save-page",         "mascot-auth-f"),
    ("NoCategory-page",   "mascot-allocate-empty-f"),
]

DARK_CONTENTS_ENTRY = [
    {
        "appearances": [{"appearance": "luminosity", "value": "dark"}],
        "filename": "",   # filled in per frame
        "idiom": "universal",
        "scale": "1x"
    },
    {
        "appearances": [{"appearance": "luminosity", "value": "dark"}],
        "idiom": "universal",
        "scale": "2x"
    },
    {
        "appearances": [{"appearance": "luminosity", "value": "dark"}],
        "idiom": "universal",
        "scale": "3x"
    },
]

for page_folder, asset_prefix in PAGES:
    dark_dir = SOURCE_BASE / page_folder / "Dark mode"
    for frame in range(1, 5):
        src = dark_dir / f"{frame}-dark.png"
        imageset_dir = ASSETS / f"{asset_prefix}{frame}.imageset"
        dark_filename = f"{asset_prefix}{frame}-dark.png"
        dest = imageset_dir / dark_filename

        # Copy image
        shutil.copy2(src, dest)

        # Update Contents.json
        contents_path = imageset_dir / "Contents.json"
        with open(contents_path, encoding="utf-8") as f:
            data = json.load(f)

        # Remove any existing dark entries so we don't duplicate
        data["images"] = [
            img for img in data["images"]
            if not img.get("appearances")
        ]

        # Append fresh dark entries
        dark_entries = json.loads(json.dumps(DARK_CONTENTS_ENTRY))  # deep copy
        dark_entries[0]["filename"] = dark_filename
        data["images"].extend(dark_entries)

        with open(contents_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)

        print(f"  {asset_prefix}{frame}: copied + updated")

print("Done.")
