package cangjie_community_knowledge_base

import std.collection.ArrayList

public class CkbFirstInitOptions {
    public var storeRoot: String = ""
    public var docsRoot: String = ""
    public var toolDocsRoot: String = ""
    public var stdRoot: String = ""
    public var stdxRoot: String = ""
    public var evalRoot: String = ""
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var apply: Bool = false
    public var dryRun: Bool = false
    public var autoMode: Bool = false
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CkbFirstInitSourceSummary {
    public var name: String = ""
    public var root: String = ""
    public var ok: Bool = false
    public var fileCount: Int64 = 0
    public var recordCount: Int64 = 0
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CkbFirstInitValidationResult {
    public var ok: Bool = false
    public var failedGates: ArrayList<String> = ArrayList<String>()
    public var queryChecks: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CkbFirstInitResult {
    public var ok: Bool = false
    public var candidateVersion: String = ""
    public var activeVersion: String = ""
    public var persisted: Bool = false
    public var dryRun: Bool = false
    public var validation: CkbFirstInitValidationResult = CkbFirstInitValidationResult()
    public var sources: ArrayList<CkbFirstInitSourceSummary> = ArrayList<CkbFirstInitSourceSummary>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public func parseCkbFirstInitOptions(args: Array<String>): CkbFirstInitOptions {
    let options = CkbFirstInitOptions()
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "--apply") {
            options.apply = true
        } else if (arg == "--dry-run") {
            options.dryRun = true
        } else if (arg == "--auto") {
            options.autoMode = true
        } else if (arg == "--store" && i + 1 < args.size) {
            options.storeRoot = args[i + 1].trimAscii()
            i += 1
        } else if (arg == "--docs-root" && i + 1 < args.size) {
            options.docsRoot = args[i + 1].trimAscii()
            i += 1
        } else if (arg == "--tool-docs-root" && i + 1 < args.size) {
            options.toolDocsRoot = args[i + 1].trimAscii()
            i += 1
        } else if (arg == "--std-root" && i + 1 < args.size) {
            options.stdRoot = args[i + 1].trimAscii()
            i += 1
        } else if (arg == "--stdx-root" && i + 1 < args.size) {
            options.stdxRoot = args[i + 1].trimAscii()
            i += 1
        } else if (arg == "--eval-root" && i + 1 < args.size) {
            options.evalRoot = args[i + 1].trimAscii()
            i += 1
        } else if (arg == "--target-version" && i + 1 < args.size) {
            options.targetVersion = args[i + 1].trimAscii()
            i += 1
        }
        i += 1
    }
    validateCkbFirstInitOptions(options)
    options
}

public func validateCkbFirstInitOptions(options: CkbFirstInitOptions): Bool {
    options.diagnostics.clear()
    if (options.apply && options.dryRun) {
        options.diagnostics.add("apply_and_dry_run_conflict")
    }
    if (options.targetVersion.trimAscii() == "") {
        options.diagnostics.add("target_version_empty")
    }
    ckbFirstInitValidatePath(options.docsRoot, "docs_root", options.diagnostics)
    ckbFirstInitValidatePath(options.toolDocsRoot, "tool_docs_root", options.diagnostics)
    ckbFirstInitValidatePath(options.stdRoot, "std_root", options.diagnostics)
    ckbFirstInitValidatePath(options.stdxRoot, "stdx_root", options.diagnostics)
    ckbFirstInitValidatePath(options.evalRoot, "eval_root", options.diagnostics)
    options.diagnostics.size == 0
}

public func renderCkbFirstInitResult(result: CkbFirstInitResult): String {
    let out = StringBuilder()
    if (result.dryRun) {
        out.append("first-init preflight ok=${result.ok}\n")
    } else {
        out.append("first-init ok=${result.ok}\n")
    }
    out.append("validation ok=${result.validation.ok}\n")
    out.append("activeKnowledgeVersion=${if (result.activeVersion == "") { "<empty>" } else { result.activeVersion }}\n")
    out.append("persisted=${result.persisted}\n")
    for (source in result.sources) {
        out.append("source ${source.name} ok=${source.ok} files=${source.fileCount} records=${source.recordCount}\n")
    }
    for (gate in result.validation.failedGates) {
        out.append("failedGate=${gate}\n")
    }
    for (diagnostic in result.diagnostics) {
        out.append("diagnostic=${diagnostic}\n")
    }
    out.toString()
}

private func ckbFirstInitValidatePath(path: String, name: String, diagnostics: ArrayList<String>): Unit {
    let clean = path.trimAscii().replace("\\", "/")
    if (clean == "") {
        return
    }
    if (clean.contains("\u{0}") || clean.contains("..")) {
        diagnostics.add("invalid_${name}")
        return
    }
    let lower = clean.toAsciiLower()
    if (lower.contains("/.ssh") || lower.contains("/.config") || lower.contains("/reference/") || lower.endsWith("/reference") || lower.contains("/hidden/") || lower.endsWith("/hidden")) {
        diagnostics.add("invalid_${name}")
    }
}
