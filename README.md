# spm-reclaim

Reclaims disk space consumed by Swift Package Manager / Xcode without changing
your workflow. Targets the real cost: every project keeps its own full clone of
every package under `DerivedData/<proj>/SourcePackages/checkouts/`, so N projects
on the same dependency means N physical copies.

`spm-reclaim` deduplicates those copies at the block level using APFS
copy-on-write clones (`clonefile(2)`). Identical files end up sharing the same
physical extents. Nothing is deleted; if anything ever writes to a shared file,
APFS transparently un-shares the blocks. No dependencies (CryptoKit + Darwin only).

## Build

    swift build -c release
    cp .build/release/spm-reclaim /usr/local/bin/

## Use

    spm-reclaim report           # where the space is going
    spm-reclaim dedup            # dry-run: what would be reclaimed
    spm-reclaim dedup --apply    # reclaim it
    spm-reclaim gc --days 30     # dry-run: stale DerivedData projects
    spm-reclaim gc --days 30 --apply

Run with Xcode idle to avoid racing a live build.

Defaults: `dedup` scans every `DerivedData/*/SourcePackages` plus
`~/Library/Caches/org.swift.swiftpm`, skipping symlinks, hardlinked files, and
files under one APFS block (4096 B, where there is no full block to share).

## How it works

1. Scan roots, group regular files by `(device, size)`.
2. Hash each size-collision group with SHA-256 to confirm identical content.
3. Pick a donor per duplicate set, `clonefile` it over each duplicate via a
   sibling temp + atomic `rename`.

Idempotent in effect: re-running on already-shared files re-clones identical
content (wasted I/O, no extra space). Run it on a schedule, not per build.

## Stop the re-clone churn (separate lever)

Dedup reclaims space already spent. To stop re-cloning packages into a fresh
per-project checkout on every resolve, point builds at one shared directory:

    xcodebuild ... -clonedSourcePackagesDirPath ~/Library/Developer/Xcode/SharedSourcePackages

Most effective in CI, where each job otherwise starts from an empty DerivedData.

## Safety

- Copy-on-write only. No file content is destroyed; duplicates are replaced by
  COW clones of byte-identical donors.
- Symlinks are never followed or rewritten.
- Hardlinked files are skipped (they already share storage).
- macOS / APFS only. On non-APFS or cross-volume sets, `clonefile` fails per file
  and that file is left untouched.
