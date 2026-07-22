package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists, remove}
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
        @Expect(first.ok, true); @Expect(second.ok, true)
        @Expect(first.candidateChecksum, second.candidateChecksum)
        @Expect(first.trustSealHash, second.trustSealHash)
        @Expect(first.summaryHash, second.summaryHash)
        let leakage = r6PrecertRead("${root}/out-a/student-leakage-report.jsonl")
        let query = r6PrecertRead("${root}/out-a/anonymous-atom-query-report.jsonl")
        let authority = r6PrecertRead("${root}/out-a/authority-isolation.json")
        let atom = r6PrecertRead("${root}/out-a/atom-test-summary.json")
        let seal = r6PrecertRead("${root}/out-a/candidate-trust-seal.json")
        @Expect(ckbCandidateTrustSealDiagnostic(seal, store.loadActiveSnapshot().normalizedRecords,
            leakage, query, authority, atom), "ok")
        @Expect(atom.contains("\"selectedAtomsHash\""), true)
        @Expect(atom.contains("\"bundleEvidenceHash\""), true)
    }

    @TestCase
    public func tR6BndZeroOneTenDuplicateEncodingAndLongText(): Unit {
        let root = r6PrecertRoot("bnd")
        let one = r6PrecertCandidates(1, knowledgeSuffix: "${r6PrecertRepeat("界", 1024)}😀")
        let store = r6PrecertStore(root, one)
        let officialStore = r6PrecertOfficialStore("${root}/official")
        let officialSnapshot = officialStore.loadActiveSnapshot()
        var officialAtomCount: Int64 = 0
        for (record in officialSnapshot.activeIndex) {
            if (record.recordKind == CangjieTypedRecordKinds.KNOWLEDGE_ATOM) { officialAtomCount += 1 }
        }
        @Expect(officialSnapshot.activeIndex.size > 0, true); @Expect(officialAtomCount, 0)
        let zero = r6PrecertRun(officialStore, "", "${root}/zero")
        @Expect(zero.ok, true); @Expect(zero.selectedCount, 0); @Expect(zero.atomTestCount, 0)
        @Expect(zero.candidateChecksum,
            ckbCertifiedNormalizedRecordsChecksum(officialSnapshot.normalizedRecords))
        @Expect(r6PrecertRun(store, one, "${root}/one").ok, true)
        @Expect(r6PrecertRun(store, one + one, "${root}/duplicate").diagnostic,
            "duplicate_selected_atom")
        let invalid = "${root}/invalid.jsonl"; File.writeTo(Path(invalid), [UInt8(0xff), UInt8(0xfe)])
        let invalidOptions = CkbCandidatePrecertOptions(); invalidOptions.selectedAtomsPath = invalid
        invalidOptions.outputRoot = "${root}/invalid-out"
        @Expect(ckbBuildCandidatePrecertSeal(store, invalidOptions).diagnostic,
            "invalid_response_encoding")
        let ten = r6PrecertCandidates(10)
        let tenStore = r6PrecertStore("${root}/ten-store", ten)
        let tenResult = r6PrecertRun(tenStore, ten, "${root}/ten-out")
        @Expect(tenResult.ok, true); @Expect(tenResult.selectedCount, 10); @Expect(tenResult.atomTestCount, 30)
    }

    @TestCase
    public func tR6PosCommittedStoreProducesSixStandardArtifacts(): Unit {
        let root = r6PrecertRoot("pos")
        let selected = r6PrecertCandidates(1)
        let store = r6PrecertStore(root, selected)
        let before = ckbActiveSnapshotPointerIdentityHash(store.loadActiveSnapshotPointer())
        let result = r6PrecertRun(store, selected, "${root}/precert")
        @Expect(result.ok, true); @Expect(result.selectedCount, 1); @Expect(result.atomTestCount, 3)
        for (name in ["student-leakage-report.jsonl", "anonymous-atom-query-report.jsonl",
            "authority-isolation.json", "atom-test-summary.json", "candidate-trust-seal.json",
            "candidate-precert-summary.json"]) { @Expect(exists(Path("${root}/precert/${name}")), true) }
        @Expect(r6PrecertRead("${root}/precert/candidate-precert-summary.json").contains(
            "\"candidateChecksum\":\"${result.candidateChecksum}\""), true)
        @Expect(ckbActiveSnapshotPointerIdentityHash(store.loadActiveSnapshotPointer()), before)
    }

    @TestCase
    public func tR6NegTamperMissingAuthorityPollutionFailureAndDriftFailClosed(): Unit {
        let root = r6PrecertRoot("neg")
        let selected = r6PrecertCandidates(1)
        let noAuthority = r6PrecertStore("${root}/no-authority", selected, authority: false)
        @Expect(r6PrecertRun(noAuthority, selected, "${root}/no-authority-out").diagnostic,
            "authority_isolation_proof_required")
        let polluted = r6PrecertStore("${root}/polluted", selected, activeEval: true)
        @Expect(r6PrecertRun(polluted, selected, "${root}/polluted-out").diagnostic,
            "active_eval_support_forbidden")
        let store = r6PrecertStore("${root}/store", selected)
        let tampered = selected.replace("General atomic knowledge", "Drifted atomic knowledge")
        @Expect(r6PrecertRun(store, tampered, "${root}/tampered-out").diagnostic,
            "atom_candidate_hash_mismatch")
        let broken = selected.replace("\"expected\":\"3\"", "\"expected\":\"99\"")
        @Expect(r6PrecertRun(store, broken, "${root}/broken-out").ok, false)
        let inside = r6PrecertRun(store, selected, "${store.root.toString()}/proof")
        @Expect(inside.diagnostic, "candidate_precert_output_inside_store")
        Directory.create(Path("${root}/exists"), recursive: true)
        @Expect(r6PrecertRun(store, selected, "${root}/exists").diagnostic,
            "candidate_precert_output_exists")
        let writeFail = r6PrecertRun(store, selected, "${root}/write-fail",
            faultInjector: R6PrecertThrowInjector())
        @Expect(writeFail.diagnostic, "candidate_precert_artifact_write_failed")
        @Expect(exists(Path("${root}/write-fail")), false)
        let driftStore = r6PrecertStore("${root}/drift", selected)
        let drift = r6PrecertRun(driftStore, selected, "${root}/drift-out",
            faultInjector: R6PrecertPointerDriftInjector(driftStore))
        @Expect(drift.diagnostic, "candidate_precert_active_pointer_drift")
        @Expect(exists(Path("${root}/drift-out")), false)
    }
}

private class R6PrecertThrowInjector <: CkbCandidatePrecertFaultInjector {
    public func checkpoint(point: String): Unit { if (point == "before_publish") { throw Exception("write") } }
}

private class R6PrecertPointerDriftInjector <: CkbCandidatePrecertFaultInjector {
    let store: FileKnowledgeStore
    init(store: FileKnowledgeStore) { this.store = store }
    public func checkpoint(point: String): Unit {
        if (point == "before_pointer_check") {
            File.writeTo(this.store.root.join("metadata/active-snapshot.manifest"), "invalid\n".toArray())
        }
    }
}

private func r6PrecertRun(store: FileKnowledgeStore, selected: String, output: String,
    faultInjector!: CkbCandidatePrecertFaultInjector = NoopCkbCandidatePrecertFaultInjector()
): CkbCandidatePrecertResult {
    let path = "${output}-selected.jsonl"; File.writeTo(Path(path), selected.toArray())
    let options = CkbCandidatePrecertOptions(); options.selectedAtomsPath = path; options.outputRoot = output
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
    let kb = newOfflineKnowledgeBase(); kb.stageCandidateRecords("r6-precert-candidate", records)
    @Expect(kb.promoteCandidateToActive("r6-precert-active"), true)
    let store = FileKnowledgeStore("${root}/store"); _ = kb.persistActiveSnapshot(store)
    if (authority) { r6PrecertPersistAuthority(store, "${root}/authority") }
    store
}

private func r6PrecertOfficialStore(root: String): FileKnowledgeStore {
    if (!exists(Path(root))) { Directory.create(Path(root), recursive: true) }
    let records = ArrayList<NormalizedRecord>()
    records.add(r6PrecertTrustedRecord("official-arraylist", "ArrayList add appends one value."))
    let kb = newOfflineKnowledgeBase(); kb.stageCandidateRecords("r6-official-candidate", records)
    @Expect(kb.promoteCandidateToActive("r6-official-active"), true)
    let store = FileKnowledgeStore("${root}/store"); _ = kb.persistActiveSnapshot(store)
    r6PrecertPersistAuthority(store, "${root}/authority"); store
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
