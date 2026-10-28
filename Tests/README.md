# Test temporary buffer lifetimes during hashing and Mach-O parsing

Run on macOS with the Xcode command-line tools:

```sh
bash Tests/run-memory-tests.sh /tmp
```

The runner compiles the actual `utilities.m` and `Libraries/MachO/MachO.m` with ARC at `-O0` and `-O2`. It creates all binaries and synthetic input files in a new directory under the supplied temporary parent, then prints that directory. No application scan is performed. An optional second argument chooses another checkout's source root, allowing the same tests to compare an unpatched revision.

Correctness checks cover empty, small, exact 1 MiB, and multi-chunk hash inputs, missing paths, directories, valid Mach-O load commands, classification enabled and disabled, invalid data, and truncated headers/load commands. They check that copied paths and load-command pointers remain usable after `parse:classify:` returns.

Two separate processes measure peak resident memory with `getrusage`: 24 parses of a synthetic 16 MiB Mach-O, and hashing a 384 MiB zero-filled file. Each keeps one outer autorelease pool alive through the measurement. The 192 MiB ceiling leaves room for framework overhead while catching accumulation of whole-file or per-chunk buffers. These measurements isolate the two code paths; they do not predict total memory consumption in a full system scan.
