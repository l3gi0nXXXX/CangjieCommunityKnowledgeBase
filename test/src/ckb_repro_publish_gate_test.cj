package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.time.DateTime
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.json.JsonValue

private class P9FakeGitProvider <: CkbReproGitEvidenceProvider {
    public let evidence: CkbReproGitEvidence
    public var calls: Int64 = 0
    public init(value: CkbReproGitEvidence) { this.evidence = value }
    public func inspect(): CkbReproGitEvidence {
        this.calls += 1
        this.evidence
    }
}

private class P9FakeSignatureVerifier <: CkbReproSignatureVerifier {
    public let evidence: CkbReproSignatureEvidence
    public var calls: Int64 = 0
    public init(value: CkbReproSignatureEvidence) { this.evidence = value }
    public func verify(): CkbReproSignatureEvidence {
        this.calls += 1
        this.evidence
    }
}

private class P9FakePublishCliExecutor <: CkbReproPublishGateCliExecutor {
    public var bundleExists: Bool = true
    public var calls: Int64 = 0
    public var result: CkbReproPublishGateResult
    public init(value: CkbReproPublishGateResult) { this.result = value }
    public func exists(path: String): Bool { this.bundleExists }
    public func evaluate(options: CkbReproPublishGateCliOptions):
        CkbReproPublishGateResult {
        this.calls += 1
        this.result
    }
}

@Test
public class CkbReproPublishGateTest {
    @TestCase
    public func p9Pos01PublishGateContractComponent(): Unit {
        let options = p9GateOptions("pre-tag")
        let git = P9FakeGitProvider(p9GitEvidence(false))
        let signature = P9FakeSignatureVerifier(p9SignatureEvidence(false))
        let result = validateCkbReproPublishBundle(options,
            p9PublishEvidence(), git, signature)
        @Expect(result.componentReady, true)
        @Expect(result.publishable, false)
        @Expect(result.diagnostic, "component_ready_external_proofs_required")
        @Expect(git.calls, 1)
        @Expect(signature.calls, 1)

        let post = p9GateOptions("post-tag")
        let postResult = validateCkbReproPublishBundle(post,
            p9PublishEvidence(),
            P9FakeGitProvider(p9GitEvidence(true)),
            P9FakeSignatureVerifier(p9SignatureEvidence(true)))
        @Expect(postResult.componentReady, true)
        @Expect(postResult.publishable, false)

        let productionSource = String.fromUtf8(File.readFrom(
            Path("../src/ckb_repro_publish_gate.cj")))
        @Expect(productionSource.contains(
            "public class CkbReproFilesystemPublishAuthentication"), false)
        @Expect(productionSource.contains(
            "public func finalizeCkbReproFilesystemPublishResult"), false)

        let cliOptions = parseCkbReproPublishGateCliArgs([
            "ckb-repro-publish-gate", "--mode", "pre-tag", "--bundle",
            "/tmp/发布 资料/final"
        ])
        @Expect(cliOptions.valid, true)
        let cliExecutor = P9FakePublishCliExecutor(result)
        let cli = executeCkbReproPublishGateCliAdapter(cliOptions, cliExecutor)
        @Expect(cli.componentReady, true)
        @Expect(cliExecutor.calls, 1)
        @Expect(renderCkbReproPublishGateCliHuman(cli).contains("{\""), false)
        @Expect(renderCkbReproPublishGateCliJson(cli).startsWith("{"), true)
        let controlResult = CkbReproPublishGateResult()
        controlResult.diagnostic = "blocked\u{0001}🙂"
        @Expect(try { JsonValue.fromStr(
            renderCkbReproPublishGateReport(controlResult)); true }
            catch (_: Exception) { false }, true)
    }

    @TestCase
    public func p9Neg01PublishGateContractComponent(): Unit {
        let bad = p9PublishEvidence()
        bad.leakageFindingCount = 1
        let result = validateCkbReproPublishBundle(p9GateOptions("pre-tag"),
            bad, P9FakeGitProvider(p9GitEvidence(false)),
            P9FakeSignatureVerifier(p9SignatureEvidence(false)))
        @Expect(result.componentReady, false)
        @Expect(result.diagnostic, "publish_leakage_gate_failed")
        let drift = p9GitEvidence(false)
        drift.originRepository = "other/repository"
        @Expect(validateCkbTagReleaseBindingEvidence(p9GateOptions("pre-tag"),
            drift, p9SignatureEvidence(false)).diagnostic,
            "publish_repository_mismatch")
        let invalidIdentity = p9GateOptions("pre-tag")
        invalidIdentity.signingFingerprint = "short"
        @Expect(validateCkbTagReleaseBindingEvidence(invalidIdentity,
            p9GitEvidence(false), p9SignatureEvidence(false)).diagnostic,
            "publish_identity_invalid")
        let rendered = renderCkbReproPublishGateReport(result)
        @Expect(rendered.contains("/Users/"), false)
        @Expect(rendered.contains("Authorization"), false)
        let handcrafted = p9PublishEvidence()
        handcrafted.externalProofsVerified = true
        let blocked = validateCkbReproPublishBundle(p9GateOptions("pre-tag"),
            handcrafted, P9FakeGitProvider(p9GitEvidence(false)),
            P9FakeSignatureVerifier(p9SignatureEvidence(false)))
        @Expect(blocked.componentReady, true)
        @Expect(blocked.publishable, false)

        @Expect(parseCkbReproPublishGateCliArgs([
            "ckb-repro-publish-gate", "--mode", "invalid", "--bundle",
            "/tmp/final"]).diagnostic, "publish_mode_invalid")
        @Expect(parseCkbReproPublishGateCliArgs([
            "ckb-repro-publish-gate", "--mode", "pre-tag", "--bundle",
            "relative/final"]).diagnostic, "publish_bundle_root_invalid")
        let missingExecutor = P9FakePublishCliExecutor(result)
        missingExecutor.bundleExists = false
        let missing = executeCkbReproPublishGateCliAdapter(
            parseCkbReproPublishGateCliArgs([
                "ckb-repro-publish-gate", "--mode", "pre-tag", "--bundle",
                "/tmp/final"]), missingExecutor)
        @Expect(missing.diagnostic, "publish_bundle_root_missing")
        @Expect(missingExecutor.calls, 0)

        let local = CkbReproPublishLocalEvidence()
        local.gateOptions = p9GateOptions("pre-tag")
        local.evidence = p9PublishEvidence()
        let hash = ckbReproBundleHash("evidence".toArray())
        let renderedLocal = renderCkbReproPublishLocalEvidence(
            local, hash, hash)
        @Expect(parseCkbReproPublishLocalEvidence(
            renderedLocal.toArray()).valid, true)
        @Expect(parseCkbReproPublishLocalEvidence([0xff, 0xfe]).diagnostic,
            "invalid_response_encoding")
        @Expect(parseCkbReproPublishLocalEvidence("{bad".toArray()).diagnostic,
            "malformed_json")
        @Expect(parseCkbReproPublishLocalEvidence(renderedLocal.replace(
            "}", ",\"unknown\":true}").toArray()).diagnostic,
            "publish_local_evidence_field_contract_invalid")
        @Expect(parseCkbReproPublishLocalEvidence(renderedLocal.replace(
            "\"strictPassed\":151", "\"strictPassed\":150").toArray()).diagnostic,
            "publish_local_evidence_hash_mismatch")
        @Expect(runCkbReproPublishGateCliAdapter(
            parseCkbReproPublishGateCliArgs([
                "ckb-repro-publish-gate", "--mode", "pre-tag", "--bundle",
                "/tmp/not-ready-final-bundle"])).diagnostic,
            "publish_bundle_root_missing")

        let fixture = p9PublishLocalFixture()
        let loadedFixture = loadCkbReproPublishLocalEvidence(fixture)
        @Expect(loadedFixture.diagnostic, "ok")
        @Expect(loadedFixture.valid, true)
        File.writeTo(Path(fixture).join("verification-report.json"),
            "{\"tampered\":true}".toArray())
        @Expect(loadCkbReproPublishLocalEvidence(fixture).diagnostic,
            "publish_bundle_evidence_hash_mismatch")
        remove(Path(fixture), recursive: true)
    }

    @TestCase
    public func p9Neg01RemoteTagSnapshotMustBeIndependentAndFresh(): Unit {
        let preMissing = p9GitEvidence(false)
        preMissing.remoteTagSnapshotAvailable = false
        preMissing.remoteTagSnapshotFresh = false
        @Expect(validateCkbTagReleaseBindingEvidence(p9GateOptions("pre-tag"),
            preMissing, p9SignatureEvidence(false)).diagnostic,
            "publish_remote_tag_evidence_unavailable")

        let preAbsent = p9GitEvidence(false)
        preAbsent.remoteTagSnapshotAvailable = true
        preAbsent.remoteTagSnapshotFresh = true
        preAbsent.remoteTagState = "absent"
        @Expect(validateCkbTagReleaseBindingEvidence(p9GateOptions("pre-tag"),
            preAbsent, p9SignatureEvidence(false)).componentReady, true)

        let localOnly = p9GitEvidence(true)
        localOnly.remoteTagSnapshotAvailable = true
        localOnly.remoteTagSnapshotFresh = true
        localOnly.remoteTagState = "absent"
        localOnly.tagExistsRemote = false
        localOnly.remoteTagCommit = ""
        @Expect(validateCkbTagReleaseBindingEvidence(p9GateOptions("post-tag"),
            localOnly, p9SignatureEvidence(true)).diagnostic,
            "publish_tag_binding_mismatch")

        let remoteOnly = p9GitEvidence(false)
        remoteOnly.remoteTagSnapshotAvailable = true
        remoteOnly.remoteTagSnapshotFresh = true
        remoteOnly.remoteTagState = "present"
        remoteOnly.tagExistsRemote = true
        remoteOnly.remoteTagCommit = remoteOnly.headCommit
        @Expect(validateCkbTagReleaseBindingEvidence(p9GateOptions("post-tag"),
            remoteOnly, p9SignatureEvidence(true)).diagnostic,
            "publish_tag_binding_mismatch")

        let both = p9GitEvidence(true)
        both.remoteTagSnapshotAvailable = true
        both.remoteTagSnapshotFresh = true
        both.remoteTagState = "present"
        both.remoteTagCommit = both.headCommit
        @Expect(validateCkbTagReleaseBindingEvidence(p9GateOptions("post-tag"),
            both, p9SignatureEvidence(true)).componentReady, true)

        let stale = p9GitEvidence(false)
        stale.remoteTagSnapshotAvailable = true
        stale.remoteTagSnapshotFresh = false
        stale.remoteTagState = "absent"
        @Expect(validateCkbTagReleaseBindingEvidence(p9GateOptions("pre-tag"),
            stale, p9SignatureEvidence(false)).diagnostic,
            "publish_remote_tag_evidence_stale")
    }
}

private func p9PublishLocalFixture(): String {
    let root = Path("target/ckb-repro-publish-local")
    if (exists(root)) { remove(root, recursive: true) }
    Directory.create(root.join("assets"), recursive: true)
    let canonicalRoot = canonicalize(root).toString()
    let asset = p9PublishAsset("assets/input.txt", "仓颉🙂".toArray(),
        "portable_report")
    let reference = p9PublishReferenceManifest()
    let referenceBytes = renderCkbReproReferenceManifest(reference).toArray()
    let referenceAsset = p9PublishAsset(
        "reproducibility/manifests/reference-run.json", referenceBytes,
        "p8_reference")
    let leakageAsset = p9PublishAsset("leakage-report.json",
        ("{\"schemaVersion\":\"ckb-repro-leakage-report-v1\"," +
        "\"findingCount\":0,\"pathFindingCount\":0}").toArray(),
        "portable_report")
    let licenseAsset = p9PublishAsset(
        "reproducibility/licenses/THIRD_PARTY_NOTICES.md",
        "fixture license evidence".toArray(), "license")
    let assets = ArrayList<CkbReproBundleAsset>()
    assets.add(asset)
    assets.add(referenceAsset)
    assets.add(leakageAsset)
    assets.add(licenseAsset)
    let manifest = writeCkbReproReleaseManifest(assets)
    let verification = "{\"schemaVersion\":\"ckb-repro-verification-report-v1\"," +
        "\"ok\":true,\"diagnostic\":\"verified\"," +
        "\"verifiedReleaseInputSetHash\":\"${computeCkbReproBundleInputSetHash(assets)}\"," +
        "\"bundleProofSetHash\":\"${ckbReproBundleHash("proof".toArray())}\"," +
        "\"releaseCommit\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," +
        "\"certifiedRunInputHash\":\"${ckbReproBundleHash("input".toArray())}\"," +
        "\"runCriticalTreeHash\":\"${reference.runCriticalTreeHash}\"," +
        "\"referenceManifestHash\":\"${ckbReproBundleHash(referenceBytes)}\"," +
        "\"authorityHash\":\"${ckbReproBundleHash("authority".toArray())}\"," +
        "\"restoreOk\":true,\"restoreDiagnostic\":\"ok\"," +
        "\"rebuildOk\":true,\"rebuildDiagnostic\":\"ok\"," +
        "\"publicEvidenceOk\":true,\"publicEvidenceDiagnostic\":\"ok\"," +
        "\"documentationOk\":true,\"documentationDiagnostic\":\"ok\"," +
        "\"runnerCalls\":0}"
    let attestation = buildCkbReproBuildAttestation(
        verification.toArray(), manifest.toArray())[1]
    let local = CkbReproPublishLocalEvidence()
    local.gateOptions = p9GateOptions("pre-tag")
    local.evidence = p9PublishEvidence()
    let localText = renderCkbReproPublishLocalEvidence(local,
        ckbReproBundleHash(verification.toArray()),
        ckbReproBundleHash(attestation.toArray()))
    let observed = DateTime.now().toUnixTimeStamp().toMilliseconds()
    let expires = observed + 600000
    let remoteSeed = "ckb-repro-remote-tag-evidence-v1|" +
        "git@github.com:l3gi0nXXXX/CangjieCommunityKnowledgeBase.git|" +
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|ckb-repro-v1|absent||" +
        "${observed}|${expires}|git-ls-remote-tags-refs|true"
    let remote = "{\"schemaVersion\":\"ckb-repro-remote-tag-evidence-v1\"," +
        "\"originRepository\":\"git@github.com:l3gi0nXXXX/CangjieCommunityKnowledgeBase.git\"," +
        "\"originMainCommit\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," +
        "\"tagName\":\"ckb-repro-v1\",\"state\":\"absent\"," +
        "\"tagCommit\":\"\",\"observedAtMillis\":${observed}," +
        "\"expiresAtMillis\":${expires}," +
        "\"queryKind\":\"git-ls-remote-tags-refs\"," +
        "\"querySucceeded\":true," +
        "\"evidenceHash\":\"${ckbReproBundleHash(remoteSeed.toArray())}\"}"
    let files = [
        (asset.relativePath, asset.bytes),
        (referenceAsset.relativePath, referenceAsset.bytes),
        (leakageAsset.relativePath, leakageAsset.bytes),
        (licenseAsset.relativePath, licenseAsset.bytes),
        ("RELEASE-MANIFEST.json", manifest.toArray()),
        ("verification-report.json", verification.toArray()),
        ("build-attestation.json", attestation.toArray()),
        ("PUBLISH-EVIDENCE.json", localText.toArray()),
        ("REMOTE-TAG-EVIDENCE.json", remote.toArray())
    ]
    var sums = ""
    for (item in files) {
        let target = Path(canonicalRoot).join(item[0])
        if (!exists(target.parent)) {
            Directory.create(target.parent, recursive: true)
        }
        File.writeTo(target, item[1])
        sums += "${ckbReproBundleHash(item[1]).replace("sha256:", "")}  ${item[0]}\n"
    }
    File.writeTo(Path(canonicalRoot).join("SHA256SUMS"), sums.toArray())
    File.writeTo(Path(canonicalRoot).join("SHA256SUMS.sig"), "fake-signature".toArray())
    File.writeTo(Path(canonicalRoot).join("REMOTE-TAG-EVIDENCE.json.sig"),
        "fake-remote-attestation-signature".toArray())
    canonicalRoot
}

private func p9PublishAsset(path: String, bytes: Array<UInt8>,
    role: String): CkbReproBundleAsset {
    let asset = CkbReproBundleAsset()
    asset.relativePath = path; asset.bytes = bytes; asset.size = bytes.size
    asset.sha256 = ckbReproBundleHash(bytes)
    asset.inputKind = "verified_input"; asset.role = role
    asset.logicalAsset = path; asset.partIndex = 0; asset.partCount = 1
    asset.logicalSize = asset.size; asset.logicalSha256 = asset.sha256
    asset
}

private func p9PublishReferenceManifest(): CkbReproReferenceManifest {
    let reference = CkbReproReferenceManifest()
    reference.schemaVersion = "ckb-repro-reference-v1"
    reference.baselineKind = "portable_release"
    reference.evidenceStatus = "complete"
    reference.releaseRepository =
        "l3gi0nXXXX/CangjieCommunityKnowledgeBase"
    reference.releaseRepositoryUrl =
        "https://github.com/l3gi0nXXXX/CangjieCommunityKnowledgeBase"
    reference.releaseBranch = "main"
    reference.observedRemote =
        "git@github.com:l3gi0nXXXX/CangjieCommunityKnowledgeBase.git"
    reference.runId = "fixture-run"; reference.knowledgeVersion = "fixture-v1"
    reference.vectorProofHash = ckbReproBundleHash("vector".toArray())
    reference.datasetVersion = "fixture-dataset"
    reference.runnerCommit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    reference.claudeCodeVersion = "fixture-cli"; reference.model = "glm-5.2"
    reference.providerFingerprint = ckbReproBundleHash("provider".toArray())
    reference.experimentGroup = "D"; reference.toolTransport = "mcp"
    reference.mcpTransport = "stdio"; reference.ckbRequired = true
    reference.localDocsPolicy = "disabled"; reference.modelEffort = "high"
    reference.modelBudget = "unbounded"; reference.timeoutSeconds = 3600
    reference.transportRetryBudget = 0
    reference.promptHash = ckbReproBundleHash("prompt".toArray())
    reference.resultsHash = ckbReproBundleHash("results".toArray())
    reference.runCriticalTreeHash = ckbReproBundleHash("tree".toArray())
    reference.certifiedRunInputHash = ckbReproBundleHash("input".toArray())
    reference.totalCases = 164; reference.rawPassed = 158
    reference.strictPassed = 151; reference.strictFailed = 13
    reference.businessFailed = 10; reference.protocolInvalid = 3
    reference.transportUnresolved = 0
    reference
}

private func p9GateOptions(mode: String): CkbReproPublishGateOptions {
    let options = CkbReproPublishGateOptions()
    options.mode = mode
    options.releaseRepository = "l3gi0nXXXX/CangjieCommunityKnowledgeBase"
    options.releaseCommit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    options.tagName = "ckb-repro-v1"
    options.releaseTitle = "CKB reproducible knowledge v1"
    options.signingFingerprint =
        "0123456789ABCDEF0123456789ABCDEF01234567"
    options
}

private func p9GitEvidence(tagExists: Bool): CkbReproGitEvidence {
    let evidence = CkbReproGitEvidence()
    evidence.originRepository = "git@github.com:l3gi0nXXXX/CangjieCommunityKnowledgeBase.git"
    evidence.headCommit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    evidence.originMainCommit = evidence.headCommit
    evidence.tagExistsLocal = tagExists
    evidence.tagExistsRemote = tagExists
    evidence.tagCommit = if (tagExists) { evidence.headCommit } else { "" }
    evidence.remoteTagSnapshotAvailable = true
    evidence.remoteTagSnapshotFresh = true
    evidence.remoteTagState = if (tagExists) { "present" } else { "absent" }
    evidence.remoteTagCommit = if (tagExists) { evidence.headCommit } else { "" }
    evidence
}

private func p9SignatureEvidence(tagSigned: Bool): CkbReproSignatureEvidence {
    let evidence = CkbReproSignatureEvidence()
    evidence.shaSumsVerified = true
    evidence.shaSumsFingerprint =
        "0123456789ABCDEF0123456789ABCDEF01234567"
    evidence.tagSigned = tagSigned
    evidence.tagFingerprint = if (tagSigned) {
        evidence.shaSumsFingerprint
    } else { "" }
    evidence
}

private func p9PublishEvidence(): CkbReproPublishEvidence {
    let evidence = CkbReproPublishEvidence()
    evidence.inputSetHashMatches = true
    evidence.manifestCoverageComplete = true
    evidence.shaCoverageComplete = true
    evidence.noSelfReference = true
    evidence.p8BindingMatches = true
    evidence.runCriticalTreeMatches = true
    evidence.strictPassed = 151
    evidence.transportUnresolved = 0
    evidence.leakageFindingCount = 0
    evidence.fullTestsPassed = true
    evidence.licenseComplete = true
    evidence.externalProofsVerified = false
    evidence
}
