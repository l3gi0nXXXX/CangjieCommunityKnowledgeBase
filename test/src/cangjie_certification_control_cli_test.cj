package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*
import std.fs.{Directory, File, Path, canonicalize, exists}
import std.process.*
import std.time.*

@Test
public class CangjieCertificationControlCliTest {
    @TestCase
    public func preflightRejectsDatasetVersionThatDoesNotMatchAuthority(): Unit {
        let root = Path("../target/control-authority-dataset-${DateTime.now().toUnixTimeStamp().toMilliseconds()}")
        Directory.create(root, recursive: true)
        let authority = cangjieHumanEvalRenderAuthorityManifest(
            buildCangjieHumanEvalManifest("cangjie_eval/cases/Cangjie-HumanEval", ""))
        let authorityPath = root.join("authority.jsonl")
        let activeStartPath = root.join("active-start.json")
        let activeEndPath = root.join("active-end.json")
        let controlPath = root.join("control.json")
        File.writeTo(authorityPath, authority.toArray())
        File.writeTo(activeStartPath, "{\"activeKnowledgeVersion\":\"knowledge-v1\"}".toArray())
        File.writeTo(activeEndPath, "{\"activeKnowledgeVersion\":\"knowledge-v1\"}".toArray())
        let control = "{" +
            "\"runId\":\"run-中文🙂\"," +
            "\"outputRoot\":\"${root.join("output")}\"," +
            "\"workspaceRoot\":\"${root.join("workspace")}\"," +
            "\"runtimeHomeRoot\":\"${root.join("runtime-home")}\"," +
            "\"frozenVersion\":\"knowledge-v1\"," +
            "\"activeStatusStartPath\":\"${activeStartPath}\"," +
            "\"activeStatusEndPath\":\"${activeEndPath}\"," +
            "\"modelVersion\":\"GLM-5.2\"," +
            "\"claudeCodeVersion\":\"2.1.179\"," +
            "\"certificationTransport\":\"C-ckb-mcp-stdio\"," +
            "\"authorityManifestPath\":\"${authorityPath}\"," +
            "\"datasetVersion\":\"旧版本🙂\"}"
        File.writeTo(controlPath, control.toArray())
        @Expect(runCkbCertificationPreflightCli([
            "--store", root.join("frozen-store").toString(),
            "cangjie-certification-preflight", "--control-manifest", controlPath.toString()],
            store: FileKnowledgeStore(root.join("frozen-store").toString())), 1)
    }

    @TestCase
    public func preflightRejectsDuplicateAndUnknownGlobalStoreArguments(): Unit {
        let store = FileKnowledgeStore("../target/control-store-args")
        @Expect(runCkbCertificationPreflightCli([
            "--store", "first", "--store", "second",
            "cangjie-certification-preflight", "--control-manifest", "control.json"],
            store: store), 2)
        @Expect(runCkbCertificationPreflightCli([
            "--store", "first", "--unexpected", "value",
            "cangjie-certification-preflight", "--control-manifest", "control.json"],
            store: store), 2)
        @Expect(runCkbCertificationPreflightCli([
            "--store", "--control-manifest", "control.json",
            "cangjie-certification-preflight"], store: store), 2)
    }

    @TestCase
    public func preflightCliArgumentContractIsFailClosedAndPreservesControlPath(): Unit {
        let valid = ckbCertificationPreflightCliArgs([
            "--store", "frozen-store", "cangjie-certification-preflight",
            "--control-manifest", "control.json"])
        @Expect(valid[0], "ok")
        @Expect(valid[1], "control.json")
        @Expect(ckbCertificationPreflightCliArgs([
            "cangjie-certification-preflight", "--control-manifest", "a.json",
            "--control-manifest", "b.json"])[0], "duplicate_argument:--control-manifest")
        @Expect(ckbCertificationPreflightCliArgs([
            "cangjie-certification-preflight", "--control-manifest"])[0],
            "missing_argument_value:--control-manifest")
        @Expect(ckbCertificationPreflightCliArgs([
            "cangjie-certification-preflight"])[0],
            "required_argument_missing:--control-manifest")
        @Expect(ckbCertificationPreflightCliArgs([
            "--store", "--control-manifest", "control.json",
            "cangjie-certification-preflight"])[0], "missing_argument_value:--store")
        @Expect(ckbCertificationPreflightCliArgs([
            "--unknown", "value", "cangjie-certification-preflight",
            "--control-manifest", "control.json"])[0], "unknown_argument:--unknown")
    }

    @TestCase
    public func preflightCliMainRoutesTheDeclaredFrozenStore(): Unit {
        let fixture = ckbPreflightStoreRouteFixture()
        @Expect(fixture.ready, true)
        if (!fixture.ready) { return }
        let correct = ckbStoreRouteRunCli([
            "--store", fixture.frozenStorePath, "cangjie-certification-preflight",
            "--control-manifest", fixture.controlPath])
        @Expect(correct.exitCode, 0)
        @Expect(exists(Path(fixture.outputRoot).join("preflight.json")), true)
        @Expect(exists(Path(fixture.outputRoot).join("run-manifest.json")), true)
        @Expect(ckbCertificationPreflightSealDiagnostic(
            String.fromUtf8(File.readFrom(Path(fixture.outputRoot).join("preflight.json"))),
            String.fromUtf8(File.readFrom(Path(fixture.outputRoot).join("run-manifest.json")))), "ok")
        let wrong = ckbStoreRouteRunCli([
            "--store", fixture.wrongStorePath, "cangjie-certification-preflight",
            "--control-manifest", fixture.controlPath])
        @Expect(wrong.exitCode, 1)
        @Expect((wrong.stdoutText + wrong.stderrText).trimAscii(),
            "preflight blocked: frozen_candidate_manifest_drift")
        let defaultStore = ckbStoreRouteRunCli([
            "cangjie-certification-preflight",
            "--control-manifest", fixture.controlPath])
        @Expect(defaultStore.exitCode, 1)
        @Expect((defaultStore.stdoutText + defaultStore.stderrText).trimAscii(),
            "preflight blocked: frozen_candidate_manifest_drift")
    }
}

private class CkbStoreRouteCliResult {
    var exitCode: Int64 = -1
    var stdoutText: String = ""
    var stderrText: String = ""
}

private class CkbPreflightStoreRouteFixture {
    var ready: Bool = false
    var controlPath: String = ""
    var frozenStorePath: String = ""
    var wrongStorePath: String = ""
    var outputRoot: String = ""
}

private func ckbStoreRouteRunCli(args: Array<String>): CkbStoreRouteCliResult {
    let root = Path("../target/control-store-cli-output-${DateTime.now().toUnixTimeStamp().toMilliseconds()}")
    Directory.create(root, recursive: true)
    let stdoutPath = root.join("stdout.log")
    let stderrPath = root.join("stderr.log")
    var command = ckbAbcdeNativeTlsBootstrapScript(
        canonicalize(Path("../target/release/bin/main")).toString(), args)
    command += " > " + ckbStoreRouteShellQuote(stdoutPath.toString()) +
        " 2> " + ckbStoreRouteShellQuote(stderrPath.toString())
    let process = launch("/bin/zsh", ["-c", command],
        stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
    let result = CkbStoreRouteCliResult()
    result.exitCode = process.wait()
    try {
        result.stdoutText = String.fromUtf8(File.readFrom(stdoutPath))
    } catch (_: Exception) {
        result.stdoutText = "invalid_response_encoding"
    }
    try {
        result.stderrText = String.fromUtf8(File.readFrom(stderrPath))
    } catch (_: Exception) {
        result.stderrText = "invalid_response_encoding"
    }
    result
}

private func ckbStoreRouteShellQuote(value: String): String {
    "'" + value.replace("'", "'\\''") + "'"
}

private func ckbPreflightStoreRouteFixture(): CkbPreflightStoreRouteFixture {
    let fixture = CkbPreflightStoreRouteFixture()
    let stamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    let root = Path("../target/control-store-route-${stamp}")
    Directory.create(root, recursive: true)
    let frozenStore = FileKnowledgeStore(root.join("frozen-store").toString())
    let kb = r7CleanKnowledgeBase()
    _ = kb.persistActiveSnapshot(frozenStore)
    let snapshot = frozenStore.loadActiveSnapshot()
    if (!snapshot.valid) { return fixture }
    let artifacts = ckbS2ReleaseV2ArtifactsForTest(snapshot.normalizedRecords)
    let trustSeal = ckbRenderCandidateTrustSeal(
        snapshot.normalizedRecords, artifacts[0], artifacts[1], artifacts[2],
        artifacts[3], restText: artifacts[4], mcpStdioText: artifacts[5],
        mcpHttpText: artifacts[6], anonymousQueryText: artifacts[7])
    let frozenOptions = CkbFrozenCandidateSealOptions()
    let checksum = ckbCertifiedNormalizedRecordsChecksum(snapshot.normalizedRecords)
    frozenOptions.expectedKnowledgeVersion = snapshot.activeVersion
    frozenOptions.expectedCandidateChecksum = checksum
    frozenOptions.inputHash = benchmarkGapSha256("store-route-input")
    frozenOptions.configHash = benchmarkGapSha256("store-route-config")
    frozenOptions.modelHash = benchmarkGapSha256("store-route-model")
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
    if (!frozen.ok) { return fixture }

    let authorityPath = root.join("authority.jsonl")
    let authority = cangjieHumanEvalRenderAuthorityManifest(
        buildCangjieHumanEvalManifest("cangjie_eval/cases/Cangjie-HumanEval", ""))
    let parsedAuthority = parseCangjieHumanEvalAuthorityManifest(authority)
    if (!parsedAuthority.ok || parsedAuthority.rows.size != 164) { return fixture }
    File.writeTo(authorityPath, authority.toArray())
    let datasetVersion = parsedAuthority.datasetVersion
    let manifestHash = benchmarkGapSha256(authority)
    let runId = "store-route-run"
    let outputRoot = root.join(runId)
    let workspace = root.join("workspace")
    let runtimeHome = root.join("runtime-home")
    let certificationRunRoot = root.join("certification-run")
    Directory.create(outputRoot, recursive: true)
    Directory.create(workspace, recursive: true)
    Directory.create(runtimeHome, recursive: true)
    Directory.create(certificationRunRoot, recursive: true)
    let configPath = root.join("runtime.conf")
    File.writeTo(configPath, "service.bind=127.0.0.1\nservice.port=19873\n".toArray())
    let activeStart = ckbStoreRouteWrite(root, "active-start.json",
        "{\"activeKnowledgeVersion\":\"${snapshot.activeVersion}\"}")
    let activeEnd = ckbStoreRouteWrite(root, "active-end.json",
        "{\"activeKnowledgeVersion\":\"${snapshot.activeVersion}\"}")
    let closure = ckbStoreRouteWrite(root, "development-closure.json",
        ckbStoreRouteClosure())
    let knowledgeGate = ckbStoreRouteWrite(root, "knowledge-gate.json",
        ckbStoreRouteGate("knowledge"))
    let releaseGate = ckbStoreRouteWrite(root, "release-gate.json",
        ckbStoreRouteGate("release"))
    let workspaceCanonical = canonicalize(workspace).toString()
    let runtimeCanonical = canonicalize(runtimeHome).toString()
    let filesystemProbe = ckbStoreRouteWrite(root, "filesystem-probe.json",
        "{\"deniedOutsideWorkspace\":true,\"deniedTests\":true,\"deniedReference\":true,\"deniedTeacher\":true,\"deniedStore\":true,\"workspaceCanonical\":\"${workspaceCanonical}\",\"runtimeHomeCanonical\":\"${runtimeCanonical}\"}")
    let provider = "{\"provider\":\"store-route-test\",\"model\":\"GLM-5.2\",\"claudeCodeVersion\":\"claude-code-1.0\"}"
    let providerPath = ckbStoreRouteWrite(root, "provider.json", provider)
    let parity = "{\"contentHash\":\"${benchmarkGapSha256("atom")}\",\"citation\":\"official\",\"knowledgeVersion\":\"${snapshot.activeVersion}\"}"
    let parityRest = ckbStoreRouteWrite(root, "parity-rest.json", parity)
    let parityStdio = ckbStoreRouteWrite(root, "parity-stdio.json", parity)
    let parityHttp = ckbStoreRouteWrite(root, "parity-http.json", parity)
    let leakagePath = ckbStoreRouteWrite(root, "leakage-proof.json", trustSeal)
    let frozenPath = ckbStoreRouteWrite(root, "frozen-manifest.json", frozen.manifestJson)
    let promptHash = benchmarkGapSha256("store-route-prompt")
    let toolHash = benchmarkGapSha256("store-route-tools")
    let control = "{" +
        "\"runId\":\"${runId}\",\"outputRoot\":\"${canonicalize(outputRoot)}\"," +
        "\"workspaceRoot\":\"${workspaceCanonical}\",\"runtimeHomeRoot\":\"${runtimeCanonical}\"," +
        "\"frozenVersion\":\"${snapshot.activeVersion}\",\"activeStatusStartPath\":\"${activeStart}\",\"activeStatusEndPath\":\"${activeEnd}\"," +
        "\"modelVersion\":\"GLM-5.2\",\"claudeCodeVersion\":\"claude-code-1.0\",\"certificationTransport\":\"${CkbAbcdeGroups.D}\"," +
        "\"transportRetryBudget\":2,\"modelTimeoutSeconds\":30," +
        "\"certificationBinaryPath\":\"${canonicalize(Path("../target/release/bin/main"))}\"," +
        "\"certificationConfigPath\":\"${canonicalize(configPath)}\",\"certificationStorePath\":\"${canonicalize(frozenStore.root)}\"," +
        "\"certificationRunRoot\":\"${canonicalize(certificationRunRoot)}\",\"ckbHttpBase\":\"http://127.0.0.1:19873\"," +
        "\"authorityManifestPath\":\"${canonicalize(authorityPath)}\",\"datasetVersion\":\"${datasetVersion}\",\"authorityManifestHash\":\"${manifestHash}\"," +
        "\"developmentClosurePath\":\"${closure}\",\"knowledgeGatePath\":\"${knowledgeGate}\",\"releaseGatePath\":\"${releaseGate}\"," +
        "\"filesystemProbePath\":\"${filesystemProbe}\",\"providerIdentityPath\":\"${providerPath}\"," +
        "\"parityRestPath\":\"${parityRest}\",\"parityStdioPath\":\"${parityStdio}\",\"parityHttpPath\":\"${parityHttp}\"," +
        "\"knowledgeContentHash\":\"${checksum}\",\"studentLeakageProofPath\":\"${leakagePath}\",\"frozenCandidateManifestPath\":\"${frozenPath}\"," +
        "\"promptHash\":\"${promptHash}\",\"toolConfigHash\":\"${toolHash}\",\"runtimeConfigHash\":\"${benchmarkGapSha256("store-route-runtime")}\"}"
    let controlPath = ckbStoreRouteWrite(root, "control.json", control)
    let wrongStore = root.join("wrong-store")
    Directory.create(wrongStore, recursive: true)
    fixture.controlPath = controlPath
    fixture.frozenStorePath = canonicalize(frozenStore.root).toString()
    fixture.wrongStorePath = canonicalize(wrongStore).toString()
    fixture.outputRoot = canonicalize(outputRoot).toString()
    fixture.ready = true
    fixture
}

private func ckbStoreRouteWrite(root: Path, name: String, content: String): String {
    let path = root.join(name)
    File.writeTo(path, content.toArray())
    canonicalize(path).toString()
}

private func ckbStoreRouteClosure(): String {
    var rows = ""
    for (i in 0..164) {
        if (i > 0) { rows += "," }
        rows += "{\"caseId\":\"CJ-HUMANEVAL-${i}\",\"developmentPass\":true,\"valid\":true}"
    }
    "{\"developmentClosed\":true,\"developmentPassed\":164,\"developmentTotal\":164,\"knowledgeCandidateCount\":0,\"invalidCaseCount\":0,\"cases\":[${rows}]}"
}

private func ckbStoreRouteGate(evidence: String): String {
    "{\"ok\":true,\"status\":\"pass\",\"evidence\":\"${evidence}\",\"evidenceHash\":\"${benchmarkGapSha256(evidence)}\"}"
}
