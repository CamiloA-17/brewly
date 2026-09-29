#!/usr/bin/env python3
"""Check that every translated catalog row has a Spanish iOS string."""

import json
import os
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "ios/BrewlyKit/Sources/BrewlyDesignSystem/Resources"
CATALOGS = {
    "brew_methods": "CatalogMethods.xcstrings",
    "processing_methods": "CatalogProcesses.xcstrings",
    "flavor_notes": "CatalogFlavorNotes.xcstrings",
    "varietals": "CatalogVarietals.xcstrings",
}


def catalog_names(table: str, database_url: str) -> list[str]:
    sql = f"SELECT coalesce(json_agg(name ORDER BY name), '[]'::json) FROM {table}"
    result = subprocess.run(
        ["psql", database_url, "--no-psqlrc", "--tuples-only", "--no-align", "-v", "ON_ERROR_STOP=1", "-c", sql],
        capture_output=True,
        check=True,
        text=True,
    )
    return json.loads(result.stdout.strip())


def main() -> int:
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        print("DATABASE_URL is required", file=sys.stderr)
        return 2

    errors = []
    for table, file_name in CATALOGS.items():
        entries = json.loads((RESOURCES / file_name).read_text())["strings"]
        names = catalog_names(table, database_url)
        for name in names:
            unit = entries.get(name, {}).get("localizations", {}).get("es", {}).get("stringUnit", {})
            if unit.get("state") != "translated" or not unit.get("value", "").strip():
                errors.append(f"{table}: missing Spanish translation for {name!r}")
        print(f"{table}: {len(names)} names checked")

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
