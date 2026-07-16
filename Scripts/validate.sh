#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Validating Package.swift"
swift package dump-package >/dev/null

echo "==> Running portable package tests"
swift test

echo "==> Linting Swift source"
swift-format lint --recursive Sources Tests Examples/Demo/Demo Examples/Demo/DemoTests

echo "==> Validating plist, JSON, and YAML files"
python3 - <<'PY'
import json
import pathlib
import plistlib
import sys

root = pathlib.Path.cwd()

with (root / "Examples/Demo/Demo/PrivacyInfo.xcprivacy").open("rb") as handle:
    manifest = plistlib.load(handle)
assert manifest["NSPrivacyTracking"] is False
assert isinstance(manifest["NSPrivacyCollectedDataTypes"], list)
assert isinstance(manifest["NSPrivacyAccessedAPITypes"], list)

for path in root.rglob("*.json"):
    with path.open("r", encoding="utf-8") as handle:
        json.load(handle)

with (root / "Examples/Demo/Demo/Configuration.storekit").open("r", encoding="utf-8") as handle:
    storekit = json.load(handle)
product_ids = {
    product["productID"]
    for group in storekit["subscriptionGroups"]
    for product in group["subscriptions"]
}
assert product_ids == {
    "com.hoangbkit.demo.pro.monthly",
    "com.hoangbkit.demo.pro.yearly",
}

try:
    import yaml
except ImportError:
    yaml = None

project_text = (root / "Examples/Demo/project.yml").read_text(encoding="utf-8")
for required in (
    "com.hoangbkit.demo",
    "J458WW3452",
    'deploymentTarget: "26.0"',
    "path: ../..",
):
    assert required in project_text, required

if yaml is not None:
    with (root / "Examples/Demo/project.yml").open("r", encoding="utf-8") as handle:
        yaml.safe_load(handle)

print("Static artifact validation passed")
PY

echo "==> Validation complete"
echo "Note: XcodeGen generation and iOS simulator builds require macOS with Xcode 26."
