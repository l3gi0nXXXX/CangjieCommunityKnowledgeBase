package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashSet}
import std.fs.{Directory, File, FileInfo, Path, canonicalize, exists, remove}
import std.process.launch
import std.time.DateTime
import std.unittest.*
import std.unittest.testmacro.*
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

@Test
public class CangjieAgentsSkillsRagE2eTest {
    @TestCase
    public func syntheticStudentContextImportPass(): Unit {
        @Expect(s5cSourceGoldenDiagnostic(), "ok")
        let seeded = s4PublishedStudentContext("s5c-import-seed")
        @Expect(seeded != "", true)
        if (seeded == "") { return }
        let root = Path(seeded).parent
        let output = root.join("explicit-scaffold-import")
        @Expect(runStudentContextImportCli(s5cImportArgs(root, root.join("candidate-set-v2"),
            root.join("approval-v2.json"), output, true)), 0)
        let context = readStudentContextBundleV2(output.toString())
        @Expect(context.ok, true)
        @Expect(ckbS4PreflightBindingDiagnostic("scaffold", context.compositeHash,
            context.combinationAuditHash, 0), "ok")
        let realOutput = root.join("default-real-import-must-not-publish")
        @Expect(runStudentContextImportCli(s5cImportArgs(root, root.join("candidate-set-v2"),
            root.join("approval-v2.json"), realOutput, false)), 1)
        @Expect(exists(realOutput), false)
    }

    @TestCase
    public func syntheticFailureAssetsBoundaryIsolationPass(): Unit {
        @Expect(s5cSourceGoldenDiagnostic(), "ok")
        let seeded = s4PublishedStudentContext("s5c-boundary-seed")
        @Expect(seeded != "", true)
        if (seeded == "") { return }
        let root = Path(seeded).parent
        let canonicalRoot = root.join("candidate-set-v2")

        let tamperedRoot = root.join("candidate-tamper")
        s5cCopyTree(canonicalRoot, tamperedRoot)
        File.writeTo(tamperedRoot.join("rules/prefer-rune-safe-text-boundaries/AGENTS.md"),
            "tampered 中文🙂\n".toArray())
        let tamperedOutput = root.join("tampered-must-not-publish")
        @Expect(runStudentContextImportCli(s5cImportArgs(root, tamperedRoot,
            root.join("approval-v2.json"), tamperedOutput, true)), 1)
        @Expect(exists(tamperedOutput), false)

        let linked = root.join("candidate-symlink")
        @Expect(launch("/bin/ln", ["-s", canonicalRoot.toString(), linked.toString()]).wait(), 0)
        let linkedOutput = root.join("symlink-must-not-publish")
        @Expect(runStudentContextImportCli(s5cImportArgs(root, linked,
            root.join("approval-v2.json"), linkedOutput, true)), 1)
        @Expect(exists(linkedOutput), false)

        let driftedApproval = root.join("approval-drift-v2.json")
        let approval = String.fromUtf8(File.readFrom(root.join("approval-v2.json")))
        File.writeTo(driftedApproval, approval.replace("\"decision\":\"approve\"",
            "\"decision\":\"reject\"").toArray())
        let approvalOutput = root.join("approval-drift-must-not-publish")
        @Expect(runStudentContextImportCli(s5cImportArgs(root, canonicalRoot,
            driftedApproval, approvalOutput, true)), 1)
        @Expect(exists(approvalOutput), false)
    }

    @TestCase
    public func syntheticFailureAssetsProduceSingleFrozenCompletion(): Unit {
        @Expect(s5cSourceGoldenDiagnostic(), "ok")
        let seeded = s4PublishedStudentContext("s5c-completion-seed")
        @Expect(seeded != "", true)
        if (seeded == "") { return }
        let seedRoot = Path(seeded).parent
        let imported = seedRoot.join("completion-import")
        @Expect(runStudentContextImportCli(s5cImportArgs(seedRoot, seedRoot.join("candidate-set-v2"),
            seedRoot.join("approval-v2.json"), imported, true)), 0)
        let importedContext = readStudentContextBundleV2(imported.toString())
        @Expect(importedContext.ok, true)
        if (!importedContext.ok) { return }
        let root = s5cRoot("single-completion")
        let capability = s5cCapability("GLM-5.2", 1048576)
        let capabilityPath = root.join("source-provider-prompt-capability.json")
        File.writeTo(capabilityPath, capability.toArray())
        let authority = s5cAuthority()
        let datasetVersion = parseCangjieHumanEvalAuthorityManifest(authority).datasetVersion
        let manifest = s5cRunManifest(imported, importedContext, capabilityPath,
            seedRoot.join("candidate-set-v2"), datasetVersion)
        let manifestPath = root.join("run-manifest.json")
        File.writeTo(manifestPath, manifest.toArray())
        let options = CkbAbcdeRunnerOptions()
        options.runId = "s5c-run"
        options.runsRoot = root.parent.toString()
        options.expectedModelVersion = "GLM-5.2"
        @Expect(applyCkbAbcdeFrozenRunManifest(options, manifest.toArray()), "ok")
        options.modelFingerprint = "GLM-5.2"
        options.certificationPreflightPath = root.join("preflight.json").toString()
        options.certificationRunManifestPath = manifestPath.toString()
        options.providerIdentityArtifactPath = root.join("provider.json").toString()
        options.manifestPath = root.join("authority.jsonl").toString()
        options.claudeBin = "/bin/sh"
        File.writeTo(Path(options.certificationPreflightPath), "synthetic preflight\n".toArray())
        File.writeTo(Path(options.providerIdentityArtifactPath), "synthetic provider\n".toArray())
        File.writeTo(Path(options.manifestPath), authority.toArray())
        @Expect(ckbAbcdeFreezeS4RunAssets(options, root.toString(), false), "ok")
        let groupRoot = root.join("cases/CJ-HUMANEVAL-000").join(CkbAbcdeGroups.D)
        Directory.create(groupRoot, recursive: true)
        _ = ckbAbcdeWriteSuccessfulFakeTransportCaseForTest(options, "CJ-HUMANEVAL-000",
            groupRoot.toString())
        let context = readStudentContextBundleV2(options.studentContextRoot)
        @Expect(context.ok, true)
        if (!context.ok) { return }
        let assets = CkbS4FrozenContextAssets()
        assets.protocol = "Use exactly one completion. Do not call tools.\n"
        assets.rules = context.agentsMarkdown
        assets.skill = context.skillsPrompt
        assets.knowledge = "Frozen public Cangjie knowledge: 中文🙂 Rune boundaries."
        assets.publicTask = "Implement the public function declared by the synthetic task."
        assets.compositeHash = context.compositeHash
        assets.combinationAuditHash = context.combinationAuditHash
        assets.providerCapability = String.fromUtf8(File.readFrom(Path(options.providerPromptCapabilityPath)))
        @Expect(ckbAbcdeFreezeS4CaseAssets(groupRoot.toString(), assets, true), "ok")
        @Expect(ckbAbcdeFreezeS4CaseAssets(groupRoot.toString(), assets, false), "ok")
        let evidence = ckbAbcdeCompletionContextEvidence(assets)
        let evidencePath = groupRoot.join("completion-context-evidence.json")
        File.writeTo(evidencePath, (evidence + "\n").toArray())
        let persistedEvidence = String.fromUtf8(File.readFrom(evidencePath)).trimAscii()
        @Expect(persistedEvidence, evidence)
        @Expect(ckbS4FrozenContextEvidenceDiagnostic(assets, persistedEvidence), "ok")
        let prompt = renderCkbS4CompletionPrompt(assets)
        @Expect(prompt != "", true)
        File.writeTo(groupRoot.join("prompt.final.md"), prompt.toArray())

        let solution = "package solution\npublic func answer(): Int64 { 7 }\n"
        let provider = S5cFakeProvider(s5cTerminalCompletion(solution))
        let generated = ckbAbcdeRunClaudeCertification(options, CkbAbcdeGroups.D, groupRoot.toString(),
            groupRoot.join("workspace").toString(), groupRoot.join("runtime-home").toString(),
            groupRoot.join("case").toString(),
            executor: provider)
        @Expect(generated.exitCode, 0)
        @Expect(provider.callCount, 1)
        let completion = ckbAbcdeExtractSingleCompletion(generated.stdout.toArray())
        @Expect(completion.ok, true)
        @Expect(completion.completionCount, 1)
        @Expect(completion.toolCallCount, 0)
        @Expect(ckbS4GenerationProtocolDiagnostic("completion-only-v1", completion.completionCount, 1,
            completion.toolCallCount), "ok")
        s5cRebindFakeTransport(groupRoot, generated.stdout, options)
        let frozen = groupRoot.join("frozen-completion")
        @Expect(ckbAbcdeFreezeCompletion(frozen.toString(), completion), "ok")
        File.writeTo(groupRoot.join("generation-evidence.json"),
            ("{\"answerHash\":\"${completion.answerHash}\",\"completionCount\":1," +
            "\"toolCallCount\":0,\"executionFeedbackCount\":0,\"interrupted\":false," +
            "\"generatedTokenCount\":1,\"checkpointRecovered\":false}\n").toArray())
        File.writeTo(groupRoot.join("answer-freeze.json"),
            "{\"answerHash\":\"${completion.answerHash}\",\"sequence\":2}\n".toArray())

        let workspace = groupRoot.join("workspace")
        if (!exists(workspace.join("src"))) { Directory.create(workspace.join("src"), recursive: true) }
        File.writeTo(workspace.join("src/solution.cj"), File.readFrom(frozen.join("solution.cj")))
        let suites = S5cFakeSuiteExecutor()
        let evaluation = ckbAbcdeEvaluateFrozenCompletion(groupRoot.toString(), groupRoot.join("case").toString(),
            workspace.toString(), completion.answerHash, "base,plus", executor: suites)
        @Expect(evaluation.baseExecuted && evaluation.plusExecuted, true)
        @Expect(evaluation.basePassed && evaluation.plusPassed, true)
        @Expect(suites.callCount, 2)
        @Expect(benchmarkGapSha256(String.fromUtf8(File.readFrom(workspace.join("src/solution.cj")))),
            completion.answerHash)
        File.writeTo(groupRoot.join("verifier-mount.json"),
            ("{\"injectExitCode\":0,\"answerHashBefore\":\"${completion.answerHash}\"," +
            "\"answerHashAfter\":\"${completion.answerHash}\",\"mountedAfterFreeze\":true}\n").toArray())
        let strictTranscript = String.fromUtf8(File.readFrom(groupRoot.join("claude-transcript.jsonl")))
        let strict = ckbAbcdeRenderStrictCertificationCaseForTest(options, "CJ-HUMANEVAL-000",
            CkbAbcdeGroups.D, groupRoot.toString(), completion.answerHash, strictTranscript, "tests passed",
            true, "none", true)
        let parsed = parseCkbCertificationEvidence(strict)
        @Expect(parsed.valid, true)
        @Expect(ckbCertificationEvidenceDiagnostic(parsed), "ok")
        @Expect(ckbStrictCompletionCaseFromRunRootDiagnostic(root.toString(), parsed), "ok")
    }

    @TestCase
    public func syntheticFailureAssetsFailClosedAtEveryBoundary(): Unit {
        let fixture = s5SplitLeakStudentContextCliFixture("s5c-combined-split-leak")
        @Expect(runStudentContextImportCli(fixture.args), 1)
        @Expect(exists(Path(fixture.output)), false)
        let candidateRoot = Path(fixture.candidateRoot)
        @Expect(exists(candidateRoot.join("prompt.final.md")), false)
        @Expect(exists(candidateRoot.parent.join("prompt.final.md")), false)
    }
}

private class S5cFakeProvider <: CkbAbcdeCertificationProviderExecutor {
    public var callCount: Int64 = 0
    let transcript: String
    public init(transcript: String) { this.transcript = transcript }
    public override func execute(options: CkbAbcdeRunnerOptions, group: String, groupRoot: String,
        workspace: String, runtimeHome: String, caseSrc: String): CkbAbcdeCommandResult {
        callCount += 1
        let out = CkbAbcdeCommandResult()
        out.exitCode = 0
        out.stdout = transcript
        out
    }
}

private class S5cFakeSuiteExecutor <: CkbAbcdeCompletionSuiteExecutor {
    public var callCount: Int64 = 0
    public override func execute(suite: String, caseSrc: String, workspace: String): CkbAbcdeCommandResult {
        callCount += 1
        let out = CkbAbcdeCommandResult()
        out.exitCode = 0
        out.stdout = "synthetic ${suite} pass\n"
        out
    }
}

private func s5cRoot(name: String): Path {
    let target = Path("../target")
    if (!exists(target)) { Directory.create(target, recursive: true) }
    let root = canonicalize(target).join(
        "s5c-${name}-${DateTime.now().toUnixTimeStamp().toMilliseconds()}")
    if (exists(root)) { remove(root, recursive: true) }
    Directory.create(root, recursive: true)
    root
}

private func s5cCopyTree(source: Path, target: Path): Unit {
    if (!exists(target)) { Directory.create(target, recursive: true) }
    for (entry in Directory.readFrom(source)) {
        let destination = target.join(entry.name)
        if (entry.isDirectory()) { s5cCopyTree(entry.path, destination) }
        else if (entry.isRegular()) { File.writeTo(destination, File.readFrom(entry.path)) }
        else { throw IllegalStateException("fixture_tree_entry_invalid") }
    }
}

private func s5cImportArgs(root: Path, candidate: Path, approval: Path, output: Path,
    scaffold: Bool): Array<String> {
    let args = ArrayList<String>()
    for (value in ["cangjie-student-context-import", "--allowed-root", root.toString(),
        "--base-context", "none", "--candidate-set", candidate.toString(), "--approval",
        approval.toString(), "--frozen-knowledge-manifest", root.join(
        "frozen-candidate-manifest.json").toString(), "--knowledge-store", root.join("store").toString(),
        "--output", output.toString(), "--context-version", "s5c-context-v1"]) { args.add(value) }
    if (scaffold) { args.add("--scaffold-import") }
    args.toArray()
}

private func s5cSourceGoldenDiagnostic(): String {
    try {
        let golden = JsonValue.fromStr(String.fromUtf8(File.readFrom(Path(
            "fixtures/student_agents_rules/source-golden.json"))).trimAscii()).asObject()
        if (golden.get("schemaVersion").getOrThrow().asString().getValue() !=
            "ckb-student-agents-rules-source-golden-v1") { return "source_golden_schema_invalid" }
        let failurePath = golden.get("failureAssetsChecksumsPath").getOrThrow().asString().getValue()
        let contextPath = golden.get("studentContextChecksumsPath").getOrThrow().asString().getValue()
        if (canonicalize(Path(failurePath)).toString() != canonicalize(Path(
            "fixtures/completion_failure_assets/SHA256SUMS")).toString() ||
            canonicalize(Path(contextPath)).toString() !=
            s3FixtureRootForTest().join("SHA256SUMS").toString()) {
            return "source_golden_checksums_path_mismatch"
        }
        if (s5cBytesSha256(File.readFrom(Path(failurePath))) !=
            golden.get("failureAssetsChecksumsHash").getOrThrow().asString().getValue() ||
            s5cBytesSha256(File.readFrom(Path(contextPath))) !=
            golden.get("studentContextChecksumsHash").getOrThrow().asString().getValue()) {
            return "source_golden_hash_mismatch"
        }
        let failureDiagnostic = s5cSha256SumsDiagnostic(Path(failurePath))
        if (failureDiagnostic != "ok") { return "failure_assets_${failureDiagnostic}" }
        let contextDiagnostic = s5cSha256SumsDiagnostic(Path(contextPath))
        if (contextDiagnostic != "ok") { return "student_context_${contextDiagnostic}" }
        let candidateRoot = golden.get("candidateRoot").getOrThrow().asString().getValue()
        if (canonicalize(Path(candidateRoot)).toString() !=
            s3FixtureRootForTest().join("candidate-set-v2").toString()) {
            return "source_golden_candidate_root_mismatch"
        }
        let manifest = JsonValue.fromStr(String.fromUtf8(File.readFrom(Path(candidateRoot).join(
            "candidate-set-manifest.json"))).trimAscii()).asObject()
        if (manifest.get("schemaVersion").getOrThrow().asString().getValue() !=
            golden.get("expectedCandidateSchemaVersion").getOrThrow().asString().getValue()) {
            return "source_golden_candidate_schema_mismatch"
        }
        "ok"
    } catch (_: Exception) { "source_golden_invalid" }
}

private func s5cSha256SumsDiagnostic(manifestPath: Path): String {
    if (!exists(manifestPath) || FileInfo(manifestPath).isSymbolicLink() ||
        !FileInfo(manifestPath).isRegular()) { return "checksums_file_invalid" }
    let root = manifestPath.parent
    if (FileInfo(root).isSymbolicLink() || !FileInfo(root).isDirectory()) {
        return "checksums_root_invalid"
    }
    let declared = HashSet<String>()
    let lines = String.fromUtf8(File.readFrom(manifestPath)).split("\n")
    for (index in 0..lines.size) {
        let line = lines[index]
        if (line == "") {
            if (index != lines.size - 1) { return "checksums_empty_line" }
            continue
        }
        let fields = line.split("  ")
        if (fields.size != 2 || !s5cLowerHex64(fields[0]) ||
            !s5cSafeRelativePath(fields[1]) || fields[1] == manifestPath.fileName) {
            return "checksums_line_invalid"
        }
        let relative = fields[1]
        if (declared.contains(relative)) { return "checksums_path_duplicate" }
        let file = root.join(relative)
        if (!exists(file) || FileInfo(file).isSymbolicLink() || !FileInfo(file).isRegular()) {
            return "checksums_entry_invalid"
        }
        if (s5cBytesSha256(File.readFrom(file)) != "sha256:${fields[0]}") {
            return "checksums_entry_hash_mismatch"
        }
        declared.add(relative)
    }
    let actual = HashSet<String>()
    let inventoryDiagnostic = s5cCollectInventory(root, "", manifestPath.fileName, actual)
    if (inventoryDiagnostic != "ok") { return inventoryDiagnostic }
    if (actual.size != declared.size) { return "checksums_inventory_mismatch" }
    for (relative in actual) {
        if (!declared.contains(relative)) { return "checksums_inventory_mismatch" }
    }
    "ok"
}

private func s5cCollectInventory(root: Path, prefix: String, excluded: String,
    inventory: HashSet<String>): String {
    for (entry in Directory.readFrom(root)) {
        if (entry.isSymbolicLink()) { return "checksums_inventory_symlink" }
        let relative = if (prefix == "") { entry.name } else { "${prefix}/${entry.name}" }
        if (entry.isDirectory()) {
            let diagnostic = s5cCollectInventory(entry.path, relative, excluded, inventory)
            if (diagnostic != "ok") { return diagnostic }
        } else if (entry.isRegular()) {
            if (relative != excluded) { inventory.add(relative) }
        } else { return "checksums_inventory_entry_invalid" }
    }
    "ok"
}

private func s5cLowerHex64(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 64) { return false }
    for (rune in runes) {
        if (!((rune >= r'0' && rune <= r'9') || (rune >= r'a' && rune <= r'f'))) {
            return false
        }
    }
    true
}

private func s5cSafeRelativePath(value: String): Bool {
    if (value == "" || value.startsWith("/") || value.endsWith("/") || value.contains("\\")) {
        return false
    }
    for (component in value.split("/")) {
        if (component == "" || component == "." || component == "..") { return false }
        for (rune in component.toRuneArray()) {
            if (!((rune >= r'a' && rune <= r'z') || (rune >= r'A' && rune <= r'Z') ||
                (rune >= r'0' && rune <= r'9') || rune == r'-' || rune == r'_' || rune == r'.')) {
                return false
            }
        }
    }
    true
}

private func s5cBytesSha256(bytes: Array<UInt8>): String {
    let digest = SHA256()
    digest.write(bytes)
    var out = ""
    for (byte in digest.finish()) {
        out += s5cHexNibble(byte / UInt8(16))
        out += s5cHexNibble(byte % UInt8(16))
    }
    "sha256:${out}"
}

private func s5cHexNibble(value: UInt8): String {
    "0123456789abcdef".toRuneArray()[Int64(value)].toString()
}

private func s5cCapability(model: String, budget: Int64): String {
    let evidence = "{\"schemaVersion\":\"ckb-provider-prompt-capability-v1\",\"modelVersion\":\"${model}\",\"maxContextTokens\":${budget + 1},\"reservedOutputTokens\":1,\"sourceEvidence\":\"synthetic-fixture\",\"observedAtUtc\":\"2026-08-07T00:00:00Z\"}"
    evidence.replace("}", ",\"capabilityHash\":\"${benchmarkGapSha256(evidence)}\"}")
}

private func s5cRebindFakeTransport(groupRoot: Path, transcript: String,
    options: CkbAbcdeRunnerOptions): Unit {
    let attemptPath = groupRoot.join("claude-attempts.jsonl")
    let oldTranscript = String.fromUtf8(File.readFrom(groupRoot.join("claude-transcript.attempt-1.jsonl")))
    let oldDiagnostic = String.fromUtf8(File.readFrom(groupRoot.join(
        "model-transport-diagnostic.attempt-1.json")))
    let assessment = ckbAbcdeAssessSample(transcript, options.expectedModelVersion)
    let diagnostic = ckbAbcdeRenderModelTransportDiagnostic(transcript, 0, assessment,
        options.modelTimeoutSeconds, "certification", "") + "\n"
    let rebound = String.fromUtf8(File.readFrom(attemptPath)).replace(
        benchmarkGapSha256(oldTranscript), benchmarkGapSha256(transcript)).replace(
        benchmarkGapSha256(oldDiagnostic), benchmarkGapSha256(diagnostic))
    File.writeTo(groupRoot.join("claude-transcript.attempt-1.jsonl"), transcript.toArray())
    File.writeTo(groupRoot.join("claude-transcript.jsonl"), transcript.toArray())
    File.writeTo(groupRoot.join("model-transport-diagnostic.attempt-1.json"), diagnostic.toArray())
    File.writeTo(attemptPath, rebound.toArray())
    let restores = String.fromUtf8(File.readFrom(groupRoot.join("workspace-restores.jsonl")))
    let lineage = ckbAbcdeAttemptLineageHash(rebound, restores)
    let summary = "{\"transportAttemptCount\":1,\"sampleAttemptCount\":1," +
        "\"lastAuditedTransportAttempt\":1,\"selectedBusinessSample\":1," +
        "\"selectedTransportAttempt\":1,\"retryCount\":0,\"unresolvedTransport\":0," +
        "\"attemptLineageHash\":\"${lineage}\",\"workspaceRestoreEvidenceHash\":" +
        "\"${benchmarkGapSha256(restores)}\",\"attemptsPath\":\"claude-attempts.jsonl\"," +
        "\"restoresPath\":\"workspace-restores.jsonl\"}"
    File.writeTo(groupRoot.join("attempt-evidence.json"), (summary + "\n").toArray())
    File.writeTo(groupRoot.join("test-result.json"), (summary.replace("}",
        ",\"testExitCode\":0,\"unitPassAt1\":true,\"failureType\":\"none\"," +
        "\"testLogPath\":\"${groupRoot.join("test.log").toString()}\"}") + "\n").toArray())
}

private func s5cRunManifest(contextRoot: Path, context: CkbContextBaseVersion, capabilityPath: Path,
    candidateRoot: Path, datasetVersion: String): String {
    let candidate = parseTeacherContextCandidateSetDirectoryV2(candidateRoot.parent.toString(),
        candidateRoot.toString())
    let provider = benchmarkGapSha256("s5c-provider")
    let sampling = benchmarkGapSha256("s5c-sampling")
    let schema = benchmarkGapSha256(ckbAbcdeCompletionOutputSchema())
    let runHash = benchmarkGapSha256(context.compositeHash + context.combinationAuditHash)
    "{\"generationProtocol\":\"completion-only-v1\",\"samplesPerCase\":1," +
        "\"datasetVersion\":\"${datasetVersion}\",\"knowledgeVersion\":\"${context.knowledgeVersion}\"," +
        "\"modelVersion\":\"GLM-5.2\",\"providerIdentityHash\":\"${provider}\"," +
        "\"skillBundleVersion\":\"${context.skillVersion}\",\"skillBundleHash\":\"${context.skillsHash}\"," +
        "\"samplingCapability\":\"provider_default_not_client_exposed\"," +
        "\"samplingCapabilityHash\":\"${sampling}\",\"outputSchemaHash\":\"${schema}\"," +
        "\"assetLineage\":\"independent\",\"rulesHash\":\"${context.rulesHash}\"," +
        "\"rulesTreeHash\":\"${candidate.rules.treeHash}\",\"rulesCount\":${context.rulesCount}," +
        "\"studentContextRoot\":\"${contextRoot.toString()}\"," +
        "\"studentContextManifestHash\":\"${benchmarkGapSha256(context.manifestJson)}\"," +
        "\"studentContextCompositeHash\":\"${context.compositeHash}\"," +
        "\"combinationAuditHash\":\"${context.combinationAuditHash}\"," +
        "\"providerPromptCapabilityPath\":\"${capabilityPath.toString()}\"," +
        "\"providerPromptCapabilityHash\":\"${benchmarkGapSha256(s5cCapability("GLM-5.2", 1048576))}\"," +
        "\"effectivePromptByteBudget\":1048576,\"runManifestHash\":\"${runHash}\"}"
}

private func s5cAuthority(): String {
    let manifest = CangjieHumanEvalManifestResult()
    var datasetSeed = ""
    for (i in 0..164) {
        let row = CangjieHumanEvalManifestRow()
        row.caseId = if (i < 10) { "CJ-HUMANEVAL-00${i}" } else if (i < 100) {
            "CJ-HUMANEVAL-0${i}"
        } else { "CJ-HUMANEVAL-${i}" }
        row.targetVersion = "1.0.0"
        row.signature = "public func answer(): Int64"
        row.prompt = "Synthetic public task ${i}."
        row.promptHash = benchmarkGapSha256(row.prompt)
        row.metadataHash = benchmarkGapSha256("synthetic metadata ${i}")
        row.starterHash = benchmarkGapSha256("synthetic starter ${i}")
        row.testsHash = benchmarkGapSha256("synthetic base tests ${i}")
        row.plusTestsHash = benchmarkGapSha256("synthetic plus tests ${i}")
        row.translationHash = benchmarkGapSha256("synthetic translation ${i}")
        row.caseHash = benchmarkGapSha256("${row.caseId}|${row.targetVersion}|${row.signature}|" +
            "${row.promptHash}|${row.metadataHash}|${row.starterHash}|${row.testsHash}|" +
            "${row.plusTestsHash}|${row.translationHash}")
        datasetSeed += "${row.caseId}|${row.caseHash}\n"
        manifest.rows.add(row)
    }
    manifest.datasetVersion = "cangjie-humaneval-164-${benchmarkGapSha256(datasetSeed).replace("sha256:", "")}"
    for (row in manifest.rows) { row.datasetVersion = manifest.datasetVersion }
    cangjieHumanEvalRenderAuthorityManifest(manifest)
}

private func s5cTerminalCompletion(solution: String): String {
    "{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false,\"modelUsage\":{\"GLM-5.2\":{}},\"structured_output\":{\"solution_cj\":\"${solution.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")}\"}}"
}
