import Foundation

func runReport() {
    let fm = FileManager.default

    func line(_ label: String, _ path: String) {
        guard fm.fileExists(atPath: path) else { return }
        print(String(format: "%-22@ %@", label as NSString, humanBytes(dirSize(path)) as NSString))
    }

    print("storage")
    line("DerivedData", derivedDataDir)
    line("swiftpm cache", swiftpmCacheDir)
    line("swiftpm config", swiftpmConfigDir)

    guard let kids = try? fm.contentsOfDirectory(atPath: derivedDataDir), !kids.isEmpty else { return }
    let sized = kids
        .map { (name: $0, size: dirSize(derivedDataDir + "/" + $0)) }
        .sorted { $0.size > $1.size }
        .prefix(10)
    print("\ntop DerivedData projects")
    for p in sized {
        print(String(format: "%-50@ %@", p.name as NSString, humanBytes(p.size) as NSString))
    }
}

func runGC(days: Int, apply: Bool) {
    let fm = FileManager.default
    guard let kids = try? fm.contentsOfDirectory(atPath: derivedDataDir) else {
        print("no DerivedData")
        return
    }
    let cutoff = Int(Date().timeIntervalSince1970) - days * 86400
    var freed = 0
    var count = 0
    for k in kids {
        let dir = derivedDataDir + "/" + k
        guard let info = lstatInfo(dir), info.mtime < cutoff else { continue }
        let size = dirSize(dir)
        let age = (Int(Date().timeIntervalSince1970) - info.mtime) / 86400
        print(String(format: "%-50@ %10@  %dd", k as NSString, humanBytes(size) as NSString, age))
        freed += size
        count += 1
        if apply {
            do { try fm.removeItem(atPath: dir) }
            catch { err("remove failed \(k): \(error.localizedDescription)") }
        }
    }
    print("\nstale projects: \(count)")
    print(apply ? "removed: \(humanBytes(freed))" : "reclaimable: \(humanBytes(freed)) (re-run with --apply)")
}
