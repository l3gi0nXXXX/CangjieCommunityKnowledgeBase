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

private class P8ProductionRunnerProbe <: CkbReproRunnerInvoker {
    public var calls: Int64 = 0
    public var exitCode: Int64 = 9
    public func run(args: Array<String>): Int64 {
        this.calls += 1; this.exitCode
    }
}

private class P8RestoreControl <: CkbQdrantSnapshotExecutor {
    public var calls: Int64 = 0
    public var deleteCalls: Int64 = 0
    public var statusCode: Int64 = 200
    public var points: Int64 = ckbReproReleaseRecordCount()
    public var targetExists: Bool = false
    public func execute(request: CkbQdrantSnapshotRequest):
        CkbQdrantSnapshotResponse {
        this.calls += 1
        let out = CkbQdrantSnapshotResponse()
        if (request.method == "DELETE") {
            this.deleteCalls += 1; out.statusCode = 202; return out
        }
        if (this.calls == 1) {
            out.statusCode = if (this.targetExists) { 200 } else { 404 }
            return out
        }
        out.statusCode = this.statusCode
        out.bodyBytes = ("{\"result\":{\"status\":\"green\"," +
            "\"points_count\":${this.points},\"config\":{\"params\":{" +
            "\"vectors\":{\"size\":1024,\"distance\":\"Cosine\"}}}}}").toArray()
        out
    }
}

private class P8RestoreFiles <: CkbQdrantSnapshotFileExecutor {
    public var uploadStatus: Int64 = 200
    public var uploadCalls: Int64 = 0
    public func download(request: CkbQdrantSnapshotRequest,
        targetPath: String, maxBytes: Int64): CkbQdrantSnapshotFileTransferResult {
        CkbQdrantSnapshotFileTransferResult()
    }
    public func upload(request: CkbQdrantSnapshotRequest, sourcePath: String,
        expectedSize: Int64, expectedSha256: String): CkbQdrantSnapshotResponse {
        this.uploadCalls += 1
        let out = CkbQdrantSnapshotResponse()
        out.statusCode = this.uploadStatus
        out.diagnostic = if (this.uploadStatus == 200) { "ok" }
            else { "qdrant_snapshot_restore_failed" }
        out
    }
}

private class P8RestoreParity <: CkbRetrievalParityBackend {
    public var version: String = ""
    public func query(transport: String, query: String):
        CkbRetrievalParityResponse {
        let out = CkbRetrievalParityResponse()
        out.ok = true; out.diagnostic = "ok"; out.knowledgeVersion = this.version
        let hit = CkbRetrievalParityHit()
        hit.logicalId = "std/string/rune"
        hit.contentHash = p8Hash("std/string/rune|按 Rune 遍历")
        hit.citation = "按 Rune 遍历"; hit.rank = 1; out.hits.add(hit); out
    }
}

private class P8RebuildMaterialHandle <: CkbReproSourceMaterialReadHandle {
    public func read(maxBytes: Int64): Array<UInt8> { Array<UInt8>() }
    public func noFollow(): Bool { true }
    public func identity(): String { "unused" }
    public func observedIdentity(): String { "unused" }
    public func close(): Unit {}
}

private class P8RebuildMaterialBackend <:
    CkbReproMaterializingSourceBackend {
    public func fetch(entry: CkbReproSourceMaterialEntry): CkbReproBackendResult {
        CkbReproBackendResult(true, entry.expectedHash)
    }
    public func generate(entry: CkbReproSourceMaterialEntry): CkbReproBackendResult {
        CkbReproBackendResult(true, entry.expectedHash)
    }
    public func open(entry: CkbReproSourceMaterialEntry):
        CkbReproSourceMaterialReadHandle { P8RebuildMaterialHandle() }
}

private class P8RebuildMaterializer <: CkbReproOwnedSourceMaterializer {
    public func materialize(lock: CkbReproSourceLock,
        manifest: CkbReproSourceMaterialsManifest,
        backend: CkbReproMaterializingSourceBackend):
        CkbReproOwnedSourceMaterials {
        let out = CkbReproOwnedSourceMaterials(); out.ok = true
        out.diagnostic = "ok"; out.root = "/owned-fixture"
        out.proofHash = p8Hash("owned-materials"); out
    }
    public func cleanup(materials: CkbReproOwnedSourceMaterials): Bool { true }
}

private class P8RebuildAssembler <: CkbReproActualSourceAssembler {
    public var record: CangjieTypedRecord = CangjieTypedRecord()
    public func assemble(materials: CkbReproOwnedSourceMaterials,
        lock: CkbReproSourceLock): CkbReproActualSourceRecords {
        let out = CkbReproActualSourceRecords(); out.ok = true
        out.diagnostic = "ok"; out.typed.add(this.record); out
    }
}

private class P8RebuildPipeline <: CkbReproBuildBackend {
    public var readyVector: Bool = false
    public var stages: Int64 = 0
    public func run(stage: String,
        input: CkbReproPipelineInput): CkbReproBackendResult {
        this.stages += 1
        if (stage == "materialize") {
            p8WriteRebuildRuntime(input.request.options.outputRoot,
                input.request.candidateVersion, this.readyVector)
        }
        CkbReproBackendResult(true, "ok")
    }
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
    public var providerCalls: Int64 = 0
    public var modelCalls: Int64 = 0
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
    public func providerFingerprint(): String {
        this.providerCalls += 1; p8Hash("provider")
    }
    public func modelIdentity(): String {
        this.modelCalls += 1; "GLM-5.2"
    }
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
    public var mutateAt: String = ""
    public var replaceRootAt: String = ""
    public init() {}
    public func restore(options: CkbReproVerifyOptions):
        CkbReproStageEvidence {
        this.calls.add("restore")
        p8MutateCandidateIfRequested(options, this.mutateAt,
            this.replaceRootAt, "restore")
        if (this.throwAt == "restore") { throw Exception("restore") }
        p8ValidStage(false)
    }
    public func rebuild(options: CkbReproVerifyOptions):
        CkbReproStageEvidence {
        this.calls.add("rebuild")
        p8MutateCandidateIfRequested(options, this.mutateAt,
            this.replaceRootAt, "rebuild")
        if (this.throwAt == "rebuild") { throw Exception("rebuild") }
        p8ValidStage(true)
    }
    public func verifyPublicEvidence(options: CkbReproVerifyOptions):
        CkbReproContractResult {
        this.calls.add("evidence")
        p8MutateCandidateIfRequested(options, this.mutateAt,
            this.replaceRootAt, "evidence")
        if (this.throwAt == "evidence") { throw Exception("evidence") }
        if (this.failAt == "evidence") {
            p8Contract(false, "public_evidence_failed")
        } else { p8Contract(true, "ok") }
    }
    public func verifyDocumentation(options: CkbReproVerifyOptions):
        CkbReproContractResult {
        this.calls.add("docs")
        p8MutateCandidateIfRequested(options, this.mutateAt,
            this.replaceRootAt, "docs")
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
    public func releaseProbeReadsOnlyAuthorizedPortablePathReport(): Unit {
        let root = p8ResetRoot("target/p8-release-path-report")
        try {
            let probe = CkbReleaseFilesystemReproVerifyEnvironmentProbe(
                root, "l3gi0nXXXX/CangjieCommunityKnowledgeBase", { => 0 })
            @Expect(probe.privatePathDependencyCount(), 1)
            let path = Path(root).join("portable-path-report.json")
            let clean = "{\"ready\":true,\"scannedFieldCount\":17," +
                "\"machinePathCount\":0,\"unmappedCount\":0,\"findings\":[]}"
            File.writeTo(path, clean.toArray())
            @Expect(probe.privatePathDependencyCount(), 0)
            File.writeTo(path, clean.replace("\"machinePathCount\":0",
                "\"machinePathCount\":1").toArray())
            @Expect(probe.privatePathDependencyCount(), 1)
            File.writeTo(path, [0xff, 0xfe])
            @Expect(probe.privatePathDependencyCount(), 1)
        } finally { p8Remove(root) }
    }

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
            let releaseOptions = p8Options("release-verify", root)
            let releaseProbe = P8EnvironmentProbe()
            releaseProbe.existing.add(releaseOptions.candidateRoot)
            @Expect(validateCkbReproReleaseVerifyEnvironment(
                releaseOptions, "4GB", releaseProbe).ok, true)
            @Expect(releaseProbe.providerCalls, 0)
            @Expect(releaseProbe.modelCalls, 0)
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
            let extraDirectoryBundle = p8CreateBundle(
                "${root}/bundle-with-empty-directory",
                "assets/unused.txt", "p0")
            Directory.create(Path(extraDirectoryBundle[0]).join(
                "额外🙂/empty/nested"), recursive: true)
            @Expect(validateCkbReproBundleManifest(
                extraDirectoryBundle[0],
                CkbReproFilesystemBundleReadBackend()).contract.diagnostic,
                "bundle_root_extra_asset")
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
                "深层/知识🙂/结果.txt", "portable-content",
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
    public func p8Bnd02VerificationReportParserIsStrictAndUtf8Safe(): Unit {
        let report = p8VerificationReport()
        let text = renderCkbReproVerificationReport(report)
        let parsed = parseCkbReproVerificationReport(text.toArray())
        @Expect(parsed[0].ok, true)
        @Expect(validateCkbReproVerificationReport(parsed[1]).ok, true)
        @Expect(parseCkbReproVerificationReport([0xff, 0xfe])[0].diagnostic,
            "invalid_response_encoding")
        @Expect(parseCkbReproVerificationReport("{".toArray())[0].diagnostic,
            "verification_report_invalid")
        @Expect(parseCkbReproVerificationReport(text.replace(
            "\"runnerCalls\":0}", "\"runnerCalls\":0,\"extra\":true}")
            .toArray())[0].diagnostic, "verification_report_invalid")
        for (drift in [
            (report.referenceManifestHash, "sha256:bad"),
            (report.certifiedRunInputHash, "sha256:bad"),
            (report.runCriticalTreeHash, "sha256:bad"),
            (report.verifiedReleaseInputSetHash, "sha256:bad"),
            (report.bundleProofSetHash, "sha256:bad"),
            (report.releaseCommit, "not-a-commit"),
            (report.authorityHash, "sha256:bad"),
            ("\"runnerCalls\":0", "\"runnerCalls\":1"),
            ("\"restoreOk\":true", "\"restoreOk\":false"),
            ("\"rebuildOk\":true", "\"rebuildOk\":false"),
            ("\"publicEvidenceOk\":true", "\"publicEvidenceOk\":false"),
            ("\"documentationOk\":true", "\"documentationOk\":false")
        ]) {
            let drifted = parseCkbReproVerificationReport(
                text.replace(drift[0], drift[1]).toArray())
            @Expect(drifted[0].ok, true)
            @Expect(validateCkbReproVerificationReport(drifted[1]).diagnostic,
                "verification_report_invalid")
        }
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
            let contract = p8AuthorityContract("p0", reference)
            @Expect(buildCkbReproReleaseAuthorityContract(
                p8AuthorityInputs("p0", reference),
                "public_rebuild")[0].ok, true)
            for (missingPath in [
                "docs/reproducibility/quick-start.md",
                "source-materials-manifest.json",
                "authority-source-materials.json"]) {
                @Expect(buildCkbReproReleaseAuthorityContract(
                    p8AuthorityInputs("p0", reference,
                        omittedPath: missingPath),
                    "public_rebuild")[0].diagnostic,
                    "release_authority_layout_incomplete")
            }
            let preflight = p8AuthorityPreflight(contract)
            let authority = CkbReproCanonicalReleaseAssetAuthority(contract)
            let releaseCommit =
                "89abcdef0123456789abcdef0123456789abcdef"
            let accepted = authority.validate(
                loaded, reference, releaseCommit, preflight)
            @Expect(accepted.ok, true)
            @Expect(accepted.rolesComplete, true)
            @Expect(accepted.derivedAssetCount, 0)

            let multiRoleBundle = p8CreateBundle(
                "${root}/multi-role-bundle", "assets/unused.txt", "p0",
                reference: reference)
            let multiRoleLoaded = validateCkbReproBundleManifest(
                multiRoleBundle[0], CkbReproFilesystemBundleReadBackend())
            @Expect(multiRoleLoaded.contract.ok, true)
            let multiRoleContract = p8AuthorityContract("p0", reference)
            @Expect(CkbReproCanonicalReleaseAssetAuthority(
                multiRoleContract).validate(multiRoleLoaded, reference,
                releaseCommit, p8AuthorityPreflight(multiRoleContract)).ok,
                true)
            let duplicateEvidence = CkbReproReleaseAuthorityEvidence()
            duplicateEvidence.role = multiRoleContract.expected[0].role
            duplicateEvidence.logicalAsset =
                multiRoleContract.expected[0].logicalAsset
            duplicateEvidence.size = multiRoleContract.expected[0].size
            duplicateEvidence.sha256 = multiRoleContract.expected[0].sha256
            multiRoleContract.expected.add(duplicateEvidence)
            @Expect(CkbReproCanonicalReleaseAssetAuthority(
                multiRoleContract).validate(multiRoleLoaded, reference,
                releaseCommit, p8AuthorityPreflight(multiRoleContract)).diagnostic,
                "release_authority_contract_mismatch")

            let missing = p8AuthorityContract("p0", reference,
                omittedRole: "p5_public_evidence")
            @Expect(CkbReproCanonicalReleaseAssetAuthority(missing).validate(
                loaded, reference, releaseCommit, preflight).diagnostic,
                "release_authority_layout_incomplete")

            preflight.inputHashes[0] = p8Hash("mismatch")
            @Expect(authority.validate(
                loaded, reference, releaseCommit, preflight).diagnostic,
                "release_authority_preflight_mismatch")
            let stablePreflight = p8AuthorityPreflight(contract)
            let duplicatePreflight = p8AuthorityPreflight(contract)
            duplicatePreflight.inputRoles[6] = "p0_manifest"
            @Expect(authority.validate(loaded, reference, releaseCommit,
                duplicatePreflight).diagnostic,
                "release_authority_preflight_mismatch")
            let missingPreflight = p8AuthorityPreflight(contract)
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
    public func p8BRejectsSelfConsistentTamperedCandidateAgainstFrozenInputs():
        Unit {
        let root = p8ResetRoot("target/p8-frozen-authority-tamper")
        try {
            let reference = p8ReferenceTemplate()
            let frozenBundle = p8CreateBundle("${root}/frozen",
                "assets/unused.txt", "p0", reference: reference)
            let contract = p8AuthorityContract("p0", reference)
            let authority = CkbReproCanonicalReleaseAssetAuthority(contract)
            let preflight = p8AuthorityPreflight(contract)
            let releaseCommit =
                "89abcdef0123456789abcdef0123456789abcdef"

            let tamperedBundle = p8CreateBundle("${root}/tampered",
                "assets/unused.txt", "tampered", reference: reference)
            let tamperedLoaded = validateCkbReproBundleManifest(
                tamperedBundle[0], CkbReproFilesystemBundleReadBackend())
            @Expect(tamperedLoaded.contract.ok, true)
            @Expect(tamperedBundle[1] == frozenBundle[1], false)
            @Expect(authority.validate(tamperedLoaded, reference,
                releaseCommit, preflight).ok, false)
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

            let mutatingBundle = p8CreateBundle(
                "${root}/mutating-bundle", "assets/unused.txt", "first",
                reference: reference)
            options.candidateRoot = mutatingBundle[0]
            let mutatingExecutor = P8ReleaseExecutor()
            mutatingExecutor.mutateAt = "restore"
            let mutated = verifyCkbUnsignedReleaseCandidate(
                options, p8Identity(), reference, mutatingBundle[1],
                reference.certifiedRunInputHash,
                reference.releaseRepository, critical,
                P8ReleaseAuthority(), p8Preflight(options),
                P8EnvironmentProbe(),
                CkbReproFilesystemBundleReadBackend(), mutatingExecutor)
            @Expect(mutated.diagnostic, "bundle_revalidation_failed")
            @Expect(mutatingExecutor.calls.toArray(), ["restore"])

            for (boundary in [
                ("rebuild", ["restore", "rebuild"]),
                ("evidence", ["restore", "rebuild", "evidence"]),
                ("docs", ["restore", "rebuild", "evidence", "docs"])]) {
                let boundaryBundle = p8CreateBundle(
                    "${root}/mutating-${boundary[0]}",
                    "assets/unused.txt", "first", reference: reference)
                options.candidateRoot = boundaryBundle[0]
                let boundaryExecutor = P8ReleaseExecutor()
                boundaryExecutor.mutateAt = boundary[0]
                let boundaryResult = verifyCkbUnsignedReleaseCandidate(
                    options, p8Identity(), reference, boundaryBundle[1],
                    reference.certifiedRunInputHash,
                    reference.releaseRepository, critical,
                    P8ReleaseAuthority(), p8Preflight(options),
                    P8EnvironmentProbe(),
                    CkbReproFilesystemBundleReadBackend(), boundaryExecutor)
                @Expect(boundaryResult.diagnostic,
                    "bundle_revalidation_failed")
                @Expect(boundaryResult.ok, false)
                @Expect(boundaryExecutor.calls.toArray(), boundary[1])
            }

            let replacedBundle = p8CreateBundle(
                "${root}/replaced-bundle", "assets/unused.txt", "first",
                reference: reference)
            options.candidateRoot = replacedBundle[0]
            let replacingExecutor = P8ReleaseExecutor()
            replacingExecutor.replaceRootAt = "restore"
            let replaced = verifyCkbUnsignedReleaseCandidate(
                options, p8Identity(), reference, replacedBundle[1],
                reference.certifiedRunInputHash,
                reference.releaseRepository, critical,
                P8ReleaseAuthority(), p8Preflight(options),
                P8EnvironmentProbe(),
                CkbReproFilesystemBundleReadBackend(), replacingExecutor)
            @Expect(replaced.diagnostic, "bundle_revalidation_failed")
            @Expect(replacingExecutor.calls.toArray(), ["restore"])
            options.candidateRoot = bundle[0]

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
            let asset = p8FindEntry(listing,
                "reproducibility/RELEASE-MANIFEST.schema.json")
            File.writeTo(Path(bundle[0]).join(
                "reproducibility/replacement.txt"),
                "second".toArray())
            _ = launch("/bin/mv", [
                Path(bundle[0]).join(
                    "reproducibility/replacement.txt").toString(),
                Path(bundle[0]).join(
                    "reproducibility/RELEASE-MANIFEST.schema.json").toString()
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

            let hardlinkBundle = p8CreateBundle(
                "${root}/hardlink-bundle", "assets/unused.txt", "first",
                reference: reference)
            let outsideReadme = Path(root).join("outside-readme.md")
            File.writeTo(outsideReadme,
                File.readFrom(Path(hardlinkBundle[0]).join("README.md")))
            _ = launch("/bin/rm",
                ["${hardlinkBundle[0]}/README.md"]).wait()
            _ = launch("/bin/ln", [canonicalize(outsideReadme).toString(),
                "${hardlinkBundle[0]}/README.md"]).wait()
            let hardlinked = validateCkbReproBundleManifest(
                hardlinkBundle[0], backend)
            @Expect(hardlinked.contract.diagnostic,
                "bundle_root_entry_type_invalid")
        } finally { p8Remove(root) }
    }

    @TestCase
    public func p8Neg02OnlyScoresBelow151HoldWithoutDownstream():
        Unit {
        let root = p8ResetRoot("target/p8-neg02")
        try {
            let below = P8RunExecutor()
            below.score = 150
            below.raw = 150
            let held = runCkbPortableReferenceHumanEval(
                p8Options("run-certify", root), p8Identity(),
                p8HashInputs(root), below)
            @Expect(held.ok, false)
            @Expect(held.target.runValid, true)
            @Expect(held.target.targetScoreMatched, false)
            @Expect(held.diagnostic, "score_mismatch_hold")
            @Expect(held.runnerCalls, 1)
            @Expect(held.downstreamCalls, 0)
            @Expect(below.calls.toArray(), ["restore", "rebuild", "runner"])

            for (score in [Int64(151), Int64(152)]) {
                let executor = P8RunExecutor()
                executor.score = score
                executor.raw = score
                let result = runCkbPortableReferenceHumanEval(
                    p8Options("run-certify", root), p8Identity(),
                    p8HashInputs(root), executor)
                @Expect(result.ok, true)
                @Expect(result.target.runValid, true)
                @Expect(result.target.targetScoreMatched, true)
                @Expect(result.diagnostic, "target_matched")
                @Expect(result.runnerCalls, 1)
                @Expect(result.downstreamCalls, 0)
                @Expect(executor.calls.toArray(),
                    ["restore", "rebuild", "runner"])
            }
            let unresolved = CkbReproReferenceRunEvidence()
            unresolved.ok = true
            unresolved.totalCases = 164
            unresolved.rawPassed = 160
            unresolved.strictPassed = 158
            unresolved.businessFailed = 2
            unresolved.protocolInvalid = 2
            unresolved.transportUnresolved = 2
            unresolved.resultsHash = p8Hash("unresolved")
            let unresolvedTarget = classifyCkbReferenceTargetScore(unresolved)
            @Expect(unresolvedTarget.runValid, true)
            @Expect(unresolvedTarget.targetScoreMatched, true)
            @Expect(unresolvedTarget.status, "target_matched")
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
            @Expect(loaded.manifest.assets.size,
                p8AuthorityContract("nested", p8ReferenceTemplate())
                    .expected.size + 1)

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

    @TestCase
    public func productionFactoriesSeparateAOnlyRunnerFromBOnlyPublicChecks(): Unit {
        let calls = ArrayList<String>()
        let restore = CkbProductionRestoreStageOperation(
            { _options: CkbReproVerifyOptions =>
                calls.add("restore"); p8ValidStage(false) })
        let rebuild = CkbProductionRebuildStageOperation(
            { _options: CkbReproVerifyOptions =>
                calls.add("rebuild"); p8ValidStage(true) })
        let reference = CkbProductionReferenceRunOperation(
            { _options: CkbReproVerifyOptions =>
                calls.add("reference")
                let out = CkbReproReferenceRunEvidence(); out.ok = true; out })
        let publicEvidence = CkbProductionPublicEvidenceOperation(
            { _options: CkbReproVerifyOptions =>
                calls.add("public"); p8Contract(true, "ok") })
        let documentation = CkbProductionDocumentationOperation(
            { _options: CkbReproVerifyOptions =>
                calls.add("docs"); p8Contract(true, "ok") })
        let options = CkbReproVerifyOptions()
        let a = newCkbInjectedRunCertificationExecutorForTest(
            restore, rebuild, reference)
        _ = a.restore(options); _ = a.rebuild(options); _ = a.runReference(options)
        @Expect(calls.toArray(), ["restore", "rebuild", "reference"])
        calls.clear()
        let b = newCkbInjectedReleaseVerificationExecutorForTest(
            restore, rebuild, publicEvidence, documentation)
        _ = b.restore(options); _ = b.rebuild(options)
        _ = b.verifyPublicEvidence(options); _ = b.verifyDocumentation(options)
        @Expect(calls.toArray(), ["restore", "rebuild", "public", "docs"])

        let referenceManifest = parseCkbReproReferenceManifest(File.readFrom(Path(
            "../reproducibility/manifests/historical-reference-run.json")))[1]
        let lock = parseCkbReproEnvironmentLock(File.readFrom(Path(
            "../reproducibility/manifests/environment-lock.json")))[1]
        let inputs = CkbReproRunnerInputs()
        inputs.runId = "p8-production-probe"
        inputs.repoRoot = "/tmp/repo"; inputs.runsRoot = "/tmp/runs"
        inputs.datasetRoot = "/tmp/dataset"
        inputs.authorityManifestPath = "/tmp/authority.json"
        inputs.ckbBin = "/tmp/ckb"; inputs.ckbConfig = "/tmp/ckb.conf"
        inputs.ckbStore = "/tmp/store"; inputs.ckbHttpBase = "http://127.0.0.1"
        inputs.claudeBin = "/tmp/claude"; inputs.docsRoot = "/tmp/docs"
        inputs.candidateVersion = "candidate"
        inputs.knowledgeVersion = referenceManifest.knowledgeVersion
        inputs.providerIdentityHash = p8Hash("provider")
        inputs.providerIdentityArtifactPath = "/tmp/provider.json"
        inputs.frozenCandidateManifestPath = "/tmp/frozen.json"
        inputs.certificationPreflightPath = "/tmp/preflight.json"
        inputs.certificationRunManifestPath = "/tmp/run.json"
        let preflight = CkbReproEnvironmentPreflightResult()
        preflight.ok = true; preflight.startAllowed = true
        let runner = P8ProductionRunnerProbe()
        let actualA = newCkbP8AInjectedExecutorForTest(restore, rebuild,
            referenceManifest, lock, inputs, preflight, runner, "authority")
        let runOptions = CkbReproVerifyOptions(); runOptions.mode = "run-certify"
        let failed = actualA.runReference(runOptions)
        @Expect(failed.diagnostic, "reference_runner_failed")
        @Expect(runner.calls, 1)
    }

    @TestCase
    public func productionRestoreReadsCurrentRuntimeAndQdrantStatus(): Unit {
        let root = p8ResetRoot("/tmp/ckb-p8-production-restore")
        try {
            let live = P8RestoreControl()
            let fixture = p8RestoreFixture(root, live)
            let restored = CkbP8ProductionRestoreOperation(fixture.inputs)
                .execute(fixture.options)
            @Expect(restored.ok, true)
            @Expect(restored.diagnostic, "ok")
            @Expect(live.calls, 3)
            @Expect(live.deleteCalls, 1)
            @Expect(restored.rawRecords, 1)
            @Expect(restored.normalizedRecords, 1)
            @Expect(exists(Path(fixture.options.runtimeRoot)), false)

            let failedStatus = P8RestoreControl(); failedStatus.statusCode = 503
            fixture.inputs.qdrantControl = Some(failedStatus)
            let unavailable = CkbP8ProductionRestoreOperation(fixture.inputs)
                .execute(fixture.options)
            @Expect(unavailable.diagnostic,
                "qdrant_snapshot_status_read_failed")
            @Expect(failedStatus.calls, 3)
            @Expect(failedStatus.deleteCalls, 1)
            @Expect(exists(Path(fixture.options.runtimeRoot)), false)

            if (exists(Path(fixture.options.runtimeRoot))) {
                remove(Path(fixture.options.runtimeRoot), recursive: true)
            }
            let driftedStatus = P8RestoreControl(); driftedStatus.points = 7979
            fixture.inputs.qdrantControl = Some(driftedStatus)
            let drifted = CkbP8ProductionRestoreOperation(fixture.inputs)
                .execute(fixture.options)
            @Expect(drifted.diagnostic, "qdrant_restored_status_mismatch")
            @Expect(driftedStatus.calls, 3)
            @Expect(driftedStatus.deleteCalls, 1)
            @Expect(exists(Path(fixture.options.runtimeRoot)), false)

            let uploadControl = P8RestoreControl()
            let uploadFiles = P8RestoreFiles(); uploadFiles.uploadStatus = 500
            fixture.inputs.qdrantControl = Some(uploadControl)
            fixture.inputs.qdrantFile = Some(uploadFiles)
            let uploadFailed = CkbP8ProductionRestoreOperation(fixture.inputs)
                .execute(fixture.options)
            @Expect(uploadFailed.diagnostic, "qdrant_snapshot_restore_failed")
            @Expect(uploadFiles.uploadCalls, 1)
            @Expect(uploadControl.deleteCalls, 1)
            @Expect(exists(Path(fixture.options.runtimeRoot)), false)

            let existingControl = P8RestoreControl(); existingControl.targetExists = true
            let existingFiles = P8RestoreFiles()
            fixture.inputs.qdrantControl = Some(existingControl)
            fixture.inputs.qdrantFile = Some(existingFiles)
            let targetExists = CkbP8ProductionRestoreOperation(fixture.inputs)
                .execute(fixture.options)
            @Expect(targetExists.diagnostic, "qdrant_snapshot_target_exists")
            @Expect(existingFiles.uploadCalls, 0)
            @Expect(existingControl.deleteCalls, 0)

            let source = String.fromUtf8(File.readFrom(Path(
                "../src/ckb_repro_verify.cj")))
            @Expect(source.contains("public var restoredStatus"), false)
            @Expect(source.contains("public var visible: CkbStudentVisiblePathInput"),
                false)
            @Expect(source.contains("CkbP3FilesystemVerificationInputProvider"),
                true)
        } finally { p8Remove(root) }
    }

    @TestCase
    public func productionRebuildRejectsOutOfScopeRootsBeforeDependencies(): Unit {
        let options = CkbReproVerifyOptions()
        options.workRoot = "/tmp/ckb-p8-work"
        options.runtimeRoot = "/tmp/ckb-p8-runtime"
        let inputs = CkbP8ProductionRebuildInputs()
        inputs.authority.outputRoot = "/tmp/outside-runtime"
        inputs.authority.temporaryRoot = "/tmp/ckb-p8-work/rebuild-temporary"
        @Expect(CkbP8ProductionRebuildOperation(inputs).execute(options).diagnostic,
            "production_rebuild_root_mismatch")
        inputs.authority.outputRoot = options.runtimeRoot
        inputs.authority.temporaryRoot = "/tmp/outside-temporary"
        @Expect(CkbP8ProductionRebuildOperation(inputs).execute(options).diagnostic,
            "production_rebuild_root_mismatch")
        inputs.authority.temporaryRoot =
            "/tmp/ckb-p8-work/rebuild-temporary"
        @Expect(CkbP8ProductionRebuildOperation(inputs).execute(options).diagnostic,
            "rebuild_reader_required")
    }

    @TestCase
    public func productionRebuildUsesPinnedInputsAndIsolatedRuntime(): Unit {
        let root = p8ResetRoot("/tmp/ckb-p8-production-rebuild")
        try {
            let restore = p8RestoreFixture(root, P8RestoreControl())
            restore.options.workRoot = Path(root).join("work").toString()
            restore.options.candidateRoot =
                Path(root).join("public-build-inputs").toString()
            let control = P8RestoreControl(); let pipeline = P8RebuildPipeline()
            let inputs = p8RebuildInputs(root, restore, control, pipeline)
            let rebuilt = CkbP8ProductionRebuildOperation(inputs)
                .execute(restore.options)
            @Expect(rebuilt.ok, true)
            @Expect(rebuilt.diagnostic, "ok")
            @Expect(rebuilt.rawRecords, 1)
            @Expect(rebuilt.normalizedRecords, 1)
            @Expect(rebuilt.vectorPoints, ckbReproReleaseRecordCount())
            @Expect(pipeline.stages, 8)
            @Expect(control.calls, 2)

            if (exists(Path(restore.options.runtimeRoot))) {
                remove(Path(restore.options.runtimeRoot), recursive: true)
            }
            let readyControl = P8RestoreControl()
            let readyPipeline = P8RebuildPipeline(); readyPipeline.readyVector = true
            let readyInputs = p8RebuildInputs(root, restore,
                readyControl, readyPipeline)
            let disguised = CkbP8ProductionRebuildOperation(readyInputs)
                .execute(restore.options)
            @Expect(disguised.diagnostic, "production_rebuild_readback_mismatch")
            @Expect(readyControl.calls, 0)
            @Expect(exists(Path(readyInputs.authority.outputRoot)), false)
            @Expect(exists(Path(readyInputs.authority.temporaryRoot)), false)
        } finally { p8Remove(root) }
    }

    @TestCase
    public func manifestAuthorizedPublicAndDocumentationReadersFailClosed(): Unit {
        let root = p8ResetRoot("/tmp/ckb-p8-authorized-readers")
        try {
            let bundle = p8CreateBundle(Path(root).join("candidate").toString(),
                "assets/unused.txt", "manifest")
            let reader = CkbP8ManifestAuthorizedReader()
            @Expect(reader.start(bundle[0]).ok, true)
            let publicExport = reader.read("p5_public_evidence",
                "public-evidence-export.json", 64 * 1024)
            @Expect(publicExport[0].ok, true)
            @Expect(String.fromUtf8(publicExport[1]), "public-export")
            @Expect(reader.finish().ok, true)

            let docs = CkbP8FilesystemDocumentationReader()
            @Expect(docs.list(bundle[0]).size, 11)
            @Expect(docs.read(bundle[0], "README.md").found, true)
            @Expect(docs.finish().ok, true)

            let changed = CkbP8ManifestAuthorizedReader()
            @Expect(changed.start(bundle[0]).ok, true)
            File.writeTo(Path(bundle[0]).join("public-evidence-export.json"),
                "changed".toArray())
            @Expect(changed.read("p5_public_evidence",
                "public-evidence-export.json", 64 * 1024)[0].ok, false)

            let extraRoot = p8CreateBundle(
                Path(root).join("extra").toString(), "assets/unused.txt",
                "manifest")[0]
            Directory.create(Path(extraRoot).join("docs/reproducibility/extra"))
            @Expect(CkbP8ManifestAuthorizedReader().start(extraRoot).ok, false)

            let options = CkbReproVerifyOptions(); options.candidateRoot = bundle[0]
            options.workRoot = Path(root).join("work").toString()
            options.sourceRoot = Path(root).join("source").toString()
            Directory.create(Path(options.sourceRoot))
            File.writeTo(Path(options.sourceRoot).join("owned.txt"),
                "owned".toArray())
            let publicResult = CkbP8ProductionPublicEvidenceOperation()
                .execute(options)
            @Expect(publicResult.ok, false)
            @Expect(exists(Path(options.workRoot)), false)

            let cleanupRebuild = CkbP8ProductionRebuildInputs()
            cleanupRebuild.qdrantControl = Some(P8RestoreControl())
            let b = newCkbP8BProductionExecutor(
                CkbP8ProductionRestoreInputs(), cleanupRebuild,
                ["ckb-repro-build", "cangjie-humaneval-strict-score"])
            @Expect(b.verifyPublicEvidence(options).ok, false)
            @Expect(b.cleanup(options), true)
            @Expect(exists(Path(options.sourceRoot)), false)
        } finally { p8Remove(root) }
    }
}

@Test
public class CkbReproAuthorityLayoutBaselineTest {
    @TestCase
    public func authorityModesMatchIndependentFixture(): Unit {
        let reference = p8ReferenceTemplate()
        let rows = p8AuthorityRows("manifest", reference)
        @Expect(rows.size, 53)
        let built = buildCkbReproReleaseAuthorityContract(
            p8AuthorityInputs("manifest", reference), "public_rebuild")
        @Expect(built[0].ok, true)
        let contract = built[1]
        @Expect(contract.expected.size, 53)
        for (row in rows) {
            var matches = 0
            for (evidence in contract.expected) {
                if (evidence.logicalAsset == row[0] &&
                    evidence.role == row[2]) { matches++ }
            }
            @Expect(matches, 1)
        }
        for (evidence in contract.expected) {
            var matches = 0
            for (row in rows) {
                if (evidence.logicalAsset == row[0] &&
                    evidence.role == row[2]) { matches++ }
            }
            @Expect(matches, 1)
        }

        let bundledInputs = p8AuthorityInputs("manifest", reference)
        for (evidence in bundledInputs) {
            if (evidence.logicalAsset == "authority-source-materials.json") {
                evidence.logicalAsset =
                    "cangjie-humaneval-authority.tar.zst"
                evidence.size = Int64("authority-bundle".toArray().size)
                evidence.sha256 = p8Hash("authority-bundle")
            }
        }
        let bundled = buildCkbReproReleaseAuthorityContract(
            bundledInputs, "bundled")
        @Expect(bundled[0].ok, true)
        @Expect(bundled[1].expected.size, 53)
        var bundledAssetMatches = 0
        var rebuildAssetMatches = 0
        for (evidence in bundled[1].expected) {
            if (evidence.logicalAsset ==
                "cangjie-humaneval-authority.tar.zst") {
                bundledAssetMatches++
            }
            if (evidence.logicalAsset == "authority-source-materials.json") {
                rebuildAssetMatches++
            }
        }
        @Expect(bundledAssetMatches, 1)
        @Expect(rebuildAssetMatches, 0)
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

private func p8VerificationReport(): CkbReproReleaseVerificationResult {
    let report = CkbReproReleaseVerificationResult()
    report.ok = true; report.diagnostic = "verified"
    report.verifiedReleaseInputSetHash = p8Hash("release-input")
    report.bundleProofSetHash = p8Hash("proof-set")
    report.releaseCommit = "0123456789012345678901234567890123456789"
    report.certifiedRunInputHash = p8Hash("certified-input")
    report.runCriticalTreeHash = p8Hash("critical-tree")
    report.referenceManifestHash = p8Hash("reference")
    report.authorityHash = p8Hash("authority")
    report.restored.ok = true; report.restored.diagnostic = "ok"
    report.rebuilt.ok = true; report.rebuilt.diagnostic = "ok"
    report.publicEvidence.ok = true; report.publicEvidence.diagnostic = "ok"
    report.documentation.ok = true; report.documentation.diagnostic = "ok"
    report.runnerCalls = 0
    report
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
    out.modelFingerprint = "claude-code-glm-5.2"
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
        p8ReferenceTemplate()): (String, String) {
    let canonicalRoot = p8ResetRoot(root)
    let assets = ArrayList<CkbReproBundleAsset>()
    let rows = p8AuthorityRows(content, reference)
    for (row in rows) {
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
    if (relativePath != "assets/unused.txt") {
        let bytes = "relative:${relativePath}".toArray()
        let asset = CkbReproBundleAsset()
        asset.relativePath = relativePath
        asset.bytes = bytes
        asset.size = bytes.size
        asset.sha256 = p8HashBytes(bytes)
        asset.inputKind = "verified_input"
        asset.role = "portable_report"
        asset.logicalAsset = relativePath
        asset.partIndex = 0
        asset.partCount = 1
        asset.logicalSize = asset.size
        asset.logicalSha256 = asset.sha256
        assets.add(asset)
        let target = Path(canonicalRoot).join(relativePath)
        if (!exists(target.parent)) {
            Directory.create(target.parent, recursive: true)
        }
        File.writeTo(target, bytes)
    }
    File.writeTo(Path(canonicalRoot).join("RELEASE-MANIFEST.json"),
        writeCkbReproReleaseManifest(assets).toArray())
    (canonicalRoot, computeCkbReproBundleInputSetHash(assets))
}

private func p8AuthorityRows(content: String,
    reference: CkbReproReferenceManifest):
    Array<(String, String, String)> {
    [
        ("README.md", "readme", "p7_documentation"),
        ("docs/reproducibility/README.md", "docs", "p7_documentation"),
        ("docs/reproducibility/quick-start.md", "quick", "p7_documentation"),
        ("docs/reproducibility/restore-knowledge-base.md", "restore", "p7_documentation"),
        ("docs/reproducibility/rebuild-from-source.md", "rebuild", "p7_documentation"),
        ("docs/reproducibility/configure-claude-glm.md", "glm", "p7_documentation"),
        ("docs/reproducibility/run-humaneval-164.md", "run", "p7_documentation"),
        ("docs/reproducibility/verify-strict-pass-at-1.md", "verify", "p7_documentation"),
        ("docs/reproducibility/result-interpretation.md", "result", "p7_documentation"),
        ("docs/reproducibility/troubleshooting.md", "trouble", "p7_documentation"),
        ("docs/reproducibility/release-maintainer-runbook.md", "maintain", "p7_documentation"),
        ("docs/service-http-operations.md", "service-http", "p7_documentation"),
        ("reproducibility/PUBLIC-EVIDENCE.schema.json", "public-evidence-schema", "p1_score_contract"),
        ("reproducibility/RELEASE-MANIFEST.schema.json", content, "p0_manifest"),
        ("reproducibility/authority-source-materials.schema.json", "authority-source-schema", "authority_delivery"),
        ("reproducibility/source-lock.schema.json", "source-schema", "source_lock"),
        ("reproducibility/source-inventory.schema.json", "inventory-schema", "source_lock"),
        ("reproducibility/knowledge-selection.schema.json", "selection-schema", "p0_manifest"),
        ("reproducibility/authority-delivery.schema.json", "authority-schema", "authority_delivery"),
        ("reproducibility/environment-lock.schema.json", "environment-schema", "p6_environment_lock"),
        ("reproducibility/historical-reference-evidence.schema.json", "historical-evidence-schema", "p0_manifest"),
        ("reproducibility/reference-run.schema.json", "reference-schema", "p0_manifest"),
        ("reproducibility/portable-path-policy.schema.json", "path-schema", "portable_report"),
        ("reproducibility/run-critical-files.schema.json", "critical-schema", "p4_build_proof"),
        ("reproducibility/configs/provider.example.env", "provider", "p6_environment_lock"),
        ("reproducibility/configs/ckb.example.conf", "config", "p6_environment_lock"),
        ("reproducibility/configs/claude-mcp.example.json", "claude-mcp", "p6_environment_lock"),
        ("reproducibility/configs/experiment-profile.json", "experiment", "p1_score_contract"),
        ("reproducibility/manifests/source-lock.json", "source-lock", "source_lock"),
        ("reproducibility/manifests/source-inventory.jsonl", "inventory", "source_lock"),
        ("reproducibility/manifests/portable-path-policy.json", "path-policy", "portable_report"),
        ("reproducibility/manifests/run-critical-files.json", "critical", "p4_build_proof"),
        ("reproducibility/manifests/knowledge-selection.jsonl", "selection", "p0_manifest"),
        ("reproducibility/manifests/environment-lock.json", "environment", "p6_environment_lock"),
        ("reproducibility/manifests/authority-delivery.json", "authority", "authority_delivery"),
        ("reproducibility/manifests/authority-source-materials.json", "authority-source-manifest", "authority_delivery"),
        ("reproducibility/manifests/historical-reference-evidence.json", "historical-evidence", "p0_manifest"),
        ("reproducibility/manifests/historical-reference-run.json", "historical", "p0_manifest"),
        ("reproducibility/manifests/reference-run.json",
            renderCkbReproReferenceManifest(reference), "p8_reference"),
        ("reproducibility/licenses/THIRD_PARTY_NOTICES.md", "licenses", "license"),
        ("ckb-logical-snapshot.tar.zst", "p2", "p2_logical_snapshot"),
        ("qdrant-collection.snapshot", "p3", "p3_qdrant_snapshot"),
        ("portable-logical-proof.json", "proof", "p4_build_proof"),
        ("promotion-candidate.json", "candidate", "p4_build_proof"),
        ("portable-vector-proof.json", "vector-proof", "p4_build_proof"),
        ("public-evidence-export.json", "public-export", "p5_public_evidence"),
        ("source-materials-manifest.json", "sources", "source_lock"),
        ("authority-source-materials.json", "authority-source", "authority_delivery"),
        ("ckb-public-reference-evidence.tar.zst", "evidence", "p5_public_evidence"),
        ("leakage-report.json", "leakage", "portable_report"),
        ("portable-path-report.json", "paths", "portable_report"),
        ("retrieval-parity.json", "parity", "portable_report"),
        ("release/release-commit.txt",
            "89abcdef0123456789abcdef0123456789abcdef", "release_commit")
    ]
}

private func p8AuthorityContract(content: String,
    reference: CkbReproReferenceManifest,
    omittedRole!: String = ""): CkbReproReleaseAuthorityContract {
    buildCkbReproReleaseAuthorityContract(
        p8AuthorityInputs(content, reference, omittedRole: omittedRole),
        "public_rebuild")[1]
}

private func p8AuthorityInputs(content: String,
    reference: CkbReproReferenceManifest,
    omittedRole!: String = "", omittedPath!: String = ""):
    ArrayList<CkbReproReleaseAuthorityEvidence> {
    let inputs = ArrayList<CkbReproReleaseAuthorityEvidence>()
    for (row in p8AuthorityRows(content, reference)) {
        if (row[2] == omittedRole || row[0] == omittedPath) { continue }
        let evidence = CkbReproReleaseAuthorityEvidence()
        evidence.role = row[2]
        evidence.logicalAsset = row[0]
        evidence.size = row[1].toArray().size
        evidence.sha256 = p8Hash(row[1])
        inputs.add(evidence)
    }
    inputs
}

private func p8AuthorityPreflight(
    contract: CkbReproReleaseAuthorityContract):
    CkbReproVerifyEnvironmentResult {
    let out = CkbReproVerifyEnvironmentResult()
    for (role in ["p0_manifest", "p1_score_contract",
        "p2_logical_snapshot", "p3_qdrant_snapshot", "p4_build_proof",
        "p6_environment_lock", "p8_reference"]) {
        for (evidence in contract.expected) {
            if (p8TestAuthorityPreflightRole(evidence.logicalAsset) == role) {
                out.inputRoles.add(role)
                out.inputHashes.add(evidence.sha256)
                out.inputSizes.add(evidence.size)
            }
        }
    }
    out
}

private func p8TestAuthorityPreflightRole(logicalAsset: String): String {
    match (logicalAsset) {
        case "reproducibility/manifests/historical-reference-run.json" =>
            "p0_manifest"
        case "reproducibility/PUBLIC-EVIDENCE.schema.json" =>
            "p1_score_contract"
        case "ckb-logical-snapshot.tar.zst" => "p2_logical_snapshot"
        case "qdrant-collection.snapshot" => "p3_qdrant_snapshot"
        case "portable-logical-proof.json" => "p4_build_proof"
        case "reproducibility/manifests/environment-lock.json" =>
            "p6_environment_lock"
        case "reproducibility/manifests/reference-run.json" =>
            "p8_reference"
        case _ => ""
    }
}

private func p8FindEntry(entries: ArrayList<CkbReproBundleReadEntry>,
    relativePath: String): CkbReproBundleReadEntry {
    for (entry in entries) {
        if (entry.relativePath == relativePath) { return entry }
    }
    CkbReproBundleReadEntry()
}

private func p8MutateCandidateIfRequested(options: CkbReproVerifyOptions,
    mutateAt: String, replaceRootAt: String, stage: String): Unit {
    if (mutateAt == stage) {
        File.writeTo(Path(options.candidateRoot).join("README.md"),
            "tampered during ${stage}".toArray())
    }
    if (replaceRootAt == stage) {
        let old = "${options.candidateRoot}-old"
        _ = launch("/bin/mv", [options.candidateRoot, old]).wait()
        _ = launch("/bin/cp", ["-R", old, options.candidateRoot]).wait()
    }
}

private func p8Contract(ok: Bool, diagnostic: String):
    CkbReproContractResult {
    let out = CkbReproContractResult()
    out.ok = ok
    out.diagnostic = diagnostic
    out
}

private class P8RestoreFixture {
    public var options: CkbReproVerifyOptions = CkbReproVerifyOptions()
    public var inputs: CkbP8ProductionRestoreInputs =
        CkbP8ProductionRestoreInputs()
    public init() {}
}

private func p8RestoreFixture(root: String, control: P8RestoreControl):
    P8RestoreFixture {
    let fixture = P8RestoreFixture()
    let version = "portable-knowledge-restore-v1"
    let store = p8WriteRebuildRuntime(
        Path(root).join("source-store").toString(), version, true)
    let proofs = CkbLogicalSnapshotExportProofs()
    proofs.sourceState = CkbLogicalSnapshotSourceStates.PORTABLE_VECTOR_CANDIDATE
    proofs.portableKnowledgeVersion = version
    proofs.p4PortableProofHash = p8Hash("p4-portable-clean")
    proofs.p3VectorProofHash = p8Hash("p3-vector-ready")
    proofs.p3ProofReal = true; proofs.vectorState = EmbeddingProviderState.READY
    proofs.vectorCollection = "portable_vectors"; proofs.vectorCount = ckbReproReleaseRecordCount()
    proofs.vectorDimension = 1024; proofs.pathMachineFindingCount = 0
    proofs.pathUnmappedFindingCount = 0
    proofs.contaminationProofHash = p8Hash("contamination-clean")
    proofs.expectedStartPointerHash = ckbActiveSnapshotPointerIdentityHash(
        store.loadActiveSnapshotPointer())
    proofs.expectedEndPointerHash = proofs.expectedStartPointerHash
    let archive = Path(root).join("logical.snapshot").toString()
    let archiveBackend = CkbPortableReleaseArchiveBackend()
    let exported = exportCkbLogicalSnapshot(store, proofs, archive, archiveBackend)
    if (!exported.ok) {
        throw Exception("p8_restore_fixture_export_failed:${exported.diagnostic}")
    }
    let inspected = inspectCkbReleaseArchive(archiveBackend, archive)
    if (!inspected.ok) { throw Exception("p8_restore_fixture_inspect_failed") }
    let snapshotBytes = "qdrant-snapshot-中文🙂".toArray()
    let snapshotPath = Path(root).join("qdrant.snapshot").toString()
    File.writeTo(Path(snapshotPath), snapshotBytes)
    let qdrant = CkbQdrantSnapshotManifest()
    qdrant.schemaVersion = "ckb-qdrant-snapshot-v1"
    qdrant.imageDigest = p8Hash("image"); qdrant.qdrantMinorVersion = "1.14"
    qdrant.collection = inspected.manifest.vectorCollection
    qdrant.distance = "Cosine"; qdrant.dimension = 1024; qdrant.points = ckbReproReleaseRecordCount()
    qdrant.snapshotSha256 = ckbQdrantSnapshotBytesHash(snapshotBytes)
    qdrant.logicalManifestHash = inspected.manifest.manifestHash
    qdrant.vectorProofHash = inspected.manifest.p3VectorProofHash
    qdrant.payloadCanonicalHash = p8Hash("payload")
    let qdrantBuilt = buildCkbQdrantSnapshotManifest(qdrant)
    if (!qdrantBuilt.ok) {
        throw Exception(
            "p8_restore_fixture_qdrant_manifest_failed:${qdrantBuilt.diagnostic}")
    }
    let parity = P8RestoreParity(); parity.version = version
    let parityBuilt = buildCkbRetrievalParityManifest(
        version, inspected.manifest.manifestHash, parity)
    if (!parityBuilt.ok) { throw Exception("p8_restore_fixture_parity_failed") }
    let context = CkbPortablePathContext()
    context.policy = parseCkbPortablePathPolicy(File.readFrom(Path(
        "../reproducibility/manifests/portable-path-policy.json")))[1]
    let local = CkbPortableLocalRoot(); local.sourceId = "fixture"
    local.kind = "PROJECT_ROOT"; local.localRoot = canonicalize(Path(root)).toString()
    context.localRoots.schemaVersion = "ckb-portable-local-root-map-v1"
    context.localRoots.roots.add(local)
    fixture.options.p2LogicalSnapshotPath = archive
    fixture.options.p3QdrantSnapshotPath = snapshotPath
    fixture.options.runtimeRoot = Path(root).join("runtime").toString()
    fixture.inputs.archiveBackend = Some(archiveBackend)
    fixture.inputs.targetCollection = qdrant.collection
    fixture.inputs.qdrantManifest = qdrant
    fixture.inputs.qdrantControl = Some(control)
    fixture.inputs.qdrantFile = Some(P8RestoreFiles())
    fixture.inputs.pathContext = context
    fixture.inputs.parityManifest = parityBuilt.manifest
    fixture.inputs.parityBackend = Some(parity)
    fixture.inputs.sourceLockHash = p8Hash("source-lock")
    fixture.inputs.pathProofHash = p8Hash("path-proof")
    fixture
}

private func p8WriteRebuildRuntime(root: String, version: String,
    readyVector: Bool): FileKnowledgeStore {
    let store = FileKnowledgeStore(root)
    let raw = RawRecord(); raw.sourceId = "atom-rune"
    raw.title = "Rune iteration"; raw.content = "按 Rune 遍历字符串"
    raw.contentHash = p8Hash(raw.content)
    raw.metadata.knowledgeVersion = version
    raw.metadata.targetVersion = "1.0.0"
    let normalized = NormalizedRecord(); normalized.sourceId = raw.sourceId
    normalized.recordKind = "knowledge_atom"; normalized.title = raw.title
    normalized.chunk = raw.content
    normalized.citation = "https://docs.cangjie-lang.cn/docs/1.0.0/"
    normalized.metadata = raw.metadata
    let raws = ArrayList<RawRecord>(); raws.add(raw)
    let records = ArrayList<NormalizedRecord>(); records.add(normalized)
    let status = KnowledgeStatus(); status.activeKnowledgeVersion = version
    status.activeStateSource = "portable_candidate"
    status.storage.rawCount = 1; status.storage.normalizedCount = 1
    status.storage.indexCount = 1; status.storage.textIndexCount = 1
    status.storage.vectorIndexCount = if (readyVector) { ckbReproReleaseRecordCount() } else { 0 }
    status.storage.vectorBackend = "qdrant"
    status.storage.vectorState = if (readyVector) {
        EmbeddingProviderState.READY
    } else { EmbeddingProviderState.DEGRADED }
    status.storage.vectorCollection = "portable_vectors"
    status.storage.vectorActiveCollection = "portable_vectors"
    status.storage.vectorCandidateCollection = "portable_vectors_candidate"
    status.storage.vectorDimension = 1024
    status.storage.graphBackend = "local"
    status.storage.graphState = EmbeddingProviderState.READY
    let committed = store.writeActiveSnapshotTransaction(status, raws, records,
        records, ArrayList<VectorRecord>(), "portable_vectors",
        GraphBuildResult(), persistVectorFile: false)
    if (!committed.ok) { throw Exception("p8_restore_fixture_commit_failed") }
    store
}

private func p8RebuildInputs(root: String, restore: P8RestoreFixture,
    control: P8RestoreControl, pipeline: P8RebuildPipeline):
    CkbP8ProductionRebuildInputs {
    let candidate = Path(root).join("public-build-inputs")
    if (!exists(candidate)) { Directory.create(candidate, recursive: true) }
    let work = Path(root).join("work")
    if (!exists(work)) { Directory.create(work, recursive: true) }
    let context = restore.inputs.pathContext
    let authority = CkbReproPrivateBuildAuthority()
    authority.evalSupport = buildVersionedEvalSupportSnapshot(
        "cangjie_eval/cases/Cangjie-HumanEval",
        "humaneval-cangjie-164-v1")
    authority.leakageHash = ckbReproLeakageAuthorityHash(authority.leakage)
    authority.pathContext = context
    authority.outputRoot = Path(root).join("runtime").toString()
    authority.temporaryRoot = work.join("rebuild-temporary").toString()
    let record = CangjieTypedRecord(); record.sourceId = "docs/a"
    record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    record.path = "docs/a.md"; record.title = "Rune iteration"
    record.content = "按 Rune 遍历字符串"
    record.contentHash = cangjieTypedRecordContentHash(
        record.sourceId, record.content)
    let sourceLock =
        "{\"schemaVersion\":\"ckb-source-lock-v1\",\"sources\":[{" +
        "\"sourceId\":\"docs/a\",\"sourceType\":\"external_git\"," +
        "\"repository\":\"https://example.invalid/docs.git\"," +
        "\"commit\":\"0123456789012345678901234567890123456789\"," +
        "\"tree\":\"${p8Hash("tree")}\",\"path\":\"docs/a.md\"," +
        "\"fileHash\":\"${p8Hash("source")}\",\"license\":\"Apache-2.0\"," +
        "\"authMode\":\"anonymous\",\"assemblyRole\":\"community_docs\"," +
        "\"outputKind\":\"DOC_SECTION\"}]}"
    let lock = parseCkbReproSourceLock(sourceLock.toArray())[1]
    let materials = renderCkbSourceMaterialsManifest(
        buildCkbSourceMaterialsManifest(lock))
    let identity = ckbReproValidatedPublicTypedRecordIdentity(record, context)
    if (!identity.ok) { throw Exception("p8_rebuild_record_identity_failed") }
    let inventoryRow = CkbReproKnowledgeInventoryRow()
    inventoryRow.identity = identity.identity; inventoryRow.sourceId = record.sourceId
    inventoryRow.recordKind = record.recordKind
    inventoryRow.portableLocator = record.path
    inventoryRow.sourceType = "external_git"; inventoryRow.license = "Apache-2.0"
    inventoryRow.sourceLockEntryHash =
        canonicalCkbReproSourceLockEntryHash(lock.entries[0])
    let inventory = renderCkbReproKnowledgeInventoryRow(inventoryRow) + "\n"
    let selectionRow = CkbReproKnowledgeSelectionRow()
    selectionRow.identity = identity.identity; selectionRow.recordKind = record.recordKind
    selectionRow.decision = "selected"; selectionRow.reason = "knowledge_plane"
    let selection = renderCkbReproKnowledgeSelectionRow(selectionRow) + "\n"
    let policy = String.fromUtf8(File.readFrom(Path(
        "../reproducibility/manifests/portable-path-policy.json")))
    let routes = renderCkbReproApiRoutes(ArrayList<String>())
    let payloads = ArrayList<String>()
    payloads.add(""); payloads.add(sourceLock); payloads.add(materials)
    payloads.add(inventory); payloads.add(selection); payloads.add(policy)
    payloads.add(routes)
    let manifest = CkbReproBuildInputManifest()
    manifest.schemaVersion = "ckb-repro-build-inputs-v1"
    manifest.candidateVersion = "portable-knowledge-restore-v1"
    manifest.targetVersion = "1.0.0"; manifest.expectedRawCount = 1
    let roles = ckbReproPublicBuildInputRoles()
    for (i in 0..roles.size) {
        let asset = CkbReproBuildInputAsset(); asset.role = roles[i]
        asset.relativePath = "inputs/${roles[i]}.json"
        asset.size = payloads[i].toArray().size
        asset.sha256 = benchmarkGapSha256(payloads[i])
        manifest.assets.add(asset)
    }
    let contract = CkbReproBuildContract()
    contract.schemaVersion = "ckb-repro-build-contract-v1"
    contract.candidateVersion = manifest.candidateVersion
    contract.targetVersion = manifest.targetVersion; contract.expectedRawCount = 1
    contract.sourceLockHash = manifest.assets[1].sha256
    contract.sourceMaterialsHash = manifest.assets[2].sha256
    contract.knowledgeInventoryHash = manifest.assets[3].sha256
    contract.knowledgeSelectionHash = manifest.assets[4].sha256
    contract.portablePolicyHash = manifest.assets[5].sha256
    contract.apiRoutesHash = manifest.assets[6].sha256
    contract.assemblerIdentityHash = ckbFirstInitReproAssemblerIdentityHash()
    contract.privateAuthorityIdentityHash =
        ckbReproPrivateBuildAuthorityIdentity(authority)
    payloads[0] = renderCkbReproBuildContract(contract)
    manifest.assets[0].size = payloads[0].toArray().size
    manifest.assets[0].sha256 = benchmarkGapSha256(payloads[0])
    for (i in 0..manifest.assets.size) {
        let target = candidate.join(manifest.assets[i].relativePath)
        if (!exists(target.parent)) { Directory.create(target.parent, recursive: true) }
        File.writeTo(target, payloads[i].toArray())
    }
    let assembler = P8RebuildAssembler(); assembler.record = record
    let inputs = CkbP8ProductionRebuildInputs()
    inputs.buildManifest = manifest; inputs.authority = authority
    inputs.reader = Some(CkbReproFilesystemBundleReadBackend())
    inputs.materialBackend = Some(P8RebuildMaterialBackend())
    inputs.materializer = Some(P8RebuildMaterializer())
    inputs.assembler = Some(assembler); inputs.pipeline = Some(pipeline)
    inputs.archiveBackend = restore.inputs.archiveBackend
    inputs.qdrantManifest = restore.inputs.qdrantManifest
    inputs.targetCollection = "portable_vectors_rebuilt"
    inputs.qdrantControl = Some(control); inputs.qdrantFile = Some(P8RestoreFiles())
    inputs.parityManifest = restore.inputs.parityManifest
    inputs.parityBackend = restore.inputs.parityBackend
    inputs.pathProofHash = p8Hash("path-proof")
    inputs
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
