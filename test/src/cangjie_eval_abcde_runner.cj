package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashSet}
import std.convert.Parsable
import std.env.getVariable
import std.fs.{Directory, File, Path, exists, canonicalize, rename, remove}
import std.io.*
import std.process.*
import stdx.encoding.base64.*
import stdx.encoding.json.*

// Real Case145 is about 1.51 MiB and Case078 is about 0.21 MiB; 4 MiB leaves replay headroom while bounding untrusted JSONL.
private let CKB_ABCDE_MAX_MODEL_TRANSCRIPT_BYTES: Int64 = 4194304

public class CkbAbcdeGroups {
    public static let A: String = "A-no-ckb"
    public static let B: String = "B-ckb-context"
    public static let C: String = "C-ckb-mcp-stdio"
    public static let D: String = "D-ckb-mcp-http"
    public static let E: String = "E-local-cangjie-docs"
}

public class CkbAbcdeRunnerOptions {
    public var generationProtocol: String = ""
    public var samplesPerCase: Int64 = 0
    public var generateOnly: Bool = false
    public var evaluateFrozen: Bool = false
    public var testSuites: String = ""
    public var runMode: String = "development"
    public var explicitRunMode: Bool = false
    public var datasetVersion: String = ""
    public var candidateVersion: String = ""
    public var knowledgeVersion: String = ""
    public var modelFingerprint: String = "claude-code-glm-5.2"
    public var repoRoot: String = ckbAbcdeDefaultRepoRoot()
    public var runsRoot: String = "/Users/l3gi0n/Downloads/ckbtest"
    public var runId: String = ""
    public var datasetRoot: String = ""
    public var manifestPath: String = ""
    public var ckbBin: String = ""
    public var ckbConfig: String = ""
    public var ckbStore: String = ""
    public var ckbHttpBase: String = "http://127.0.0.1:18890"
    public var claudeBin: String = ""
    public var docsRoot: String = "/Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs"
    public var caseStart: Int64 = 0
    public var caseEnd: Int64 = 163
    public var groups: ArrayList<String> = ArrayList<String>()
    public var preflightOnly: Bool = false
    public var skipClaude: Bool = false
    public var help: Bool = false
    public var agentAttempts: Int64 = 1
    public var providerRetries: Int64 = 0
    public var sdkRetries: Int64 = 0
    public var maxTurns: Int64 = 1
    public var knowledgeRestRetries: Int64 = 0
    public var transportRetries: Int64 = 2
    public var certificationPreflightPath: String = ""
    public var certificationRunManifestPath: String = ""
    public var expectedModelVersion: String = "GLM-5.2"
    public var providerIdentityHash: String = ""
    public var providerIdentityArtifactPath: String = ""
    public var frozenCandidateManifestPath: String = ""
    public var modelTimeoutSeconds: Int64 = 180
    public var modelEffort: String = "low"
    public var modelMaxBudgetUsd: String = ""
    public var modelEffortExplicit: Bool = false
    public var modelMaxBudgetUsdExplicit: Bool = false

    public init() {
        this.datasetRoot = "${this.repoRoot}/test/cangjie_eval/cases/Cangjie-HumanEval"
        this.manifestPath = "${this.repoRoot}/test/cangjie_eval/cangjie_humaneval_manifest.jsonl"
        this.ckbBin = "${this.repoRoot}/target/release/bin/main"
        this.ckbStore = "${this.repoRoot}/ckb-data"
        this.groups.add(CkbAbcdeGroups.A)
        this.groups.add(CkbAbcdeGroups.B)
        this.groups.add(CkbAbcdeGroups.C)
        this.groups.add(CkbAbcdeGroups.D)
        this.groups.add(CkbAbcdeGroups.E)
    }
}

public func ckbAbcdeCertificationBudget(options: CkbAbcdeRunnerOptions): CkbCertificationBudget {
    let budget = CkbCertificationBudget()
    budget.agentAttempts = options.agentAttempts
    budget.providerRetries = options.providerRetries
    budget.sdkRetries = options.sdkRetries
    budget.maxTurns = options.maxTurns
    budget.knowledgeRestRetries = options.knowledgeRestRetries
    budget.transportRetries = options.transportRetries
    budget
}

public func ckbAbcdeCertificationTransportParity(rest: CkbAbcdeParityObservation, stdio: CkbAbcdeParityObservation, http: CkbAbcdeParityObservation): Bool {
    ckbAbcdeParityDiagnostic(rest, stdio, http) == "ok" && rest.evidenceHash != "" && rest.evidenceHash == stdio.evidenceHash && rest.evidenceHash == http.evidenceHash
}

public class CkbAbcdeCommandResult {
    public var exitCode: Int64 = 1
    public var stdout: String = ""
    public var stderr: String = ""

    public init() {}
}

public class CkbAbcdeSingleCompletion {
    public var ok: Bool = false
    public var diagnostic: String = "not_parsed"
    public var solutionCj: String = ""
    public var answerHash: String = ""
    public var completionCount: Int64 = 0
    public var toolCallCount: Int64 = 0
    public init() {}
}

public class CkbAbcdeCompletionCapabilityProbe {
    public var ok: Bool = false
    public var diagnostic: String = "not_run"
    public var samplingControl: String = ""
    public var answerHash: String = ""
    public init() {}
}

public func ckbAbcdeCompletionOptionsDiagnostic(options: CkbAbcdeRunnerOptions): String {
    if (options.generationProtocol != "completion-only-v1") { return "generation_protocol_required" }
    if (options.samplesPerCase != 1) { return "samples_per_case_must_be_one" }
    if (options.generateOnly == options.evaluateFrozen) { return "generation_phase_must_be_explicit" }
    if (options.generateOnly && options.testSuites != "") { return "generation_test_suites_forbidden" }
    if (options.evaluateFrozen && options.testSuites != "base" && options.testSuites != "plus" &&
        options.testSuites != "base,plus") { return "frozen_test_suites_invalid" }
    "ok"
}

public func applyCkbAbcdeFrozenRunManifest(options: CkbAbcdeRunnerOptions,
    bytes: Array<UInt8>): String {
    let raw = try { String.fromUtf8(bytes) } catch (_: Exception) { return "run_manifest_invalid_encoding" }
    try {
        let object = JsonValue.fromStr(raw).asObject()
        let protocol = ckbAbcdeManifestString(object, "generationProtocol")
        let samples = ckbAbcdeManifestInt(object, "samplesPerCase")
        let dataset = ckbAbcdeManifestString(object, "datasetVersion")
        let knowledge = ckbAbcdeManifestString(object, "knowledgeVersion")
        let model = ckbAbcdeManifestString(object, "modelVersion")
        let provider = ckbAbcdeManifestString(object, "providerIdentityHash")
        let bundleHash = ckbAbcdeManifestString(object, "skillBundleHash")
        let samplingHash = ckbAbcdeManifestString(object, "samplingCapabilityHash")
        let schemaHash = ckbAbcdeManifestString(object, "outputSchemaHash")
        if (protocol != "completion-only-v1" || samples != 1 || !ckbAbcdePlainHash(bundleHash) ||
            !ckbAbcdePlainHash(samplingHash) || !ckbAbcdePlainHash(schemaHash)) {
            return "run_manifest_completion_contract_invalid"
        }
        if ((options.datasetVersion != "" && options.datasetVersion != dataset) ||
            (options.knowledgeVersion != "" && options.knowledgeVersion != knowledge) ||
            (options.expectedModelVersion != "" && options.expectedModelVersion != model) ||
            (options.providerIdentityHash != "" && options.providerIdentityHash != provider) ||
            (options.generationProtocol != "" && options.generationProtocol != protocol) ||
            (options.samplesPerCase != 0 && options.samplesPerCase != samples)) {
            return "run_manifest_cli_identity_drift"
        }
        options.datasetVersion=dataset;options.knowledgeVersion=knowledge;options.expectedModelVersion=model
        options.providerIdentityHash=provider;options.generationProtocol=protocol;options.samplesPerCase=samples
        "ok"
    } catch (_: Exception) { "run_manifest_malformed_json" }
}

public func ckbAbcdeExtractSingleCompletion(bytes: Array<UInt8>): CkbAbcdeSingleCompletion {
    let result = CkbAbcdeSingleCompletion()
    if (bytes.size > CKB_ABCDE_MAX_MODEL_TRANSCRIPT_BYTES) { result.diagnostic="transcript_too_large";return result }
    let raw = try { String.fromUtf8(bytes) } catch (_: Exception) { result.diagnostic="invalid_response_encoding";return result }
    if (raw.contains("```")) { result.diagnostic="generation_protocol_violation";return result }
    try {
        let terminal=JsonValue.fromStr(raw.trimAscii()).asObject()
        if(ckbAbcdeManifestString(terminal,"type")!="result"||ckbAbcdeManifestString(terminal,"subtype")!="success"||
            terminal.get("is_error").getOrThrow().asBool().getValue()){result.diagnostic="completion_unsuccessful_result";return result}
        let usage=terminal.get("modelUsage").getOrThrow().asObject()
        if(usage.getFields().size!=1){result.diagnostic="completion_observed_model_mismatch";return result}
        match(usage.get("GLM-5.2")){case Some(_)=>() case None=>result.diagnostic="completion_observed_model_mismatch";return result}
        let object=terminal.get("structured_output").getOrThrow().asObject()
        if (object.getFields().size != 1 || raw.split("\"solution_cj\"").size != 2) {
            result.diagnostic="completion_schema_invalid";return result
        }
        let solution=ckbAbcdeManifestString(object,"solution_cj")
        if (solution.toArray().size > 262144) { result.diagnostic="solution_too_large";return result }
        if (solution == "") { result.diagnostic="completion_empty";return result }
        result.ok=true;result.diagnostic="ok";result.solutionCj=solution
        result.answerHash=benchmarkGapSha256(solution);result.completionCount=1
        result
    } catch (_: Exception) { result.diagnostic="malformed_json";result }
}

public func ckbAbcdeFreezeCompletion(caseRoot: String, completion: CkbAbcdeSingleCompletion): String {
    if (!completion.ok || completion.completionCount != 1 || completion.toolCallCount != 0 ||
        completion.answerHash != benchmarkGapSha256(completion.solutionCj)) { return "completion_not_freezable" }
    let root=Path(caseRoot)
    if (exists(root)) { return "completion_already_frozen" }
    let stage=Path("${caseRoot}.stage-${completion.answerHash.replace("sha256:","")}")
    try {
        if(exists(stage)){remove(stage,recursive:true)};Directory.create(stage,recursive:true)
        let payload="{\"solution_cj\":\"${ckbAbcdeJsonEscape(completion.solutionCj)}\"}"
        File.writeTo(stage.join("completion.txt"),payload.toArray());File.writeTo(stage.join("solution.cj"),completion.solutionCj.toArray())
        let committed=String.fromUtf8(File.readFrom(stage.join("solution.cj")))
        if (benchmarkGapSha256(committed)!=completion.answerHash) { remove(stage,recursive:true);return "completion_freeze_hash_mismatch" }
        rename(stage.toString(),to:root.toString(),overwrite:false)
        "ok"
    } catch (_: Exception) { try{if(exists(stage)){remove(stage,recursive:true)}}catch(_:Exception){};"completion_freeze_failed" }
}

private func ckbAbcdeInstallFrozenSolution(workspace:String,completion:CkbAbcdeSingleCompletion):String{
    let target=Path(workspace).join("src/solution.cj");let tmp=Path(workspace).join("src/.solution.cj.tmp-${completion.answerHash.replace("sha256:","")}")
    try{File.writeTo(tmp,completion.solutionCj.toArray());let checked=String.fromUtf8(File.readFrom(tmp));if(benchmarkGapSha256(checked)!=completion.answerHash){remove(tmp);return "completion_install_hash_mismatch"};rename(tmp.toString(),to:target.toString(),overwrite:true);"ok"}
    catch(_:Exception){try{if(exists(tmp)){remove(tmp)}}catch(_:Exception){};"completion_install_failed"}
}

public func ckbAbcdeCompletionOutputSchema():String{"{\"type\":\"object\",\"additionalProperties\":false,\"required\":[\"solution_cj\"],\"properties\":{\"solution_cj\":{\"type\":\"string\"}}}"}

public func ckbAbcdeRunCompletionCapabilityProbe(command: String, transcript: Array<UInt8>,
    samplingControl: String): CkbAbcdeCompletionCapabilityProbe {
    let probe=CkbAbcdeCompletionCapabilityProbe()
    for (flag in ["--bare", "--tools ''", "--disable-slash-commands", "--setting-sources ''",
        "--strict-mcp-config", "--max-turns 1", "--json-schema"]) {
        if (!command.contains(flag)) { probe.diagnostic="capability_command_contract_invalid";return probe }
    }
    if (samplingControl!="temperature_zero" && samplingControl!="provider_default_not_client_exposed") {
        probe.diagnostic="sampling_capability_invalid";return probe
    }
    let completion=ckbAbcdeExtractSingleCompletion(transcript)
    if (!completion.ok) { probe.diagnostic=completion.diagnostic;return probe }
    probe.ok=true;probe.diagnostic="ok";probe.samplingControl=samplingControl;probe.answerHash=completion.answerHash
    probe
}

private func ckbAbcdeManifestString(object:JsonObject,key:String):String{object.get(key).getOrThrow().asString().getValue()}
private func ckbAbcdeManifestInt(object:JsonObject,key:String):Int64{object.get(key).getOrThrow().asInt().getValue()}
private func ckbAbcdePlainHash(value:String):Bool{if(value.toRuneArray().size!=64){return false};for(c in value.toRuneArray()){if(!((c>=r'0'&&c<=r'9')||(c>=r'a'&&c<=r'f'))){return false}};true}

public class CkbAbcdeClaudeExecutable {
    public var valid: Bool = false
    public var requested: String = ""
    public var canonical: String = ""
    public var diagnostic: String = "claude_executable_missing"
    public init() {}
}

public func ckbAbcdeResolveClaudeExecutable(requested: String): CkbAbcdeClaudeExecutable {
    let result = CkbAbcdeClaudeExecutable()
    result.requested = requested.trimAscii()
    if (result.requested == "") { return result }
    if (!result.requested.startsWith("/")) {
        result.diagnostic = "claude_executable_must_be_absolute"
        return result
    }
    if (!exists(Path(result.requested))) {
        result.diagnostic = "claude_executable_not_found"
        return result
    }
    result.canonical = try {
        canonicalize(Path(result.requested)).toString()
    } catch (_: Exception) {
        result.diagnostic = "claude_executable_canonicalize_failed"
        return result
    }
    let installRoot = try {
        canonicalize(Path(result.requested).parent.parent).toString()
    } catch (_: Exception) {
        result.diagnostic = "claude_executable_install_root_invalid"
        return result
    }
    if (result.canonical != result.requested &&
        result.canonical != installRoot && !result.canonical.startsWith("${installRoot}/")) {
        result.diagnostic = "claude_executable_symlink_escape"
        result.canonical = ""
        return result
    }
    if (ckbAbcdeRunShell("/bin/test -x ${ckbAbcdeShellQuote(result.canonical)}", "").exitCode != 0) {
        result.diagnostic = "claude_executable_not_executable"
        result.canonical = ""
        return result
    }
    result.valid = true
    result.diagnostic = "ok"
    result
}

public class CkbAbcdeSampleAssessment {
    public var completeResult: Bool = false
    public var identityMatched: Bool = false
    public var sampleAttempt: Int64 = 0
    public var transcriptDiagnostic: String = "ok"
    public var toolEventCount: Int64 = 0
    public var toolFailureCount: Int64 = 0
    public var terminalResultCount: Int64 = 0
    public init() {}
}

public class CkbAbcdeBoundedTextRead {
    public var ok: Bool = false
    public var text: String = ""
    public var diagnostic: String = "artifact_read_failed"
    public var contentHash: String = ""
    public init() {}
}

public class CkbAbcdeUsageStats {
    public var usageParseStatus: String = "missing_result"
    public var modelInputTokens: Int64 = 0
    public var modelOutputTokens: Int64 = 0
    public var modelCacheReadTokens: Int64 = 0
    public var modelCacheCreationTokens: Int64 = 0
    public var modelTotalTokens: Int64 = 0
    public var llmTurnCount: Int64 = 0
    public var usageSourcePath: String = ""

    public init() {}
}

public class CkbAbcdePreflightResult {
    public var ok: Bool = true
    public var checks: ArrayList<String> = ArrayList<String>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func add(name: String, passed: Bool, diagnostic: String): Unit {
        this.checks.add("{\"name\":\"${ckbAbcdeJsonEscape(name)}\",\"ok\":${passed},\"diagnostic\":\"${ckbAbcdeJsonEscape(diagnostic)}\"}")
        if (!passed) {
            this.ok = false
            this.diagnostics.add("${name}: ${diagnostic}")
        }
    }
}

public class CkbAbcdeParityObservation {
    public var caseId: String = ""
    public var interfaceId: String = "cangjie_task_knowledge_pack"
    public var transport: String = ""
    public var ok: Bool = false
    public var evidenceHash: String = ""
    public var coveragePass: Bool = false
    public var citationCount: Int64 = 0
    public var diagnostic: String = ""
    public var payloadPath: String = ""

    public init() {}
}

public class CkbAbcdeParityReport {
    public var caseId: String = ""
    public var interfaceId: String = "cangjie_task_knowledge_pack"
    public var ok: Bool = false
    public var diagnostic: String = ""
    public var rest: CkbAbcdeParityObservation = CkbAbcdeParityObservation()
    public var stdio: CkbAbcdeParityObservation = CkbAbcdeParityObservation()
    public var http: CkbAbcdeParityObservation = CkbAbcdeParityObservation()

    public init() {}
}

public class CkbAbcdeTaskContext {
    public var taskId: String = ""
    public var benchmark: String = "Cangjie-HumanEval"
    public var taskText: String = ""
    public var signature: String = ""
    public var datasetVersion: String = ""
    public var promptHash: String = ""
    public var starterHash: String = ""
    public var targetVersion: String = "1.0.0"
    public var sourceSet: String = CangjieSourceSets.ALL
    public var versionPolicy: String = CangjieVersionPolicies.DEFAULT
    public var expectedKnowledgeTags: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CkbAbcdeTaskKnowledgeEvidence {
    public var valid: Bool = false
    public var diagnostic: String = "task_knowledge_tool_use_missing"
    public var evidenceHash: String = ""
    public var knowledgeVersion: String = ""
    public var coveragePass: Bool = false
    public var citationCount: Int64 = 0
    public var requestBindingHash: String = ""

    public init() {}
}

public func parseCkbAbcdeRunnerOptions(args: Array<String>): CkbAbcdeRunnerOptions {
    let options = CkbAbcdeRunnerOptions()
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "cangjie-eval-abcde") {
            i += 1
            continue
        }
        if (arg == "--help" || arg == "-h") {
            options.help = true
            i += 1
            continue
        }
        if (arg == "--preflight-only") {
            options.preflightOnly = true
            i += 1
            continue
        }
        if (arg == "--skip-claude") {
            options.skipClaude = true
            i += 1
            continue
        }
        if (arg == "--generate-only") { options.generateOnly = true; i += 1; continue }
        if (arg == "--evaluate-frozen") { options.evaluateFrozen = true; i += 1; continue }
        if (arg == "--generation-protocol" && i + 1 < args.size) { options.generationProtocol = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--samples-per-case" && i + 1 < args.size) { options.samplesPerCase = ckbAbcdeParseInt(args[i + 1], -1); i += 2; continue }
        if (arg == "--test-suites" && i + 1 < args.size) { options.testSuites = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--run-mode" && i + 1 < args.size) { options.runMode = args[i + 1].trimAscii(); options.explicitRunMode = true; i += 2; continue }
        if (arg == "--dataset-version" && i + 1 < args.size) { options.datasetVersion = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--candidate-version" && i + 1 < args.size) { options.candidateVersion = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--knowledge-version" && i + 1 < args.size) { options.knowledgeVersion = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--model-fingerprint" && i + 1 < args.size) { options.modelFingerprint = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--certification-preflight" && i + 1 < args.size) { options.certificationPreflightPath = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--certification-run-manifest" && i + 1 < args.size) { options.certificationRunManifestPath = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--expected-model-version" && i + 1 < args.size) { options.expectedModelVersion = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--provider-identity-hash" && i + 1 < args.size) { options.providerIdentityHash = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--provider-identity-artifact" && i + 1 < args.size) { options.providerIdentityArtifactPath = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--frozen-candidate-manifest" && i + 1 < args.size) { options.frozenCandidateManifestPath = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--transport-retries" && i + 1 < args.size) { options.transportRetries = ckbAbcdeParseInt(args[i + 1], -1); i += 2; continue }
        if (arg == "--model-timeout-seconds" && i + 1 < args.size) { options.modelTimeoutSeconds = ckbAbcdeParseInt(args[i + 1], -1); i += 2; continue }
        if (arg == "--model-effort" && i + 1 < args.size) { options.modelEffort = args[i + 1].trimAscii(); options.modelEffortExplicit = true; i += 2; continue }
        if (arg == "--model-max-budget-usd" && i + 1 < args.size) { options.modelMaxBudgetUsd = args[i + 1].trimAscii(); options.modelMaxBudgetUsdExplicit = true; i += 2; continue }
        if (arg == "--run-id" && i + 1 < args.size) {
            options.runId = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--repo-root" && i + 1 < args.size) {
            options.repoRoot = args[i + 1].trimAscii()
            options.datasetRoot = "${options.repoRoot}/test/cangjie_eval/cases/Cangjie-HumanEval"
            options.manifestPath = "${options.repoRoot}/test/cangjie_eval/cangjie_humaneval_manifest.jsonl"
            options.ckbBin = "${options.repoRoot}/target/release/bin/main"
            options.ckbStore = "${options.repoRoot}/ckb-data"
            i += 2
            continue
        }
        if (arg == "--runs-root" && i + 1 < args.size) {
            options.runsRoot = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--dataset-root" && i + 1 < args.size) {
            options.datasetRoot = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--manifest" && i + 1 < args.size) {
            options.manifestPath = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--ckb-bin" && i + 1 < args.size) {
            options.ckbBin = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--config" && i + 1 < args.size) {
            options.ckbConfig = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if ((arg == "--ckb-store" || arg == "--store") && i + 1 < args.size) {
            options.ckbStore = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--ckb-http-base" && i + 1 < args.size) {
            options.ckbHttpBase = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--claude-bin" && i + 1 < args.size) {
            options.claudeBin = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--docs-root" && i + 1 < args.size) {
            options.docsRoot = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--case-start" && i + 1 < args.size) {
            options.caseStart = ckbAbcdeParseInt(args[i + 1], options.caseStart)
            i += 2
            continue
        }
        if (arg == "--case-end" && i + 1 < args.size) {
            options.caseEnd = ckbAbcdeParseInt(args[i + 1], options.caseEnd)
            i += 2
            continue
        }
        if (arg == "--case-id" && i + 1 < args.size) {
            let parsed = ckbAbcdeParseCaseIndex(args[i + 1])
            options.caseStart = parsed
            options.caseEnd = parsed
            i += 2
            continue
        }
        if (arg == "--groups" && i + 1 < args.size) {
            options.groups = ckbAbcdeParseGroups(args[i + 1])
            i += 2
            continue
        }
        i += 1
    }
    options
}

public func runCangjieEvalAbcde(args: Array<String>): Int64 {
    let usage = ckbAbcdeStrictUsageDiagnostic(args)
    if (usage != "ok") { println("usage error: ${usage}"); return 2 }
    let options = parseCkbAbcdeRunnerOptions(args)
    if (options.help) {
        print(ckbAbcdeUsage())
        return 0
    }
    if (options.runMode == "certification") {
        if (!exists(Path(options.certificationRunManifestPath))) { println("ABCDE certification start blocked: run_manifest_missing"); return 1 }
        let manifestBytes=try{File.readFrom(Path(options.certificationRunManifestPath))}catch(_:Exception){println("ABCDE certification start blocked: run_manifest_unreadable");return 1}
        let manifestDiagnostic=applyCkbAbcdeFrozenRunManifest(options,manifestBytes)
        if(manifestDiagnostic!="ok"){println("ABCDE certification start blocked: ${manifestDiagnostic}");return 1}
        let completionDiagnostic=ckbAbcdeCompletionOptionsDiagnostic(options)
        if(completionDiagnostic!="ok"){println("ABCDE certification start blocked: ${completionDiagnostic}");return 1}
    }
    let developmentContract = ckbAbcdeDevelopmentOptionsDiagnostic(options)
    if (developmentContract != "") { println("usage error: ${developmentContract}"); return 2 }
    if (options.runId == "") {
        options.runId = "abcde-${ckbAbcdeGeneratedRunId()}"
    }
    let safetyDiagnostic = ckbAbcdeOptionsSafetyDiagnostic(options)
    if (safetyDiagnostic != "ok") {
        println("ABCDE safety check failed: ${safetyDiagnostic}")
        return 1
    }
    let runRoot = "${options.runsRoot}/${options.runId}"
    if (options.runMode == "certification") {
        let certificationDiagnostic = ckbAbcdeCertificationEntryDiagnostic(options, runRoot)
        if (certificationDiagnostic != "ok") {
            println("ABCDE certification start blocked: ${certificationDiagnostic}")
            return 1
        }
    }
    ckbAbcdeEnsureDir(runRoot)
    if (options.runMode == "certification") {
        // Preserve exact trusted inputs in the immutable run evidence. Do not
        // rerun the legacy development preflight or synthesize replacements.
        ckbAbcdeWriteText("${runRoot}/preflight.json", ckbAbcdeReadText(options.certificationPreflightPath))
        ckbAbcdeWriteText("${runRoot}/run-manifest.json", ckbAbcdeReadText(options.certificationRunManifestPath))
        ckbAbcdeWriteText("${runRoot}/provider-identity.json",ckbAbcdeReadText(options.providerIdentityArtifactPath))
        ckbAbcdeWriteText("${runRoot}/frozen-candidate-manifest.json",ckbAbcdeReadText(options.frozenCandidateManifestPath))
        options.certificationPreflightPath="${runRoot}/preflight.json"
        options.certificationRunManifestPath="${runRoot}/run-manifest.json"
        options.providerIdentityArtifactPath="${runRoot}/provider-identity.json"
        options.frozenCandidateManifestPath="${runRoot}/frozen-candidate-manifest.json"
    } else {
        let preflight = ckbAbcdePreflight(options, runRoot)
        ckbAbcdeWriteText("${runRoot}/preflight.json", ckbAbcdeRenderPreflightJson(options, runRoot, preflight))
        ckbAbcdeWriteText("${runRoot}/preflight.md", ckbAbcdeRenderPreflightMarkdown(options, runRoot, preflight))
        if (!preflight.ok) {
            println("ABCDE preflight failed: ${runRoot}/preflight.md")
            return 1
        }
        if (options.preflightOnly) {
            println("ABCDE preflight ok: ${runRoot}")
            return 0
        }
    }

    if (options.runMode == "certification") {
        let portDiagnostic = ckbAbcdeCertificationPortDiagnostic(options.ckbHttpBase)
        if (portDiagnostic != "ok") { println("ABCDE certification start blocked: ${portDiagnostic}"); return 1 }
        let binaryHash=ckbAbcdeBinaryHash(options.ckbBin);if(!ckbAbcdeStrictSha256(binaryHash)){println("ABCDE certification start blocked: certification_http_binary_hash_failed");return 1}
        let launchSpecHash=ckbAbcdeCertificationHttpLaunchSpecHash(binaryHash,options.ckbConfig,options.ckbStore,runRoot,options.ckbHttpBase)
        let commandHash=benchmarkGapSha256(ckbAbcdeCertificationHttpLaunchScript(options.ckbBin,options.ckbConfig,options.ckbStore,runRoot))
        try{let manifest=JsonValue.fromStr(ckbAbcdeReadText(options.certificationRunManifestPath)).asObject();if(ckbAbcdeStrictJsonString(manifest,"certificationBinaryHash")!=binaryHash||ckbAbcdeStrictJsonString(manifest,"certificationHttpLaunchSpecHash")!=launchSpecHash||ckbAbcdeStrictJsonString(manifest,"certificationHttpCommandHash")!=commandHash){println("ABCDE certification start blocked: certification_http_provenance_mismatch");return 1}}catch(_:Exception){println("ABCDE certification start blocked: certification_http_provenance_malformed");return 1}
        let serviceCommand=ckbAbcdeCertificationHttpLaunchScript(options.ckbBin,options.ckbConfig,options.ckbStore,runRoot)
        let process = try {
            launch("/bin/zsh", ["-lc", serviceCommand], stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
        } catch (_: Exception) { println("ABCDE certification start blocked: certification_http_launch_failed"); return 1 }
        let owner = "{\"schemaVersion\":\"ckb-certification-http-owner-v1\",\"pid\":${process.pid},\"binaryHash\":\"${binaryHash}\",\"launchSpecHash\":\"${launchSpecHash}\",\"commandHash\":\"${commandHash}\"}"
        ckbAbcdeWriteText("${runRoot}/certification-http-owner.json", owner)
        var caseExit:Int64=1
        try {
            let ready = ckbAbcdeWaitForCertificationIdentity(options,runRoot)
            if (ready != "ok") { println("ABCDE certification start blocked: ${ready}"); return 1 }
            caseExit=ckbAbcdeRunCases(options, runRoot)
        } finally {
            let stopMethod=ckbAbcdeStopOwnedCertificationHttpWithEscalation(process.pid)
            _ = try { process.wait() } catch (_: Exception) { -1 }
            ckbAbcdeWriteText("${runRoot}/certification-http-stopped.json", "{\"schemaVersion\":\"ckb-certification-http-stop-v1\",\"pid\":${process.pid},\"stopMethod\":\"${stopMethod}\",\"aliveAfterStop\":${ckbAbcdePidAlive(process.pid)}}")
        }
        if(caseExit==0&&!ckbAbcdeWriteRunnerProvenance(options,runRoot,binaryHash,launchSpecHash,commandHash)){println("ABCDE certification failed: runner_provenance_write_failed");return 1}
        return caseExit
    }
    ckbAbcdeRunCases(options, runRoot)
}

private func ckbAbcdeRunCases(options: CkbAbcdeRunnerOptions, runRoot: String): Int64 {
    ckbAbcdeWriteText("${runRoot}/case-usage-summary.csv", "caseId,usageParseOkGroupCount,caseTotalModelTokens,caseAverageModelTokensPerGroup,caseTotalLlmTurns,caseAverageLlmTurnsPerGroup,usageParseFailedGroups\n")
    var failed: Int64 = 0
    var caseIndex = options.caseStart
    while (caseIndex <= options.caseEnd) {
        if(options.runMode=="certification"&&ckbAbcdeFrozenPointerDiagnostic(FileKnowledgeStore(options.ckbStore),ckbAbcdeReadText(options.frozenCandidateManifestPath))!="ok"){println("ABCDE certification blocked: frozen_candidate_store_drift_before_case");return 1}
        let caseId = ckbAbcdeCaseId(caseIndex)
        let caseRoot = "${runRoot}/cases/${caseId}"
        ckbAbcdeEnsureDir(caseRoot)
        let summaries = ArrayList<String>()
        var previousGroup = ""
        for (group in options.groups) {
            let resultLine = ckbAbcdeRunCaseGroup(options, runRoot, caseId, group, previousGroup)
            summaries.add(resultLine)
            ckbAbcdeAppendText("${runRoot}/results.jsonl", "${resultLine}\n")
            if (resultLine.contains("\"status\":\"failed\"")) {
                failed += 1
            }
            previousGroup = group
        }
        ckbAbcdeWriteText("${caseRoot}/case-summary.json", ckbAbcdeRenderCaseSummary(options, runRoot, caseId, summaries))
        ckbAbcdeAppendText("${runRoot}/case-usage-summary.csv", ckbAbcdeRenderCaseUsageSummaryCsvRow(caseId, summaries) + "\n")
        if(options.runMode=="certification"&&ckbAbcdeFrozenPointerDiagnostic(FileKnowledgeStore(options.ckbStore),ckbAbcdeReadText(options.frozenCandidateManifestPath))!="ok"){println("ABCDE certification blocked: frozen_candidate_store_drift_after_case");return 1}
        caseIndex += 1
    }
    if (options.explicitRunMode && options.runMode == "development" && options.caseStart == 0 && options.caseEnd == 163) {
        let aggregate = aggregateDevelopmentRun(options, runRoot)
        if (!aggregate.ok) { failed += 1 }
    }
    ckbAbcdeWriteSummary(runRoot)
    if(options.runMode=="certification"&&ckbFrozenCandidateManifestDiagnostic(FileKnowledgeStore(options.ckbStore),ckbAbcdeReadText(options.frozenCandidateManifestPath))!="ok"){println("ABCDE certification blocked: frozen_candidate_store_drift_at_end");return 1}
    let pass1GateOk = ckbAbcdeWritePass1GateArtifactsIfFullRun(options, runRoot)
    println("ABCDE run complete: ${runRoot}")
    if (failed > 0 || !pass1GateOk) { 1 } else { 0 }
}

public func ckbAbcdeCertificationPortDiagnostic(base: String): String {
    if (!base.startsWith("http://127.0.0.1:") && !base.startsWith("http://localhost:")) { return "certification_http_loopback_required" }
    let occupied = ckbAbcdeRunShell("curl --max-time 1 -sS -o /dev/null ${ckbAbcdeShellQuote(base+"/v1/certification/identity")} >/dev/null 2>&1", "")
    if (occupied.exitCode == 0) { "certification_http_port_already_owned" } else { "ok" }
}

private func ckbAbcdeWaitForCertificationIdentity(options: CkbAbcdeRunnerOptions,runRoot:String): String {
    let frozen = try { JsonValue.fromStr(ckbAbcdeReadText(options.frozenCandidateManifestPath)).asObject() } catch (_: Exception) { return "frozen_candidate_manifest_invalid" }
    let version = ckbAbcdeStrictJsonString(frozen, "knowledgeVersion")
    let pointer = ckbAbcdeStrictJsonString(frozen, "activePointerHash")
    let checksum = ckbAbcdeStrictJsonString(frozen, "candidateChecksum")
    let deadline = ckbCoreNowMillis() + ckbAbcdeCertificationReadinessDeadlineMillis()
    while (ckbCoreNowMillis() < deadline) {
        let maxTimeSeconds = ckbAbcdeCertificationProbeMaxTimeSeconds(
            deadline - ckbCoreNowMillis())
        if (maxTimeSeconds <= 0) { break }
        let response = ckbAbcdeRunShell("curl --connect-timeout 1 --max-time ${maxTimeSeconds} -fsS ${ckbAbcdeShellQuote(options.ckbHttpBase+"/v1/certification/identity")}", "")
        if (response.exitCode == 0) {
            let diagnostic = ckbAbcdeCertificationIdentityResponseDiagnostic(
                response.stdout, version, pointer, checksum)
            if (diagnostic == "ok") {
                ckbAbcdeWriteText("${runRoot}/certification-http-identity.json",response.stdout)
            }
            return diagnostic
        }
        _ = ckbAbcdeRunShell("sleep 0.10", "")
    }
    "certification_http_not_ready"
}

public func ckbAbcdeCertificationReadinessDeadlineMillis(): Int64 { 300000 }
public func ckbAbcdeDevelopmentToolProbeTimeoutSeconds(): Int64 { 30 }
public func ckbAbcdeCertificationProbeMaxTimeSeconds(remainingMillis: Int64): Int64 {
    if (remainingMillis < 1000) { return 0 }
    let remainingSeconds = remainingMillis / 1000
    if (remainingSeconds > 30) { 30 } else { remainingSeconds }
}

public func ckbAbcdeCertificationIdentityResponseDiagnostic(raw: String, version: String,
    pointer: String, checksum: String): String {
    try {
        let root = JsonValue.fromStr(raw).asObject()
        if (!ckbAbcdeStrictJsonBool(root, "ok")) {
            return "certification_http_identity_mismatch"
        }
        let data = root.get("data").getOrThrow().asObject()
        if (ckbAbcdeStrictJsonString(data, "activeVersion") != version ||
            ckbAbcdeStrictJsonString(data, "pointerIdentityHash") != pointer ||
            ckbAbcdeStrictJsonString(data, "candidateChecksum") != checksum) {
            return "certification_http_identity_mismatch"
        }
        "ok"
    } catch (_: Exception) { "certification_http_identity_malformed" }
}

public func ckbAbcdeFrozenPointerDiagnostic(store: FileKnowledgeStore,
    manifestJson: String): String {
    if (ckbFrozenCandidateManifestIntegrityDiagnostic(manifestJson) != "ok") {
        return "frozen_candidate_store_drift"
    }
    try {
        let manifest = JsonValue.fromStr(manifestJson).asObject()
        let pointer = store.loadActiveSnapshotPointer()
        if (!pointer.valid ||
            ckbAbcdeStrictJsonString(manifest, "knowledgeVersion") != pointer.activeVersion ||
            ckbAbcdeStrictJsonString(manifest, "txIdHash") != benchmarkGapSha256(pointer.txId) ||
            ckbAbcdeStrictJsonString(manifest, "activePointerHash") !=
                ckbActiveSnapshotPointerIdentityHash(pointer)) {
            return "frozen_candidate_store_drift"
        }
        "ok"
    } catch (_: Exception) { "frozen_candidate_store_drift" }
}

public func ckbAbcdeBinaryHash(path: String): String {
    let result=ckbAbcdeRunShell("shasum -a 256 ${ckbAbcdeShellQuote(path)}","");if(result.exitCode!=0){return ""};let fields=result.stdout.trimAscii().split(" ");if(fields.size==0||fields[0].toRuneArray().size!=64){return ""};"sha256:${fields[0]}"
}
public func ckbAbcdeCertificationHttpLaunchSpecHash(binaryHash:String,config:String,store:String,runRoot:String,httpBase:String):String{
    if(!ckbAbcdeStrictSha256(binaryHash)){return ""}
    let configHash=ckbAbcdeBinaryHash(config);if(!ckbAbcdeStrictSha256(configHash)){return ""}
    try{
        let configPath=canonicalize(Path(config)).toString();let storePath=canonicalize(Path(store)).toString();let rootPath=canonicalize(Path(runRoot)).toString()
        if(ckbAbcdeCertificationPortDiagnostic(httpBase)!="ok"){return ""};benchmarkGapSha256("ckb-certification-http-launch-v1|${binaryHash}|${configHash}|${configPath}|${storePath}|${rootPath}|${httpBase}")
    }catch(_:Exception){""}
}
private func ckbAbcdeWriteRunnerProvenance(options:CkbAbcdeRunnerOptions,runRoot:String,runnerBinaryHash:String,launchSpecHash:String,commandHash:String):Bool{
    try{
        let manifest=ckbAbcdeReadText("${runRoot}/run-manifest.json");let manifestObject=JsonValue.fromStr(manifest).asObject();let runManifestHash=ckbAbcdeStrictJsonString(manifestObject,"runManifestHash")
        let authority=ckbAbcdeReadText(options.manifestPath);let results=ckbAbcdeReadText("${runRoot}/results.jsonl");var count:Int64=0;for(line in results.split("\n")){if(line.trimAscii()!=""){count+=1}}
        let canonicalRoot=canonicalize(Path(runRoot)).toString();let provenance="{\"schemaVersion\":\"ckb-certification-runner-provenance-v1\",\"runId\":\"${ckbAbcdeJsonEscape(options.runId)}\",\"canonicalRunRootHash\":\"${benchmarkGapSha256(canonicalRoot)}\",\"runManifestHash\":\"${runManifestHash}\",\"runnerBinaryHash\":\"${runnerBinaryHash}\",\"launchSpecHash\":\"${launchSpecHash}\",\"commandHash\":\"${commandHash}\",\"authorityHash\":\"${benchmarkGapSha256(authority)}\",\"caseCount\":${count},\"resultManifestHash\":\"${benchmarkGapSha256(results)}\"}"
        ckbAbcdeWriteText("${runRoot}/runner-provenance.json",provenance);true
    }catch(_:Exception){false}
}
public func ckbAbcdeCertificationHttpLaunchScript(bin:String,config:String,store:String,runRoot:String):String{ckbAbcdeNativeTlsBootstrapScript(bin,["certification-http","--config",config,"--store",store])+" > ${ckbAbcdeShellQuote(runRoot+"/certification-http.stdout.log")} 2> ${ckbAbcdeShellQuote(runRoot+"/certification-http.stderr.log")}"}

private func ckbAbcdePidAlive(pid: Int64): Bool {
    pid > 0 && ckbAbcdeRunShell("/bin/kill -0 ${pid} 2>/dev/null", "").exitCode == 0
}
public func ckbAbcdeStopOwnedCertificationHttpWithEscalation(pid:Int64):String{if(pid<=0){return "invalid"};let term=ckbAbcdeRunShell("/bin/kill -TERM ${pid} 2>/dev/null","").exitCode;if(term!=0){return "not_running"};var i:Int64=0;while(i<50&&ckbAbcdePidAlive(pid)){_=ckbAbcdeRunShell("sleep 0.01","");i+=1};if(ckbAbcdePidAlive(pid)){_=ckbAbcdeRunShell("/bin/kill -KILL ${pid} 2>/dev/null","");"kill"}else{"term"}}
public func ckbAbcdeStopOwnedCertificationHttp(pid:Int64):Bool{let method=ckbAbcdeStopOwnedCertificationHttpWithEscalation(pid);method=="term"||method=="kill"}

// Certification is an auditable one-shot operation.  Silently ignored or
// duplicated arguments would make the recorded lineage differ from operator
// intent, so validate the complete argv before applying defaults.
public func ckbAbcdeStrictUsageDiagnostic(args: Array<String>): String {
    let flags = HashSet<String>()
    let valued = HashSet<String>()
    for (name in ["--generation-protocol","--samples-per-case","--test-suites","--run-mode","--dataset-version","--candidate-version","--knowledge-version","--model-fingerprint","--certification-preflight","--certification-run-manifest","--expected-model-version","--provider-identity-hash","--provider-identity-artifact","--frozen-candidate-manifest","--transport-retries","--model-timeout-seconds","--model-effort","--model-max-budget-usd","--run-id","--repo-root","--runs-root","--dataset-root","--manifest","--ckb-bin","--ckb-store","--ckb-http-base","--claude-bin","--docs-root","--case-start","--case-end","--case-id","--groups","--config","--store"]) { valued.add(name) }
    for (name in ["--help","-h","--preflight-only","--skip-claude","--generate-only","--evaluate-frozen"]) { flags.add(name) }
    let seen = HashSet<String>(); var commandSeen = false; var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "cangjie-eval-abcde" && !commandSeen) { commandSeen=true; i+=1; continue }
        if (flags.contains(arg)) {
            if (seen.contains(arg)) { return "duplicate_argument:${arg}" }; seen.add(arg); i+=1; continue
        }
        if (valued.contains(arg)) {
            if ((arg == "--store" && seen.contains("--ckb-store")) || (arg == "--ckb-store" && seen.contains("--store"))) { return "ambiguous_store_argument" }
            if (seen.contains(arg)) { return "duplicate_argument:${arg}" }
            if (i+1>=args.size || args[i+1].startsWith("--")) { return "missing_argument_value:${arg}" }
            if (arg == "--model-timeout-seconds" && ckbAbcdeModelTimeoutDiagnostic(args[i+1]) != "ok") { return ckbAbcdeModelTimeoutDiagnostic(args[i+1]) }
            if (arg == "--transport-retries" && ckbAbcdeTransportRetriesDiagnostic(args[i+1]) != "ok") { return ckbAbcdeTransportRetriesDiagnostic(args[i+1]) }
            if (arg == "--model-effort" && ckbAbcdeModelEffortDiagnostic(args[i+1]) != "ok") { return ckbAbcdeModelEffortDiagnostic(args[i+1]) }
            if (arg == "--model-max-budget-usd" && ckbAbcdeModelMaxBudgetDiagnostic(args[i+1]) != "ok") { return ckbAbcdeModelMaxBudgetDiagnostic(args[i+1]) }
            seen.add(arg); i+=2; continue
        }
        return "unknown_argument:${arg}"
    }
    if (!commandSeen) { return "command_required" }
    "ok"
}

public func ckbAbcdeTransportRetriesDiagnostic(value:String):String{try{let parsed=Int64.parse(value);if(parsed<0||parsed>10){return "invalid_argument_value:--transport-retries"}}catch(_:Exception){return "invalid_argument_value:--transport-retries"};"ok"}

public func ckbAbcdeModelTimeoutDiagnostic(value: String): String {
    if (value == "" || value != value.trimAscii()) { return "invalid_argument_value:--model-timeout-seconds" }
    try {
        let parsed = Int64.parse(value)
        if (parsed <= 0 || parsed > 3600) { return "invalid_argument_value:--model-timeout-seconds" }
    } catch (_: Exception) { return "invalid_argument_value:--model-timeout-seconds" }
    "ok"
}

public func ckbAbcdeModelEffortDiagnostic(value: String): String {
    if (value == "" || value != value.trimAscii()) { return "invalid_argument_value:--model-effort" }
    if (!(["low", "medium", "high", "xhigh", "max"].contains(value))) { return "invalid_argument_value:--model-effort" }
    "ok"
}

public func ckbAbcdeModelMaxBudgetDiagnostic(value: String): String {
    if (value == "" || value != value.trimAscii()) { return "invalid_argument_value:--model-max-budget-usd" }
    let lowered = value.toAsciiLower()
    if (lowered.contains("nan") || lowered.contains("inf")) { return "invalid_argument_value:--model-max-budget-usd" }
    try { let parsed = Float64.parse(value); if (parsed <= 0.0 || parsed > 100.0) { return "invalid_argument_value:--model-max-budget-usd" } } catch (_: Exception) { return "invalid_argument_value:--model-max-budget-usd" }
    "ok"
}

public func runCangjieAbcdeParitySmoke(args: Array<String>): Int64 {
    let taskContextJson = ckbAbcdeSmokeTaskContextJson()
    let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/abcde-parity-smoke-store"))
    let report = ckbAbcdeProbeInProcessTransportParity(service, "CJ-HUMANEVAL-000", taskContextJson)
    let restResponse = ckbAbcdeParityStructuredPayload(ckbApiHandle(service, "POST", "/v1/cangjie/task-knowledge-pack", taskContextJson, []), "rest")
    let promptB = renderCkbAbcdePrompt(CkbAbcdeGroups.B, "CJ-HUMANEVAL-000", "Implement `src/solution.cj`.", taskContextJson + "\n---CKB_RESPONSE---\n" + restResponse)
    let promptC = renderCkbAbcdePrompt(CkbAbcdeGroups.C, "CJ-HUMANEVAL-000", "Implement `src/solution.cj`.", taskContextJson)
    let promptD = renderCkbAbcdePrompt(CkbAbcdeGroups.D, "CJ-HUMANEVAL-000", "Implement `src/solution.cj`.", taskContextJson)
    let stdioUse = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"mcp__ckb-cangjie__cangjie_task_knowledge_pack\"}]}}"
    let httpUse = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"mcp__ckb-cangjie-http__cangjie_task_knowledge_pack\"}]}}"
    let canonicalOk = taskContextJson.contains("\"taskId\":\"CJ-HUMANEVAL-000\"") && taskContextJson.contains("\"targetVersion\":\"1.0.0\"")
    let bPromptOk = promptB.contains("Canonical CKB Task Context") && promptB.contains("CKB REST Context") && promptB.contains("\"versionResolution\"")
    let stdioPromptOk = promptC.contains("mcp__ckb-cangjie__cangjie_task_knowledge_pack")
    let httpPromptOk = promptD.contains("mcp__ckb-cangjie-http__cangjie_task_knowledge_pack")
    let toolEvidenceOk = ckbAbcdeToolEvidence(CkbAbcdeGroups.C, stdioUse) == "cangjie_task_knowledge_pack" &&
        ckbAbcdeToolEvidence(CkbAbcdeGroups.D, httpUse) == "cangjie_task_knowledge_pack"
    let ok = canonicalOk && bPromptOk && stdioPromptOk && httpPromptOk && toolEvidenceOk && report.ok
    println("abcde-parity-smoke ok=${ok}")
    println("canonicalTaskContext=${canonicalOk}")
    println("bRestTaskPackPrompt=${bPromptOk}")
    println("stdioTaskToolPrompt=${stdioPromptOk}")
    println("httpTaskToolPrompt=${httpPromptOk}")
    println("toolEvidenceOk=${toolEvidenceOk}")
    println("transportParity=${report.ok}")
    println(ckbAbcdeRenderParityJsonl(report))
    if (ok) { 0 } else { 1 }
}

public func renderCkbAbcdePrompt(group: String, caseId: String, modelTask: String, contextText: String): String {
    renderCkbAbcdePromptForMode(group, caseId, modelTask, contextText, "development")
}

public func renderCkbAbcdePromptForMode(group: String, caseId: String, modelTask: String, contextText: String, runMode: String): String {
    let taskContextJson = ckbAbcdePromptTaskContextJson(contextText)
    let restContextText = ckbAbcdePromptRestContext(contextText)
    var out = "# ${caseId} ${group}\n\n"
    out += "Run mode: ${if (runMode == "certification") { "certification" } else { "development" }}. This label changes retry and accounting policy only; it does not expose tests, previous attempts, or other case artifacts.\n\n"
    out += "You are completing one Cangjie HumanEval case. Modify only `src/solution.cj` in the current workspace. Keep the public function signature unchanged. The copied workspace root is your current directory; if the task text below mentions `starter/src/solution.cj`, still edit exactly `src/solution.cj`. Do not read hidden tests, reference solutions, teacher artifacts, unrelated repositories, files outside the allowed paths, or outputs from previous attempts. Use at most three knowledge or documentation lookup tool calls before editing; do not perform prolonged research. If documentation is inconclusive, implement directly from the starter signature, examples, and common Cangjie syntax. Before replying, run the public local checks available in this workspace within this same model call; at minimum run `cjpm build`, and run public tests only when they are already present in the workspace. If no public tests are already present, `cjpm build` is sufficient. Never create a `main` or test harness, never create or modify test files, and do not modify `cjpm.toml`, even temporarily; temporary out-of-scope edits that are later restored are still protocol violations. If a local check fails, fix `src/solution.cj` and rerun it before replying. Independently trace every example shown in the task and review task-relevant boundaries such as empty or single inputs, duplicates, signs, structure closure, and operator precedence. When task evidence conflicts, normative prose and the core algorithm are authoritative; use examples as consistency checks, report any inconsistency, and do not silently replace the specified algorithm with example-only behavior. Do not create, discover, or infer hidden verifier inputs. After these checks pass, reply with a short completion note that names the checks performed.\n\n"
    if (group == CkbAbcdeGroups.A) {
        out += "Knowledge policy for this run: No CKB baseline. Do not use CKB HTTP APIs, MCP tools, local cangjie_docs, web search, or external source repositories.\n\n"
    } else if (group == CkbAbcdeGroups.B) {
        out += "Knowledge policy for this run: use only the CKB REST context embedded below. Do not use MCP tools, local cangjie_docs, web search, or external source repositories.\n\n"
        out += "## CKB REST Context\n\n```json\n${restContextText}\n```\n\n"
    } else if (group == CkbAbcdeGroups.C) {
        out += "Knowledge policy for this run: use the configured stdio MCP server `ckb-cangjie`. The runner has already bound the immutable canonical task context to this MCP process. Before reading or editing `src/solution.cj`, you must call `mcp__ckb-cangjie__cangjie_task_knowledge_pack` exactly once with `{}`. Do not copy, paraphrase, reorder, or add task fields to the tool input; any non-empty input or duplicate call invalidates the run. This run is invalid without that real tool call and its paired tool result, even if the task looks trivial. Do not use CKB REST context, HTTP MCP, local cangjie_docs, web search, or external source repositories.\n\n"
    } else if (group == CkbAbcdeGroups.D) {
        out += "Knowledge policy for this run: use the configured Streamable HTTP MCP server `ckb-cangjie-http`. The runner has already bound the immutable canonical task context to this MCP session. Before reading or editing `src/solution.cj`, you must call `mcp__ckb-cangjie-http__cangjie_task_knowledge_pack` exactly once with `{}`. Do not copy, paraphrase, reorder, or add task fields to the tool input; any non-empty input or duplicate call invalidates the run. This run is invalid without that real tool call and its paired tool result, even if the task looks trivial. Do not use CKB REST context, stdio MCP, local cangjie_docs, web search, or external source repositories.\n\n"
    } else if (group == CkbAbcdeGroups.E) {
        out += "Knowledge policy for this run: 当前这个项目是仓颉语言开发的项目。You may use local official Cangjie docs under /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs when Cangjie syntax, standard library, stdx, or tool usage knowledge is needed. Start from /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs/dev-guide/summary_cjnative_EN.md and /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs/tools/summary_cjnative_EN.md when they are useful, and prefer targeted read-only Bash rg queries or focused Read calls over loading large documents. You may use Bash only for read-only inspection inside the current temporary workspace or read-only documentation queries under /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs. For documentation Bash queries, prefer absolute paths such as `rg \"ArrayList\" /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs`; do not rely on `cd` followed by later relative documentation queries. Do not use CKB REST APIs, MCP tools, web search, network commands, shell commands that write/delete/move files, or external source repositories.\n\n"
    }
    if (group == CkbAbcdeGroups.B || group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D) {
        out += "## Canonical CKB Task Context\n\n"
        out += if (group == CkbAbcdeGroups.B) { "Use this exact JSON as the task context for the embedded CKB REST request.\n\n" } else { "Audit record only: the runner has already bound this exact JSON to MCP. Do not copy any field into a tool call; the only valid `cangjie_task_knowledge_pack` arguments are `{}`.\n\n" }
        out += "```json\n${taskContextJson}\n```\n\n"
    }
    out += "## Task\n\n"
    out += modelTask
    if (!modelTask.endsWith("\n")) {
        out += "\n"
    }
    out
}

private func ckbAbcdePromptTaskContextJson(contextText: String): String {
    let marker = "\n---CKB_RESPONSE---\n"
    let parts = contextText.split(marker)
    if (parts.size > 0) { parts[0] } else { contextText }
}

private func ckbAbcdePromptRestContext(contextText: String): String {
    let marker = "\n---CKB_RESPONSE---\n"
    let parts = contextText.split(marker)
    if (parts.size > 1) { parts[1] } else { contextText }
}

private func ckbAbcdeMcpStdioArguments(options: CkbAbcdeRunnerOptions, taskContextJson!: String = ""): Array<String> {
    let args = ArrayList<String>(); args.add("--config"); args.add(options.ckbConfig); args.add("--store"); args.add(options.ckbStore); args.add("mcp-stdio")
    if (taskContextJson != "") { args.add("--bound-task-context-base64"); args.add(toBase64String(taskContextJson.toArray())); args.add("--bound-task-context-sha256"); args.add(benchmarkGapSha256(taskContextJson)) }
    args.toArray()
}

public func ckbAbcdeMcpStdioArgumentsForTest(options: CkbAbcdeRunnerOptions, taskContextJson!: String = ""): Array<String> {
    ckbAbcdeMcpStdioArguments(options, taskContextJson: taskContextJson)
}

public func renderCkbAbcdeMcpConfig(group: String, ckbBin: String, ckbConfig: String, ckbStore: String, ckbHttpBase: String, taskContextJson!: String = ""): String {
    if ((group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D) && taskContextJson == "") {
        return "{\n  \"mcpServers\": {}\n}\n"
    }
    if (group == CkbAbcdeGroups.C) {
        let options = CkbAbcdeRunnerOptions()
        options.ckbConfig = ckbConfig
        options.ckbStore = ckbStore
        let stdioScript = ckbAbcdeNativeTlsBootstrapScript(ckbBin, ckbAbcdeMcpStdioArguments(options, taskContextJson: taskContextJson))
        return "{\n  \"mcpServers\": {\n    \"ckb-cangjie\": {\n      \"command\": \"/bin/zsh\",\n      \"args\": [\"-lc\", \"${ckbAbcdeJsonEscape(stdioScript)}\"]\n    }\n  }\n}\n"
    }
    if (group == CkbAbcdeGroups.D) {
        let encoded = toBase64String(taskContextJson.toArray())
        let hash = benchmarkGapSha256(taskContextJson)
        return "{\n  \"mcpServers\": {\n    \"ckb-cangjie-http\": {\n      \"type\": \"http\",\n      \"url\": \"${ckbAbcdeJsonEscape(ckbHttpBase)}/mcp\",\n      \"headers\": {\"X-CKB-Runner-Context\":\"${ckbAbcdeJsonEscape(encoded)}\",\"X-CKB-Runner-Context-SHA256\":\"${hash}\"}\n    }\n  }\n}\n"
    }
    "{\n  \"mcpServers\": {}\n}\n"
}

public func ckbAbcdeJsonEscape(value: String): String {
    let out = StringBuilder()
    for (ch in value.toRuneArray()) {
        if (ch == r'"') {
            out.append("\\\"")
        } else if (ch == r'\\') {
            out.append("\\\\")
        } else if (ch == r'\n') {
            out.append("\\n")
        } else if (ch == r'\r') {
            out.append("\\r")
        } else if (ch == r'\t') {
            out.append("\\t")
        } else {
            out.append(ch)
        }
    }
    out.toString()
}

public func ckbAbcdeBuildTaskContext(caseRoot: String, caseId: String): CkbAbcdeTaskContext {
    ckbAbcdeBuildTaskContext(caseRoot, caseId, "")
}

public func ckbAbcdeBuildTaskContext(caseRoot: String, caseId: String, manifestText: String): CkbAbcdeTaskContext {
    let context = CkbAbcdeTaskContext()
    context.taskId = caseId
    context.taskText = ckbAbcdeCanonicalTaskTextFromFile(ckbAbcdeReadText("${caseRoot}/prompt.md"))
    let starter = ckbAbcdeReadText("${caseRoot}/starter/src/solution.cj")
    context.signature = ckbAbcdeExtractCangjieSignature(starter)
    for (tag in ckbAbcdeInferKnowledgeTags("${context.taskText}\n${starter}")) {
        context.expectedKnowledgeTags.add(tag)
    }
    if (manifestText.contains("cangjie-humaneval-authority-v1")) {
        match (cangjieHumanEvalAuthorityRowForCase(manifestText, caseId)) {
            case Some(row) =>
                context.signature = row.signature
                context.targetVersion = row.targetVersion
                context.datasetVersion = row.datasetVersion
                context.promptHash = row.promptHash
                context.starterHash = row.starterHash
            case None => ()
        }
    }
    context
}

// prompt.md is a line-oriented file. Its single terminal LF/CRLF is a file
// delimiter, not benchmark task content; all other whitespace stays exact.
private func ckbAbcdeCanonicalTaskTextFromFile(value: String): String {
    let runes = value.toRuneArray()
    var end = runes.size
    if (end > 0 && runes[end - 1] == r'\n') {
        end -= 1
        if (end > 0 && runes[end - 1] == r'\r') { end -= 1 }
    }
    let out = StringBuilder()
    for (i in 0..end) { out.append(runes[i]) }
    out.toString()
}

public func ckbAbcdeRenderTaskContextJson(context: CkbAbcdeTaskContext): String {
    "{\"taskId\":\"${ckbAbcdeJsonEscape(context.taskId)}\",\"benchmark\":\"${ckbAbcdeJsonEscape(context.benchmark)}\",\"taskText\":\"${ckbAbcdeJsonEscape(context.taskText)}\",\"signature\":\"${ckbAbcdeJsonEscape(context.signature)}\",\"datasetVersion\":\"${ckbAbcdeJsonEscape(context.datasetVersion)}\",\"promptHash\":\"${ckbAbcdeJsonEscape(context.promptHash)}\",\"starterHash\":\"${ckbAbcdeJsonEscape(context.starterHash)}\",\"expectedKnowledgeTags\":${ckbAbcdeStringArrayJson(context.expectedKnowledgeTags)},\"targetVersion\":\"${ckbAbcdeJsonEscape(context.targetVersion)}\",\"sourceSet\":\"${ckbAbcdeJsonEscape(context.sourceSet)}\",\"versionPolicy\":\"${ckbAbcdeJsonEscape(context.versionPolicy)}\",\"budget\":10,\"responseMode\":\"evidence\"}"
}

private func ckbAbcdeExtractCangjieSignature(source: String): String {
    for (line in source.split("\n")) {
        let trimmed = line.trimAscii()
        if (trimmed.startsWith("func ")) {
            let parts = trimmed.split("{")
            if (parts.size > 0) { return parts[0].trimAscii() }
            return trimmed
        }
    }
    ""
}

private func ckbAbcdeInferKnowledgeTags(text: String): ArrayList<String> {
    let tags = ArrayList<String>()
    let lower = text.toAsciiLower()
    ckbAbcdeAddTagIf(tags, lower.contains("arraylist") || lower.contains("array<"), "ArrayList")
    ckbAbcdeAddTagIf(tags, lower.contains("string") || lower.contains("rune"), "String")
    ckbAbcdeAddTagIf(tags, lower.contains("hashmap") || lower.contains("map"), "HashMap")
    ckbAbcdeAddTagIf(tags, lower.contains("hashset") || lower.contains("set"), "HashSet")
    ckbAbcdeAddTagIf(tags, lower.contains("sort"), "sort")
    ckbAbcdeAddTagIf(tags, lower.contains("int64") || lower.contains("float"), "numeric")
    ckbAbcdeAddTagIf(tags, lower.contains("option") || lower.contains("none") || lower.contains("some"), "Option")
    if (tags.size == 0) {
        tags.add("Cangjie syntax")
    }
    tags
}

private func ckbAbcdeAddTagIf(tags: ArrayList<String>, condition: Bool, tag: String): Unit {
    if (condition && !tags.contains(tag)) {
        tags.add(tag)
    }
}

private func ckbAbcdeStringArrayJson(values: ArrayList<String>): String {
    var out = "["
    for (i in 0..values.size) {
        if (i > 0) {
            out += ","
        }
        out += "\"${ckbAbcdeJsonEscape(values[i])}\""
    }
    out + "]"
}

private func ckbAbcdeSmokeTaskContextJson(): String {
    let context = CkbAbcdeTaskContext()
    context.taskId = "CJ-HUMANEVAL-000"
    context.taskText = "Implement a Cangjie ArrayList helper."
    context.signature = "func solution(values: Array<Int64>): Int64"
    context.datasetVersion = "smoke-dataset-v1"
    context.promptHash = benchmarkGapSha256(context.taskText)
    context.starterHash = benchmarkGapSha256(context.signature)
    context.expectedKnowledgeTags.add("ArrayList")
    context.expectedKnowledgeTags.add("Cangjie syntax")
    ckbAbcdeRenderTaskContextJson(context)
}

public func ckbAbcdeSmokeTaskContextJsonForTest(): String {
    ckbAbcdeSmokeTaskContextJson()
}

private func ckbAbcdeRunCaseGroup(options: CkbAbcdeRunnerOptions, runRoot: String, caseId: String, group: String, previousGroup: String): String {
    let caseSrc = "${options.datasetRoot}/${caseId}"
    let groupRoot = "${runRoot}/cases/${caseId}/${group}"
    let workspace = "${groupRoot}/workspace"
    let taskContext = ckbAbcdeBuildTaskContext(caseSrc, caseId, ckbAbcdeReadText(options.manifestPath))
    let taskContextJson = ckbAbcdeRenderTaskContextJson(taskContext)
    ckbAbcdeEnsureDir(groupRoot)
    ckbAbcdeWriteText("${groupRoot}/canonical-task-context.json", taskContextJson + "\n")
    ckbAbcdeWriteText("${groupRoot}/switch-gate.json", "{\"caseId\":\"${caseId}\",\"group\":\"${group}\",\"status\":\"entered\"}\n")
    ckbAbcdeAppendText("${runRoot}/cases/${caseId}/env-switch-checks.jsonl", ckbAbcdeRenderEnvSwitchCheck(caseId, previousGroup, group, workspace, groupRoot) + "\n")

    let copy = ckbAbcdeRunShell("rm -rf ${ckbAbcdeShellQuote(workspace)} && cp -R ${ckbAbcdeShellQuote("${caseSrc}/starter")} ${ckbAbcdeShellQuote(workspace)}", "")
    ckbAbcdeWriteText("${groupRoot}/workspace-copy.stdout.log", copy.stdout)
    ckbAbcdeWriteText("${groupRoot}/workspace-copy.stderr.log", copy.stderr)
    ckbAbcdeEnsureDir("${groupRoot}/session")
    ckbAbcdeEnsureDir("${groupRoot}/runtime-home")
    let entryWorkspaceId = "cases/${caseId}/${group}/workspace"
    let entrySessionId = "cases/${caseId}/${group}/session"
    let entryRuntimeHomeId = "cases/${caseId}/${group}/runtime-home"
    let entryIsolationDiagnostic = ckbAbcdeIsolationDiagnostic(caseId, entryWorkspaceId, entrySessionId, entryRuntimeHomeId, "", "", "", "")
    ckbAbcdeWriteText("${groupRoot}/isolation.json", "{\"workspaceId\":\"${ckbAbcdeJsonEscape(entryWorkspaceId)}\",\"sessionId\":\"${ckbAbcdeJsonEscape(entrySessionId)}\",\"runtimeHomeId\":\"${ckbAbcdeJsonEscape(entryRuntimeHomeId)}\",\"diagnostic\":\"${entryIsolationDiagnostic}\"}\n")

    var contextText = ""
    var knowledgeReady = true
    if (group == CkbAbcdeGroups.B) {
        let body = taskContextJson
        ckbAbcdeWriteText("${groupRoot}/ckb-rest-request.json", body)
        let rest = ckbAbcdeRunShell("curl ${ckbAbcdeCurlRetryFlags()} --max-time 20 -fsS -X POST -H 'Content-Type: application/json' --data-binary @${ckbAbcdeShellQuote("${groupRoot}/ckb-rest-request.json")} ${ckbAbcdeShellQuote("${options.ckbHttpBase}/v1/cangjie/task-knowledge-pack")}", "")
        contextText = rest.stdout
        knowledgeReady = rest.exitCode == 0 && rest.stdout.contains("\"ok\":true")
        ckbAbcdeWriteText("${groupRoot}/ckb-rest-response.json", rest.stdout)
        ckbAbcdeWriteText("${groupRoot}/ckb-task-knowledge-pack.json", rest.stdout)
        ckbAbcdeWriteText("${groupRoot}/ckb-knowledge-pack.json", rest.stdout)
        ckbAbcdeWriteText("${groupRoot}/ckb-rest.stderr.log", rest.stderr)
        contextText = taskContextJson + "\n---CKB_RESPONSE---\n" + rest.stdout
    } else if (group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D) {
        contextText = taskContextJson
    }

    if (group == CkbAbcdeGroups.C) {
        ckbAbcdeRunMcpStdioSmoke(options, groupRoot, taskContextJson: taskContextJson)
    }
    if (group == CkbAbcdeGroups.D) {
        ckbAbcdeRunMcpHttpSmoke(options, groupRoot, taskContextJson: taskContextJson)
    }

    let mcpConfig = renderCkbAbcdeMcpConfig(group, options.ckbBin, options.ckbConfig, options.ckbStore, options.ckbHttpBase, taskContextJson: taskContextJson)
    ckbAbcdeWriteText("${groupRoot}/mcp-config.json", mcpConfig)
    if (group != CkbAbcdeGroups.C && group != CkbAbcdeGroups.D) {
        ckbAbcdeWriteText("${groupRoot}/empty-mcp.json", mcpConfig)
    } else if (group == CkbAbcdeGroups.C) {
        ckbAbcdeWriteText("${groupRoot}/ckb-mcp-stdio.json", mcpConfig)
    } else if (group == CkbAbcdeGroups.D) {
        ckbAbcdeWriteText("${groupRoot}/ckb-mcp-http.json", mcpConfig)
    }

    let prompt = renderCkbAbcdePromptForMode(group, caseId, ckbAbcdeReadText("${caseSrc}/prompt.md"), contextText, options.runMode)
    ckbAbcdeWriteText("${groupRoot}/prompt.final.md", prompt)

    var claudeExit: Int64 = 0
    if(options.runMode=="certification"&&options.evaluateFrozen){
        ckbAbcdeWriteText("${groupRoot}/evaluation-model-call.json","{\"modelCalled\":false,\"reason\":\"evaluate_frozen\"}\n")
    } else if (options.skipClaude) {
        ckbAbcdeWriteText("${groupRoot}/claude-transcript.jsonl", "{\"event\":\"skipped\",\"reason\":\"skip-claude\"}\n")
        ckbAbcdeWriteText("${groupRoot}/claude.stdout.log", "")
        ckbAbcdeWriteText("${groupRoot}/claude.stderr.log", "")
    } else {
        let claude = if (options.runMode == "certification") { ckbAbcdeRunClaudeCertification(options, group, groupRoot, workspace, "${groupRoot}/runtime-home", caseSrc) } else { ckbAbcdeRunClaude(options, group, groupRoot, workspace, "${groupRoot}/runtime-home", options.docsRoot, caseSrc, "${caseSrc}/starter") }
        claudeExit = claude.exitCode
    }
    let usage = ckbAbcdeParseClaudeUsageFile("${groupRoot}/claude-transcript.jsonl")
    ckbAbcdeWriteText("${groupRoot}/usage.json", ckbAbcdeRenderUsageJson(usage) + "\n")
    ckbAbcdeWriteText("${groupRoot}/attempt-evidence.json",ckbAbcdeAttemptSummaryJson(groupRoot)+"\n")

    if(options.runMode=="certification"){
        let frozenRoot="${groupRoot}/frozen-completion";var completion=CkbAbcdeSingleCompletion()
        if(options.evaluateFrozen){
            let frozenPath=Path(frozenRoot).join("solution.cj")
            if(!exists(frozenPath)){return "{\"caseId\":\"${caseId}\",\"group\":\"${group}\",\"status\":\"failed\",\"diagnostic\":\"frozen_completion_missing\"}"}
            try{completion.solutionCj=String.fromUtf8(File.readFrom(frozenPath));completion.answerHash=benchmarkGapSha256(completion.solutionCj);completion.ok=true;completion.completionCount=1}catch(_:Exception){return "{\"caseId\":\"${caseId}\",\"group\":\"${group}\",\"status\":\"failed\",\"diagnostic\":\"invalid_response_encoding\"}"}
        }else{
            let transcriptPath=Path(groupRoot).join("claude-transcript.jsonl")
            let bytes=try{File.readFrom(transcriptPath)}catch(_:Exception){return "{\"caseId\":\"${caseId}\",\"group\":\"${group}\",\"status\":\"failed\",\"diagnostic\":\"completion_read_failed\"}"}
            completion=ckbAbcdeExtractSingleCompletion(bytes)
            if(!completion.ok){return "{\"caseId\":\"${caseId}\",\"group\":\"${group}\",\"status\":\"failed\",\"diagnostic\":\"${completion.diagnostic}\"}"}
            let freezeDiagnostic=ckbAbcdeFreezeCompletion(frozenRoot,completion)
            if(freezeDiagnostic!="ok"){return "{\"caseId\":\"${caseId}\",\"group\":\"${group}\",\"status\":\"failed\",\"diagnostic\":\"${freezeDiagnostic}\"}"}
        }
        let installDiagnostic=ckbAbcdeInstallFrozenSolution(workspace,completion)
        if(installDiagnostic!="ok"){return "{\"caseId\":\"${caseId}\",\"group\":\"${group}\",\"status\":\"failed\",\"diagnostic\":\"${installDiagnostic}\"}"}
        if(options.generateOnly){
            let evidence="{\"caseId\":\"${caseId}\",\"group\":\"${group}\",\"status\":\"frozen\",\"answerHash\":\"${completion.answerHash}\",\"completionCount\":1,\"toolCallCount\":0}"
            ckbAbcdeWriteText("${groupRoot}/generation-evidence.json",evidence+"\n");return evidence
        }
    }

    // The answer is immutable before verifier-owned material enters the workspace.
    let frozenAnswer=ckbAbcdeReadText("${workspace}/src/solution.cj")
    let frozenAnswerHash=benchmarkGapSha256(frozenAnswer)
    ckbAbcdeWriteText("${groupRoot}/answer-freeze.json","{\"answerHash\":\"${frozenAnswerHash}\",\"verifierMounted\":false}\n")
    let inject = ckbAbcdeRunShell("cp ${ckbAbcdeShellQuote("${caseSrc}/tests/TestMain.cj")} ${ckbAbcdeShellQuote("${workspace}/src/main.cj")} && cp ${ckbAbcdeShellQuote("${caseSrc}/tests/cjpm.executable.toml")} ${ckbAbcdeShellQuote("${workspace}/cjpm.toml")}", "")
    ckbAbcdeWriteText("${groupRoot}/hidden-test-inject.stdout.log", inject.stdout)
    ckbAbcdeWriteText("${groupRoot}/hidden-test-inject.stderr.log", inject.stderr)
    ckbAbcdeWriteText("${groupRoot}/hidden-test-inject.log", inject.stdout + inject.stderr)
    ckbAbcdeWriteText("${groupRoot}/verifier-mount.json","{\"injectExitCode\":${inject.exitCode},\"answerHashBefore\":\"${frozenAnswerHash}\",\"answerHashAfter\":\"${benchmarkGapSha256(ckbAbcdeReadText("${workspace}/src/solution.cj"))}\",\"mountedAfterFreeze\":${inject.exitCode==0}}\n")
    let test = ckbAbcdeRunShell("cjpm run", workspace)
    let testLog = test.stdout + test.stderr
    ckbAbcdeWriteText("${groupRoot}/test.log", testLog)

    let primaryTranscript = ckbAbcdeReadText("${groupRoot}/claude-transcript.jsonl")
    let transcript = if (primaryTranscript != "") { primaryTranscript } else { ckbAbcdeReadText("${groupRoot}/claude.stdout.log") + ckbAbcdeReadText("${groupRoot}/claude.stderr.log") }
    let parsedEvidence = ckbAbcdeTaskKnowledgeEvidence(group, transcript, contextText)
    let toolEvidence = if (group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D) { if (parsedEvidence.valid && parsedEvidence.knowledgeVersion == options.knowledgeVersion) { "cangjie_task_knowledge_pack" } else { "manual_required" } } else { ckbAbcdeToolEvidence(group, transcript) }
    let forbiddenViolation = ckbAbcdeForbiddenEvidence(group, transcript, workspace)
    let violation = if (forbiddenViolation != "none") { forbiddenViolation } else if ((group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D) && (!parsedEvidence.valid || parsedEvidence.knowledgeVersion != options.knowledgeVersion)) { if (parsedEvidence.valid) { "task_knowledge_version_mismatch" } else { "task_knowledge_${parsedEvidence.diagnostic}" } } else { "none" }
    ckbAbcdePersistTaskKnowledgeEvidence(groupRoot, parsedEvidence, parsedEvidence.valid && parsedEvidence.knowledgeVersion == options.knowledgeVersion)
    let unitPass = test.exitCode == 0 && !ckbAbcdeTestLogContainsFailure(testLog)
    let unitPassAt1 = ckbAbcdeUnitPassAt1(unitPass, groupRoot)
    let toolReady = ckbAbcdeRequiredKnowledgeReady(group, knowledgeReady, toolEvidence)
    let legacyFailureType = ckbAbcdeFailureType(claudeExit, test.exitCode, unitPass, violation, testLog, toolReady)
    let failureType = if (options.explicitRunMode) { ckbAbcdeExpandedFailureType(legacyFailureType) } else { legacyFailureType }
    let protocolViolation = violation != "none"
    let observedModel = ckbAbcdeObservedModel(transcript)
    let sampleReady = !options.explicitRunMode || options.runMode != "development" || ckbAbcdeSampleAttemptCount(groupRoot) == 1
    let modelReady = (!options.explicitRunMode || observedModel == options.expectedModelVersion) && sampleReady
    if (options.explicitRunMode) {
        ckbAbcdeWriteText("${groupRoot}/provider-identity.json", ckbAbcdeProviderIdentityJson(observedModel, ckbAbcdeClaudeVersion(executable: options.claudeBin)))
    }
    let status = if (copy.exitCode == 0 && inject.exitCode == 0 && claudeExit == 0 && unitPass && violation == "none" && toolReady && modelReady) { "passed" } else { "failed" }
    let attemptSummary=ckbAbcdeAttemptSummaryJson(groupRoot);ckbAbcdeWriteText("${groupRoot}/test-result.json",attemptSummary.replace("}",",\"testExitCode\":${test.exitCode},\"unitPassAt1\":${unitPassAt1},\"failureType\":\"${failureType}\",\"testLogPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/test.log")}\"}")+"\n")
    ckbAbcdeWriteText("${groupRoot}/protocol-audit.json", "{\"protocolViolation\":${protocolViolation},\"protocolViolationReason\":\"${ckbAbcdeJsonEscape(violation)}\",\"knowledgeEntry\":\"${ckbAbcdeKnowledgeEntry(group)}\",\"toolTransport\":\"${ckbAbcdeToolTransport(group)}\",\"toolEvidence\":\"${ckbAbcdeJsonEscape(toolEvidence)}\"}\n")
    if (group == CkbAbcdeGroups.E) {
        ckbAbcdeWriteText("${groupRoot}/docs-path-audit.json", "{\"docsRoot\":\"${ckbAbcdeJsonEscape(options.docsRoot)}\",\"summaryFiles\":[\"${ckbAbcdeJsonEscape("${options.docsRoot}/dev-guide/summary_cjnative_EN.md")}\",\"${ckbAbcdeJsonEscape("${options.docsRoot}/tools/summary_cjnative_EN.md")}\"],\"allowed\":${exists(Path("${options.docsRoot}/dev-guide/summary_cjnative_EN.md")) && exists(Path("${options.docsRoot}/tools/summary_cjnative_EN.md"))}}\n")
    }
    var result = if(options.runMode=="certification"){ckbAbcdeRenderStrictCertificationCase(options,caseId,group,groupRoot,frozenAnswerHash,transcript,testLog,unitPassAt1,violation,toolReady,parsedEvidence)}else{ckbAbcdeRenderCaseResultBound(options, runRoot, caseId, group, status, claudeExit, test.exitCode, unitPass, unitPassAt1, failureType, toolEvidence, violation, groupRoot, parsedEvidence)}
    if (options.explicitRunMode && options.runMode == "certification") {
        ckbAbcdeWriteText("${groupRoot}/result-evidence.json", result + "\n")
    }
    if (options.explicitRunMode && options.runMode == "development") {
        let attemptCount = ckbAbcdeClaudeAttemptCount(groupRoot)
        let selectedTransportAttempt=ckbAbcdeSelectedSampleTransportAttempt(groupRoot)
        let resultEvidence = ckbAbcdeTriageEvidenceBound(options, caseId, if(selectedTransportAttempt>0){selectedTransportAttempt}else if(attemptCount>0){attemptCount}else{1}, failureType, unitPass, protocolViolation, claudeExit, test.exitCode, groupRoot, parsedEvidence)
        ckbAbcdeWriteText("${groupRoot}/result-evidence.json", resultEvidence + "\n")
        let closureInput = CangjieEvalDevelopmentClosureInput()
        closureInput.caseResultJson = result; closureInput.resultEvidenceJson = resultEvidence; closureInput.taskText = taskContext.taskText
        closureInput.firstClassifierJson = ckbAbcdeReadText("${groupRoot}/classifier-1.json")
        closureInput.secondClassifierJson = ckbAbcdeReadText("${groupRoot}/classifier-2.json")
        let closureInputs = ArrayList<CangjieEvalDevelopmentClosureInput>(); closureInputs.add(closureInput)
        let closure = orchestrateDevelopmentClosure(closureInputs, options.runId)
        ckbAbcdeWriteText("${groupRoot}/development-closure.json", closure.developmentClosureJson + "\n")
        ckbAbcdeWriteText("${groupRoot}/authoritative-gap.jsonl", closure.authoritativeGapJsonl)
        if (closure.knowledgeGapCount == 1) { result = result.replace("\"knowledgeGapConfirmationStatus\":\"pending_classifier_artifacts\"", "\"knowledgeGapConfirmationStatus\":\"confirmed\"") }
    }
    ckbAbcdeWriteText("${groupRoot}/case-result.json", result + "\n")
    ckbAbcdeWriteText("${groupRoot}/audit.json", "{\"toolEvidence\":\"${toolEvidence}\",\"violation\":\"${violation}\"}\n")
    result
}

private func ckbAbcdeRenderStrictCertificationCase(options:CkbAbcdeRunnerOptions,caseId:String,group:String,groupRoot:String,answerHash:String,transcript:String,testLog:String,unitPassAt1:Bool,violation:String,toolReady:Bool,taskKnowledge:CkbAbcdeTaskKnowledgeEvidence):String{
    let row=CkbCertificationCaseEvidence();row.runId=options.runId;row.caseId=caseId;row.group=group;row.datasetVersion=options.datasetVersion;row.knowledgeVersion=options.knowledgeVersion;row.modelFingerprint=options.modelFingerprint;row.expectedModelVersion=options.expectedModelVersion;row.observedModelVersion=ckbAbcdeObservedModel(transcript);row.claudeCodeVersion=ckbAbcdeClaudeVersion(executable: options.claudeBin);row.providerIdentityHash=options.providerIdentityHash
    let taskKnowledgeReady=taskKnowledge.valid&&taskKnowledge.knowledgeVersion==options.knowledgeVersion;let pairedEvidence=ckbAbcdeReadText("${groupRoot}/paired-tool-evidence.json")
    let preflight=ckbAbcdeReadText(options.certificationPreflightPath);let manifestText=ckbAbcdeReadText(options.certificationRunManifestPath);row.preflightHash=benchmarkGapSha256(preflight)
    try{let manifest=JsonValue.fromStr(manifestText).asObject();row.runManifestHash=ckbAbcdeStrictJsonString(manifest,"runManifestHash")}catch(_:Exception){}
    let authority=parseCangjieHumanEvalAuthorityManifest(ckbAbcdeReadText(options.manifestPath));for(a in authority.rows){if(a.caseId==caseId){row.authorityCaseHash=a.caseHash;row.authorityTestsHash=a.testsHash}}
    let workspace="${groupRoot}/workspace";let selected=ckbAbcdeSelectedSampleTransportAttempt(groupRoot);let audited=ckbAbcdeClaudeAttemptCount(groupRoot);let evidenceAttempt=if(selected>0){selected}else{audited};let runtimeHome="${groupRoot}/runtime-home/attempt-${evidenceAttempt}";row.workspaceId=benchmarkGapSha256(try{canonicalize(Path(workspace)).toString()}catch(_:Exception){workspace});row.sessionId=benchmarkGapSha256(ckbAbcdeReadText("${groupRoot}/session-id.txt"));row.runtimeHomeId=benchmarkGapSha256(try{canonicalize(Path(runtimeHome)).toString()}catch(_:Exception){runtimeHome})
    let probe=ckbAbcdeReadText("${groupRoot}/sandbox-probe.json");row.isolationEvidenceHash=benchmarkGapSha256(probe);row.answerHash=answerHash;row.transcriptHash=benchmarkGapSha256(transcript);row.testHash=benchmarkGapSha256(testLog);row.configHash=benchmarkGapSha256(ckbAbcdeReadText("${groupRoot}/mcp-config.json")+ckbAbcdeReadText("${groupRoot}/runtime-policy.json")+ckbAbcdeReadText(options.providerIdentityArtifactPath)+pairedEvidence);row.artifactHash=benchmarkGapSha256(row.answerHash+row.transcriptHash+row.testHash+row.configHash)
    let lowered=transcript.toAsciiLower();row.referenceExposure=if(violation.contains("reference")||lowered.contains("/reference")){1}else{0};row.hiddenTestExposure=if(violation.contains("test")||lowered.contains("/tests/")||lowered.contains("testmain.cj")){1}else{0};row.teacherExposure=if(violation.contains("teacher")||lowered.contains("cangjieteacher")||lowered.contains("teacher-solutions")){1}else{0};row.crossCaseExposure=if(violation.contains("cross_case")||ckbAbcdeTranscriptHasOtherCase(transcript,caseId)){1}else{0}
    let attempts=ckbAbcdeReadText("${groupRoot}/claude-attempts.jsonl");let restores=ckbAbcdeReadText("${groupRoot}/workspace-restores.jsonl");let attemptCount=ckbAbcdeClaudeAttemptCount(groupRoot);row.sampleAttemptCount=ckbAbcdeSampleAttemptCount(groupRoot);row.lastAuditedTransportAttempt=attemptCount;row.selectedBusinessSample=selected;row.transportAttemptCount=attemptCount;row.retryCount=if(attemptCount>0){attemptCount-1}else{0};row.unresolvedTransport=if(row.sampleAttemptCount==1){0}else{1};row.attemptLineageHash=ckbAbcdeAttemptLineageHash(attempts,restores);row.agentRetryCount=ckbAbcdeAgentRetryCount(attempts,attemptCount,row.sampleAttemptCount);row.retryUsed=ckbAbcdeBusinessRetryUsed(attempts,attemptCount,row.sampleAttemptCount);row.fallbackUsed=attempts.contains("\"fallbackUsed\":true")||lowered.contains("fallback_model");row.providerRetryCount=ckbAbcdeCountOccurrences(transcript,"provider_retry");row.sdkRetryCount=ckbAbcdeCountOccurrences(transcript,"sdk_retry");row.llmTurnCount=ckbAbcdeParseClaudeUsageFromText(transcript,"transcript").llmTurnCount
    let attemptArtifactsOk=ckbAbcdeAttemptArtifactsDiagnostic(groupRoot)=="ok";row.sandboxDeniedOutsideWorkspace=ckbAbcdeStrictSandboxProbeOk(probe,workspace,runtimeHome);row.verifierMountedAfterAnswerFreeze=ckbAbcdeStrictVerifierMountOk(ckbAbcdeReadText("${groupRoot}/verifier-mount.json"),answerHash);row.certificationPassAt1=unitPassAt1&&attemptArtifactsOk&&toolReady&&taskKnowledgeReady&&pairedEvidence!=""&&violation=="none"&&row.observedModelVersion==row.expectedModelVersion&&row.sampleAttemptCount==1&&row.unresolvedTransport==0&&!row.retryUsed&&!row.fallbackUsed&&row.agentRetryCount==0&&row.providerRetryCount==0&&row.sdkRetryCount==0&&row.sandboxDeniedOutsideWorkspace&&row.verifierMountedAfterAnswerFreeze&&row.referenceExposure==0&&row.hiddenTestExposure==0&&row.teacherExposure==0&&row.crossCaseExposure==0&&row.llmTurnCount>0
    sealCkbCertificationEvidence(row);renderCkbCertificationEvidenceJson(row)
}
public func ckbAbcdeRenderStrictCertificationCaseForTest(options:CkbAbcdeRunnerOptions,caseId:String,group:String,groupRoot:String,answerHash:String,transcript:String,testLog:String,unitPassAt1:Bool,violation:String,toolReady:Bool):String{let evidence=ckbAbcdeTaskKnowledgeEvidence(group,transcript,ckbAbcdeReadText("${groupRoot}/canonical-task-context.json"));ckbAbcdePersistTaskKnowledgeEvidence(groupRoot,evidence,evidence.valid&&evidence.knowledgeVersion==options.knowledgeVersion);ckbAbcdeRenderStrictCertificationCase(options,caseId,group,groupRoot,answerHash,transcript,testLog,unitPassAt1,violation,toolReady,evidence)}

// Builds raw successful fake-transport output, then delegates all hashes,
// paired-tool evidence, and result sealing to the production runner path.
public func ckbAbcdeWriteSuccessfulFakeTransportCaseForTest(options:CkbAbcdeRunnerOptions,caseId:String,groupRoot:String):String{
    let workspace="${groupRoot}/workspace";let home="${groupRoot}/runtime-home/attempt-1";Directory.create(Path("${workspace}/src"),recursive:true);Directory.create(Path(home),recursive:true)
    let solution="public func solve(): String { \"${caseId}\" }\n";ckbAbcdeWriteText("${workspace}/src/solution.cj",solution);let answerHash=benchmarkGapSha256(solution)
    let context="{\"taskId\":\"${caseId}\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"Certification fake transport task\",\"signature\":\"public func solve(): String\",\"datasetVersion\":\"${options.datasetVersion}\",\"promptHash\":\"sha256:prompt\",\"starterHash\":\"sha256:starter\",\"expectedKnowledgeTags\":[\"String\"],\"targetVersion\":\"1.0.0\",\"sourceSet\":\"all\",\"versionPolicy\":\"default\",\"budget\":10,\"responseMode\":\"evidence\"}";ckbAbcdeWriteText("${groupRoot}/canonical-task-context.json",context)
    let contextHash=benchmarkGapSha256(context);let inputHash=benchmarkGapSha256("{}");let toolUse="{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"call-cert\",\"name\":\"mcp__ckb-cangjie-http__cangjie_task_knowledge_pack\",\"input\":{}}]}}";let toolResult="{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"call-cert\",\"content\":\"{\\\"taskId\\\":\\\"${caseId}\\\",\\\"resultType\\\":\\\"task_knowledge_pack\\\",\\\"evidenceHash\\\":\\\"sha256:fake-transport-evidence\\\",\\\"knowledgeVersion\\\":\\\"${options.knowledgeVersion}\\\",\\\"coverage\\\":{\\\"coveragePass\\\":true},\\\"citations\\\":[{\\\"citation\\\":\\\"official\\\"}],\\\"requestBinding\\\":{\\\"schemaVersion\\\":\\\"ckb-runner-bound-mcp-v1\\\",\\\"bindingMode\\\":\\\"runner_immutable\\\",\\\"requestHash\\\":\\\"${contextHash}\\\",\\\"effectiveRequestHash\\\":\\\"${contextHash}\\\",\\\"modelArgumentsHash\\\":\\\"${inputHash}\\\",\\\"taskId\\\":\\\"${caseId}\\\"}}\"}]}}";let transcript="{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"${options.expectedModelVersion}\"}\n${toolUse}\n${toolResult}\n{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false,\"num_turns\":1,\"usage\":{\"input_tokens\":1,\"output_tokens\":1,\"cache_read_input_tokens\":0,\"cache_creation_input_tokens\":0}}\n"
    let session="session-${caseId}";let probe="{\"ok\":true,\"deniedOutsideWorkspace\":true,\"deniedTests\":true,\"deniedReference\":true,\"deniedTeacher\":true,\"deniedStore\":true,\"workspaceCanonical\":\"${canonicalize(Path(workspace)).toString()}\",\"runtimeHomeCanonical\":\"${canonicalize(Path(home)).toString()}\"}";let assessment=ckbAbcdeAssessSample(transcript,options.expectedModelVersion);let diagnostic=ckbAbcdeRenderModelTransportDiagnostic(transcript,0,assessment,options.modelTimeoutSeconds,"certification","")+"\n"
    ckbAbcdeWriteText("${groupRoot}/mcp-config.json","{}");ckbAbcdeWriteText("${groupRoot}/runtime-policy.json","{\"model\":\"${options.expectedModelVersion}\",\"modelTimeoutSeconds\":${options.modelTimeoutSeconds},\"sampleAttempts\":1}");ckbAbcdeWriteText("${groupRoot}/test.log","tests passed");ckbAbcdeWriteText("${groupRoot}/session-id.attempt-1.txt",session);ckbAbcdeWriteText("${groupRoot}/session-id.txt",session);ckbAbcdeWriteText("${groupRoot}/sandbox-probe.attempt-1.json",probe);ckbAbcdeWriteText("${groupRoot}/sandbox-probe.json",probe);ckbAbcdeWriteText("${groupRoot}/claude-transcript.attempt-1.jsonl",transcript);ckbAbcdeWriteText("${groupRoot}/claude-transcript.jsonl",transcript);ckbAbcdeWriteText("${groupRoot}/claude.attempt-1.stderr.log","");ckbAbcdeWriteText("${groupRoot}/model-transport-diagnostic.attempt-1.json",diagnostic);ckbAbcdeInitializeWorkspaceRestoreEvidenceForTest(groupRoot);ckbAbcdeWriteText("${groupRoot}/verifier-mount.json","{\"injectExitCode\":0,\"answerHashBefore\":\"${answerHash}\",\"answerHashAfter\":\"${answerHash}\",\"mountedAfterFreeze\":true}")
    let attempt="{\"attempt\":1,\"transportAttempt\":1,\"modelTimeoutSeconds\":${options.modelTimeoutSeconds},\"sampleAttempt\":1,\"exitCode\":0,\"classification\":\"business_sample\",\"completeResult\":true,\"identityMatched\":true,\"workspaceRestored\":false,\"restoreEvidenceHash\":\"\",\"sessionIdHash\":\"${benchmarkGapSha256(session)}\",\"runtimeHomeId\":\"${benchmarkGapSha256(canonicalize(Path(home)).toString())}\",\"sandboxProbeHash\":\"${benchmarkGapSha256(probe)}\",\"transcriptHash\":\"${benchmarkGapSha256(transcript)}\",\"stderrHash\":\"${benchmarkGapSha256("")}\",\"diagnosticHash\":\"${benchmarkGapSha256(diagnostic)}\",\"retryUsed\":false,\"fallbackUsed\":false}\n";ckbAbcdeWriteText("${groupRoot}/claude-attempts.jsonl",attempt);let lineage=ckbAbcdeAttemptLineageHash(attempt,"");let summary="{\"transportAttemptCount\":1,\"sampleAttemptCount\":1,\"lastAuditedTransportAttempt\":1,\"selectedBusinessSample\":1,\"selectedTransportAttempt\":1,\"retryCount\":0,\"unresolvedTransport\":0,\"attemptLineageHash\":\"${lineage}\",\"workspaceRestoreEvidenceHash\":\"${benchmarkGapSha256("")}\",\"attemptsPath\":\"claude-attempts.jsonl\",\"restoresPath\":\"workspace-restores.jsonl\"}";ckbAbcdeWriteText("${groupRoot}/attempt-evidence.json",summary);let testResult=summary.replace("}",",\"testExitCode\":0,\"unitPassAt1\":true,\"failureType\":\"none\",\"testLogPath\":\"${groupRoot}/test.log\"}");ckbAbcdeWriteText("${groupRoot}/test-result.json",testResult)
    let row=ckbAbcdeRenderStrictCertificationCaseForTest(options,caseId,CkbAbcdeGroups.D,groupRoot,answerHash,transcript,"tests passed",true,"none",true);ckbAbcdeWriteText("${groupRoot}/result-evidence.json",row);row
}

private func ckbAbcdeObservedModel(transcript:String):String{for(line in transcript.split("\n")){try{let o=JsonValue.fromStr(line).asObject();if(ckbAbcdeStrictJsonString(o,"subtype")=="init"){return ckbAbcdeStrictJsonString(o,"model")}}catch(_:Exception){}};""}

private func ckbAbcdeStrictSandboxProbeOk(raw:String,workspace:String,runtimeHome:String):Bool{try{let o=JsonValue.fromStr(raw).asObject();ckbAbcdeStrictJsonBool(o,"ok")&&ckbAbcdeStrictJsonBool(o,"deniedOutsideWorkspace")&&ckbAbcdeStrictJsonBool(o,"deniedTests")&&ckbAbcdeStrictJsonBool(o,"deniedReference")&&ckbAbcdeStrictJsonBool(o,"deniedTeacher")&&ckbAbcdeStrictJsonBool(o,"deniedStore")&&ckbAbcdeStrictJsonString(o,"workspaceCanonical")==canonicalize(Path(workspace)).toString()&&ckbAbcdeStrictJsonString(o,"runtimeHomeCanonical")==canonicalize(Path(runtimeHome)).toString()}catch(_:Exception){false}}
private func ckbAbcdeStrictVerifierMountOk(raw:String,answerHash:String):Bool{try{let o=JsonValue.fromStr(raw).asObject();ckbAbcdeStrictJsonInt(o,"injectExitCode",-1)==0&&ckbAbcdeStrictJsonString(o,"answerHashBefore")==answerHash&&ckbAbcdeStrictJsonString(o,"answerHashAfter")==answerHash&&ckbAbcdeStrictJsonBool(o,"mountedAfterFreeze")}catch(_:Exception){false}}
private func ckbAbcdeTranscriptHasOtherCase(raw:String,current:String):Bool{for(i in 0..164){let id=ckbAbcdeCaseId(i);if(id!=current&&raw.contains(id)){return true}};false}

private func ckbAbcdeRunClaude(options: CkbAbcdeRunnerOptions, group: String, groupRoot: String, workspace: String, runtimeHome: String, docsRoot: String, caseSrc: String, authoritativeWorkspace: String): CkbAbcdeCommandResult {
    var last = CkbAbcdeCommandResult()
    let attemptLimit = ckbAbcdeDevelopmentTransportAttemptLimit(options.transportRetries)
    for (transportAttempt in 1..=attemptLimit) {
        var restoreJson = "{\"transportAttempt\":${transportAttempt},\"restored\":false,\"diagnostic\":\"initial_authoritative_copy\"}"
        if (transportAttempt > 1) {
            restoreJson = ckbAbcdeRestoreWorkspaceForRetry(workspace, authoritativeWorkspace, transportAttempt)
            ckbAbcdeAppendText("${groupRoot}/workspace-restores.jsonl", restoreJson + "\n")
            if (!restoreJson.contains("\"restored\":true")) {
                let blocked = CkbAbcdeCommandResult(); blocked.exitCode = 125; blocked.stderr = "workspace_restore_failed"; return blocked
            }
        }
        let current = ckbAbcdeRunClaudeOnce(group, groupRoot, workspace, runtimeHome, docsRoot, caseSrc, options.ckbBin, options.ckbConfig, options.ckbStore, options.claudeBin, transportAttempt, options.expectedModelVersion, options.modelTimeoutSeconds, options.modelEffort, options.modelMaxBudgetUsd)
        last = current
        let transcript = ckbAbcdeReadText("${groupRoot}/claude-transcript.attempt-${transportAttempt}.jsonl")
        let assessment = ckbAbcdeAssessSample(transcript, options.expectedModelVersion)
        let diagnostic = ckbAbcdeReadTransportDiagnostic("${groupRoot}/claude.attempt-${transportAttempt}.stderr.log")
        let classification = ckbAbcdeTransportClassification(current.exitCode, assessment, diagnostic)
        ckbAbcdeWriteText("${groupRoot}/model-transport-diagnostic.attempt-${transportAttempt}.json", ckbAbcdeRenderModelTransportDiagnostic(transcript, current.exitCode, assessment, options.modelTimeoutSeconds, options.modelEffort, options.modelMaxBudgetUsd) + "\n")
        let restoreHash = if (transportAttempt > 1) { benchmarkGapSha256(restoreJson) } else { "" }
        ckbAbcdeAppendText("${groupRoot}/claude-attempts.jsonl", "{\"attempt\":${transportAttempt},\"transportAttempt\":${transportAttempt},\"sampleAttempt\":${if (current.exitCode == 0 && assessment.completeResult && assessment.identityMatched) { 1 } else { 0 }},\"exitCode\":${current.exitCode},\"classification\":\"${classification}\",\"completeResult\":${assessment.completeResult},\"identityMatched\":${assessment.identityMatched},\"workspaceRestored\":${transportAttempt > 1 && restoreJson.contains("\"restored\":true")},\"restoreEvidenceHash\":\"${restoreHash}\"}\n")
        if (current.exitCode == 0 && assessment.completeResult && assessment.identityMatched) {
            ckbAbcdePublishClaudeSampleArtifacts(groupRoot, transportAttempt)
            return current
        }
        if (!ckbAbcdeShouldRetryTransport(current.exitCode, assessment, diagnostic: diagnostic)) {
            ckbAbcdePublishClaudeAttemptArtifacts(groupRoot, transportAttempt)
            return current
        }
    }
    ckbAbcdePublishClaudeAttemptArtifacts(groupRoot, attemptLimit)
    last
}

private func ckbAbcdeDevelopmentTransportAttemptLimit(transportRetries: Int64): Int64 {
    transportRetries + 1
}

public func ckbAbcdeDevelopmentTransportAttemptLimitForTest(transportRetries: Int64): Int64 {
    ckbAbcdeDevelopmentTransportAttemptLimit(transportRetries)
}

public func ckbAbcdeAssessSample(transcript: String, expectedModel: String): CkbAbcdeSampleAssessment {
    let result = CkbAbcdeSampleAssessment()
    if(transcript==""){result.transcriptDiagnostic="empty_transcript";return result}
    try {
        let terminal=JsonValue.fromStr(transcript).asObject()
        if(ckbAbcdeStrictJsonString(terminal,"type")=="result"){
            let completion=ckbAbcdeExtractSingleCompletion(transcript.toArray());result.terminalResultCount=1
            result.completeResult=completion.ok;result.identityMatched=completion.ok&&expectedModel=="GLM-5.2"
            result.sampleAttempt=if(result.identityMatched){1}else{0};result.transcriptDiagnostic=completion.diagnostic
            return result
        }
    } catch (_:Exception) {}
    var observedModel = ""
    var initCount:Int64=0;var terminalCount:Int64=0
    let knowledgeToolUseIds = HashSet<String>()
    for (line in transcript.split("\n")) {
        if(line.trimAscii()==""){continue}
        try {
            let object = JsonValue.fromStr(line).asObject()
            if (ckbAbcdeStrictJsonString(object, "type") != "assistant") { continue }
            let content = object.get("message").getOrThrow().asObject().get("content").getOrThrow().asArray().getItems()
            for (value in content) {
                let entry = value.asObject()
                if (ckbAbcdeStrictJsonString(entry, "type") == "tool_use" && ckbAbcdeStrictJsonString(entry, "name").contains("mcp__ckb-cangjie-")) {
                    let id = ckbAbcdeStrictJsonString(entry, "id")
                    if (id != "") { knowledgeToolUseIds.add(id) }
                }
            }
        } catch (_: Exception) {}
    }
    for (line in transcript.split("\n")) {
        if(line.trimAscii()==""){continue}
        try {
            let object = JsonValue.fromStr(line).asObject()
            if (ckbAbcdeStrictJsonString(object, "subtype") == "init") { initCount+=1;observedModel = ckbAbcdeStrictJsonString(object, "model") }
            if(line.contains("\"type\":\"tool_use\"")||line.contains("\"type\":\"tool_result\"")){result.toolEventCount+=1}
            if (ckbAbcdeStrictJsonString(object, "type") == "user") {
                let content = object.get("message").getOrThrow().asObject().get("content").getOrThrow().asArray().getItems()
                for (value in content) {
                    let entry = value.asObject()
                    if (ckbAbcdeStrictJsonString(entry, "type") != "tool_result" || !knowledgeToolUseIds.contains(ckbAbcdeStrictJsonString(entry, "tool_use_id"))) { continue }
                    let lower = entry.toString().toAsciiLower()
                    if (lower.contains("\"is_error\":true") || lower.contains("mcp_error") || lower.contains("tool_result_failed") || lower.contains("knowledge_transport_failure")) { result.toolFailureCount += 1 }
                }
            }
            if (ckbAbcdeStrictJsonString(object, "type") == "result") { terminalCount+=1;result.terminalResultCount+=1;if(ckbAbcdeStrictJsonString(object, "subtype") == "success" && !ckbAbcdeStrictJsonBool(object, "is_error")){result.completeResult = true} }
        } catch (_: Exception) {result.transcriptDiagnostic="malformed_json"}
    }
    if(result.transcriptDiagnostic=="ok"&&(initCount!=1||terminalCount>1)){result.transcriptDiagnostic="protocol_violation"}
    result.identityMatched = result.completeResult && observedModel == expectedModel
    result.sampleAttempt = if (result.identityMatched) { 1 } else { 0 }
    result
}

public func ckbAbcdeRenderModelTransportDiagnostic(transcript: String, exitCode: Int64, assessment: CkbAbcdeSampleAssessment, timeoutSeconds: Int64, effort: String, maxBudgetUsd: String): String {
    let toolUses = ckbAbcdeCountOccurrences(transcript, "\"type\":\"tool_use\"")
    let toolResults = ckbAbcdeCountOccurrences(transcript, "\"type\":\"tool_result\"")
    let thinkingEvents = ckbAbcdeCountOccurrences(transcript, "\"subtype\":\"thinking_tokens\"")
    let reason = if (exitCode == 124 && assessment.terminalResultCount == 0) { "provider_no_terminal_result_timeout" } else if (exitCode == 124) { "provider_timeout" } else if (exitCode != 0) { "process_exit_failure" } else if (!assessment.completeResult) { "missing_terminal_result" } else if (!assessment.identityMatched) { "model_identity_mismatch" } else { "ok" }
    "{\"exitCode\":${exitCode},\"timeoutSeconds\":${timeoutSeconds},\"effort\":\"${ckbAbcdeJsonEscape(effort)}\",\"maxBudgetUsd\":\"${ckbAbcdeJsonEscape(maxBudgetUsd)}\",\"completeResult\":${assessment.completeResult},\"identityMatched\":${assessment.identityMatched},\"sampleEligible\":${exitCode == 0 && assessment.sampleAttempt == 1},\"toolUseCount\":${toolUses},\"toolResultCount\":${toolResults},\"thinkingEventCount\":${thinkingEvents},\"terminalDiagnostic\":\"${reason}\"}"
}

public func ckbAbcdeTransportClassification(exitCode:Int64,assessment:CkbAbcdeSampleAssessment,diagnostic:String):String{
    if(assessment.transcriptDiagnostic!="ok"&&assessment.transcriptDiagnostic!="empty_transcript"){return "non_retryable_transport_error"}
    if(exitCode==0&&assessment.completeResult){return if(assessment.identityMatched){"business_sample"}else{"model_identity_mismatch"}}
    let value=diagnostic.toAsciiLower()
    for(blocked in ["mcp_error","tool_result_failed","knowledge_transport_failure","ckb_transport_error"]){if(value.contains(blocked)){return "knowledge_transport_failure"}}
    for(blocked in ["invalid_response_encoding","transcript_too_large","diagnostic_too_large","malformed_json","protocol violation","protocol_violation","sandbox","identity mismatch"]){if(value.contains(blocked)){return "non_retryable_transport_error"}}
    if(assessment.toolFailureCount>0){return "knowledge_transport_failure"}
    if(exitCode==124){return "timeout"}
    if(exitCode!=0){for(marker in ["connection reset","connection aborted","connection refused","broken pipe","network connection lost","connection closed"]){if(value.contains(marker)){return "connection_interrupted"}};for(marker in ["service unavailable","temporarily unavailable","server unavailable","http 502","http 503","http 504","overloaded_error"]){if(value.contains(marker)){return "service_unavailable"}};return "terminal_failure"}
    if(assessment.completeResult){return if(assessment.identityMatched){"business_sample"}else{"model_identity_mismatch"}}
    if(assessment.terminalResultCount>0){return "terminal_failure"}
    "unknown_transport_error"
}

public func ckbAbcdeShouldRetryTransport(exitCode:Int64,assessment:CkbAbcdeSampleAssessment,diagnostic!:String=""):Bool{
    let classification=ckbAbcdeTransportClassification(exitCode,assessment,diagnostic)
    classification=="timeout"||classification=="connection_interrupted"||classification=="service_unavailable"
}

public func ckbAbcdeAttemptLineageHash(attempts:String,restores:String):String{benchmarkGapSha256("${attempts.toArray().size}:${attempts}${restores.toArray().size}:${restores}")}

public func ckbAbcdeAttemptLineageDiagnostic(attempts:String,restores:String,transportAttemptCount:Int64,sampleAttemptCount:Int64):String{
    if(transportAttemptCount<1||sampleAttemptCount<0||sampleAttemptCount>1){return "business_sample_count_invalid"}
    let restoreDiagnostic=ckbAbcdeRestoreLineageDiagnostic(restores,transportAttemptCount);if(restoreDiagnostic!="ok"){return restoreDiagnostic}
    var count:Int64=0;var samples:Int64=0;let sessions=HashSet<String>();let homes=HashSet<String>()
    for(line in attempts.split("\n")){if(line.trimAscii()==""){continue};count+=1;try{let row=JsonValue.fromStr(line).asObject();if(ckbAbcdeStrictJsonInt(row,"transportAttempt",-1)!=count){return "transport_attempt_sequence_invalid"};for(key in ["sessionIdHash","runtimeHomeId","sandboxProbeHash","transcriptHash","stderrHash","diagnosticHash"]){if(!ckbAbcdeStrictSha256(ckbAbcdeStrictJsonString(row,key))){return "transport_artifact_binding_missing"}};let session=ckbAbcdeStrictJsonString(row,"sessionIdHash");let home=ckbAbcdeStrictJsonString(row,"runtimeHomeId");if(sessions.contains(session)||homes.contains(home)){return "transport_isolation_identity_reuse"};sessions.add(session);homes.add(home);let sample=ckbAbcdeStrictJsonInt(row,"sampleAttempt",-1);let classification=ckbAbcdeStrictJsonString(row,"classification");if(sample==1){samples+=1;if(classification!="business_sample"){return "business_sample_classification_invalid"}}else if(sample!=0){return "business_sample_count_invalid"}else if(classification!="timeout"&&classification!="connection_interrupted"&&classification!="service_unavailable"&&count<transportAttemptCount){return "non_retryable_attempt_followed_by_retry"};if(count>1){let restoreHash=ckbAbcdeStrictJsonString(row,"restoreEvidenceHash");if(!ckbAbcdeStrictJsonBool(row,"workspaceRestored")||!ckbAbcdeStrictSha256(restoreHash)){return "transport_restore_binding_invalid"};var matched=false;for(restore in restores.split("\n")){if(restore.trimAscii()==""){continue};if(benchmarkGapSha256(restore)==restoreHash){let object=JsonValue.fromStr(restore).asObject();if(ckbAbcdeStrictJsonInt(object,"transportAttempt",-1)==count&&ckbAbcdeStrictJsonBool(object,"restored")){matched=true}}};if(!matched){return "transport_restore_binding_invalid"}}}catch(_:Exception){return "transport_lineage_malformed"}}
    if(count!=transportAttemptCount){return "transport_attempt_count_mismatch"};if(samples!=sampleAttemptCount){return "business_sample_count_invalid"};"ok"
}

private func ckbAbcdeRestoreLineageDiagnostic(restores:String,transportAttemptCount:Int64):String{
    var count:Int64=0;let seen=HashSet<Int64>();for(line in restores.split("\n")){if(line.trimAscii()==""){continue};count+=1;try{let row=JsonValue.fromStr(line).asObject();let attempt=ckbAbcdeStrictJsonInt(row,"transportAttempt",-1);if(attempt<2||attempt>transportAttemptCount||seen.contains(attempt)){return "transport_restore_sequence_invalid"};seen.add(attempt);let restored=ckbAbcdeStrictJsonBool(row,"restored");let before=ckbAbcdeStrictJsonString(row,"beforeHash");let authority=ckbAbcdeStrictJsonString(row,"authorityHash");let after=ckbAbcdeStrictJsonString(row,"afterHash");let diagnostic=ckbAbcdeStrictJsonString(row,"diagnostic");let base="{\"transportAttempt\":${attempt},\"restored\":${restored},\"beforeHash\":\"${before}\",\"authorityHash\":\"${authority}\",\"afterHash\":\"${after}\",\"diagnostic\":\"${diagnostic}\"}";if(!restored||authority!=after||!ckbAbcdeStrictSha256(before)||!ckbAbcdeStrictSha256(authority)||ckbAbcdeStrictJsonString(row,"evidenceHash")!=benchmarkGapSha256(base)){return "transport_restore_evidence_invalid"}}catch(_:Exception){return "transport_restore_evidence_invalid"}}
    if(count!=transportAttemptCount-1){return "transport_restore_count_mismatch"};if(transportAttemptCount>1){for(attempt in 2..=transportAttemptCount){if(!seen.contains(attempt)){return "transport_restore_sequence_invalid"}}};"ok"
}

public func ckbAbcdeRunFakeTransportRetryForTest(root:String,workspace:String,authoritativeWorkspace:String,frozenPointerPath:String,exitCodes:Array<Int64>,diagnostics:Array<String>,transcripts:Array<String>,expectedModel:String,retryBudget:Int64):String{
    if(exitCodes.size!=diagnostics.size||exitCodes.size!=transcripts.size||retryBudget<0){return "{\"diagnostic\":\"fake_transport_input_invalid\"}"}
    ckbAbcdeEnsureDir(root);let pointerBefore=benchmarkGapSha256(ckbAbcdeReadText(frozenPointerPath));var attempts="";var restores="";var attemptCount:Int64=0;var sampleCount:Int64=0
    let attemptLimit=ckbAbcdeDevelopmentTransportAttemptLimit(retryBudget)
    let limit=if(exitCodes.size<attemptLimit){exitCodes.size}else{attemptLimit}
    for(i in 0..limit){let attempt=Int64(i)+1;attemptCount=attempt;var restore="";if(attempt>1){restore=ckbAbcdeRestoreWorkspaceForRetry(workspace,authoritativeWorkspace,attempt);restores+=restore+"\n";if(!restore.contains("\"restored\":true")){break}}
        let home="${root}/runtime-home/attempt-${attempt}";ckbAbcdeEnsureDir(home);let session="fake-session-${attempt}";let probe="{\"ok\":true,\"attempt\":${attempt}}";let assessment=ckbAbcdeAssessSample(transcripts[i],expectedModel);let classification=ckbAbcdeTransportClassification(exitCodes[i],assessment,diagnostics[i]);let sample=if(exitCodes[i]==0&&assessment.completeResult&&assessment.identityMatched){1}else{0};sampleCount+=sample
        attempts+="{\"transportAttempt\":${attempt},\"sampleAttempt\":${sample},\"classification\":\"${classification}\",\"workspaceRestored\":${attempt>1},\"restoreEvidenceHash\":\"${if(attempt>1){benchmarkGapSha256(restore)}else{""}}\",\"sessionIdHash\":\"${benchmarkGapSha256(session)}\",\"runtimeHomeId\":\"${benchmarkGapSha256(home)}\",\"sandboxProbeHash\":\"${benchmarkGapSha256(probe)}\",\"transcriptHash\":\"${benchmarkGapSha256(transcripts[i])}\",\"stderrHash\":\"${benchmarkGapSha256(diagnostics[i])}\",\"diagnosticHash\":\"${benchmarkGapSha256(classification+diagnostics[i])}\"}\n"
        if(sample==1||!ckbAbcdeShouldRetryTransport(exitCodes[i],assessment,diagnostic:diagnostics[i])){break}
    }
    let pointerAfter=benchmarkGapSha256(ckbAbcdeReadText(frozenPointerPath));let lineage=ckbAbcdeAttemptLineageDiagnostic(attempts,restores,attemptCount,sampleCount);ckbAbcdeWriteText("${root}/fake-attempts.jsonl",attempts);ckbAbcdeWriteText("${root}/fake-restores.jsonl",restores)
    "{\"transportAttemptCount\":${attemptCount},\"sampleAttemptCount\":${sampleCount},\"retryCount\":${if(attemptCount>0){attemptCount-1}else{0}},\"lineageDiagnostic\":\"${lineage}\",\"attemptLineageHash\":\"${ckbAbcdeAttemptLineageHash(attempts,restores)}\",\"frozenPointerBeforeHash\":\"${pointerBefore}\",\"frozenPointerAfterHash\":\"${pointerAfter}\",\"frozenPointerUnchanged\":${pointerBefore==pointerAfter}}"
}

public func ckbAbcdeRestoreWorkspaceForRetry(workspace: String, authoritativeWorkspace: String, transportAttempt: Int64): String {
    let beforeHash = benchmarkGapSha256(ckbAbcdeReadText("${workspace}/src/solution.cj"))
    let authorityHash = benchmarkGapSha256(ckbAbcdeReadText("${authoritativeWorkspace}/src/solution.cj"))
    let restored = ckbAbcdeRunShell("rm -rf ${ckbAbcdeShellQuote(workspace)} && cp -R ${ckbAbcdeShellQuote(authoritativeWorkspace)} ${ckbAbcdeShellQuote(workspace)}", "")
    let afterHash = benchmarkGapSha256(ckbAbcdeReadText("${workspace}/src/solution.cj"))
    let ok = restored.exitCode == 0 && afterHash == authorityHash
    let base = "{\"transportAttempt\":${transportAttempt},\"restored\":${ok},\"beforeHash\":\"${beforeHash}\",\"authorityHash\":\"${authorityHash}\",\"afterHash\":\"${afterHash}\",\"diagnostic\":\"${if (ok) { "ok" } else { "workspace_restore_failed" }}\"}"
    base.replace("}", ",\"evidenceHash\":\"${benchmarkGapSha256(base)}\"}")
}

private func ckbAbcdePublishClaudeSampleArtifacts(groupRoot: String, transportAttempt: Int64): Unit {
    let transcript = ckbAbcdeReadText("${groupRoot}/claude-transcript.attempt-${transportAttempt}.jsonl")
    let stderr = ckbAbcdeReadText("${groupRoot}/claude.attempt-${transportAttempt}.stderr.log")
    ckbAbcdeWriteText("${groupRoot}/claude-transcript.jsonl", transcript)
    ckbAbcdeWriteText("${groupRoot}/claude.stdout.log", transcript)
    ckbAbcdeWriteText("${groupRoot}/claude.stderr.log", stderr)
}

private func ckbAbcdeInitializeWorkspaceRestoreEvidence(groupRoot: String): Unit {
    ckbAbcdeWriteText("${groupRoot}/workspace-restores.jsonl", "")
}

public func ckbAbcdeInitializeWorkspaceRestoreEvidenceForTest(groupRoot: String): Unit {
    ckbAbcdeInitializeWorkspaceRestoreEvidence(groupRoot)
}

private func ckbAbcdeRunClaudeCertification(options:CkbAbcdeRunnerOptions,group:String,groupRoot:String,workspace:String,runtimeHome:String,caseSrc:String):CkbAbcdeCommandResult{
    let claude=ckbAbcdeResolveClaudeExecutable(options.claudeBin)
    if(!claude.valid){let blocked=CkbAbcdeCommandResult();blocked.exitCode=126;blocked.stderr=claude.diagnostic;return blocked}
    let dependencyDiagnostic=ckbAbcdeSandboxDependencyDiagnostic(ckbAbcdeOpenSslCanonicalPairReady(),ckbAbcdeCurrentMagicStdxPath()!="")
    if(dependencyDiagnostic!="ok"){let blocked=CkbAbcdeCommandResult();blocked.exitCode=126;blocked.stderr=dependencyDiagnostic;return blocked}
    let authority="${groupRoot}/authoritative-workspace";let copied=ckbAbcdeRunShell("rm -rf ${ckbAbcdeShellQuote(authority)} && cp -R ${ckbAbcdeShellQuote(workspace)} ${ckbAbcdeShellQuote(authority)}","");if(copied.exitCode!=0){let blocked=CkbAbcdeCommandResult();blocked.exitCode=126;blocked.stderr="authoritative_workspace_snapshot_failed";return blocked}
    ckbAbcdeWriteText("${groupRoot}/runtime-policy.json","{\"model\":\"${ckbAbcdeJsonEscape(options.expectedModelVersion)}\",\"modelTimeoutSeconds\":${options.modelTimeoutSeconds},\"sampleAttempts\":1,\"internalTurns\":\"audited_not_gated\",\"agentAttempts\":1,\"transportRetries\":${options.transportRetries},\"providerRetries\":0,\"sdkRetries\":0,\"fallbackEnabled\":false}\n")
    ckbAbcdeInitializeWorkspaceRestoreEvidence(groupRoot)
    var last=CkbAbcdeCommandResult()
    for(transportAttempt in 1..=(options.transportRetries+1)){
        var restoreJson="";if(transportAttempt>1){restoreJson=ckbAbcdeRestoreWorkspaceForRetry(workspace,authority,transportAttempt);ckbAbcdeAppendText("${groupRoot}/workspace-restores.jsonl",restoreJson+"\n");if(!restoreJson.contains("\"restored\":true")){let blocked=CkbAbcdeCommandResult();blocked.exitCode=125;blocked.stderr="workspace_restore_failed";return blocked}}
        let attemptHome="${runtimeHome}/attempt-${transportAttempt}";let runtimeDiagnostic=ckbAbcdePrepareClaudeRuntimeHome(attemptHome);if(runtimeDiagnostic!="ok"){let blocked=CkbAbcdeCommandResult();blocked.exitCode=126;blocked.stderr=runtimeDiagnostic;return blocked}
        let cangjieHome=match(getVariable("CANGJIE_HOME")){case Some(value)=>value case None=>""};let archiverDiagnostic=ckbAbcdePrepareBundledArchiver(attemptHome,cangjieHome);if(archiverDiagnostic!="ok"){let blocked=CkbAbcdeCommandResult();blocked.exitCode=126;blocked.stderr=archiverDiagnostic;return blocked}
        let profilePath="${groupRoot}/certification.attempt-${transportAttempt}.sb";ckbAbcdeWriteText(profilePath,ckbAbcdeCertificationSandboxProfile(workspace,attemptHome,options.ckbBin,options.ckbConfig,options.ckbStore,caseSrc,claude.requested,claude.canonical,group:group))
        let probe=ckbAbcdeCertificationSandboxProbe(profilePath,workspace,attemptHome,caseSrc,options.ckbStore);ckbAbcdeWriteText("${groupRoot}/sandbox-probe.attempt-${transportAttempt}.json",probe.stdout);if(probe.exitCode!=0){let blocked=CkbAbcdeCommandResult();blocked.exitCode=126;blocked.stderr="certification_sandbox_probe_failed";return blocked}
        let current=ckbAbcdeRunClaudeOnceInCertificationSandbox(group,groupRoot,workspace,attemptHome,profilePath,claude.canonical,options.expectedModelVersion,options.modelTimeoutSeconds,transportAttempt);last=current
        let transcriptPath="${groupRoot}/claude-transcript.attempt-${transportAttempt}.jsonl";let transcriptRead=ckbAbcdeSanitizeTranscriptArtifact(transcriptPath,ckbAbcdeSandboxTranscriptPath(attemptHome));let transcript=if(transcriptRead.ok){transcriptRead.text}else{""};let assessment=ckbAbcdeAssessSample(transcript,options.expectedModelVersion);if(!transcriptRead.ok){assessment.transcriptDiagnostic=transcriptRead.diagnostic}
        let stderrPath="${groupRoot}/claude.attempt-${transportAttempt}.stderr.log";let stderrRead=ckbAbcdeSanitizeStderrArtifact(stderrPath,ckbAbcdeSandboxStderrPath(attemptHome));let diagnostic=if(stderrRead.ok){stderrRead.text}else{stderrRead.diagnostic};let classification=ckbAbcdeTransportClassification(current.exitCode,assessment,diagnostic)
        let diagnosticJson=ckbAbcdeRenderModelTransportDiagnostic(transcript,current.exitCode,assessment,options.modelTimeoutSeconds,"certification","");ckbAbcdeWriteText("${groupRoot}/model-transport-diagnostic.attempt-${transportAttempt}.json",diagnosticJson+"\n")
        let restoreHash=if(transportAttempt>1){benchmarkGapSha256(restoreJson)}else{""};let session=ckbAbcdeReadText("${groupRoot}/session-id.attempt-${transportAttempt}.txt")
        ckbAbcdeAppendText("${groupRoot}/claude-attempts.jsonl","{\"attempt\":${transportAttempt},\"transportAttempt\":${transportAttempt},\"modelTimeoutSeconds\":${options.modelTimeoutSeconds},\"sampleAttempt\":${if(current.exitCode==0&&assessment.completeResult&&assessment.identityMatched){1}else{0}},\"exitCode\":${current.exitCode},\"classification\":\"${classification}\",\"completeResult\":${assessment.completeResult},\"identityMatched\":${assessment.identityMatched},\"workspaceRestored\":${transportAttempt>1},\"restoreEvidenceHash\":\"${restoreHash}\",\"sessionIdHash\":\"${benchmarkGapSha256(session)}\",\"runtimeHomeId\":\"${benchmarkGapSha256(try{canonicalize(Path(attemptHome)).toString()}catch(_:Exception){attemptHome})}\",\"sandboxProbeHash\":\"${benchmarkGapSha256(probe.stdout)}\",\"transcriptHash\":\"${benchmarkGapSha256(transcript)}\",\"stderrHash\":\"${benchmarkGapSha256(diagnostic)}\",\"diagnosticHash\":\"${benchmarkGapSha256(diagnosticJson+"\n")}\",\"retryUsed\":false,\"fallbackUsed\":false}\n")
        if(current.exitCode==0&&assessment.completeResult&&assessment.identityMatched){ckbAbcdePublishClaudeSampleArtifacts(groupRoot,transportAttempt);ckbAbcdeWriteText("${groupRoot}/sandbox-probe.json",probe.stdout);ckbAbcdeWriteText("${groupRoot}/session-id.txt",session);return current}
        if(!ckbAbcdeShouldRetryTransport(current.exitCode,assessment,diagnostic:diagnostic)){ckbAbcdePublishLastAuditedCertificationArtifacts(groupRoot,transportAttempt);return current}
    }
    ckbAbcdePublishLastAuditedCertificationArtifacts(groupRoot,options.transportRetries+1);last
}

public func ckbAbcdeCertificationSandboxProfile(workspace:String,runtimeHome:String,ckbBin:String,ckbConfig:String,ckbStore:String,caseSrc:String,claudeRequested:String,claudeCanonical:String,group!:String=CkbAbcdeGroups.D):String{
    let w=ckbAbcdeSandboxPath(workspace);let h=ckbAbcdeSandboxPath(runtimeHome);let bin=ckbAbcdeSandboxPath(ckbBin);let config=ckbAbcdeSandboxPath(ckbConfig);let store=ckbAbcdeSandboxPath(ckbStore);let tests=ckbAbcdeSandboxPath("${caseSrc}/tests");let reference=ckbAbcdeSandboxPath("${caseSrc}/translation");let teacher=ckbAbcdeSandboxPath("/Users/l3gi0n/work/workspace_cangjie/CangjieTeacher")
    let requested=ckbAbcdeSandboxLiteral(claudeRequested);let canonical=ckbAbcdeSandboxLiteral(claudeCanonical);let storeRead=if(group==CkbAbcdeGroups.C){" (subpath \"${store}\")"}else{""};let storeMetadata=if(group==CkbAbcdeGroups.C){ckbAbcdeSandboxMetadataPaths(ckbStore)}else{""};let magic=ckbAbcdeCurrentMagicStdxPath();let magicRead=if(magic==""){""}else{" (subpath \"${ckbAbcdeSandboxLiteral(magic)}\")"};let magicMetadata=if(magic==""){""}else{ckbAbcdeSandboxMetadataPaths(magic)};let opensslRead=ckbAbcdeOpenSslCanonicalReadRules();let opensslMetadata=ckbAbcdeOpenSslCanonicalMetadataRules();let archiver=ckbAbcdeCurrentBundledArchiver();let archiverRead=if(archiver==""){""}else{" (literal \"${ckbAbcdeSandboxLiteral(archiver)}\")"};let archiverMetadata=if(archiver==""){""}else{ckbAbcdeSandboxMetadataPaths(archiver)};let dsymutil="/usr/bin/dsymutil";let dsymutilRead=" (literal \"${dsymutil}\")";let dsymutilMetadata=ckbAbcdeSandboxMetadataPaths(dsymutil);let cangjieHome=match(getVariable("CANGJIE_HOME")){case Some(value)=>try{canonicalize(Path(value)).toString()}catch(_:Exception){""} case None=>""};let sdkRoot=match(getVariable("SDKROOT")){case Some(value)=>try{canonicalize(Path(value)).toString()}catch(_:Exception){""} case None=>""};let sdkRead=if(cangjieHome==""){""}else{" (subpath \"${ckbAbcdeSandboxLiteral(cangjieHome)}\")"};let macSdkRead=if(sdkRoot==""){""}else{" (subpath \"${ckbAbcdeSandboxLiteral(sdkRoot)}\")"};let sdkMetadata=if(cangjieHome==""){""}else{ckbAbcdeSandboxMetadataPaths(cangjieHome)};let macSdkMetadata=if(sdkRoot==""){""}else{ckbAbcdeSandboxMetadataPaths(sdkRoot)};let metadata=ckbAbcdeSandboxMetadataPaths(workspace)+ckbAbcdeSandboxMetadataPaths(runtimeHome)+ckbAbcdeSandboxMetadataPaths(ckbBin)+ckbAbcdeSandboxMetadataPaths(ckbConfig)+storeMetadata+ckbAbcdeSandboxMetadataPaths(claudeRequested)+ckbAbcdeSandboxMetadataPaths(claudeCanonical)+magicMetadata+opensslMetadata+archiverMetadata+dsymutilMetadata+sdkMetadata+macSdkMetadata
    "(version 1)\n(import \"system.sb\")\n(deny default)\n(allow process*)\n(allow sysctl-read)\n(allow mach-lookup)\n(allow network*)\n(allow file-read-metadata${metadata} (literal \"/dev\") (literal \"/dev/fd\") (literal \"/dev/fd/0\") (literal \"/dev/stdin\"))\n(allow file-read* (literal \"/dev/fd/0\") (literal \"/dev/stdin\") (literal \"${requested}\") (literal \"${canonical}\") (subpath \"${w}\") (subpath \"${h}\") (literal \"${bin}\") (literal \"${config}\")${storeRead}${magicRead}${opensslRead}${archiverRead}${dsymutilRead}${sdkRead}${macSdkRead})\n(allow file-write* (subpath \"${w}\") (subpath \"${h}\"))\n(deny file-read* (subpath \"${tests}\") (subpath \"${reference}\") (subpath \"${teacher}\") (subpath \"${store}\"))\n"
}

private func ckbAbcdeSandboxLiteral(value:String):String{value.replace("\\","\\\\").replace("\"","\\\"")}
private func ckbAbcdeSandboxPath(value:String):String{ckbAbcdeSandboxLiteral(try{canonicalize(Path(value)).toString()}catch(_:Exception){value})}

private func ckbAbcdeCertificationSandboxProbe(profilePath:String,workspace:String,runtimeHome:String,caseSrc:String,ckbStore:String):CkbAbcdeCommandResult{
    let workspacePath=try{canonicalize(Path(workspace)).toString()}catch(_:Exception){workspace};let homePath=try{canonicalize(Path(runtimeHome)).toString()}catch(_:Exception){runtimeHome};let casePath=try{canonicalize(Path(caseSrc)).toString()}catch(_:Exception){caseSrc};let sandboxProfile=try{canonicalize(Path(profilePath)).toString()}catch(_:Exception){profilePath}
    ckbAbcdeEnsureDir("${homePath}/tmp")
    let cangjieHome=match(getVariable("CANGJIE_HOME")){case Some(value)=>try{canonicalize(Path(value)).toString()}catch(_:Exception){""} case None=>""};let sdkRoot=match(getVariable("SDKROOT")){case Some(value)=>try{canonicalize(Path(value)).toString()}catch(_:Exception){""} case None=>""};let project="${homePath}/sandbox-build-probe";ckbAbcdeEnsureDir("${project}/src");ckbAbcdeWriteText("${project}/cjpm.toml","[package]\n  cjc-version = \"1.0.0\"\n  name = \"ckb_certification_sandbox_probe\"\n  version = \"0.1.0\"\n  output-type = \"static\"\n  src-dir = \"\"\n");ckbAbcdeWriteText("${project}/src/solution.cj","package ckb_certification_sandbox_probe\n\npublic func sandboxProbe(): String { \"仓颉🙂\" }\n")
    let marker="${workspacePath}/.sandbox-write-probe";let stdinProbe="${homePath}/sandbox-stdin-probe.txt";ckbAbcdeWriteText(stdinProbe,"sandbox-stdin-仓颉🙂\n")
    let outside=Path(workspacePath).parent.join(".sandbox-outside-probe").toString();let tempSibling=Path(homePath).parent.join("claude-sibling-cwd").toString();let externalTemp="/tmp/claude-external-${ckbCoreNowMillis()}-cwd"
    let script="IFS= read -r stdin_marker; [ \"$stdin_marker\" = 'sandbox-stdin-仓颉🙂' ] || exit 37; [ \"$HOME\" = ${ckbAbcdeShellQuote(homePath)} ] || exit 38; [ \"$CLAUDE_CODE_TMPDIR\" = ${ckbAbcdeShellQuote("${homePath}/tmp")} ] || exit 39; [ \"$CLAUDE_TMPDIR\" = ${ckbAbcdeShellQuote("${homePath}/tmp")} ] || exit 40; one=\"$CLAUDE_CODE_TMPDIR/claude-0001-cwd\"; two=\"$CLAUDE_CODE_TMPDIR/claude-0002-cwd\"; [ \"$one\" != \"$two\" ] || exit 41; printf '仓颉🙂' > \"$one\" && printf 'emoji🙂' > \"$two\" && /bin/cat \"$one\" \"$two\" >/dev/null || exit 42; rm -f \"$one\" \"$two\"; [ ! -e \"$one\" ] && [ ! -e \"$two\" ] || exit 43; ! /usr/bin/touch ${ckbAbcdeShellQuote(externalTemp)} >/dev/null 2>&1 || exit 44; ! /usr/bin/touch ${ckbAbcdeShellQuote(tempSibling)} >/dev/null 2>&1 || exit 45; [ \"$(command -v ar)\" = ${ckbAbcdeShellQuote("${homePath}/bin/ar")} ] || exit 46; cd ${ckbAbcdeShellQuote(project)} && cjpm build -i >/dev/null 2>&1 || exit 47; printf probe > ${ckbAbcdeShellQuote(marker)} && rm -f ${ckbAbcdeShellQuote(marker)} || exit 48; ! /usr/bin/touch ${ckbAbcdeShellQuote(outside)} >/dev/null 2>&1 || exit 49; ! /bin/ls ${ckbAbcdeShellQuote("${casePath}/tests")} >/dev/null 2>&1 || exit 50; ! /bin/ls ${ckbAbcdeShellQuote("${casePath}/translation")} >/dev/null 2>&1 || exit 51; ! /bin/ls ${ckbAbcdeShellQuote("/Users/l3gi0n/work/workspace_cangjie/CangjieTeacher")} >/dev/null 2>&1 || exit 52"
    let raw=ckbAbcdeRunShell("HOME=${ckbAbcdeShellQuote(homePath)} PATH=${ckbAbcdeShellQuote("${homePath}/bin")}:\"$PATH\" TMPDIR=${ckbAbcdeShellQuote("${homePath}/tmp")} CLAUDE_CODE_TMPDIR=${ckbAbcdeShellQuote("${homePath}/tmp")} CLAUDE_TMPDIR=${ckbAbcdeShellQuote("${homePath}/tmp")} XDG_CONFIG_HOME=${ckbAbcdeShellQuote("${homePath}/xdg-config")} XDG_CACHE_HOME=${ckbAbcdeShellQuote("${homePath}/xdg-cache")} CLAUDE_CONFIG_DIR=${ckbAbcdeShellQuote("${homePath}/claude-config")} CANGJIE_HOME=${ckbAbcdeShellQuote(cangjieHome)} SDKROOT=${ckbAbcdeShellQuote(sdkRoot)} sandbox-exec -f ${ckbAbcdeShellQuote(sandboxProfile)} /bin/zsh -lc ${ckbAbcdeShellQuote(script)} < ${ckbAbcdeShellQuote(stdinProbe)}",workspacePath)
    let storePointer=Path(ckbStore).join("metadata/active-snapshot.manifest").toString();let storeProbe=if(exists(Path(storePointer))){ckbAbcdeRunShell("sandbox-exec -f ${ckbAbcdeShellQuote(sandboxProfile)} /bin/cat ${ckbAbcdeShellQuote(storePointer)} >/dev/null 2>&1",workspacePath)}else{CkbAbcdeCommandResult()};let deniedStore=exists(Path(storePointer))&&storeProbe.exitCode!=0;if(raw.exitCode==0&&!deniedStore){raw.exitCode=53}
    try{_=launch("/bin/rm",["-f",stdinProbe,externalTemp]).wait()}catch(_:Exception){}
    let result=CkbAbcdeCommandResult();result.exitCode=raw.exitCode;result.stderr=raw.stderr;result.stdout="{\"ok\":${raw.exitCode==0},\"stdinReadable\":${raw.exitCode==0},\"runtimeTempMarkersPassed\":${raw.exitCode==0},\"runtimeTempMarkersCleaned\":${raw.exitCode==0},\"archiverReady\":${raw.exitCode==0},\"minimalBuildPassed\":${raw.exitCode==0},\"deniedExternalTemp\":${raw.exitCode==0},\"deniedTempSibling\":${raw.exitCode==0},\"deniedOutsideWorkspace\":${raw.exitCode==0},\"deniedTests\":${raw.exitCode==0},\"deniedReference\":${raw.exitCode==0},\"deniedTeacher\":${raw.exitCode==0},\"deniedStore\":${deniedStore},\"workspaceCanonical\":\"${ckbAbcdeJsonEscape(try{canonicalize(Path(workspace)).toString()}catch(_:Exception){""})}\",\"runtimeHomeCanonical\":\"${ckbAbcdeJsonEscape(try{canonicalize(Path(runtimeHome)).toString()}catch(_:Exception){""})}\"}\n";result
}
public func ckbAbcdeCertificationSandboxProbeForTest(profilePath:String,workspace:String,runtimeHome:String,caseSrc:String,ckbStore!:String=""):CkbAbcdeCommandResult{ckbAbcdeCertificationSandboxProbe(profilePath,workspace,runtimeHome,caseSrc,ckbStore)}

public func ckbAbcdeDevelopmentSandboxProfile(group:String,workspace:String,runtimeHome:String,ckbBin:String,ckbConfig:String,ckbStore:String,caseSrc:String,docsRoot:String,cangjieHome:String,sdkRoot:String,claudeRequested:String,claudeCanonical:String):String{
    let w=ckbAbcdeSandboxPath(workspace);let h=ckbAbcdeSandboxPath(runtimeHome);let bin=ckbAbcdeSandboxPath(ckbBin);let config=ckbAbcdeSandboxPath(ckbConfig);let store=ckbAbcdeSandboxPath(ckbStore);let sdk=ckbAbcdeSandboxPath(cangjieHome);let macSdk=ckbAbcdeSandboxPath(sdkRoot);let tests=ckbAbcdeSandboxPath("${caseSrc}/tests");let reference=ckbAbcdeSandboxPath("${caseSrc}/translation");let teacher=ckbAbcdeSandboxPath("/Users/l3gi0n/work/workspace_cangjie/CangjieTeacher")
    let docs=if(group==CkbAbcdeGroups.E){" (subpath \"${ckbAbcdeSandboxPath(docsRoot)}\")"}else{""}
    let requested=ckbAbcdeSandboxLiteral(claudeRequested);let canonical=ckbAbcdeSandboxLiteral(claudeCanonical);let magic=ckbAbcdeCurrentMagicStdxPath();let magicRead=if(magic==""){""}else{" (subpath \"${ckbAbcdeSandboxLiteral(magic)}\")"}
    let docsMetadata=if(group==CkbAbcdeGroups.E){ckbAbcdeSandboxMetadataPaths(docsRoot)}else{""};let magicMetadata=if(magic==""){""}else{ckbAbcdeSandboxMetadataPaths(magic)};let opensslRead=ckbAbcdeOpenSslCanonicalReadRules();let opensslMetadata=ckbAbcdeOpenSslCanonicalMetadataRules();let metadata=ckbAbcdeSandboxMetadataPaths(workspace)+ckbAbcdeSandboxMetadataPaths(runtimeHome)+ckbAbcdeSandboxMetadataPaths(ckbBin)+ckbAbcdeSandboxMetadataPaths(ckbConfig)+ckbAbcdeSandboxMetadataPaths(ckbStore)+ckbAbcdeSandboxMetadataPaths(cangjieHome)+ckbAbcdeSandboxMetadataPaths(sdkRoot)+ckbAbcdeSandboxMetadataPaths(claudeRequested)+ckbAbcdeSandboxMetadataPaths(claudeCanonical)+docsMetadata+magicMetadata+opensslMetadata
    "(version 1)\n(import \"system.sb\")\n(deny default)\n(allow process*)\n(allow process-info* (target self))\n(allow sysctl-read)\n(allow mach-lookup)\n(allow network*)\n(allow file-read-metadata${metadata} (literal \"/dev\") (literal \"/dev/fd\") (literal \"/dev/fd/0\") (literal \"/dev/stdin\") (literal \"/usr\") (literal \"/usr/bin\") (literal \"/usr/bin/ar\"))\n(allow file-read* (literal \"/dev/fd/0\") (literal \"/dev/stdin\") (literal \"/usr\") (literal \"/usr/bin\") (literal \"/usr/bin/ar\") (literal \"${requested}\") (literal \"${canonical}\") (subpath \"${w}\") (subpath \"${h}\") (literal \"${bin}\") (literal \"${config}\") (subpath \"${store}\") (subpath \"${sdk}\") (subpath \"${macSdk}\")${magicRead}${opensslRead}${docs})\n(allow file-write* (subpath \"${w}\") (subpath \"${h}\"))\n(deny file-read* (literal \"${tests}\") (subpath \"${tests}\") (literal \"${reference}\") (subpath \"${reference}\") (literal \"${teacher}\") (subpath \"${teacher}\"))\n"
}

private func ckbAbcdeSandboxMetadataAncestors(path:String):String{var current=try{canonicalize(Path(path)).parent}catch(_:Exception){Path(path).parent};var out="";while(current.toString()!="/"&&current.toString()!="."&&current.toString()!=""){out=" (literal \"${ckbAbcdeSandboxLiteral(current.toString())}\")"+out;current=current.parent};out}
private func ckbAbcdeSandboxMetadataPaths(path:String):String{" (literal \"${ckbAbcdeSandboxPath(path)}\")"+ckbAbcdeSandboxMetadataAncestors(path)}

private func ckbAbcdeOpenSslCanonicalFile(requested:String,expectedName:String):String{
    if(expectedName!="libcrypto.3.dylib"&&expectedName!="libssl.3.dylib"){return ""}
    if(requested==""||requested!=requested.trimAscii()||!requested.startsWith("/")||!requested.endsWith("/${expectedName}")){return ""}
    let trusted=requested=="/opt/homebrew/opt/openssl@3/lib/${expectedName}"||requested=="/opt/homebrew/opt/openssl@3.5/lib/${expectedName}"||requested=="/usr/local/opt/openssl@3/lib/${expectedName}"
    if(!trusted||!exists(Path(requested))){return ""}
    let canonical=try{canonicalize(Path(requested)).toString()}catch(_:Exception){return ""}
    let canonicalTrusted=canonical.startsWith("/opt/homebrew/Cellar/openssl@3/")||canonical.startsWith("/usr/local/Cellar/openssl@3/")
    if(!canonicalTrusted||!canonical.endsWith("/${expectedName}")){return ""}
    try{if(launch("/bin/test",["-f",canonical]).wait()!=0||launch("/bin/test",["-L",canonical]).wait()==0){return ""}}catch(_:Exception){return ""}
    canonical
}

private func ckbAbcdeCurrentOpenSslCanonicalFiles():ArrayList<String>{
    let out=ArrayList<String>()
    for(root in ["/opt/homebrew/opt/openssl@3/lib","/opt/homebrew/opt/openssl@3.5/lib","/usr/local/opt/openssl@3/lib"]){
        let crypto=ckbAbcdeOpenSslCanonicalFile("${root}/libcrypto.3.dylib","libcrypto.3.dylib");let ssl=ckbAbcdeOpenSslCanonicalFile("${root}/libssl.3.dylib","libssl.3.dylib")
        if(ckbAbcdeOpenSslPairReady(crypto,ssl)){out.add(crypto);out.add(ssl);return out}
    }
    out
}

private func ckbAbcdeCurrentOpenSslAliasRoot():String{
    for(root in ["/opt/homebrew/opt/openssl@3","/opt/homebrew/opt/openssl@3.5","/usr/local/opt/openssl@3"]){
        let crypto=ckbAbcdeOpenSslCanonicalFile("${root}/lib/libcrypto.3.dylib","libcrypto.3.dylib");let ssl=ckbAbcdeOpenSslCanonicalFile("${root}/lib/libssl.3.dylib","libssl.3.dylib")
        if(ckbAbcdeOpenSslPairReady(crypto,ssl)){return root}
    }
    ""
}
public func ckbAbcdeCurrentOpenSslAliasRootForTest():String{ckbAbcdeCurrentOpenSslAliasRoot()}

private func ckbAbcdeOpenSslCanonicalPairReady():Bool{ckbAbcdeCurrentOpenSslCanonicalFiles().size==2}
public func ckbAbcdeOpenSslCanonicalPairReadyForTest():Bool{ckbAbcdeOpenSslCanonicalPairReady()}
private func ckbAbcdeSandboxDependencyDiagnostic(opensslPairReady:Bool,magicReady:Bool):String{if(!opensslPairReady){"sandbox_openssl_canonical_pair_missing"}else if(!magicReady){"sandbox_magic_stdx_missing"}else{"ok"}}
public func ckbAbcdeSandboxDependencyDiagnosticForTest(opensslPairReady:Bool,magicReady:Bool):String{ckbAbcdeSandboxDependencyDiagnostic(opensslPairReady,magicReady)}
private func ckbAbcdePrepareClaudeRuntimeHome(runtimeHome:String):String{if(runtimeHome==""||!runtimeHome.startsWith("/")){return "sandbox_runtime_home_invalid"};for(path in [runtimeHome,"${runtimeHome}/tmp","${runtimeHome}/xdg-config","${runtimeHome}/xdg-cache","${runtimeHome}/claude-config"]){ckbAbcdeEnsureDir(path);if(!exists(Path(path))){return "sandbox_runtime_home_prepare_failed"}};"ok"}
public func ckbAbcdePrepareClaudeRuntimeHomeForTest(runtimeHome:String):String{ckbAbcdePrepareClaudeRuntimeHome(runtimeHome)}

private func ckbAbcdeBundledArchiver(cangjieHome:String):String{
    if(cangjieHome==""||cangjieHome!=cangjieHome.trimAscii()||!cangjieHome.startsWith("/")||!exists(Path(cangjieHome))){return ""}
    try{if(launch("/bin/test",["-L",cangjieHome]).wait()==0||launch("/bin/test",["-d",cangjieHome]).wait()!=0){return ""}}catch(_:Exception){return ""}
    let canonicalHome=try{canonicalize(Path(cangjieHome)).toString()}catch(_:Exception){return ""};if(canonicalHome!=cangjieHome){return ""}
    let expected=Path(canonicalHome).join("third_party/llvm/bin/llvm-ar").toString();if(!exists(Path(expected))){return ""}
    try{if(launch("/bin/test",["-L",expected]).wait()==0||launch("/bin/test",["-f",expected]).wait()!=0||launch("/bin/test",["-x",expected]).wait()!=0){return ""}}catch(_:Exception){return ""}
    let canonical=try{canonicalize(Path(expected)).toString()}catch(_:Exception){return ""};if(canonical!=expected||!canonical.startsWith("${canonicalHome}/third_party/llvm/bin/")){return ""};canonical
}
private func ckbAbcdeCurrentBundledArchiver():String{let home=match(getVariable("CANGJIE_HOME")){case Some(value)=>value case None=>""};ckbAbcdeBundledArchiver(home)}
public func ckbAbcdeBundledArchiverForTest(cangjieHome:String):String{ckbAbcdeBundledArchiver(cangjieHome)}

private func ckbAbcdePrepareBundledArchiver(runtimeHome:String,cangjieHome:String):String{
    if(runtimeHome==""||runtimeHome!=runtimeHome.trimAscii()||!runtimeHome.startsWith("/")||!exists(Path(runtimeHome))){return "sandbox_bundled_archiver_runtime_home_invalid"}
    let canonicalHome=try{canonicalize(Path(runtimeHome)).toString()}catch(_:Exception){return "sandbox_bundled_archiver_runtime_home_invalid"};if(canonicalHome!=runtimeHome){return "sandbox_bundled_archiver_runtime_home_invalid"}
    let archiver=ckbAbcdeBundledArchiver(cangjieHome);if(archiver==""){return "sandbox_bundled_archiver_missing"}
    let bin=Path(canonicalHome).join("bin");if(exists(bin)){try{if(launch("/bin/test",["-L",bin.toString()]).wait()==0){return "sandbox_bundled_archiver_bin_symlink_forbidden"};if(launch("/bin/test",["-d",bin.toString()]).wait()!=0){return "sandbox_bundled_archiver_bin_invalid"}}catch(_:Exception){return "sandbox_bundled_archiver_bin_invalid"}}else{ckbAbcdeEnsureDir(bin.toString())}
    let canonicalBin=try{canonicalize(bin).toString()}catch(_:Exception){return "sandbox_bundled_archiver_bin_invalid"};if(canonicalBin!=bin.toString()||!canonicalBin.startsWith("${canonicalHome}/")){return "sandbox_bundled_archiver_bin_invalid"}
    let shim=bin.join("ar");if(exists(shim)){try{if(launch("/bin/test",["-L",shim.toString()]).wait()==0){return "sandbox_bundled_archiver_shim_symlink_forbidden"}}catch(_:Exception){return "sandbox_bundled_archiver_shim_invalid"}}
    let staged=bin.join(".ar-${ckbCoreNowMillis()}.tmp");ckbAbcdeWriteText(staged.toString(),"#!/bin/zsh\nexec ${ckbAbcdeShellQuote(archiver)} \"$@\"\n")
    if(launch("/bin/chmod",["700",staged.toString()]).wait()!=0||launch("/bin/mv",["-f",staged.toString(),shim.toString()]).wait()!=0){_=launch("/bin/rm",["-f",staged.toString()]).wait();return "sandbox_bundled_archiver_shim_prepare_failed"}
    try{if(launch("/bin/test",["-L",shim.toString()]).wait()==0||launch("/bin/test",["-f",shim.toString()]).wait()!=0||launch("/bin/test",["-x",shim.toString()]).wait()!=0){return "sandbox_bundled_archiver_shim_invalid"}}catch(_:Exception){return "sandbox_bundled_archiver_shim_invalid"};"ok"
}
public func ckbAbcdePrepareBundledArchiverForTest(runtimeHome:String,cangjieHome:String):String{ckbAbcdePrepareBundledArchiver(runtimeHome,cangjieHome)}

private func ckbAbcdeOpenSslCanonicalReadRules():String{var out="";for(path in ckbAbcdeCurrentOpenSslCanonicalFiles()){out+=" (literal \"${ckbAbcdeSandboxLiteral(path)}\")"};out}
private func ckbAbcdeOpenSslCanonicalMetadataRules():String{
    var out="";for(path in ckbAbcdeCurrentOpenSslCanonicalFiles()){out+=ckbAbcdeSandboxMetadataPaths(path)}
    let root=ckbAbcdeCurrentOpenSslAliasRoot()
    if(root.startsWith("/opt/homebrew/opt/")){out+=" (literal \"/opt\") (literal \"/opt/homebrew\") (literal \"/opt/homebrew/opt\") (literal \"${ckbAbcdeSandboxLiteral(root)}\")"}
    else if(root=="/usr/local/opt/openssl@3"){out+=" (literal \"/usr\") (literal \"/usr/local\") (literal \"/usr/local/opt\") (literal \"/usr/local/opt/openssl@3\")"};out
}
public func ckbAbcdeOpenSslCanonicalFileForTest(requested:String,expectedName:String):String{ckbAbcdeOpenSslCanonicalFile(requested,expectedName)}
private func ckbAbcdeOpenSslPairReady(crypto:String,ssl:String):Bool{crypto!=""&&ssl!=""&&crypto!=ssl}
public func ckbAbcdeOpenSslPairReadyForTest(crypto:String,ssl:String):Bool{ckbAbcdeOpenSslPairReady(crypto,ssl)}

private func ckbAbcdeMagicStdxPath(magicRoot:String):String{
    if(magicRoot==""||magicRoot!=magicRoot.trimAscii()||!magicRoot.startsWith("/")||!exists(Path(magicRoot))){return ""}
    try{if(launch("/bin/test",["-L",magicRoot]).wait()==0){return ""}}catch(_:Exception){return ""}
    let canonicalRoot=try{canonicalize(Path(magicRoot)).toString()}catch(_:Exception){return ""}
    if(canonicalRoot!=magicRoot){return ""}
    let expected=Path(canonicalRoot).join("libs/cangjie-stdx-mac-aarch64-1.0.0.1/darwin_aarch64_llvm/dynamic/stdx").toString()
    if(!exists(Path(expected))){return ""}
    try{if(launch("/bin/test",["-L",expected]).wait()==0||launch("/bin/test",["-d",expected]).wait()!=0){return ""}}catch(_:Exception){return ""}
    let canonicalStdx=try{canonicalize(Path(expected)).toString()}catch(_:Exception){return ""}
    if(canonicalStdx!=expected||!canonicalStdx.startsWith("${canonicalRoot}/libs/")){return ""}
    canonicalStdx
}

private func ckbAbcdeCurrentMagicStdxPath():String{
    let primary=match(getVariable("MAGIC_PATH")){case Some(value)=>value case None=>""}
    let fallback=match(getVariable("CKB_MAGIC_ROOT")){case Some(value)=>value case None=>""}
    ckbAbcdeMagicStdxPath(if(primary==""){fallback}else{primary})
}

public func ckbAbcdeMagicStdxPathForTest(magicRoot:String):String{ckbAbcdeMagicStdxPath(magicRoot)}
public func ckbAbcdeCurrentMagicStdxPathForTest():String{ckbAbcdeCurrentMagicStdxPath()}

private func ckbAbcdeDevelopmentSandboxProbe(profilePath:String,workspace:String,runtimeHome:String,caseSrc:String,docsRoot:String,group:String,cangjieHome:String,sdkRoot:String):CkbAbcdeCommandResult{
    let workspacePath=try{canonicalize(Path(workspace)).toString()}catch(_:Exception){workspace};let homePath=try{canonicalize(Path(runtimeHome)).toString()}catch(_:Exception){runtimeHome};let casePath=try{canonicalize(Path(caseSrc)).toString()}catch(_:Exception){caseSrc};let docsPath=try{canonicalize(Path(docsRoot)).toString()}catch(_:Exception){docsRoot};let sdkPath=try{canonicalize(Path(cangjieHome)).toString()}catch(_:Exception){cangjieHome};let macSdkPath=try{canonicalize(Path(sdkRoot)).toString()}catch(_:Exception){sdkRoot};let sandboxProfile=try{canonicalize(Path(profilePath)).toString()}catch(_:Exception){profilePath}
    let marker="${workspacePath}/.development-sandbox-write-probe";let outside=Path(workspacePath).parent.join(".development-sandbox-outside-probe").toString();let tempSibling=Path(homePath).parent.join("attempt-sibling").toString();let externalTemp="/tmp/claude-external-${ckbCoreNowMillis()}-cwd";let privateName=".ckb-private-仓颉🙂-probe";let privatePath=Path(workspacePath).parent.join(privateName).toString();let project="${homePath}/sandbox-build-probe"
    let stdinProbe="${homePath}/sandbox-stdin-probe.txt";ckbAbcdeWriteText(stdinProbe,"sandbox-stdin-仓颉🙂\n");ckbAbcdeWriteText(privatePath,"private-probe-value");ckbAbcdeEnsureDir("${homePath}/tmp");ckbAbcdeEnsureDir("${project}/src");ckbAbcdeWriteText("${project}/cjpm.toml","[package]\n  cjc-version = \"1.0.0\"\n  name = \"ckb_sandbox_probe\"\n  version = \"0.1.0\"\n  output-type = \"static\"\n  src-dir = \"\"\n");ckbAbcdeWriteText("${project}/src/solution.cj","package ckb_sandbox_probe\n\npublic func sandboxProbe(): String { \"仓颉🙂\" }\n")
    let docsCheck=if(group==CkbAbcdeGroups.E){"/bin/ls ${ckbAbcdeShellQuote(docsPath)} >/dev/null 2>&1 || exit 50; "}else{""}
    let script="IFS= read -r stdin_marker; [ \"$stdin_marker\" = 'sandbox-stdin-仓颉🙂' ] || exit 37; [ \"$HOME\" = ${ckbAbcdeShellQuote(homePath)} ] || exit 38; [ \"$CLAUDE_CODE_TMPDIR\" = ${ckbAbcdeShellQuote("${homePath}/tmp")} ] || exit 39; [ \"$CLAUDE_TMPDIR\" = ${ckbAbcdeShellQuote("${homePath}/tmp")} ] || exit 40; one=\"$CLAUDE_CODE_TMPDIR/claude-0001-cwd\"; two=\"$CLAUDE_CODE_TMPDIR/claude-0002-cwd\"; [ \"$one\" != \"$two\" ] || exit 41; printf '仓颉🙂' > \"$one\" && printf 'emoji🙂' > \"$two\" && /bin/cat \"$one\" \"$two\" >/dev/null || exit 42; rm -f \"$one\" \"$two\"; [ ! -e \"$one\" ] && [ ! -e \"$two\" ] || exit 43; ! /usr/bin/touch ${ckbAbcdeShellQuote(externalTemp)} >/dev/null 2>&1 || exit 44; ! /usr/bin/touch ${ckbAbcdeShellQuote(tempSibling)} >/dev/null 2>&1 || exit 45; [ \"$CANGJIE_HOME\" = ${ckbAbcdeShellQuote(sdkPath)} ] || exit 46; [ \"$SDKROOT\" = ${ckbAbcdeShellQuote(macSdkPath)} ] || exit 47; [ \"$(command -v ar)\" = ${ckbAbcdeShellQuote("${homePath}/bin/ar")} ] || exit 48; cjpm --version >/dev/null 2>&1 || exit 49; cd ${ckbAbcdeShellQuote(project)} && cjpm build -i >/dev/null 2>&1 || exit 50; printf probe > ${ckbAbcdeShellQuote(marker)} && rm -f ${ckbAbcdeShellQuote(marker)} || exit 51; ! /usr/bin/touch ${ckbAbcdeShellQuote(outside)} >/dev/null 2>&1 || exit 52; ! /bin/cat ${ckbAbcdeShellQuote(privatePath)} >/dev/null 2>&1 || exit 53; broad=$(/usr/bin/find / -name ${ckbAbcdeShellQuote(privateName)} 2>/dev/null | /usr/bin/head -n 1); [ -z \"$broad\" ] || exit 54; ! /bin/ls ${ckbAbcdeShellQuote("${casePath}/tests")} >/dev/null 2>&1 || exit 55; ! /bin/ls ${ckbAbcdeShellQuote("${casePath}/translation")} >/dev/null 2>&1 || exit 56; ! /bin/ls ${ckbAbcdeShellQuote("/Users/l3gi0n/work/workspace_cangjie/CangjieTeacher")} >/dev/null 2>&1 || exit 57; ${docsCheck}/usr/bin/true"
    let raw=ckbAbcdeRunShell("HOME=${ckbAbcdeShellQuote(homePath)} PATH=${ckbAbcdeShellQuote("${homePath}/bin")}:\"$PATH\" TMPDIR=${ckbAbcdeShellQuote("${homePath}/tmp")} CLAUDE_CODE_TMPDIR=${ckbAbcdeShellQuote("${homePath}/tmp")} CLAUDE_TMPDIR=${ckbAbcdeShellQuote("${homePath}/tmp")} XDG_CONFIG_HOME=${ckbAbcdeShellQuote("${homePath}/xdg-config")} XDG_CACHE_HOME=${ckbAbcdeShellQuote("${homePath}/xdg-cache")} CLAUDE_CONFIG_DIR=${ckbAbcdeShellQuote("${homePath}/claude-config")} CANGJIE_HOME=${ckbAbcdeShellQuote(sdkPath)} SDKROOT=${ckbAbcdeShellQuote(macSdkPath)} sandbox-exec -f ${ckbAbcdeShellQuote(sandboxProfile)} /bin/zsh -lc ${ckbAbcdeShellQuote(script)} < ${ckbAbcdeShellQuote(stdinProbe)}",workspacePath)
    try{_=launch("/bin/rm",["-f",privatePath,stdinProbe,externalTemp]).wait()}catch(_:Exception){}
    let ok=raw.exitCode==0;let result=CkbAbcdeCommandResult();result.exitCode=raw.exitCode;result.stderr=if(ok){""}else{"development_sandbox_probe_failed"};result.stdout="{\"ok\":${ok},\"stdinReadable\":${ok},\"runtimeTempMarkersPassed\":${ok},\"runtimeTempMarkersCleaned\":${ok},\"deniedExternalTemp\":${ok},\"deniedTempSibling\":${ok},\"archiverReady\":${ok},\"cjpmAvailable\":${ok},\"minimalBuildPassed\":${ok},\"deniedOutsideWorkspace\":${ok},\"deniedPrivateSibling\":${ok},\"deniedBroadFilesystemScan\":${ok},\"deniedTests\":${ok},\"deniedReference\":${ok},\"deniedTeacher\":${ok},\"docsReadableWhenAllowed\":${ok},\"workspaceCanonical\":\"${ckbAbcdeJsonEscape(workspacePath)}\",\"runtimeHomeCanonical\":\"${ckbAbcdeJsonEscape(homePath)}\",\"cangjieHomeCanonical\":\"${ckbAbcdeJsonEscape(sdkPath)}\"}\n";result
}
public func ckbAbcdeDevelopmentSandboxProbeForTest(profilePath:String,workspace:String,runtimeHome:String,caseSrc:String,docsRoot:String,group:String,cangjieHome:String,sdkRoot:String):CkbAbcdeCommandResult{ckbAbcdeDevelopmentSandboxProbe(profilePath,workspace,runtimeHome,caseSrc,docsRoot,group,cangjieHome,sdkRoot)}

public func ckbAbcdeSandboxTranscriptPath(runtimeHome:String):String{"${runtimeHome}/claude-transcript.jsonl"}
public func ckbAbcdeSandboxStderrPath(runtimeHome:String):String{"${runtimeHome}/claude.stderr.log"}
public func ckbAbcdeSandboxPromptPath(runtimeHome:String):String{"${runtimeHome}/prompt.final.md"}

public func ckbAbcdePrepareSandboxPrompt(groupRoot:String,runtimeHome:String):String{
    let source=Path(groupRoot).join("prompt.final.md");let target=Path(ckbAbcdeSandboxPromptPath(runtimeHome))
    if(launch("/bin/test",["-L",source.toString()]).wait()==0){return "sandbox_prompt_source_symlink_forbidden"}
    if(!exists(source)){return "sandbox_prompt_missing"}
    let canonicalRoot=try{canonicalize(Path(groupRoot)).toString()}catch(_:Exception){return "sandbox_prompt_root_invalid"}
    let canonicalSource=try{canonicalize(source).toString()}catch(_:Exception){return "sandbox_prompt_source_invalid"}
    if(canonicalSource!=Path(canonicalRoot).join("prompt.final.md").toString()){return "sandbox_prompt_source_symlink_forbidden"}
    let bytes=try{File.readFrom(source)}catch(_:Exception){return "sandbox_prompt_read_failed"}
    if(bytes.size==0){return "sandbox_prompt_empty"}
    if(bytes.size>1048576){return "sandbox_prompt_too_large"}
    let text=try{String.fromUtf8(bytes)}catch(_:Exception){return "sandbox_prompt_invalid_encoding"}
    let canonicalHome=try{canonicalize(Path(runtimeHome)).toString()}catch(_:Exception){return "sandbox_prompt_runtime_home_invalid"}
    if(launch("/bin/test",["-L",target.toString()]).wait()==0){return "sandbox_prompt_destination_symlink_forbidden"}
    let expectedTarget=Path(canonicalHome).join("prompt.final.md").toString()
    if(exists(target)){let canonicalTarget=try{canonicalize(target).toString()}catch(_:Exception){return "sandbox_prompt_destination_invalid"};if(canonicalTarget!=expectedTarget){return "sandbox_prompt_destination_symlink_forbidden"}}
    let hash=benchmarkGapSha256(text);let tmp=Path(canonicalHome).join(".prompt.final.md.tmp-${hash.replace("sha256:","")}")
    try{_=launch("/bin/rm",["-f",tmp.toString()]).wait();File.writeTo(tmp,bytes)}catch(_:Exception){return "sandbox_prompt_stage_write_failed"}
    let staged=try{String.fromUtf8(File.readFrom(tmp))}catch(_:Exception){_=launch("/bin/rm",["-f",tmp.toString()]).wait();return "sandbox_prompt_stage_invalid_encoding"}
    if(benchmarkGapSha256(staged)!=hash){_=launch("/bin/rm",["-f",tmp.toString()]).wait();return "sandbox_prompt_stage_hash_mismatch"}
    if(launch("/bin/mv",["-f",tmp.toString(),expectedTarget]).wait()!=0){_=launch("/bin/rm",["-f",tmp.toString()]).wait();return "sandbox_prompt_atomic_replace_failed"}
    let committed=try{String.fromUtf8(File.readFrom(Path(expectedTarget)))}catch(_:Exception){return "sandbox_prompt_commit_invalid_encoding"}
    if(benchmarkGapSha256(committed)!=hash){return "sandbox_prompt_commit_hash_mismatch"}
    "ok"
}

private func ckbAbcdeRunClaudeOnceInCertificationSandbox(group:String,groupRoot:String,workspace:String,runtimeHome:String,profilePath:String,claudeExecutable:String,expectedModel:String,modelTimeoutSeconds:Int64,attempt:Int64):CkbAbcdeCommandResult{
    let transcript=ckbAbcdeSandboxTranscriptPath(runtimeHome);let stderr=ckbAbcdeSandboxStderrPath(runtimeHome)
    let evidenceTranscript="${groupRoot}/claude-transcript.attempt-${attempt}.jsonl";let evidenceStderr="${groupRoot}/claude.attempt-${attempt}.stderr.log"
    ckbAbcdeWriteText("${runtimeHome}/mcp-config.json","{\"mcpServers\":{}}")
    let promptDiagnostic=ckbAbcdePrepareSandboxPrompt(groupRoot,runtimeHome);if(promptDiagnostic!="ok"){let blocked=CkbAbcdeCommandResult();blocked.exitCode=126;blocked.stderr=promptDiagnostic;return blocked}
    let command=ckbAbcdeCertificationClaudeCommand(groupRoot,runtimeHome,profilePath,claudeExecutable,expectedModel,transcript,stderr,attempt:attempt)
    let script=ckbAbcdeClaudeTimeoutShell(command,stderr,modelTimeoutSeconds)+"; cp ${ckbAbcdeShellQuote(transcript)} ${ckbAbcdeShellQuote(evidenceTranscript)} 2>/dev/null || true; cp ${ckbAbcdeShellQuote(stderr)} ${ckbAbcdeShellQuote(evidenceStderr)} 2>/dev/null || true; exit $code";let result=ckbAbcdeRunShell(script,workspace);try{_=launch("/bin/rm",["-f",ckbAbcdeSandboxPromptPath(runtimeHome)]).wait()}catch(_:Exception){};result
}
public func ckbAbcdeCertificationClaudeCommand(groupRoot:String,runtimeHome:String,profilePath:String,claudeExecutable:String,expectedModel:String,transcript:String,stderr:String,attempt!:Int64=1):String{"session_id=$(uuidgen | tr '[:upper:]' '[:lower:]'); printf '%s' \"$session_id\" > ${ckbAbcdeShellQuote("${groupRoot}/session-id.attempt-${attempt}.txt")}; HOME=${ckbAbcdeShellQuote(runtimeHome)} PATH=${ckbAbcdeShellQuote("${runtimeHome}/bin")}:\"$PATH\" TMPDIR=${ckbAbcdeShellQuote("${runtimeHome}/tmp")} CLAUDE_CODE_TMPDIR=${ckbAbcdeShellQuote("${runtimeHome}/tmp")} CLAUDE_TMPDIR=${ckbAbcdeShellQuote("${runtimeHome}/tmp")} XDG_CONFIG_HOME=${ckbAbcdeShellQuote("${runtimeHome}/xdg-config")} XDG_CACHE_HOME=${ckbAbcdeShellQuote("${runtimeHome}/xdg-cache")} CLAUDE_CONFIG_DIR=${ckbAbcdeShellQuote("${runtimeHome}/claude-config")} ANTHROPIC_MAX_RETRIES=0 CLAUDE_CODE_MAX_RETRIES=0 sandbox-exec -f ${ckbAbcdeShellQuote(profilePath)} ${ckbAbcdeShellQuote(claudeExecutable)} -p --bare --tools '' --disable-slash-commands --setting-sources '' --max-turns 1 --verbose --no-session-persistence --session-id \"$session_id\" --model ${ckbAbcdeShellQuote(expectedModel)} --output-format json --strict-mcp-config --mcp-config ${ckbAbcdeShellQuote("${runtimeHome}/mcp-config.json")} --json-schema ${ckbAbcdeShellQuote(ckbAbcdeCompletionOutputSchema())} ${ckbAbcdeClaudePermissionFlag()} < ${ckbAbcdeShellQuote(ckbAbcdeSandboxPromptPath(runtimeHome))} > ${ckbAbcdeShellQuote(transcript)} 2> ${ckbAbcdeShellQuote(stderr)}"}

private func ckbAbcdeRunClaudeOnce(group: String, groupRoot: String, workspace: String, runtimeHome: String, docsRoot: String, caseSrc: String, ckbBin: String, ckbConfig: String, ckbStore: String, claudeBin: String, attempt: Int64, expectedModel: String, modelTimeoutSeconds: Int64, modelEffort: String, modelMaxBudgetUsd: String): CkbAbcdeCommandResult {
    var addDir = "--add-dir ${ckbAbcdeShellQuote(workspace)}"
    if (group == CkbAbcdeGroups.E) {
        addDir += " --add-dir ${ckbAbcdeShellQuote(docsRoot)}"
    }
    let toolLimit = ckbAbcdeClaudeToolLimitForGroup(group)
    let budgetFlag = if (modelMaxBudgetUsd == "") { "" } else { " --max-budget-usd ${ckbAbcdeShellQuote(modelMaxBudgetUsd)}" }
    let attemptRuntimeHome=ckbAbcdeDevelopmentAttemptRuntimeHome(runtimeHome,attempt)
    let transcript=ckbAbcdeSandboxTranscriptPath(attemptRuntimeHome);let stderr=ckbAbcdeSandboxStderrPath(attemptRuntimeHome)
    let evidenceTranscript="${groupRoot}/claude-transcript.attempt-${attempt}.jsonl";let evidenceStderr="${groupRoot}/claude.attempt-${attempt}.stderr.log"
    let runtimeDiagnostic=ckbAbcdePrepareClaudeRuntimeHome(attemptRuntimeHome);if(runtimeDiagnostic!="ok"){let blocked=CkbAbcdeCommandResult();blocked.exitCode=126;blocked.stderr=runtimeDiagnostic;return blocked}
    ckbAbcdeWriteText("${attemptRuntimeHome}/mcp-config.json",ckbAbcdeReadText("${groupRoot}/mcp-config.json"))
    let cangjieHome=match(getVariable("CANGJIE_HOME")){case Some(value)=>value case None=>""}
    if(cangjieHome==""||!exists(Path(cangjieHome))){let blocked=CkbAbcdeCommandResult();blocked.exitCode=126;blocked.stderr="development_sandbox_cangjie_home_missing";return blocked}
    let archiverDiagnostic=ckbAbcdePrepareBundledArchiver(attemptRuntimeHome,cangjieHome);if(archiverDiagnostic!="ok"){let blocked=CkbAbcdeCommandResult();blocked.exitCode=126;blocked.stderr=archiverDiagnostic;return blocked}
    let sdkRoot=match(getVariable("SDKROOT")){case Some(value)=>value case None=>""}
    if(sdkRoot==""||!exists(Path(sdkRoot))){let blocked=CkbAbcdeCommandResult();blocked.exitCode=126;blocked.stderr="development_sandbox_sdk_root_missing";return blocked}
    let claude=ckbAbcdeResolveClaudeExecutable(claudeBin)
    if(!claude.valid){let blocked=CkbAbcdeCommandResult();blocked.exitCode=126;blocked.stderr=claude.diagnostic;return blocked}
    let dependencyDiagnostic=ckbAbcdeSandboxDependencyDiagnostic(ckbAbcdeOpenSslCanonicalPairReady(),ckbAbcdeCurrentMagicStdxPath()!="")
    if(dependencyDiagnostic!="ok"){let blocked=CkbAbcdeCommandResult();blocked.exitCode=126;blocked.stderr=dependencyDiagnostic;return blocked}
    let profilePath="${groupRoot}/development.attempt-${attempt}.sb"
    ckbAbcdeWriteText(profilePath,ckbAbcdeDevelopmentSandboxProfile(group,workspace,attemptRuntimeHome,ckbBin,ckbConfig,ckbStore,caseSrc,docsRoot,cangjieHome,sdkRoot,claude.requested,claude.canonical))
    let probe=ckbAbcdeDevelopmentSandboxProbe(profilePath,workspace,attemptRuntimeHome,caseSrc,docsRoot,group,cangjieHome,sdkRoot)
    ckbAbcdeWriteText("${groupRoot}/sandbox-probe.attempt-${attempt}.json",probe.stdout);ckbAbcdeWriteText("${groupRoot}/sandbox-probe.json",probe.stdout)
    if(probe.exitCode!=0){let blocked=CkbAbcdeCommandResult();blocked.exitCode=126;blocked.stderr="development_sandbox_probe_failed";return blocked}
    ckbAbcdeWriteText("${groupRoot}/model-transport-profile.json", "{\"effort\":\"${ckbAbcdeJsonEscape(modelEffort)}\",\"maxBudgetUsd\":\"${ckbAbcdeJsonEscape(modelMaxBudgetUsd)}\",\"timeoutSeconds\":${modelTimeoutSeconds},\"attempt\":${attempt}}\n")
    let promptDiagnostic=ckbAbcdePrepareSandboxPrompt(groupRoot,attemptRuntimeHome);if(promptDiagnostic!="ok"){let blocked=CkbAbcdeCommandResult();blocked.exitCode=126;blocked.stderr=promptDiagnostic;return blocked}
    let command = ckbAbcdeDevelopmentClaudeCommand(groupRoot,attemptRuntimeHome,profilePath,claude.canonical,expectedModel,modelEffort,budgetFlag,toolLimit,addDir,transcript,stderr,attempt)
    let script = ckbAbcdeClaudeTimeoutShell(command, stderr, modelTimeoutSeconds) + "; cp ${ckbAbcdeShellQuote(transcript)} ${ckbAbcdeShellQuote(evidenceTranscript)} 2>/dev/null || true; cp ${ckbAbcdeShellQuote(stderr)} ${ckbAbcdeShellQuote(evidenceStderr)} 2>/dev/null || true; cp ${ckbAbcdeShellQuote(transcript)} ${ckbAbcdeShellQuote("${groupRoot}/claude-transcript.jsonl")} 2>/dev/null || true; cp ${ckbAbcdeShellQuote(transcript)} ${ckbAbcdeShellQuote("${groupRoot}/claude.stdout.log")} 2>/dev/null || true; cp ${ckbAbcdeShellQuote(stderr)} ${ckbAbcdeShellQuote("${groupRoot}/claude.stderr.log")} 2>/dev/null || true; exit $code"
    let result=ckbAbcdeRunShell(script, workspace);try{_=launch("/bin/rm",["-f",ckbAbcdeSandboxPromptPath(attemptRuntimeHome)]).wait()}catch(_:Exception){};result
}

public func ckbAbcdeDevelopmentAttemptRuntimeHome(runtimeHome:String,attempt:Int64):String{"${runtimeHome}/attempt-${attempt}"}

public func ckbAbcdeDevelopmentClaudeCommand(groupRoot:String,runtimeHome:String,profilePath:String,claudeExecutable:String,expectedModel:String,modelEffort:String,budgetFlag:String,toolLimit:String,addDir:String,transcript:String,stderr:String,attempt:Int64):String{
    let attemptSession="${groupRoot}/session-id.attempt-${attempt}.txt";let currentSession="${groupRoot}/session-id.txt"
    "session_id=$(uuidgen | tr '[:upper:]' '[:lower:]'); printf '%s' \"$session_id\" > ${ckbAbcdeShellQuote(attemptSession)}; cp ${ckbAbcdeShellQuote(attemptSession)} ${ckbAbcdeShellQuote(currentSession)}; HOME=${ckbAbcdeShellQuote(runtimeHome)} PATH=${ckbAbcdeShellQuote("${runtimeHome}/bin")}:\"$PATH\" TMPDIR=${ckbAbcdeShellQuote("${runtimeHome}/tmp")} CLAUDE_CODE_TMPDIR=${ckbAbcdeShellQuote("${runtimeHome}/tmp")} CLAUDE_TMPDIR=${ckbAbcdeShellQuote("${runtimeHome}/tmp")} XDG_CONFIG_HOME=${ckbAbcdeShellQuote("${runtimeHome}/xdg-config")} XDG_CACHE_HOME=${ckbAbcdeShellQuote("${runtimeHome}/xdg-cache")} CLAUDE_CONFIG_DIR=${ckbAbcdeShellQuote("${runtimeHome}/claude-config")} sandbox-exec -f ${ckbAbcdeShellQuote(profilePath)} ${ckbAbcdeShellQuote(claudeExecutable)} -p --verbose --no-session-persistence --session-id \"$session_id\" --model ${ckbAbcdeShellQuote(expectedModel)} --effort ${ckbAbcdeShellQuote(modelEffort)}${budgetFlag} --output-format stream-json --strict-mcp-config --mcp-config ${ckbAbcdeShellQuote("${runtimeHome}/mcp-config.json")} ${ckbAbcdeClaudePermissionFlag()} ${toolLimit} ${addDir} < ${ckbAbcdeShellQuote(ckbAbcdeSandboxPromptPath(runtimeHome))} > ${ckbAbcdeShellQuote(transcript)} 2> ${ckbAbcdeShellQuote(stderr)}"
}

private func ckbAbcdePublishClaudeAttemptArtifacts(groupRoot: String, attemptCount: Int64): Unit {
    let transcript = ckbAbcdeMergedClaudeAttemptText(groupRoot, "claude-transcript.attempt-", ".jsonl", attemptCount)
    let stderr = ckbAbcdeMergedClaudeAttemptText(groupRoot, "claude.attempt-", ".stderr.log", attemptCount)
    ckbAbcdeWriteText("${groupRoot}/claude-transcript.jsonl", transcript)
    ckbAbcdeWriteText("${groupRoot}/claude.stdout.log", transcript)
    ckbAbcdeWriteText("${groupRoot}/claude.stderr.log", stderr)
}

private func ckbAbcdePublishLastAuditedCertificationArtifacts(groupRoot:String,attempt:Int64):Unit{
    let transcript=ckbAbcdeReadText("${groupRoot}/claude-transcript.attempt-${attempt}.jsonl")
    ckbAbcdeWriteText("${groupRoot}/claude-transcript.jsonl",transcript);ckbAbcdeWriteText("${groupRoot}/claude.stdout.log",transcript)
    ckbAbcdeWriteText("${groupRoot}/claude.stderr.log",ckbAbcdeReadText("${groupRoot}/claude.attempt-${attempt}.stderr.log"))
    ckbAbcdeWriteText("${groupRoot}/sandbox-probe.json",ckbAbcdeReadText("${groupRoot}/sandbox-probe.attempt-${attempt}.json"));ckbAbcdeWriteText("${groupRoot}/session-id.txt",ckbAbcdeReadText("${groupRoot}/session-id.attempt-${attempt}.txt"))
}
public func ckbAbcdePublishLastAuditedCertificationArtifactsForTest(groupRoot:String,attempt:Int64):Unit{ckbAbcdePublishLastAuditedCertificationArtifacts(groupRoot,attempt)}

private func ckbAbcdeMergedClaudeAttemptText(groupRoot: String, prefix: String, suffix: String, attemptCount: Int64): String {
    let out = StringBuilder()
    for (attempt in 1..=attemptCount) {
        ckbAbcdeAppendAttemptText(out, ckbAbcdeReadText("${groupRoot}/${prefix}${attempt}${suffix}"))
    }
    out.toString()
}

private func ckbAbcdeAppendAttemptText(out: StringBuilder, text: String): Unit {
    if (text == "") {
        return
    }
    out.append(text)
    if (!text.endsWith("\n")) {
        out.append("\n")
    }
}

public func ckbAbcdeJoinClaudeAttemptTextForTest(first: String, second: String): String {
    let out = StringBuilder()
    ckbAbcdeAppendAttemptText(out, first)
    ckbAbcdeAppendAttemptText(out, second)
    out.toString()
}

private func ckbAbcdeClaudeTimeoutShell(command: String, stderrPath: String, timeoutSeconds: Int64): String {
    let quotedStderr = ckbAbcdeShellQuote(stderrPath)
    let safeTimeout = if (timeoutSeconds < 1) { 1 } else { timeoutSeconds }
    let perl = ckbAbcdeShellQuote("defined POSIX::setsid() or exit 125; exec @ARGV")
    let isolatedCommand = ckbAbcdeShellQuote(command)
    "/usr/bin/perl -MPOSIX -e ${perl} /bin/zsh -lc ${isolatedCommand} & child=$!; elapsed=0; timed_out=0; while /bin/kill -0 \"$child\" 2>/dev/null; do if [ \"$elapsed\" -ge ${safeTimeout} ]; then echo claude_timeout_after_${safeTimeout}s >> ${quotedStderr}; /bin/kill -TERM -- \"-$child\" 2>/dev/null || true; grace=0; while /bin/kill -0 -- \"-$child\" 2>/dev/null && [ \"$grace\" -lt 2 ]; do sleep 1; grace=$((grace + 1)); done; /bin/kill -KILL -- \"-$child\" 2>/dev/null || true; timed_out=1; break; fi; sleep 1; elapsed=$((elapsed + 1)); done; if [ \"$timed_out\" -eq 1 ]; then wait \"$child\" 2>/dev/null || true; code=124; else wait \"$child\"; code=$?; fi"
}

public func ckbAbcdeClaudeTimeoutShellForTest(command: String, stderrPath: String, timeoutSeconds: Int64): String {
    ckbAbcdeClaudeTimeoutShell(command, stderrPath, timeoutSeconds)
}

public func ckbAbcdeClaudeTimeoutShellForOptionsForTest(command: String, stderrPath: String, options: CkbAbcdeRunnerOptions): String {
    ckbAbcdeClaudeTimeoutShell(command, stderrPath, options.modelTimeoutSeconds)
}

public func ckbAbcdeRunClaudeTimeoutShellForTest(command:String,stderrPath:String,timeoutSeconds:Int64,workspace:String):CkbAbcdeCommandResult {
    ckbAbcdeRunShell(ckbAbcdeClaudeTimeoutShell(command,stderrPath,timeoutSeconds)+"; exit $code",workspace)
}

private func ckbAbcdeClaudePermissionFlag(): String {
    "--dangerously-skip-permissions"
}

public func ckbAbcdeClaudePermissionFlagForTest(): String {
    ckbAbcdeClaudePermissionFlag()
}

public func ckbAbcdeClaudeToolLimitForGroup(group: String): String {
    ""
}

private func ckbAbcdeCurlRetryFlags(): String {
    "--retry 3 --retry-delay 2 --retry-connrefused"
}

public func ckbAbcdeCurlRetryFlagsForTest(): String {
    ckbAbcdeCurlRetryFlags()
}

private func ckbAbcdeRunMcpStdioSmoke(options: CkbAbcdeRunnerOptions, groupRoot: String, taskContextJson!: String = ckbAbcdeSmokeTaskContextJson()): Unit {
    let requests = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"ckb-abcde-runner\",\"version\":\"1.0\"}}}\n" +
        "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\",\"params\":{}}\n" +
        "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\",\"params\":{}}\n" +
        "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"cangjie_task_knowledge_pack\",\"arguments\":{}}}\n"
    ckbAbcdeWriteText("${groupRoot}/mcp-stdio-smoke-requests.jsonl", requests)
    let script = "cat ${ckbAbcdeShellQuote("${groupRoot}/mcp-stdio-smoke-requests.jsonl")} | ( " +
        ckbAbcdeNativeTlsBootstrapScript(options.ckbBin, ckbAbcdeMcpStdioArguments(options, taskContextJson: taskContextJson)) +
        " ) > ${ckbAbcdeShellQuote("${groupRoot}/mcp-stdio-smoke.stdout.jsonl")} 2> ${ckbAbcdeShellQuote("${groupRoot}/mcp-stdio-smoke.stderr.log")}"
    let result = ckbAbcdeRunShell(script, "")
    let stdout = ckbAbcdeReadText("${groupRoot}/mcp-stdio-smoke.stdout.jsonl")
    let ok = result.exitCode == 0 && stdout.contains("cangjie_task_knowledge_pack") && stdout.contains("\"versionResolution\"")
    let observation = ckbAbcdeParityObservationFromResponse("CJ-HUMANEVAL-smoke", "mcp_stdio", stdout)
    ckbAbcdeWriteText("${groupRoot}/mcp-stdio-tools-list.json", "{\"exitCode\":${result.exitCode},\"knowledgePackCallOk\":${ok},\"taskKnowledgePackCallOk\":${ok},\"toolNamesContainsTaskKnowledgePack\":${stdout.contains("cangjie_task_knowledge_pack")},\"versionResolutionReturned\":${stdout.contains("\"versionResolution\"")}}\n")
    ckbAbcdeWriteText("${groupRoot}/parity.jsonl", ckbAbcdeRenderParityObservationJson(observation) + "\n")
}

private func ckbAbcdeRunMcpHttpSmoke(options: CkbAbcdeRunnerOptions, groupRoot: String, taskContextJson!: String = ckbAbcdeSmokeTaskContextJson()): Unit {
    let initBody = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"ckb-abcde-runner\",\"version\":\"1.0\"}}}"
    let initializedBody = "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\",\"params\":{}}"
    let callBody = "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"cangjie_task_knowledge_pack\",\"arguments\":{}}}"
    let boundHeader = "X-CKB-Runner-Context: ${toBase64String(taskContextJson.toArray())}"
    let boundHashHeader = "X-CKB-Runner-Context-SHA256: ${benchmarkGapSha256(taskContextJson)}"
    ckbAbcdeWriteText("${groupRoot}/mcp-http-initialize-request.json", initBody)
    ckbAbcdeWriteText("${groupRoot}/mcp-http-initialized-request.json", initializedBody)
    ckbAbcdeWriteText("${groupRoot}/mcp-http-tool-call-request.json", callBody)
    let script = "curl --max-time 5 -i -sS -X POST -H 'Accept: application/json, text/event-stream' -H 'Content-Type: application/json' -H ${ckbAbcdeShellQuote(boundHeader)} -H ${ckbAbcdeShellQuote(boundHashHeader)} --data-binary @${ckbAbcdeShellQuote("${groupRoot}/mcp-http-initialize-request.json")} ${ckbAbcdeShellQuote("${options.ckbHttpBase}/mcp")} > ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-initialize-response.txt")} 2> ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-initialize.stderr.log")}; " +
        "sid=$(grep -i '^mcp-session-id:' ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-initialize-response.txt")} | head -n1 | cut -d' ' -f2 | tr -d '\\r'); " +
        "printf '%s\\n' \"$sid\" > ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-session-id.txt")}; " +
        "if [ -z \"$sid\" ]; then exit 4; fi; " +
        "curl --max-time 5 -fsS -X POST -H 'Accept: application/json, text/event-stream' -H 'Content-Type: application/json' -H ${ckbAbcdeShellQuote(boundHeader)} -H ${ckbAbcdeShellQuote(boundHashHeader)} -H \"Mcp-Session-Id: $sid\" -H 'MCP-Protocol-Version: 2025-06-18' --data-binary @${ckbAbcdeShellQuote("${groupRoot}/mcp-http-initialized-request.json")} ${ckbAbcdeShellQuote("${options.ckbHttpBase}/mcp")} > ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-initialized-response.txt")} 2> ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-initialized.stderr.log")}; " +
        "curl --max-time ${ckbAbcdeDevelopmentToolProbeTimeoutSeconds()} -fsS -X POST -H 'Accept: application/json, text/event-stream' -H 'Content-Type: application/json' -H ${ckbAbcdeShellQuote(boundHeader)} -H ${ckbAbcdeShellQuote(boundHashHeader)} -H \"Mcp-Session-Id: $sid\" -H 'MCP-Protocol-Version: 2025-06-18' --data-binary @${ckbAbcdeShellQuote("${groupRoot}/mcp-http-tool-call-request.json")} ${ckbAbcdeShellQuote("${options.ckbHttpBase}/mcp")} > ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-tool-call-response.json")} 2> ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-tool-call.stderr.log")}; " +
        "curl --max-time 5 -fsS -N -H 'Accept: text/event-stream' -H ${ckbAbcdeShellQuote(boundHeader)} -H ${ckbAbcdeShellQuote(boundHashHeader)} -H \"Mcp-Session-Id: $sid\" -H 'MCP-Protocol-Version: 2025-06-18' ${ckbAbcdeShellQuote("${options.ckbHttpBase}/mcp")}"
    let get = ckbAbcdeRunShell(script, "")
    ckbAbcdeWriteText("${groupRoot}/mcp-http-smoke.stdout.log", get.stdout)
    ckbAbcdeWriteText("${groupRoot}/mcp-http-smoke.stderr.log", get.stderr)
    let ready = get.stdout.contains("event") || get.stdout.contains("ready")
    let callResponse = ckbAbcdeReadText("${groupRoot}/mcp-http-tool-call-response.json")
    let toolOk = callResponse.contains("\"versionResolution\"") && callResponse.contains("\"queryPlan\"")
    let observation = ckbAbcdeParityObservationFromResponse("CJ-HUMANEVAL-smoke", "mcp_http", callResponse)
    ckbAbcdeWriteText("${groupRoot}/mcp-http-smoke.json", "{\"exitCode\":${get.exitCode},\"ok\":${toolOk},\"taskKnowledgePackCallOk\":${toolOk},\"sseReady\":${ready},\"versionResolutionReturned\":${callResponse.contains("\"versionResolution\"")}}\n")
    ckbAbcdeWriteText("${groupRoot}/parity.jsonl", ckbAbcdeRenderParityObservationJson(observation) + "\n")
}

public func ckbAbcdeProbeInProcessTransportParity(service: CkbCommandLoopService, caseId: String, taskContextJson: String): CkbAbcdeParityReport {
    let report = CkbAbcdeParityReport()
    report.caseId = caseId
    report.rest = ckbAbcdeParityObservationFromResponse(caseId, "rest", ckbApiHandle(service, "POST", "/v1/cangjie/task-knowledge-pack", taskContextJson, []))
    let jsonRpc = ckbAbcdeMcpTaskKnowledgePackRequest(taskContextJson)
    report.stdio = ckbAbcdeParityObservationFromResponse(caseId, "mcp_stdio", CkbMcpStdioServer(service).handleRequest(jsonRpc))
    report.http = ckbAbcdeParityObservationFromResponse(caseId, "mcp_http", ckbAbcdeRunInProcessMcpHttpToolCall(service, jsonRpc))
    report.diagnostic = ckbAbcdeParityDiagnostic(report.rest, report.stdio, report.http)
    report.ok = report.diagnostic == "ok"
    report
}

public func ckbAbcdeProbeInProcessTransportParityArtifacts(service: CkbCommandLoopService, runRoot: String, caseId: String, taskContextJson: String): CkbAbcdeParityReport {
    ckbAbcdeEnsureDir(runRoot)
    let jsonRpc = ckbAbcdeMcpTaskKnowledgePackRequest(taskContextJson)
    let restPath = "${runRoot}/transport-parity-rest.json"
    let stdioPath = "${runRoot}/transport-parity-stdio.json"
    let httpPath = "${runRoot}/transport-parity-http.json"
    let restResponse = ckbApiHandle(service, "POST", "/v1/cangjie/task-knowledge-pack", taskContextJson, [])
    let stdioResponse = CkbMcpStdioServer(service).handleRequest(jsonRpc)
    let httpResponse = ckbAbcdeRunInProcessMcpHttpToolCall(service, jsonRpc)
    ckbAbcdeWriteText(restPath, restResponse)
    ckbAbcdeWriteText(stdioPath, stdioResponse)
    ckbAbcdeWriteText(httpPath, httpResponse)
    ckbAbcdeBuildParityReportFromPayloads(caseId, runRoot, restPath, restResponse, 0, "", stdioPath, stdioResponse, 0, "", httpPath, httpResponse, 0, "")
}

public func ckbAbcdeProbeRealTransportParity(options: CkbAbcdeRunnerOptions, runRoot: String, caseId: String, taskContextJson: String): CkbAbcdeParityReport {
    ckbAbcdeEnsureDir(runRoot)
    ckbAbcdeWriteText("${runRoot}/transport-parity-task-context.json", taskContextJson + "\n")

    let restRequestPath = "${runRoot}/transport-parity-rest-request.json"
    let restPath = "${runRoot}/transport-parity-rest.json"
    ckbAbcdeWriteText(restRequestPath, taskContextJson)
    let rest = ckbAbcdeRunShell("curl ${ckbAbcdeCurlRetryFlags()} --max-time ${ckbAbcdeDevelopmentToolProbeTimeoutSeconds()} -fsS -X POST -H 'Content-Type: application/json' --data-binary @${ckbAbcdeShellQuote(restRequestPath)} ${ckbAbcdeShellQuote("${options.ckbHttpBase}/v1/cangjie/task-knowledge-pack")}", "")
    ckbAbcdeWriteText(restPath, rest.stdout)
    ckbAbcdeWriteText("${runRoot}/transport-parity-rest.stderr.log", rest.stderr)

    let stdioRequestPath = "${runRoot}/transport-parity-stdio-requests.jsonl"
    let stdioFullPath = "${runRoot}/transport-parity-stdio-full.jsonl"
    let stdioPath = "${runRoot}/transport-parity-stdio.json"
    let stdioRequests = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"ckb-transport-parity\",\"version\":\"1.0\"}}}\n" +
        "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\",\"params\":{}}\n" +
        ckbAbcdeMcpTaskKnowledgePackRequest("{}") + "\n"
    ckbAbcdeWriteText(stdioRequestPath, stdioRequests)
    let stdioScript = "cat ${ckbAbcdeShellQuote(stdioRequestPath)} | ( " +
        ckbAbcdeNativeTlsBootstrapScript(options.ckbBin, ckbAbcdeMcpStdioArguments(options, taskContextJson: taskContextJson)) +
        " ) > ${ckbAbcdeShellQuote(stdioFullPath)} 2> ${ckbAbcdeShellQuote("${runRoot}/transport-parity-stdio.stderr.log")}"
    let stdio = ckbAbcdeRunShell(stdioScript, "")
    let stdioFull = ckbAbcdeReadText(stdioFullPath)
    let stdioPayload = ckbAbcdeExtractMcpToolResponse(stdioFull)
    ckbAbcdeWriteText(stdioPath, stdioPayload)

    let initBody = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"ckb-transport-parity\",\"version\":\"1.0\"}}}"
    let initializedBody = "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\",\"params\":{}}"
    let callBody = ckbAbcdeMcpTaskKnowledgePackRequest("{}")
    let boundHeader = "X-CKB-Runner-Context: ${toBase64String(taskContextJson.toArray())}"
    let boundHashHeader = "X-CKB-Runner-Context-SHA256: ${benchmarkGapSha256(taskContextJson)}"
    let httpInitPath = "${runRoot}/transport-parity-http-initialize-request.json"
    let httpInitializedPath = "${runRoot}/transport-parity-http-initialized-request.json"
    let httpRequestPath = "${runRoot}/transport-parity-http-request.json"
    let httpPath = "${runRoot}/transport-parity-http.json"
    ckbAbcdeWriteText(httpInitPath, initBody)
    ckbAbcdeWriteText(httpInitializedPath, initializedBody)
    ckbAbcdeWriteText(httpRequestPath, callBody)
    let httpScript = "curl --max-time 5 -i -sS -X POST -H 'Accept: application/json, text/event-stream' -H 'Content-Type: application/json' -H ${ckbAbcdeShellQuote(boundHeader)} -H ${ckbAbcdeShellQuote(boundHashHeader)} --data-binary @${ckbAbcdeShellQuote(httpInitPath)} ${ckbAbcdeShellQuote("${options.ckbHttpBase}/mcp")} > ${ckbAbcdeShellQuote("${runRoot}/transport-parity-http-initialize-response.txt")} 2> ${ckbAbcdeShellQuote("${runRoot}/transport-parity-http-initialize.stderr.log")}; " +
        "sid=$(grep -i '^mcp-session-id:' ${ckbAbcdeShellQuote("${runRoot}/transport-parity-http-initialize-response.txt")} | head -n1 | cut -d' ' -f2 | tr -d '\\r'); " +
        "printf '%s\\n' \"$sid\" > ${ckbAbcdeShellQuote("${runRoot}/transport-parity-http-session-id.txt")}; " +
        "if [ -z \"$sid\" ]; then exit 4; fi; " +
        "curl --max-time 5 -fsS -X POST -H 'Accept: application/json, text/event-stream' -H 'Content-Type: application/json' -H ${ckbAbcdeShellQuote(boundHeader)} -H ${ckbAbcdeShellQuote(boundHashHeader)} -H \"Mcp-Session-Id: $sid\" -H 'MCP-Protocol-Version: 2025-06-18' --data-binary @${ckbAbcdeShellQuote(httpInitializedPath)} ${ckbAbcdeShellQuote("${options.ckbHttpBase}/mcp")} > ${ckbAbcdeShellQuote("${runRoot}/transport-parity-http-initialized-response.txt")} 2> ${ckbAbcdeShellQuote("${runRoot}/transport-parity-http-initialized.stderr.log")}; " +
        "curl --max-time ${ckbAbcdeDevelopmentToolProbeTimeoutSeconds()} -fsS -X POST -H 'Accept: application/json, text/event-stream' -H 'Content-Type: application/json' -H ${ckbAbcdeShellQuote(boundHeader)} -H ${ckbAbcdeShellQuote(boundHashHeader)} -H \"Mcp-Session-Id: $sid\" -H 'MCP-Protocol-Version: 2025-06-18' --data-binary @${ckbAbcdeShellQuote(httpRequestPath)} ${ckbAbcdeShellQuote("${options.ckbHttpBase}/mcp")} > ${ckbAbcdeShellQuote(httpPath)} 2> ${ckbAbcdeShellQuote("${runRoot}/transport-parity-http.stderr.log")}"
    let http = ckbAbcdeRunShell(httpScript, "")
    let httpPayload = ckbAbcdeReadText(httpPath)

    ckbAbcdeBuildParityReportFromPayloads(caseId, runRoot, restPath, rest.stdout, rest.exitCode, rest.stderr, stdioPath, stdioPayload, stdio.exitCode, ckbAbcdeReadText("${runRoot}/transport-parity-stdio.stderr.log"), httpPath, httpPayload, http.exitCode, ckbAbcdeReadText("${runRoot}/transport-parity-http.stderr.log"))
}

private func ckbAbcdeBuildParityReportFromPayloads(
    caseId: String,
    runRoot: String,
    restPath: String,
    restResponse: String,
    restExitCode: Int64,
    restStderr: String,
    stdioPath: String,
    stdioResponse: String,
    stdioExitCode: Int64,
    stdioStderr: String,
    httpPath: String,
    httpResponse: String,
    httpExitCode: Int64,
    httpStderr: String
): CkbAbcdeParityReport {
    let report = CkbAbcdeParityReport()
    report.caseId = caseId
    report.rest = ckbAbcdeParityObservationFromArtifact(caseId, "rest", restPath, restResponse, restExitCode, restStderr)
    report.stdio = ckbAbcdeParityObservationFromArtifact(caseId, "mcp_stdio", stdioPath, stdioResponse, stdioExitCode, stdioStderr)
    report.http = ckbAbcdeParityObservationFromArtifact(caseId, "mcp_http", httpPath, httpResponse, httpExitCode, httpStderr)
    report.diagnostic = ckbAbcdeParityDiagnostic(report.rest, report.stdio, report.http)
    report.ok = report.diagnostic == "ok"
    ckbAbcdeWriteText("${runRoot}/transport-parity.jsonl", ckbAbcdeRenderParityJsonl(report) + "\n")
    report
}

private func ckbAbcdeMcpTaskKnowledgePackRequest(taskContextJson: String): String {
    "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"cangjie_task_knowledge_pack\",\"arguments\":${taskContextJson}}}"
}

private func ckbAbcdeRunInProcessMcpHttpToolCall(service: CkbCommandLoopService, jsonRpc: String): String {
    let sessionStore = CkbMcpHttpSessionStore()
    let httpConfig = CkbHttpServiceConfig()
    let mcpConfig = CkbMcpHttpServiceConfig()
    let initBody = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"ckb-abcde-runner\",\"version\":\"1.0\"}}}"
    let initHeaders = ["Content-Type: application/json", "Accept: application/json, text/event-stream"]
    let initResponse = handleCkbMcpHttpRequest(service, "POST", "/mcp", initBody, initHeaders, httpConfig, mcpConfig, sessionStore)
    let sessionId = ckbAbcdeMcpHttpSessionId(initResponse.headers)
    if (sessionId == "") {
        return initResponse.body
    }
    let sessionHeaders = ["Content-Type: application/json", "Accept: application/json, text/event-stream", "MCP-Protocol-Version: 2025-06-18", "Mcp-Session-Id: ${sessionId}"]
    _ = handleCkbMcpHttpRequest(service, "POST", "/mcp", "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\",\"params\":{}}", sessionHeaders, httpConfig, mcpConfig, sessionStore)
    handleCkbMcpHttpRequest(service, "POST", "/mcp", jsonRpc, sessionHeaders, httpConfig, mcpConfig, sessionStore).body
}

private func ckbAbcdeMcpHttpSessionId(headers: ArrayList<String>): String {
    for (header in headers) {
        let lower = header.toAsciiLower()
        if (lower.startsWith("mcp-session-id:")) {
            let parts = header.split(":")
            if (parts.size > 1) { return parts[1].trimAscii() }
        }
    }
    ""
}

public func ckbAbcdeParityObservationFromResponse(caseId: String, transport: String, response: String): CkbAbcdeParityObservation {
    let payload = ckbAbcdeParityStructuredPayload(response, transport)
    let observation = CkbAbcdeParityObservation()
    observation.caseId = caseId
    observation.transport = transport
    observation.evidenceHash = ckbAbcdeJsonStringField(payload, "evidenceHash")
    observation.coveragePass = payload.contains("\"coveragePass\":true")
    observation.citationCount = ckbAbcdeCountOccurrences(payload, "\"citation\"")
    observation.ok = payload != "" && observation.evidenceHash != ""
    observation.diagnostic = if (payload == "") { "missing_structured_payload" } else if (observation.evidenceHash == "") { "missing_evidence_hash" } else { "ok" }
    observation
}

private func ckbAbcdeParityObservationFromArtifact(caseId: String, transport: String, payloadPath: String, response: String, exitCode: Int64, stderr: String): CkbAbcdeParityObservation {
    let observation = ckbAbcdeParityObservationFromResponse(caseId, transport, response)
    observation.payloadPath = payloadPath
    if (exitCode != 0) {
        observation.ok = false
        observation.diagnostic = "${observation.diagnostic};transport_exit_${exitCode}:${utf8SafePrefix(stderr.replace("\n", " "), 160)}"
    } else if (!observation.ok && stderr.trimAscii() != "") {
        observation.diagnostic = "${observation.diagnostic};${utf8SafePrefix(stderr.replace("\n", " "), 160)}"
    }
    observation
}

public func ckbAbcdeParityObservationFromArtifactForTest(caseId: String, transport: String, payloadPath: String, response: String, exitCode: Int64, stderr: String): CkbAbcdeParityObservation {
    ckbAbcdeParityObservationFromArtifact(caseId, transport, payloadPath, response, exitCode, stderr)
}

private func ckbAbcdeExtractMcpToolResponse(stdout: String): String {
    for (line in stdout.split("\n")) {
        if (line.contains("\"structuredContent\"") && line.contains("\"cangjie_task_knowledge_pack\"")) {
            return line
        }
    }
    for (line in stdout.split("\n")) {
        if (line.contains("\"structuredContent\"")) {
            return line
        }
    }
    ""
}

public func ckbAbcdeParityStructuredPayload(response: String, transport: String): String {
    if (transport == "rest") {
        return ckbMcpJsonObjectField(response, "data")
    }
    let result = ckbMcpJsonObjectField(response, "result")
    ckbMcpJsonObjectField(result, "structuredContent")
}

private func ckbAbcdeParityDiagnostic(rest: CkbAbcdeParityObservation, stdio: CkbAbcdeParityObservation, http: CkbAbcdeParityObservation): String {
    if (!rest.ok) { return "rest_${rest.diagnostic}" }
    if (!stdio.ok) { return "mcp_stdio_${stdio.diagnostic}" }
    if (!http.ok) { return "mcp_http_${http.diagnostic}" }
    if (rest.evidenceHash != stdio.evidenceHash || rest.evidenceHash != http.evidenceHash) { return "evidence_hash_mismatch" }
    if (rest.coveragePass != stdio.coveragePass || rest.coveragePass != http.coveragePass) { return "coverage_mismatch" }
    if (rest.citationCount != stdio.citationCount || rest.citationCount != http.citationCount) { return "citation_count_mismatch" }
    "ok"
}

public func ckbAbcdeParityDiagnosticForTest(rest: CkbAbcdeParityObservation, stdio: CkbAbcdeParityObservation, http: CkbAbcdeParityObservation): String {
    ckbAbcdeParityDiagnostic(rest, stdio, http)
}

public func ckbAbcdeRenderParityJsonl(report: CkbAbcdeParityReport): String {
    ckbAbcdeRenderParityObservationJson(report.rest) + "\n" +
        ckbAbcdeRenderParityObservationJson(report.stdio) + "\n" +
        ckbAbcdeRenderParityObservationJson(report.http)
}

public func ckbAbcdeRenderParityObservationJson(observation: CkbAbcdeParityObservation): String {
    "{\"caseId\":\"${ckbAbcdeJsonEscape(observation.caseId)}\",\"interfaceId\":\"${ckbAbcdeJsonEscape(observation.interfaceId)}\",\"transport\":\"${ckbAbcdeJsonEscape(observation.transport)}\",\"ok\":${observation.ok},\"evidenceHash\":\"${ckbAbcdeJsonEscape(observation.evidenceHash)}\",\"coveragePass\":${observation.coveragePass},\"citationCount\":${observation.citationCount},\"diagnostic\":\"${ckbAbcdeJsonEscape(observation.diagnostic)}\",\"payloadPath\":\"${ckbAbcdeJsonEscape(observation.payloadPath)}\"}"
}

private func ckbAbcdePreflight(options: CkbAbcdeRunnerOptions, runRoot: String): CkbAbcdePreflightResult {
    let result = CkbAbcdePreflightResult()
    result.add("runs_root", exists(Path(options.runsRoot)), options.runsRoot)
    result.add("run_root_created", exists(Path(runRoot)), runRoot)
    result.add("ckb_bin", exists(Path(options.ckbBin)), options.ckbBin)
    result.add("ckb_store", exists(Path(options.ckbStore)), options.ckbStore)
    result.add("dataset_root", exists(Path(options.datasetRoot)), options.datasetRoot)
    result.add("manifest", exists(Path(options.manifestPath)) && ckbAbcdeManifestLineCount(options.manifestPath) == 164, "lines=${ckbAbcdeManifestLineCount(options.manifestPath)}")
    result.add("humaneval_cases", ckbAbcdeCaseLayoutOk(options.datasetRoot), "CJ-HUMANEVAL-000..163 required files")
    result.add("docs_root", exists(Path(options.docsRoot)) && exists(Path("${options.docsRoot}/dev-guide/summary_cjnative_EN.md")) && exists(Path("${options.docsRoot}/tools/summary_cjnative_EN.md")), options.docsRoot)
    let claudeExecutable = ckbAbcdeResolveClaudeExecutable(options.claudeBin)
    result.add("claude_cli", claudeExecutable.valid && ckbAbcdeRunShell("${ckbAbcdeShellQuote(claudeExecutable.canonical)} --version >/dev/null", "").exitCode == 0, claudeExecutable.diagnostic)
    result.add("claude_glm52_settings", ckbAbcdeClaudeSettingsLooksGlm52(), "~/.claude/settings.json model keys")
    result.add("cjpm_cli", ckbAbcdeRunShell("command -v cjpm >/dev/null && cjpm --version >/dev/null", "").exitCode == 0, "cjpm command available")
    result.add("ckb_http_health", ckbAbcdeRunShell(ckbAbcdePreflightHttpHealthCommand(options.ckbHttpBase), "").exitCode == 0, options.ckbHttpBase)
    result.add("ckb_http_schema", ckbAbcdeRunShell("curl --max-time 5 -fsS ${ckbAbcdeShellQuote("${options.ckbHttpBase}/v1/schema")} | grep -q cangjie_task_knowledge_pack", "").exitCode == 0, "${options.ckbHttpBase}/v1/schema")
    let stdioRoot = "${runRoot}/preflight-stdio"
    ckbAbcdeEnsureDir(stdioRoot)
    ckbAbcdeRunMcpStdioSmoke(options, stdioRoot)
    let stdioJson = ckbAbcdeReadText("${stdioRoot}/mcp-stdio-tools-list.json")
    result.add("mcp_stdio", stdioJson.contains("\"knowledgePackCallOk\":true"), "${stdioRoot}/mcp-stdio-tools-list.json")
    let httpRoot = "${runRoot}/preflight-http"
    ckbAbcdeEnsureDir(httpRoot)
    ckbAbcdeRunMcpHttpSmoke(options, httpRoot)
    let httpJson = ckbAbcdeReadText("${httpRoot}/mcp-http-smoke.json")
    result.add("mcp_http", httpJson.contains("\"ok\":true"), "${httpRoot}/mcp-http-smoke.json")
    let parity = ckbAbcdeProbeRealTransportParity(options, runRoot, "preflight", ckbAbcdeSmokeTaskContextJson())
    ckbAbcdeWriteText("${runRoot}/preflight-parity.jsonl", ckbAbcdeRenderParityJsonl(parity) + "\n")
    result.add("transport_parity", parity.ok, "${runRoot}/preflight-parity.jsonl diagnostic=${parity.diagnostic}")
    result
}

public func ckbAbcdePreflightHttpHealthCommand(baseUrl: String): String {
    "curl --max-time 60 -fsS ${ckbAbcdeShellQuote("${baseUrl}/v1/health")} >/dev/null"
}

private func ckbAbcdeRenderPreflightJson(options: CkbAbcdeRunnerOptions, runRoot: String, result: CkbAbcdePreflightResult): String {
    var checks = ""
    for (i in 0..result.checks.size) {
        if (i > 0) {
            checks += ","
        }
        checks += result.checks[i]
    }
    "{\"ok\":${result.ok},\"runRoot\":\"${ckbAbcdeJsonEscape(runRoot)}\",\"runsRoot\":\"${ckbAbcdeJsonEscape(options.runsRoot)}\",\"expectedModelVersion\":\"${ckbAbcdeJsonEscape(options.expectedModelVersion)}\",\"caseStart\":${options.caseStart},\"caseEnd\":${options.caseEnd},\"checks\":[${checks}]}\n"
}

private func ckbAbcdeRenderPreflightMarkdown(options: CkbAbcdeRunnerOptions, runRoot: String, result: CkbAbcdePreflightResult): String {
    var out = "# CKB ABCDE Benchmark Preflight\n\n"
    out += "- ok: ${result.ok}\n"
    out += "- runRoot: `${runRoot}`\n"
    out += "- runsRoot: `${options.runsRoot}`\n"
    out += "- expectedModelVersion: `${options.expectedModelVersion}`\n"
    out += "- cases: `${options.caseStart}..${options.caseEnd}`\n\n"
    out += "## Checks\n\n"
    for (check in result.checks) {
        out += "- `${check}`\n"
    }
    if (result.diagnostics.size > 0) {
        out += "\n## Diagnostics\n\n"
        for (diagnostic in result.diagnostics) {
            out += "- ${diagnostic}\n"
        }
    }
    out
}

private func ckbAbcdeWriteSummary(runRoot: String): Unit {
    let results = ckbAbcdeReadText("${runRoot}/results.jsonl")
    let lines = results.split("\n")
    let total = ckbAbcdeSummaryTotalForGroup(lines, "ALL")
    let passed = ckbAbcdeSummaryPassedForGroup(lines, "ALL")
    let passAt1 = ckbAbcdeSummaryPassAt1ForGroup(lines, "ALL")
    var csv = "group,total,passed,failed,pass_at_1,average_token_per_case,average_llm_turns_per_case,usage_parse_failed\n"
    csv += ckbAbcdeRenderSummaryCsvRow("ALL", lines)
    csv += ckbAbcdeRenderSummaryCsvRow(CkbAbcdeGroups.A, lines)
    csv += ckbAbcdeRenderSummaryCsvRow(CkbAbcdeGroups.B, lines)
    csv += ckbAbcdeRenderSummaryCsvRow(CkbAbcdeGroups.C, lines)
    csv += ckbAbcdeRenderSummaryCsvRow(CkbAbcdeGroups.D, lines)
    csv += ckbAbcdeRenderSummaryCsvRow(CkbAbcdeGroups.E, lines)
    ckbAbcdeWriteText("${runRoot}/summary.csv", csv)

    var md = "# CKB ABCDE Benchmark Summary\n\n"
    md += "- total: ${total}\n"
    md += "- passed: ${passed}\n"
    md += "- failed: ${total - passed}\n"
    md += "- pass@1: ${passAt1}\n"
    md += "- results: `${runRoot}/results.jsonl`\n"
    md += "- case usage summary: `${runRoot}/case-usage-summary.csv`\n\n"
    md += "| Group | total | passed | failed | pass@1 | avg token/case | avg llm turns/case | usage parse failed |\n"
    md += "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n"
    md += ckbAbcdeRenderSummaryMarkdownRow("ALL", lines)
    md += ckbAbcdeRenderSummaryMarkdownRow(CkbAbcdeGroups.A, lines)
    md += ckbAbcdeRenderSummaryMarkdownRow(CkbAbcdeGroups.B, lines)
    md += ckbAbcdeRenderSummaryMarkdownRow(CkbAbcdeGroups.C, lines)
    md += ckbAbcdeRenderSummaryMarkdownRow(CkbAbcdeGroups.D, lines)
    md += ckbAbcdeRenderSummaryMarkdownRow(CkbAbcdeGroups.E, lines)
    ckbAbcdeWriteText("${runRoot}/summary.md", md)
}

private func ckbAbcdeWritePass1GateArtifactsIfFullRun(options: CkbAbcdeRunnerOptions, runRoot: String): Bool {
    if (!ckbAbcdeShouldRunPass1Gate(options)) {
        return true
    }
    ckbAbcdeWritePass1GateArtifacts(options, runRoot)
}

public func ckbAbcdeWritePass1GateArtifactsForTest(options: CkbAbcdeRunnerOptions, runRoot: String): Bool {
    ckbAbcdeWritePass1GateArtifacts(options, runRoot)
}

private func ckbAbcdeShouldRunPass1Gate(options: CkbAbcdeRunnerOptions): Bool {
    options.caseStart == 0 && options.caseEnd == 163 && (options.groups.contains(CkbAbcdeGroups.C) || options.groups.contains(CkbAbcdeGroups.D))
}

private func ckbAbcdeWritePass1GateArtifacts(options: CkbAbcdeRunnerOptions, runRoot: String): Bool {
    if (options.runMode == "certification") {
        let strict=ckbStrictCertificationGate(ckbAbcdeReadText("${runRoot}/results.jsonl"),ckbAbcdeReadText(options.manifestPath))
        ckbAbcdeWriteText("${runRoot}/pass1-gate.json",renderCkbStrictCertificationGateJson(strict));ckbAbcdeWriteText("${runRoot}/pass1-gate.md",renderCkbStrictCertificationGateMarkdown(strict));return strict.ok
    }
    let gateOptions = CangjieHumanEvalPass1GateOptions()
    gateOptions.runRoot = runRoot
    gateOptions.manifestPath = options.manifestPath
    gateOptions.expectedTotal = options.caseEnd - options.caseStart + 1
    gateOptions.expectedPass = gateOptions.expectedTotal
    gateOptions.groups.clear()
    if (options.groups.contains(CkbAbcdeGroups.C)) {
        gateOptions.groups.add(CangjieHumanEvalPass1GateGroups.C)
    }
    if (options.groups.contains(CkbAbcdeGroups.D)) {
        gateOptions.groups.add(CangjieHumanEvalPass1GateGroups.D)
    }
    if (gateOptions.groups.size == 0) {
        return true
    }
    let gate = cangjieHumanEvalPass1GateFromFiles(gateOptions)
    ckbAbcdeWriteText("${runRoot}/pass1-gate.json", renderCangjieHumanEvalPass1GateJson(gate))
    ckbAbcdeWriteText("${runRoot}/pass1-gate.md", renderCangjieHumanEvalPass1GateMarkdown(gate))
    if (!gate.ok) {
        ckbAbcdeWriteText("${runRoot}/gap-curation-input.jsonl", emitCangjieHumanEvalGapCurationInput(gate))
    }
    gate.ok
}

private func ckbAbcdeRenderSummaryCsvRow(group: String, lines: Array<String>): String {
    let total = ckbAbcdeSummaryTotalForGroup(lines, group)
    let passed = ckbAbcdeSummaryPassedForGroup(lines, group)
    let passAt1 = ckbAbcdeSummaryPassAt1ForGroup(lines, group)
    let usageOk = ckbAbcdeSummaryUsageOkForGroup(lines, group)
    let tokenTotal = ckbAbcdeSummaryTokenTotalForGroup(lines, group)
    let turnTotal = ckbAbcdeSummaryTurnTotalForGroup(lines, group)
    "${group},${total},${passed},${total - passed},${passAt1},${ckbAbcdeAverageText(tokenTotal, usageOk)},${ckbAbcdeAverageText(turnTotal, usageOk)},${total - usageOk}\n"
}

private func ckbAbcdeRenderSummaryMarkdownRow(group: String, lines: Array<String>): String {
    let total = ckbAbcdeSummaryTotalForGroup(lines, group)
    let passed = ckbAbcdeSummaryPassedForGroup(lines, group)
    let passAt1 = ckbAbcdeSummaryPassAt1ForGroup(lines, group)
    let usageOk = ckbAbcdeSummaryUsageOkForGroup(lines, group)
    let tokenTotal = ckbAbcdeSummaryTokenTotalForGroup(lines, group)
    let turnTotal = ckbAbcdeSummaryTurnTotalForGroup(lines, group)
    "| ${group} | ${total} | ${passed} | ${total - passed} | ${passAt1} | ${ckbAbcdeAverageText(tokenTotal, usageOk)} | ${ckbAbcdeAverageText(turnTotal, usageOk)} | ${total - usageOk} |\n"
}

private func ckbAbcdeSummaryTotalForGroup(lines: Array<String>, group: String): Int64 {
    var total: Int64 = 0
    for (line in lines) {
        if (line.trimAscii() == "") {
            continue
        }
        if (ckbAbcdeSummaryLineMatchesGroup(line, group)) {
            total += 1
        }
    }
    total
}

private func ckbAbcdeSummaryPassedForGroup(lines: Array<String>, group: String): Int64 {
    var passed: Int64 = 0
    for (line in lines) {
        if (line.trimAscii() != "" && ckbAbcdeSummaryLineMatchesGroup(line, group) && line.contains("\"status\":\"passed\"")) {
            passed += 1
        }
    }
    passed
}

private func ckbAbcdeSummaryPassAt1ForGroup(lines: Array<String>, group: String): Int64 {
    var passAt1: Int64 = 0
    for (line in lines) {
        if (line.trimAscii() != "" && ckbAbcdeSummaryLineMatchesGroup(line, group) && line.contains("\"unitPassAt1\":true")) {
            passAt1 += 1
        }
    }
    passAt1
}

private func ckbAbcdeSummaryUsageOkForGroup(lines: Array<String>, group: String): Int64 {
    var ok: Int64 = 0
    for (line in lines) {
        if (line.trimAscii() != "" && ckbAbcdeSummaryLineMatchesGroup(line, group) && line.contains("\"usageParseStatus\":\"ok\"")) {
            ok += 1
        }
    }
    ok
}

private func ckbAbcdeSummaryTokenTotalForGroup(lines: Array<String>, group: String): Int64 {
    var total: Int64 = 0
    for (line in lines) {
        if (line.trimAscii() != "" && ckbAbcdeSummaryLineMatchesGroup(line, group) && line.contains("\"usageParseStatus\":\"ok\"")) {
            total += ckbAbcdeJsonIntField(line, "modelTotalTokens", 0)
        }
    }
    total
}

private func ckbAbcdeSummaryTurnTotalForGroup(lines: Array<String>, group: String): Int64 {
    var total: Int64 = 0
    for (line in lines) {
        if (line.trimAscii() != "" && ckbAbcdeSummaryLineMatchesGroup(line, group) && line.contains("\"usageParseStatus\":\"ok\"")) {
            total += ckbAbcdeJsonIntField(line, "llmTurnCount", 0)
        }
    }
    total
}

private func ckbAbcdeSummaryLineMatchesGroup(line: String, group: String): Bool {
    group == "ALL" || line.contains("\"group\":\"${group}\"")
}

public func ckbAbcdeRenderEnvSwitchCheck(caseId: String, fromGroup: String, toGroup: String, workspace: String, groupRoot: String): String {
    let fromValue = if (fromGroup == "") { "START" } else { fromGroup }
    "{\"caseId\":\"${caseId}\",\"fromGroup\":\"${fromValue}\",\"toGroup\":\"${toGroup}\",\"cwd\":\"${ckbAbcdeJsonEscape(workspace)}\",\"mcpConfigPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/mcp-config.json")}\",\"knowledgeEntry\":\"${ckbAbcdeKnowledgeEntry(toGroup)}\",\"toolTransport\":\"${ckbAbcdeToolTransport(toGroup)}\",\"cleanupAction\":\"fresh_group_workspace_and_strict_mcp_config\",\"ok\":true}\n".trimAscii()
}

public func ckbAbcdeRenderCaseResult(
    options: CkbAbcdeRunnerOptions,
    runRoot: String,
    caseId: String,
    group: String,
    status: String,
    claudeExitCode: Int64,
    testExitCode: Int64,
    unitPass: Bool,
    unitPassAt1: Bool,
    failureType: String,
    toolEvidence: String,
    violation: String,
    groupRoot: String
): String {
    let evidence=ckbAbcdeTaskKnowledgeEvidence(group,ckbAbcdeReadText("${groupRoot}/claude-transcript.jsonl"),ckbAbcdeReadText("${groupRoot}/canonical-task-context.json"));ckbAbcdePersistTaskKnowledgeEvidence(groupRoot,evidence,evidence.valid&&evidence.knowledgeVersion==options.knowledgeVersion)
    ckbAbcdeRenderCaseResultBound(options, runRoot, caseId, group, status, claudeExitCode, testExitCode, unitPass, unitPassAt1, failureType, toolEvidence, violation, groupRoot, evidence)
}

private func ckbAbcdeRenderCaseResultBound(
    options: CkbAbcdeRunnerOptions, runRoot: String, caseId: String, group: String, status: String,
    claudeExitCode: Int64, testExitCode: Int64, unitPass: Bool, unitPassAt1: Bool, failureType: String,
    toolEvidence: String, violation: String, groupRoot: String, taskKnowledge: CkbAbcdeTaskKnowledgeEvidence
): String {
    let protocolViolation = violation != "none"
    let modelRunStatus = if (claudeExitCode == 0) { "ok" } else { "failed" }
    let toolCallCount = ckbAbcdeToolCallCount(group, toolEvidence)
    let firstClaudeExitCode = ckbAbcdeFirstClaudeAttemptExitCode(groupRoot)
    let claudeAttemptCount = ckbAbcdeClaudeAttemptCount(groupRoot)
    let sampleAttemptCount = ckbAbcdeSampleAttemptCount(groupRoot)
    let selectedTransportAttempt = ckbAbcdeSelectedSampleTransportAttempt(groupRoot)
    let usage = ckbAbcdeParseClaudeUsageFile("${groupRoot}/claude-transcript.jsonl")
    let explicitDevelopment = options.explicitRunMode && options.runMode == "development"
    let recordedRunMode = if (options.explicitRunMode) { options.runMode } else { "" }
    let workspaceId = "cases/${caseId}/${group}/workspace"
    let sessionId = "cases/${caseId}/${group}/session"
    let runtimeHomeId = "cases/${caseId}/${group}/runtime-home"
    let finalAttempt = if (selectedTransportAttempt > 0) { selectedTransportAttempt } else if (claudeAttemptCount > 0) { claudeAttemptCount } else { 1 }
    let firstAttemptPass = unitPassAt1 && status == "passed"
    let triageEvidence = ckbAbcdeTriageEvidenceBound(options, caseId, finalAttempt, failureType, unitPass, protocolViolation, claudeExitCode, testExitCode, groupRoot, taskKnowledge)
    let triage = if (options.explicitRunMode) { triageEvalFailure(triageEvidence) } else { CangjieEvalFailureTriageResult() }
    let triageStatus = if (!options.explicitRunMode) { "legacy" } else if (triage.ok) { triage.category } else { "blocked:${triage.diagnostic}" }
    let failureRoute = if (triage.ok) { triage.route } else { ckbAbcdeFailureRoute(failureType) }
    let firstAttemptTriage = if (firstAttemptPass) { "none" } else if (sampleAttemptCount == 0) { "environment_failure" } else { triageStatus }
    let confirmationStatus = if (triage.ok && triage.category == "knowledge_gap") { "pending_classifier_artifacts" } else { "not_applicable" }
    let observedRuntimeModel = ckbAbcdeObservedModel(ckbAbcdeReadText("${groupRoot}/claude-transcript.jsonl"))
    let claudeCodeVersion = ckbAbcdeClaudeVersion(executable: options.claudeBin)
    let canonicalProviderIdentity = ckbAbcdeProviderIdentityJson(observedRuntimeModel, claudeCodeVersion)
    let providerIdentityText = ckbAbcdeReadText("${groupRoot}/provider-identity.json")
    let providerIdentityHash = if (providerIdentityText == "") { "" } else { benchmarkGapSha256(providerIdentityText) }
    let identityReady = observedRuntimeModel == options.expectedModelVersion && providerIdentityText == canonicalProviderIdentity && ckbAbcdeStrictSha256(providerIdentityHash)
    let developmentPass = explicitDevelopment && status == "passed" && identityReady
    let closureStatus = if (!options.explicitRunMode) { "legacy" } else if (options.runMode == "certification") { "certification_not_run" } else if (developmentPass && triage.ok && triage.category == "none") { "development_closed" } else { "development_open" }
    let taskKnowledgeReady = taskKnowledge.valid && taskKnowledge.knowledgeVersion == options.knowledgeVersion
    "{\"runId\":\"${ckbAbcdeJsonEscape(options.runId)}\",\"benchmark\":\"Cangjie-HumanEval\",\"runMode\":\"${ckbAbcdeJsonEscape(recordedRunMode)}\",\"datasetVersion\":\"${ckbAbcdeJsonEscape(options.datasetVersion)}\",\"candidateVersion\":\"${ckbAbcdeJsonEscape(options.candidateVersion)}\",\"lineageKnowledgeVersion\":\"${ckbAbcdeJsonEscape(options.knowledgeVersion)}\",\"modelFingerprint\":\"${ckbAbcdeJsonEscape(options.modelFingerprint)}\",\"workspaceId\":\"${ckbAbcdeJsonEscape(workspaceId)}\",\"sessionId\":\"${ckbAbcdeJsonEscape(sessionId)}\",\"runtimeHomeId\":\"${ckbAbcdeJsonEscape(runtimeHomeId)}\",\"developmentPass\":${developmentPass},\"firstAttemptPass\":${firstAttemptPass},\"firstAttemptTriage\":\"${ckbAbcdeJsonEscape(firstAttemptTriage)}\",\"knowledgeGapConfirmationStatus\":\"${confirmationStatus}\",\"certificationPassAt1\":null,\"closureStatus\":\"${closureStatus}\",\"triageStatus\":\"${ckbAbcdeJsonEscape(triageStatus)}\",\"failureRoute\":\"${failureRoute}\",\"caseId\":\"${caseId}\",\"group\":\"${group}\",\"expectedModelVersion\":\"${ckbAbcdeJsonEscape(options.expectedModelVersion)}\",\"observedModelVersion\":\"${ckbAbcdeJsonEscape(observedRuntimeModel)}\",\"model\":\"${ckbAbcdeJsonEscape(observedRuntimeModel)}\",\"claudeCodeVersion\":\"${ckbAbcdeJsonEscape(claudeCodeVersion)}\",\"providerIdentityHash\":\"${ckbAbcdeJsonEscape(providerIdentityHash)}\",\"knowledgeEntry\":\"${ckbAbcdeKnowledgeEntry(group)}\",\"preflightStatus\":\"ok\",\"modelRunStatus\":\"${modelRunStatus}\",\"status\":\"${status}\",\"claudeExitCode\":${claudeExitCode},\"firstClaudeExitCode\":${firstClaudeExitCode},\"claudeAttemptCount\":${claudeAttemptCount},\"transportAttemptCount\":${claudeAttemptCount},\"sampleAttemptCount\":${sampleAttemptCount},\"selectedTransportAttempt\":${selectedTransportAttempt},\"testExitCode\":${testExitCode},\"unitPass\":${unitPass},\"unitPassAt1\":${unitPassAt1},\"failureType\":\"${failureType}\",\"usageParseStatus\":\"${usage.usageParseStatus}\",\"modelInputTokens\":${usage.modelInputTokens},\"modelOutputTokens\":${usage.modelOutputTokens},\"modelCacheReadTokens\":${usage.modelCacheReadTokens},\"modelCacheCreationTokens\":${usage.modelCacheCreationTokens},\"modelTotalTokens\":${usage.modelTotalTokens},\"llmTurnCount\":${usage.llmTurnCount},\"usageSourcePath\":\"${ckbAbcdeJsonEscape(usage.usageSourcePath)}\",\"ckbUsed\":${ckbAbcdeUsesCkb(group)},\"localDocsUsed\":${group == CkbAbcdeGroups.E},\"toolTransport\":\"${ckbAbcdeToolTransport(group)}\",\"toolCallCount\":${toolCallCount},\"toolEvidence\":\"${ckbAbcdeJsonEscape(toolEvidence)}\",\"toolEvidenceHash\":\"${ckbAbcdeJsonEscape(if (taskKnowledgeReady) { taskKnowledge.evidenceHash } else { "" })}\",\"toolCoveragePass\":${taskKnowledgeReady && taskKnowledge.coveragePass},\"transportParityPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/parity.jsonl")}\",\"knowledgeVersion\":\"${ckbAbcdeJsonEscape(if (taskKnowledgeReady) { taskKnowledge.knowledgeVersion } else { "" })}\",\"citationCount\":${if (taskKnowledgeReady) { taskKnowledge.citationCount } else { 0 }},\"docsPathCount\":${if (group == CkbAbcdeGroups.E) { 2 } else { 0 }},\"protocolViolation\":${protocolViolation},\"protocolViolationReason\":\"${ckbAbcdeJsonEscape(violation)}\",\"durationMs\":0,\"promptPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/prompt.final.md")}\",\"transcriptPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/claude-transcript.jsonl")}\",\"testLogPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/test.log")}\",\"resultPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/case-result.json")}\",\"notes\":\"${ckbAbcdeJsonEscape(ckbAbcdeResultNotes(status, violation, toolEvidence))}\"}"
}

private func ckbAbcdeTriageEvidenceBound(options: CkbAbcdeRunnerOptions, caseId: String, attempt: Int64, failureType: String, unitPass: Bool, protocolViolation: Bool, claudeExitCode: Int64, testExitCode: Int64, groupRoot: String, taskKnowledge: CkbAbcdeTaskKnowledgeEvidence): String {
    let timedOut = claudeExitCode == 124
    let environmentFailure = claudeExitCode != 0 && !timedOut
    let observation = if (failureType == "none") { "case_passed" } else { failureType }
    let firstRetrieval = ckbAbcdeFirstSampleTranscript(groupRoot)
    let taskContext = ckbAbcdeReadText("${groupRoot}/canonical-task-context.json")
    let structuredMissing = ckbAbcdeHasBoundStructuredMissingEvidence(caseId, taskContext, firstRetrieval)
    let coverageCompilerConflict = ckbAbcdeHasBoundStructuredCoveragePass(caseId, taskContext, firstRetrieval) && ckbAbcdeReadText("${groupRoot}/test.log").toAsciiLower().contains("is not a member of")
    let suspectedKnowledgeGap = options.runMode == "development" && failureType == "compile_error" && !unitPass && !protocolViolation && claudeExitCode == 0 && testExitCode != 0 && (structuredMissing || coverageCompilerConflict)
    let retrievalDiagnostic = if (taskKnowledge.valid) { "bound_tool_result" } else if (structuredMissing && suspectedKnowledgeGap) { "structured_missing_evidence" } else if (coverageCompilerConflict && suspectedKnowledgeGap) { "coverage_compiler_member_conflict" } else { "not_applicable" }
    let retrievalEvidenceHash = if (taskKnowledge.valid) { taskKnowledge.evidenceHash } else if (suspectedKnowledgeGap) { benchmarkGapSha256(taskContext + firstRetrieval) } else { "" }
    let provisional = "{\"attempt\":${attempt},\"runMode\":\"${ckbAbcdeJsonEscape(options.runMode)}\",\"failureType\":\"${ckbAbcdeJsonEscape(failureType)}\",\"protocolViolation\":${protocolViolation},\"timedOut\":${timedOut},\"environmentFailure\":${environmentFailure},\"suspectedKnowledgeGap\":${suspectedKnowledgeGap},\"reasoningFailure\":false,\"unitPass\":${unitPass}}"
    let reasoningFailure = cangjieEvalAuthoritativeFailureCategory(provisional) == "reasoning_failure"
    let base = "{\"caseId\":\"${ckbAbcdeJsonEscape(caseId)}\",\"runId\":\"${ckbAbcdeJsonEscape(options.runId)}\",\"datasetVersion\":\"${ckbAbcdeJsonEscape(options.datasetVersion)}\",\"attempt\":${attempt},\"transportAttempt\":${attempt},\"sampleAttempt\":${if(ckbAbcdeSelectedSampleTransportAttempt(groupRoot)==attempt){1}else{0}},\"runMode\":\"${ckbAbcdeJsonEscape(options.runMode)}\",\"failureObservation\":\"${ckbAbcdeJsonEscape(observation)}\",\"protocolViolation\":${protocolViolation},\"timedOut\":${timedOut},\"environmentFailure\":${environmentFailure},\"suspectedKnowledgeGap\":${suspectedKnowledgeGap},\"retrievalDiagnostic\":\"${retrievalDiagnostic}\",\"retrievalEvidenceHash\":\"${retrievalEvidenceHash}\",\"reasoningFailure\":${reasoningFailure && !suspectedKnowledgeGap},\"failureType\":\"${ckbAbcdeJsonEscape(failureType)}\",\"unitPass\":${unitPass}}"
    let hash = cangjieEvalTriageResultEvidenceHash(base)
    base.replace("}", ",\"resultEvidenceHash\":\"${hash}\"}")
}

private func ckbAbcdeFirstSampleTranscript(groupRoot:String):String{
    let selected=ckbAbcdeSelectedSampleTransportAttempt(groupRoot)
    if(selected>0){
        let selectedTranscript=ckbAbcdeReadText("${groupRoot}/claude-transcript.attempt-${selected}.jsonl")
        if(selectedTranscript!=""){return selectedTranscript}
        return ckbAbcdeReadText("${groupRoot}/claude-transcript.jsonl")
    }
    let legacy=ckbAbcdeReadText("${groupRoot}/claude-transcript.attempt-1.jsonl")
    if(legacy!=""){legacy}else{ckbAbcdeReadText("${groupRoot}/claude-transcript.jsonl")}
}

private func ckbAbcdeHasBoundStructuredCoveragePass(caseId: String, taskContext: String, transcript: String): Bool {
    if (caseId == "" || !taskContext.contains("\"taskId\":\"${ckbAbcdeJsonEscape(caseId)}\"") || transcript == "") { return false }
    for (line in transcript.split("\n")) {
        if (!line.contains("\"type\":\"user\"") || !line.contains("\"type\":\"tool_result\"")) { continue }
        try {
            _ = JsonValue.fromStr(line).asObject()
            if (line.contains("\\\"coveragePass\\\":true") || line.contains("\"coveragePass\":true")) { return true }
        } catch (_: Exception) {}
    }
    false
}

private func ckbAbcdeHasBoundStructuredMissingEvidence(caseId: String, taskContext: String, transcript: String): Bool {
    if (caseId == "" || !taskContext.contains("\"taskId\":\"${ckbAbcdeJsonEscape(caseId)}\"") || transcript == "") { return false }
    for (line in transcript.split("\n")) {
        if (!line.contains("\"type\":\"user\"") || !line.contains("\"type\":\"tool_result\"")) { continue }
        try {
            _ = JsonValue.fromStr(line).asObject()
            let citationMissing = line.contains("\\\"diagnostic\\\":\\\"missing_citation\\\"") || line.contains("\"diagnostic\":\"missing_citation\"")
            let evidenceMissing = line.contains("\\\"reason\\\":\\\"evidence_missing\\\"") || line.contains("\"reason\":\"evidence_missing\"") || line.contains("\\\"missingReason\\\":\\\"evidence_missing\\\"") || line.contains("\"missingReason\":\"evidence_missing\"")
            let coverageMissing = (line.contains("\\\"coveragePass\\\":false") || line.contains("\"coveragePass\":false")) && (line.contains("\\\"status\\\":\\\"missing\\\"") || line.contains("\"status\":\"missing\"") || line.contains("\\\"missingCount\\\":") || line.contains("\"missingCount\":"))
            if (citationMissing || evidenceMissing || coverageMissing) { return true }
        } catch (_: Exception) {}
    }
    false
}

public func ckbAbcdeHasBoundStructuredMissingEvidenceForTest(caseId: String, taskContext: String, transcript: String): Bool {
    ckbAbcdeHasBoundStructuredMissingEvidence(caseId, taskContext, transcript)
}

public func ckbAbcdeTriageEvidenceForTest(options: CkbAbcdeRunnerOptions, caseId: String, attempt: Int64, failureType: String, unitPass: Bool, protocolViolation: Bool, claudeExitCode: Int64, testExitCode: Int64, groupRoot: String): String {
    let transcript = ckbAbcdeReadText("${groupRoot}/claude-transcript.jsonl"); let context = ckbAbcdeReadText("${groupRoot}/canonical-task-context.json")
    let c = ckbAbcdeTaskKnowledgeEvidence(CkbAbcdeGroups.C, transcript, context); let evidence = if (c.valid) { c } else { ckbAbcdeTaskKnowledgeEvidence(CkbAbcdeGroups.D, transcript, context) }
    ckbAbcdeTriageEvidenceBound(options, caseId, attempt, failureType, unitPass, protocolViolation, claudeExitCode, testExitCode, groupRoot, evidence)
}

private func ckbAbcdeRenderCaseSummary(options: CkbAbcdeRunnerOptions, runRoot: String, caseId: String, summaries: ArrayList<String>): String {
    var rows = ""
    var failed: Int64 = 0
    var violations: Int64 = 0
    var usageOk: Int64 = 0
    var tokenTotal: Int64 = 0
    var turnTotal: Int64 = 0
    var usageFailedGroups = ""
    for (i in 0..summaries.size) {
        if (i > 0) {
            rows += ","
        }
        rows += summaries[i]
        if (summaries[i].contains("\"status\":\"failed\"")) {
            failed += 1
        }
        if (summaries[i].contains("\"protocolViolation\":true")) {
            violations += 1
        }
        if (summaries[i].contains("\"usageParseStatus\":\"ok\"")) {
            usageOk += 1
            tokenTotal += ckbAbcdeJsonIntField(summaries[i], "modelTotalTokens", 0)
            turnTotal += ckbAbcdeJsonIntField(summaries[i], "llmTurnCount", 0)
        } else {
            if (usageFailedGroups != "") {
                usageFailedGroups += ","
            }
            usageFailedGroups += "\"${ckbAbcdeJsonEscape(ckbAbcdeJsonStringField(summaries[i], "group"))}\""
        }
    }
    "{\"runId\":\"${ckbAbcdeJsonEscape(options.runId)}\",\"caseId\":\"${caseId}\",\"benchmark\":\"Cangjie-HumanEval\",\"completedGroups\":${summaries.size},\"failedGroups\":${failed},\"protocolViolationGroups\":${violations},\"usageParseOkGroupCount\":${usageOk},\"caseTotalModelTokens\":${tokenTotal},\"caseAverageModelTokensPerGroup\":${ckbAbcdeAverageText(tokenTotal, usageOk)},\"caseTotalLlmTurns\":${turnTotal},\"caseAverageLlmTurnsPerGroup\":${ckbAbcdeAverageText(turnTotal, usageOk)},\"usageParseFailedGroups\":[${usageFailedGroups}],\"resultRows\":[${rows}],\"caseResultPaths\":\"${ckbAbcdeJsonEscape("${runRoot}/cases/${caseId}")}\",\"envSwitchChecksPath\":\"${ckbAbcdeJsonEscape("${runRoot}/cases/${caseId}/env-switch-checks.jsonl")}\"}\n"
}

private func ckbAbcdeRenderCaseUsageSummaryCsvRow(caseId: String, summaries: ArrayList<String>): String {
    var usageOk: Int64 = 0
    var tokenTotal: Int64 = 0
    var turnTotal: Int64 = 0
    var failedGroups = ""
    for (summary in summaries) {
        if (summary.contains("\"usageParseStatus\":\"ok\"")) {
            usageOk += 1
            tokenTotal += ckbAbcdeJsonIntField(summary, "modelTotalTokens", 0)
            turnTotal += ckbAbcdeJsonIntField(summary, "llmTurnCount", 0)
        } else {
            if (failedGroups != "") {
                failedGroups += "|"
            }
            failedGroups += ckbAbcdeJsonStringField(summary, "group")
        }
    }
    "${caseId},${usageOk},${tokenTotal},${ckbAbcdeAverageText(tokenTotal, usageOk)},${turnTotal},${ckbAbcdeAverageText(turnTotal, usageOk)},${failedGroups}"
}

public func ckbAbcdeRenderCaseSummaryForTest(options: CkbAbcdeRunnerOptions, runRoot: String, caseId: String, summaries: ArrayList<String>): String {
    ckbAbcdeRenderCaseSummary(options, runRoot, caseId, summaries)
}

public func ckbAbcdeRenderCaseUsageSummaryCsvRowForTest(caseId: String, summaries: ArrayList<String>): String {
    ckbAbcdeRenderCaseUsageSummaryCsvRow(caseId, summaries)
}

private func ckbAbcdeToolEvidence(group: String, transcript: String): String {
    if (group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D) {
        for (line in transcript.split("\n")) {
            if (line.contains("\"subtype\":\"init\"")) {
                continue
            }
            if (line.contains("mcp__ckb-cangjie__cangjie_task_knowledge_pack") ||
                line.contains("mcp__ckb-cangjie-http__cangjie_task_knowledge_pack") ||
                line.contains("\"name\":\"cangjie_task_knowledge_pack\"")) {
                return "cangjie_task_knowledge_pack"
            }
        }
        return "manual_required"
    }
    "none"
}

private func ckbAbcdeCanonicalStringArrayEqual(expected: JsonObject, actual: JsonObject, key: String): Bool {
    let left = expected.get(key).getOrThrow().asArray().getItems()
    let right = actual.get(key).getOrThrow().asArray().getItems()
    if (left.size != right.size) { return false }
    for (i in 0..left.size) { if (left[i].asString().getValue() != right[i].asString().getValue()) { return false } }
    true
}

private func ckbAbcdeCanonicalTaskInputEqual(expected: JsonObject, actual: JsonObject): Bool {
    if (expected.getFields().size != 13 || actual.getFields().size != expected.getFields().size) { return false }
    for (key in ["taskId", "benchmark", "taskText", "signature", "datasetVersion", "promptHash", "starterHash", "targetVersion", "sourceSet", "versionPolicy", "responseMode"]) {
        if (ckbAbcdeStrictJsonString(expected, key) == "" || ckbAbcdeStrictJsonString(actual, key) != ckbAbcdeStrictJsonString(expected, key)) { return false }
    }
    ckbAbcdeStrictJsonInt(expected, "budget", -1) >= 0 &&
        ckbAbcdeStrictJsonInt(actual, "budget", -1) == ckbAbcdeStrictJsonInt(expected, "budget", -1) &&
        ckbAbcdeCanonicalStringArrayEqual(expected, actual, "expectedKnowledgeTags")
}

private func ckbAbcdeEvidenceHashSafe(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size == 0 || runes.size > 256) { return false }
    let lowered = value.toAsciiLower()
    if (lowered.contains("token=") || lowered.contains("authorization") || lowered.contains("api_key") || lowered.contains("password")) { return false }
    for (ch in runes) { if (ch <= r' ') { return false } }
    true
}

private func ckbAbcdeTaskKnowledgeToolName(group: String): String {
    if (group == CkbAbcdeGroups.C) { return "mcp__ckb-cangjie__cangjie_task_knowledge_pack" }
    if (group == CkbAbcdeGroups.D) { return "mcp__ckb-cangjie-http__cangjie_task_knowledge_pack" }
    ""
}

private func ckbAbcdeTaskKnowledgeEvidence(group: String, transcript: String, contextText: String): CkbAbcdeTaskKnowledgeEvidence {
    let result = CkbAbcdeTaskKnowledgeEvidence()
    if (transcript.size > CKB_ABCDE_MAX_MODEL_TRANSCRIPT_BYTES) { result.diagnostic = "transcript_too_large"; return result }
    if (contextText.size > 262144) { result.diagnostic = "task_context_too_large"; return result }
    let toolName = ckbAbcdeTaskKnowledgeToolName(group)
    if (toolName == "") { result.diagnostic = "task_knowledge_tool_not_applicable"; return result }
    var context: JsonObject
    try { context = JsonValue.fromStr(contextText).asObject() } catch (_: Exception) { result.diagnostic = "malformed_task_context_json"; return result }
    var toolUseId = ""
    var toolUseCount: Int64 = 0
    for (line in transcript.split("\n")) {
        if (line.trimAscii() == "") { continue }
        try {
            let event = JsonValue.fromStr(line).asObject()
            if (ckbAbcdeStrictJsonString(event, "type") != "assistant") { continue }
            let content = event.get("message").getOrThrow().asObject().get("content").getOrThrow().asArray().getItems()
            for (value in content) {
                let entry = value.asObject()
                if (ckbAbcdeStrictJsonString(entry, "type") != "tool_use" || ckbAbcdeStrictJsonString(entry, "name") != toolName) { continue }
                toolUseCount += 1
                toolUseId = ckbAbcdeStrictJsonString(entry, "id")
                if (toolUseId == "" || entry.get("input").getOrThrow().asObject().getFields().size != 0) { result.diagnostic = "bound_tool_arguments_not_empty"; return result }
            }
        } catch (_: Exception) { result.diagnostic = "malformed_transcript_json"; return result }
    }
    if (toolUseCount == 0) { result.diagnostic = "task_knowledge_tool_use_missing"; return result }
    if (toolUseCount != 1) { result.diagnostic = "task_knowledge_tool_use_not_unique"; return result }
    var pairedCount: Int64 = 0
    for (line in transcript.split("\n")) {
        if (line.trimAscii() == "") { continue }
        try {
            let event = JsonValue.fromStr(line).asObject()
            if (ckbAbcdeStrictJsonString(event, "type") != "user") { continue }
            let content = event.get("message").getOrThrow().asObject().get("content").getOrThrow().asArray().getItems()
            for (value in content) {
                let entry = value.asObject()
                if (ckbAbcdeStrictJsonString(entry, "type") != "tool_result" || ckbAbcdeStrictJsonString(entry, "tool_use_id") != toolUseId) { continue }
                pairedCount += 1
                match (entry.get("is_error")) {
                    case Some(value) =>
                        if (value.toString() != "null") {
                            try {
                                if (value.asBool().getValue()) { result.diagnostic = "paired_tool_result_error"; return result }
                            } catch (_: Exception) { result.diagnostic = "malformed_transcript_json"; return result }
                        }
                    case None => ()
                }
                let payload = JsonValue.fromStr(ckbAbcdeStrictJsonString(entry, "content")).asObject()
                let evidenceHash = ckbAbcdeStrictJsonString(payload, "evidenceHash")
                let knowledgeVersion = ckbAbcdeStrictJsonString(payload, "knowledgeVersion")
                if (ckbAbcdeStrictJsonString(payload, "taskId") != ckbAbcdeStrictJsonString(context, "taskId") || ckbAbcdeStrictJsonString(payload, "resultType") != "task_knowledge_pack") {
                    result.diagnostic = "paired_tool_result_mismatch"; return result
                }
                if (!ckbAbcdeEvidenceHashSafe(evidenceHash)) { result.diagnostic = "evidence_hash_invalid"; return result }
                if (knowledgeVersion == "") { result.diagnostic = "knowledge_version_missing"; return result }
                var binding: JsonObject
                try { binding = payload.get("requestBinding").getOrThrow().asObject() } catch (_: Exception) { result.diagnostic = "request_binding_missing"; return result }
                if (binding.getFields().size != 6 || ckbAbcdeStrictJsonString(binding, "schemaVersion") != CKB_MCP_BOUND_CONTEXT_SCHEMA ||
                    ckbAbcdeStrictJsonString(binding, "bindingMode") != "runner_immutable" ||
                    ckbAbcdeStrictJsonString(binding, "taskId") != ckbAbcdeStrictJsonString(context, "taskId")) { result.diagnostic = "request_binding_invalid"; return result }
                let expectedRequestHash = benchmarkGapSha256(contextText.trimAscii())
                if (ckbAbcdeStrictJsonString(binding, "requestHash") != expectedRequestHash ||
                    ckbAbcdeStrictJsonString(binding, "effectiveRequestHash") != expectedRequestHash ||
                    ckbAbcdeStrictJsonString(binding, "modelArgumentsHash") != benchmarkGapSha256("{}")) { result.diagnostic = "request_binding_hash_mismatch"; return result }
                result.evidenceHash = evidenceHash
                result.requestBindingHash = expectedRequestHash
                result.knowledgeVersion = knowledgeVersion
                result.coveragePass = payload.get("coverage").getOrThrow().asObject().get("coveragePass").getOrThrow().asBool().getValue()
                result.citationCount = Int64(payload.get("citations").getOrThrow().asArray().getItems().size)
            }
        } catch (_: Exception) { result.diagnostic = "malformed_transcript_json"; return result }
    }
    if (pairedCount == 0) { result.diagnostic = "paired_tool_result_missing"; result.evidenceHash = ""; result.knowledgeVersion = ""; return result }
    if (pairedCount != 1) { result.diagnostic = "paired_tool_result_not_unique"; result.evidenceHash = ""; result.knowledgeVersion = ""; return result }
    result.valid = true; result.diagnostic = "ok"; result
}

public func ckbAbcdeTaskKnowledgeEvidenceForTest(group: String, transcript: String, contextText: String): CkbAbcdeTaskKnowledgeEvidence {
    ckbAbcdeTaskKnowledgeEvidence(group, transcript, contextText)
}
public func ckbAbcdeTaskKnowledgeEvidenceForAudit(group:String,transcript:String,contextText:String):CkbAbcdeTaskKnowledgeEvidence{ckbAbcdeTaskKnowledgeEvidence(group,transcript,contextText)}

public func ckbAbcdeTaskKnowledgeEvidenceFromUtf8ForTest(group: String, transcript: Array<UInt8>, context: Array<UInt8>): CkbAbcdeTaskKnowledgeEvidence {
    try { ckbAbcdeTaskKnowledgeEvidence(group, String.fromUtf8(transcript), String.fromUtf8(context)) } catch (_: Exception) {
        let result = CkbAbcdeTaskKnowledgeEvidence(); result.diagnostic = "invalid_response_encoding"; result
    }
}

private func ckbAbcdePersistTaskKnowledgeEvidence(groupRoot:String,evidence:CkbAbcdeTaskKnowledgeEvidence,ready:Bool):Unit{
    let hash=if(ready){evidence.evidenceHash}else{""};let version=if(ready){evidence.knowledgeVersion}else{""}
    ckbAbcdeWriteText("${groupRoot}/paired-tool-evidence.json","{\"valid\":${ready},\"evidenceHash\":\"${ckbAbcdeJsonEscape(hash)}\",\"knowledgeVersion\":\"${ckbAbcdeJsonEscape(version)}\",\"requestBindingHash\":\"${if(ready){ckbAbcdeJsonEscape(evidence.requestBindingHash)}else{""}}\",\"coveragePass\":${ready&&evidence.coveragePass},\"citationCount\":${if(ready){evidence.citationCount}else{0}}}\n")
}

public func ckbAbcdeToolEvidenceForTest(group: String, transcript: String): String {
    ckbAbcdeToolEvidence(group, transcript)
}

private func ckbAbcdeKnowledgeEntry(group: String): String {
    if (group == CkbAbcdeGroups.B) { return "ckb_rest" }
    if (group == CkbAbcdeGroups.C) { return "mcp_stdio" }
    if (group == CkbAbcdeGroups.D) { return "mcp_http" }
    if (group == CkbAbcdeGroups.E) { return "local_docs" }
    "none"
}

private func ckbAbcdeToolTransport(group: String): String {
    if (group == CkbAbcdeGroups.C) { return "stdio" }
    if (group == CkbAbcdeGroups.D) { return "streamable_http" }
    "none"
}

private func ckbAbcdeUsesCkb(group: String): Bool {
    group == CkbAbcdeGroups.B || group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D
}

private func ckbAbcdeToolCallCount(group: String, toolEvidence: String): Int64 {
    if ((group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D) && toolEvidence == "cangjie_task_knowledge_pack") {
        return 1
    }
    0
}

private func ckbAbcdeRequiredKnowledgeReady(group: String, knowledgeReady: Bool, toolEvidence: String): Bool {
    if (group == CkbAbcdeGroups.B) {
        return knowledgeReady
    }
    if (group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D) {
        return toolEvidence == "cangjie_task_knowledge_pack"
    }
    true
}

private func ckbAbcdeFailureType(claudeExitCode: Int64, testExitCode: Int64, unitPass: Bool, violation: String, testLog: String, toolReady: Bool): String {
    if (violation != "none") {
        return "protocol_violation"
    }
    if (claudeExitCode == 124) {
        return "timeout"
    }
    if (!toolReady) {
        return "tool_unavailable"
    }
    if (claudeExitCode != 0) {
        return "model_error"
    }
    if (unitPass) {
        return "none"
    }
    let lowered = testLog.toAsciiLower()
    if (testExitCode != 0 && (lowered.contains("compile") || lowered.contains("syntax") || lowered.contains("error:"))) {
        return "compile_error"
    }
    "unit_failure"
}

public func ckbAbcdeExpandedFailureType(legacy: String): String {
    if (legacy == "protocol_violation") { return "policy_violation" }
    if (legacy == "tool_unavailable") { return "tool_failure" }
    if (legacy == "model_error") { return "environment_failure" }
    if (legacy == "unit_failure") { return "test_failure" }
    legacy
}

public func ckbAbcdeDevelopmentOptionsDiagnostic(options: CkbAbcdeRunnerOptions): String {
    if (!options.explicitRunMode) { return "" }
    if (options.runMode != "development" && options.runMode != "certification") { return "run_mode_invalid" }
    if (options.datasetVersion.trimAscii() == "" || options.knowledgeVersion.trimAscii() == "" || options.modelFingerprint.trimAscii() == "") { return "frozen_lineage_required" }
    if (options.claudeBin.trimAscii() == "") { return "claude_bin_required" }
    if (!options.claudeBin.startsWith("/")) { return "claude_bin_must_be_absolute" }
    if (options.groups.contains(CkbAbcdeGroups.C)) {
        if (options.ckbConfig.trimAscii() == "") { return "ckb_config_required" }
        if (!options.ckbConfig.startsWith("/")) { return "ckb_config_must_be_absolute" }
        if (!exists(Path(options.ckbConfig))) { return "ckb_config_not_found" }
    }
    if (options.runMode == "development" && options.candidateVersion.trimAscii() == "") { return "candidate_version_required" }
    if (options.runMode == "development" && options.expectedModelVersion != "GLM-5.2") { return "development_requires_glm_5_2" }
    if (options.runMode == "development" && ckbAbcdeModelEffortDiagnostic(options.modelEffort) != "ok") { return ckbAbcdeModelEffortDiagnostic(options.modelEffort) }
    if (options.runMode == "certification") {
        if (options.modelEffortExplicit || options.modelMaxBudgetUsdExplicit) { return "certification_forbids_development_transport_profile" }
        if (options.caseStart != 0 || options.caseEnd != 163) { return "certification_requires_full_164" }
        if (options.groups.size != 1 || options.groups[0] != CkbAbcdeGroups.D) { return "certification_requires_isolated_http_transport" }
        if (options.skipClaude || options.preflightOnly) { return "certification_requires_real_model_execution" }
        if (ckbCertificationBudgetDiagnostic(ckbAbcdeCertificationBudget(options)) != "ok") { return ckbCertificationBudgetDiagnostic(ckbAbcdeCertificationBudget(options)) }
        let authority = parseCangjieHumanEvalAuthorityManifest(ckbAbcdeReadText(options.manifestPath))
        let authorityDatasetDiagnostic = cangjieHumanEvalAuthorityDatasetDiagnostic(authority, options.datasetVersion)
        if (authorityDatasetDiagnostic == "authority_manifest_invalid") { return "certification_requires_authority_manifest" }
        if (authorityDatasetDiagnostic != "ok") { return authorityDatasetDiagnostic }
        if (options.certificationPreflightPath == "" || options.certificationRunManifestPath == "") { return "certification_requires_p6_artifacts" }
        if (options.expectedModelVersion == "") { return "certification_requires_exact_model_version" }
        if (!ckbAbcdeStrictSha256(options.providerIdentityHash)) { return "certification_requires_provider_identity_hash" }
        if(options.providerIdentityArtifactPath==""){return "certification_requires_provider_identity_artifact"}
        if(options.frozenCandidateManifestPath==""){return "certification_requires_frozen_candidate_manifest"}
    }
    ""
}

// Certification never falls through to the legacy development preflight. The
// trusted P6 artifacts are immutable inputs, while this run root must be fresh.
public func ckbAbcdeCertificationEntryDiagnostic(options: CkbAbcdeRunnerOptions, runRoot: String): String {
    if (options.runMode != "certification") { return "ok" }
    let authority = parseCangjieHumanEvalAuthorityManifest(ckbAbcdeReadText(options.manifestPath))
    if (!authority.ok || authority.rows.size != 164) { return "authority_manifest_invalid" }
    if (cangjieHumanEvalAuthorityDatasetDiagnostic(authority, options.datasetVersion) != "ok") { return "authority_dataset_version_mismatch" }
    if (options.certificationPreflightPath == "" || options.certificationRunManifestPath == "" || !exists(Path(options.certificationPreflightPath)) || !exists(Path(options.certificationRunManifestPath))) { return "p6_artifact_missing" }
    if(options.frozenCandidateManifestPath==""||!exists(Path(options.frozenCandidateManifestPath))){return "frozen_candidate_manifest_missing"}
    let frozen=ckbAbcdeReadText(options.frozenCandidateManifestPath);if(frozen==""||ckbFrozenCandidateManifestDiagnostic(FileKnowledgeStore(options.ckbStore),frozen)!="ok"){return "frozen_candidate_store_drift"}
    if(!exists(Path(options.providerIdentityArtifactPath))||benchmarkGapSha256(ckbAbcdeReadText(options.providerIdentityArtifactPath))!=options.providerIdentityHash){return "provider_identity_artifact_invalid"}
    let p6 = cangjieCertificationReleaseGateIntegrated(options.certificationPreflightPath, options.certificationRunManifestPath)
    if (!p6.ok) { return "p6_artifact_verification_failed" }
    try {
        let manifest = JsonValue.fromStr(ckbAbcdeReadText(options.certificationRunManifestPath)).asObject()
        if (ckbAbcdeStrictJsonString(manifest, "runId") != options.runId) { return "p6_run_identity_mismatch" }
        if (ckbAbcdeStrictJsonString(manifest, "fingerprint") != options.modelFingerprint) { return "p6_fingerprint_mismatch" }
        if (ckbAbcdeStrictJsonString(manifest,"providerIdentityHash")!=options.providerIdentityHash) { return "p6_provider_identity_mismatch" }
        if (ckbAbcdeStrictJsonString(manifest,"modelVersion")!=options.expectedModelVersion) { return "p6_model_identity_mismatch" }
        if (ckbAbcdeStrictJsonString(manifest,"certificationTransport")!=options.groups[0]) { return "p6_transport_mismatch" }
        if(ckbAbcdeStrictJsonInt(manifest,"transportRetryBudget",-1)!=options.transportRetries){return "p6_transport_retry_budget_mismatch"}
        if(ckbAbcdeStrictJsonInt(manifest,"modelTimeoutSeconds",-1)!=options.modelTimeoutSeconds){return "p6_model_timeout_mismatch"}
        let binaryHash=ckbAbcdeBinaryHash(options.ckbBin);let launchSpecHash=ckbAbcdeCertificationHttpLaunchSpecHash(binaryHash,options.ckbConfig,options.ckbStore,runRoot,options.ckbHttpBase);let commandHash=benchmarkGapSha256(ckbAbcdeCertificationHttpLaunchScript(options.ckbBin,options.ckbConfig,options.ckbStore,runRoot))
        if(ckbAbcdeStrictJsonString(manifest,"certificationBinaryHash")!=binaryHash||ckbAbcdeStrictJsonString(manifest,"certificationHttpLaunchSpecHash")!=launchSpecHash||ckbAbcdeStrictJsonString(manifest,"certificationHttpCommandHash")!=commandHash){return "p6_certification_http_provenance_mismatch"}
        if(ckbAbcdeStrictJsonString(manifest,"frozenCandidateManifestHash")!=benchmarkGapSha256(frozen)){return "p6_frozen_candidate_manifest_mismatch"}
        if (ckbAbcdeStrictJsonString(manifest,"claudeCodeVersion")!=ckbAbcdeClaudeVersion(executable: options.claudeBin)) { return "p6_claude_version_drift" }
        let provider=JsonValue.fromStr(ckbAbcdeReadText(options.providerIdentityArtifactPath)).asObject();if(ckbAbcdeStrictJsonString(provider,"model")!=options.expectedModelVersion||ckbAbcdeStrictJsonString(provider,"claudeCodeVersion")!=ckbAbcdeClaudeVersion(executable: options.claudeBin)||ckbAbcdeStrictJsonString(provider,"provider")==""){return "provider_runtime_identity_mismatch"}
    } catch (_: Exception) { return "p6_manifest_malformed" }
    if (!options.evaluateFrozen && exists(Path(runRoot))) {
        try { for (_ in Directory.readFrom(Path(runRoot))) { return "certification_run_root_not_empty" } }
        catch (_: Exception) { return "certification_run_root_unreadable" }
    }
    if(options.evaluateFrozen&&!exists(Path(runRoot))){return "frozen_run_root_missing"}
    "ok"
}

private func ckbAbcdeStrictJsonString(object: JsonObject, key: String): String {
    match (object.get(key)) { case Some(value) => value.asString().getValue(); case None => "" }
}
private func ckbAbcdeStrictJsonBool(object:JsonObject,key:String):Bool{match(object.get(key)){case Some(value)=>value.asBool().getValue();case None=>false}}
private func ckbAbcdeStrictJsonInt(object:JsonObject,key:String,fallback:Int64):Int64{match(object.get(key)){case Some(value)=>value.asInt().getValue();case None=>fallback}}
private func ckbAbcdeStrictSha256(value:String):Bool{let runes=value.toRuneArray();if(runes.size!=71||!value.startsWith("sha256:")){return false};for(i in 7..71){let c=runes[i];if(!((c>=r'0'&&c<=r'9')||(c>=r'a'&&c<=r'f'))){return false}};true}

public func ckbAbcdeFailureRoute(failureType: String): String {
    if (failureType == "knowledge_gap") { return "knowledge_candidate_pending_independent_triage" }
    if (failureType == "reasoning_error") { return "model_capability" }
    if (failureType == "dataset_defect") { return "dataset_repair" }
    if (failureType == "tool_failure" || failureType == "timeout" || failureType == "environment_failure") { return "infrastructure_repair" }
    if (failureType == "policy_violation") { return "policy_blocked" }
    if (failureType == "none") { return "closed" }
    "functional_repair"
}

public func ckbAbcdeIsolationDiagnostic(caseId: String, workspaceId: String, sessionId: String, runtimeHomeId: String, previousCaseId: String, previousWorkspaceId: String, previousSessionId: String, previousRuntimeHomeId: String): String {
    if (caseId.trimAscii() == "" || workspaceId.trimAscii() == "" || sessionId.trimAscii() == "" || runtimeHomeId.trimAscii() == "") { return "isolation_identity_required" }
    if (previousCaseId != "" && previousCaseId != caseId && (workspaceId == previousWorkspaceId || sessionId == previousSessionId || runtimeHomeId == previousRuntimeHomeId)) { return "cross_case_isolation_reuse" }
    ""
}

public func ckbAbcdeFailureTypeForTest(claudeExitCode: Int64, testExitCode: Int64, unitPass: Bool, violation: String, testLog: String, toolReady: Bool): String {
    ckbAbcdeFailureType(claudeExitCode, testExitCode, unitPass, violation, testLog, toolReady)
}

private func ckbAbcdeResultNotes(status: String, violation: String, toolEvidence: String): String {
    if (violation != "none") {
        return violation
    }
    if (toolEvidence == "manual_required") {
        return "tool evidence requires manual transcript review"
    }
    if (status == "failed") {
        return "see transcript and test log"
    }
    ""
}

private func ckbAbcdeClaudeVersion(executable!:String="claude"): String {
    let command=if(executable.trimAscii()==""){"claude"}else{ckbAbcdeShellQuote(executable)}
    let result = ckbAbcdeRunShell("${command} --version 2>/dev/null | head -n1", "")
    result.stdout.trimAscii()
}

public func ckbAbcdeClaudeVersionForTest(executable!:String="claude"): String { ckbAbcdeClaudeVersion(executable: executable) }

private func ckbAbcdeCountOccurrences(text: String, needle: String): Int64 {
    if (needle == "" || text.size < needle.size) {
        return 0
    }
    let parts = text.split(needle)
    if (parts.size <= 1) { 0 } else { parts.size - 1 }
}

private func ckbAbcdeJsonStringField(text: String, field: String): String {
    let marker = "\"${field}\":\""
    let parts = text.split(marker)
    if (parts.size <= 1) {
        return ""
    }
    let tail = parts[1]
    let values = tail.split("\"")
    if (values.size > 0) { values[0] } else { "" }
}

public func ckbAbcdeJsonStringFieldForTest(text: String, field: String): String {
    ckbAbcdeJsonStringField(text, field)
}

public func ckbAbcdeCountOccurrencesForTest(text: String, needle: String): Int64 {
    ckbAbcdeCountOccurrences(text, needle)
}

private func ckbAbcdeUnitPassAt1(unitPass: Bool, groupRoot: String): Bool {
    if (!unitPass) { return false }
    let attempts = ckbAbcdeReadText("${groupRoot}/claude-attempts.jsonl")
    if (attempts.contains("\"sampleAttempt\":")) { return ckbAbcdeSampleAttemptCount(groupRoot) == 1 }
    ckbAbcdeFirstClaudeAttemptExitCodeFromText(attempts) == 0
}

private func ckbAbcdeFirstClaudeAttemptExitCode(groupRoot: String): Int64 {
    ckbAbcdeFirstClaudeAttemptExitCodeFromText(ckbAbcdeReadText("${groupRoot}/claude-attempts.jsonl"))
}

private func ckbAbcdeClaudeAttemptCount(groupRoot: String): Int64 {
    var count: Int64 = 0
    for (line in ckbAbcdeReadText("${groupRoot}/claude-attempts.jsonl").split("\n")) {
        if (line.contains("\"attempt\":")) {
            count += 1
        }
    }
    count
}

private func ckbAbcdeSampleAttemptCount(groupRoot: String): Int64 {
    var count: Int64 = 0
    for (line in ckbAbcdeReadText("${groupRoot}/claude-attempts.jsonl").split("\n")) {
        if (ckbAbcdeJsonIntField(line, "sampleAttempt", 0) > count) { count = ckbAbcdeJsonIntField(line, "sampleAttempt", 0) }
    }
    count
}

private func ckbAbcdeSelectedSampleTransportAttempt(groupRoot:String):Int64{
    for(line in ckbAbcdeReadText("${groupRoot}/claude-attempts.jsonl").split("\n")){
        if(ckbAbcdeJsonIntField(line,"sampleAttempt",0)==1){return ckbAbcdeJsonIntField(line,"transportAttempt",ckbAbcdeJsonIntField(line,"attempt",0))}
    }
    0
}

private func ckbAbcdeAttemptSummaryJson(groupRoot:String):String{
    let attempts=ckbAbcdeReadText("${groupRoot}/claude-attempts.jsonl");let restores=ckbAbcdeReadText("${groupRoot}/workspace-restores.jsonl");let count=ckbAbcdeClaudeAttemptCount(groupRoot);let samples=ckbAbcdeSampleAttemptCount(groupRoot);let selected=ckbAbcdeSelectedSampleTransportAttempt(groupRoot)
    "{\"transportAttemptCount\":${count},\"sampleAttemptCount\":${samples},\"lastAuditedTransportAttempt\":${count},\"selectedBusinessSample\":${selected},\"selectedTransportAttempt\":${selected},\"retryCount\":${if(count>0){count-1}else{0}},\"unresolvedTransport\":${if(samples==1){0}else{1}},\"attemptLineageHash\":\"${ckbAbcdeAttemptLineageHash(attempts,restores)}\",\"workspaceRestoreEvidenceHash\":\"${ckbAbcdeJsonEscape(benchmarkGapSha256(restores))}\",\"attemptsPath\":\"claude-attempts.jsonl\",\"restoresPath\":\"workspace-restores.jsonl\"}"
}

public func ckbAbcdeAttemptArtifactsDiagnostic(groupRoot:String):String{
    let attempts=ckbAbcdeReadText("${groupRoot}/claude-attempts.jsonl");let restores=ckbAbcdeReadText("${groupRoot}/workspace-restores.jsonl");let count=ckbAbcdeClaudeAttemptCount(groupRoot);let samples=ckbAbcdeSampleAttemptCount(groupRoot);let lineage=ckbAbcdeAttemptLineageDiagnostic(attempts,restores,count,samples);if(lineage!="ok"){return lineage};let recomputed=ckbAbcdeAttemptArtifactRecomputeDiagnostic(groupRoot,attempts);if(recomputed!="ok"){return recomputed};let selected=ckbAbcdeSelectedSampleTransportAttempt(groupRoot);if((samples==1&&(selected<1||selected!=count))||(samples==0&&selected!=0)){return "selected_transport_attempt_invalid"}
    for(line in attempts.split("\n")){if(line.trimAscii()==""){continue};try{let row=JsonValue.fromStr(line).asObject();let attempt=ckbAbcdeStrictJsonInt(row,"transportAttempt",-1);let home="${groupRoot}/runtime-home/attempt-${attempt}";for(pair in [("sessionIdHash",benchmarkGapSha256(ckbAbcdeReadText("${groupRoot}/session-id.attempt-${attempt}.txt"))),("runtimeHomeId",benchmarkGapSha256(try{canonicalize(Path(home)).toString()}catch(_:Exception){home})),("sandboxProbeHash",benchmarkGapSha256(ckbAbcdeReadText("${groupRoot}/sandbox-probe.attempt-${attempt}.json"))),("transcriptHash",benchmarkGapSha256(ckbAbcdeReadText("${groupRoot}/claude-transcript.attempt-${attempt}.jsonl"))),("stderrHash",benchmarkGapSha256(ckbAbcdeReadTransportDiagnostic("${groupRoot}/claude.attempt-${attempt}.stderr.log"))),("diagnosticHash",benchmarkGapSha256(ckbAbcdeReadText("${groupRoot}/model-transport-diagnostic.attempt-${attempt}.json")))]){if(ckbAbcdeStrictJsonString(row,pair[0])!=pair[1]){return "transport_artifact_hash_mismatch"}}}catch(_:Exception){return "transport_lineage_malformed"}}
    let expected=ckbAbcdeAttemptSummaryJson(groupRoot);for(path in ["${groupRoot}/attempt-evidence.json","${groupRoot}/test-result.json"]){let raw=ckbAbcdeReadText(path);try{let actual=JsonValue.fromStr(raw).asObject();let summary=JsonValue.fromStr(expected).asObject();for(key in ["transportAttemptCount","sampleAttemptCount","selectedTransportAttempt","retryCount","unresolvedTransport"]){if(ckbAbcdeStrictJsonInt(actual,key,-1)!=ckbAbcdeStrictJsonInt(summary,key,-1)){return "attempt_summary_binding_mismatch"}};for(key in ["attemptLineageHash","workspaceRestoreEvidenceHash"]){if(ckbAbcdeStrictJsonString(actual,key)!=ckbAbcdeStrictJsonString(summary,key)){return "attempt_summary_binding_mismatch"}}}catch(_:Exception){return "attempt_summary_malformed"}}
    if(samples==1&&(benchmarkGapSha256(ckbAbcdeReadText("${groupRoot}/claude-transcript.jsonl"))!=benchmarkGapSha256(ckbAbcdeReadText("${groupRoot}/claude-transcript.attempt-${selected}.jsonl"))||benchmarkGapSha256(ckbAbcdeReadText("${groupRoot}/sandbox-probe.json"))!=benchmarkGapSha256(ckbAbcdeReadText("${groupRoot}/sandbox-probe.attempt-${selected}.json"))||benchmarkGapSha256(ckbAbcdeReadText("${groupRoot}/session-id.txt"))!=benchmarkGapSha256(ckbAbcdeReadText("${groupRoot}/session-id.attempt-${selected}.txt")))){return "selected_transport_artifact_mismatch"};"ok"
}

private func ckbAbcdeAttemptArtifactRecomputeDiagnostic(groupRoot:String,attempts:String):String{
    let policy=ckbAbcdeReadText("${groupRoot}/runtime-policy.json");var expected="";var timeout:Int64=-1;try{let object=JsonValue.fromStr(policy).asObject();expected=ckbAbcdeStrictJsonString(object,"model");timeout=ckbAbcdeStrictJsonInt(object,"modelTimeoutSeconds",-1)}catch(_:Exception){};if(expected==""){return "runtime_policy_model_missing"};if(timeout<=0){return "runtime_policy_timeout_missing"}
    for(line in attempts.split("\n")){if(line.trimAscii()==""){continue};try{let row=JsonValue.fromStr(line).asObject();if(ckbAbcdeStrictJsonInt(row,"modelTimeoutSeconds",-1)!=timeout){return "transport_timeout_policy_mismatch"};let attempt=ckbAbcdeStrictJsonInt(row,"transportAttempt",-1);let transcriptRead=ckbAbcdeReadBoundedText("${groupRoot}/claude-transcript.attempt-${attempt}.jsonl",CKB_ABCDE_MAX_MODEL_TRANSCRIPT_BYTES,"transcript_too_large");if(!transcriptRead.ok){return transcriptRead.diagnostic};let stderrRead=ckbAbcdeReadBoundedText("${groupRoot}/claude.attempt-${attempt}.stderr.log",65536,"diagnostic_too_large");if(!stderrRead.ok){return stderrRead.diagnostic};let assessment=ckbAbcdeAssessSample(transcriptRead.text,expected);let exitCode=ckbAbcdeStrictJsonInt(row,"exitCode",-1);let classification=ckbAbcdeTransportClassification(exitCode,assessment,stderrRead.text);let sample=if(exitCode==0){assessment.sampleAttempt}else{0};if(ckbAbcdeStrictJsonString(row,"classification")!=classification||ckbAbcdeStrictJsonBool(row,"completeResult")!=assessment.completeResult||ckbAbcdeStrictJsonBool(row,"identityMatched")!=assessment.identityMatched||ckbAbcdeStrictJsonInt(row,"sampleAttempt",-1)!=sample){return "transport_attempt_recompute_mismatch"}}catch(_:Exception){return "transport_lineage_malformed"}};"ok"
}

private func ckbAbcdeAgentRetryCount(attempts:String,transportAttemptCount:Int64,sampleAttemptCount:Int64):Int64{
    if(attempts.contains("\"sampleAttempt\":")){if(sampleAttemptCount>1){sampleAttemptCount-1}else{0}}
    else if(transportAttemptCount>1){transportAttemptCount-1}else{0}
}

private func ckbAbcdeBusinessRetryUsed(attempts:String,transportAttemptCount:Int64,sampleAttemptCount:Int64):Bool{
    attempts.contains("\"retryUsed\":true")||if(attempts.contains("\"sampleAttempt\":")){sampleAttemptCount>1}else{transportAttemptCount!=1}
}

public func ckbAbcdeAgentRetryCountFromAttemptsForTest(attempts:String):Int64{
    var transport:Int64=0;var samples:Int64=0;for(line in attempts.split("\n")){if(line.contains("\"attempt\":")){transport+=1};let sample=ckbAbcdeJsonIntField(line,"sampleAttempt",0);if(sample>samples){samples=sample}}
    ckbAbcdeAgentRetryCount(attempts,transport,samples)
}

public func ckbAbcdeBusinessRetryUsedFromAttemptsForTest(attempts:String):Bool{
    var transport:Int64=0;var samples:Int64=0;for(line in attempts.split("\n")){if(line.contains("\"attempt\":")){transport+=1};let sample=ckbAbcdeJsonIntField(line,"sampleAttempt",0);if(sample>samples){samples=sample}}
    ckbAbcdeBusinessRetryUsed(attempts,transport,samples)
}

private func ckbAbcdeWorkspaceRestoreEvidenceHash(groupRoot: String): String {
    let evidence = ckbAbcdeReadText("${groupRoot}/workspace-restores.jsonl")
    if (evidence == "") { "" } else { benchmarkGapSha256(evidence) }
}

private func ckbAbcdeFirstClaudeAttemptExitCodeFromText(attempts: String): Int64 {
    for (line in attempts.split("\n")) {
        if (line.contains("\"attempt\":1")) {
            return ckbAbcdeJsonIntField(line, "exitCode", -1)
        }
    }
    -1
}

private func ckbAbcdeJsonIntField(text: String, field: String, fallback: Int64): Int64 {
    let parts = text.split("\"${field}\":")
    if (parts.size <= 1) {
        return fallback
    }
    var raw = parts[1]
    let commaParts = raw.split(",")
    if (commaParts.size > 0) {
        raw = commaParts[0]
    }
    let braceParts = raw.split("}")
    if (braceParts.size > 0) {
        raw = braceParts[0]
    }
    ckbAbcdeParseInt(raw.trimAscii(), fallback)
}

private func ckbAbcdeParseClaudeUsageFile(path: String): CkbAbcdeUsageStats {
    ckbAbcdeParseClaudeUsageFromText(ckbAbcdeReadText(path), path)
}

public func ckbAbcdeParseClaudeUsageFromText(transcript: String, sourcePath: String): CkbAbcdeUsageStats {
    let stats = CkbAbcdeUsageStats()
    stats.usageSourcePath = sourcePath
    var resultLine = ""
    for (line in transcript.split("\n")) {
        if (ckbAbcdeTranscriptLineIsResult(line)) {
            resultLine = line
        }
    }
    if (resultLine == "") {
        stats.usageParseStatus = "missing_result"
        return stats
    }

    let inputTokens = ckbAbcdeJsonIntFieldAny(resultLine, "input_tokens", "inputTokens", "modelInputTokens", -1)
    let outputTokens = ckbAbcdeJsonIntFieldAny(resultLine, "output_tokens", "outputTokens", "modelOutputTokens", -1)
    let cacheReadTokens = ckbAbcdeJsonIntFieldAny(resultLine, "cache_read_input_tokens", "cacheReadInputTokens", "modelCacheReadTokens", 0)
    let cacheCreationTokens = ckbAbcdeJsonIntFieldAny(resultLine, "cache_creation_input_tokens", "cacheCreationInputTokens", "modelCacheCreationTokens", 0)
    let explicitTotal = ckbAbcdeJsonIntFieldAny(resultLine, "total_tokens", "totalTokens", "modelTotalTokens", -1)
    let turns = ckbAbcdeJsonIntFieldAny(resultLine, "num_turns", "numTurns", "llmTurnCount", -1)

    let computedTotal = ckbAbcdeNonNegative(inputTokens) + ckbAbcdeNonNegative(outputTokens) + cacheReadTokens + cacheCreationTokens
    let total = if (explicitTotal >= 0) { explicitTotal } else { computedTotal }
    if (turns < 0 || total <= 0 || inputTokens < 0 || outputTokens < 0) {
        stats.usageParseStatus = "missing_usage"
        return stats
    }

    stats.usageParseStatus = "ok"
    stats.modelInputTokens = inputTokens
    stats.modelOutputTokens = outputTokens
    stats.modelCacheReadTokens = cacheReadTokens
    stats.modelCacheCreationTokens = cacheCreationTokens
    stats.modelTotalTokens = total
    stats.llmTurnCount = turns
    stats
}

public func ckbAbcdeRenderUsageJson(stats: CkbAbcdeUsageStats): String {
    "{\"usageParseStatus\":\"${stats.usageParseStatus}\",\"modelInputTokens\":${stats.modelInputTokens},\"modelOutputTokens\":${stats.modelOutputTokens},\"modelCacheReadTokens\":${stats.modelCacheReadTokens},\"modelCacheCreationTokens\":${stats.modelCacheCreationTokens},\"modelTotalTokens\":${stats.modelTotalTokens},\"llmTurnCount\":${stats.llmTurnCount},\"usageSourcePath\":\"${ckbAbcdeJsonEscape(stats.usageSourcePath)}\"}"
}

private func ckbAbcdeTranscriptLineIsResult(line: String): Bool {
    (line.contains("\"type\":\"result\"") || line.contains("\"type\": \"result\"")) &&
        !line.contains("\"subtype\":\"init\"")
}

private func ckbAbcdeJsonIntFieldAny(text: String, fieldA: String, fieldB: String, fieldC: String, fallback: Int64): Int64 {
    let a = ckbAbcdeJsonIntField(text, fieldA, fallback)
    if (a != fallback) {
        return a
    }
    let b = ckbAbcdeJsonIntField(text, fieldB, fallback)
    if (b != fallback) {
        return b
    }
    ckbAbcdeJsonIntField(text, fieldC, fallback)
}

private func ckbAbcdeNonNegative(value: Int64): Int64 {
    if (value < 0) { 0 } else { value }
}

private func ckbAbcdeAverageText(total: Int64, count: Int64): String {
    if (count <= 0) {
        return "null"
    }
    let whole = total / count
    let remainder = total % count
    if (remainder == 0) {
        return "${whole}"
    }
    let tenth = (remainder * 10) / count
    "${whole}.${tenth}"
}

public func ckbAbcdeAverageTextForTest(total: Int64, count: Int64): String {
    ckbAbcdeAverageText(total, count)
}

public func ckbAbcdeUnitPassAt1FromAttemptsForTest(unitPass: Bool, attempts: String): Bool {
    if (!unitPass) { return false }
    for (line in attempts.split("\n")) {
        if (ckbAbcdeJsonIntField(line, "sampleAttempt", 0) == 1) { return true }
    }
    // Compatibility for historical artifacts written before sampleAttempt existed.
    ckbAbcdeFirstClaudeAttemptExitCodeFromText(attempts) == 0
}

private func ckbAbcdeTestLogContainsFailure(testLog: String): Bool {
    testLog.contains("CangjieEval failure") ||
        testLog.contains("An exception has occurred") ||
        testLog.contains("FAILED") ||
        testLog.contains("Error: cjpm run failed")
}

private func ckbAbcdeForbiddenEvidence(group: String, transcript: String, workspaceRoot: String): String {
    let lowered = transcript.toAsciiLower()
    let runtimeHomeAccess = ckbAbcdeDefaultRuntimeHomeAccessEvidence(transcript)
    if (runtimeHomeAccess != "none") { return runtimeHomeAccess }
    let broadScan = ckbAbcdeBroadFilesystemScanEvidence(group, transcript, workspaceRoot)
    if (broadScan != "none") { return broadScan }
    let workspaceMutation = ckbAbcdeForbiddenWorkspaceMutationEvidence(transcript)
    if (workspaceMutation != "none") { return workspaceMutation }
    if (group == CkbAbcdeGroups.A && (lowered.contains("cangjie_knowledge_pack") || lowered.contains("cangjie_task_knowledge_pack") || lowered.contains("/v1/cangjie") || lowered.contains("cangjie_docs-release"))) {
        return "forbidden_knowledge_entry"
    }
    if (group == CkbAbcdeGroups.B && (lowered.contains("mcp__") || lowered.contains("cangjie_docs-release"))) {
        return "forbidden_tool_or_docs_entry"
    }
    if ((group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D) && lowered.contains("cangjie_docs-release")) {
        return "forbidden_local_docs_entry"
    }
    if (group == CkbAbcdeGroups.E && (lowered.contains("mcp__") || lowered.contains("/v1/cangjie"))) {
        return "forbidden_ckb_entry"
    }
    if (group == CkbAbcdeGroups.E) {
        let eViolation = ckbAbcdeForbiddenLocalDocsEvidence(transcript)
        if (eViolation != "none") {
            return eViolation
        }
    }
    "none"
}

private func ckbAbcdeBroadFilesystemScanEvidence(group: String, transcript: String, workspaceRoot: String): String {
    for (line in transcript.split("\n")) {
        try {
            let event = JsonValue.fromStr(line).asObject()
            if (ckbAbcdeStrictJsonString(event, "type") != "assistant") { continue }
            let content = event.get("message").getOrThrow().asObject().get("content").getOrThrow().asArray().getItems()
            for (value in content) {
                let entry = value.asObject()
                if (ckbAbcdeStrictJsonString(entry, "type") != "tool_use" || ckbAbcdeStrictJsonString(entry, "name") != "Bash") { continue }
                let command = ckbAbcdeStrictJsonString(entry.get("input").getOrThrow().asObject(), "command")
                if (ckbAbcdeFindCommandEscapesWorkspace(group, command, workspaceRoot)) { return "broad_filesystem_scan" }
            }
        } catch (_: Exception) {}
    }
    "none"
}

private func ckbAbcdeFindCommandEscapesWorkspace(group: String, command: String, workspaceRoot: String): Bool {
    let tokens = ckbAbcdeShellAuditTokens(command)
    for (i in 0..tokens.size) {
        let executable = tokens[i].toAsciiLower()
        if (!(executable == "find" || executable.endsWith("/find"))) { continue }
        if (command.contains("$") || command.contains("`")) { return true }
        var targetCount: Int64 = 0
        var target = ""
        for (j in (i + 1)..tokens.size) {
            let token = tokens[j]
            if (ckbAbcdeShellAuditBoundary(token) || token.startsWith("-")) { break }
            targetCount += 1
            target = token
        }
        if (targetCount != 1 || !ckbAbcdeFindTargetInsideWorkspace(group, target, workspaceRoot)) { return true }
        if (!target.startsWith("/") && command.contains("cd ") && !command.contains(workspaceRoot)) { return true }
    }
    false
}

private func ckbAbcdeFindTargetInsideWorkspace(group: String, target: String, workspaceRoot: String): Bool {
    let normalizedTarget = ckbAbcdeTrimTrailingPathSeparators(target.trimAscii())
    if (normalizedTarget == "" || ckbAbcdePathHasParentSegment(normalizedTarget)) { return false }
    if (normalizedTarget == "." || normalizedTarget.startsWith("./")) { return true }
    if (!normalizedTarget.startsWith("/")) { return true }
    let canonicalWorkspace = try { canonicalize(Path(workspaceRoot)).toString() } catch (_: Exception) { workspaceRoot }
    let normalizedWorkspace = ckbAbcdeTrimTrailingPathSeparators(canonicalWorkspace)
    if (normalizedWorkspace != "" && (normalizedTarget == normalizedWorkspace || normalizedTarget.startsWith("${normalizedWorkspace}/"))) { return true }
    group == CkbAbcdeGroups.E && (normalizedTarget.endsWith("/cangjie_docs-release-1.0/docs") || normalizedTarget.contains("/cangjie_docs-release-1.0/docs/"))
}

private func ckbAbcdePathHasParentSegment(path: String): Bool {
    for (segment in path.split("/")) { if (segment == "..") { return true } }
    false
}

private func ckbAbcdeTrimTrailingPathSeparators(path: String): String {
    let runes = path.toRuneArray()
    var end = runes.size
    while (end > 1 && runes[end - 1] == r'/') { end -= 1 }
    let out = StringBuilder()
    for (i in 0..end) { out.append(runes[i]) }
    out.toString()
}

private func ckbAbcdeShellAuditBoundary(token: String): Bool {
    token == ";" || token == "|" || token == "&" || token == "<" || token == ">"
}

private func ckbAbcdeShellAuditTokens(command: String): ArrayList<String> {
    let tokens = ArrayList<String>()
    var current = StringBuilder()
    var quoteMarker: Rune = r'\u{0}'
    var escaped = false
    for (rune in command.toRuneArray()) {
        if (escaped) { current.append(rune); escaped = false; continue }
        if (rune == r'\\') { escaped = true; continue }
        if (quoteMarker != r'\u{0}') {
            if (rune == quoteMarker) { quoteMarker = r'\u{0}' } else { current.append(rune) }
            continue
        }
        if (rune == r'\'' || rune == r'"') { quoteMarker = rune; continue }
        if (rune == r' ' || rune == r'\t' || rune == r'\n' || rune == r'\r') {
            if (current.toString() != "") { tokens.add(current.toString()); current = StringBuilder() }
            continue
        }
        if (rune == r';' || rune == r'|' || rune == r'&' || rune == r'<' || rune == r'>') {
            if (current.toString() != "") { tokens.add(current.toString()); current = StringBuilder() }
            tokens.add(rune.toString())
            continue
        }
        current.append(rune)
    }
    if (escaped || quoteMarker != r'\u{0}') { tokens.add("$") }
    if (current.toString() != "") { tokens.add(current.toString()) }
    tokens
}

private func ckbAbcdeDefaultRuntimeHomeAccessEvidence(transcript:String):String{
    for(line in transcript.split("\n")){
        try{
            let event=JsonValue.fromStr(line).asObject();if(ckbAbcdeStrictJsonString(event,"type")!="assistant"){continue}
            let content=event.get("message").getOrThrow().asObject().get("content").getOrThrow().asArray().getItems()
            for(value in content){let entry=value.asObject();if(ckbAbcdeStrictJsonString(entry,"type")!="tool_use"){continue};let input=entry.get("input").getOrThrow().asObject();let path=ckbAbcdeStrictJsonString(input,"file_path").toAsciiLower();let command=ckbAbcdeStrictJsonString(input,"command").toAsciiLower();if(path.contains("/.claude/")||path.endsWith("/.claude")||command.contains("/.claude/")||command.contains("~/.claude")){return "default_runtime_home_access"}}
        }catch(_:Exception){}
    }
    "none"
}

private func ckbAbcdeForbiddenWorkspaceMutationEvidence(transcript: String): String {
    for (line in transcript.split("\n")) {
        try {
            let event = JsonValue.fromStr(line).asObject()
            if (ckbAbcdeStrictJsonString(event, "type") != "assistant") { continue }
            let message = event.get("message").getOrThrow().asObject()
            let content = message.get("content").getOrThrow().asArray().getItems()
            for (entryValue in content) {
                let entry = entryValue.asObject()
                if (ckbAbcdeStrictJsonString(entry, "type") != "tool_use") { continue }
                let name = ckbAbcdeStrictJsonString(entry, "name").toAsciiLower()
                let input = entry.get("input").getOrThrow().asObject()
                if (name == "write" || name == "edit") {
                    let path = ckbAbcdeStrictJsonString(input, "file_path")
                    if (!(path == "src/solution.cj" || path == "./src/solution.cj" || path.endsWith("/src/solution.cj"))) {
                        return "forbidden_workspace_mutation"
                    }
                } else if (name == "bash") {
                    let command = ckbAbcdeStrictJsonString(input, "command").toAsciiLower()
                    let protectedPath = command.contains("src/main.cj") || command.contains("cjpm.toml") || command.contains("/test/") || command.contains("/tests/")
                    let redirectedWriter = ckbAbcdeRedirectsProtectedWorkspacePath(command)
                    let directMutation = command.contains("sed -i") || command.contains("rm ") || command.contains("mv ") ||
                        command.contains("cp ") || command.contains("touch ") || command.contains("mkdir ") || command.contains("tee ") ||
                        command.contains("python") || command.contains("perl ") || command.contains("apply_patch") ||
                        command.contains("truncate ") || command.contains("install ") || command.contains("chmod ") || command.contains("dd ")
                    if (protectedPath && (redirectedWriter || directMutation)) { return "forbidden_workspace_mutation" }
                }
            }
        } catch (_: Exception) {}
    }
    "none"
}

private func ckbAbcdeRedirectsProtectedWorkspacePath(command: String): Bool {
    let parts = command.split(">")
    for (i in 1..parts.size) {
        var target = parts[i].trimAscii()
        for (separator in [" ", "\t", "\n", ";", "&", "|"]) {
            let tokens = target.split(separator)
            if (tokens.size > 0) { target = tokens[0] }
        }
        target = ckbAbcdeUnquoteShellToken(target)
        if (target == "src/main.cj" || target == "cjpm.toml" || target.endsWith("/src/main.cj") || target.endsWith("/cjpm.toml") ||
            target.contains("/test/") || target.contains("/tests/")) { return true }
    }
    false
}

private func ckbAbcdeUnquoteShellToken(token: String): String {
    let runes = token.toRuneArray()
    if (runes.size < 2 || !((runes[0] == r'\'' && runes[runes.size - 1] == r'\'') ||
        (runes[0] == r'"' && runes[runes.size - 1] == r'"'))) { return token }
    let out = StringBuilder()
    for (i in 1..(runes.size - 1)) { out.append(runes[i]) }
    out.toString()
}

public func ckbAbcdeForbiddenEvidenceForTest(group: String, transcript: String): String {
    ckbAbcdeForbiddenEvidence(group, transcript, "")
}

public func ckbAbcdeForbiddenEvidenceForWorkspaceForTest(group: String, transcript: String, workspaceRoot: String): String {
    ckbAbcdeForbiddenEvidence(group, transcript, workspaceRoot)
}

private func ckbAbcdeForbiddenLocalDocsEvidence(transcript: String): String {
    for (line in transcript.split("\n")) {
        let lowered = line.toAsciiLower()
        if (lowered.contains("\"type\":\"tool_use\"") &&
            (lowered.contains("\"name\":\"webfetch\"") || lowered.contains("\"name\":\"websearch\"") ||
             lowered.contains("\"name\":\"task\"") || lowered.contains("\"name\":\"askuserquestion\""))) {
            return "forbidden_e_tool_use"
        }
    }
    "none"
}

private func ckbAbcdeRunShell(script: String, cwd: String): CkbAbcdeCommandResult {
    let result = CkbAbcdeCommandResult()
    let finalScript = if (cwd == "") { script } else { "cd ${ckbAbcdeShellQuote(cwd)} && ${script}" }
    try {
        let process = launch("/bin/zsh", ["-lc", finalScript], stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
        result.stdout = ckbAbcdeSafeReadPipe(process.stdOutPipe)
        result.stderr = ckbAbcdeSafeReadPipe(process.stdErrPipe)
        result.exitCode = process.wait()
    } catch (e: Exception) {
        result.exitCode = 127
        result.stderr = "launch_failed"
    }
    result
}

private func ckbAbcdeSafeReadPipe(pipe: InputStream): String {
    try {
        StringReader<InputStream>(pipe).readToEnd()
    } catch (_: Exception) {
        "invalid_response_encoding"
    }
}

private func ckbAbcdeReadText(path: String): String {
    try {
        String.fromUtf8(File.readFrom(Path(path)))
    } catch (_: Exception) {
        ""
    }
}

private func ckbAbcdeReadTransportDiagnostic(path:String):String{
    let result=ckbAbcdeReadBoundedText(path,65536,"diagnostic_too_large");if(result.ok){result.text}else{result.diagnostic}
}

public func ckbAbcdeReadBoundedText(path:String,maxBytes:Int64,oversizeDiagnostic:String):CkbAbcdeBoundedTextRead{
    let result=CkbAbcdeBoundedTextRead();try{let bytes=File.readFrom(Path(path));if(bytes.size>maxBytes){result.diagnostic=oversizeDiagnostic;return result};try{result.text=String.fromUtf8(bytes);result.contentHash=benchmarkGapSha256(result.text);result.ok=true;result.diagnostic="ok"}catch(_:Exception){result.diagnostic="invalid_response_encoding"}}catch(_:Exception){result.diagnostic="artifact_read_failed"};result
}
private func ckbAbcdeReplaceUnsafeArtifact(path:String,safe:String):Unit{try{_=launch("/bin/rm",["-f",path]).wait()}catch(_:Exception){};ckbAbcdeWriteText(path,safe)}
public func ckbAbcdeSanitizeTranscriptArtifact(path:String,runtimePath:String):CkbAbcdeBoundedTextRead{let result=ckbAbcdeReadBoundedText(path,CKB_ABCDE_MAX_MODEL_TRANSCRIPT_BYTES,"transcript_too_large");if(!result.ok){ckbAbcdeReplaceUnsafeArtifact(path,"");if(runtimePath!=""){try{_=launch("/bin/rm",["-f",runtimePath]).wait()}catch(_:Exception){}}};result}
private func ckbAbcdeRedactStderrHeaders(text:String):String{let safe=StringBuilder();for(line in text.split("\n")){if(line.toAsciiLower().contains("authorization:")){safe.append("[REDACTED_HEADER]")}else{safe.append(line)};safe.append("\n")};safe.toString()}
public func ckbAbcdeSanitizeStderrArtifact(path:String,runtimePath:String):CkbAbcdeBoundedTextRead{let result=ckbAbcdeReadBoundedText(path,65536,"diagnostic_too_large");let safe=if(result.ok){utf8SafePrefix(redactSensitive(ckbAbcdeRedactStderrHeaders(result.text)),8192)}else{result.diagnostic};ckbAbcdeReplaceUnsafeArtifact(path,safe);if(runtimePath!=""){try{_=launch("/bin/rm",["-f",runtimePath]).wait()}catch(_:Exception){}};if(result.ok){result.text=safe};result}

private func ckbAbcdeWriteText(path: String, text: String): Unit {
    let target = Path(path)
    if (!exists(target.parent)) {
        Directory.create(target.parent, recursive: true)
    }
    File.writeTo(target, text.toArray())
}

private func ckbAbcdeAppendText(path: String, text: String): Unit {
    let existing = if (exists(Path(path))) { ckbAbcdeReadText(path) } else { "" }
    ckbAbcdeWriteText(path, existing + text)
}

private func ckbAbcdeEnsureDir(path: String): Unit {
    if (!exists(Path(path))) {
        Directory.create(Path(path), recursive: true)
    }
}

private func ckbAbcdeCaseLayoutOk(datasetRoot: String): Bool {
    for (i in 0..164) {
        let caseRoot = "${datasetRoot}/${ckbAbcdeCaseId(i)}"
        if (!exists(Path("${caseRoot}/metadata.json")) ||
            !exists(Path("${caseRoot}/prompt.md")) ||
            !exists(Path("${caseRoot}/starter/cjpm.toml")) ||
            !exists(Path("${caseRoot}/starter/src/solution.cj")) ||
            !exists(Path("${caseRoot}/starter/src/eval_support.cj")) ||
            !exists(Path("${caseRoot}/tests/TestMain.cj")) ||
            !exists(Path("${caseRoot}/tests/cjpm.executable.toml"))) {
            return false
        }
    }
    true
}

private func ckbAbcdeManifestLineCount(path: String): Int64 {
    var count: Int64 = 0
    for (line in ckbAbcdeReadText(path).split("\n")) {
        if (line.trimAscii() != "") {
            count += 1
        }
    }
    count
}

private func ckbAbcdeClaudeSettingsLooksGlm52(): Bool {
    let home = match (getVariable("HOME")) {
        case Some(value) => value
        case None => ""
    }
    if (home == "") {
        return false
    }
    let text = ckbAbcdeReadText("${home}/.claude/settings.json")
    text.contains("GLM-5.2") &&
        text.contains("ANTHROPIC_MODEL") &&
        text.contains("ANTHROPIC_DEFAULT_OPUS_MODEL") &&
        text.contains("ANTHROPIC_DEFAULT_SONNET_MODEL") &&
        text.contains("ANTHROPIC_DEFAULT_HAIKU_MODEL") &&
        text.contains("CLAUDE_CODE_SUBAGENT_MODEL")
}

private func ckbAbcdeGeneratedRunId(): String {
    let result = ckbAbcdeRunShell("date +%Y%m%d-%H%M%S", "")
    let value = result.stdout.trimAscii()
    if (value == "") { "manual" } else { value }
}

private func ckbAbcdeDefaultRepoRoot(): String {
    match (getVariable("CKB_REPO_ROOT")) {
        case Some(value) => value
        case None => "/Users/l3gi0n/work/workspace_cangjie/CangjieCommunityKnowledgeBase"
    }
}

public func ckbAbcdeOptionsSafetyDiagnostic(options: CkbAbcdeRunnerOptions): String {
    if (options.runsRoot != "/Users/l3gi0n/Downloads/ckbtest") {
        let repo=try{canonicalize(Path(options.repoRoot)).toString()}catch(_:Exception){return "repo_root_invalid"}
        let runs=try{canonicalize(Path(options.runsRoot)).toString()}catch(_:Exception){return "runs_root_invalid"}
        if(options.runsRoot!=runs||!runs.startsWith(repo+"/target/certification-")||Path(runs).parent.toString()!=repo+"/target"){return "runs_root_outside_allowed_root"}
    }
    if (!ckbAbcdeSafePathSegment(options.runId)) {
        return "unsafe_run_id"
    }
    if (options.caseStart < 0 || options.caseEnd > 163 || options.caseStart > options.caseEnd) {
        return "case_range_must_be_0_163"
    }
    if (options.groups.size == 0) {
        return "groups_must_not_be_empty"
    }
    if (!options.ckbHttpBase.startsWith("http://127.0.0.1:") && !options.ckbHttpBase.startsWith("http://localhost:")) {
        return "ckb_http_base_must_be_loopback_http"
    }
    "ok"
}

private func ckbAbcdeSafePathSegment(value: String): Bool {
    let trimmed = value.trimAscii()
    if (trimmed == "" || trimmed == "." || trimmed == "..") {
        return false
    }
    if (trimmed.contains("/") || trimmed.contains("\\") || trimmed.contains("..") ||
        trimmed.contains("$") || trimmed.contains("'") || trimmed.contains("\"") ||
        trimmed.contains("`") || trimmed.contains("\n") || trimmed.contains("\r")) {
        return false
    }
    true
}

private func ckbAbcdeParseInt(value: String, fallback: Int64): Int64 {
    try {
        Int64.parse(value)
    } catch (_: Exception) {
        fallback
    }
}

private func ckbAbcdeParseCaseIndex(value: String): Int64 {
    let trimmed = value.trimAscii()
    if (trimmed.startsWith("CJ-HUMANEVAL-")) {
        return ckbAbcdeParseInt(trimmed.replace("CJ-HUMANEVAL-", ""), 0)
    }
    ckbAbcdeParseInt(trimmed, 0)
}

private func ckbAbcdeParseGroups(value: String): ArrayList<String> {
    let groups = ArrayList<String>()
    for (raw in value.split(",")) {
        let item = raw.trimAscii()
        let group = if (item == "A" || item == CkbAbcdeGroups.A) {
            CkbAbcdeGroups.A
        } else if (item == "B" || item == CkbAbcdeGroups.B) {
            CkbAbcdeGroups.B
        } else if (item == "C" || item == CkbAbcdeGroups.C) {
            CkbAbcdeGroups.C
        } else if (item == "D" || item == CkbAbcdeGroups.D) {
            CkbAbcdeGroups.D
        } else if (item == "E" || item == CkbAbcdeGroups.E) {
            CkbAbcdeGroups.E
        } else {
            ""
        }
        if (group != "") {
            groups.add(group)
        }
    }
    groups
}

private func ckbAbcdeCaseId(index: Int64): String {
    if (index < 10) {
        return "CJ-HUMANEVAL-00${index}"
    }
    if (index < 100) {
        return "CJ-HUMANEVAL-0${index}"
    }
    "CJ-HUMANEVAL-${index}"
}

private func ckbAbcdeShellQuote(value: String): String {
    "'" + value.replace("'", "'\\''") + "'"
}

public func ckbAbcdeNativeTlsBootstrapScript(command: String, args: Array<String>): String {
    var script = "export cjHeapSize=4GB; " +
        "export CKB_NATIVE_TLS_BOOTSTRAPPED=1; " +
        "MAGIC_ROOT=\"" + "$" + "{MAGIC_PATH:-}\"; " +
        "if [ -z \"" + "$" + "{MAGIC_ROOT}\" ]; then MAGIC_ROOT=\"" + "$" + "{CKB_MAGIC_ROOT:-}\"; fi; " +
        "CANGJIE_ROOT=\"" + "$" + "{CANGJIE_HOME:-}\"; " +
        "if [ -z \"" + "$" + "{CANGJIE_ROOT}\" ]; then CANGJIE_ROOT=\"" + "$" + "{CKB_CANGJIE_ROOT:-}\"; fi; " +
        "CKB_DYLD_EXTRA=\"/opt/homebrew/opt/openssl@3/lib:/opt/homebrew/opt/openssl@3.5/lib:/usr/local/opt/openssl@3/lib\"; " +
        "if [ -n \"" + "$" + "{CANGJIE_ROOT}\" ]; then CKB_DYLD_EXTRA=\"" + "$" + "{CKB_DYLD_EXTRA}:" + "$" + "{CANGJIE_ROOT}/runtime/lib/darwin_aarch64_llvm\"; fi; " +
        "if [ -n \"" + "$" + "{MAGIC_ROOT}\" ]; then CKB_DYLD_EXTRA=\"" + "$" + "{CKB_DYLD_EXTRA}:" + "$" + "{MAGIC_ROOT}/libs/cangjie-stdx-mac-aarch64-1.0.0.1/darwin_aarch64_llvm/dynamic/stdx\"; fi; " +
        "export DYLD_LIBRARY_PATH=\"" +
        "$" + "{CKB_DYLD_EXTRA}:" +
        "$" + "{DYLD_LIBRARY_PATH}\"; " +
        "exec " + ckbAbcdeShellQuote(command)
    for (arg in args) {
        script += " " + ckbAbcdeShellQuote(arg)
    }
    script
}

private func ckbAbcdeUsage(): String {
    "Usage: cangjie_community_knowledge_base cangjie-eval-abcde --run-mode <development|certification> --run-id <id> --dataset-version <version> --knowledge-version <version> --model-fingerprint <sha256> --claude-bin <absolute-executable> --config <runtime.conf> [--candidate-version <version>] [--model-timeout-seconds <1..3600, default 180>] [--model-effort <low|medium|high|xhigh|max> --model-max-budget-usd <positive>] [--case-id CJ-HUMANEVAL-000|--case-start 0 --case-end 163] [--groups C|D] [--runs-root <path>] [--ckb-http-base <url>] [--ckb-bin <path>] [--ckb-store <path>] [--dataset-root <path>] [--manifest <authority.jsonl>] [--docs-root <path>] [--certification-preflight <preflight.json> --certification-run-manifest <run-manifest.json> --expected-model-version <exact> --provider-identity-hash <sha256> --provider-identity-artifact <redacted.json>]\n"
}
