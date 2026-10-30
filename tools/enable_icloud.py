#!/usr/bin/env python3
"""Fügt die iCloud-Entitlements in project.yml ein. Läuft im Release-Workflow, wenn iCloud aktiviert ist.
Voraussetzung: Container iCloud.de.nicosellmaier.form im Developer-Portal angelegt und der App-ID zugewiesen (docs/TESTFLIGHT.md)."""
p = "project.yml"
s = open(p).read()
marker = "        com.apple.security.application-groups:\n          - group.de.nicosellmaier.form\n    settings:\n      base:\n        PRODUCT_BUNDLE_IDENTIFIER: de.nicosellmaier.form\n"
add = """        com.apple.security.application-groups:
          - group.de.nicosellmaier.form
        com.apple.developer.icloud-container-identifiers:
          - iCloud.de.nicosellmaier.form
        com.apple.developer.icloud-services:
          - CloudDocuments
        com.apple.developer.ubiquity-container-identifiers:
          - iCloud.de.nicosellmaier.form
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: de.nicosellmaier.form
"""
assert marker in s, "Stelle in project.yml nicht gefunden"
open(p, "w").write(s.replace(marker, add, 1))
print("iCloud-Entitlements eingefügt")
