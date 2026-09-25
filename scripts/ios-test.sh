#!/usr/bin/env bash
# Runs the BrewlyKit package tests on the newest available iPhone simulator.
set -euo pipefail

cd "$(dirname "$0")/../ios/BrewlyKit"

SIMULATOR_ID=$(xcrun simctl list devices available --json | python3 -c '
import json, re, sys
runtimes = json.load(sys.stdin)["devices"]
def version(runtime):
    return [int(n) for n in re.findall(r"\d+", runtime.split("iOS")[-1])]
ios = sorted((r for r in runtimes if "iOS" in r), key=version, reverse=True)
for runtime in ios:
    for device in runtimes[runtime]:
        if device["name"].startswith("iPhone"):
            print(device["udid"])
            sys.exit(0)
sys.exit("No iPhone simulator available")
')

echo "Using simulator ${SIMULATOR_ID}"
xcodebuild -list

xcodebuild test \
    -scheme BrewlyKit-Package \
    -destination "id=${SIMULATOR_ID}" \
    -skipPackagePluginValidation \
    -quiet
