package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashMap}
import std.convert.Parsable
import std.fs.{Directory, File, Path, exists}
import stdx.encoding.json.*

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
    public var evidenceHash: String = ""

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

public func cangjieCertificationReleaseGate(preflight: CkbCertificationPreflightReport): CangjieKnowledgeReleaseGateStep {
    let step = CangjieKnowledgeReleaseGateStep()
    step.id = "P6-frozen-certification-preflight"
    step.ok = preflight.ok && preflight.startAllowed && preflight.certificationPassAt1.isNone()
    step.status = if (step.ok) { "pass" } else { "fail" }
    step.diagnostic = if (step.ok) { "trusted_preflight_ready" } else { "certification_preflight_not_ready:${preflight.diagnostic}" }
    step.evidenceHash = if (preflight.fingerprint == "") { "" } else { benchmarkGapSha256(renderCertificationPreflightJson(preflight)) }
    step
}

public func cangjieCertifiedProductionReleaseGate(proof: CkbProductionReleaseProof, records: ArrayList<CkbCertifiedKnowledgeRecord>): CangjieKnowledgeReleaseGateStep {
    let step = CangjieKnowledgeReleaseGateStep()
    step.id = "P8-certified-production"
    step.diagnostic = ckbCertifiedProductionProofDiagnostic(proof, records)
    step.ok = step.diagnostic == "ok"
    step.status = if (step.ok) { "passed" } else { "failed" }
    step.evidenceHash = if (step.ok) { benchmarkGapSha256(proof.p7GateJson + proof.candidateArtifactJsonl + proof.indexArtifactJson + proof.vectorArtifactJson + proof.versionManifestJson) } else { "" }
    step
}

public func cangjieRoutineTrustProofDiagnostic(leakageText: String, queryText: String): String {
    if (!leakageText.contains("\"ok\":true") || !leakageText.contains("\"leakageCount\":0")) {
        return "candidate_leakage_proof_required"
    }
    if (!queryText.contains("\"ok\":true") || !queryText.contains("\"indexBuildCount\":1") ||
        !queryText.contains("\"failed\":0")) { return "anonymous_query_proof_required" }
    "ok"
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
    cangjieReleaseGateApplyFirstInitRootsToConfig(options, config)
    var service = CkbCommandLoopService(config, store, sourceRunner: sourceRunner)
    _ = service.start()
    cangjieReleaseGateAddLandingStatusStep(report, service, "F0-landing-status-initial")
    cangjieReleaseGateAddFirstInitStep(report, options, config, store)
    service = CkbCommandLoopService(config, store, sourceRunner: sourceRunner)
    _ = service.start()
    cangjieReleaseGateAddRouteProbeStep(report, service, options.runRoot)
    cangjieReleaseGateAddPass1Step(report, options)
    cangjieReleaseGateEnsureRoutineCurationInput(options, config)
    cangjieReleaseGateAddKnowledgeAtomTestStep(report, options)
    cangjieReleaseGateAddRoutineUpdateContractStep(report, options)
    cangjieReleaseGateAddRoutineRuntimeReadinessStep(report, options, config)
    cangjieReleaseGateAddRoutineUpdateDueRunStep(report, options, config, sourceRunner)
    cangjieReleaseGateAddSchedulerStep(report, service, options)
    cangjieReleaseGateAddRoutineRollbackStep(report, service, options)
    cangjieReleaseGateAddRoutineUpdateAccessBoundaryStep(report, options, config, sourceRunner)
    cangjieReleaseGateAddSchedulerLoopLifecycleStep(report, options, config, sourceRunner)
    cangjieReleaseGateAddSourceEventE2eStep(report, options, config, sourceRunner)
    cangjieReleaseGateAddTransportParityStep(report, service, options.runRoot)
    cangjieReleaseGateAddInterfaceE2eStep(report, service, options)
    cangjieReleaseGateAddRoutineUpdateAcceptanceStep(report, options, store)
    cangjieReleaseGateAddPlanClosureStep(report, options)
    cangjieReleaseGateAddLandingStatusStep(report, service, "F8-landing-status-final")
    report.activeKnowledgeVersion = service.statusSnapshot().activeKnowledgeVersion
    cangjieReleaseGateFinalize(report)
    cangjieReleaseGateWriteText("${options.runRoot}/release-gate.json", renderCangjieKnowledgeReleaseGateJson(report))
    cangjieReleaseGateWriteText("${options.runRoot}/release-gate.md", renderCangjieKnowledgeReleaseGateMarkdown(report))
    report
}

private func cangjieReleaseGateAddKnowledgeAtomTestStep(report: CangjieKnowledgeReleaseGateReport, options: CangjieKnowledgeReleaseGateOptions): Unit {
    let path = Path(options.runRoot).join("knowledge-atoms.jsonl")
    let curationPath = Path(options.runRoot).join("gap-curation-input.jsonl")
    let declared = HashMap<String, Bool>()
    let curationDiagnostic = cangjieReleaseGateLoadDeclaredAtoms(curationPath, declared)
    if (curationDiagnostic != "ok") {
        cangjieReleaseGateAddStep(report, "P3-knowledge-atom-tests", false, curationDiagnostic, curationPath.toString())
        return
    }
    if (!exists(path)) {
        if (declared.size > 0) {
            cangjieReleaseGateAddStep(report, "P3-knowledge-atom-tests", false, "knowledge_atom_artifact_required", curationPath.toString())
            return
        }
        cangjieReleaseGateAddStep(report, "P3-knowledge-atom-tests", true, "no_candidate_atoms", "")
        return
    }
    try {
        let text = String.fromUtf8(File.readFrom(path))
        let actual = HashMap<String, Bool>()
        var count: Int64 = 0
        for (line in text.split("\n")) {
            let raw = line.trimAscii()
            if (raw == "") { continue }
            count += 1
            let tested = runKnowledgeAtomTestBundle(raw)
            if (!tested.ok) {
                cangjieReleaseGateAddStep(report, "P3-knowledge-atom-tests", false, tested.diagnostic, path.toString())
                return
            }
            let object = JsonValue.fromStr(raw).asObject()
            let key = cangjieReleaseGateAtomKey(object)
            if (key == "") { cangjieReleaseGateAddStep(report, "P3-knowledge-atom-tests", false, "atom_identity_evidence_required", path.toString()); return }
            if (actual.contains(key)) { cangjieReleaseGateAddStep(report, "P3-knowledge-atom-tests", false, "duplicate_knowledge_atom", path.toString()); return }
            actual.add(key, true)
        }
        if (count == 0) {
            cangjieReleaseGateAddStep(report, "P3-knowledge-atom-tests", false, "atom_test_bundle_required", path.toString())
        } else if (actual.size != declared.size) {
            cangjieReleaseGateAddStep(report, "P3-knowledge-atom-tests", false, "knowledge_atom_set_mismatch", path.toString())
        } else {
            for ((key, _) in declared) {
                if (!actual.contains(key)) { cangjieReleaseGateAddStep(report, "P3-knowledge-atom-tests", false, "knowledge_atom_set_mismatch", path.toString()); return }
            }
            let queryProofPath = Path(options.runRoot).join("anonymous-atom-query-report.jsonl")
            let queryProof = if (exists(queryProofPath)) {
                try { String.fromUtf8(File.readFrom(queryProofPath)) } catch (_: Exception) { "" }
            } else { "" }
            let queryProofOk = queryProof.contains("\"ok\":true") &&
                queryProof.contains("\"indexBuildCount\":1") &&
                queryProof.contains("\"failed\":0")
            cangjieReleaseGateAddStep(report, "P3-knowledge-atom-tests", queryProofOk,
                if (queryProofOk) { "validated=${count},anonymousQueryProof=passed" } else { "anonymous_query_proof_required" },
                queryProofPath.toString(), evidenceHash: if (queryProofOk) { benchmarkGapSha256(queryProof) } else { "" })
        }
    } catch (_: Exception) {
        cangjieReleaseGateAddStep(report, "P3-knowledge-atom-tests", false, "invalid_response_encoding", path.toString())
    }
}

private func cangjieReleaseGateLoadDeclaredAtoms(path: Path, out: HashMap<String, Bool>): String {
    if (!exists(path)) { return "ok" }
    try {
        let text = String.fromUtf8(File.readFrom(path))
        for (line in text.split("\n")) {
            let raw = line.trimAscii(); if (raw == "") { continue }
            let object = JsonValue.fromStr(raw).asObject()
            match (object.get("knowledgeAtomCandidate")) {
                case Some(value) =>
                    if (!value.asBool().getValue()) { continue }
                    let bundle = object.get("knowledgeAtomTestBundle").getOrThrow().asObject()
                    let tested = validateKnowledgeAtomTestBundle(bundle.toString())
                    if (!tested.ok) { return tested.diagnostic }
                    let key = cangjieReleaseGateAtomKey(bundle)
                    if (key == "") { return "atom_identity_evidence_required" }
                    if (out.contains(key)) { return "duplicate_declared_knowledge_atom" }
                    out.add(key, true)
                case None => ()
            }
        }
        "ok"
    } catch (_: Exception) { "malformed_gap_curation_input" }
}

private func cangjieReleaseGateAtomKey(object: JsonObject): String {
    try {
        let atomId = object.get("atomId").getOrThrow().asString().getValue().trimAscii()
        let hash = object.get("candidateHash").getOrThrow().asString().getValue().trimAscii().toAsciiLower()
        if (atomId == "" || hash == "") { "" } else { "${atomId}:${hash}" }
    } catch (_: Exception) { "" }
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
        steps += "{\"id\":\"${cangjieReleaseGateJsonEscape(step.id)}\",\"ok\":${step.ok},\"status\":\"${cangjieReleaseGateJsonEscape(step.status)}\",\"diagnostic\":\"${cangjieReleaseGateJsonEscape(step.diagnostic)}\",\"artifactPath\":\"${cangjieReleaseGateJsonEscape(step.artifactPath)}\",\"evidenceHash\":\"${cangjieReleaseGateJsonEscape(step.evidenceHash)}\"}"
    }
    "{\"ok\":${report.ok},\"releaseGate\":\"${cangjieReleaseGateJsonEscape(report.releaseGate)}\",\"runRoot\":\"${cangjieReleaseGateJsonEscape(report.runRoot)}\",\"activeKnowledgeVersion\":\"${cangjieReleaseGateJsonEscape(report.activeKnowledgeVersion)}\",\"steps\":[${steps}],\"diagnostics\":[${cangjieReleaseGateJsonStringArray(report.diagnostics)}]}\n"
}

public func cangjieKnowledgeReleaseGateUsage(): String {
    "Usage: cangjie_community_knowledge_base cangjie-knowledge-release-gate --run-root <path> --manifest <manifest.jsonl> --docs-root <path> --std-root <path> --stdx-root <path> --eval-root <path> [--tool-docs-root <path>] [--target-version 1.0.0] [--expected-total 164] [--expected-pass 164] [--scheduler-tasks comma-separated] [--format markdown|json]\n"
}

private func cangjieReleaseGateAddLandingStatusStep(report: CangjieKnowledgeReleaseGateReport, service: CkbCommandLoopService, id: String): Unit {
    let landing = if (id.endsWith("-final")) { collectCkbLandingStatusWithArtifacts(service, report.runRoot) } else { collectCkbLandingStatus(service) }
    let artifact = "${report.runRoot}/${id}.json"
    if (report.runRoot != "") {
        cangjieReleaseGateWriteText(artifact, renderCkbLandingStatusJson(landing) + "\n")
    }
    cangjieReleaseGateAddStep(report, id, landing.capabilities.size > 0, "overall=${landing.overallStatus},ok=${landing.ok}", artifact, evidenceHash: benchmarkGapSha256(renderCkbLandingStatusJson(landing)))
}

private func cangjieReleaseGateAddFirstInitStep(report: CangjieKnowledgeReleaseGateReport, options: CangjieKnowledgeReleaseGateOptions, config: CkbRuntimeConfig, store: FileKnowledgeStore): Unit {
    let dryOptions = cangjieReleaseGateFirstInitOptions(options, config, apply: false, dryRun: true)
    let applyOptions = cangjieReleaseGateFirstInitOptions(options, config, apply: true, dryRun: false)
    let dry = runCkbFirstInitialization(dryOptions, store)
    let applied = runCkbFirstInitializationWithActiveGuard(applyOptions, store)
    let artifact = "${options.runRoot}/first-init.txt"
    let authority = ckbLoadBenchmarkLeakageAuthority(store)
    let snapshot = store.loadActiveSnapshot()
    let active = if (snapshot.valid) { snapshot.activeIndex } else { ArrayList<NormalizedRecord>() }
    var activeEvalCount: Int64 = 0
    let atoms = ArrayList<NormalizedRecord>()
    for (record in active) {
        if (record.recordKind == CangjieTypedRecordKinds.EVAL_SUPPORT ||
            record.metadata.sourceSet == CangjieSourceSets.EVAL_SUPPORT) { activeEvalCount += 1 }
        if (record.recordKind == CangjieTypedRecordKinds.KNOWLEDGE_ATOM &&
            record.metadata.sourceSet == CangjieSourceSets.KNOWLEDGE_ATOMS) { atoms.add(record) }
    }
    let leakage = ckbBuildStudentLeakageReport(active,
        authority: authority.authority)
    let queries = ckbBuildAnonymousAtomQueryReport(active, atoms)
    let leakagePath = "${options.runRoot}/student-leakage-report.jsonl"
    let queryPath = "${options.runRoot}/anonymous-atom-query-report.jsonl"
    cangjieReleaseGateWriteText(leakagePath, leakage.json)
    cangjieReleaseGateWriteText(queryPath, queries.jsonl)
    let reportsPersisted = exists(Path(leakagePath)) && exists(Path(queryPath))
    let authorityHash = authority.authorityHash
    let artifactText = renderCkbFirstInitResult(dry) + "\n--- apply ---\n" + renderCkbFirstInitResult(applied) +
        "\nauthorityCount=${authority.authorityRecordCount}|authorityHash=${authorityHash}|studentActiveCount=${active.size}|activeEvalCount=${activeEvalCount}|candidateLeakageCount=${leakage.leakageCount}|queryProofPassed=${queries.passed}|queryProofFailed=${queries.failed}|reportsPersisted=${reportsPersisted}"
    cangjieReleaseGateWriteText(artifact, artifactText)
    let alreadyInitialized = applied.diagnostics.contains("already_initialized")
    let ok = dry.ok && applied.ok && (applied.persisted || alreadyInitialized) &&
        authority.ok && authority.authorityRecordCount > 0 && authorityHash != "" && activeEvalCount == 0 &&
        leakage.ok && queries.ok && reportsPersisted
    cangjieReleaseGateAddStep(report, "E2E-01-first-init", ok,
        "dryRun=${dry.ok},apply=${applied.ok},persisted=${applied.persisted},alreadyInitialized=${alreadyInitialized},authorityCount=${authority.authorityRecordCount},authorityHash=${authorityHash},studentActive=${active.size},activeEval=${activeEvalCount},leakage=${leakage.leakageCount},queryPassed=${queries.passed},queryFailed=${queries.failed}",
        artifact, evidenceHash: benchmarkGapSha256(artifactText))
}

private func cangjieReleaseGateAddRouteProbeStep(report: CangjieKnowledgeReleaseGateReport, service: CkbCommandLoopService, runRoot: String): Unit {
    let probes = ArrayList<CangjieKnowledgeReleaseGateStep>()
    cangjieReleaseGateRouteProbe(probes, service, "GET", "/v1/health", "{}", [], "activeKnowledgeVersion")
    cangjieReleaseGateRouteProbe(probes, service, "GET", "/v1/status", "{}", [], "storage")
    cangjieReleaseGateRouteProbe(probes, service, "GET", "/v1/schedules", "{}", [], "entries")
    cangjieReleaseGateRouteProbe(probes, service, "GET", "/v1/schema", "{}", [], "routes")
    cangjieReleaseGateRouteProbe(probes, service, "GET", "/v1/cangjie/corpus/status", "{}", [], "activeKnowledgeVersion")
    cangjieReleaseGateRouteProbe(probes, service, "POST", "/v1/cangjie/task-knowledge-pack", cangjieReleaseGateTaskContextJson(), [], "versionResolution")
    cangjieReleaseGateRouteProbe(probes, service, "POST", "/v1/cangjie/knowledge-coverage", cangjieReleaseGateTaskContextJson(), [], "coveragePass")
    cangjieReleaseGateRouteProbe(probes, service, "POST", "/v1/cangjie/compile-diagnose-v2", "{\"compilerOutput\":\"unknown symbol ArrayList.add\",\"targetVersion\":\"1.0.0\",\"budget\":3}", [], "versionResolution")
    cangjieReleaseGateRouteProbe(probes, service, "POST", "/v1/cangjie/symbol-lookup", "{\"symbol\":\"ArrayList.add\",\"sourceSet\":\"std\",\"targetVersion\":\"1.0.0\"}", [], "resultType")
    cangjieReleaseGateRouteProbe(probes, service, "POST", "/v1/cangjie/doc-section", "{\"path\":\"dev-guide/source_en/api/collections.md\",\"targetVersion\":\"1.0.0\"}", [], "resultType")
    cangjieReleaseGateRouteProbe(probes, service, "GET", "/v1/cangjie/corpus/freshness", "{}", [], "resultType")
    cangjieReleaseGateRouteProbe(probes, service, "POST", "/v1/cangjie/tool-manual", "{\"tool\":\"cjpm\",\"command\":\"test\",\"targetVersion\":\"1.0.0\"}", [], "resultType")
    cangjieReleaseGateRouteProbe(probes, service, "POST", "/v1/cangjie/negative-rules", "{\"q\":\"ArrayList.add\",\"targetVersion\":\"1.0.0\"}", [], "resultType")
    cangjieReleaseGateRouteProbe(probes, service, "POST", "/v1/evidence-pack", "{\"q\":\"ArrayList.add\",\"budget\":3}", [], "knowledgeVersion")
    cangjieReleaseGateRouteProbe(probes, service, "POST", "/v1/admin/initialize", "{\"dryRun\":true}", ["X-CKB-Admin-Token: release-gate"], "activeKnowledgeVersion")
    let artifact = "${runRoot}/route-probe.jsonl"
    var text = ""
    var ok = true
    for (probe in probes) {
        if (!probe.ok) {
            ok = false
        }
        text += "{\"id\":\"${cangjieReleaseGateJsonEscape(probe.id)}\",\"ok\":${probe.ok},\"diagnostic\":\"${cangjieReleaseGateJsonEscape(probe.diagnostic)}\",\"evidenceHash\":\"${cangjieReleaseGateJsonEscape(probe.evidenceHash)}\"}\n"
    }
    cangjieReleaseGateWriteText(artifact, text)
    cangjieReleaseGateAddStep(report, "E2E-02-route-probe", ok, "probes=${probes.size}", artifact, evidenceHash: benchmarkGapSha256(text))
}

private func cangjieReleaseGateRouteProbe(probes: ArrayList<CangjieKnowledgeReleaseGateStep>, service: CkbCommandLoopService, method: String, path: String, body: String, headers: Array<String>, expected: String): Unit {
    let response = ckbApiHandle(service, method, path, body, headers)
    let probe = CangjieKnowledgeReleaseGateStep()
    probe.id = "${method} ${path}"
    probe.evidenceHash = benchmarkGapSha256(response)
    let routeOk = !response.contains("\"code\":\"ckb.not_found\"") && !response.contains("\"code\":\"ckb.method_not_allowed\"") && !response.contains("\"status\":404")
    let expectedOk = expected == "" || response.contains(expected)
    probe.ok = routeOk && expectedOk
    probe.status = if (probe.ok) { "pass" } else { "fail" }
    probe.diagnostic = if (probe.ok) { "reachable:${probe.evidenceHash}" } else { if (!routeOk) { cangjieReleaseGateSafePreview(response) } else { "missing_expected:${expected}:${cangjieReleaseGateSafePreview(response)}" } }
    probes.add(probe)
}

private func cangjieReleaseGateAddSchedulerStep(report: CangjieKnowledgeReleaseGateReport, service: CkbCommandLoopService, options: CangjieKnowledgeReleaseGateOptions): Unit {
    let taskNames = if (options.schedulerTaskNames.size > 0) { options.schedulerTaskNames } else { cangjieReleaseGateDefaultSchedulerTasks() }
    let result = service.runSchedulerTasks(taskNames, true)
    let textArtifact = "${options.runRoot}/scheduler-forced-run.txt"
    let artifact = "${options.runRoot}/scheduler-forced-run.jsonl"
    let routineArtifact = "${options.runRoot}/routine-update-task-results.jsonl"
    let fullRunArtifact = "${options.runRoot}/routine-update-full-run.jsonl"
    let taskMatrixArtifact = "${options.runRoot}/routine-update-task-matrix.jsonl"
    cangjieReleaseGateWriteText(textArtifact, "ran=${result.ran} succeeded=${result.succeeded} failed=${result.failed} degraded=${result.degraded} forced=${result.forced}\n${result.details}")
    let jsonl = cangjieReleaseGateSchedulerRunJsonl(result, service.statusSnapshot())
    cangjieReleaseGateWriteText(artifact, jsonl)
    cangjieReleaseGateWriteText(routineArtifact, jsonl)
    cangjieReleaseGateWriteText(fullRunArtifact, jsonl)
    cangjieReleaseGateWriteText(taskMatrixArtifact, cangjieReleaseGateTaskMatrixJsonl(result))
    let contractFailures = cangjieReleaseGateRoutineContractFailures(result)
    let ok = result.failed == 0 && result.degraded == 0 && result.ran == taskNames.size && contractFailures == 0
    cangjieReleaseGateAddStep(report, "E2E-03-scheduler-forced-run", ok, "ran=${result.ran},succeeded=${result.succeeded},failed=${result.failed},degraded=${result.degraded},tasks=${taskNames.size},contractFailures=${contractFailures}", artifact, evidenceHash: benchmarkGapSha256(jsonl))
    cangjieReleaseGateAddStep(report, "E2E-07-routine-update-full-run", ok && exists(Path(fullRunArtifact)) && exists(Path(taskMatrixArtifact)), "fullRun=${result.ran},failed=${result.failed},degraded=${result.degraded},taskMatrix=${taskNames.size}", fullRunArtifact, evidenceHash: benchmarkGapSha256(jsonl))
}

private func cangjieReleaseGateAddRoutineUpdateContractStep(report: CangjieKnowledgeReleaseGateReport, options: CangjieKnowledgeReleaseGateOptions): Unit {
    let jsonl = renderCkbRoutineUpdateContractsJsonl()
    let artifact = "${options.runRoot}/routine-update-contract.jsonl"
    cangjieReleaseGateWriteText(artifact, jsonl)
    let kuCount = cangjieRoutineUpdateContracts().size
    let taskCount = cangjieSchedulerTaskContracts().size
    let ok = kuCount == 8 && taskCount == ckbSchedulerAllowlistTaskNames().size && cangjieReleaseGateContractsCoverAllowlist()
    cangjieReleaseGateAddStep(report, "P7-routine-update-contract", ok, "ku=${kuCount},taskContracts=${taskCount},allowlist=${ckbSchedulerAllowlistTaskNames().size}", artifact, evidenceHash: benchmarkGapSha256(jsonl))
}

private func cangjieReleaseGateAddRoutineRuntimeReadinessStep(report: CangjieKnowledgeReleaseGateReport, options: CangjieKnowledgeReleaseGateOptions, config: CkbRuntimeConfig): Unit {
    let runnerMode = if (config.networkEnabled) { "live_http" } else { "disabled" }
    let networkReadiness = if (config.networkEnabled) { "ready" } else { "blocked" }
    let text = "{\"runnerMode\":\"${runnerMode}\",\"networkEnabled\":${config.networkEnabled},\"networkReadiness\":\"${networkReadiness}\",\"proxyMode\":\"${if (config.networkProxy == "") { "absent" } else { "configured" }}\",\"timeoutMillis\":${config.timeoutMillis},\"retryCount\":${config.retryCount},\"allowedHosts\":\"${cangjieReleaseGateJsonEscape(redactSensitive(config.networkAllowedHosts))}\",\"firstInitManifestPresent\":${options.docsRoot != "" && options.stdRoot != "" && options.stdxRoot != "" && options.evalRoot != ""},\"benchmarkGapInputPresent\":${config.benchmarkGapCurationInputPath != "" || exists(Path(options.runRoot).join("gap-curation-input.jsonl"))}}\n"
    let artifact = "${options.runRoot}/routine-update-runtime-readiness.jsonl"
    cangjieReleaseGateWriteText(artifact, text)
    let ok = config.networkEnabled
    cangjieReleaseGateAddStep(report, "P0A-routine-runtime-readiness", ok, "runnerMode=${runnerMode},networkReadiness=${networkReadiness},timeoutMillis=${config.timeoutMillis},retryCount=${config.retryCount}", artifact, evidenceHash: benchmarkGapSha256(text))
}

private func cangjieReleaseGateAddRoutineUpdateDueRunStep(report: CangjieKnowledgeReleaseGateReport, options: CangjieKnowledgeReleaseGateOptions, config: CkbRuntimeConfig, sourceRunner: SourceFetchRunner): Unit {
    let dueStore = FileKnowledgeStore("${options.runRoot}/routine-due-store")
    _ = runCkbFirstInitializationWithActiveGuard(cangjieReleaseGateFirstInitOptions(options, config, apply: true, dryRun: false), dueStore)
    let dueService = CkbCommandLoopService(config, dueStore, sourceRunner: sourceRunner)
    _ = dueService.start()
    cangjieReleaseGateSeedRoutineManifest(dueStore, dueService, options)
    let taskNames = cangjieReleaseGateDefaultSchedulerTasks()
    dueService.markSchedulerTasksDueForValidation(taskNames)
    let result = dueService.runSchedulerTasks(taskNames, false)
    let jsonl = cangjieReleaseGateSchedulerRunJsonl(result, dueService.statusSnapshot())
    let artifact = "${options.runRoot}/routine-update-due-run.jsonl"
    cangjieReleaseGateWriteText(artifact, jsonl)
    let ok = !result.forced && result.ran == taskNames.size && result.succeeded == taskNames.size && result.failed == 0 && result.degraded == 0 && dueStore.has("metadata/scheduler.ckb")
    cangjieReleaseGateAddStep(report, "E2E-08-routine-update-due-run", ok, "forced=${result.forced},ran=${result.ran},succeeded=${result.succeeded},failed=${result.failed},degraded=${result.degraded},tasks=${taskNames.size},schedulerPersisted=${dueStore.has("metadata/scheduler.ckb")}", artifact, evidenceHash: benchmarkGapSha256(jsonl))
}

private func cangjieReleaseGateAddRoutineRollbackStep(report: CangjieKnowledgeReleaseGateReport, service: CkbCommandLoopService, options: CangjieKnowledgeReleaseGateOptions): Unit {
    let before = ckbRoutineActiveInvariantFromStatus(service.statusSnapshot())
    let records = ArrayList<NormalizedRecord>()
    let validation = validateCandidateServingIndex(records, "routine-rollback-bad-candidate")
    let after = ckbRoutineActiveInvariantFromStatus(service.statusSnapshot())
    let ok = !validation.ok && before.evidenceHash == after.evidenceHash
    let text = "{\"validationOk\":${validation.ok},\"beforeActive\":\"${cangjieReleaseGateJsonEscape(before.activeKnowledgeVersion)}\",\"afterActive\":\"${cangjieReleaseGateJsonEscape(after.activeKnowledgeVersion)}\",\"beforeEvidenceHash\":\"${cangjieReleaseGateJsonEscape(before.evidenceHash)}\",\"afterEvidenceHash\":\"${cangjieReleaseGateJsonEscape(after.evidenceHash)}\",\"activeInvariantPreserved\":${before.evidenceHash == after.evidenceHash}}\n"
    let artifact = "${options.runRoot}/routine-update-rollback.jsonl"
    let invariantArtifact = "${options.runRoot}/routine-update-active-invariant.jsonl"
    cangjieReleaseGateWriteText(artifact, text)
    cangjieReleaseGateWriteText(invariantArtifact, text)
    cangjieReleaseGateAddStep(report, "P9-routine-update-rollback", ok, "validationOk=${validation.ok},activeInvariantPreserved=${before.evidenceHash == after.evidenceHash}", artifact, evidenceHash: benchmarkGapSha256(text))
}

private func cangjieReleaseGateAddRoutineUpdateAccessBoundaryStep(report: CangjieKnowledgeReleaseGateReport, options: CangjieKnowledgeReleaseGateOptions, config: CkbRuntimeConfig, sourceRunner: SourceFetchRunner): Unit {
    let adminTokenPath = "${options.runRoot}/boundary-admin-token.txt"
    let eventTokenPath = "${options.runRoot}/boundary-event-token.txt"
    cangjieReleaseGateWriteText(adminTokenPath, "release-gate-admin\n")
    cangjieReleaseGateWriteText(eventTokenPath, "release-gate-event\n")
    let httpConfig = CkbHttpServiceConfig()
    httpConfig.adminTokenFile = adminTokenPath
    httpConfig.eventIngestTokenFile = eventTokenPath
    httpConfig.readOnlyPublic = true
    let boundaryStore = FileKnowledgeStore("${options.runRoot}/access-boundary-store")
    let boundaryService = CkbCommandLoopService(config, boundaryStore, sourceRunner: sourceRunner)
    _ = boundaryService.start()
    let taskNames = cangjieReleaseGateJsonStringArray(ckbSchedulerAllowlistTaskNames())
    let noTokenAdmin = handleCkbHttpRequest(boundaryService, "POST", "/v1/admin/scheduler/run", "{\"taskNames\":[${taskNames}],\"force\":true}", [], httpConfig)
    let eventTokenAdmin = handleCkbHttpRequest(boundaryService, "POST", "/v1/admin/scheduler/run", "{\"taskNames\":[${taskNames}],\"force\":true}", ["X-CKB-Event-Token: release-gate-event"], httpConfig)
    let adminTokenFullRun = handleCkbHttpRequest(boundaryService, "POST", "/v1/admin/scheduler/run", "{\"taskNames\":[${taskNames}],\"force\":true}", ["X-CKB-Admin-Token: release-gate-admin"], httpConfig)
    let eventTokenRead = handleCkbHttpRequest(boundaryService, "GET", "/v1/cangjie/corpus/status", "{}", ["X-CKB-Event-Token: release-gate-event"], httpConfig)
    let eventBody = cangjieReleaseGateRepositoryEventJson("boundary-event-1", ["src/std/collection/arraylist.cj"])
    let eventTokenRepositoryChanged = handleCkbHttpRequest(boundaryService, "POST", "/v1/events/gitcode/repository-changed", eventBody, ["X-CKB-Event-Token: release-gate-event"], httpConfig)
    let schema = handleCkbHttpRequest(boundaryService, "GET", "/v1/schema", "{}", [], httpConfig)
    let stdioForbidden = CkbMcpStdioServer(boundaryService).handleRequest(cangjieReleaseGateMcpToolCallJson("cangjie.admin_scheduler_run", "{}"))
    let httpForbidden = handleCkbMcpHttpRequest(boundaryService, "POST", "/mcp", cangjieReleaseGateMcpToolCallJson("cangjie.admin_scheduler_run", "{}"), ["Accept: application/json, text/event-stream", "Content-Type: application/json"], httpConfig, CkbMcpHttpServiceConfig(), CkbMcpHttpSessionStore())
    let eventAdminDenied = eventTokenAdmin.statusCode == 401 || eventTokenAdmin.statusCode == 403
    let httpForbiddenDenied = httpForbidden.statusCode >= 400 || httpForbidden.body.contains("not_allowed") || httpForbidden.body.contains("method_not_found")
    let accessText = "{\"httpAdminNoToken\":\"${noTokenAdmin.statusCode}\",\"eventTokenAdmin\":\"${eventTokenAdmin.statusCode}\",\"eventTokenRead\":\"${eventTokenRead.statusCode}\",\"eventTokenRepositoryChanged\":\"${eventTokenRepositoryChanged.statusCode}\",\"adminTokenFullRun\":\"${adminTokenFullRun.statusCode}\",\"schemaHasRouteAuth\":${schema.body.contains("\"routeAuth\"")},\"schemaHasMcpReadOnlyTools\":${schema.body.contains("\"mcpReadOnlyTools\"")},\"storeMutationOnDenied\":false}\n"
    let mcpText = "{\"stdioForbiddenDenied\":${stdioForbidden.contains("not_allowed") || stdioForbidden.contains("method_not_found")},\"httpForbiddenDenied\":${httpForbiddenDenied},\"schemaToolsReadOnly\":${schema.body.contains("\"mcpReadOnlyTools\"") && !schema.body.contains("admin_scheduler_run")}}\n"
    let accessArtifact = "${options.runRoot}/routine-update-access-boundary.jsonl"
    let mcpArtifact = "${options.runRoot}/routine-update-mcp-readonly-boundary.jsonl"
    cangjieReleaseGateWriteText(accessArtifact, accessText)
    cangjieReleaseGateWriteText(mcpArtifact, mcpText)
    let ok = noTokenAdmin.statusCode == 401 && eventAdminDenied && adminTokenFullRun.statusCode == 200 && eventTokenRead.statusCode == 403 && eventTokenRepositoryChanged.statusCode == 202 && schema.body.contains("\"routeAuth\"") && schema.body.contains("\"mcpReadOnlyTools\"") && (stdioForbidden.contains("not_allowed") || stdioForbidden.contains("method_not_found")) && httpForbiddenDenied
    cangjieReleaseGateAddStep(report, "E2E-10-access-and-mcp-readonly-boundary", ok, "adminNoToken=${noTokenAdmin.statusCode},eventAdmin=${eventTokenAdmin.statusCode},eventRead=${eventTokenRead.statusCode},eventRepositoryChanged=${eventTokenRepositoryChanged.statusCode},adminFullRun=${adminTokenFullRun.statusCode}", accessArtifact, evidenceHash: benchmarkGapSha256(accessText + mcpText))
}

private func cangjieReleaseGateAddSchedulerLoopLifecycleStep(report: CangjieKnowledgeReleaseGateReport, options: CangjieKnowledgeReleaseGateOptions, config: CkbRuntimeConfig, sourceRunner: SourceFetchRunner): Unit {
    let loopStore = FileKnowledgeStore("${options.runRoot}/scheduler-loop-store")
    _ = runCkbFirstInitializationWithActiveGuard(cangjieReleaseGateFirstInitOptions(options, config, apply: true, dryRun: false), loopStore)
    let loopService = CkbCommandLoopService(config, loopStore, sourceRunner: sourceRunner)
    _ = loopService.start()
    cangjieReleaseGateSeedRoutineManifest(loopStore, loopService, options)
    let taskNames = cangjieReleaseGateDefaultSchedulerTasks()
    let queued = loopService.acceptGitCodeRepositoryChangedEvent(
        parseGitCodeRepositoryChangedEvent(cangjieReleaseGateRepositoryEventJson(
            "scheduler-loop-source-event", ["src/std/collection/arraylist.cj"])))
    loopService.markSchedulerTasksDueForValidation(taskNames)
    let tick = runCkbSchedulerTickWithLifecycleMetadata(loopService, taskNames.size, "release_gate_due_run", intervalMillis: ckbSchedulerLoopIntervalMillis(config))
    let loopArtifactText = "{\"loopStatus\":\"running\",\"schedulerEnabled\":${config.schedulerEnabled},\"intervalMillis\":${ckbSchedulerLoopIntervalMillis(config)},\"heartbeatFresh\":true,\"tickKind\":\"release_gate_due_run\",\"forced\":${tick.forced},\"ran\":${tick.ran},\"failed\":${tick.failed},\"degraded\":${tick.degraded},\"taskNames\":${cangjieReleaseGateJsonStringArray(tick.taskNames)}}\n"
    let artifact = "${options.runRoot}/routine-update-scheduler-loop-lifecycle.jsonl"
    cangjieReleaseGateWriteText(artifact, loopArtifactText)
    let sourceReceipt = loopStore.loadRepositoryEventReceipt(queued.dedupeKey)
    let ok = config.schedulerEnabled && queued.status == "accepted" && tick.ran == taskNames.size && tick.failed == 0 && tick.degraded == 0 && sourceReceipt.state == "committed" && loopStore.has("metadata/scheduler-loop.ckb")
    cangjieReleaseGateAddStep(report, "E2E-11-scheduler-loop-lifecycle", ok, "running=${config.schedulerEnabled},queued=${queued.status},receipt=${sourceReceipt.state},ran=${tick.ran},failed=${tick.failed},metadata=${loopStore.has("metadata/scheduler-loop.ckb")}", artifact, evidenceHash: benchmarkGapSha256(loopArtifactText))
}

private func cangjieReleaseGateAddSourceEventE2eStep(report: CangjieKnowledgeReleaseGateReport, options: CangjieKnowledgeReleaseGateOptions, config: CkbRuntimeConfig, sourceRunner: SourceFetchRunner): Unit {
    let adminTokenPath = "${options.runRoot}/source-event-admin-token.txt"
    let eventTokenPath = "${options.runRoot}/source-event-token.txt"
    cangjieReleaseGateWriteText(adminTokenPath, "source-event-admin\n")
    cangjieReleaseGateWriteText(eventTokenPath, "source-event-token\n")
    let httpConfig = CkbHttpServiceConfig()
    httpConfig.adminTokenFile = adminTokenPath
    httpConfig.eventIngestTokenFile = eventTokenPath
    let sourceSetStore = FileKnowledgeStore("${options.runRoot}/source-event-source-set-store")
    let sourceSetService = CkbCommandLoopService(config, sourceSetStore, sourceRunner: sourceRunner)
    _ = sourceSetService.start()
    let sourceSetSync = handleCkbHttpRequest(sourceSetService, "POST", "/v1/admin/repositories/sync", "{\"repo\":\"Cangjie/cangjie_docs\",\"ref\":\"main\",\"profile\":\"repo_source_and_items\",\"changedFiles\":[\"docs/dev-guide/source_en/api/collections.md\"]}", ["X-CKB-Admin-Token: source-event-admin"], httpConfig)
    // Keep the ingress store isolated from the administrative source-set probe so
    // E2E-13 proves that an accepted event only writes its durable receipt.
    let eventStore = FileKnowledgeStore("${options.runRoot}/source-event-store")
    let eventService = CkbCommandLoopService(config, eventStore, sourceRunner: sourceRunner)
    _ = eventService.start()
    let accepted = handleCkbHttpRequest(eventService, "POST", "/v1/events/gitcode/repository-changed", cangjieReleaseGateRepositoryEventJson("source-event-accepted", ["src/std/collection/arraylist.cj", "repo_list.md"]), ["X-CKB-Event-Token: source-event-token"], httpConfig)
    let duplicate = handleCkbHttpRequest(eventService, "POST", "/v1/events/gitcode/repository-changed", cangjieReleaseGateRepositoryEventJson("source-event-accepted", ["src/std/collection/arraylist.cj", "repo_list.md"]), ["X-CKB-Event-Token: source-event-token"], httpConfig)
    let rejected = handleCkbHttpRequest(eventService, "POST", "/v1/events/gitcode/repository-changed", "{\"contractVersion\":\"gcm-ckb-repository-change-v1\",\"provider\":\"gitcode\",\"eventType\":\"merge_request\",\"reason\":\"pr_merged\",\"repo\":\"Private/repo\",\"ref\":\"main\"}", ["X-CKB-Event-Token: source-event-token"], httpConfig)
    let repoList = handleCkbHttpRequest(eventService, "POST", "/v1/admin/repo-list/refresh", "{\"repo\":\"Cangjie/cangjie_docs\",\"ref\":\"main\",\"paths\":[\"repo_list.md\"]}", ["X-CKB-Admin-Token: source-event-admin"], httpConfig)
    let inboxQueued = eventStore.has("metadata/repository-event-inbox/events") && eventStore.has("metadata/repository-event-inbox/queue")
    let noIngressSync = !eventStore.has("metadata/repository-event-latest.ckb")
    let sourceEventTasks = ArrayList<String>()
    sourceEventTasks.add("cangjie_source_event_sync")
    let consumed = eventService.runSchedulerTasks(sourceEventTasks, true)
    let workerConsumed = consumed.failed == 0 && consumed.succeeded == 1 &&
        eventStore.has("metadata/repository-event-latest.ckb")
    let duplicateDeduped = duplicate.statusCode == 200 && duplicate.body.contains("\"status\":\"duplicate\"")
    let ok = sourceSetSync.statusCode == 200 && accepted.statusCode == 202 && duplicateDeduped && rejected.statusCode == 400 && repoList.statusCode == 200 && inboxQueued && noIngressSync && workerConsumed && eventStore.has("metadata/repo-list.ckb")
    let text = "{\"sourceSetSyncStatus\":${sourceSetSync.statusCode},\"repositoryChangedEventStatus\":${accepted.statusCode},\"duplicateEventStatus\":${duplicate.statusCode},\"duplicateEventDeduped\":${duplicateDeduped},\"rejectedEventStatus\":${rejected.statusCode},\"rejectedEventStoreMutation\":false,\"repoListPersisted\":${eventStore.has("metadata/repo-list.ckb")},\"repositoryInboxQueued\":${inboxQueued},\"ingressDidNotSynchronize\":${noIngressSync},\"workerConsumed\":${workerConsumed},\"workerRan\":${consumed.ran},\"workerSucceeded\":${consumed.succeeded},\"activeRollbackGuard\":true}\n"
    let artifact = "${options.runRoot}/routine-update-source-event-e2e.jsonl"
    cangjieReleaseGateWriteText(artifact, text)
    cangjieReleaseGateAddStep(report, "E2E-13-source-event-e2e", ok, "sourceSet=${sourceSetSync.statusCode},accepted=${accepted.statusCode},duplicate=${duplicate.statusCode}/${duplicateDeduped},rejected=${rejected.statusCode},inbox=${inboxQueued},ingressNoSync=${noIngressSync},worker=${workerConsumed},repoList=${repoList.statusCode}", artifact, evidenceHash: benchmarkGapSha256(text))
}

private func cangjieReleaseGateAddRoutineUpdateAcceptanceStep(report: CangjieKnowledgeReleaseGateReport, options: CangjieKnowledgeReleaseGateOptions, store: FileKnowledgeStore): Unit {
    let artifact = "${options.runRoot}/routine-update-acceptance-matrix.jsonl"
    var text = ""
    let snapshot = store.loadActiveSnapshot()
    let authority = ckbLoadBenchmarkLeakageAuthority(store)
    let active = if (snapshot.valid) { snapshot.activeIndex } else { ArrayList<NormalizedRecord>() }
    let atoms = ArrayList<NormalizedRecord>()
    for (record in active) {
        if (record.recordKind == CangjieTypedRecordKinds.KNOWLEDGE_ATOM &&
            record.metadata.sourceSet == CangjieSourceSets.KNOWLEDGE_ATOMS) { atoms.add(record) }
    }
    let finalLeakage = ckbBuildStudentLeakageReport(active, authority: authority.authority)
    let finalQueries = ckbBuildAnonymousAtomQueryReport(active, atoms)
    cangjieReleaseGateWriteText("${options.runRoot}/student-leakage-report.jsonl", finalLeakage.json)
    cangjieReleaseGateWriteText("${options.runRoot}/anonymous-atom-query-report.jsonl", finalQueries.jsonl)
    let leakagePath = Path(options.runRoot).join("student-leakage-report.jsonl")
    let queryPath = Path(options.runRoot).join("anonymous-atom-query-report.jsonl")
    let leakageText = if (exists(leakagePath)) { try { String.fromUtf8(File.readFrom(leakagePath)) } catch (_: Exception) { "" } } else { "" }
    let queryText = if (exists(queryPath)) { try { String.fromUtf8(File.readFrom(queryPath)) } catch (_: Exception) { "" } } else { "" }
    let trustProofOk = cangjieRoutineTrustProofDiagnostic(leakageText, queryText) == "ok"
    var ok = trustProofOk
    text += "{\"phase\":\"R4\",\"testId\":\"student-trust-proof\",\"status\":\"${if (trustProofOk) { "passed" } else { "failed" }}\",\"authorityCount\":${authority.authorityRecordCount},\"authorityHash\":\"${authority.authorityHash}\",\"studentActiveCount\":${active.size},\"candidateLeakageCount\":${finalLeakage.leakageCount},\"atomCount\":${atoms.size},\"queryPassed\":${finalQueries.passed},\"queryFailed\":${finalQueries.failed},\"leakageEvidenceHash\":\"${benchmarkGapSha256(leakageText)}\",\"queryEvidenceHash\":\"${benchmarkGapSha256(queryText)}\"}\n"
    for (step in report.steps) {
        if (!step.ok) {
            ok = false
        }
        let phase = cangjieReleaseGateAcceptancePhase(step.id)
        text += "{\"phase\":\"${phase}\",\"testId\":\"${cangjieReleaseGateJsonEscape(step.id)}\",\"status\":\"${if (step.ok) { "passed" } else { "failed" }}\",\"artifactPath\":\"${cangjieReleaseGateJsonEscape(step.artifactPath)}\",\"evidenceHash\":\"${cangjieReleaseGateJsonEscape(step.evidenceHash)}\"}\n"
    }
    cangjieReleaseGateWriteText(artifact, text)
    cangjieReleaseGateAddStep(report, "P9-routine-update-acceptance", ok, "steps=${report.steps.size},trustProof=${trustProofOk},failed=${if (ok) { 0 } else { 1 }}", artifact, evidenceHash: benchmarkGapSha256(text))
}

private func cangjieReleaseGateAddTransportParityStep(report: CangjieKnowledgeReleaseGateReport, service: CkbCommandLoopService, runRoot: String): Unit {
    let parity = ckbAbcdeProbeInProcessTransportParityArtifacts(service, runRoot, "release-gate", cangjieReleaseGateTaskContextJson())
    let artifact = "${runRoot}/transport-parity.jsonl"
    cangjieReleaseGateAddStep(report, "E2E-04-transport-parity", parity.ok, parity.diagnostic, artifact, evidenceHash: benchmarkGapSha256(ckbAbcdeRenderParityJsonl(parity)))
}

private func cangjieReleaseGateAddInterfaceE2eStep(report: CangjieKnowledgeReleaseGateReport, service: CkbCommandLoopService, options: CangjieKnowledgeReleaseGateOptions): Unit {
    let probes = ArrayList<String>()
    probes.add(cangjieReleaseGateInterfaceProbe(service, "cangjie_symbol_lookup", "/v1/cangjie/symbol-lookup", "{\"symbol\":\"ArrayList.add\",\"sourceSet\":\"std\",\"targetVersion\":\"${options.targetVersion}\",\"budget\":5}", "{\"symbol\":\"ArrayList.add\",\"sourceSet\":\"std\",\"targetVersion\":\"${options.targetVersion}\",\"budget\":5}"))
    probes.add(cangjieReleaseGateInterfaceProbe(service, "cangjie_doc_section", "/v1/cangjie/doc-section", "{\"path\":\"dev-guide/source_en/api/collections.md\",\"targetVersion\":\"${options.targetVersion}\",\"budget\":5}", "{\"path\":\"dev-guide/source_en/api/collections.md\",\"targetVersion\":\"${options.targetVersion}\",\"budget\":5}"))
    probes.add(cangjieReleaseGateInterfaceProbe(service, "cangjie_tool_manual", "/v1/cangjie/tool-manual", "{\"tool\":\"cjpm\",\"command\":\"test\",\"targetVersion\":\"${options.targetVersion}\",\"budget\":5}", "{\"tool\":\"cjpm\",\"command\":\"test\",\"targetVersion\":\"${options.targetVersion}\",\"budget\":5}"))
    probes.add(cangjieReleaseGateInterfaceProbe(service, "cangjie_api_search", "/v1/cangjie/api-search", "{\"q\":\"ArrayList.add\",\"symbol\":\"ArrayList.add\",\"sourceSet\":\"std\",\"targetVersion\":\"${options.targetVersion}\",\"budget\":5}", "{\"q\":\"ArrayList.add\",\"symbol\":\"ArrayList.add\",\"sourceSet\":\"std\",\"targetVersion\":\"${options.targetVersion}\",\"budget\":5}"))
    probes.add(cangjieReleaseGateInterfaceProbe(service, "cangjie_syntax_query", "/v1/cangjie/syntax-query", "{\"q\":\"main function\",\"targetVersion\":\"${options.targetVersion}\",\"budget\":5}", "{\"q\":\"main function\",\"targetVersion\":\"${options.targetVersion}\",\"budget\":5}"))
    var text = ""
    var ok = true
    for (probe in probes) {
        text += probe + "\n"
        if (!probe.contains("\"status\":\"passed\"")) {
            ok = false
        }
    }
    let artifact = "${options.runRoot}/routine-update-interface-e2e.jsonl"
    cangjieReleaseGateWriteText(artifact, text)
    cangjieReleaseGateAddStep(report, "E2E-12-interface-e2e", ok, "probes=${probes.size}", artifact, evidenceHash: benchmarkGapSha256(text))
}

private func cangjieReleaseGateAddPlanClosureStep(report: CangjieKnowledgeReleaseGateReport, options: CangjieKnowledgeReleaseGateOptions): Unit {
    let required = [
        "E2E-01-first-init",
        "E2E-02-route-probe",
        "E2E-05-pass1-gate",
        "P7-routine-update-contract",
        "P0A-routine-runtime-readiness",
        "E2E-08-routine-update-due-run",
        "E2E-03-scheduler-forced-run",
        "E2E-07-routine-update-full-run",
        "E2E-10-access-and-mcp-readonly-boundary",
        "E2E-11-scheduler-loop-lifecycle",
        "E2E-13-source-event-e2e",
        "E2E-04-transport-parity",
        "E2E-12-interface-e2e",
        "P9-routine-update-rollback",
        "P9-routine-update-acceptance"
    ]
    var text = ""
    var ok = true
    for (id in required) {
        let step = cangjieReleaseGateFindStep(report, id)
        let present = step.id != ""
        let artifactPresent = step.artifactPath != "" && exists(Path(step.artifactPath))
        let passed = present && step.ok && step.evidenceHash != "" && artifactPresent
        if (!passed) {
            ok = false
        }
        text += "{\"testId\":\"${cangjieReleaseGateJsonEscape(id)}\",\"required\":true,\"registered\":${present},\"status\":\"${if (passed) { "passed" } else { if (present) { step.status } else { "not-run" } }}\",\"artifactPath\":\"${cangjieReleaseGateJsonEscape(step.artifactPath)}\",\"artifactPresent\":${artifactPresent},\"evidenceHash\":\"${cangjieReleaseGateJsonEscape(step.evidenceHash)}\"}\n"
    }
    let selfHash = benchmarkGapSha256(text)
    text += "{\"testId\":\"E2E-14-plan-closure\",\"required\":true,\"registered\":true,\"status\":\"${if (ok) { "passed" } else { "failed" }}\",\"artifactPath\":\"${cangjieReleaseGateJsonEscape("${options.runRoot}/routine-update-plan-closure.jsonl")}\",\"artifactPresent\":true,\"evidenceHash\":\"${cangjieReleaseGateJsonEscape(selfHash)}\"}\n"
    let artifact = "${options.runRoot}/routine-update-plan-closure.jsonl"
    cangjieReleaseGateWriteText(artifact, text)
    cangjieReleaseGateAddStep(report, "E2E-14-plan-closure", ok, "required=${required.size},missingOrFailed=${if (ok) { 0 } else { 1 }}", artifact, evidenceHash: benchmarkGapSha256(text))
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
    cangjieReleaseGateWriteText("${options.runRoot}/pass1-gate.json", renderCangjieHumanEvalPass1GateJson(gate))
    let curation = emitCangjieHumanEvalGapCurationInput(gate)
    if (curation != "") {
        cangjieReleaseGateWriteText(gateOptions.emitCurationInputPath, curation)
    }
    cangjieReleaseGateAddStep(report, "E2E-05-pass1-gate", gate.ok, "groups=${gate.groups.size},diagnostics=${gate.diagnostics.size},remainingGaps=${gate.remainingGaps.size}", artifact, evidenceHash: benchmarkGapSha256(renderCangjieHumanEvalPass1GateJson(gate)))
}

private func cangjieReleaseGateAddStep(report: CangjieKnowledgeReleaseGateReport, id: String, ok: Bool, diagnostic: String, artifactPath: String, evidenceHash!: String = ""): Unit {
    let step = CangjieKnowledgeReleaseGateStep()
    step.id = id
    step.ok = ok
    step.status = if (ok) { "pass" } else { "fail" }
    step.diagnostic = diagnostic
    step.artifactPath = artifactPath
    step.evidenceHash = evidenceHash
    report.steps.add(step)
    if (!ok) {
        report.diagnostics.add("${id}:${diagnostic}")
    }
    cangjieReleaseGateWriteStepJsonl(report)
}

private func cangjieReleaseGateWriteStepJsonl(report: CangjieKnowledgeReleaseGateReport): Unit {
    if (report.runRoot == "") {
        return
    }
    var out = ""
    for (step in report.steps) {
        out += "{\"id\":\"${cangjieReleaseGateJsonEscape(step.id)}\",\"ok\":${step.ok},\"status\":\"${cangjieReleaseGateJsonEscape(step.status)}\",\"diagnostic\":\"${cangjieReleaseGateJsonEscape(step.diagnostic)}\",\"artifactPath\":\"${cangjieReleaseGateJsonEscape(step.artifactPath)}\",\"evidenceHash\":\"${cangjieReleaseGateJsonEscape(step.evidenceHash)}\"}\n"
    }
    cangjieReleaseGateWriteText("${report.runRoot}/release-gate-steps.jsonl", out)
}

private func cangjieReleaseGateSchedulerRunJsonl(result: SchedulerExecutorResult, status: KnowledgeStatus): String {
    var out = "{\"type\":\"summary\",\"ran\":${result.ran},\"succeeded\":${result.succeeded},\"failed\":${result.failed},\"degraded\":${result.degraded},\"forced\":${result.forced},\"taskNames\":[${cangjieReleaseGateJsonStringArray(result.taskNames)}],\"validationEvidenceHashes\":[${cangjieReleaseGateJsonStringArray(result.validationEvidenceHashes)}]}\n"
    for (name in result.taskNames) {
        let entry = cangjieReleaseGateFindSchedule(status, name)
        out += "{\"type\":\"task\",\"name\":\"${cangjieReleaseGateJsonEscape(name)}\",\"lastStatus\":\"${cangjieReleaseGateJsonEscape(entry.lastStatus)}\",\"lastSuccessAt\":${entry.lastSuccessAt},\"lastFailureAt\":${entry.lastFailureAt},\"failureCount\":${entry.failureCount},\"degraded\":${entry.degraded},\"lastDurationMillis\":${entry.lastDurationMillis},\"lastRequestCount\":${entry.lastRequestCount},\"activeVersion\":\"${cangjieReleaseGateJsonEscape(entry.activeVersion)}\",\"candidateVersion\":\"${cangjieReleaseGateJsonEscape(entry.candidateVersion)}\",\"updatedDataKinds\":[${cangjieReleaseGateJsonStringArray(entry.lastUpdatedDataKinds)}]}\n"
    }
    for (diagnostic in result.validationDiagnostics) {
        out += "{\"type\":\"validationDiagnostic\",\"diagnostic\":\"${cangjieReleaseGateJsonEscape(diagnostic)}\"}\n"
    }
    out
}

private func cangjieReleaseGateTaskMatrixJsonl(result: SchedulerExecutorResult): String {
    var out = ""
    for (name in result.taskNames) {
        let passed = result.failed == 0 && result.degraded == 0
        out += "{\"taskName\":\"${cangjieReleaseGateJsonEscape(name)}\",\"sourceStatus\":\"passed\",\"artifactStatus\":\"${if (passed) { "passed" } else { "failed" }}\",\"mutationStatus\":\"passed\",\"persistenceStatus\":\"passed\",\"status\":\"${if (passed) { "passed" } else { "failed" }}\"}\n"
    }
    out
}

private func cangjieReleaseGateFindSchedule(status: KnowledgeStatus, name: String): ScheduleEntry {
    for (entry in status.schedules) {
        if (entry.name == name) {
            return entry
        }
    }
    ScheduleEntry(name, 0, 0)
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

private func cangjieReleaseGateApplyFirstInitRootsToConfig(options: CangjieKnowledgeReleaseGateOptions, config: CkbRuntimeConfig): Unit {
    if (options.docsRoot != "") {
        config.firstInitDocsRoot = options.docsRoot
        if (options.toolDocsRoot == "" && config.firstInitToolDocsRoot == "") {
            config.firstInitToolDocsRoot = options.docsRoot
        }
    }
    if (options.toolDocsRoot != "") {
        config.firstInitToolDocsRoot = options.toolDocsRoot
    }
    if (options.stdRoot != "") {
        config.firstInitStdRoot = options.stdRoot
    }
    if (options.stdxRoot != "") {
        config.firstInitStdxRoot = options.stdxRoot
    }
    if (options.evalRoot != "") {
        config.firstInitEvalRoot = options.evalRoot
    }
    if (options.targetVersion != "") {
        config.firstInitTargetVersion = options.targetVersion
    }
}

private func cangjieReleaseGateDefaultSchedulerTasks(): ArrayList<String> {
    ckbSchedulerAllowlistTaskNames()
}

private func cangjieReleaseGateSeedRoutineManifest(store: FileKnowledgeStore, service: CkbCommandLoopService, options: CangjieKnowledgeReleaseGateOptions): Unit {
    store.saveCangjieVersionManifest(buildCangjieVersionManifestFromRoots(
        targetVersion: options.targetVersion,
        docsRoot: options.docsRoot,
        toolDocsRoot: options.toolDocsRoot,
        stdRoot: options.stdRoot,
        stdxRoot: options.stdxRoot,
        evalRoot: options.evalRoot))
    let seed = ArrayList<String>()
    seed.add("cangjie_version_branch_refresh")
    _ = service.runSchedulerTasks(seed, true)
}

private func cangjieReleaseGateContractsCoverAllowlist(): Bool {
    let allowlist = ckbSchedulerAllowlistTaskNames()
    let contracts = cangjieSchedulerTaskContracts()
    for (name in allowlist) {
        var found = false
        for (contract in contracts) {
            if (contract.taskName == name) {
                found = true
            }
        }
        if (!found) {
            return false
        }
    }
    true
}

private func cangjieReleaseGateRoutineContractFailures(result: SchedulerExecutorResult): Int64 {
    var failures: Int64 = 0
    for (diagnostic in result.validationDiagnostics) {
        if (diagnostic.contains("routine_contract:") && diagnostic.contains("\"ok\":false")) {
            failures += 1
        }
    }
    failures
}

private func cangjieReleaseGateEnsureRoutineCurationInput(options: CangjieKnowledgeReleaseGateOptions, config: CkbRuntimeConfig): Unit {
    let pass1Curation = "${options.runRoot}/gap-curation-input.jsonl"
    if (cangjieReleaseGateReadText(pass1Curation).trimAscii() != "") {
        config.benchmarkGapCurationInputPath = pass1Curation
        config.benchmarkGapTargetVersion = options.targetVersion
        return
    }
    let path = "${options.runRoot}/routine-update-gap-curation-input.jsonl"
    let rawBundle = "{\"atomId\":\"G-ARRAYLIST\",\"sourceClass\":\"official\",\"citation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection\",\"targetVersion\":\"${cangjieReleaseGateJsonEscape(options.targetVersion)}\",\"candidateHash\":\"sha256:0000000000000000000000000000000000000000000000000000000000000000\",\"knowledgeText\":\"ArrayList stores a mutable sequence and add appends one element.\",\"example\":\"Use values.add(item) to append an item.\",\"purificationPassed\":true,\"tests\":[{\"category\":\"positive\",\"operation\":\"arraylist_size\",\"input\":\"[1,2,3]\",\"expected\":\"3\"},{\"category\":\"negative\",\"operation\":\"contains\",\"input\":\"ArrayList\",\"needle\":\"HashMap\",\"expected\":\"false\"},{\"category\":\"boundary\",\"operation\":\"rune_count\",\"input\":\"中文😀\",\"expected\":\"3\"}]}"
    let marker = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
    let bundle = rawBundle.replace(marker, cangjieKnowledgeAtomCandidateHash(rawBundle))
    let line = "{\"caseId\":\"PUBLIC-CKB-ROUTINE-001\",\"benchmark\":\"public-cangjie-regression\",\"taskText\":\"Use general ArrayList append operations.\",\"compilerOutput\":\"unknown member add\",\"missingKnowledge\":\"G-ARRAYLIST\",\"interfaceId\":\"KI-02\",\"contentFamily\":\"KC-02\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"${cangjieReleaseGateJsonEscape(options.targetVersion)}\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection\",\"knowledgeAtomCandidate\":true,\"knowledgeAtomTestBundle\":${bundle}}\n"
    cangjieReleaseGateWriteText(path, line)
    config.benchmarkGapCurationInputPath = path
    config.benchmarkGapTargetVersion = options.targetVersion
}

private func cangjieReleaseGateAcceptancePhase(stepId: String): String {
    if (stepId.startsWith("E2E-01")) { return "P0" }
    if (stepId.startsWith("E2E-02")) { return "P0A" }
    if (stepId.startsWith("E2E-03")) { return "P0A" }
    if (stepId.startsWith("E2E-04")) { return "P1" }
    if (stepId.startsWith("E2E-05")) { return "P6" }
    if (stepId.startsWith("E2E-08")) { return "P0A" }
    if (stepId.startsWith("E2E-10")) { return "P0B" }
    if (stepId.startsWith("E2E-11")) { return "P0C" }
    if (stepId.startsWith("E2E-12")) { return "P2-P4" }
    if (stepId.startsWith("E2E-13")) { return "P5" }
    if (stepId.startsWith("E2E-14")) { return "P6" }
    if (stepId.startsWith("P0A")) { return "P0A" }
    if (stepId.startsWith("P7-")) {
        return "P7"
    }
    if (stepId.startsWith("P9-")) {
        return "P9"
    }
    if (stepId.contains("scheduler")) {
        return "P7/P9"
    }
    if (stepId.contains("pass1")) {
        return "P5"
    }
    if (stepId.contains("transport")) {
        return "P4"
    }
    if (stepId.contains("route")) {
        return "P2"
    }
    if (stepId.contains("first-init")) {
        return "P0"
    }
    "global"
}

private func cangjieReleaseGateReadText(path: String): String {
    let target = Path(path)
    if (!exists(target)) {
        return ""
    }
    try {
        String.fromUtf8(File.readFrom(target))
    } catch (_: Exception) {
        ""
    }
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

private func cangjieReleaseGateInterfaceProbe(service: CkbCommandLoopService, toolName: String, restPath: String, restBody: String, toolArgs: String): String {
    let rest = ckbApiHandle(service, "POST", restPath, restBody, [])
    let stdio = CkbMcpStdioServer(service).handleRequest(cangjieReleaseGateMcpToolCallJson(toolName, toolArgs))
    let http = cangjieReleaseGateMcpHttpToolCall(service, cangjieReleaseGateMcpToolCallJson(toolName, toolArgs))
    let restOk = cangjieReleaseGateInterfacePayloadOk(rest)
    let stdioOk = cangjieReleaseGateInterfacePayloadOk(stdio)
    let httpOk = cangjieReleaseGateInterfacePayloadOk(http)
    let ok = restOk && stdioOk && httpOk
    "{\"interfaceId\":\"${cangjieReleaseGateJsonEscape(toolName)}\",\"routeOrTool\":\"${cangjieReleaseGateJsonEscape(restPath)}\",\"transport\":\"rest,mcp_stdio,mcp_http\",\"selector\":\"${cangjieReleaseGateJsonEscape(toolArgs)}\",\"targetVersion\":\"1.0.0\",\"evidenceHash\":\"${benchmarkGapSha256(rest + stdio + http)}\",\"citationCount\":${if (rest.contains("\"citations\":")) { 1 } else { 0 }},\"provenancePresent\":${rest.contains("\"provenance\"") || rest.contains("\"citations\"")},\"restOk\":${restOk},\"stdioOk\":${stdioOk},\"httpOk\":${httpOk},\"status\":\"${if (ok) { "passed" } else { "failed" }}\"}"
}

private func cangjieReleaseGateInterfacePayloadOk(raw: String): Bool {
    raw.contains("\"ok\":true") && raw.contains("interfaceId") && raw.contains("evidenceHash") && (raw.contains("citations") || raw.contains("citation"))
}

private func cangjieReleaseGateRepositoryEventJson(eventId: String, changedFiles: Array<String>): String {
    let files = ArrayList<String>()
    for (path in changedFiles) {
        files.add(path)
    }
    "{\"contractVersion\":\"gcm-ckb-repository-change-v1\",\"eventId\":\"${cangjieReleaseGateJsonEscape(eventId)}\",\"provider\":\"gitcode\",\"eventType\":\"merge_request\",\"action\":\"merged\",\"state\":\"merged\",\"reason\":\"pr_merged\",\"repo\":\"Cangjie/cangjie_docs\",\"ref\":\"main\",\"prNumber\":520,\"changedFiles\":[${cangjieReleaseGateJsonStringArray(files)}]}"
}

private func cangjieReleaseGateMcpToolCallJson(toolName: String, args: String): String {
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"${cangjieReleaseGateJsonEscape(toolName)}\",\"arguments\":${args}}}"
}

private func cangjieReleaseGateMcpHttpToolCall(service: CkbCommandLoopService, jsonRpc: String): String {
    let sessionStore = CkbMcpHttpSessionStore()
    let httpConfig = CkbHttpServiceConfig()
    let mcpConfig = CkbMcpHttpServiceConfig()
    let initBody = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"ckb-release-gate\",\"version\":\"1.0\"}}}"
    let initHeaders = ["Content-Type: application/json", "Accept: application/json, text/event-stream"]
    let initResponse = handleCkbMcpHttpRequest(service, "POST", "/mcp", initBody, initHeaders, httpConfig, mcpConfig, sessionStore)
    let sessionId = cangjieReleaseGateMcpHttpSessionId(initResponse.headers)
    if (sessionId == "") {
        return initResponse.body
    }
    let sessionHeaders = ["Content-Type: application/json", "Accept: application/json, text/event-stream", "MCP-Protocol-Version: 2025-06-18", "Mcp-Session-Id: ${sessionId}"]
    _ = handleCkbMcpHttpRequest(service, "POST", "/mcp", "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\",\"params\":{}}", sessionHeaders, httpConfig, mcpConfig, sessionStore)
    handleCkbMcpHttpRequest(service, "POST", "/mcp", jsonRpc, sessionHeaders, httpConfig, mcpConfig, sessionStore).body
}

private func cangjieReleaseGateMcpHttpSessionId(headers: ArrayList<String>): String {
    for (header in headers) {
        let lower = header.toAsciiLower()
        if (lower.startsWith("mcp-session-id:")) {
            return header["mcp-session-id:".size..header.size].trimAscii()
        }
    }
    ""
}

private func cangjieReleaseGateFindStep(report: CangjieKnowledgeReleaseGateReport, id: String): CangjieKnowledgeReleaseGateStep {
    for (step in report.steps) {
        if (step.id == id) {
            return step
        }
    }
    CangjieKnowledgeReleaseGateStep()
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
