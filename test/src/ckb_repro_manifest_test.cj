package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists, remove}
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbReproManifestTest {
    @TestCase
    public func p0Ut01AllManifestsRoundTripCanonically(): Unit {
        let referenceBytes = p0Read("../reproducibility/manifests/historical-reference-run.json")
        let reference = parseCkbReproReferenceManifest(referenceBytes)
        @Expect(reference[0].ok, true)
        let referenceValidation = validateCkbReproReferenceManifest(reference[1], mode: "contract")
        @Expect(referenceValidation.ok, true)
        let referenceAgain = parseCkbReproReferenceManifest(
            referenceValidation.canonicalJson.toArray())
        @Expect(referenceAgain[0].ok, true)
        @Expect(renderCkbReproReferenceManifest(referenceAgain[1]),
            referenceValidation.canonicalJson)
        @Expect(referenceValidation.manifestHash.startsWith("sha256:"), true)

        let policy = parseCkbPortablePathPolicy(
            p0Read("../reproducibility/manifests/portable-path-policy.json"))
        @Expect(policy[0].ok, true)
        let policyValidation = validateCkbPortablePathPolicy(policy[1])
        @Expect(policyValidation.ok, true)
        let policyAgain = parseCkbPortablePathPolicy(policyValidation.canonicalJson.toArray())
        @Expect(policyAgain[0].ok, true)
        @Expect(renderCkbPortablePathPolicy(policyAgain[1]), policyValidation.canonicalJson)

        let critical = parseCkbRunCriticalFilesManifest(
            p0Read("../reproducibility/manifests/run-critical-files.json"))
        @Expect(critical[0].ok, true)
        let contract = validateCkbRunCriticalFilesManifest(critical[1], "..", mode: "contract")
        @Expect(contract.ok, true)
        @Expect(contract.presentCount > 0, true)
        @Expect(contract.plannedCount > 0, true)
        @Expect(contract.treeHash, "")
        let criticalAgain = parseCkbRunCriticalFilesManifest(contract.canonicalJson.toArray())
        @Expect(criticalAgain[0].ok, true)
        @Expect(renderCkbRunCriticalFilesManifest(criticalAgain[1]), contract.canonicalJson)
        @Expect(validateCkbRunCriticalFilesManifest(critical[1], "..",
            mode: "execution").diagnostic, "run_critical_manifest_not_frozen")
    }

    @TestCase
    public func p0Bnd01AggregatesUtf8RemoteAndRunCriticalBoundariesFailClosed(): Unit {
        let complete = p0CompleteReference()
        @Expect(validateCkbReproReferenceManifest(complete).ok, true)
        @Expect(normalizeCkbReproRepositoryRemote(
            "git@github.com:l3gi0nXXXX/CangjieCommunityKnowledgeBase.git"),
            "l3gi0nXXXX/CangjieCommunityKnowledgeBase")
        @Expect(normalizeCkbReproRepositoryRemote(
            "https://github.com/l3gi0nXXXX/CangjieCommunityKnowledgeBase.git"),
            "l3gi0nXXXX/CangjieCommunityKnowledgeBase")
        @Expect(normalizeCkbReproRepositoryRemote(
            "ssh://git@github.com/l3gi0nXXXX/CangjieCommunityKnowledgeBase.git"),
            "l3gi0nXXXX/CangjieCommunityKnowledgeBase")
        @Expect(normalizeCkbReproRepositoryRemote(
            "https://github.com/wrong/repository.git"), "wrong/repository")

        for (strict in [Int64(0), Int64(151), Int64(158), Int64(164)]) {
            let sample = p0CompleteReference()
            sample.strictPassed = strict
            sample.strictFailed = 164 - strict
            sample.businessFailed = sample.strictFailed
            sample.protocolInvalid = 0
            sample.rawPassed = if (strict < 158) { 158 } else { strict }
            @Expect(validateCkbReproReferenceManifest(sample).ok, true)
        }
        let unicode = p0CompleteReference()
        unicode.runId = "公开-复现🙂"
        let unicodeRoundTrip = parseCkbReproReferenceManifest(
            renderCkbReproReferenceManifest(unicode).toArray())
        @Expect(unicodeRoundTrip[0].ok, true)
        @Expect(unicodeRoundTrip[1].runId, "公开-复现🙂")
        @Expect(parseCkbReproReferenceManifest([0xff, 0xfe])[0].diagnostic,
            "invalid_response_encoding")
        @Expect(parseCkbPortablePathPolicy([0xff, 0xfe])[0].diagnostic,
            "invalid_response_encoding")
        @Expect(parseCkbRunCriticalFilesManifest([0xff, 0xfe])[0].diagnostic,
            "invalid_response_encoding")

        let empty = CkbRunCriticalFilesManifest()
        empty.schemaVersion = "ckb-run-critical-files-v1"
        @Expect(validateCkbRunCriticalFilesManifest(empty, "..").diagnostic,
            "run_critical_manifest_invalid")
        for (bad in ["src/*.cj", "/src/main.cj", "src/../main.cj", "src/main?.cj"]) {
            let manifest = p0MinimalCritical("present", bad)
            @Expect(validateCkbRunCriticalFilesManifest(manifest, "..").diagnostic,
                "run_critical_path_invalid")
        }
        let duplicate = p0MinimalCritical("present", "src/native_tls_bootstrap.cj")
        let second = CkbRunCriticalFile()
        second.path = duplicate.files[0].path
        second.status = duplicate.files[0].status
        second.sha256 = duplicate.files[0].sha256
        duplicate.files.add(second)
        @Expect(validateCkbRunCriticalFilesManifest(duplicate, "..").diagnostic,
            "run_critical_path_duplicate")
    }

    @TestCase
    public func p0Pos01HistoricalFactsAreFixedButExecutionEvidenceIsNotInvented(): Unit {
        let bytes = p0Read("../reproducibility/manifests/historical-reference-run.json")
        let parsed = parseCkbReproReferenceManifest(bytes)
        @Expect(parsed[0].ok, true)
        @Expect(parsed[1].baselineKind, "historical_pre_portable")
        @Expect(parsed[1].strictPassed, 151)
        @Expect(parsed[1].rawPassed, 158)
        @Expect(parsed[1].strictFailed, 13)
        @Expect(parsed[1].businessFailed, 3)
        @Expect(parsed[1].protocolInvalid, 10)
        @Expect(parsed[1].transportUnresolved, 0)
        @Expect(runCkbReproManifestVerify(bytes, mode: "contract").ok, true)
        @Expect(runCkbReproManifestVerify(bytes, mode: "execution").diagnostic,
            "identity_evidence_incomplete")
        @Expect(exists(Path("../reproducibility/manifests/reference-run.json")), false)
    }

    @TestCase
    public func p0Neg01IdentityAggregateHashAndPathTamperingAreRejected(): Unit {
        let repository = p0CompleteReference()
        repository.releaseRepository = "wrong/repository"
        @Expect(validateCkbReproReferenceManifest(repository).diagnostic,
            "release_repository_mismatch")
        for (field in 0..7) {
            let manifest = p0CompleteReference()
            if (field == 0) { manifest.releaseBranch = "develop" }
            if (field == 1) { manifest.knowledgeVersion = "" }
            if (field == 2) { manifest.datasetVersion = "" }
            if (field == 3) { manifest.experimentGroup = "" }
            if (field == 4) { manifest.mcpTransport = "" }
            if (field == 5) { manifest.ckbRequired = false }
            if (field == 6) { manifest.modelBudget = "" }
            if (field == 7) { manifest.runnerCommit = "" }
            @Expect(validateCkbReproReferenceManifest(manifest).ok, false)
        }
        let aggregate = p0CompleteReference()
        aggregate.strictFailed = 12
        @Expect(validateCkbReproReferenceManifest(aggregate).diagnostic, "invalid_aggregate")
        let hash = p0CompleteReference()
        hash.resultsHash = "sha256:tampered"
        @Expect(validateCkbReproReferenceManifest(hash).diagnostic, "hash_mismatch")

        let critical = parseCkbRunCriticalFilesManifest(
            p0Read("../reproducibility/manifests/run-critical-files.json"))[1]
        critical.files[0].sha256 = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
        @Expect(validateCkbRunCriticalFilesManifest(critical, "..").diagnostic, "hash_mismatch")
        let omittedRuntimeDependency = p0WithoutCriticalPath("src/main.cj")
        @Expect(validateCkbRunCriticalFilesManifest(omittedRuntimeDependency, "..").diagnostic,
            "run_critical_manifest_incomplete")
        let policy = parseCkbPortablePathPolicy(
            p0Read("../reproducibility/manifests/portable-path-policy.json"))[1]
        policy.allowlist.add("/tmp")
        @Expect(validateCkbPortablePathPolicy(policy).diagnostic,
            "path_policy_allowlist_invalid")
    }

    @TestCase
    public func p0Reg01CriticalTreeBoundaryAndProductionMirrorStayStable(): Unit {
        let source = String.fromUtf8(p0Read("../src/ckb_repro_manifest.cj"))
        let mirror = String.fromUtf8(p0Read("src/ckb_repro_manifest.cj"))
        @Expect(mirror.replace("package cangjie_community_knowledge_base_test",
            "package cangjie_community_knowledge_base"), source)

        let root = "target/p0-reg-critical-tree"
        if (exists(Path(root))) { remove(Path(root), recursive: true) }
        Directory.create(Path(root).join("src"), recursive: true)
        File.writeTo(Path(root).join("src/native_tls_bootstrap.cj"),
            p0Read("../src/native_tls_bootstrap.cj"))
        File.writeTo(Path(root).join("src/service_http.cj"),
            p0Read("../src/service_http.cj"))
        File.writeTo(Path(root).join("docs-note.md"), "说明🙂".toArray())
        let manifest = p0CriticalFromRepositoryManifest(
            ["src/native_tls_bootstrap.cj", "src/service_http.cj"])
        let firstTreeHash = computeCkbRunCriticalTreeHash(manifest, root)
        @Expect(firstTreeHash.startsWith("sha256:"), true)

        File.writeTo(Path(root).join("docs-note.md"), "说明变化🙂".toArray())
        let docsOnly = computeCkbRunCriticalTreeHash(manifest, root)
        @Expect(docsOnly, firstTreeHash)
        File.writeTo(Path(root).join("src/service_http.cj"),
            (String.fromUtf8(p0Read("../src/service_http.cj")) + "\n// critical change\n").toArray())
        let criticalChange = computeCkbRunCriticalTreeHash(manifest, root)
        @Expect(criticalChange == firstTreeHash, false)
        @Expect(validateCkbRunCriticalFilesManifest(manifest, root,
            mode: "execution").diagnostic, "hash_mismatch")
        remove(Path(root), recursive: true)
    }
}

private func p0CompleteReference(): CkbReproReferenceManifest {
    let manifest = CkbReproReferenceManifest()
    manifest.schemaVersion = "ckb-repro-reference-v1"
    manifest.baselineKind = "portable_release"
    manifest.evidenceStatus = "complete"
    manifest.releaseRepository = "l3gi0nXXXX/CangjieCommunityKnowledgeBase"
    manifest.releaseRepositoryUrl = "https://github.com/l3gi0nXXXX/CangjieCommunityKnowledgeBase"
    manifest.releaseBranch = "main"
    manifest.observedRemote = "https://github.com/l3gi0nXXXX/CangjieCommunityKnowledgeBase.git"
    manifest.runId = "portable-公开🙂"
    manifest.knowledgeVersion = "portable-v1"
    manifest.vectorProofHash = p0HashA()
    manifest.datasetVersion = "dataset-v1"
    manifest.runnerCommit = "0123456789012345678901234567890123456789"
    manifest.claudeCodeVersion = "2.1.179"
    manifest.model = "GLM-5.2"
    manifest.providerFingerprint = p0HashA()
    manifest.experimentGroup = "D-ckb-mcp-http"
    manifest.toolTransport = "streamable_http"
    manifest.mcpTransport = "mcp_http"
    manifest.ckbRequired = true
    manifest.localDocsPolicy = "disabled"
    manifest.modelEffort = "fixed"
    manifest.modelBudget = "fixed"
    manifest.timeoutSeconds = 3600
    manifest.transportRetryBudget = 10
    manifest.promptHash = p0HashA()
    manifest.resultsHash = p0HashA()
    manifest.runCriticalTreeHash = p0HashA()
    manifest.totalCases = 164
    manifest.rawPassed = 158
    manifest.strictPassed = 151
    manifest.strictFailed = 13
    manifest.businessFailed = 3
    manifest.protocolInvalid = 10
    manifest.transportUnresolved = 0
    manifest
}

private func p0MinimalCritical(status: String, firstPath: String): CkbRunCriticalFilesManifest {
    let source = parseCkbRunCriticalFilesManifest(
        p0Read("../reproducibility/manifests/run-critical-files.json"))[1]
    let result = CkbRunCriticalFilesManifest()
    result.schemaVersion = "ckb-run-critical-files-v1"
    for (path in [firstPath, "src/service_http.cj"]) {
        let row = CkbRunCriticalFile()
        row.path = path
        row.status = status
        for (existing in source.files) {
            if (existing.path == path) { row.sha256 = existing.sha256 }
        }
        result.files.add(row)
    }
    result
}

private func p0CriticalFromRepositoryManifest(paths: Array<String>): CkbRunCriticalFilesManifest {
    let source = parseCkbRunCriticalFilesManifest(
        p0Read("../reproducibility/manifests/run-critical-files.json"))[1]
    let result = CkbRunCriticalFilesManifest()
    result.schemaVersion = "ckb-run-critical-files-v1"
    for (path in paths) {
        for (existing in source.files) {
            if (existing.path == path) {
                let row = CkbRunCriticalFile()
                row.path = path
                row.status = "present"
                row.sha256 = existing.sha256
                result.files.add(row)
            }
        }
    }
    result
}

private func p0WithoutCriticalPath(omitted: String): CkbRunCriticalFilesManifest {
    let source = parseCkbRunCriticalFilesManifest(
        p0Read("../reproducibility/manifests/run-critical-files.json"))[1]
    let result = CkbRunCriticalFilesManifest()
    result.schemaVersion = source.schemaVersion
    for (existing in source.files) {
        if (existing.path == omitted) { continue }
        let row = CkbRunCriticalFile()
        row.path = existing.path
        row.status = existing.status
        row.sha256 = existing.sha256
        result.files.add(row)
    }
    result
}

private func p0Read(path: String): Array<UInt8> {
    try { File.readFrom(Path(path)) } catch (_: Exception) { [] }
}

private func p0HashA(): String {
    "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
}
