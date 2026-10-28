#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Usage: $0 <temporary-parent-directory> [source-root]" >&2
    exit 2
fi

test_dir=$(cd "$(dirname "$0")" && pwd)
source_root=${2:-"$test_dir/.."}
mkdir -p "$1"
scratch=$(mktemp -d "$1/knockknock-tests.XXXXXX")
echo "Test artifacts: $scratch"
status=0

for optimization in 0 2; do
    binary="$scratch/memory-tests-O$optimization"
    xcrun clang -fobjc-arc -fmodules -O"$optimization" -Wno-deprecated-declarations \
        -fmodules-cache-path="$scratch/modules" \
        -include "$source_root/KnockKnock-Prefix.pch" -I "$source_root" \
        "$test_dir/MemoryTests.m" "$source_root/utilities.m" \
        "$source_root/Libraries/MachO/MachO.m" \
        -framework Cocoa -framework Security -framework SystemConfiguration \
        -framework CoreServices -framework Collaboration -framework UniformTypeIdentifiers \
        -o "$binary"
    for mode in correctness parse-memory hash-memory; do
        echo "Running -O$optimization $mode"
        if ! "$binary" "$mode" "$scratch"; then
            status=1
        fi
    done
done
exit "$status"
