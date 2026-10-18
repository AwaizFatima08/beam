#!/usr/bin/env bash
# Refuses a release while Beam still carries Google's sample AdMob ids
# (they serve "Test Ad" creatives, earn nothing and look broken to reviewers).
# Run before every `flutter build appbundle --release`.
set -euo pipefail
cd "$(dirname "$0")/.."
SAMPLE="ca-app-pub-3940256099942544"
fail=0

release_block=$(awk '/static const release = AdUnitIds\(/,/\);/' lib/ads/ad_ids.dart)
if echo "$release_block" | grep -q "$SAMPLE"; then
  echo "FAIL: lib/ads/ad_ids.dart (AdUnitIds.release) still uses sample ad unit ids"; fail=1
fi
for unit in banner interstitial rewarded; do
  if ! echo "$release_block" | grep -Eq "$unit: 'ca-app-pub-[0-9]{16}/[0-9]{10}'"; then
    echo "FAIL: AdUnitIds.release.$unit is missing or malformed"; fail=1
  fi
done

release_app=$(awk '/release \{/,/\}/' android/app/build.gradle.kts | grep 'admobAppId' || true)
if [ -z "$release_app" ]; then
  echo "FAIL: no admobAppId set for the release build type"; fail=1
elif echo "$release_app" | grep -q "$SAMPLE"; then
  echo "FAIL: android/app/build.gradle.kts release admobAppId is still the sample app id"; fail=1
elif ! echo "$release_app" | grep -Eq 'ca-app-pub-[0-9]{16}~[0-9]{10}'; then
  echo "FAIL: release admobAppId is malformed"; fail=1
fi

if [ $fail -eq 0 ]; then echo "PASS: release ad ids are Beam's own"; fi
exit $fail
