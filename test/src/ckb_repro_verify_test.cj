package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashSet}
import std.fs.{Directory, File, FileInfo, Path, canonicalize, exists, remove}
import std.process.*
import std.unittest.*
import std.unittest.testmacro.*

private class P8InterruptedReadOperation <: CkbReproNativeReadOperation {
    public var calls: Int64 = 0
    public init() {}
    public func read(fd: Int32, buffer: Array<UInt8>): Int64 {
        this.calls += 1
        if (this.calls == 1) { return -1 }
        buffer[0] = UInt8(42)
        1
    }
    public func errorNumber(): Int32 { 4 }
}

private class P8EnvironmentProbe <: CkbReproVerifyEnvironmentProbe {
    public let existing = HashSet<String>()
    public let empty = HashSet<String>()
    public var stale: Int64 = 0
    public var privatePaths: Int64 = 0
    public var candidateEntries: Int64 = 1
    public var inputValid: Bool = true
    public var throwProbe: Bool = false
    public var identityVersion: String = "v1"
    public init() {}
    public func pathExists(path: String): Bool {
        this.existing.contains(path)
    }
    public func pathIsEmptyDirectory(path: String): Bool {
        this.empty.contains(path)
    }
    public func candidateEntryCount(path: String): Int64 {
        this.candidateEntries
    }
    public func inspectInput(path: String): CkbReproVerifyInputEvidence {
        if (this.throwProbe) { throw Exception("probe") }
        let out = CkbReproVerifyInputEvidence()
        out.ok = this.inputValid
        out.regular = true
        out.noFollow = true
        out.stable = true
        let role = if (path.endsWith("p0.json")) { "p0" }
            else if (path.endsWith("p1.json")) { "p1" }
            else if (path.endsWith("p2.tar")) { "p2" }
            else if (path.endsWith("p3.snapshot")) { "p3" }
            else if (path.endsWith("p4.json")) { "p4" }
            else if (path.endsWith("p6.json")) { "p6" } else { "p8" }
        out.size = role.toArray().size
        out.sha256 = p8Hash(role)
        out.identity = "${this.identityVersion}:${path}"
        out
    }
    public func canonicalReleaseRepository(): String {
        "l3gi0nXXXX/CangjieCommunityKnowledgeBase"
    }
    public func providerFingerprint(): String { p8Hash("provider") }
    public func modelIdentity(): String { "GLM-5.2" }
    public func staleProcessCount(): Int64 { this.stale }
    public func privatePathDependencyCount(): Int64 { this.privatePaths }
}

private class P8RunExecutor <: CkbReproRunCertificationExecutor {
    public let calls = ArrayList<String>()
    public var score: Int64 = 151
    public var raw: Int64 = 151
    public var transport: Int64 = 0
    public var failAt: String = ""
    public var throwAt: String = ""
    public var mutateCritical: Bool = false
    public init() {}
    public func restore(options: CkbReproVerifyOptions):
        CkbReproStageEvidence {
        this.calls.add("restore")
        if (this.throwAt == "restore") { throw Exception("restore") }
        let out = p8ValidStage(false)
        if (this.failAt == "restore") {
            out.ok = false
            out.diagnostic = "restore_failed"
        }
        out
    }
    public func rebuild(options: CkbReproVerifyOptions):
        CkbReproStageEvidence {
        this.calls.add("rebuild")
        if (this.throwAt == "rebuild") { throw Exception("rebuild") }
        if (this.mutateCritical) {
            File.writeTo(Path(options.repositoryRoot).join(
                "src/critical.cj"), "critical-v2".toArray())
        }
        let out = p8ValidStage(true)
        if (this.failAt == "rebuild") {
            out.ok = false
            out.diagnostic = "rebuild_failed"
        }
        out
    }
    public func runReference(options: CkbReproVerifyOptions):
        CkbReproReferenceRunEvidence {
        this.calls.add("runner")
        if (this.throwAt == "runner") { throw Exception("runner") }
        let out = CkbReproReferenceRunEvidence()
        out.ok = true
        out.totalCases = 164
        out.rawPassed = this.raw
        out.strictPassed = this.score
        out.businessFailed = 164 - this.score
        out.protocolInvalid = 0
        out.transportUnresolved = this.transport
        out.resultsHash = p8Hash("results-${this.score}")
        out
    }
}

private class P8ReleaseExecutor <:
    CkbReproReleaseVerificationExecutor {
    public let calls = ArrayList<String>()
    public var failAt: String = ""
    public var throwAt: String = ""
    public init() {}
    public func restore(options: CkbReproVerifyOptions):
        CkbReproStageEvidence {
        this.calls.add("restore")
        if (this.throwAt == "restore") { throw Exception("restore") }
        p8ValidStage(false)
    }
    public func rebuild(options: CkbReproVerifyOptions):
        CkbReproStageEvidence {
        this.calls.add("rebuild")
        if (this.throwAt == "rebuild") { throw Exception("rebuild") }
        p8ValidStage(true)
    }
    public func verifyPublicEvidence(options: CkbReproVerifyOptions):
        CkbReproContractResult {
        this.calls.add("evidence")
        if (this.throwAt == "evidence") { throw Exception("evidence") }
        if (this.failAt == "evidence") {
            p8Contract(false, "public_evidence_failed")
        } else { p8Contract(true, "ok") }
    }
    public func verifyDocumentation(options: CkbReproVerifyOptions):
        CkbReproContractResult {
        this.calls.add("docs")
        if (this.throwAt == "docs") { throw Exception("docs") }
        if (this.failAt == "docs") {
            p8Contract(false, "documentation_failed")
        } else { p8Contract(true, "ok") }
    }
}

private class P8ReleaseAuthority <: CkbReproReleaseAssetAuthority {
    public var fail: Bool = false
    public var throwFailure: Bool = false
    public var calls: Int64 = 0
    public init() {}
    public func validate(loaded: CkbReproBundleLoadResult,
        reference: CkbReproReferenceManifest, releaseCommit: String,
        preflight: CkbReproVerifyEnvironmentResult):
        CkbReproVerifiedReleaseAuthority {
        this.calls += 1
        if (this.throwFailure) { throw Exception("authority") }
        let out = CkbReproVerifiedReleaseAuthority()
        if (this.fail) {
            out.diagnostic = "fake_authority_failed"
            return out
        }
        out.ok = true
        out.diagnostic = "verified"
        out.authorityHash = p8Hash("authority")
        out.verifiedInputSetHash =
            computeCkbVerifiedReleaseInputSetHash(loaded.manifest)
        out.proofSetHash = loaded.proofSetHash
        out.referenceManifestHash = validateCkbReproReferenceManifest(
            reference, mode: "execution").manifestHash
        out.releaseCommitHash = p8Hash(releaseCommit)
        out.rolesComplete = true
        out.derivedAssetCount = 0
        out
    }
}

@Test
public class CkbReproVerifyTest {
    @TestCase
    public func p8Ut01ModesAreParsedWithoutImplicitReleaseState(): Unit {
        let run = parseCkbReproVerifyOptions([
            "--mode", "run-certify",
            "--work-root", "/tmp/ckb p8/work",
            "--runtime-root", "/tmp/ckb p8/runtime",
            "--qdrant-root", "/tmp/ckb p8/qdrant",
            "--source-root", "/tmp/ckb p8/source",
            "--candidate-root", "/tmp/ckb p8/candidate",
            "--repository-root", "/tmp/ckb p8/repository",
            "--p0-manifest", "/tmp/ckb p8/inputs/p0.json",
            "--p1-score-contract", "/tmp/ckb p8/inputs/p1.json",
            "--p2-logical-snapshot", "/tmp/ckb p8/inputs/p2.tar",
            "--p3-qdrant-snapshot", "/tmp/ckb p8/inputs/p3.snapshot",
            "--p4-build-proof", "/tmp/ckb p8/inputs/p4.json",
            "--p6-environment-lock", "/tmp/ckb p8/inputs/p6.json",
            "--run-candidate-commit",
            "0123456789abcdef0123456789abcdef01234567"
        ])
        @Expect(run.ok, true)
        @Expect(run.options.mode, "run-certify")
        @Expect(run.options.releaseCommit, "")
        @Expect(run.options.tag, "")

        let release = parseCkbReproVerifyOptions([
            "--mode", "release-verify",
            "--work-root", "/tmp/ckb p8/release work",
            "--runtime-root", "/tmp/ckb p8/release runtime",
            "--qdrant-root", "/tmp/ckb p8/release qdrant",
            "--source-root", "/tmp/ckb p8/release source",
            "--candidate-root", "/tmp/ckb p8/unsigned",
            "--repository-root", "/tmp/ckb p8/repository",
            "--p0-manifest", "/tmp/ckb p8/inputs/p0.json",
            "--p1-score-contract", "/tmp/ckb p8/inputs/p1.json",
            "--p2-logical-snapshot", "/tmp/ckb p8/inputs/p2.tar",
            "--p3-qdrant-snapshot", "/tmp/ckb p8/inputs/p3.snapshot",
            "--p4-build-proof", "/tmp/ckb p8/inputs/p4.json",
            "--p6-environment-lock", "/tmp/ckb p8/inputs/p6.json",
            "--p8-reference", "/tmp/ckb p8/inputs/p8.json",
            "--release-commit",
            "89abcdef0123456789abcdef0123456789abcdef"
        ])
        @Expect(release.ok, true)
        @Expect(release.options.mode, "release-verify")
        @Expect(release.options.runCandidateCommit, "")
        @Expect(release.options.tag, "")

        let invalid = parseCkbReproVerifyOptions(
            ["--mode", "online", "--mode", "run-certify"])
        @Expect(invalid.ok, false)
        @Expect(invalid.diagnostic, "verify_argument_duplicate_or_empty")
        let forbiddenReference = p8Options("run-certify", "/tmp/p8-ref")
        forbiddenReference.p8ReferencePath = "/tmp/p8-ref/reference.json"
        let forbiddenStart = runCkbPortableReferenceHumanEval(
            forbiddenReference, p8Identity(),
            p8HashInputs("/tmp/p8-ref"),
            CkbReproVerifyEnvironmentResult(), P8EnvironmentProbe(),
            p8ReferenceTemplate(),
            P8RunExecutor())
        @Expect(forbiddenStart.diagnostic, "run_candidate_commit_invalid")

        let root = p8ResetRoot("target/p8-ut-hash")
        try {
            let inputs = p8HashInputs(root)
            let first = computeCkbCertifiedRunInputHash(inputs)
            @Expect(first.startsWith("sha256:"), true)
            inputs.environmentHash = p8Hash("changed")
            @Expect(computeCkbCertifiedRunInputHash(inputs) == first, false)
            let options = p8Options("run-certify", root)
            options.runCandidateCommit =
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
            let secondInputs = p8HashInputs(root)
            @Expect(computeCkbCertifiedRunInputHash(secondInputs), first)
            options.runCandidateCommit =
                "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
            @Expect(computeCkbCertifiedRunInputHash(secondInputs), first)
            let otherRoot = p8ResetRoot("target/p8-ut-hash-other")
            try {
                @Expect(computeCkbCertifiedRunInputHash(
                    p8HashInputs(otherRoot)), first)
                @Expect(p8Preflight(p8Options(
                    "run-certify", otherRoot)).localToctouToken ==
                    p8Preflight(p8Options(
                    "run-certify", root)).localToctouToken, false)
            } finally { p8Remove(otherRoot) }
        } finally { p8Remove(root) }
    }

    @TestCase
    public func p8Bnd01EnvironmentHeapRootsEncodingAndPathsFailClosed():
        Unit {
        let root = p8ResetRoot("target/p8-bnd")
        try {
            let options = p8Options("run-certify", root)
            let probe = P8EnvironmentProbe()
            probe.existing.add(options.candidateRoot)
            @Expect(validateCkbReproVerifyEnvironment(
                options, "4GB", probe).ok, true)
            for (heap in ["", "仓颉🙂", "4095MB"]) {
                let result = validateCkbReproVerifyEnvironment(
                    options, heap, probe)
                @Expect(result.ok, false)
                @Expect(result.startAllowed, false)
                @Expect(result.diagnostic.startsWith(
                    "ckb.service_heap_"), true)
            }
            for (staleRoot in [options.workRoot, options.runtimeRoot,
                options.qdrantRoot, options.sourceRoot]) {
                probe.existing.add(staleRoot)
                @Expect(validateCkbReproVerifyEnvironment(
                    options, "4096MB", probe).diagnostic,
                    "verify_root_contains_old_state")
                probe.existing.remove(staleRoot)
            }
            probe.stale = 1
            @Expect(validateCkbReproVerifyEnvironment(
                options, "4GB", probe).diagnostic,
                "verify_stale_process_detected")
            probe.stale = 0
            probe.privatePaths = 1
            @Expect(validateCkbReproVerifyEnvironment(
                options, "4GB", probe).diagnostic,
                "verify_private_path_dependency")
            probe.privatePaths = 0
            probe.candidateEntries = 0
            @Expect(validateCkbReproVerifyEnvironment(
                options, "4GB", probe).diagnostic,
                "verify_candidate_empty")
            probe.candidateEntries = 1
            probe.inputValid = false
            @Expect(validateCkbReproVerifyEnvironment(
                options, "4GB", probe).diagnostic,
                "verify_input_evidence_invalid")
            probe.inputValid = true
            probe.throwProbe = true
            @Expect(validateCkbReproVerifyEnvironment(
                options, "4GB", probe).diagnostic,
                "verify_environment_probe_failed")

            let executor = P8RunExecutor()
            let noPreflight = runCkbPortableReferenceHumanEval(
                options, p8Identity(), p8HashInputs(root),
                CkbReproVerifyEnvironmentResult(), P8EnvironmentProbe(),
                p8ReferenceTemplate(),
                executor)
            @Expect(noPreflight.diagnostic, "verify_preflight_required")
            @Expect(executor.calls.size, 0)

            let invalidManifestRoot =
                p8ResetRoot("${root}/invalid utf8 🙂")
            File.writeTo(Path(invalidManifestRoot).join(
                "RELEASE-MANIFEST.json"), [0xff, 0xfe])
            let invalid = validateCkbReproBundleManifest(
                canonicalize(Path(invalidManifestRoot)).toString(),
                CkbReproFilesystemBundleReadBackend())
            @Expect(invalid.contract.ok, false)
            @Expect(invalid.contract.diagnostic,
                "invalid_response_encoding")

            let interrupted = P8InterruptedReadOperation()
            let interruptBuffer = Array<UInt8>(65536, repeat: 0)
            @Expect(ckbReproReadRetryingInterrupt(
                7, interruptBuffer, interrupted), 1)
            @Expect(interrupted.calls, 2)
            @Expect(interruptBuffer[0], UInt8(42))

            let directoryRoot = p8ResetRoot("${root}/directory-entry")
            Directory.create(Path(directoryRoot).join("empty/nested"),
                recursive: true)
            let directoryResult = validateCkbReproBundleManifest(
                directoryRoot, CkbReproFilesystemBundleReadBackend())
            @Expect(directoryResult.contract.diagnostic,
                "bundle_root_entry_type_invalid")
        } finally { p8Remove(root) }
    }

    @TestCase
    public func p8Pos01RestoreChecksIdentityCountsLeakageAndMcpParity():
        Unit {
        let root = p8ResetRoot("target/p8-pos01")
        try {
            let executor = P8RunExecutor()
            let restored = verifyRestoredCkbRelease(
                p8Options("run-certify", root), p8Identity(), executor)
            @Expect(restored.ok, true)
            @Expect(restored.rawRecords, 7818)
            @Expect(restored.activeRecords, 7978)
            @Expect(restored.vectorPoints, 7978)
            @Expect(restored.leakageFindings, 0)
            @Expect(restored.mcpParityDiff, 0)
            @Expect(executor.calls.toArray(), ["restore"])
        } finally { p8Remove(root) }
    }

    @TestCase
    public func p8Pos02RebuildChecksSourcePathAndRetrievalProofs():
        Unit {
        let root = p8ResetRoot("target/p8-pos02")
        try {
            let executor = P8RunExecutor()
            let rebuilt = verifyRebuiltCkbRelease(
                p8Options("run-certify", root), p8Identity(), executor)
            @Expect(rebuilt.ok, true)
            @Expect(rebuilt.sourceLockHash, p8Hash("source-lock"))
            @Expect(rebuilt.pathProofHash, p8Hash("path-proof"))
            @Expect(rebuilt.retrievalDiff, 0)
            @Expect(executor.calls.toArray(), ["rebuild"])
        } finally { p8Remove(root) }
    }

    @TestCase
    public func p8Pos03RunCertifyOrdersStagesAndRunsExactlyOne164():
        Unit {
        let root = p8ResetRoot("target/p8-pos03")
        try {
            let executor = P8RunExecutor()
            let result = runCkbPortableReferenceHumanEval(
                p8Options("run-certify", root), p8Identity(),
                p8HashInputs(root), executor)
            @Expect(result.ok, true)
            @Expect(result.diagnostic, "target_matched")
            @Expect(result.target.targetScoreMatched, true)
            @Expect(result.runnerCalls, 1)
            @Expect(result.downstreamCalls, 0)
            @Expect(executor.calls.toArray(), ["restore", "rebuild", "runner"])
            @Expect(result.certifiedRunInputHash.startsWith(
                "sha256:"), true)
            @Expect(result.referenceValidation.ok, true)
            @Expect(result.referenceManifest.strictPassed, 151)

            let template = p8ReferenceTemplate()
            let written = writeCkbPortableReferenceManifest(
                template, result.run,
                "0123456789abcdef0123456789abcdef01234567",
                result.certifiedRunInputHash,
                result.runCriticalTreeHash)
            @Expect(written[0].ok, true)
            @Expect(written[1].baselineKind, "portable_release")
            @Expect(written[1].certifiedRunInputHash,
                result.certifiedRunInputHash)

            let detached = p8HashInputs(root)
            detached.logicalProofHash = p8Hash("detached")
            let detachedExecutor = P8RunExecutor()
            let detachedResult = runCkbPortableReferenceHumanEval(
                p8Options("run-certify", root), p8Identity(), detached,
                p8Preflight(p8Options("run-certify", root)),
                P8EnvironmentProbe(), p8ReferenceTemplate(),
                detachedExecutor)
            @Expect(detachedResult.diagnostic,
                "certified_run_input_binding_mismatch")
            @Expect(detachedExecutor.calls.size, 0)

            let driftOptions = p8Options("run-certify", root)
            let driftProbe = P8EnvironmentProbe()
            driftProbe.existing.add(driftOptions.candidateRoot)
            let driftPreflight = validateCkbReproVerifyEnvironment(
                driftOptions, "4GB", driftProbe)
            let driftInputs = p8HashInputs(root)
            driftInputs.inputEvidenceHash =
                driftPreflight.inputEvidenceHash
            driftProbe.identityVersion = "v2"
            let driftExecutor = P8RunExecutor()
            let drifted = runCkbPortableReferenceHumanEval(
                driftOptions, p8Identity(), driftInputs, driftPreflight,
                driftProbe, p8ReferenceTemplate(), driftExecutor)
            @Expect(drifted.diagnostic, "verify_input_identity_drift")
            @Expect(driftExecutor.calls.toArray(),
                ["restore", "rebuild"])

            let throwing = P8RunExecutor()
            throwing.throwAt = "runner"
            let runnerFailed = runCkbPortableReferenceHumanEval(
                p8Options("run-certify", root), p8Identity(),
                p8HashInputs(root), throwing)
            @Expect(runnerFailed.diagnostic, "reference_runner_failed")
            @Expect(runnerFailed.runnerCalls, 1)

            let criticalRoot = p8ResetRoot("${root}/critical-drift")
            try {
                let criticalExecutor = P8RunExecutor()
                criticalExecutor.mutateCritical = true
                let criticalResult = runCkbPortableReferenceHumanEval(
                    p8Options("run-certify", criticalRoot), p8Identity(),
                    p8HashInputs(criticalRoot), criticalExecutor)
                @Expect(criticalResult.diagnostic,
                    "run_critical_identity_drift")
                @Expect(criticalResult.runnerCalls, 0)
                @Expect(criticalExecutor.calls.toArray(),
                    ["restore", "rebuild"])
            } finally { p8Remove(criticalRoot) }
        } finally { p8Remove(root) }
    }

    @TestCase
    public func p8Pos04ReleaseVerifyReadsNestedBundleWithoutRunner():
        Unit {
        let root = p8ResetRoot("target/p8 pos04 中文🙂")
        try {
            let repository = p8ResetRoot("${root}/repository")
            let options = p8Options("release-verify", root)
            options.repositoryRoot = repository
            let critical = p8Critical(repository)
            let reference = p8ReferenceTemplate()
            reference.runCriticalTreeHash =
                computeCkbRunCriticalTreeHash(critical, repository)
            let bundle = p8CreateBundle("${root}/unsigned candidate",
                "assets/知识🙂.txt", "portable-content",
                reference: reference)
            options.candidateRoot = bundle[0]
            let executor = P8ReleaseExecutor()
            let result = verifyCkbUnsignedReleaseCandidate(
                options, p8Identity(), reference, bundle[1],
                reference.certifiedRunInputHash,
                reference.releaseRepository, critical,
                P8ReleaseAuthority(),
                p8Preflight(options),
                P8EnvironmentProbe(),
                CkbReproFilesystemBundleReadBackend(), executor)
            @Expect(result.ok, true)
            @Expect(result.diagnostic, "verified")
            @Expect(result.runnerCalls, 0)
            @Expect(executor.calls.toArray(),
                ["restore", "rebuild", "evidence", "docs"])
            @Expect(result.verifiedReleaseInputSetHash, bundle[1])
            @Expect(renderCkbReproVerificationReport(result).contains(
                "\"runnerCalls\":0"), true)
            result.diagnostic = "中文🙂\t\u{0001}"
            let report = renderCkbReproVerificationReport(result)
            @Expect(report.contains("中文🙂\\t\\u0001"), true)
            @Expect(report.contains("\"restoreOk\":true"), true)
        } finally { p8Remove(root) }
    }

    @TestCase
    public func p8Pos04AndNeg01ProductionReleaseAuthority(): Unit {
        let root = p8ResetRoot("target/p8-authority")
        try {
            let reference = p8ReferenceTemplate()
            let bundle = p8CreateBundle("${root}/bundle",
                "assets/unused.txt", "p0", reference: reference)
            let loaded = validateCkbReproBundleManifest(bundle[0],
                CkbReproFilesystemBundleReadBackend())
            @Expect(loaded.contract.ok, true)
            let contract = p8AuthorityContract(loaded)
            let preflight = p8AuthorityPreflight(loaded)
            let authority = CkbReproCanonicalReleaseAssetAuthority(contract)
            let releaseCommit =
                "89abcdef0123456789abcdef0123456789abcdef"
            let accepted = authority.validate(
                loaded, reference, releaseCommit, preflight)
            @Expect(accepted.ok, true)
            @Expect(accepted.rolesComplete, true)
            @Expect(accepted.derivedAssetCount, 0)

            let multipartBundle = p8CreateBundle("${root}/multipart-bundle",
                "assets/unused.txt", "p0", reference: reference,
                multipartP2: true)
            let multipartLoaded = validateCkbReproBundleManifest(
                multipartBundle[0], CkbReproFilesystemBundleReadBackend())
            @Expect(multipartLoaded.contract.ok, true)
            @Expect(CkbReproCanonicalReleaseAssetAuthority(
                p8AuthorityContract(multipartLoaded)).validate(
                multipartLoaded, reference, releaseCommit,
                p8AuthorityPreflight(multipartLoaded)).ok, true)

            let missing = p8AuthorityContract(loaded,
                omittedRole: "p5_public_evidence")
            @Expect(CkbReproCanonicalReleaseAssetAuthority(missing).validate(
                loaded, reference, releaseCommit, preflight).diagnostic,
                "release_authority_role_missing")

            preflight.inputHashes[0] = p8Hash("mismatch")
            @Expect(authority.validate(
                loaded, reference, releaseCommit, preflight).diagnostic,
                "release_authority_preflight_mismatch")
            let stablePreflight = p8AuthorityPreflight(loaded)
            let duplicatePreflight = p8AuthorityPreflight(loaded)
            duplicatePreflight.inputRoles[6] = "p0_manifest"
            @Expect(authority.validate(loaded, reference, releaseCommit,
                duplicatePreflight).diagnostic,
                "release_authority_preflight_mismatch")
            let missingPreflight = p8AuthorityPreflight(loaded)
            missingPreflight.inputRoles.remove(at: 6)
            missingPreflight.inputHashes.remove(at: 6)
            missingPreflight.inputSizes.remove(at: 6)
            @Expect(authority.validate(loaded, reference, releaseCommit,
                missingPreflight).diagnostic,
                "release_authority_preflight_mismatch")
            let wrongReference = p8ReferenceTemplate()
            wrongReference.resultsHash = p8Hash("different-reference")
            @Expect(authority.validate(loaded, wrongReference,
                releaseCommit, stablePreflight).diagnostic,
                "release_authority_reference_mismatch")
            @Expect(authority.validate(loaded, reference,
                "0123456789abcdef0123456789abcdef01234567",
                stablePreflight).diagnostic,
                "release_authority_commit_mismatch")
        } finally { p8Remove(root) }
    }

    @TestCase
    public func p8Neg01TamperSelfReferenceSymlinkSwapAndDriftStop():
        Unit {
        let root = p8ResetRoot("target/p8-neg01")
        try {
            let repository = p8ResetRoot("${root}/repository")
            let options = p8Options("release-verify", root)
            options.repositoryRoot = repository
            let critical = p8Critical(repository)
            let reference = p8ReferenceTemplate()
            reference.runCriticalTreeHash =
                computeCkbRunCriticalTreeHash(critical, repository)
            let bundle = p8CreateBundle("${root}/bundle",
                "assets/a.txt", "first", reference: reference)
            options.candidateRoot = bundle[0]
            let executor = P8ReleaseExecutor()
            let changedInput = verifyCkbUnsignedReleaseCandidate(
                options, p8Identity(), reference, p8Hash("changed"),
                reference.certifiedRunInputHash,
                reference.releaseRepository, critical,
                P8ReleaseAuthority(),
                p8Preflight(options),
                P8EnvironmentProbe(),
                CkbReproFilesystemBundleReadBackend(), executor)
            @Expect(changedInput.diagnostic,
                "verified_release_input_changed")
            @Expect(executor.calls.size, 0)

            let rejectedAuthority = P8ReleaseAuthority()
            rejectedAuthority.fail = true
            let rejected = verifyCkbUnsignedReleaseCandidate(
                options, p8Identity(), reference, bundle[1],
                reference.certifiedRunInputHash,
                reference.releaseRepository, critical,
                rejectedAuthority, p8Preflight(options),
                P8EnvironmentProbe(),
                CkbReproFilesystemBundleReadBackend(), executor)
            @Expect(rejected.diagnostic,
                "release_asset_authority_invalid")
            @Expect(rejectedAuthority.calls, 1)
            @Expect(executor.calls.size, 0)

            let throwingAuthority = P8ReleaseAuthority()
            throwingAuthority.throwFailure = true
            let authorityException = verifyCkbUnsignedReleaseCandidate(
                options, p8Identity(), reference, bundle[1],
                reference.certifiedRunInputHash,
                reference.releaseRepository, critical,
                throwingAuthority, p8Preflight(options),
                P8EnvironmentProbe(),
                CkbReproFilesystemBundleReadBackend(), executor)
            @Expect(authorityException.diagnostic,
                "release_asset_authority_failed")
            @Expect(executor.calls.size, 0)

            let bProbe = P8EnvironmentProbe()
            bProbe.existing.add(options.candidateRoot)
            let bPreflight = validateCkbReproVerifyEnvironment(
                options, "4GB", bProbe)
            bProbe.identityVersion = "v2"
            let bDrift = verifyCkbUnsignedReleaseCandidate(
                options, p8Identity(), reference, bundle[1],
                reference.certifiedRunInputHash,
                reference.releaseRepository, critical,
                P8ReleaseAuthority(), bPreflight, bProbe,
                CkbReproFilesystemBundleReadBackend(), executor)
            @Expect(bDrift.diagnostic, "verify_input_identity_drift")
            @Expect(executor.calls.size, 0)

            let wrongReference = p8ReferenceTemplate()
            wrongReference.runCriticalTreeHash =
                reference.runCriticalTreeHash
            wrongReference.strictPassed = 150
            wrongReference.strictFailed = 14
            wrongReference.businessFailed = 14
            let oldRun = verifyCkbUnsignedReleaseCandidate(
                options, p8Identity(), wrongReference, bundle[1],
                wrongReference.certifiedRunInputHash,
                wrongReference.releaseRepository, critical,
                P8ReleaseAuthority(),
                p8Preflight(options),
                P8EnvironmentProbe(),
                CkbReproFilesystemBundleReadBackend(), executor)
            @Expect(oldRun.diagnostic, "portable_reference_invalid")
            @Expect(executor.calls.size, 0)

            File.writeTo(Path(repository).join("src/critical.cj"),
                "changed".toArray())
            let changedCritical = verifyCkbUnsignedReleaseCandidate(
                options, p8Identity(), reference, bundle[1],
                reference.certifiedRunInputHash,
                reference.releaseRepository, critical,
                P8ReleaseAuthority(),
                p8Preflight(options),
                P8EnvironmentProbe(),
                CkbReproFilesystemBundleReadBackend(), executor)
            @Expect(changedCritical.diagnostic,
                "run_critical_changed_rerun_a")
            @Expect(executor.calls.size, 0)

            let backend = CkbReproFilesystemBundleReadBackend()
            let listing = backend.list(bundle[0])
            let asset = p8FindEntry(listing, "contracts/p0.json")
            File.writeTo(Path(bundle[0]).join("contracts/replacement.txt"),
                "second".toArray())
            _ = launch("/bin/mv", [
                Path(bundle[0]).join("contracts/replacement.txt").toString(),
                Path(bundle[0]).join("contracts/p0.json").toString()
            ]).wait()
            let swapped = backend.open(bundle[0], asset)
            try {
                let buffer = Array<UInt8>(65536, repeat: 0)
                while (swapped.read(buffer) > 0) {}
                @Expect(swapped.noFollow(), true)
                @Expect(swapped.observedEntry().identity == asset.identity,
                    false)
            } finally { swapped.close() }

            let outside = Path(root).join("outside.txt")
            File.writeTo(outside, "outside".toArray())
            let linkRoot = p8ResetRoot("${root}/link-root")
            _ = launch("/bin/ln", ["-s",
                canonicalize(outside).toString(),
                "${linkRoot}/RELEASE-MANIFEST.json"]).wait()
            let linked = validateCkbReproBundleManifest(
                canonicalize(Path(linkRoot)).toString(), backend)
            @Expect(linked.contract.ok, false)
            @Expect(linked.contract.diagnostic,
                "bundle_root_entry_type_invalid")
        } finally { p8Remove(root) }
    }

    @TestCase
    public func p8Neg02ValidNonTargetScoresHoldWithoutDownstream():
        Unit {
        let root = p8ResetRoot("target/p8-neg02")
        try {
            for (score in [Int64(150), Int64(152), Int64(164)]) {
                let executor = P8RunExecutor()
                executor.score = score
                executor.raw = score
                let result = runCkbPortableReferenceHumanEval(
                    p8Options("run-certify", root), p8Identity(),
                    p8HashInputs(root), executor)
                @Expect(result.ok, false)
                @Expect(result.target.runValid, true)
                @Expect(result.target.targetScoreMatched, false)
                @Expect(result.diagnostic, "score_mismatch_hold")
                @Expect(result.runnerCalls, 1)
                @Expect(result.downstreamCalls, 0)
                @Expect(executor.calls.toArray(),
                    ["restore", "rebuild", "runner"])
            }
            let negative = CkbReproReferenceRunEvidence()
            negative.ok = true
            negative.totalCases = 164
            negative.rawPassed = 151
            negative.strictPassed = 151
            negative.businessFailed = -1
            negative.protocolInvalid = 14
            negative.transportUnresolved = 0
            negative.resultsHash = p8Hash("negative")
            @Expect(classifyCkbReferenceTargetScore(negative).runValid,
                false)
        } finally { p8Remove(root) }
    }

    @TestCase
    public func p8Reg01MirrorNestedAndFailureIsolationRemainStable():
        Unit {
        let root = p8ResetRoot("target/p8-reg01")
        try {
            let nested = p8CreateBundle("${root}/nested bundle",
                "one/two/three/知识🙂.txt", "nested")
            let loaded = validateCkbReproBundleManifest(
                nested[0], CkbReproFilesystemBundleReadBackend())
            @Expect(loaded.contract.ok, true)
            @Expect(loaded.manifest.assets.size, 14)

            let executor = P8RunExecutor()
            executor.failAt = "restore"
            let stopped = runCkbPortableReferenceHumanEval(
                p8Options("run-certify", root), p8Identity(),
                p8HashInputs(root), executor)
            @Expect(stopped.ok, false)
            @Expect(stopped.diagnostic, "restore_failed")
            @Expect(executor.calls.toArray(), ["restore"])
            let throwing = P8RunExecutor()
            throwing.throwAt = "restore"
            let isolated = runCkbPortableReferenceHumanEval(
                p8Options("run-certify", root), p8Identity(),
                p8HashInputs(root), throwing)
            @Expect(isolated.diagnostic, "restore_executor_failed")
            @Expect(throwing.calls.toArray(), ["restore"])

            let productionSentinel =
                Path(root).join("protected-production.ckb")
            File.writeTo(productionSentinel, "unchanged".toArray())
            _ = runCkbPortableReferenceHumanEval(
                p8Options("run-certify", root), p8Identity(),
                p8HashInputs(root), P8RunExecutor())
            @Expect(File.readFrom(productionSentinel),
                "unchanged".toArray())

            let production = File.readFrom(
                "../src/ckb_repro_verify.cj")
            let mirror = File.readFrom("src/ckb_repro_verify.cj")
            @Expect(String.fromUtf8(production).replace(
                "package cangjie_community_knowledge_base",
                "package cangjie_community_knowledge_base_test"),
                String.fromUtf8(mirror))
        } finally { p8Remove(root) }
    }
}

private func p8Options(mode: String, root: String):
    CkbReproVerifyOptions {
    let out = CkbReproVerifyOptions()
    out.mode = mode
    out.workRoot = "${root}/work"
    out.runtimeRoot = "${root}/runtime"
    out.qdrantRoot = "${root}/qdrant"
    out.sourceRoot = "${root}/source"
    out.candidateRoot = "${root}/candidate"
    out.repositoryRoot = "${root}/repository"
    out.p0ManifestPath = "${root}/inputs/p0.json"
    out.p1ScoreContractPath = "${root}/inputs/p1.json"
    out.p2LogicalSnapshotPath = "${root}/inputs/p2.tar"
    out.p3QdrantSnapshotPath = "${root}/inputs/p3.snapshot"
    out.p4BuildProofPath = "${root}/inputs/p4.json"
    out.p6EnvironmentLockPath = "${root}/inputs/p6.json"
    if (mode == "run-certify") {
        out.runCandidateCommit =
            "0123456789abcdef0123456789abcdef01234567"
    } else {
        out.releaseCommit =
            "89abcdef0123456789abcdef0123456789abcdef"
        out.p8ReferencePath = "${root}/inputs/p8.json"
    }
    out
}

private func p8Preflight(options: CkbReproVerifyOptions):
    CkbReproVerifyEnvironmentResult {
    let probe = P8EnvironmentProbe()
    probe.existing.add(options.candidateRoot)
    validateCkbReproVerifyEnvironment(options, "4GB", probe)
}

private func runCkbPortableReferenceHumanEval(
    options: CkbReproVerifyOptions, expected: CkbReproExpectedIdentity,
    hashInputs: CkbReproCertifiedRunHashInputs,
    executor: CkbReproRunCertificationExecutor):
    CkbReproRunCertificationResult {
    runCkbPortableReferenceHumanEval(
        options, expected, hashInputs, p8Preflight(options),
        P8EnvironmentProbe(), p8ReferenceTemplate(), executor)
}

private func p8Identity(): CkbReproExpectedIdentity {
    let out = CkbReproExpectedIdentity()
    out.knowledgeVersion = "portable-v1"
    out.logicalManifestHash = p8Hash("logical")
    out.vectorProofHash = p8Hash("vector")
    out.sourceLockHash = p8Hash("source-lock")
    out.pathProofHash = p8Hash("path-proof")
    out
}

private func p8ValidStage(rebuilt: Bool): CkbReproStageEvidence {
    let identity = p8Identity()
    let out = CkbReproStageEvidence()
    out.ok = true
    out.diagnostic = "ok"
    out.knowledgeVersion = identity.knowledgeVersion
    out.logicalManifestHash = identity.logicalManifestHash
    out.vectorProofHash = identity.vectorProofHash
    out.rawRecords = identity.rawRecords
    out.normalizedRecords = identity.normalizedRecords
    out.activeRecords = identity.activeRecords
    out.vectorPoints = identity.vectorPoints
    out.vectorDimension = identity.vectorDimension
    if (rebuilt) {
        out.sourceLockHash = identity.sourceLockHash
        out.pathProofHash = identity.pathProofHash
    }
    out
}

private func p8HashInputs(root: String):
    CkbReproCertifiedRunHashInputs {
    let repository = "${root}/repository"
    let out = CkbReproCertifiedRunHashInputs()
    out.logicalProofHash = p8Hash("logical")
    out.vectorProofHash = p8Hash("vector")
    out.datasetHash = p8Hash("dataset")
    out.authorityHash = p8Hash("authority")
    out.environmentHash = p8Hash("environment")
    out.experimentHash = p8Hash("experiment")
    out.inputEvidenceHash =
        p8Preflight(p8Options("run-certify", root)).inputEvidenceHash
    out.repositoryRoot = repository
    out.runCriticalManifest = p8Critical(repository)
    out
}

private func p8Critical(repository: String):
    CkbRunCriticalFilesManifest {
    let source = Path(repository).join("src")
    if (!exists(source)) { Directory.create(source, recursive: true) }
    let file = source.join("critical.cj")
    if (!exists(file)) { File.writeTo(file, "critical-v1".toArray()) }
    let manifest = CkbRunCriticalFilesManifest()
    manifest.schemaVersion = "ckb-run-critical-files-v1"
    let row = CkbRunCriticalFile()
    row.path = "src/critical.cj"
    row.status = "present"
    row.sha256 = p8HashBytes(File.readFrom(file))
    manifest.files.add(row)
    manifest
}

private func p8ReferenceTemplate(): CkbReproReferenceManifest {
    let out = CkbReproReferenceManifest()
    out.schemaVersion = "ckb-repro-reference-v1"
    out.baselineKind = "portable_release"
    out.evidenceStatus = "complete"
    out.releaseRepository =
        "l3gi0nXXXX/CangjieCommunityKnowledgeBase"
    out.releaseRepositoryUrl =
        "https://github.com/l3gi0nXXXX/CangjieCommunityKnowledgeBase"
    out.releaseBranch = "main"
    out.observedRemote =
        "https://github.com/l3gi0nXXXX/CangjieCommunityKnowledgeBase.git"
    out.runId = "portable-reference"
    out.knowledgeVersion = "portable-v1"
    out.vectorProofHash = p8Hash("vector")
    out.datasetVersion = "cangjie-humaneval-164-v1"
    out.runnerCommit =
        "0123456789abcdef0123456789abcdef01234567"
    out.claudeCodeVersion = "1.0"
    out.model = "GLM-5.2"
    out.providerFingerprint = p8Hash("provider")
    out.experimentGroup = CkbAbcdeGroups.D
    out.toolTransport = "claude-code"
    out.mcpTransport = "mcp_stdio"
    out.ckbRequired = true
    out.localDocsPolicy = "disabled"
    out.modelEffort = "max"
    out.modelBudget = "unbounded"
    out.timeoutSeconds = 3600
    out.transportRetryBudget = 10
    out.promptHash = p8Hash("prompt")
    out.resultsHash = p8Hash("results")
    out.runCriticalTreeHash = p8Hash("critical")
    out.certifiedRunInputHash = p8Hash("certified")
    out.totalCases = 164
    out.rawPassed = 151
    out.strictPassed = 151
    out.strictFailed = 13
    out.businessFailed = 13
    out
}

private func p8CreateBundle(root: String, relativePath: String,
    content: String, reference!: CkbReproReferenceManifest =
        p8ReferenceTemplate(), multipartP2!: Bool = false): (String, String) {
    let canonicalRoot = p8ResetRoot(root)
    let assets = ArrayList<CkbReproBundleAsset>()
    let rows = [
        ("contracts/p0.json", content, "p0_manifest"),
        ("contracts/p1.json", "p1", "p1_score_contract"),
        ("snapshots/p2.tar", "p2", "p2_logical_snapshot"),
        ("snapshots/p3.snapshot", "p3", "p3_qdrant_snapshot"),
        ("proofs/p4.json", "p4", "p4_build_proof"),
        ("evidence/p5.json", "p5", "p5_public_evidence"),
        ("locks/p6.json", "p6", "p6_environment_lock"),
        ("docs/reproduce.md", "p7", "p7_documentation"),
        ("reference/reference-run.json",
            renderCkbReproReferenceManifest(reference), "p8_reference"),
        ("locks/source.json", "source", "source_lock"),
        ("locks/authority-delivery.json", "authority",
            "authority_delivery"),
        ("reports/portable.json", "portable", "portable_report"),
        ("LICENSE", "license", "license"),
        ("release/release-commit.txt",
            "89abcdef0123456789abcdef0123456789abcdef",
            "release_commit")
    ]
    for (row in rows) {
        if (multipartP2 && row[2] == "p2_logical_snapshot") {
            let logicalBytes = row[1].toArray()
            for (index in 0..2) {
                let bytes = [logicalBytes[index]]
                let asset = CkbReproBundleAsset()
                asset.relativePath = "${row[0]}.part-000${index}"
                asset.bytes = bytes
                asset.size = bytes.size
                asset.sha256 = p8HashBytes(bytes)
                asset.inputKind = "verified_input"
                asset.role = row[2]
                asset.logicalAsset = row[0]
                asset.partIndex = index
                asset.partCount = 2
                asset.logicalSize = logicalBytes.size
                asset.logicalSha256 = p8HashBytes(logicalBytes)
                assets.add(asset)
                let target = Path(canonicalRoot).join(asset.relativePath)
                if (!exists(target.parent)) {
                    Directory.create(target.parent, recursive: true)
                }
                File.writeTo(target, bytes)
            }
            continue
        }
        let bytes = row[1].toArray()
        let asset = CkbReproBundleAsset()
        asset.relativePath = row[0]
        asset.bytes = bytes
        asset.size = bytes.size
        asset.sha256 = p8HashBytes(bytes)
        asset.inputKind = "verified_input"
        asset.role = row[2]
        asset.logicalAsset = row[0]
        asset.partIndex = 0
        asset.partCount = 1
        asset.logicalSize = asset.size
        asset.logicalSha256 = asset.sha256
        assets.add(asset)
        let target = Path(canonicalRoot).join(row[0])
        if (!exists(target.parent)) {
            Directory.create(target.parent, recursive: true)
        }
        File.writeTo(target, bytes)
    }
    File.writeTo(Path(canonicalRoot).join("RELEASE-MANIFEST.json"),
        writeCkbReproReleaseManifest(assets).toArray())
    (canonicalRoot, computeCkbReproBundleInputSetHash(assets))
}

private func p8AuthorityContract(loaded: CkbReproBundleLoadResult,
    omittedRole!: String = ""): CkbReproReleaseAuthorityContract {
    let contract = CkbReproReleaseAuthorityContract()
    let seen = HashSet<String>()
    for (asset in loaded.manifest.assets) {
        if (asset.role == omittedRole) { continue }
        let key = asset.role + "\t" + asset.logicalAsset
        if (seen.contains(key)) { continue }
        seen.add(key)
        let evidence = CkbReproReleaseAuthorityEvidence()
        evidence.role = asset.role
        evidence.logicalAsset = asset.logicalAsset
        evidence.size = asset.logicalSize
        evidence.sha256 = asset.logicalSha256
        contract.expected.add(evidence)
    }
    contract
}

private func p8AuthorityPreflight(loaded: CkbReproBundleLoadResult):
    CkbReproVerifyEnvironmentResult {
    let out = CkbReproVerifyEnvironmentResult()
    let seen = HashSet<String>()
    for (role in ["p0_manifest", "p1_score_contract",
        "p2_logical_snapshot", "p3_qdrant_snapshot", "p4_build_proof",
        "p6_environment_lock", "p8_reference"]) {
        for (asset in loaded.manifest.assets) {
            if (asset.role == role && !seen.contains(role)) {
                seen.add(role)
                out.inputRoles.add(role)
                out.inputHashes.add(asset.logicalSha256)
                out.inputSizes.add(asset.logicalSize)
            }
        }
    }
    out
}

private func p8FindEntry(entries: ArrayList<CkbReproBundleReadEntry>,
    relativePath: String): CkbReproBundleReadEntry {
    for (entry in entries) {
        if (entry.relativePath == relativePath) { return entry }
    }
    CkbReproBundleReadEntry()
}

private func p8Contract(ok: Bool, diagnostic: String):
    CkbReproContractResult {
    let out = CkbReproContractResult()
    out.ok = ok
    out.diagnostic = diagnostic
    out
}

private func p8Hash(value: String): String {
    p8HashBytes(value.toArray())
}

private func p8HashBytes(bytes: Array<UInt8>): String {
    ckbReproBundleHash(bytes)
}

private func p8ResetRoot(relative: String): String {
    let path = Path(relative)
    if (exists(path)) { remove(path, recursive: true) }
    Directory.create(path, recursive: true)
    canonicalize(path).toString()
}

private func p8Remove(path: String): Unit {
    if (exists(Path(path))) { remove(Path(path), recursive: true) }
}
