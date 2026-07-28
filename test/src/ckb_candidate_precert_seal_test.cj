package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.process.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbCandidatePrecertSealTest {
    @TestCase
    public func tR6UtLeakageFingerprintSetPreservesRuneWindowSemanticsAtScale(): Unit {
        let authorityRecords = ArrayList<NormalizedRecord>()
        for (i in 0..656) {
            let record = r6PrecertTrustedRecord("authority-${i}",
                "权威中文😀窗口-${i}-abcdefghijklmnopqrstuvwxyz")
            authorityRecords.add(record)
        }
        let duplicateFree = buildCangjieBenchmarkLeakageAuthority(authorityRecords)
        let uniqueCount = duplicateFree.fingerprints.size
        authorityRecords.add(r6PrecertTrustedRecord("authority-duplicate",
            "权威中文😀窗口-0-abcdefghijklmnopqrstuvwxyz"))
        let authority = buildCangjieBenchmarkLeakageAuthority(authorityRecords)
        @Expect(authority.fingerprintSet.size, uniqueCount)
        @Expect(authority.fingerprints.size, uniqueCount)
        let contaminated = r6PrecertTrustedRecord("student-contaminated",
            "前缀-权威中文😀窗口-0-abcdefghijklmnopqrstuvwx-后缀")
        @Expect(cangjieStudentRecordDiagnostic(contaminated, authority: authority).ok, false)
        let safe = ArrayList<NormalizedRecord>()
        for (i in 0..7373) {
            safe.add(r6PrecertTrustedRecord("student-${i}",
                "通用仓颉知识😀-${i}-安全内容"))
        }
        let started = ckbCoreNowMillis()
        @Expect(validateCangjieStudentKnowledgeRecords(safe, authority: authority).ok, true)
        @Expect(ckbCoreNowMillis() - started < 30000, true)
    }

    @TestCase
    public func tR6UtDeterministicHashesSealRecomputeAndUtf8(): Unit {
        let root = r6PrecertRoot("ut")
        let selected = r6PrecertCandidates(1, knowledgeSuffix: "中文😀")
        let store = r6PrecertStore(root, selected)
        let first = r6PrecertRun(store, selected, "${root}/out-a")
        let second = r6PrecertRun(store, selected, "${root}/out-b")
        @Expect(first.diagnostic, "ok"); @Expect(second.diagnostic, "ok")
        @Expect(first.ok, true); @Expect(second.ok, true)
        @Expect(first.candidateChecksum, second.candidateChecksum)
        @Expect(first.trustSealHash, second.trustSealHash)
        @Expect(first.summaryHash, second.summaryHash)
        let leakage = r6PrecertRead("${root}/out-a/student-leakage-report.jsonl")
        let serving = r6PrecertRead("${root}/out-a/student-serving-leakage-report.json")
        let authority = r6PrecertRead("${root}/out-a/authority-isolation.json")
        let atom = r6PrecertRead("${root}/out-a/atom-test-summary.json")
        let seal = r6PrecertRead("${root}/out-a/candidate-trust-seal.json")
        let rest = r6PrecertRead("${root}/out-a/student-serving-rest-report.json")
        let stdio = r6PrecertRead("${root}/out-a/student-serving-mcp-stdio-report.json")
        let http = r6PrecertRead("${root}/out-a/student-serving-mcp-http-report.json")
        let anonymous = r6PrecertRead("${root}/out-a/anonymous-atom-query-report.jsonl")
        let candidate = store.loadCandidateSnapshotImmutable("r6-precert-v1")
        @Expect(ckbCandidateTrustSealDiagnostic(seal, candidate.normalizedRecords,
            leakage, serving, authority, atom, restText: rest,
            mcpStdioText: stdio, mcpHttpText: http,
            anonymousQueryText: anonymous), "ok")
        @Expect(atom.contains("\"selectedAtomsHash\""), true)
        @Expect(atom.contains("\"bundleEvidenceHash\""), true)
    }

    @TestCase
    public func tR6BndZeroOneTenDuplicateEncodingAndLongText(): Unit {
        let root = r6PrecertRoot("bnd")
        let one = r6PrecertCandidates(1, knowledgeSuffix: "${r6PrecertRepeat("界", 1024)}😀")
        let store = r6PrecertStore(root, one)
        let officialStore = r6PrecertOfficialStore("${root}/official")
        let officialSnapshot = officialStore.loadCandidateSnapshotImmutable("r6-precert-v1")
        var officialAtomCount: Int64 = 0
        for (record in officialSnapshot.activeIndex) {
            if (record.recordKind == CangjieTypedRecordKinds.KNOWLEDGE_ATOM) { officialAtomCount += 1 }
        }
        @Expect(officialSnapshot.activeIndex.size > 0, true); @Expect(officialAtomCount, 0)
        let zero = r6PrecertRun(officialStore, "", "${root}/zero")
        @Expect(zero.diagnostic, "ok"); @Expect(zero.ok, true)
        @Expect(zero.selectedCount, 0); @Expect(zero.atomTestCount, 0)
        @Expect(zero.candidateChecksum,
            ckbCertifiedNormalizedRecordsChecksum(officialSnapshot.normalizedRecords))
        let oneResult = r6PrecertRun(store, one, "${root}/one")
        @Expect(oneResult.diagnostic, "ok"); @Expect(oneResult.ok, true)
        @Expect(r6PrecertRun(store, one + one, "${root}/duplicate").diagnostic,
            "duplicate_selected_atom")
        let invalid = "${root}/invalid.jsonl"; File.writeTo(Path(invalid), [UInt8(0xff), UInt8(0xfe)])
        let invalidOptions = CkbCandidatePrecertOptions(); invalidOptions.selectedAtomsPath = invalid
        invalidOptions.outputRoot = "${root}/invalid-out"
        invalidOptions.candidateVersion = "r6-precert-v1"
        invalidOptions.authorityStore = store.root.parent.join("authority-store").toString()
        @Expect(ckbBuildCandidatePrecertSeal(store, invalidOptions).diagnostic,
            "invalid_response_encoding")
        let ten = r6PrecertCandidates(10)
        let tenStore = r6PrecertStore("${root}/ten-store", ten)
        let tenResult = r6PrecertRun(tenStore, ten, "${root}/ten-out")
        @Expect(tenResult.diagnostic, "ok"); @Expect(tenResult.ok, true)
        @Expect(tenResult.selectedCount, 10); @Expect(tenResult.atomTestCount, 30)
    }

    @TestCase
    public func s2Pos01ImmutableCandidateProducesAllBoundArtifacts(): Unit {
        let root = r6PrecertRoot("pos")
        let selected = r6PrecertCandidates(1)
        let store = r6PrecertStore(root, selected)
        let before = store.loadCandidateSnapshotImmutable("r6-precert-v1").immutableManifestHash
        let result = r6PrecertRun(store, selected, "${root}/precert")
        @Expect(result.ok, true); @Expect(result.selectedCount, 1); @Expect(result.atomTestCount, 3)
        for (name in ["student-leakage-report.jsonl", "anonymous-atom-query-report.jsonl",
            "student-serving-leakage-report.json", "student-serving-rest-report.json",
            "student-serving-mcp-stdio-report.json", "student-serving-mcp-http-report.json",
            "authority-isolation.json", "atom-test-summary.json", "candidate-trust-seal.json",
            "candidate-precert-summary.json"]) { @Expect(exists(Path("${root}/precert/${name}")), true) }
        @Expect(r6PrecertRead("${root}/precert/candidate-precert-summary.json").contains(
            "\"candidateChecksum\":\"${result.candidateChecksum}\""), true)
        for (name in ["student-serving-rest-report.json",
            "student-serving-mcp-stdio-report.json",
            "student-serving-mcp-http-report.json"]) {
            let transport = r6PrecertRead("${root}/precert/${name}")
            @Expect(transport.contains("\"probeCount\":4"), true)
            @Expect(transport.contains("\"responseHash\":\"sha256:"), true)
            @Expect(transport.contains("\"expectedBlocked\":true"), true)
            @Expect(transport.contains("\"expectedBlocked\":false"), true)
            @Expect(transport.contains("\"passed\":true"), true)
        }
        @Expect(store.loadCandidateSnapshotImmutable("r6-precert-v1").immutableManifestHash, before)
        @Expect(store.loadActiveSnapshotPointer().valid, false)
    }

    @TestCase
    public func s2Neg01TamperMissingAuthorityAndCandidateDriftFailClosed(): Unit {
        let root = r6PrecertRoot("neg")
        let selected = r6PrecertCandidates(1)
        let noAuthority = r6PrecertStore("${root}/no-authority", selected, authority: false)
        @Expect(r6PrecertRun(noAuthority, selected, "${root}/no-authority-out").diagnostic,
            "authority_isolation_proof_required")
        let store = r6PrecertStore("${root}/store", selected)
        let tampered = selected.replace("General atomic knowledge", "Drifted atomic knowledge")
        @Expect(r6PrecertRun(store, tampered, "${root}/tampered-out").diagnostic,
            "atom_candidate_hash_mismatch")
        let broken = selected.replace("\"expected\":\"3\"", "\"expected\":\"99\"")
        @Expect(r6PrecertRun(store, broken, "${root}/broken-out").ok, false)
        let inside = r6PrecertRun(store, selected, "${store.root.toString()}/proof")
        @Expect(inside.diagnostic, "candidate_precert_output_inside_store")
        let nestedStore = r6PrecertStore("${root}/nested", selected)
        let nestedSelected = "${root}/nested-selected.jsonl"
        File.writeTo(Path(nestedSelected), selected.toArray())
        let authorityParent = CkbCandidatePrecertOptions()
        authorityParent.selectedAtomsPath = nestedSelected
        authorityParent.outputRoot = "${root}/authority-parent-out"
        authorityParent.candidateVersion = "r6-precert-v1"
        authorityParent.authorityStore = nestedStore.root.parent.toString()
        @Expect(ckbBuildCandidatePrecertSeal(nestedStore,
            authorityParent).diagnostic, "authority_store_must_be_separate")
        let authorityChild = CkbCandidatePrecertOptions()
        authorityChild.selectedAtomsPath = nestedSelected
        authorityChild.outputRoot = "${root}/authority-child-out"
        authorityChild.candidateVersion = "r6-precert-v1"
        authorityChild.authorityStore =
            nestedStore.root.join("authority-child").toString()
        Directory.create(Path(authorityChild.authorityStore), recursive: true)
        @Expect(ckbBuildCandidatePrecertSeal(nestedStore,
            authorityChild).diagnostic, "authority_store_must_be_separate")
        Directory.create(Path("${root}/exists"), recursive: true)
        @Expect(r6PrecertRun(store, selected, "${root}/exists").diagnostic,
            "candidate_precert_output_exists")
        let writeFail = r6PrecertRun(store, selected, "${root}/write-fail",
            faultInjector: R6PrecertThrowInjector())
        @Expect(writeFail.diagnostic, "candidate_precert_artifact_write_failed")
        @Expect(exists(Path("${root}/write-fail")), false)
        let driftStore = r6PrecertStore("${root}/drift", selected)
        let drift = r6PrecertRun(driftStore, selected, "${root}/drift-out",
            faultInjector: R6PrecertCandidateDriftInjector(driftStore))
        @Expect(drift.diagnostic, "candidate_precert_candidate_drift")
        @Expect(exists(Path("${root}/drift-out")), false)
    }

    @TestCase
    public func s2E2E01RestStdioAndMcpHttpEnforceSameStudentEvidenceBoundary(): Unit {
        let root = r6PrecertRoot("s2-transport")
        let selected = r6PrecertCandidates(1)
        _ = r6PrecertStore(root, selected)
        let service = CkbCommandLoopService(CkbRuntimeConfig(),
            FileKnowledgeStore("${root}/atoms-store"))
        let generic = "{\"taskId\":\"anonymous-probe\",\"taskText\":\"General atomic knowledge\",\"targetVersion\":\"1.0.0\"}"
        let caseProbe = "{\"taskId\":\"CJ-HUMANEVAL-125\",\"taskText\":\"CJ-HUMANEVAL-125\",\"targetVersion\":\"1.0.0\"}"
        let promptProbe = "{\"taskId\":\"prompt-probe\",\"taskText\":\"public enum EvalValue Number Int64\",\"targetVersion\":\"1.0.0\"}"
        for (probe in [caseProbe, promptProbe]) {
            let outputs = r6PrecertTransportOutputs(service, probe)
            for (output in outputs) {
                @Expect(output.contains("General atomic knowledge"), false)
            }
        }
        let outputs = r6PrecertTransportOutputs(service, generic)
        for (output in outputs) {
            @Expect(output.contains("General atomic knowledge"), true)
            @Expect(output.contains("cangjie-humaneval"), false)
            @Expect(output.contains("visible-benchmark"), false)
            @Expect(output.contains("curated-gap-"), false)
        }
        let versionArgs =
            "{\"targetVersion\":\"1.0.0\",\"sourceSet\":\"all\"}"
        let versionCall =
            "{\"jsonrpc\":\"2.0\",\"id\":9,\"method\":\"tools/call\",\"params\":{\"name\":\"cangjie_version_resolve\",\"arguments\":${versionArgs}}}"
        let versions = [
            ckbApiHandle(service, "POST", "/v1/cangjie/version/resolve",
                versionArgs, []),
            CkbMcpStdioServer(service).handleRequest(versionCall),
            r6PrecertMcpHttp(service, versionCall)
        ]
        for (output in versions) {
            let lower = output.toAsciiLower()
            @Expect(lower.contains("eval-support"), false)
            @Expect(lower.contains("humaneval"), false)
            @Expect(lower.contains("1.0.0"), true)
        }
    }

    @TestCase
    public func s2Bnd01MalformedTransportPayloadsFailClosedWithoutPanic(): Unit {
        let root = r6PrecertRoot("s2-malformed")
        let service = CkbCommandLoopService(CkbRuntimeConfig(),
            FileKnowledgeStore("${root}/empty-store"))
        let rest = ckbApiHandle(service, "POST",
            "/v1/cangjie/task-knowledge-pack", "{bad", [])
        let stdio = CkbMcpStdioServer(service).handleRequest("{bad")
        let http = r6PrecertMcpHttp(service, "{bad")
        @Expect(rest.contains("\"ok\":false"), true)
        @Expect(stdio.contains("\"error\""), true)
        @Expect(http.contains("\"error\""), true)
        @Expect(rest.contains("General atomic knowledge"), false)
        @Expect(stdio.contains("General atomic knowledge"), false)
        @Expect(http.contains("General atomic knowledge"), false)
    }

    @TestCase
    public func s6mUt01MaterializesBoundActiveSnapshot(): Unit {
        let root = r6PrecertRoot("s6m-ut")
        let source = r6PrecertStore(root, r6PrecertCandidates(1,
            knowledgeSuffix: "中文😀"))
        let candidate = source.loadCandidateSnapshotImmutable("r6-precert-v1")
        let options = CkbCandidateRuntimeMaterializeOptions()
        options.sourceStore = canonicalize(source.root).toString()
        options.outputStore = s6mOutput(root, "runtime")
        options.candidateVersion = "r6-precert-v1"
        let result = ckbMaterializeCandidateRuntime(options)
        let runtime = FileKnowledgeStore(options.outputStore)
        let active = runtime.loadActiveSnapshot()
        let metadata = runtime.loadMetadataStatus()
        @Expect(result.ok, true); @Expect(result.diagnostic, "ok")
        @Expect(result.activeVersion, candidate.version)
        @Expect(result.candidateChecksum, candidate.candidateChecksum)
        @Expect(result.rawCount, candidate.rawCount)
        @Expect(result.normalizedCount, candidate.normalizedCount)
        @Expect(result.activeCount, candidate.activeIndex.size)
        @Expect(active.valid, true); @Expect(active.activeVersion, candidate.version)
        @Expect(active.candidateVersion, candidate.version)
        @Expect(active.hasVectorArtifact, false)
        @Expect(metadata.valid, true)
        @Expect(metadata.activeVersion, candidate.version)
        @Expect(metadata.vectorState, EmbeddingProviderState.DEGRADED)
        @Expect(metadata.vectorIndexCount, 0)
        @Expect(metadata.vectorDimension, 0)
        @Expect(metadata.vectorDegradedReason, "vector_snapshot_missing")
        @Expect(ckbCertifiedNormalizedRecordsChecksum(active.normalizedRecords),
            candidate.candidateChecksum)
        @Expect(result.pointerIdentityHash,
            ckbActiveSnapshotPointerIdentityHash(runtime.loadActiveSnapshotPointer()))
        @Expect(result.immutableManifestHash.startsWith("sha256:"), true)
        @Expect(result.cleanManifestHash.startsWith("sha256:"), true)
        @Expect(result.manifestEvidenceHash.toRuneArray().size, 64)
        @Expect(result.authorityHash.startsWith("sha256:"), true)
        @Expect(result.sourceEvidenceHash.startsWith("sha256:"), true)
        @Expect(result.txIdHash.startsWith("sha256:"), true)
        @Expect(result.transactionPayloadHash.startsWith("hsha256:"), true)
        @Expect(result.transactionPayloadHash.toRuneArray().size, 72)
        let pointer = runtime.loadActiveSnapshotPointer()
        @Expect(runtime.readText("transactions/${pointer.txId}/COMMIT")
            .contains("payloadHash=${result.transactionPayloadHash}\n"), true)
        for (record in active.rawRecords) {
            @Expect(record.sourceId == "doc-syntax", false)
        }
    }

    @TestCase
    public func s6mBnd01Utf8AndPathBoundariesFailClosed(): Unit {
        let root = r6PrecertRoot("s6m-bnd")
        let source = r6PrecertStore(root, r6PrecertCandidates(1,
            knowledgeSuffix: "${r6PrecertRepeat("中", 2048)}😀"))
        let valid = CkbCandidateRuntimeMaterializeOptions()
        valid.sourceStore = canonicalize(source.root).toString()
        valid.outputStore = s6mOutput(root, "runtime-unicode")
        valid.candidateVersion = "r6-precert-v1"
        @Expect(ckbMaterializeCandidateRuntime(valid).ok, true)

        let invalidRoot = r6PrecertRoot("s6m-invalid-utf8")
        let invalidSource = r6PrecertStore(invalidRoot, r6PrecertCandidates(1))
        File.writeTo(invalidSource.root.join(
            "raw/candidate/r6-precert-v1/records.ckb"), [UInt8(0xff), UInt8(0xfe)])
        let invalid = CkbCandidateRuntimeMaterializeOptions()
        invalid.sourceStore = canonicalize(invalidSource.root).toString()
        invalid.outputStore = s6mOutput(invalidRoot, "runtime")
        invalid.candidateVersion = "r6-precert-v1"
        @Expect(ckbMaterializeCandidateRuntime(invalid).diagnostic,
            "candidate_immutable_invalid_response_encoding")
        @Expect(exists(Path(invalid.outputStore)), false)

        for ((output, diagnostic) in [
            (canonicalize(source.root).toString(),
                "candidate_runtime_output_exists"),
            (canonicalize(source.root).join("nested").toString(),
                "candidate_runtime_store_overlap"),
            (canonicalize(source.root.parent).toString(),
                "candidate_runtime_output_exists")
        ]) {
            let blocked = CkbCandidateRuntimeMaterializeOptions()
            blocked.sourceStore = canonicalize(source.root).toString()
            blocked.outputStore = output
            blocked.candidateVersion = "r6-precert-v1"
            @Expect(ckbMaterializeCandidateRuntime(blocked).diagnostic, diagnostic)
        }
        let sourceLink = s6mOutput(root, "source-link")
        @Expect(launch("/bin/ln",
            ["-s", canonicalize(source.root).toString(), sourceLink]).wait(), 0)
        let linkedSource = CkbCandidateRuntimeMaterializeOptions()
        linkedSource.sourceStore = sourceLink
        linkedSource.outputStore = s6mOutput(root, "linked-source-runtime")
        linkedSource.candidateVersion = "r6-precert-v1"
        @Expect(ckbMaterializeCandidateRuntime(linkedSource).diagnostic,
            "candidate_runtime_source_path_invalid")
        let realParent = s6mOutput(root, "real-parent")
        Directory.create(Path(realParent), recursive: true)
        let linkedParent = s6mOutput(root, "linked-parent")
        @Expect(launch("/bin/ln", ["-s", realParent, linkedParent]).wait(), 0)
        let parentLink = CkbCandidateRuntimeMaterializeOptions()
        parentLink.sourceStore = canonicalize(source.root).toString()
        parentLink.outputStore = Path(linkedParent).join("runtime").toString()
        parentLink.candidateVersion = "r6-precert-v1"
        @Expect(ckbMaterializeCandidateRuntime(parentLink).diagnostic,
            "candidate_runtime_output_path_invalid")
    }

    @TestCase
    public func s6mBnd02InvalidUtf8InEveryManifestLayerFailsClosed(): Unit {
        for ((kind, relative) in [
            ("manifest", "candidate-artifacts/r6-precert-v1/manifest.ckb"),
            ("clean", "candidate-artifacts/r6-precert-v1/clean-candidate-manifest.json"),
            ("audit", "candidate-artifacts/r6-precert-v1/clean-candidate-audit.json")
        ]) {
            let root = r6PrecertRoot("s6m-utf8-${kind}")
            let source = r6PrecertStore(root, r6PrecertCandidates(1))
            File.writeTo(source.root.join(relative), [UInt8(0xff), UInt8(0xfe)])
            let options = CkbCandidateRuntimeMaterializeOptions()
            options.sourceStore = canonicalize(source.root).toString()
            options.outputStore = s6mOutput(root, "runtime")
            options.candidateVersion = "r6-precert-v1"
            @Expect(ckbMaterializeCandidateRuntime(options).diagnostic,
                "candidate_immutable_invalid_response_encoding")
            @Expect(exists(Path(options.outputStore)), false)
        }
    }

    @TestCase
    public func s6mPos01RuntimeSupportsFrozenSealAndCertificationIdentity(): Unit {
        let root = r6PrecertRoot("s6m-pos")
        let selected = r6PrecertCandidates(1)
        let source = r6PrecertStore(root, selected)
        let precert = r6PrecertRun(source, selected, "${root}/precert")
        @Expect(precert.ok, true)
        let options = CkbCandidateRuntimeMaterializeOptions()
        options.sourceStore = canonicalize(source.root).toString()
        options.outputStore = s6mOutput(root, "runtime")
        options.candidateVersion = "r6-precert-v1"
        @Expect(ckbMaterializeCandidateRuntime(options).ok, true)
        let runtime = FileKnowledgeStore(options.outputStore)
        let frozenOptions = CkbFrozenCandidateSealOptions()
        frozenOptions.expectedKnowledgeVersion = "r6-precert-v1"
        frozenOptions.expectedCandidateChecksum = precert.candidateChecksum
        frozenOptions.inputHash = benchmarkGapSha256("s6m-input")
        frozenOptions.configHash = benchmarkGapSha256("s6m-config")
        frozenOptions.modelHash = benchmarkGapSha256("s6m-model")
        frozenOptions.studentLeakageProofJson =
            r6PrecertRead("${root}/precert/candidate-trust-seal.json")
        frozenOptions.studentLeakageArtifactJson =
            r6PrecertRead("${root}/precert/student-leakage-report.jsonl")
        frozenOptions.anonymousQueryArtifactJson =
            r6PrecertRead("${root}/precert/student-serving-leakage-report.json")
        frozenOptions.authorityIsolationArtifactJson =
            r6PrecertRead("${root}/precert/authority-isolation.json")
        frozenOptions.atomTestArtifactJson =
            r6PrecertRead("${root}/precert/atom-test-summary.json")
        frozenOptions.restLeakageArtifactJson =
            r6PrecertRead("${root}/precert/student-serving-rest-report.json")
        frozenOptions.mcpStdioLeakageArtifactJson =
            r6PrecertRead("${root}/precert/student-serving-mcp-stdio-report.json")
        frozenOptions.mcpHttpLeakageArtifactJson =
            r6PrecertRead("${root}/precert/student-serving-mcp-http-report.json")
        frozenOptions.anonymousAtomQueryArtifactJson =
            r6PrecertRead("${root}/precert/anonymous-atom-query-report.jsonl")
        let frozen = ckbBuildFrozenCandidateSeal(runtime, frozenOptions)
        @Expect(frozen.ok, true); @Expect(frozen.diagnostic, "ok")
        @Expect(ckbFrozenCandidateManifestDiagnostic(runtime, frozen.manifestJson), "ok")
        let identity = prepareCkbCertificationHttpIdentity(
            CkbCommandLoopService(CkbRuntimeConfig(), runtime), runtime)
        @Expect(identity.valid, true); @Expect(identity.diagnostic, "ok")
        @Expect(identity.activeVersion, "r6-precert-v1")
        @Expect(identity.candidateChecksum, precert.candidateChecksum)
    }

    @TestCase
    public func s6mNeg01TamperNonemptyOverlapAndDuplicateArgsAreBlocked(): Unit {
        let root = r6PrecertRoot("s6m-neg")
        let source = r6PrecertStore(root, r6PrecertCandidates(1))
        let before = source.loadCandidateSnapshotImmutable(
            "r6-precert-v1").immutableManifestHash
        Directory.create(Path("${root}/nonempty"), recursive: true)
        File.writeTo(Path("${root}/nonempty/sentinel"), "unchanged".toArray())
        let nonempty = CkbCandidateRuntimeMaterializeOptions()
        nonempty.sourceStore = canonicalize(source.root).toString()
        nonempty.outputStore = s6mOutput(root, "nonempty")
        nonempty.candidateVersion = "r6-precert-v1"
        @Expect(ckbMaterializeCandidateRuntime(nonempty).diagnostic,
            "candidate_runtime_output_exists")
        @Expect(String.fromUtf8(File.readFrom(Path("${root}/nonempty/sentinel"))),
            "unchanged")
        let manifest = source.root.join(
            "candidate-artifacts/r6-precert-v1/clean-candidate-manifest.json")
        File.writeTo(manifest,
            r6PrecertRead(manifest.toString()).replace("\"ok\":true",
                "\"ok\":false").toArray())
        let tampered = CkbCandidateRuntimeMaterializeOptions()
        tampered.sourceStore = canonicalize(source.root).toString()
        tampered.outputStore = s6mOutput(root, "tampered-runtime")
        tampered.candidateVersion = "r6-precert-v1"
        @Expect(ckbMaterializeCandidateRuntime(tampered).ok, false)
        @Expect(exists(Path(tampered.outputStore)), false)
        @Expect(runCkbCandidateRuntimeMaterializeCli([
            "cangjie-candidate-runtime-materialize",
            "--source-store", canonicalize(source.root).toString(),
            "--source-store", canonicalize(source.root).toString(),
            "--output-store", s6mOutput(root, "duplicate-runtime"),
            "--candidate-version", "r6-precert-v1"
        ]), 2)
        @Expect(exists(Path("${root}/duplicate-runtime")), false)
        @Expect(runCkbCandidateRuntimeMaterializeCli([
            "cangjie-candidate-runtime-materialize", "--unknown", "x"
        ]), 2)
        @Expect(runCkbCandidateRuntimeMaterializeCli([
            "cangjie-candidate-runtime-materialize",
            "--source-store", canonicalize(source.root).toString()
        ]), 2)
        @Expect(before != "", true)
    }

    @TestCase
    public func s6mNeg02PostCommitTamperHasNoValidRuntimePointer(): Unit {
        for (kind in ["commit", "pointer", "payload"]) {
            let root = r6PrecertRoot("s6m-tamper-${kind}")
            let source = r6PrecertStore(root, r6PrecertCandidates(1))
            let manifestPath = source.root.join(
                "candidate-artifacts/r6-precert-v1/manifest.ckb")
            let cleanPath = source.root.join(
                "candidate-artifacts/r6-precert-v1/clean-candidate-manifest.json")
            let sourceBefore = String.fromUtf8(File.readFrom(manifestPath)) +
                String.fromUtf8(File.readFrom(cleanPath))
            let options = CkbCandidateRuntimeMaterializeOptions()
            options.sourceStore = canonicalize(source.root).toString()
            options.outputStore = s6mOutput(root, "runtime")
            options.candidateVersion = "r6-precert-v1"
            let result = ckbMaterializeCandidateRuntime(options,
                faultInjector: S6mTamperInjector(kind))
            @Expect(result.ok, false)
            @Expect(FileKnowledgeStore(options.outputStore)
                .loadActiveSnapshotPointer().valid, false)
            @Expect(String.fromUtf8(File.readFrom(manifestPath)) +
                String.fromUtf8(File.readFrom(cleanPath)), sourceBefore)
        }
    }

    @TestCase
    public func s6mNeg03OutputSymlinkSwapDoesNotDeleteOrMutateSource(): Unit {
        let root = r6PrecertRoot("s6m-symlink-swap")
        let source = r6PrecertStore(root, r6PrecertCandidates(1))
        let sourcePath = canonicalize(source.root).toString()
        let before = source.loadCandidateSnapshotImmutable("r6-precert-v1")
        let options = CkbCandidateRuntimeMaterializeOptions()
        options.sourceStore = sourcePath
        options.outputStore = s6mOutput(root, "runtime")
        options.candidateVersion = "r6-precert-v1"
        let result = ckbMaterializeCandidateRuntime(options,
            faultInjector: S6mOutputSymlinkSwapInjector(sourcePath))
        @Expect(result.ok, false)
        @Expect(result.diagnostic, "candidate_runtime_output_path_drift")
        let after = source.loadCandidateSnapshotImmutable("r6-precert-v1")
        @Expect(after.valid, true)
        @Expect(after.immutableManifestHash, before.immutableManifestHash)
        @Expect(after.cleanManifestHash, before.cleanManifestHash)
        @Expect(after.candidateChecksum, before.candidateChecksum)
    }

    @TestCase
    public func s6mNeg04SourceDriftAfterCommitRemovesRuntime(): Unit {
        let root = r6PrecertRoot("s6m-source-drift")
        let source = r6PrecertStore(root, r6PrecertCandidates(1))
        let options = CkbCandidateRuntimeMaterializeOptions()
        options.sourceStore = canonicalize(source.root).toString()
        options.outputStore = s6mOutput(root, "runtime")
        options.candidateVersion = "r6-precert-v1"
        let result = ckbMaterializeCandidateRuntime(options,
            faultInjector: S6mSourceDriftInjector(source))
        @Expect(result.ok, false)
        @Expect(result.diagnostic, "candidate_runtime_source_drift")
        @Expect(exists(Path(options.outputStore)), false)
    }
}

private func s6mOutput(root: String, name: String): String {
    canonicalize(Path(root)).join(name).toString()
}

private class S6mTamperInjector <: CkbCandidateRuntimeMaterializeFaultInjector {
    let kind: String
    init(kind: String) { this.kind = kind }
    public func checkpoint(point: String, output: FileKnowledgeStore): Unit {
        if (point != "after_active_commit") { return }
        let pointer = output.loadActiveSnapshotPointer()
        if (this.kind == "commit") {
            remove(output.root.join("transactions").join(pointer.txId).join("COMMIT"))
        } else if (this.kind == "pointer") {
            File.writeTo(output.root.join("metadata/active-snapshot.manifest"),
                "invalid\n".toArray())
        } else {
            File.writeTo(output.root.join("transactions").join(pointer.txId)
                .join("normalized/records.ckb"), "tampered\n".toArray())
        }
    }
}

private class S6mOutputSymlinkSwapInjector <:
    CkbCandidateRuntimeMaterializeFaultInjector {
    let source: String
    init(source: String) { this.source = source }
    public func checkpoint(point: String, output: FileKnowledgeStore): Unit {
        if (point != "after_active_commit") { return }
        remove(output.root, recursive: true)
        if (launch("/bin/ln", ["-s", this.source, output.root.toString()]).wait() != 0) {
            throw Exception("candidate_runtime_test_symlink_failed")
        }
    }
}

private class S6mSourceDriftInjector <:
    CkbCandidateRuntimeMaterializeFaultInjector {
    let source: FileKnowledgeStore
    init(source: FileKnowledgeStore) { this.source = source }
    public func checkpoint(point: String, _output: FileKnowledgeStore): Unit {
        if (point != "before_source_recheck") { return }
        File.writeTo(this.source.root.join(
            "candidate-artifacts/r6-precert-v1/clean-candidate-manifest.json"),
            "drift\n".toArray())
    }
}

private class R6PrecertThrowInjector <: CkbCandidatePrecertFaultInjector {
    public func checkpoint(point: String): Unit { if (point == "before_publish") { throw Exception("write") } }
}

private class R6PrecertCandidateDriftInjector <: CkbCandidatePrecertFaultInjector {
    let store: FileKnowledgeStore
    init(store: FileKnowledgeStore) { this.store = store }
    public func checkpoint(point: String): Unit {
        if (point == "before_candidate_check") {
            let path = this.store.root.join(
                "candidate-artifacts/r6-precert-v1/manifest.ckb")
            File.writeTo(path, "invalid\n".toArray())
        }
    }
}

private func r6PrecertRun(store: FileKnowledgeStore, selected: String, output: String,
    faultInjector!: CkbCandidatePrecertFaultInjector = NoopCkbCandidatePrecertFaultInjector()
): CkbCandidatePrecertResult {
    let path = "${output}-selected.jsonl"; File.writeTo(Path(path), selected.toArray())
    let options = CkbCandidatePrecertOptions(); options.selectedAtomsPath = path; options.outputRoot = output
    options.candidateVersion = "r6-precert-v1"
    options.authorityStore = store.root.parent.join("authority-store").toString()
    ckbBuildCandidatePrecertSeal(store, options, faultInjector: faultInjector)
}

private func r6PrecertStore(root: String, selected: String, authority!: Bool = true,
    activeEval!: Bool = false): FileKnowledgeStore {
    if (!exists(Path(root))) { Directory.create(Path(root), recursive: true) }
    let parsed = parseBenchmarkGapInputsJsonl(selected); let curated = curateBenchmarkGapRecords(parsed.inputs)
    let records = curated.records
    if (activeEval) {
        let eval = NormalizedRecord(); eval.sourceId = "eval-visible"; eval.recordKind = CangjieTypedRecordKinds.EVAL_SUPPORT
        eval.title = "Visible eval"; eval.chunk = "public"; eval.metadata.sourceSet = CangjieSourceSets.EVAL_SUPPORT
        records.add(eval)
    }
    let source = r6PrecertOfficialSource("${root}/source")
    let atomsStore = r6PrecertAtomsStore("${root}/atoms-store", records)
    let authorityStore = FileKnowledgeStore("${root}/authority-store")
    r6PrecertPersistAuthority(authorityStore, "${root}/authority")
    let options = CkbCleanCandidateBuildOptions()
    options.sourceStore = source.root.toString()
    options.stagingStore = "${root}/store"
    options.authorityStore = authorityStore.root.toString()
    options.atomsStore = atomsStore.root.toString()
    options.version = "r6-precert-v1"
    options.apply = true
    let built = ckbRunCleanCandidateBuild(options)
    @Expect(built.diagnostic, "ok")
    @Expect(built.ok, true)
    if (!authority) {
        remove(authorityStore.root, recursive: true)
        Directory.create(authorityStore.root, recursive: true)
    }
    FileKnowledgeStore(options.stagingStore)
}

private func r6PrecertOfficialStore(root: String): FileKnowledgeStore {
    if (!exists(Path(root))) { Directory.create(Path(root), recursive: true) }
    let source = r6PrecertOfficialSource("${root}/source")
    let authorityStore = FileKnowledgeStore("${root}/authority-store")
    r6PrecertPersistAuthority(authorityStore, "${root}/authority")
    let options = CkbCleanCandidateBuildOptions()
    options.sourceStore = source.root.toString()
    options.stagingStore = "${root}/store"
    options.authorityStore = authorityStore.root.toString()
    options.version = "r6-precert-v1"
    options.apply = true
    let built = ckbRunCleanCandidateBuild(options)
    @Expect(built.diagnostic, "ok")
    @Expect(built.ok, true)
    FileKnowledgeStore(options.stagingStore)
}

private func r6PrecertOfficialSource(root: String): FileKnowledgeStore {
    let typed = CangjieTypedRecord()
    typed.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    typed.sourceId = "official-arraylist"
    typed.title = "ArrayList append"
    typed.content = "ArrayList add appends one value."
    typed.citation = "https://docs.cangjie-lang.cn/docs/1.0.0/"
    typed.sourceSet = CangjieSourceSets.DOCS
    typed.path = "docs/collection/arraylist.md"
    typed.targetVersion = "1.0.0"
    typed.sourceRef = "release-1.0.0"
    typed.versionResolutionId = "cangjie-1.0.0-docs-release-1.0.0"
    let records = ArrayList<CangjieTypedRecord>(); records.add(typed)
    let kb = KnowledgeBase(FakeClock(0))
    kb.loadFirstInitializationTypedRecords(records, "r6-source-candidate")
    @Expect(kb.promoteFirstInitializationCandidate("r6-source-active"), true)
    let store = FileKnowledgeStore(root)
    @Expect(kb.persistActiveSnapshot(store).ok, true)
    store
}

private func r6PrecertAtomsStore(root: String,
    records: ArrayList<NormalizedRecord>): FileKnowledgeStore {
    let snapshot = ActiveSnapshot()
    snapshot.valid = true
    snapshot.diagnostic = "ok"
    snapshot.activeVersion = "r6-atoms-active"
    snapshot.candidateVersion = "r6-atoms-candidate"
    snapshot.activeStateSource = "test_fixture"
    for (record in records) {
        let raw = RawRecord()
        raw.sourceId = record.sourceId
        raw.title = record.title
        raw.content = record.chunk
        raw.contentHash = benchmarkGapSha256(record.chunk)
        raw.metadata = record.metadata
        raw.requiresReview = record.requiresReview
        snapshot.rawRecords.add(raw)
        snapshot.normalizedRecords.add(record)
        snapshot.activeIndex.add(record)
    }
    let kb = KnowledgeBase(FakeClock(0))
    @Expect(kb.restoreActiveSnapshot(snapshot), true)
    let store = FileKnowledgeStore(root)
    @Expect(kb.persistActiveSnapshot(store).ok, true)
    store
}

private func r6PrecertPersistAuthority(store: FileKnowledgeStore, dataset: String): Unit {
        let caseRoot = Path(dataset).join("CJ-HUMANEVAL-000")
        Directory.create(caseRoot.join("starter/src"), recursive: true); Directory.create(caseRoot.join("tests"), recursive: true)
        File.writeTo(caseRoot.join("prompt.md"), "# Public task\nGeneral prompt.\n".toArray())
        File.writeTo(caseRoot.join("metadata.json"), "{\"task\":\"public\"}\n".toArray())
        File.writeTo(caseRoot.join("starter/src/eval_support.cj"), "public enum EvalValue { Number(Int64) }\n".toArray())
        File.writeTo(caseRoot.join("tests/TestMain.cj"), "public func visibleHelper(): Int64 { 1 }\n".toArray())
        let snapshot = buildVersionedEvalSupportSnapshot(dataset, "r6-precert-authority-v1")
        @Expect(snapshot.ok, true); @Expect(persistVersionedEvalSupportSnapshot(store, snapshot), true)
}

private func r6PrecertTransportOutputs(service: CkbCommandLoopService,
    arguments: String): Array<String> {
    let call = "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"tools/call\",\"params\":{\"name\":\"cangjie_task_knowledge_pack\",\"arguments\":${arguments}}}"
    [
        ckbApiHandle(service, "POST", "/v1/cangjie/task-knowledge-pack",
            arguments, []),
        CkbMcpStdioServer(service).handleRequest(call),
        r6PrecertMcpHttp(service, call)
    ]
}

private func r6PrecertMcpHttp(service: CkbCommandLoopService,
    toolCall: String): String {
    let sessions = CkbMcpHttpSessionStore()
    let initHeaders = [
        "Content-Type: application/json",
        "Accept: application/json, text/event-stream"
    ]
    let initialize = handleCkbMcpHttpRequest(service, "POST", "/mcp",
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"s2-precert\",\"version\":\"1\"}}}",
        initHeaders, CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), sessions)
    let sessionId = r6PrecertMcpSessionId(initialize)
    let headers = [
        "Content-Type: application/json",
        "Accept: application/json, text/event-stream",
        "MCP-Protocol-Version: 2025-06-18",
        "Mcp-Session-Id: ${sessionId}"
    ]
    _ = handleCkbMcpHttpRequest(service, "POST", "/mcp",
        "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\",\"params\":{}}",
        headers, CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), sessions)
    handleCkbMcpHttpRequest(service, "POST", "/mcp", toolCall, headers,
        CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), sessions).body
}

private func r6PrecertMcpSessionId(response: CkbMcpHttpResponse): String {
    for (header in response.headers) {
        if (header.toAsciiLower().startsWith("mcp-session-id:")) {
            return header["mcp-session-id:".size..header.size].trimAscii()
        }
    }
    ""
}

private func r6PrecertCandidates(count: Int64, knowledgeSuffix!: String = ""): String {
    let out = StringBuilder()
    for (i in 0..count) { out.append(r6PrecertCandidate(i, knowledgeSuffix)); out.append("\n") }
    out.toString()
}

private func r6PrecertCandidate(index: Int64, suffix: String): String {
    let atomId = "G-PRECERT-${index}"
    let marker = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
    let rawBundle = "{\"atomId\":\"${atomId}\",\"knowledgeFamily\":\"syntax\",\"sourceClass\":\"official\",\"citation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/\",\"targetVersion\":\"1.0.0\",\"candidateHash\":\"${marker}\",\"knowledgeText\":\"General atomic knowledge ${index} ${suffix}\",\"example\":\"中文😀 example ${index}\",\"extractor\":{\"provider\":\"codex\",\"model\":\"gpt-5.6-sol\",\"exitCode\":0,\"transcriptHash\":\"${benchmarkGapSha256("transcript-${index}")}\"},\"purificationPassed\":true,\"tests\":[{\"category\":\"positive\",\"operation\":\"arraylist_size\",\"input\":\"[1,2,3]\",\"expected\":\"3\"},{\"category\":\"negative\",\"operation\":\"contains\",\"input\":\"stable\",\"needle\":\"unstable\",\"expected\":\"false\"},{\"category\":\"boundary\",\"operation\":\"rune_count\",\"input\":\"中文😀\",\"expected\":\"3\"}],\"execution\":{\"total\":3,\"passed\":3,\"failed\":0,\"status\":\"passed\",\"commandEvidence\":\"public\",\"commandEvidenceHash\":\"${benchmarkGapSha256("public")}\"}}"
    let bundle = rawBundle.replace(marker, cangjieKnowledgeAtomCandidateHash(rawBundle))
    let input = CangjieBenchmarkGapInput(); input.schemaVersion = "ckb-benchmark-gap-v1"
    input.datasetVersion = "cangjie-humaneval-164-${benchmarkGapSha256("r6-precert-dataset")}"; input.teacherRunId = "r6-precert-${index}"
    input.evidence = "public evidence ${index}"; input.evidenceHash = benchmarkGapSha256(input.evidence)
    input.candidatePath = "candidate-knowledge/ckb-benchmark-gap.jsonl"; input.revision = 1; input.attempt = 1
    input.failureTaxonomy = "knowledge_gap"; input.knowledgeGapConfirmations = 2; input.caseId = "PUBLIC-${index}"
    input.benchmark = "public-regression"; input.taskText = "General task ${index}"; input.visibleTestExcerpt = "public"
    input.compilerOutput = "public diagnostic"; input.missingKnowledge = "G-STRING"; input.interfaceId = "KI-02"
    input.contentFamily = "KC-02"; input.updateMechanism = "KU-11"; input.targetVersion = "1.0.0"
    input.officialCitation = "https://docs.cangjie-lang.cn/docs/1.0.0/"; input.knowledgeAtomCandidate = true
    input.knowledgeAtomTestBundle = bundle; input.candidateHash = canonicalBenchmarkGapCandidateHash(input)
    "{\"schemaVersion\":\"${input.schemaVersion}\",\"datasetVersion\":\"${input.datasetVersion}\",\"teacherRunId\":\"${input.teacherRunId}\",\"evidenceHash\":\"${input.evidenceHash}\",\"evidence\":\"${input.evidence}\",\"candidateHash\":\"${input.candidateHash}\",\"candidatePath\":\"${input.candidatePath}\",\"revision\":1,\"attempt\":1,\"failureTaxonomy\":\"knowledge_gap\",\"knowledgeGapConfirmations\":2,\"caseId\":\"${input.caseId}\",\"benchmark\":\"${input.benchmark}\",\"taskText\":\"${input.taskText}\",\"visibleTestExcerpt\":\"public\",\"compilerOutput\":\"public diagnostic\",\"missingKnowledge\":\"G-STRING\",\"interfaceId\":\"KI-02\",\"contentFamily\":\"KC-02\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"1.0.0\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/\",\"knowledgeAtomTestBundle\":${bundle},\"knowledgeAtomCandidate\":true}"
}

private func r6PrecertRoot(name: String): String {
    let root = "target/t-r6-precert-${name}"; if (exists(Path(root))) { remove(Path(root), recursive: true) }
    Directory.create(Path(root), recursive: true); root
}

private func r6PrecertRead(path: String): String { try { String.fromUtf8(File.readFrom(Path(path))) } catch (_: Exception) { "" } }
private func r6PrecertRepeat(value: String, count: Int64): String { let out = StringBuilder(); for (_ in 0..count) { out.append(value) }; out.toString() }
private func r6PrecertTrustedRecord(sourceId: String, chunk: String): NormalizedRecord {
    let record = NormalizedRecord(); record.sourceId = sourceId; record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    record.title = "General"; record.chunk = chunk; record.citation = "doc"
    record.metadata.sourceSet = CangjieSourceSets.DOCS; record.metadata.sourceType = SourceTypes.DOC
    record.metadata.trustLevel = TrustLevels.OFFICIAL; record.metadata.reviewState = ReviewStates.TRUSTED
    record
}
