#!/bin/sh

set -e

# Define targets
TARGETS="
x86_64-linux-musl
aarch64-linux-musl
"

# Clean releases folder
rm -rf releases
mkdir -p releases

for TARGET in $TARGETS; do
    echo "Building for $TARGET..."
    zig build -Doptimize=ReleaseSafe -Dtarget=$TARGET -p releases/$TARGET
done

echo "Done! Binaries are in releases/"
