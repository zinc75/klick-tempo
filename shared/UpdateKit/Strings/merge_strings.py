#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Adds the texts of UpdateKit to the string catalog of an application.

    python3 -I merge_strings.py <path to Localizable.xcstrings>

The texts of the kit are looked up in the catalog of the application (the keys are the French texts), as the texts of the other kits are.
A key the catalog already has is left alone (its translation was chosen with the rest of the application); "Fermer" and "révision"
are the ones of the About panel and must be there already. The file keeps the style it has (Xcode's, or a script's).
"""
import json
import pathlib
import sys

fragment = json.loads((pathlib.Path(__file__).parent / "Localizable.fragment.json").read_text(encoding="utf-8"))
path = pathlib.Path(sys.argv[1])
catalog = json.loads(path.read_text(encoding="utf-8"))
strings = catalog["strings"]

added = 0
for key, translations in fragment.items():
    if key in strings:
        continue
    localizations = {"fr": {"stringUnit": {"state": "translated", "value": key}}}
    for language, value in translations.items():
        localizations[language] = {"stringUnit": {"state": "translated", "value": value}}
    strings[key] = {"localizations": dict(sorted(localizations.items()))}
    added += 1

for needed in ("Fermer", "révision"):
    if needed not in strings:
        sys.exit(f"missing in the catalog: {needed}")

# Xcode writes `"key" : value`; a catalog written by a script has `"key": value`. The file keeps the style it has.
colon = ": " if '"sourceLanguage": ' in path.read_text(encoding="utf-8") else " : "
path.write_text(json.dumps(catalog, indent=2, ensure_ascii=False, separators=(",", colon)) + "\n", encoding="utf-8")
print(f"{path}: {added} texts added, {len(fragment) - added} already there")
