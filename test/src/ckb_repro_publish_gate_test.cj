package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.io.InputStream
import std.process.{ProcessRedirect, launch}
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

private class P9FakeFilesystemAuthentication <:
    CkbReproPublishAuthenticationProvider {
    public func readGit(options: CkbReproPublishGateOptions,
        root: String): (String, CkbReproGitEvidence) {
        ("ok", p9GitEvidence(false))
    }
    public func readSignature(root: String,
        options: CkbReproPublishGateOptions,
        mode: String): (String, CkbReproSignatureEvidence) {
        ("ok", p9SignatureEvidence(false))
    }
}

private class P9FakeGpgvRunner <: CkbReproGpgvRunner {
    public var calls: Int64 = 0
    public var command: String = ""
    public var args: Array<String> = Array<String>()
    public var output: String =
        "[GNUPG:] VALIDSIG 0123456789ABCDEF0123456789ABCDEF01234567 20260801"
    public func run(value: String, arguments: Array<String>): (Int64, String) {
        this.calls += 1; this.command = value; this.args = arguments
        (0, this.output)
    }
}

private class P9RealGpgvRunner <: CkbReproGpgvRunner {
    public func run(command: String, args: Array<String>): (Int64, String) {
        let result = p9TestCommand(command, args)
        if (result[1] != "ok") { return (127, "") }
        (result[0], result[2])
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

        let aboveFloor = p9PublishEvidence()
        aboveFloor.strictPassed = 152
        @Expect(validateCkbReproPublishBundle(options, aboveFloor,
            P9FakeGitProvider(p9GitEvidence(false)),
            P9FakeSignatureVerifier(p9SignatureEvidence(false)))
            .componentReady, true)

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
        @Expect(productionSource.split("runner.run(\"gpgv\"").size - 1, 1)
        @Expect(productionSource.contains("p9PublishCommand(\"gpg\""), false)
        @Expect(productionSource.split("--keyring").size - 1, 1)
        @Expect(productionSource.contains("signed-remote-tag-attestation"), true)

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
    public func p9Pos02FilesystemProductionDerivesExternalProofs(): Unit {
        let fixture = p9PublishLocalFixture()
        let loaded = loadCkbReproPublishLocalEvidence(fixture)
        @Expect(loaded.valid, true)
        @Expect(loaded.evidence.externalProofsVerified, true)
        let options = parseCkbReproPublishGateCliArgs([
            "ckb-repro-publish-gate", "--mode", "pre-tag", "--bundle",
            fixture])
        let executor = CkbReproFilesystemPublishGateCliExecutor(
            P9FakeFilesystemAuthentication())
        let published = executeCkbReproPublishGateCliAdapter(options, executor)
        @Expect(published.publishable, true)
        @Expect(published.diagnostic, "ok")

        remove(Path(fixture), recursive: true)
        for (proof in ["fixture/p5_public_evidence.txt",
            "reproducibility/manifests/reference-run.json",
            "full-test-report.json", "leakage-report.json",
            "reproducibility/licenses/THIRD_PARTY_NOTICES.md",
            "verification-report.json", "build-attestation.json"]) {
            let missingFixture = p9PublishLocalFixture()
            remove(Path(missingFixture).join(proof))
            let missingOptions = parseCkbReproPublishGateCliArgs([
                "ckb-repro-publish-gate", "--mode", "pre-tag", "--bundle",
                missingFixture])
            @Expect(executeCkbReproPublishGateCliAdapter(
                missingOptions, executor).publishable, false)
            remove(Path(missingFixture), recursive: true)
        }
        let tamperedFixture = p9PublishLocalFixture()
        File.writeTo(Path(tamperedFixture).join("fixture/p5_public_evidence.txt"),
            "tampered-authority-proof".toArray())
        let tamperedOptions = parseCkbReproPublishGateCliArgs([
            "ckb-repro-publish-gate", "--mode", "pre-tag", "--bundle",
            tamperedFixture])
        @Expect(executeCkbReproPublishGateCliAdapter(
            tamperedOptions, executor).publishable, false)
        remove(Path(tamperedFixture), recursive: true)
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
        let manifestBytes = File.readFrom(Path(fixture).join(
            "RELEASE-MANIFEST.json"))
        let reportBytes = File.readFrom(Path(fixture).join(
            "verification-report.json"))
        @Expect(validateCkbReproPublishBindings(
            fixture, manifestBytes, reportBytes).ok, true)
        let parsedFixtureManifest = parseCkbReproBundleManifest(manifestBytes)[1]
        for (role in ["full_test_clean_log", "full_test_build_log",
            "full_test_test_log", "full_test_topology", "full_test_runner",
            "full_test_source"]) {
            var count: Int64 = 0
            for (asset in parsedFixtureManifest.assets) {
                if (asset.role == role) { count += 1 }
            }
            @Expect(count, Int64(1))
        }
        for (field in ["bundleProofSetHash", "certifiedRunInputHash",
            "authorityHash", "referenceManifestHash",
            "runCriticalTreeHash"]) {
            let reportObject = JsonValue.fromStr(
                String.fromUtf8(reportBytes)).asObject()
            let original = reportObject.get(field).getOrThrow()
                .asString().getValue()
            let forged = String.fromUtf8(reportBytes).replace(
                original, ckbReproBundleHash("forged-${field}".toArray()))
            @Expect(validateCkbReproPublishBindings(
                fixture, manifestBytes, forged.toArray()).ok, false)
        }
        let testLogPath = Path(fixture).join("full-test/test.log")
        let originalTestLog = File.readFrom(testLogPath)
        File.writeTo(testLogPath, "forged-test-log".toArray())
        @Expect(validateCkbReproPublishBindings(
            fixture, manifestBytes, reportBytes).ok, false)
        File.writeTo(testLogPath, originalTestLog)

        let remote = File.readFrom(Path(fixture).join(
            "REMOTE-TAG-EVIDENCE.json"))
        let remoteSignature = File.readFrom(Path(fixture).join(
            "REMOTE-TAG-EVIDENCE.json.sig"))
        for (name in ["PUBLISH-EVIDENCE.json", "REMOTE-TAG-EVIDENCE.json",
            "REMOTE-TAG-EVIDENCE.json.sig", "SHA256SUMS",
            "SHA256SUMS.sig"]) {
            remove(Path(fixture).join(name))
        }
        @Expect(prepareCkbReproPreSignatureArtifacts(fixture,
            p9GateOptions("pre-tag"), remote, remoteSignature).ok, true)
        for (name in ["PUBLISH-EVIDENCE.json", "REMOTE-TAG-EVIDENCE.json",
            "REMOTE-TAG-EVIDENCE.json.sig", "SHA256SUMS"]) {
            @Expect(exists(Path(fixture).join(name)), true)
        }
        @Expect(exists(Path(fixture).join("SHA256SUMS.sig")), false)
        let rebuiltSums = String.fromUtf8(File.readFrom(
            Path(fixture).join("SHA256SUMS")))
        @Expect(rebuiltSums.contains("  PUBLISH-EVIDENCE.json\n"), true)
        @Expect(rebuiltSums.contains("  REMOTE-TAG-EVIDENCE.json\n"), true)
        @Expect(rebuiltSums.contains("  SHA256SUMS\n"), false)
        @Expect(rebuiltSums.contains("  SHA256SUMS.sig\n"), false)
        @Expect(rebuiltSums.contains(
            "  REMOTE-TAG-EVIDENCE.json.sig\n"), false)
        File.writeTo(Path(fixture).join("SHA256SUMS.sig"),
            "fake-signature".toArray())
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

    @TestCase
    public func p9Bnd02RemoteTagUsesExactAuthoritativeRefs(): Unit {
        let object = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        let commit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        let tag = "ckb-repro-v1"
        let absent = parseCkbRemoteTagLsRemote("", tag)
        @Expect(absent[0], "ok"); @Expect(absent[1], false)
        let lightweight = parseCkbRemoteTagLsRemote(
            "${commit}\trefs/tags/${tag}\n", tag)
        @Expect(lightweight[0], "publish_remote_tag_query_invalid")
        let annotated = parseCkbRemoteTagLsRemote(
            "${object}\trefs/tags/${tag}\n" +
            "${commit}\trefs/tags/${tag}^{}\n", tag)
        @Expect(annotated[0], "ok"); @Expect(annotated[2], object)
        @Expect(annotated[3], commit)
        for (forged in [
            "${commit}\trefs/tags/${tag}-old\n",
            "${commit}\trefs/tags/${tag}\n${commit}\trefs/tags/${tag}\n",
            "${commit}\trefs/tags/${tag}^{}\n",
            "not-a-commit\trefs/tags/${tag}\n",
            "${commit}\trefs/heads/main\n"
        ]) {
            @Expect(parseCkbRemoteTagLsRemote(forged, tag)[0],
                "publish_remote_tag_query_invalid")
        }
        let source = String.fromUtf8(File.readFrom(
            Path("../src/ckb_repro_publish_gate.cj")))
        @Expect(source.contains("\"ls-remote\", \"--tags\", \"origin\","), true)
        @Expect(source.contains("\"refs/tags/\${tagName}\","), true)
        @Expect(source.contains("\"refs/tags/\${tagName}^{}\"]"), true)
        @Expect(source.contains("refs/remotes/origin/tags"), false)
    }

    @TestCase
    public func p9Neg05GitEvidenceUsesCanonicalAuthorityRoot(): Unit {
        let created = p9TestCommand("mktemp",
            ["-d", "/tmp/ckb-p9-git-root-XXXXXX"])
        if (created[0] != 0 || created[1] != "ok" ||
            created[2].trimAscii() == "") {
            throw Exception("test temporary directory unavailable")
        }
        let base = Path(created[2].trimAscii())
        let origin = base.join("origin.git")
        let authority = base.join("authority")
        try {
            p9TestCommandOk("git", ["init", "--bare", origin.toString()])
            p9TestCommandOk("git", ["init", authority.toString()])
            p9TestCommandOk("git", ["-C", authority.toString(), "config",
                "user.name", "Metis Repro Test"])
            p9TestCommandOk("git", ["-C", authority.toString(), "config",
                "user.email", "repro@example.invalid"])
            File.writeTo(authority.join("authority.txt"),
                "authority repository\n".toArray())
            p9TestCommandOk("git", ["-C", authority.toString(), "add",
                "authority.txt"])
            p9TestCommandOk("git", ["-C", authority.toString(), "commit",
                "-m", "authority commit"])
            p9TestCommandOk("git", ["-C", authority.toString(), "branch",
                "-M", "main"])
            p9TestCommandOk("git", ["-C", authority.toString(), "remote",
                "add", "origin", "../origin.git"])
            p9TestCommandOk("git", ["-C", authority.toString(), "push",
                "-u", "origin", "main"])
            p9TestCommandOk("git", ["-C", authority.toString(), "tag",
                "-a", "ckb-repro-v1", "-m", "release tag"])
            p9TestCommandOk("git", ["-C", authority.toString(), "push",
                "origin", "refs/tags/ckb-repro-v1"])
            p9TestCommandOk("git", ["-C", authority.toString(), "push",
                "origin", ":refs/tags/ckb-repro-v1"])
            let authorityRoot = canonicalize(authority).toString()
            @Expect(authorityRoot == canonicalize(Path(".")).toString(), false)
            let cwdHead = p9TestCommand("git", ["rev-parse", "HEAD"])[2]
                .trimAscii()
            let expectedHead = p9TestCommand("git", ["-C", authorityRoot,
                "rev-parse", "HEAD"])[2].trimAscii()
            @Expect(expectedHead == cwdHead, false)
            let observed = readCkbReproRepositoryGitEvidence(authorityRoot,
                "ckb-repro-v1")
            @Expect(observed[0], "ok")
            @Expect(observed[1].originRepository, "../origin.git")
            @Expect(observed[1].headCommit, expectedHead)
            @Expect(observed[1].originMainCommit, expectedHead)
            @Expect(observed[1].tagExistsLocal, true)
            @Expect(observed[1].tagCommit, expectedHead)
            @Expect(observed[1].tagExistsRemote, false)
            @Expect(observed[1].remoteTagCommit, "")
            @Expect(observed[1].headCommit == cwdHead, false)
        } finally {
            if (exists(base)) { remove(base, recursive: true) }
        }
    }

    @TestCase
    public func p9Neg06LiveRemoteTagMustMatchSignedSnapshot(): Unit {
        let live = p9GitEvidence(true)
        live.remoteTagCommit =
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        let signedSnapshotCommit =
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        @Expect(p9PublishBindRemoteTagSnapshot(live, "present",
            signedSnapshotCommit, signedSnapshotCommit),
            "publish_tag_binding_mismatch")
        @Expect(live.remoteTagCommit,
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    }

    @TestCase
    public func p9Neg03ReleaseKeyAndTagVerificationAreIsolated(): Unit {
        let base = Path("target/p9-signing-root")
        if (exists(base)) { remove(base, recursive: true) }
        let repository = base.join("repository")
        let bundle = base.join("bundle")
        Directory.create(repository.join("reproducibility"), recursive: true)
        Directory.create(bundle.join("reproducibility"), recursive: true)
        let key = "-----BEGIN PGP PUBLIC KEY BLOCK-----\nZml4dHVyZQ==\n" +
            "-----END PGP PUBLIC KEY BLOCK-----\n"
        File.writeTo(repository.join("reproducibility/RELEASE-SIGNING-KEY.asc"),
            key.toArray())
        p9TestCommandOk("git", ["-C", repository.toString(), "init"])
        p9TestCommandOk("git", ["-C", repository.toString(), "config",
            "user.name", "Metis Repro Test"])
        p9TestCommandOk("git", ["-C", repository.toString(), "config",
            "user.email", "repro@example.invalid"])
        p9TestCommandOk("git", ["-C", repository.toString(), "add",
            "reproducibility/RELEASE-SIGNING-KEY.asc"])
        p9TestCommandOk("git", ["-C", repository.toString(), "commit",
            "-m", "fixture key"])
        let releaseCommit = p9TestCommand("git", ["-C",
            repository.toString(), "rev-parse", "HEAD"])[2].trimAscii()
        File.writeTo(bundle.join("reproducibility/RELEASE-SIGNING-KEY.asc"),
            key.toArray())
        File.writeTo(bundle.join("SHA256SUMS.sig"), "signature".toArray())
        File.writeTo(bundle.join("SHA256SUMS"), "payload".toArray())
        let repositoryRoot = canonicalize(repository).toString()
        let bundleRoot = canonicalize(bundle).toString()
        let runner = P9FakeGpgvRunner()
        @Expect(ckbReproVerifyReleaseSignatureAtCommit(repositoryRoot,
            releaseCommit, bundleRoot,
            "SHA256SUMS.sig", "SHA256SUMS",
            "0123456789ABCDEF0123456789ABCDEF01234567", runner), "ok")
        @Expect(runner.command, "gpgv")
        @Expect(runner.args[0], "--homedir")
        @Expect(exists(Path(runner.args[1])), false)
        @Expect(runner.args[2], "--status-fd")
        @Expect(runner.args[3], "1")
        @Expect(runner.args[4], "--keyring")
        @Expect(runner.args[5].endsWith("release-signing-key.gpg"), true)
        @Expect(exists(Path(runner.args[5])), false)
        File.writeTo(bundle.join("reproducibility/RELEASE-SIGNING-KEY.asc"),
            (key + "drift").toArray())
        let drift = P9FakeGpgvRunner()
        @Expect(ckbReproVerifyReleaseSignatureAtCommit(repositoryRoot,
            releaseCommit, bundleRoot,
            "SHA256SUMS.sig", "SHA256SUMS",
            "0123456789ABCDEF0123456789ABCDEF01234567", drift),
            "publish_release_key_mismatch")
        @Expect(drift.calls, Int64(0))
        File.writeTo(bundle.join("reproducibility/RELEASE-SIGNING-KEY.asc"),
            key.toArray())
        remove(repository.join("reproducibility/RELEASE-SIGNING-KEY.asc"))
        @Expect(ckbReproVerifyReleaseSignatureAtCommit(repositoryRoot,
            releaseCommit, bundleRoot,
            "SHA256SUMS.sig", "SHA256SUMS",
            "0123456789ABCDEF0123456789ABCDEF01234567",
            P9FakeGpgvRunner()), "ok")
        let productionSource = String.fromUtf8(File.readFrom(
            Path("../src/ckb_repro_publish_gate.cj")))
        @Expect(productionSource.contains("[\"verify-tag\", \"--raw\""), false)
        @Expect(productionSource.contains("RELEASE-TAG-EVIDENCE.json"), false)
        @Expect(productionSource.contains(
            "\"cat-file\", \"tag\", \"refs/tags/\${options.tagName}\""), true)
        let tagPayload = "object aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n" +
            "type commit\ntag ckb-repro-v1\n" +
            "tagger Tester <test@example.invalid> 0 +0000\n\n发布🙂\n"
        let rawTag = (tagPayload + "-----BEGIN PGP SIGNATURE-----\nfixture\n" +
            "-----END PGP SIGNATURE-----\n").toArray()
        let parsedTag = parseCkbReproAnnotatedTag(rawTag,
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "ckb-repro-v1")
        @Expect(parsedTag[0], "ok")
        @Expect(parsedTag[1], tagPayload.toArray())
        @Expect(parseCkbReproAnnotatedTag(rawTag,
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            "ckb-repro-v1")[0], "publish_tag_binding_mismatch")
        let invalidTag = ArrayList<UInt8>()
        invalidTag.add(UInt8(0xff)); invalidTag.add(UInt8(0xfe))
        invalidTag.add(all: "-----BEGIN PGP SIGNATURE-----".toArray())
        @Expect(parseCkbReproAnnotatedTag(invalidTag.toArray(),
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "ckb-repro-v1")[0], "publish_tag_encoding_invalid")
        remove(base, recursive: true)
    }

    @TestCase
    public func p9Pos03ReleaseCommitKeyVerifiesRealSignature(): Unit {
        let created = p9TestCommand("mktemp",
            ["-d", "/tmp/ckb-p9-signing-XXXXXX"])
        if (created[0] != 0 || created[1] != "ok" ||
            created[2].trimAscii() == "") {
            throw Exception("test temporary directory unavailable")
        }
        let base = Path(created[2].trimAscii())
        let repository = base.join("repository")
        let bundle = base.join("bundle")
        let firstHome = base.join("first-home")
        let wrongHome = base.join("wrong-home")
        try {
        Directory.create(repository.join("reproducibility"), recursive: true)
        Directory.create(bundle.join("reproducibility"), recursive: true)
        Directory.create(firstHome); Directory.create(wrongHome)
        p9TestCommandOk("chmod", ["700", firstHome.toString()])
        p9TestCommandOk("chmod", ["700", wrongHome.toString()])
        p9TestCommandOk("gpg", ["--homedir", firstHome.toString(),
            "--batch", "--pinentry-mode", "loopback", "--passphrase", "",
            "--quick-generate-key", "Metis Repro Test <repro@example.invalid>",
            "ed25519", "sign", "0"])
        let firstFingerprint = p9TestGpgFingerprint(firstHome.toString())
        @Expect(firstFingerprint.size, Int64(40))
        let repositoryKey = repository.join(
            "reproducibility/RELEASE-SIGNING-KEY.asc")
        p9TestCommandOk("gpg", ["--homedir", firstHome.toString(),
            "--batch", "--yes", "--armor", "--output",
            repositoryKey.toString(), "--export", firstFingerprint])
        File.writeTo(bundle.join("reproducibility/RELEASE-SIGNING-KEY.asc"),
            File.readFrom(repositoryKey))
        File.writeTo(bundle.join("SHA256SUMS"), "payload\n".toArray())
        p9TestCommandOk("gpg", ["--homedir", firstHome.toString(),
            "--batch", "--yes", "--armor", "--output",
            bundle.join("SHA256SUMS.sig").toString(), "--detach-sign",
            bundle.join("SHA256SUMS").toString()])
        p9TestCommandOk("git", ["-C", repository.toString(), "init"])
        p9TestCommandOk("git", ["-C", repository.toString(), "config",
            "user.name", "Metis Repro Test"])
        p9TestCommandOk("git", ["-C", repository.toString(), "config",
            "user.email", "repro@example.invalid"])
        p9TestCommandOk("git", ["-C", repository.toString(), "add",
            "reproducibility/RELEASE-SIGNING-KEY.asc"])
        p9TestCommandOk("git", ["-C", repository.toString(), "commit",
            "-m", "trusted key"])
        let trustedCommit = p9TestCommand("git", ["-C",
            repository.toString(), "rev-parse", "HEAD"])[2].trimAscii()
        let repositoryRoot = canonicalize(repository).toString()
        let bundleRoot = canonicalize(bundle).toString()
        @Expect(ckbReproVerifyReleaseSignatureAtCommit(repositoryRoot,
            trustedCommit, bundleRoot, "SHA256SUMS.sig", "SHA256SUMS",
            firstFingerprint, P9RealGpgvRunner()), "ok")

        p9TestCommandOk("gpg", ["--homedir", wrongHome.toString(),
            "--batch", "--pinentry-mode", "loopback", "--passphrase", "",
            "--quick-generate-key", "Metis Wrong Test <wrong@example.invalid>",
            "ed25519", "sign", "0"])
        let wrongFingerprint = p9TestGpgFingerprint(wrongHome.toString())
        p9TestCommandOk("gpg", ["--homedir", wrongHome.toString(),
            "--batch", "--yes", "--armor", "--output",
            repositoryKey.toString(), "--export", wrongFingerprint])
        File.writeTo(bundle.join("reproducibility/RELEASE-SIGNING-KEY.asc"),
            File.readFrom(repositoryKey))
        p9TestCommandOk("git", ["-C", repository.toString(), "add",
            "reproducibility/RELEASE-SIGNING-KEY.asc"])
        p9TestCommandOk("git", ["-C", repository.toString(), "commit",
            "-m", "wrong key"])
        let wrongCommit = p9TestCommand("git", ["-C",
            repository.toString(), "rev-parse", "HEAD"])[2].trimAscii()
        @Expect(ckbReproVerifyReleaseSignatureAtCommit(repositoryRoot,
            wrongCommit, bundleRoot, "SHA256SUMS.sig", "SHA256SUMS",
            wrongFingerprint, P9RealGpgvRunner()),
            "publish_signature_mismatch")
        } finally {
            if (exists(firstHome)) {
                p9TestCommand("gpgconf", ["--homedir",
                    firstHome.toString(), "--kill", "all"])
            }
            if (exists(wrongHome)) {
                p9TestCommand("gpgconf", ["--homedir",
                    wrongHome.toString(), "--kill", "all"])
            }
            if (exists(base)) { remove(base, recursive: true) }
        }
    }

    @TestCase
    public func p9Neg04FullTestProofBindsActualTrustedRun(): Unit {
        let commit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        let tree = ckbReproBundleHash("tree".toArray())
        let input = ckbReproBundleHash("input".toArray())
        let manifest = ckbReproBundleHash("release-manifest".toArray())
        let verifiedAsset = ckbReproBundleHash("verified-input-asset".toArray())
        let topology = ckbReproBundleHash("tracked-test-topology".toArray())
        let runner = ckbReproBundleHash("tracked-test-runner".toArray())
        let source = ckbReproBundleHash("build-attestation".toArray())
        let cleanLog = ckbReproBundleHash("clean-log".toArray())
        let buildLog = ckbReproBundleHash("build-log".toArray())
        let testLog = ckbReproBundleHash("test-log".toArray())
        let proof = renderCkbReproFullTestProof(commit, tree, input,
            manifest, verifiedAsset, topology, runner, source,
            cleanLog, buildLog, testLog, 1266)
        @Expect(proof.contains("\"testCommand\":\"cjpm test -j 1\""), true)
        let originalProofHash = computeCkbReproFullTestProofHash(commit, tree,
            input, manifest, verifiedAsset, topology, runner, source,
            ckbReproBundleHash("cjpm clean".toArray()), cleanLog,
            ckbReproBundleHash("cjpm build -i".toArray()), buildLog,
            ckbReproBundleHash("cjpm test -j 1".toArray()), testLog, 1266)
        let changedBuildHash = ckbReproBundleHash("cjpm build".toArray())
        let recomputedOuterHash = computeCkbReproFullTestProofHash(commit,
            tree, input, manifest, verifiedAsset, topology, runner, source,
            ckbReproBundleHash("cjpm clean".toArray()), cleanLog,
            changedBuildHash, buildLog,
            ckbReproBundleHash("cjpm test -j 1".toArray()), testLog, 1266)
        let recomputedTamper = proof.replace("cjpm build -i", "cjpm build")
            .replace(ckbReproBundleHash("cjpm build -i".toArray()),
                changedBuildHash).replace(originalProofHash, recomputedOuterHash)
        @Expect(validateCkbReproFullTestProof(proof.toArray(), commit, tree,
            input, manifest, verifiedAsset, topology, runner, source), "ok")
        for (tampered in [
            proof.replace("cjpm build -i", "cjpm build"),
            proof.replace("\"testExitCode\":0", "\"testExitCode\":1"),
            proof.replace("\"testPassedCount\":1266",
                "\"testPassedCount\":1265"),
            proof.replace(source, ckbReproBundleHash("other-source".toArray())),
            proof.replace(testLog, ckbReproBundleHash("claimed-log".toArray())),
            proof.replace("\"proofHash\":\"sha256:",
                "\"proofHash\":\"sha256:0"),
            recomputedTamper,
            proof.replace("}", ",\"ok\":true,\"result\":\"passed\"}")
        ]) {
            @Expect(validateCkbReproFullTestProof(tampered.toArray(), commit,
                tree, input, manifest, verifiedAsset, topology, runner, source),
                "publish_full_test_proof_invalid")
        }
        @Expect(validateCkbReproFullTestProof([UInt8(0xff), UInt8(0xfe)],
            commit, tree, input, manifest, verifiedAsset, topology, runner,
            source), "invalid_response_encoding")
    }
}

private func p9TestCommand(command: String, args: Array<String>):
    (Int64, String, String) {
    try {
        let process = launch(command, args, stdOut: ProcessRedirect.Pipe,
            stdErr: ProcessRedirect.Pipe)
        let stdout = spawn { => p9TestReadPipe(process.stdOutPipe) }
        let stderr = spawn { => p9TestReadPipe(process.stdErrPipe) }
        let code = process.wait()
        let output = stdout.get(); let error = stderr.get()
        if (output[0] != "ok") { return (code, output[0], "") }
        if (error[0] != "ok") { return (code, error[0], "") }
        (code, "ok", if (output[1] == "") { error[1] } else { output[1] })
    } catch (_: Exception) { (127, "command_failed", "") }
}

private func p9TestReadPipe(pipe: InputStream): (String, String) {
    let bytes = ArrayList<UInt8>()
    let buffer = Array<UInt8>(8192, repeat: UInt8(0))
    try {
        while (true) {
            let count = pipe.read(buffer)
            if (count < 0 || count > buffer.size) { return ("read_failed", "") }
            if (count == 0) { break }
            if (bytes.size + count > 1024 * 1024) {
                return ("output_too_large", "")
            }
            for (i in 0..count) { bytes.add(buffer[i]) }
        }
        ("ok", String.fromUtf8(bytes.toArray()))
    } catch (_: Exception) { ("invalid_response_encoding", "") }
}

private func p9TestCommandOk(command: String, args: Array<String>): Unit {
    let result = p9TestCommand(command, args)
    @Expect(result[1], "ok")
    @Expect(result[0], Int64(0))
}

private func p9TestGpgFingerprint(home: String): String {
    let result = p9TestCommand("gpg", ["--homedir", home, "--batch",
        "--with-colons", "--list-keys"])
    if (result[0] != 0 || result[1] != "ok") { return "" }
    for (line in result[2].split("\n")) {
        let fields = line.split(":")
        if (fields.size > 9 && fields[0] == "fpr") { return fields[9] }
    }
    ""
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
    let releaseCommitAsset = p9PublishAsset("release/release-commit.txt",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".toArray(),
        "release_commit")
    let assets = ArrayList<CkbReproBundleAsset>()
    assets.add(asset)
    assets.add(referenceAsset)
    assets.add(leakageAsset)
    assets.add(licenseAsset)
    assets.add(releaseCommitAsset)
    for (role in ["p0_manifest", "p1_score_contract",
        "p2_logical_snapshot", "p3_qdrant_snapshot", "p4_build_proof",
        "p5_public_evidence", "p6_environment_lock", "p7_documentation",
        "source_lock", "authority_delivery"]) {
        assets.add(p9PublishAsset("fixture/${role}.txt",
            "fixture-${role}".toArray(), role))
    }
    for (entry in [
        ("full-test/clean.log", "clean completed\n", "full_test_clean_log"),
        ("full-test/build.log", "build completed\n", "full_test_build_log"),
        ("full-test/test.log", "1267 tests passed\n", "full_test_test_log"),
        ("full-test/topology.json", "{\"packages\":1}\n", "full_test_topology"),
        ("full-test/runner.txt", "cjpm test -j 1\n", "full_test_runner"),
        ("full-test/source.txt", "signed release source\n", "full_test_source")]) {
        assets.add(p9PublishAsset(entry[0], entry[1].toArray(), entry[2]))
    }
    var cleanLogHash = ""; var buildLogHash = ""; var testLogHash = ""
    var topologyHash = ""; var runnerHash = ""; var sourceHash = ""
    for (item in assets) {
        if (item.role == "full_test_clean_log") { cleanLogHash = item.logicalSha256 }
        if (item.role == "full_test_build_log") { buildLogHash = item.logicalSha256 }
        if (item.role == "full_test_test_log") { testLogHash = item.logicalSha256 }
        if (item.role == "full_test_topology") { topologyHash = item.logicalSha256 }
        if (item.role == "full_test_runner") { runnerHash = item.logicalSha256 }
        if (item.role == "full_test_source") { sourceHash = item.logicalSha256 }
    }
    let fullTestAsset = p9PublishAsset("full-test-report.json",
        renderCkbReproFullTestProof(
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            reference.runCriticalTreeHash, reference.certifiedRunInputHash,
            ckbReproBundleHash(referenceBytes), reference.resultsHash,
            topologyHash, runnerHash, sourceHash, cleanLogHash,
            buildLogHash, testLogHash, 1267).toArray(),
        "portable_report")
    assets.add(fullTestAsset)
    let manifest = writeCkbReproReleaseManifest(assets)
    let parsedManifest = parseCkbReproBundleManifest(manifest.toArray())[1]
    let proofSetHash = computeCkbReproBundleProofSetHash(parsedManifest)
    let authorityHash = computeCkbReproPublishAuthorityHash(parsedManifest,
        proofSetHash, ckbReproBundleHash(referenceBytes),
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    let verification = "{\"schemaVersion\":\"ckb-repro-verification-report-v1\"," +
        "\"ok\":true,\"diagnostic\":\"verified\"," +
        "\"verifiedReleaseInputSetHash\":\"${computeCkbReproBundleInputSetHash(assets)}\"," +
        "\"bundleProofSetHash\":\"${proofSetHash}\"," +
        "\"releaseCommit\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," +
        "\"certifiedRunInputHash\":\"${ckbReproBundleHash("input".toArray())}\"," +
        "\"runCriticalTreeHash\":\"${reference.runCriticalTreeHash}\"," +
        "\"referenceManifestHash\":\"${ckbReproBundleHash(referenceBytes)}\"," +
        "\"authorityHash\":\"${authorityHash}\"," +
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
        "${observed}|${expires}|signed-remote-tag-attestation|true"
    let remote = "{\"schemaVersion\":\"ckb-repro-remote-tag-evidence-v1\"," +
        "\"originRepository\":\"git@github.com:l3gi0nXXXX/CangjieCommunityKnowledgeBase.git\"," +
        "\"originMainCommit\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," +
        "\"tagName\":\"ckb-repro-v1\",\"state\":\"absent\"," +
        "\"tagCommit\":\"\",\"observedAtMillis\":${observed}," +
        "\"expiresAtMillis\":${expires}," +
        "\"queryKind\":\"signed-remote-tag-attestation\"," +
        "\"querySucceeded\":true," +
        "\"evidenceHash\":\"${ckbReproBundleHash(remoteSeed.toArray())}\"}"
    let files = ArrayList<(String, Array<UInt8>)>()
    for (entry in assets) { files.add((entry.relativePath, entry.bytes)) }
    for (entry in [
        ("RELEASE-MANIFEST.json", manifest.toArray()),
        ("verification-report.json", verification.toArray()),
        ("build-attestation.json", attestation.toArray()),
        ("PUBLISH-EVIDENCE.json", localText.toArray()),
        ("REMOTE-TAG-EVIDENCE.json", remote.toArray())]) { files.add(entry) }
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
    reference.modelFingerprint = "claude-code-glm-5.2"
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
    evidence.tagObjectHash = if (tagExists) {
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    } else { "" }
    evidence.remoteTagSnapshotAvailable = true
    evidence.remoteTagSnapshotFresh = true
    evidence.remoteTagState = if (tagExists) { "present" } else { "absent" }
    evidence.remoteTagCommit = if (tagExists) { evidence.headCommit } else { "" }
    evidence.remoteTagObjectHash = evidence.tagObjectHash
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
