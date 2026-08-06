package cangjie_community_knowledge_base_test

import std.collection.*
import std.fs.*
import std.process.*
import std.time.*
import stdx.encoding.json.*

public class R7RealRunnerFixture {
    public var ok: Bool = false
    public var diagnostic: String = "not_run"
    public var runnerExitCode: Int64 = -1
    public var modelFingerprint: String = ""
    public var proof: CkbProductionReleaseProof = CkbProductionReleaseProof()
}

public func r7CleanKnowledgeBase():KnowledgeBase{
    let records=ArrayList<CangjieTypedRecord>()
    records.add(r7OfficialTypedRecord("r7-official-arraylist-add-symbol",CangjieTypedRecordKinds.SYMBOL_CARD,"ArrayList.add","symbolKey=ArrayList.add\nmodule=std.collection\nsignature=func add(value: T): Unit",CangjieSourceSets.STD,"std/collection/array_list.cj"))
    records.add(r7OfficialTypedRecord("r7-official-arraylist-add-doc",CangjieTypedRecordKinds.DOC_SECTION,"ArrayList.add documentation","ArrayList.add appends a value. Do not use append.",CangjieSourceSets.DOCS,"language/collections.md"))
    records.add(r7OfficialTypedRecord("r7-official-cjpm-test",CangjieTypedRecordKinds.TOOL_MANUAL,"cjpm test","Run cjpm test to execute package tests.",CangjieSourceSets.TOOLS,"tools/cjpm.md"))
    let kb=KnowledgeBase(FakeClock(0));_=kb.loadFirstInitializationTypedRecords(records,"r7-clean-candidate");_=kb.promoteFirstInitializationCandidate("r7-clean-active");kb
}

public func r7CertifiedKnowledgeRecords(
    records: ArrayList<NormalizedRecord>
): ArrayList<CkbCertifiedKnowledgeRecord> {
    let out = ArrayList<CkbCertifiedKnowledgeRecord>()
    for (record in records) {
        let item = CkbCertifiedKnowledgeRecord()
        item.canonicalIdentity = "active:${record.sourceId}"
        item.revision = 1
        item.record = record
        item.evidenceHash = ckbCertifiedKnowledgeRecordEvidenceHash(item)
        out.add(item)
    }
    out
}

private func r7OfficialTypedRecord(sourceId:String,kind:String,title:String,content:String,sourceSet:String,path:String):CangjieTypedRecord{
    let record=CangjieTypedRecord();record.recordKind=kind;record.sourceId=sourceId;record.title=title;record.content=content;record.citation="https://docs.cangjie-lang.cn/docs/1.0.0/${path}";record.sourceSet=sourceSet;record.path=path;record.targetVersion="1.0.0";record.versionResolutionId="r7-official-1.0.0-${sourceId}";record
}

// This is the only positive R7 fixture. It invokes the production P6 builder,
// production certification runner, real loopback MCP HTTP service and verifier.
public func r7BuildRealRunnerProof(records: ArrayList<CkbCertifiedKnowledgeRecord>): R7RealRunnerFixture {
    let result = R7RealRunnerFixture()
    let stamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    let repoRoot=canonicalize(Path("..")).toString()
    let root = Path(repoRoot).join("target/r7-real-runner-${stamp}")
    Directory.create(root, recursive: true)
    let datasetRoot = root.join("authority-data"); r7WriteSyntheticAuthority(datasetRoot)
    let authorityPath = root.join("authority.jsonl")
    let authority = buildCangjieHumanEvalManifest(datasetRoot.toString(), authorityPath.toString())
    if (!authority.ok || authority.rows.size != 164) { result.diagnostic = "authority_build_failed"; return result }
    let authorityText = String.fromUtf8(File.readFrom(authorityPath))

    let normalized = ArrayList<NormalizedRecord>()
    for (record in records) { normalized.add(record.record) }
    let frozenKb = r7CleanKnowledgeBase()
    if (ckbCertifiedNormalizedRecordsChecksum(frozenKb.activeRecordSnapshot()) != ckbCertifiedNormalizedRecordsChecksum(normalized)) {
        result.diagnostic = "fixture_records_do_not_match_frozen_store"; return result
    }
    let frozenStore = FileKnowledgeStore(root.join("frozen-store").toString())
    _ = frozenKb.persistActiveSnapshot(frozenStore)
    let snapshot = frozenStore.loadActiveSnapshot()
    let artifacts = r7TrustV2Artifacts(snapshot.normalizedRecords)
    let trustSeal = ckbRenderCandidateTrustSeal(snapshot.normalizedRecords,
        artifacts[0], artifacts[1], artifacts[2], artifacts[3],
        restText: artifacts[4], mcpStdioText: artifacts[5],
        mcpHttpText: artifacts[6], anonymousQueryText: artifacts[7])
    let trustDiagnostic=ckbCandidateTrustSealDiagnostic(trustSeal,
        snapshot.normalizedRecords, artifacts[0], artifacts[1], artifacts[2],
        artifacts[3], restText: artifacts[4], mcpStdioText: artifacts[5],
        mcpHttpText: artifacts[6], anonymousQueryText: artifacts[7])
    if (trustDiagnostic != "ok") {
        result.diagnostic = "candidate_trust_seal_failed:${trustDiagnostic}"; return result
    }
    let frozenOptions = CkbFrozenCandidateSealOptions()
    frozenOptions.expectedKnowledgeVersion = snapshot.activeVersion
    frozenOptions.expectedCandidateChecksum = ckbCertifiedNormalizedRecordsChecksum(snapshot.normalizedRecords)
    frozenOptions.inputHash = benchmarkGapSha256("r7-input")
    frozenOptions.configHash = benchmarkGapSha256("r7-config")
    frozenOptions.modelHash = benchmarkGapSha256("r7-model")
    frozenOptions.studentLeakageProofJson = trustSeal
    frozenOptions.studentLeakageArtifactJson = artifacts[0]
    frozenOptions.anonymousQueryArtifactJson = artifacts[1]
    frozenOptions.authorityIsolationArtifactJson = artifacts[2]
    frozenOptions.atomTestArtifactJson = artifacts[3]
    frozenOptions.restLeakageArtifactJson = artifacts[4]
    frozenOptions.mcpStdioLeakageArtifactJson = artifacts[5]
    frozenOptions.mcpHttpLeakageArtifactJson = artifacts[6]
    frozenOptions.anonymousAtomQueryArtifactJson = artifacts[7]
    let frozen = ckbBuildFrozenCandidateSeal(frozenStore, frozenOptions)
    if (!frozen.ok) { result.diagnostic = "frozen_seal_failed:${frozen.diagnostic}"; return result }
    let frozenPath = root.join("frozen-candidate-manifest.json"); File.writeTo(frozenPath, frozen.manifestJson.toArray())

    let fixtureRoot = canonicalize(
        Path(repoRoot).join("test/fixtures/certification_fake_claude")).toString()
    let fixtureBuild = launch("/bin/zsh", ["-lc", "cjpm build -i"],
        workingDirectory: Some<Path>(Path(fixtureRoot))).wait()
    if (fixtureBuild != 0) { result.diagnostic = "fake_claude_build_failed"; return result }
    let fakeClaude = canonicalize(Path(fixtureRoot).join("target/release/bin/main")).toString()
    let claudeVersion = ckbAbcdeClaudeVersionForTest(executable: fakeClaude)
    if (claudeVersion != "ckb-certification-fake-claude-1.0") { result.diagnostic = "fake_claude_version_failed:${claudeVersion}"; return result }
    let provider = "{\"provider\":\"r7-test-fake-claude\",\"model\":\"GLM-5.2\",\"claudeCodeVersion\":\"${claudeVersion}\"}"
    let providerPath = root.join("provider-identity.json"); File.writeTo(providerPath, provider.toArray())

    let runId = "r7-real-certification"
    let configPath = root.join("runtime.conf")
    let port: Int64 = 19873
    File.writeTo(configPath, "service.bind=127.0.0.1\nservice.port=${port}\n".toArray())
    let runsRoot = Path(repoRoot).join("target/certification-r7-${stamp}"); Directory.create(runsRoot, recursive: true)
    let certificationRunRoot = runsRoot.join(runId); Directory.create(certificationRunRoot, recursive: true)
    let ckbBin = canonicalize(
        Path(repoRoot).join("target/release/bin/main")).toString()
    let p6Root = root.join("p6").join(runId); Directory.create(p6Root, recursive: true)
    let p6Workspace = root.join("p6-workspace"); let p6Runtime = root.join("p6-runtime")
    Directory.create(p6Workspace, recursive: true); Directory.create(p6Runtime, recursive: true)
    let p6 = r7P6Options(p6Root, p6Workspace, p6Runtime, runId, authorityText, authority.datasetVersion,
        snapshot.activeVersion, frozenOptions.expectedCandidateChecksum, frozen.manifestJson, trustSeal, provider, claudeVersion)
    p6.certificationBinaryPath=ckbBin;p6.certificationConfigPath=canonicalize(configPath).toString();p6.certificationStorePath=canonicalize(frozenStore.root).toString();p6.certificationRunRoot=canonicalize(certificationRunRoot).toString();p6.certificationHttpBase="http://127.0.0.1:${port}"
    let fingerprint = r7Fingerprint(p6, authority.datasetVersion, authorityText)
    p6.experimentReport = r7Experiment(fingerprint, authority.datasetVersion, benchmarkGapSha256(authorityText),
        claudeVersion, snapshot.activeVersion, frozenOptions.expectedCandidateChecksum)
    let preflight = runCertificationPreflight(p6, fingerprint)
    if (!preflight.ok) { result.diagnostic = "p6_failed:${preflight.diagnostic}"; return result }

    let control = root.join("starter-control"); Directory.create(control, recursive: true)
    let controlExit = launch("/bin/zsh", ["-lc", "cp -R '${datasetRoot}/CJ-HUMANEVAL-000/starter/.' '${control}/' && cp '${datasetRoot}/CJ-HUMANEVAL-000/tests/TestMain.cj' '${control}/src/main.cj' && cp '${datasetRoot}/CJ-HUMANEVAL-000/tests/cjpm.executable.toml' '${control}/cjpm.toml' && cjpm run >/dev/null 2>&1"], workingDirectory: Some<Path>(root)).wait()
    if (controlExit == 0) { result.diagnostic = "starter_control_must_fail"; return result }

    let args = ["cangjie-eval-abcde", "--repo-root", repoRoot, "--run-mode", "certification", "--run-id", runId,
        "--dataset-version", authority.datasetVersion, "--knowledge-version", snapshot.activeVersion,
        "--model-fingerprint", preflight.fingerprint, "--claude-bin", fakeClaude,
        "--config", canonicalize(configPath).toString(), "--groups", CkbAbcdeGroups.D,
        "--runs-root", canonicalize(runsRoot).toString(), "--ckb-http-base", "http://127.0.0.1:${port}",
        "--ckb-bin", ckbBin, "--ckb-store", canonicalize(frozenStore.root).toString(),
        "--dataset-root", canonicalize(datasetRoot).toString(), "--manifest", canonicalize(authorityPath).toString(),
        "--certification-preflight", canonicalize(p6Root.join("preflight.json")).toString(),
        "--certification-run-manifest", canonicalize(p6Root.join("run-manifest.json")).toString(),
        "--expected-model-version", "GLM-5.2", "--provider-identity-hash", benchmarkGapSha256(provider),
        "--provider-identity-artifact", canonicalize(providerPath).toString(),
        "--frozen-candidate-manifest", canonicalize(frozenPath).toString(),
        "--transport-retries", "1", "--model-timeout-seconds", "30"]
    result.runnerExitCode = runCangjieEvalAbcde(args)
    let runRoot = runsRoot.join(runId)
    if (result.runnerExitCode != 0) { result.diagnostic = "runner_failed"; return result }
    let gate = ckbStrictCertificationGateFromRunRoot(runRoot.toString(), authorityText)
    if (!gate.ok || gate.total != 164 || gate.unitPassAt1 != 164 || gate.transportRetryCount != 1 || gate.retryUsed != 0) { result.diagnostic = "strict_gate_failed:${gate.diagnostics}"; return result }
    let sessions=HashSet<String>();let runtimeHomes=HashSet<String>()
    for (row in authority.rows) {
        let groupRoot=runRoot.join("cases").join(row.caseId).join(CkbAbcdeGroups.D)
        let solution = String.fromUtf8(File.readFrom(groupRoot.join("workspace/src/solution.cj")))
        if (!solution.contains("return true")) { result.diagnostic = "solution_not_written:${row.caseId}"; return result }
        let session=String.fromUtf8(File.readFrom(groupRoot.join("session-id.txt"))).trimAscii()
        if(session==""||sessions.contains(session)){result.diagnostic="session_not_fresh:${row.caseId}";return result};sessions.add(session)
        let selectedAttempt=if(row.caseId=="CJ-HUMANEVAL-000"){2}else{1}
        let runtime=canonicalize(groupRoot.join("runtime-home/attempt-${selectedAttempt}")).toString()
        if(runtimeHomes.contains(runtime)){result.diagnostic="runtime_home_not_fresh:${row.caseId}";return result};runtimeHomes.add(runtime)
        if(row.caseId=="CJ-HUMANEVAL-000"){
            let attempts=String.fromUtf8(File.readFrom(groupRoot.join("claude-attempts.jsonl")));let restores=String.fromUtf8(File.readFrom(groupRoot.join("workspace-restores.jsonl")))
            let restore=JsonValue.fromStr(restores.trimAscii()).asObject();let before=restore.get("beforeHash").getOrThrow().asString().getValue();let authorityHash=restore.get("authorityHash").getOrThrow().asString().getValue();let after=restore.get("afterHash").getOrThrow().asString().getValue()
            if(!attempts.contains("\"transportAttempt\":1")||!attempts.contains("\"classification\":\"timeout\"")||!attempts.contains("\"transportAttempt\":2")||!attempts.contains("\"sampleAttempt\":1")||!restores.contains("\"transportAttempt\":2")||!restores.contains("\"restored\":true")||before==authorityHash||after!=authorityHash||!exists(groupRoot.join("runtime-home/attempt-1"))||!exists(groupRoot.join("runtime-home/attempt-2"))||String.fromUtf8(File.readFrom(groupRoot.join("session-id.attempt-1.txt")))==String.fromUtf8(File.readFrom(groupRoot.join("session-id.attempt-2.txt")))){result.diagnostic="real_transport_retry_evidence_invalid";return result}
        }
    }
    if(sessions.size!=164||runtimeHomes.size!=164){result.diagnostic="fresh_identity_count_mismatch";return result}

    let proof = CkbProductionReleaseProof()
    proof.p6PreflightJson = String.fromUtf8(File.readFrom(runRoot.join("preflight.json")))
    proof.p6RunManifestJson = String.fromUtf8(File.readFrom(runRoot.join("run-manifest.json")))
    proof.p7RunRoot = runRoot.toString(); proof.p7ResultsJsonl = String.fromUtf8(File.readFrom(runRoot.join("results.jsonl")))
    proof.p7ArtifactManifestHash = gate.artifactManifestHash; proof.p7GateJson = renderCkbStrictCertificationGateJson(gate)
    proof.authorityManifestJsonl = authorityText; proof.frozenCandidateManifestJson = frozen.manifestJson
    proof.frozenCandidateManifestHash = benchmarkGapSha256(frozen.manifestJson)
    proof.studentLeakageArtifactJson = artifacts[0]; proof.anonymousQueryArtifactJson = artifacts[1]
    proof.authorityIsolationArtifactJson = artifacts[2]; proof.atomTestArtifactJson = artifacts[3]
    proof.restLeakageArtifactJson = artifacts[4]; proof.mcpStdioLeakageArtifactJson = artifacts[5]
    proof.mcpHttpLeakageArtifactJson = artifacts[6]; proof.anonymousAtomQueryArtifactJson = artifacts[7]
    proof.studentLeakageProofJson = trustSeal
    proof.candidateArtifactJsonl = ckbRenderCertifiedCandidateArtifact(records)
    proof.indexArtifactJson = ckbRenderCertifiedCountArtifact("index", records)
    proof.vectorArtifactJson = ckbRenderCertifiedCountArtifact("vector", records)
    proof.versionManifestJson = ckbRenderCertifiedVersionManifest(snapshot.activeVersion, records)
    proof.stdioQueryPayload = ckbRenderCertifiedQueryPayload(snapshot.activeVersion, records)
    proof.httpQueryPayload = proof.stdioQueryPayload
    result.proof = proof; result.modelFingerprint=preflight.fingerprint; result.ok = true; result.diagnostic = "ok"; result
}

private func r7TrustV2Artifacts(records: ArrayList<NormalizedRecord>): Array<String> {
    let authorityHash = benchmarkGapSha256("r7-trust-v2-authority")
    let input = CkbStudentLeakageScanInput()
    input.authorityHash = authorityHash
    input.candidateChecksum = ckbCertifiedNormalizedRecordsChecksum(records)
    input.normalizedRecords = records
    for (record in records) {
        let raw = RawRecord()
        raw.sourceId = record.sourceId; raw.title = record.title
        raw.content = record.chunk; raw.contentHash = benchmarkGapSha256(record.chunk)
        raw.metadata = record.metadata; input.rawRecords.add(raw)
    }
    let feed = buildServingDocuments(records)
    let index = buildCangjieStudentServingIndex(records,
        activeKnowledgeVersion: "r7-trust-v2")
    input.servingDocuments = feed.documents
    input.indexRecords = index.records
    input.indexDocuments = index.documents
    input.exactEntries = index.exactEntries
    let pack = CangjieTaskKnowledgePack()
    pack.queryId = "safe-query"; pack.taskId = "safe-task"
    pack.knowledgeVersion = "r7-trust-v2"; pack.targetVersion = "1.0.0"
    input.taskPacks.add(pack)
    let leakage = ckbBuildStudentLeakageReportFromLayers(input).json
    let anonymous = ckbBuildAnonymousAtomQueryReport(records,
        ArrayList<NormalizedRecord>()).jsonl
    let serving = r7TrustV2ServingArtifacts(records, benchmarkGapSha256(anonymous))
    let materializationHash = benchmarkGapSha256("r7-materialization")
        .replace("sha256:", "").toAsciiUpper()
    let authority = "{\"ok\":true,\"authorityCount\":164,\"authorityHash\":\"${authorityHash}\",\"activeEvalCount\":0,\"normalizedEvalCount\":0,\"immutableManifestHash\":\"${benchmarkGapSha256("r7-immutable")}\",\"cleanManifestHash\":\"${benchmarkGapSha256("r7-clean")}\",\"materializationManifestEvidenceHash\":\"${materializationHash}\"}\n"
    let atomBody = "{\"ok\":true,\"diagnostic\":\"validated\",\"bundleCount\":1,\"testCount\":1,\"passed\":1,\"failed\":0,\"selectedAtomsHash\":\"${benchmarkGapSha256("r7-selected")}\",\"bundleEvidenceHash\":\"${benchmarkGapSha256("r7-bundle")}\""
    let atom = atomBody + ",\"evidenceHash\":\"${benchmarkGapSha256(atomBody + "}")}\"}\n"
    [leakage, serving.summaryJson, authority, atom, serving.restJson,
        serving.mcpStdioJson, serving.mcpHttpJson, anonymous]
}

private func r7TrustV2ServingArtifacts(records: ArrayList<NormalizedRecord>,
    anonymousHash: String): CkbStudentServingLeakageReport {
    let root = Path("target/r7-trust-serving-${ckbCoreNowMillis()}")
    let kb = newOfflineKnowledgeBase()
    kb.stageCandidateRecords("r7-trust-v2", records)
    _ = kb.promoteCandidateToActive("r7-trust-v2")
    let store = FileKnowledgeStore(root.join("clean").toString())
    _ = kb.persistActiveSnapshot(store)
    let blockedRecords = ArrayList<NormalizedRecord>()
    for (record in records) { blockedRecords.add(record) }
    let poisoned = NormalizedRecord()
    poisoned.sourceId = "precert-synthetic-contamination"
    poisoned.recordKind = records[0].recordKind
    poisoned.title = "Synthetic transport rejection fixture"
    poisoned.chunk = "Synthetic benchmark reference solution marker CJ-HUMANEVAL-000"
    poisoned.citation = records[0].citation
    poisoned.metadata.sourceId = poisoned.sourceId
    poisoned.metadata.sourceType = records[0].metadata.sourceType
    poisoned.metadata.sourceUrl = records[0].metadata.sourceUrl
    poisoned.metadata.repo = records[0].metadata.repo
    poisoned.metadata.path = records[0].metadata.path
    poisoned.metadata.targetVersion = records[0].metadata.targetVersion
    poisoned.metadata.sourceSet = records[0].metadata.sourceSet
    poisoned.metadata.versionResolutionId = records[0].metadata.versionResolutionId
    poisoned.metadata.trustLevel = records[0].metadata.trustLevel
    poisoned.metadata.reviewState = records[0].metadata.reviewState
    blockedRecords.add(poisoned)
    let blockedKb = newOfflineKnowledgeBase()
    blockedKb.stageCandidateRecords("r7-trust-v2", blockedRecords)
    _ = blockedKb.promoteCandidateToActive("r7-trust-v2")
    let blockedStore = FileKnowledgeStore(root.join("blocked").toString())
    _ = blockedKb.persistActiveSnapshot(blockedStore)
    let probes = ArrayList<CkbStudentServingProbe>()
    probes.add(r7TrustV2Probe("case",
        "CJ-HUMANEVAL-000 Cangjie function and collection syntax", false))
    probes.add(r7TrustV2Probe("path",
        "cangjie\\u002dhumaneval/中文😀/visible-benchmark/prompt.md Cangjie function and collection syntax",
        false))
    probes.add(r7TrustV2Probe("stored-evidence-contamination",
        "Cangjie function and collection syntax", true))
    let report = ckbBuildStudentServingLeakageReportWithBlockedService(
        CkbCommandLoopService(CkbRuntimeConfig(), store),
        CkbCommandLoopService(CkbRuntimeConfig(), blockedStore), probes,
        anonymousQueryArtifactHash: anonymousHash)
    if (exists(root)) { remove(root, recursive: true) }
    report
}

private func r7TrustV2Probe(id: String, query: String,
    blocked: Bool): CkbStudentServingProbe {
    let probe = CkbStudentServingProbe()
    probe.probeId = id; probe.query = query; probe.expectedBlocked = blocked
    probe
}

private func r7WriteSyntheticAuthority(root: Path): Unit {
    for (i in 0..164) {
        let id = if (i < 10) { "CJ-HUMANEVAL-00${i}" } else if (i < 100) { "CJ-HUMANEVAL-0${i}" } else { "CJ-HUMANEVAL-${i}" }
        let packageName = "ckb_certification_case_${i}"
        let caseRoot = root.join(id); Directory.create(caseRoot.join("starter/src"), recursive: true)
        Directory.create(caseRoot.join("tests"), recursive: true); Directory.create(caseRoot.join("tests-plus"), recursive: true); Directory.create(caseRoot.join("translation"), recursive: true)
        File.writeTo(caseRoot.join("prompt.md"), "Implement certificationFixture so it returns true.\n".toArray())
        File.writeTo(caseRoot.join("metadata.json"), "{\"id\":\"${id}\",\"targetVersion\":\"1.0.0\",\"signature\":\"public func certificationFixture(): Bool\"}\n".toArray())
        let staticToml = "[package]\n  cjc-version = \"1.0.0\"\n  name = \"${packageName}\"\n  version = \"0.1.0\"\n  output-type = \"static\"\n  src-dir = \"src\"\n"
        let executableToml = staticToml.replace("output-type = \"static\"", "output-type = \"executable\"")
        File.writeTo(caseRoot.join("starter/cjpm.toml"), staticToml.toArray())
        File.writeTo(caseRoot.join("tests/cjpm.executable.toml"), executableToml.toArray())
        File.writeTo(caseRoot.join("tests-plus/cjpm.executable.toml"), executableToml.toArray())
        File.writeTo(caseRoot.join("starter/src/solution.cj"), "package ${packageName}\n\npublic func certificationFixture(): Bool { return false }\n".toArray())
        File.writeTo(caseRoot.join("tests/TestMain.cj"), "package ${packageName}\n\nmain(): Int64 { if (certificationFixture()) { return 0 }; return 1 }\n".toArray())
        File.writeTo(caseRoot.join("tests-plus/TestMain.cj"), "package ${packageName}\n\nmain(): Int64 { if (certificationFixture()) { return 0 }; return 1 }\n".toArray())
        File.writeTo(caseRoot.join("translation/line_translation.md"), "synthetic certification fixture\n".toArray())
    }
}

private func r7P6Options(output:Path,workspace:Path,runtime:Path,runId:String,authority:String,datasetVersion:String,version:String,checksum:String,frozen:String,seal:String,provider:String,claudeVersion:String):CkbCertificationPreflightOptions{
    let o=CkbCertificationPreflightOptions();let skill=parseStudentSkillCandidateDirectory("fixtures/teacher_skill_candidate/static-boundary-review",true);let bundle=compileStudentSkillBundle("student-skills-v1",ArrayList<CkbStudentSkillCandidate>([skill]));o.skillBundlePath=runtime.join("student-skills.json").toString();File.writeTo(Path(o.skillBundlePath),(bundle.json+"\n").toArray());o.skillBundleVersion=bundle.bundleVersion;o.skillBundleHash=bundle.canonicalHash;o.skillCount=bundle.skillCount;o.skillContentBytes=bundle.contentBytes;let sampling="{\"samplingControl\":\"provider_default_not_client_exposed\"}\n";o.samplingCapabilityPath=runtime.join("sampling.json").toString();File.writeTo(Path(o.samplingCapabilityPath),sampling.toArray());o.samplingCapabilityHash=benchmarkGapSha256(sampling);o.generationProtocol="completion-only-v1";o.samplesPerCase=1;o.outputSchemaHash=benchmarkGapSha256(ckbAbcdeCompletionOutputSchema());o.assetLineage="independent";o.lineageProofJson="{\"assetLineage\":\"independent\",\"source\":\"non_humaneval_seed\"}\n";o.lineageProofPath=runtime.join("lineage.json").toString();File.writeTo(Path(o.lineageProofPath),o.lineageProofJson.toArray());o.lineageProofHash=benchmarkGapSha256(o.lineageProofJson);o.runId=runId;o.outputRoot=output.toString();o.workspaceRoot=canonicalize(workspace).toString();o.runtimeHomeRoot=canonicalize(runtime).toString();o.frozenVersion=version;o.activeVersionAtStart=version;o.activeVersionAtEnd=version;o.expectedManifestHash=benchmarkGapSha256(authority);o.actualManifestHash=o.expectedManifestHash;o.modelVersion="GLM-5.2";o.claudeCodeVersion=claudeVersion;o.providerIdentityJson=provider;o.providerIdentityHash=benchmarkGapSha256(provider);o.certificationTransport=CkbAbcdeGroups.D;o.developmentClosureJson=r7Closure();o.knowledgeGateJson=r7Gate("knowledge");o.releaseGateJson=r7Gate("release");o.filesystemProbeJson="{\"deniedOutsideWorkspace\":true,\"deniedTests\":true,\"deniedReference\":true,\"deniedTeacher\":true,\"deniedStore\":true,\"workspaceCanonical\":\"${o.workspaceRoot}\",\"runtimeHomeCanonical\":\"${o.runtimeHomeRoot}\"}";let parity="{\"contentHash\":\"${benchmarkGapSha256("atom")}\",\"citation\":\"official\",\"knowledgeVersion\":\"${version}\"}";o.parityRestPayload=parity;o.parityStdioPayload=parity;o.parityHttpPayload=parity;o.parityEvidenceHash=benchmarkGapSha256(parity);o.candidateChecksum=checksum;o.studentLeakageProofJson=seal;o.studentLeakageProofHash=benchmarkGapSha256(seal);o.frozenCandidateManifestJson=frozen;o.frozenCandidateManifestHash=benchmarkGapSha256(frozen);o.budget.transportRetries=1;o.modelTimeoutSeconds=30;o
}

private func r7Fingerprint(o:CkbCertificationPreflightOptions,datasetVersion:String,authority:String):CkbFrozenFingerprintInput{let f=CkbFrozenFingerprintInput();f.knowledgeVersion=o.frozenVersion;f.knowledgeContentHash=o.candidateChecksum;f.datasetVersion=datasetVersion;f.manifestHash=benchmarkGapSha256(authority);f.modelVersion=o.modelVersion;f.claudeCodeVersion=o.claudeCodeVersion;f.promptHash=benchmarkGapSha256("r7-prompt");f.toolConfigHash=benchmarkGapSha256("r7-tool-config");f.providerIdentityHash=o.providerIdentityHash;f.certificationTransport=CkbAbcdeGroups.D;f.runtimeConfigHash=benchmarkGapSha256("r7-runtime");f.candidateChecksum=o.candidateChecksum;f.studentLeakageProofHash=o.studentLeakageProofHash;f.frozenCandidateManifestHash=o.frozenCandidateManifestHash;f.skillBundleVersion=o.skillBundleVersion;f.skillBundleHash=o.skillBundleHash;f.skillCount=o.skillCount;f.skillContentBytes=o.skillContentBytes;f.samplingCapabilityHash=o.samplingCapabilityHash;f.generationProtocol=o.generationProtocol;f.outputSchemaHash=o.outputSchemaHash;f.assetLineage=o.assetLineage;f.lineageProofHash=o.lineageProofHash;f}
private func r7Experiment(fingerprint:CkbFrozenFingerprintInput,dataset:String,manifest:String,claude:String,version:String,checksum:String):CkbContributionExperimentReport{let a=r7Arm("no-ckb",false,dataset,manifest,claude,"","");let b=r7Arm("frozen-ckb",true,dataset,manifest,claude,version,checksum);runCkbContributionExperiment(a,b,frozenFingerprint:ckbFrozenFingerprint(fingerprint))}
private func r7Arm(name:String,enabled:Bool,dataset:String,manifest:String,claude:String,version:String,checksum:String):CkbContributionArm{let a=CkbContributionArm();a.name=name;a.ckbEnabled=enabled;a.workspaceId="${name}-workspace";a.sessionId="${name}-session";a.runtimeHomeId="${name}-home";a.datasetVersion=dataset;a.manifestHash=manifest;a.modelVersion="GLM-5.2";a.claudeCodeVersion=claude;a.promptHash=benchmarkGapSha256("prompt");a.toolConfigHash=benchmarkGapSha256("tools");a.temperature="0";a.toolBudget=1;a.total=164;a.passed=if(enabled){164}else{100};a.knowledgeHits=if(enabled){164}else{0};a.failureClassificationHash=benchmarkGapSha256("${name}-classification");a.resultArtifactJson="{\"arm\":\"${name}\"}";a.resultArtifactHash=benchmarkGapSha256(a.resultArtifactJson);a.isolationSetJson="{\"arm\":\"${name}\",\"isolated\":true}";a.isolationSetHash=benchmarkGapSha256(a.isolationSetJson);a.frozenKnowledgeVersion=version;a.frozenKnowledgeContentHash=checksum;a}
private func r7Closure():String{var rows="";for(i in 0..164){if(i>0){rows+=","};rows+="{\"caseId\":\"${i}\",\"developmentPass\":true,\"valid\":true}"};"{\"developmentClosed\":true,\"developmentPassed\":164,\"developmentTotal\":164,\"knowledgeCandidateCount\":0,\"invalidCaseCount\":0,\"cases\":[${rows}]}"}
private func r7Gate(evidence:String):String{"{\"ok\":true,\"status\":\"pass\",\"evidence\":\"${evidence}\",\"evidenceHash\":\"${benchmarkGapSha256(evidence)}\"}"}
