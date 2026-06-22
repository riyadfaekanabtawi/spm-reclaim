import Foundation

let usage = """
spm-reclaim <command> [options]

commands
  report                 Show where SPM/Xcode storage is going.
  dedup                  COW-clone identical files across package checkouts and
                         the global swiftpm cache. Dry-run unless --apply.
    --apply              Perform the clones. Default is dry-run.
    --path <dir>         Add a root to scan (repeatable). Defaults to every
                         DerivedData SourcePackages dir + the swiftpm cache.
    --min-size <bytes>   Skip files smaller than this. Default 4096 (one APFS
                         block; smaller files share no full blocks).
  gc                     Report DerivedData projects untouched for --days. Dry-run
                         unless --apply.
    --days <n>           Staleness threshold. Default 30.
    --apply              Delete the stale project dirs.

Run with Xcode idle. Dedup is non-destructive: clones are copy-on-write, so any
later write transparently un-shares the blocks.
"""

func value(after flag: String, in args: [String]) -> String? {
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    return args[i + 1]
}

func values(forRepeated flag: String, in args: [String]) -> [String] {
    var out: [String] = []
    var i = 0
    while i < args.count {
        if args[i] == flag, i + 1 < args.count { out.append(args[i + 1]); i += 2 }
        else { i += 1 }
    }
    return out
}

let argv = Array(CommandLine.arguments.dropFirst())
guard let command = argv.first else {
    print(usage)
    exit(2)
}
let rest = Array(argv.dropFirst())
let apply = rest.contains("--apply")

switch command {
case "report":
    runReport()

case "dedup":
    let custom = values(forRepeated: "--path", in: rest).map(expand)
    let roots = custom.isEmpty ? defaultDedupRoots() : custom
    let minSize = value(after: "--min-size", in: rest).flatMap(Int.init) ?? 4096
    if roots.isEmpty {
        print("no roots to scan")
        exit(1)
    }
    runDedup(roots: roots, minSize: minSize, apply: apply)

case "gc":
    let days = value(after: "--days", in: rest).flatMap(Int.init) ?? 30
    runGC(days: days, apply: apply)

case "-h", "--help", "help":
    print(usage)

default:
    err("unknown command: \(command)")
    print(usage)
    exit(2)
}
