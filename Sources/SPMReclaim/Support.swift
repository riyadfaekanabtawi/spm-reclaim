import Foundation
import Darwin

func expand(_ p: String) -> String { (p as NSString).expandingTildeInPath }

func humanBytes(_ n: Int) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var v = Double(n)
    var i = 0
    while v >= 1024 && i < units.count - 1 { v /= 1024; i += 1 }
    return i == 0 ? "\(n) B" : String(format: "%.2f %@", v, units[i])
}

func err(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

struct StatInfo {
    let dev: Int
    let size: Int
    let nlink: Int
    let isRegular: Bool
    let isSymlink: Bool
    let mtime: Int
}

func lstatInfo(_ path: String) -> StatInfo? {
    var s = stat()
    guard lstat(path, &s) == 0 else { return nil }
    let kind = s.st_mode & S_IFMT
    return StatInfo(
        dev: Int(s.st_dev),
        size: Int(s.st_size),
        nlink: Int(s.st_nlink),
        isRegular: kind == S_IFREG,
        isSymlink: kind == S_IFLNK,
        mtime: Int(s.st_mtimespec.tv_sec)
    )
}

func dirSize(_ path: String) -> Int {
    let url = URL(fileURLWithPath: path)
    guard let en = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey]
    ) else { return 0 }
    var total = 0
    for case let u as URL in en {
        guard let v = try? u.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey]),
              v.isRegularFile == true else { continue }
        total += v.totalFileAllocatedSize ?? 0
    }
    return total
}

let homeDir = expand("~")
let derivedDataDir = homeDir + "/Library/Developer/Xcode/DerivedData"
let swiftpmCacheDir = homeDir + "/Library/Caches/org.swift.swiftpm"
let swiftpmConfigDir = homeDir + "/Library/org.swift.swiftpm"

func defaultDedupRoots() -> [String] {
    let fm = FileManager.default
    var roots: [String] = []
    if let kids = try? fm.contentsOfDirectory(atPath: derivedDataDir) {
        for k in kids {
            let sp = derivedDataDir + "/" + k + "/SourcePackages"
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: sp, isDirectory: &isDir), isDir.boolValue {
                roots.append(sp)
            }
        }
    }
    if fm.fileExists(atPath: swiftpmCacheDir) { roots.append(swiftpmCacheDir) }
    return roots
}
