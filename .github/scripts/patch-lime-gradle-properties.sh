#!/bin/bash
# patch-lime-gradle-properties.sh - Adds Gradle performance flags (parallel
# module execution, build cache, more daemon heap) to Lime's Android
# template gradle.properties. Neither this project's nor NightmareVision's
# workflow tunes this today -- Gradle's own dexing/packaging phase runs with
# whatever defaults ship in Lime's template otherwise.
set -euo pipefail

GRADLE_PROPERTIES=".haxelib/lime/git/templates/android/template/gradle.properties"
if [ ! -f "$GRADLE_PROPERTIES" ]; then
    GRADLE_PROPERTIES=$(find .haxelib/lime/git/templates/android -maxdepth 2 -name "gradle.properties" | head -1)
fi
[ -z "$GRADLE_PROPERTIES" ] && echo "Lime Android gradle.properties not found" && exit 1

echo "[INFO] Found: $GRADLE_PROPERTIES"

# .haxelib/lime is one cache shared across all three jobs (fat/arm64/arm32)
# -- reset to Lime's own committed version first, same reasoning as
# patch-lime-gradle.sh's own reset: without it, whichever job last patched
# and saved the cache would leak its jvmargs/etc into what the other jobs
# restore next run.
REL_PATH="${GRADLE_PROPERTIES#.haxelib/lime/git/}"
git -C .haxelib/lime/git checkout -- "$REL_PATH" 2>/dev/null || true

# Drop any of our own flags left over from a previous run against this same
# restored file, then append fresh -- avoids duplicate/conflicting lines if
# this script ever runs more than once in a job.
sed -i '/^org\.gradle\.parallel=/d;/^org\.gradle\.caching=/d;/^org\.gradle\.jvmargs=/d' "$GRADLE_PROPERTIES"

cat >> "$GRADLE_PROPERTIES" << 'EOF'
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.jvmargs=-Xmx4g -XX:+UseParallelGC
EOF

echo "[INFO] Done! Added Gradle performance flags to $GRADLE_PROPERTIES"
