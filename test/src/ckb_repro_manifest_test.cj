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
        let portableReference = parseCkbReproReferenceManifest(
            p0Read("../reproducibility/manifests/reference-run.json"))
        @Expect(portableReference[0].ok, true)
        let portableReferenceValidation = validateCkbReproReferenceManifest(
            portableReference[1], mode: "contract")
        @Expect(portableReferenceValidation.ok, true)
        @Expect(portableReferenceValidation.manifestHash,
            "sha256:86ac13a68f21b7f63566bff5154e85edc14632e54d70dd4d93f0aa1bdfefbdec")
        let evidence = parseCkbHistoricalReferenceEvidence(
            p0Read("../reproducibility/manifests/historical-reference-evidence.json"))
        @Expect(evidence[0].ok, true)
        @Expect(validateCkbHistoricalReferenceEvidence(evidence[1], reference[1]).ok, true)

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
        @Expect(contract.plannedCount, 0)
        @Expect(contract.treeHash, "")
        let criticalAgain = parseCkbRunCriticalFilesManifest(contract.canonicalJson.toArray())
        @Expect(criticalAgain[0].ok, true)
        @Expect(renderCkbRunCriticalFilesManifest(criticalAgain[1]), contract.canonicalJson)
        let execution = validateCkbRunCriticalFilesManifest(critical[1], "..",
            mode: "execution")
        @Expect(execution.ok, true)
        @Expect(execution.treeHash,
            "sha256:d389767f9fef3b917bc676bafc4a2674a71fcc7da455e8994def0a6282cf07f6")
        var bundleListed = false
        var plusAuthorityListed = false
        for (file in critical[1].files) {
            if (file.path == "src/ckb_repro_bundle.cj") { bundleListed = true }
            if (file.path == "src/cangjie_humaneval_plus_authority.cj") {
                plusAuthorityListed = true
            }
        }
        @Expect(bundleListed, true)
        @Expect(plusAuthorityListed, true)
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
        let unresolved = p0CompleteReference()
        unresolved.strictPassed = 158
        unresolved.strictFailed = 6
        unresolved.rawPassed = 160
        unresolved.businessFailed = 2
        unresolved.protocolInvalid = 2
        unresolved.transportUnresolved = 2
        @Expect(validateCkbReproReferenceManifest(unresolved).ok, true)
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
    public func p0Pos01HistoricalFactsAndExecutionEvidenceAreComplete(): Unit {
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
        @Expect(runCkbReproManifestVerify(bytes, mode: "execution").ok, true)
        let evidence = parseCkbHistoricalReferenceEvidence(
            p0Read("../reproducibility/manifests/historical-reference-evidence.json"))
        @Expect(evidence[0].ok, true)
        @Expect(evidence[1].modelProfileCount, 164)
        @Expect(evidence[1].modelBudgetDerivation,
            "empty_maxBudgetUsd_means_runner_amount_limit_unset")
        @Expect(computeCkbHistoricalEvidenceTreeHash(evidence[1]),
            parsed[1].runCriticalTreeHash)
        @Expect(validateCkbHistoricalReferenceEvidence(evidence[1], parsed[1]).ok, true)
        let portable = parseCkbReproReferenceManifest(
            p0Read("../reproducibility/manifests/reference-run.json"))
        @Expect(portable[0].ok, true)
        @Expect(validateCkbReproReferenceManifest(portable[1]).ok, true)
        @Expect(portable[1].baselineKind, "portable_release")
        @Expect(portable[1].strictPassed, 158)
        @Expect(portable[1].transportUnresolved, 2)
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
        let historicalReference = parseCkbReproReferenceManifest(
            p0Read("../reproducibility/manifests/historical-reference-run.json"))[1]
        let historicalEvidence = parseCkbHistoricalReferenceEvidence(
            p0Read("../reproducibility/manifests/historical-reference-evidence.json"))[1]
        historicalEvidence.promptHash =
            "sha256:0000000000000000000000000000000000000000000000000000000000000000"
        @Expect(validateCkbHistoricalReferenceEvidence(
            historicalEvidence, historicalReference).diagnostic,
            "historical_evidence_hash_mismatch")
        let vectorEvidence = parseCkbHistoricalReferenceEvidence(
            p0Read("../reproducibility/manifests/historical-reference-evidence.json"))[1]
        vectorEvidence.vectorProofHash =
            "sha256:0000000000000000000000000000000000000000000000000000000000000000"
        @Expect(validateCkbHistoricalReferenceEvidence(
            vectorEvidence, historicalReference).diagnostic,
            "historical_evidence_hash_mismatch")
        let sourceEvidence = parseCkbHistoricalReferenceEvidence(
            p0Read("../reproducibility/manifests/historical-reference-evidence.json"))[1]
        sourceEvidence.runCriticalFiles[0].sha256 =
            "sha256:0000000000000000000000000000000000000000000000000000000000000000"
        @Expect(validateCkbHistoricalReferenceEvidence(
            sourceEvidence, historicalReference).diagnostic,
            "historical_evidence_hash_mismatch")

        let critical = parseCkbRunCriticalFilesManifest(
            p0Read("../reproducibility/manifests/run-critical-files.json"))[1]
        critical.files[0].sha256 = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
        @Expect(validateCkbRunCriticalFilesManifest(critical, "..").diagnostic, "hash_mismatch")
        let omittedRuntimeDependency = p0WithoutCriticalPath("src/main.cj")
        @Expect(validateCkbRunCriticalFilesManifest(omittedRuntimeDependency, "..").diagnostic,
            "run_critical_manifest_incomplete")
        let omittedOwnedLifecycle = p0WithoutCriticalPath(
            "src/ckb_repro_p8_owned_lifecycle.cj")
        @Expect(validateCkbRunCriticalFilesManifest(omittedOwnedLifecycle, "..").diagnostic,
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
        File.writeTo(Path(root).join("src/ckb_repro_bundle.cj"),
            p0Read("../src/ckb_repro_bundle.cj"))
        File.writeTo(Path(root).join("src/ckb_repro_authority_bundle.cj"),
            p0Read("../src/ckb_repro_authority_bundle.cj"))
        File.writeTo(Path(root).join("docs-note.md"), "说明🙂".toArray())
        let manifest = p0CriticalFromRepositoryManifest([
            "src/native_tls_bootstrap.cj", "src/service_http.cj",
            "src/ckb_repro_bundle.cj",
            "src/ckb_repro_authority_bundle.cj"])
        let firstTreeHash = computeCkbRunCriticalTreeHash(manifest, root)
        @Expect(firstTreeHash.startsWith("sha256:"), true)

        File.writeTo(Path(root).join("docs-note.md"), "说明变化🙂".toArray())
        let docsOnly = computeCkbRunCriticalTreeHash(manifest, root)
        @Expect(docsOnly, firstTreeHash)
        File.writeTo(Path(root).join("src/ckb_repro_bundle.cj"),
            "release-only change".toArray())
        let releaseOnly = computeCkbRunCriticalTreeHash(manifest, root)
        @Expect(releaseOnly == firstTreeHash, false)
        File.writeTo(Path(root).join("src/ckb_repro_authority_bundle.cj"),
            "weakened authority policy".toArray())
        let authorityPolicyChange = computeCkbRunCriticalTreeHash(
            manifest, root)
        @Expect(authorityPolicyChange == firstTreeHash, false)
        File.writeTo(Path(root).join("src/ckb_repro_authority_bundle.cj"),
            p0Read("../src/ckb_repro_authority_bundle.cj"))
        File.writeTo(Path(root).join("src/service_http.cj"),
            (String.fromUtf8(p0Read("../src/service_http.cj")) + "\n// critical change\n").toArray())
        let criticalChange = computeCkbRunCriticalTreeHash(manifest, root)
        @Expect(criticalChange == firstTreeHash, false)
        @Expect(validateCkbRunCriticalFilesManifest(manifest, root,
            mode: "execution").diagnostic, "hash_mismatch")
        remove(Path(root), recursive: true)
    }

    @TestCase
    public func p8Ut01PortableReferenceRoundTripsCertifiedRunInputHash(): Unit {
        let manifest = p0CompleteReference()
        manifest.certifiedRunInputHash = p0HashB()
        let validation = validateCkbReproReferenceManifest(manifest)
        @Expect(validation.ok, true)
        @Expect(validation.canonicalJson.contains(
            "\"certifiedRunInputHash\":\"${p0HashB()}\""), true)
        let parsed = parseCkbReproReferenceManifest(validation.canonicalJson.toArray())
        @Expect(parsed[0].ok, true)
        @Expect(parsed[1].certifiedRunInputHash, p0HashB())
        @Expect(renderCkbReproReferenceManifest(parsed[1]), validation.canonicalJson)
    }

    @TestCase
    public func p8Bnd01HistoricalReferenceKeepsCanonicalBytesAndHash(): Unit {
        let parsed = parseCkbReproReferenceManifest(
            p0Read("../reproducibility/manifests/historical-reference-run.json"))
        @Expect(parsed[0].ok, true)
        @Expect(parsed[1].certifiedRunInputHash, "")
        let validation = validateCkbReproReferenceManifest(parsed[1], mode: "execution")
        @Expect(validation.ok, true)
        @Expect(validation.canonicalJson.contains("\"certifiedRunInputHash\""), false)
        @Expect(validation.manifestHash,
            "sha256:0642644d26edeb6cdd9a0a2b0283247c0d2277b1646eac72165a2b3c03fb9a79")
        let historicalWithOptional = validation.canonicalJson.replace(
            "\"runCriticalTreeHash\":\"${parsed[1].runCriticalTreeHash}\"",
            "\"runCriticalTreeHash\":\"${parsed[1].runCriticalTreeHash}\"," +
            "\"certifiedRunInputHash\":\"${p0HashB()}\"")
        let optionalParsed = parseCkbReproReferenceManifest(historicalWithOptional.toArray())
        @Expect(optionalParsed[0].ok, true)
        @Expect(validateCkbReproReferenceManifest(
            optionalParsed[1], mode: "execution").ok, true)
        @Expect(parseCkbReproReferenceManifest([0xff, 0xfe])[0].diagnostic,
            "invalid_response_encoding")
    }

    @TestCase
    public func p8Neg01PortableCompleteRequiresValidCertifiedRunInputHash(): Unit {
        let missing = p0CompleteReference()
        missing.certifiedRunInputHash = ""
        @Expect(validateCkbReproReferenceManifest(missing).diagnostic,
            "certified_run_input_hash_required")

        let malformed = p0CompleteReference()
        malformed.certifiedRunInputHash = "sha256:bad"
        @Expect(validateCkbReproReferenceManifest(malformed).diagnostic, "hash_mismatch")

        let historical = validateCkbReproReferenceManifest(
            parseCkbReproReferenceManifest(
                p0Read("../reproducibility/manifests/historical-reference-run.json"))[1],
            mode: "execution")
        let unknownField = historical.canonicalJson.replace(
            "\"missingEvidence\":[]}", "\"missingEvidence\":[],\"unexpected\":true}")
        @Expect(parseCkbReproReferenceManifest(
            unknownField.toArray())[0].diagnostic, "reference_field_contract_invalid")
        @Expect(parseCkbReproReferenceManifest("{".toArray())[0].diagnostic,
            "reference_field_contract_invalid")
    }

    @TestCase
    public func p8Reg01ReferenceV1HistoricalAndPortableContractsCoexist(): Unit {
        let historical = parseCkbReproReferenceManifest(
            p0Read("../reproducibility/manifests/historical-reference-run.json"))
        @Expect(historical[0].ok, true)
        @Expect(renderCkbReproReferenceManifest(historical[1]).contains(
            "\"certifiedRunInputHash\""), false)

        let portable = p0CompleteReference()
        portable.certifiedRunInputHash = p0HashB()
        let rendered = renderCkbReproReferenceManifest(portable)
        @Expect(parseCkbReproReferenceManifest(rendered.toArray())[0].ok, true)
        @Expect(rendered.contains("\"schemaVersion\":\"ckb-repro-reference-v1\""), true)
        let schema = String.fromUtf8(
            p0Read("../reproducibility/reference-run.schema.json"))
        @Expect(schema.contains(
            "\"then\": {\"required\": [\"certifiedRunInputHash\"]}"), true)
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
    manifest.modelFingerprint = "claude-code-glm-5.2"
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
    manifest.certifiedRunInputHash = p0HashB()
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

private func p0HashB(): String {
    "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
}
