import Foundation
import Darwin
import CryptoKit

struct FileEntry {
    let path: String
    let size: Int
    let dev: Int
}

func collectFiles(roots: [String], minSize: Int) -> [FileEntry] {
    let fm = FileManager.default
    var out: [FileEntry] = []
    for root in roots {
        guard let en = fm.enumerator(atPath: root) else { continue }
        for case let rel as String in en {
            let full = root + "/" + rel
            guard let info = lstatInfo(full) else { continue }
            // Skip symlinks (never follow), non-regular files, hardlinked files
            // (already share storage), and sub-block files (no full block to share).
            if info.isSymlink || !info.isRegular || info.nlink != 1 || info.size < minSize {
                continue
            }
            out.append(FileEntry(path: full, size: info.size, dev: info.dev))
        }
    }
    return out
}

func hashFile(_ path: String) -> Data? {
    guard let fh = FileHandle(forReadingAtPath: path) else { return nil }
    defer { try? fh.close() }
    var hasher = SHA256()
    while let chunk = try? fh.read(upToCount: 1 << 20), !chunk.isEmpty {
        hasher.update(data: chunk)
    }
    return Data(hasher.finalize())
}

// clonefile fails if the destination exists, so clone to a sibling temp and
// rename over the target atomically. clonefile copies the donor's metadata,
// which is acceptable: both files are identical content of the same pinned version.
func cloneOver(donor: String, target: String) -> Bool {
    let tmp = target + ".spmreclaim.tmp.\(getpid())"
    unlink(tmp)
    let rc = donor.withCString { s in tmp.withCString { d in clonefile(s, d, 0) } }
    if rc != 0 {
        err("clone failed \(target): \(String(cString: strerror(errno)))")
        return false
    }
    if rename(tmp, target) != 0 {
        err("rename failed \(target): \(String(cString: strerror(errno)))")
        unlink(tmp)
        return false
    }
    return true
}

func runDedup(roots: [String], minSize: Int, apply: Bool) {
    let files = collectFiles(roots: roots, minSize: minSize)

    var bySizeDev: [String: [FileEntry]] = [:]
    for f in files { bySizeDev["\(f.dev):\(f.size)", default: []].append(f) }

    var groups = 0
    var redundantBytes = 0
    var clonedFiles = 0
    var reclaimed = 0
    var failures = 0

    for (_, candidates) in bySizeDev where candidates.count > 1 {
        var byHash: [Data: [FileEntry]] = [:]
        for f in candidates {
            guard let h = hashFile(f.path) else { continue }
            byHash[h, default: []].append(f)
        }
        for (_, dupes) in byHash where dupes.count > 1 {
            let sorted = dupes.sorted { $0.path < $1.path }
            let donor = sorted[0]
            groups += 1
            for target in sorted.dropFirst() {
                redundantBytes += target.size
                guard apply else { continue }
                if cloneOver(donor: donor.path, target: target.path) {
                    clonedFiles += 1
                    reclaimed += target.size
                } else {
                    failures += 1
                }
            }
        }
    }

    print("files scanned:    \(files.count)")
    print("duplicate groups: \(groups)")
    print("redundant data:   \(humanBytes(redundantBytes))")
    if apply {
        print("files cloned:     \(clonedFiles)")
        print("reclaimed:        \(humanBytes(reclaimed))")
        if failures > 0 { print("failures:         \(failures)") }
    } else {
        print("mode: dry-run (re-run with --apply to reclaim)")
    }
}
