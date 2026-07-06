package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.convert.Parsable
import std.fs.{Directory, File, Path, exists}

public class CangjieKnowledgeReleaseGateOptions {
    public var runRoot: String = ""
    public var manifestPath: String = "test/cangjie_eval/cangjie_humaneval_manifest.jsonl"
    public var expectedTotal: Int64 = 164
    public var expectedPass: Int64 = 164
    public var format: String = "markdown"
    public var docsRoot: String = ""
    public var toolDocsRoot: String = ""
    public var stdRoot: String = ""
    public var stdxRoot: String = ""
    public var evalRoot: String = ""
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var schedulerTaskNames: ArrayList<String> = ArrayList<String>()
    public var help: Bool = false

    public init() {}
}

public class CangjieKnowledgeReleaseGateStep {
    public var id: String = ""
    public var ok: Bool = false
    public var status: String = "fail"
    public var diagnostic: String = ""
    public var artifactPath: String = ""

    public init() {}
}

public class CangjieKnowledgeReleaseGateReport {
    public var ok: Bool = true
    public var releaseGate: String = "pass"
    public var runRoot: String = ""
    public var activeKnowledgeVersion: String = ""
    public var steps: ArrayList<CangjieKnowledgeReleaseGateStep> = ArrayList<CangjieKnowledgeReleaseGateStep>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public func parseCangjieKnowledgeReleaseGateOptions(args: Array<String>): CangjieKnowledgeReleaseGateOptions {
    let options = CangjieKnowledgeReleaseGateOptions()
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "cangjie-knowledge-release-gate") {
            i += 1
            continue
        }
        if (arg == "--help" || arg == "-h") {
            options.help = true
            i += 1
            continue
        }
        if ((arg == "--run-root" || arg == "--run") && i + 1 < args.size) {
            options.runRoot = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--manifest" && i + 1 < args.size) {
            options.manifestPath = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--expected-total" && i + 1 < args.size) {
            options.expectedTotal = cangjieReleaseGateParseInt(args[i + 1], options.expectedTotal)
            i += 2
            continue
        }
        if (arg == "--expected-pass" && i + 1 < args.size) {
            options.expectedPass = cangjieReleaseGateParseInt(args[i + 1], options.expectedPass)
            i += 2
            continue
        }
        if (arg == "--format" && i + 1 < args.size) {
            options.format = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--docs-root" && i + 1 < args.size) {
            options.docsRoot = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--tool-docs-root" && i + 1 < args.size) {
            options.toolDocsRoot = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--std-root" && i + 1 < args.size) {
            options.stdRoot = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--stdx-root" && i + 1 < args.size) {
            options.stdxRoot = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--eval-root" && i + 1 < args.size) {
            options.evalRoot = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--target-version" && i + 1 < args.size) {
            options.targetVersion = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--scheduler-tasks" && i + 1 < args.size) {
            options.schedulerTaskNames = cangjieReleaseGateParseTaskNames(args[i + 1])
            i += 2
            continue
        }
        i += 1
    }
    options
}

public func runCangjieKnowledgeReleaseGate(
    args: Array<String>,
    config!: CkbRuntimeConfig = CkbRuntimeConfig(),
    store!: FileKnowledgeStore = FileKnowledgeStore("ckb-data"),
    sourceRunner!: SourceFetchRunner = DisabledNetworkFetchRunner()
): Int64 {
    let options = parseCangjieKnowledgeReleaseGateOptions(args)
    if (options.help) {
        print(cangjieKnowledgeReleaseGateUsage())
        return 0
    }
    let usageDiagnostic = cangjieKnowledgeReleaseGateUsageDiagnostic(options)
    if (usageDiagnostic != "ok") {
        println("usage error: ${usageDiagnostic}")
        print(cangjieKnowledgeReleaseGateUsage())
        return 2
    }
    cangjieReleaseGateEnsureDir(options.runRoot)
    let report = cangjieKnowledgeReleaseGate(options, config, store, sourceRunner: sourceRunner)
    let json = renderCangjieKnowledgeReleaseGateJson(report)
    let markdown = renderCangjieKnowledgeReleaseGateMarkdown(report)
    cangjieReleaseGateWriteText("${options.runRoot}/release-gate.json", json)
    cangjieReleaseGateWriteText("${options.runRoot}/release-gate.md", markdown)
    if (options.format == "json") {
        print(json)
    } else {
        print(markdown)
    }
    if (report.ok) { 0 } else { 1 }
}

public func cangjieKnowledgeReleaseGate(
    options: CangjieKnowledgeReleaseGateOptions,
    config: CkbRuntimeConfig,
    store: FileKnowledgeStore,
    sourceRunner!: SourceFetchRunner = DisabledNetworkFetchRunner()
): CangjieKnowledgeReleaseGateReport {
    let report = CangjieKnowledgeReleaseGateReport()
    report.runRoot = options.runRoot
    let usageDiagnostic = cangjieKnowledgeReleaseGateUsageDiagnostic(options)
    if (usageDiagnostic != "ok") {
        cangjieReleaseGateAddStep(report, "F8-BND-01-usage", false, usageDiagnostic, "")
        cangjieReleaseGateFinalize(report)
        return report
    }
    cangjieReleaseGateEnsureDir(options.runRoot)
    var service = CkbCommandLoopService(config, store, sourceRunner: sourceRunner)
    _ = service.start()
    cangjieReleaseGateAddLandingStatusStep(report, service, "F0-landing-status-initial")
    cangjieReleaseGateAddFirstInitStep(report, options, config, store)
    service = CkbCommandLoopService(config, store, sourceRunner: sourceRunner)
    _ = service.start()
    cangjieReleaseGateAddRouteProbeStep(report, service, options.runRoot)
    cangjieReleaseGateAddSchedulerStep(report, service, options)
    cangjieReleaseGateAddTransportParityStep(report, service, options.runRoot)
    cangjieReleaseGateAddPass1Step(report, options)
    cangjieReleaseGateAddLandingStatusStep(report, service, "F8-landing-status-final")
    report.activeKnowledgeVersion = service.statusSnapshot().activeKnowledgeVersion
    cangjieReleaseGateFinalize(report)
    cangjieReleaseGateWriteText("${options.runRoot}/release-gate.json", renderCangjieKnowledgeReleaseGateJson(report))
    cangjieReleaseGateWriteText("${options.runRoot}/release-gate.md", renderCangjieKnowledgeReleaseGateMarkdown(report))
    report
}

public func renderCangjieKnowledgeReleaseGateMarkdown(report: CangjieKnowledgeReleaseGateReport): String {
    let out = StringBuilder()
    out.append("# Cangjie Knowledge Release Gate\n\n")
    out.append("- releaseGate: ${report.releaseGate}\n")
    out.append("- ok: ${report.ok}\n")
    out.append("- runRoot: `${report.runRoot}`\n")
    out.append("- activeKnowledgeVersion: `${report.activeKnowledgeVersion}`\n\n")
    out.append("## Steps\n\n")
    out.append("| step | status | diagnostic | artifact |\n")
    out.append("| --- | --- | --- | --- |\n")
    for (step in report.steps) {
        out.append("| ${step.id} | ${step.status} | ${cangjieReleaseGateEscapeMarkdown(step.diagnostic)} | ${step.artifactPath} |\n")
    }
    out.append("\n## Diagnostics\n\n")
    if (report.diagnostics.size == 0) {
        out.append("- none\n")
    } else {
        for (diagnostic in report.diagnostics) {
            out.append("- `${cangjieReleaseGateEscapeMarkdown(diagnostic)}`\n")
        }
    }
    out.toString()
}

public func renderCangjieKnowledgeReleaseGateJson(report: CangjieKnowledgeReleaseGateReport): String {
    var steps = ""
    for (i in 0..report.steps.size) {
        if (i > 0) {
            steps += ","
        }
        let step = report.steps[i]
        steps += "{\"id\":\"${cangjieReleaseGateJsonEscape(step.id)}\",\"ok\":${step.ok},\"status\":\"${cangjieReleaseGateJsonEscape(step.status)}\",\"diagnostic\":\"${cangjieReleaseGateJsonEscape(step.diagnostic)}\",\"artifactPath\":\"${cangjieReleaseGateJsonEscape(step.artifactPath)}\"}"
    }
    "{\"ok\":${report.ok},\"releaseGate\":\"${cangjieReleaseGateJsonEscape(report.releaseGate)}\",\"runRoot\":\"${cangjieReleaseGateJsonEscape(report.runRoot)}\",\"activeKnowledgeVersion\":\"${cangjieReleaseGateJsonEscape(report.activeKnowledgeVersion)}\",\"steps\":[${steps}],\"diagnostics\":[${cangjieReleaseGateJsonStringArray(report.diagnostics)}]}\n"
}

public func cangjieKnowledgeReleaseGateUsage(): String {
    "Usage: cangjie_community_knowledge_base cangjie-knowledge-release-gate --run-root <path> --manifest <manifest.jsonl> --docs-root <path> --std-root <path> --stdx-root <path> --eval-root <path> [--tool-docs-root <path>] [--target-version 1.0.0] [--expected-total 164] [--expected-pass 164] [--scheduler-tasks comma-separated] [--format markdown|json]\n"
}

private func cangjieReleaseGateAddLandingStatusStep(report: CangjieKnowledgeReleaseGateReport, service: CkbCommandLoopService, id: String): Unit {
    let landing = collectCkbLandingStatus(service)
    let artifact = "${report.runRoot}/${id}.json"
    if (report.runRoot != "") {
        cangjieReleaseGateWriteText(artifact, renderCkbLandingStatusJson(landing) + "\n")
    }
    cangjieReleaseGateAddStep(report, id, landing.capabilities.size > 0, "overall=${landing.overallStatus},ok=${landing.ok}", artifact)
}

private func cangjieReleaseGateAddFirstInitStep(report: CangjieKnowledgeReleaseGateReport, options: CangjieKnowledgeReleaseGateOptions, config: CkbRuntimeConfig, store: FileKnowledgeStore): Unit {
    let dryOptions = cangjieReleaseGateFirstInitOptions(options, config, apply: false, dryRun: true)
    let applyOptions = cangjieReleaseGateFirstInitOptions(options, config, apply: true, dryRun: false)
    let dry = runCkbFirstInitialization(dryOptions, store)
    let applied = runCkbFirstInitializationWithActiveGuard(applyOptions, store)
    let artifact = "${options.runRoot}/first-init.txt"
    cangjieReleaseGateWriteText(artifact, renderCkbFirstInitResult(dry) + "\n--- apply ---\n" + renderCkbFirstInitResult(applied))
    let alreadyInitialized = applied.diagnostics.contains("already_initialized")
    let ok = dry.ok && applied.ok && (applied.persisted || alreadyInitialized)
    cangjieReleaseGateAddStep(report, "E2E-01-first-init", ok, "dryRun=${dry.ok},apply=${applied.ok},persisted=${applied.persisted},alreadyInitialized=${alreadyInitialized}", artifact)
}

private func cangjieReleaseGateAddRouteProbeStep(report: CangjieKnowledgeReleaseGateReport, service: CkbCommandLoopService, runRoot: String): Unit {
    let probes = ArrayList<CangjieKnowledgeReleaseGateStep>()
    cangjieReleaseGateRouteProbe(probes, service, "GET", "/v1/health", "{}", [])
    cangjieReleaseGateRouteProbe(probes, service, "GET", "/v1/status", "{}", [])
    cangjieReleaseGateRouteProbe(probes, service, "GET", "/v1/schema", "{}", [])
    cangjieReleaseGateRouteProbe(probes, service, "GET", "/v1/cangjie/corpus/status", "{}", [])
    cangjieReleaseGateRouteProbe(probes, service, "POST", "/v1/cangjie/task-knowledge-pack", cangjieReleaseGateTaskContextJson(), [])
    cangjieReleaseGateRouteProbe(probes, service, "POST", "/v1/cangjie/symbol-lookup", "{\"symbol\":\"ArrayList.add\",\"sourceSet\":\"std\",\"targetVersion\":\"1.0.0\"}", [])
    cangjieReleaseGateRouteProbe(probes, service, "POST", "/v1/cangjie/tool-manual", "{\"tool\":\"cjpm\",\"command\":\"test\",\"targetVersion\":\"1.0.0\"}", [])
    cangjieReleaseGateRouteProbe(probes, service, "POST", "/v1/evidence-pack", "{\"q\":\"ArrayList.add\",\"budget\":3}", [])
    cangjieReleaseGateRouteProbe(probes, service, "POST", "/v1/admin/initialize", "{\"dryRun\":true}", ["X-CKB-Admin-Token: release-gate"])
    let artifact = "${runRoot}/route-probe.jsonl"
    var text = ""
    var ok = true
    for (probe in probes) {
        if (!probe.ok) {
            ok = false
        }
        text += "{\"id\":\"${cangjieReleaseGateJsonEscape(probe.id)}\",\"ok\":${probe.ok},\"diagnostic\":\"${cangjieReleaseGateJsonEscape(probe.diagnostic)}\"}\n"
    }
    cangjieReleaseGateWriteText(artifact, text)
    cangjieReleaseGateAddStep(report, "E2E-02-route-probe", ok, "probes=${probes.size}", artifact)
}

private func cangjieReleaseGateRouteProbe(probes: ArrayList<CangjieKnowledgeReleaseGateStep>, service: CkbCommandLoopService, method: String, path: String, body: String, headers: Array<String>): Unit {
    let response = ckbApiHandle(service, method, path, body, headers)
    let probe = CangjieKnowledgeReleaseGateStep()
    probe.id = "${method} ${path}"
    probe.ok = !response.contains("\"code\":\"ckb.not_found\"") && !response.contains("\"code\":\"ckb.method_not_allowed\"") && !response.contains("\"status\":404")
    probe.status = if (probe.ok) { "pass" } else { "fail" }
    probe.diagnostic = if (probe.ok) { "reachable" } else { cangjieReleaseGateSafePreview(response) }
    probes.add(probe)
}

private func cangjieReleaseGateAddSchedulerStep(report: CangjieKnowledgeReleaseGateReport, service: CkbCommandLoopService, options: CangjieKnowledgeReleaseGateOptions): Unit {
    let taskNames = if (options.schedulerTaskNames.size > 0) { options.schedulerTaskNames } else { cangjieReleaseGateDefaultSchedulerTasks() }
    let result = service.runSchedulerTasks(taskNames, true)
    let artifact = "${options.runRoot}/scheduler-forced-run.txt"
    cangjieReleaseGateWriteText(artifact, "ran=${result.ran} succeeded=${result.succeeded} failed=${result.failed} degraded=${result.degraded} forced=${result.forced}\n${result.details}")
    let ok = result.failed == 0 && result.ran == taskNames.size
    cangjieReleaseGateAddStep(report, "E2E-03-scheduler-forced-run", ok, "ran=${result.ran},succeeded=${result.succeeded},failed=${result.failed},tasks=${taskNames.size}", artifact)
}

private func cangjieReleaseGateAddTransportParityStep(report: CangjieKnowledgeReleaseGateReport, service: CkbCommandLoopService, runRoot: String): Unit {
    let parity = ckbAbcdeProbeInProcessTransportParity(service, "release-gate", cangjieReleaseGateTaskContextJson())
    let artifact = "${runRoot}/transport-parity.jsonl"
    cangjieReleaseGateWriteText(artifact, ckbAbcdeRenderParityJsonl(parity) + "\n")
    cangjieReleaseGateAddStep(report, "E2E-04-transport-parity", parity.ok, parity.diagnostic, artifact)
}

private func cangjieReleaseGateAddPass1Step(report: CangjieKnowledgeReleaseGateReport, options: CangjieKnowledgeReleaseGateOptions): Unit {
    let gateOptions = CangjieHumanEvalPass1GateOptions()
    gateOptions.runRoot = options.runRoot
    gateOptions.manifestPath = options.manifestPath
    gateOptions.expectedTotal = options.expectedTotal
    gateOptions.expectedPass = options.expectedPass
    gateOptions.emitCurationInputPath = "${options.runRoot}/gap-curation-input.jsonl"
    let gate = cangjieHumanEvalPass1GateFromFiles(gateOptions)
    let artifact = "${options.runRoot}/pass1-gate.md"
    cangjieReleaseGateWriteText(artifact, renderCangjieHumanEvalPass1GateMarkdown(gate))
    let curation = emitCangjieHumanEvalGapCurationInput(gate)
    if (curation != "") {
        cangjieReleaseGateWriteText(gateOptions.emitCurationInputPath, curation)
    }
    cangjieReleaseGateAddStep(report, "E2E-05-pass1-gate", gate.ok, "groups=${gate.groups.size},diagnostics=${gate.diagnostics.size},remainingGaps=${gate.remainingGaps.size}", artifact)
}

private func cangjieReleaseGateAddStep(report: CangjieKnowledgeReleaseGateReport, id: String, ok: Bool, diagnostic: String, artifactPath: String): Unit {
    let step = CangjieKnowledgeReleaseGateStep()
    step.id = id
    step.ok = ok
    step.status = if (ok) { "pass" } else { "fail" }
    step.diagnostic = diagnostic
    step.artifactPath = artifactPath
    report.steps.add(step)
    if (!ok) {
        report.diagnostics.add("${id}:${diagnostic}")
    }
}

private func cangjieReleaseGateFinalize(report: CangjieKnowledgeReleaseGateReport): Unit {
    report.ok = true
    for (step in report.steps) {
        if (!step.ok) {
            report.ok = false
        }
    }
    report.releaseGate = if (report.ok) { "pass" } else { "fail" }
}

private func cangjieReleaseGateFirstInitOptions(options: CangjieKnowledgeReleaseGateOptions, config: CkbRuntimeConfig, apply!: Bool, dryRun!: Bool): CkbFirstInitOptions {
    let initOptions = CkbFirstInitOptions()
    initOptions.docsRoot = if (options.docsRoot != "") { options.docsRoot } else { config.firstInitDocsRoot }
    initOptions.toolDocsRoot = if (options.toolDocsRoot != "") { options.toolDocsRoot } else { config.firstInitToolDocsRoot }
    initOptions.stdRoot = if (options.stdRoot != "") { options.stdRoot } else { config.firstInitStdRoot }
    initOptions.stdxRoot = if (options.stdxRoot != "") { options.stdxRoot } else { config.firstInitStdxRoot }
    initOptions.evalRoot = if (options.evalRoot != "") { options.evalRoot } else { config.firstInitEvalRoot }
    initOptions.targetVersion = if (options.targetVersion != "") { options.targetVersion } else { config.firstInitTargetVersion }
    initOptions.apply = apply
    initOptions.dryRun = dryRun
    initOptions.autoMode = true
    initOptions
}

private func cangjieReleaseGateDefaultSchedulerTasks(): ArrayList<String> {
    let tasks = ArrayList<String>()
    tasks.add("cangjie_freshness_daily")
    tasks.add("cangjie_docs_full_weekly")
    tasks.add("cangjie_release_full_sync")
    tasks.add("cangjie_source_event_sync")
    tasks.add("cangjie_version_branch_refresh")
    tasks.add("cangjie_benchmark_gap_curation")
    tasks
}

private func cangjieReleaseGateParseTaskNames(raw: String): ArrayList<String> {
    let tasks = ArrayList<String>()
    for (item in raw.split(",")) {
        let trimmed = item.trimAscii()
        if (trimmed != "") {
            tasks.add(trimmed)
        }
    }
    tasks
}

private func cangjieKnowledgeReleaseGateUsageDiagnostic(options: CangjieKnowledgeReleaseGateOptions): String {
    if (options.runRoot.trimAscii() == "") {
        return "cangjie-knowledge-release-gate requires --run-root <path>"
    }
    if (options.manifestPath.trimAscii() == "") {
        return "cangjie-knowledge-release-gate requires --manifest <manifest.jsonl>"
    }
    if (options.expectedTotal <= 0 || options.expectedPass <= 0 || options.expectedPass > options.expectedTotal) {
        return "invalid_expected_pass1_threshold"
    }
    if (options.runRoot.contains("\u{0}") || options.runRoot.contains("..") || options.runRoot == "/" || options.runRoot == ".") {
        return "invalid_run_root"
    }
    if (options.manifestPath.contains("\u{0}") || options.manifestPath.contains("..") || options.manifestPath == "/" || options.manifestPath == ".") {
        return "invalid_manifest_path"
    }
    if (!exists(Path(options.manifestPath))) {
        return "manifest_not_found:${options.manifestPath}"
    }
    "ok"
}

private func cangjieReleaseGateTaskContextJson(): String {
    "{\"taskId\":\"release-gate\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"Implement a Cangjie ArrayList helper.\",\"signature\":\"func solution(values: Array<Int64>): Int64\",\"imports\":[],\"argTypes\":[\"Array<Int64>\"],\"returnType\":\"Int64\",\"expectedKnowledgeTags\":[\"ArrayList\",\"Cangjie syntax\"],\"starterCodeExcerpt\":\"\",\"compilerOutput\":\"\",\"targetVersion\":\"1.0.0\",\"sourceSet\":\"all\",\"sourceRef\":\"\",\"versionPolicy\":\"default\",\"budget\":5}"
}

private func cangjieReleaseGateParseInt(raw: String, fallback: Int64): Int64 {
    try {
        Int64.parse(raw.trimAscii())
    } catch (_: Exception) {
        fallback
    }
}

private func cangjieReleaseGateEnsureDir(path: String): Unit {
    let target = Path(path)
    if (!exists(target)) {
        Directory.create(target, recursive: true)
    }
}

private func cangjieReleaseGateWriteText(path: String, text: String): Unit {
    let target = Path(path)
    if (!exists(target.parent)) {
        Directory.create(target.parent, recursive: true)
    }
    File.writeTo(target, text.toArray())
}

private func cangjieReleaseGateSafePreview(raw: String): String {
    let text = redactSensitive(raw.replace("\n", " ").replace("\r", " "))
    let runes = text.toRuneArray()
    if (runes.size <= 120) {
        return text
    }
    let out = StringBuilder()
    for (i in 0..120) {
        out.append(runes[i])
    }
    out.append("...")
    out.toString()
}

private func cangjieReleaseGateJsonStringArray(values: ArrayList<String>): String {
    var out = ""
    for (i in 0..values.size) {
        if (i > 0) {
            out += ","
        }
        out += "\"${cangjieReleaseGateJsonEscape(values[i])}\""
    }
    out
}

private func cangjieReleaseGateJsonEscape(raw: String): String {
    let text = redactSensitive(raw)
    text.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
}

private func cangjieReleaseGateEscapeMarkdown(raw: String): String {
    redactSensitive(raw).replace("|", "\\|").replace("\n", " ")
}
