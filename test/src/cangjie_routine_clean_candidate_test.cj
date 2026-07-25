package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists}
import std.process.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieRoutineCleanCandidateTest {
    @TestCase
    public func s1Ut01ClassifiesPollutionAndPreservesCleanContent(): Unit {
        let clean = s1Normalized("official-rune", "Rune 文档🙂")
        let duplicate = s1Normalized("official-rune", "Rune 文档🙂")
        let eval = s1Normalized("eval-record", "public fixture")
        eval.recordKind = CangjieTypedRecordKinds.EVAL_SUPPORT
        eval.metadata.sourceSet = CangjieSourceSets.EVAL_SUPPORT
        let identity = s1Normalized("CJ-HUMANEVAL-125", "case-specific")
        let composite = s1Normalized("composite", "Task: implement\nVisible tests: assert\nCompiler output: error")
        let input = ArrayList<NormalizedRecord>()
        for (record in [clean, duplicate, eval, identity, composite]) { input.add(record) }

        let result = ckbCleanHistoricalStudentRecords(input)

        @Expect(result.ok, true)
        @Expect(result.inputCount, 5)
        @Expect(result.keptCount, 1)
        @Expect(result.removedCount, 4)
        @Expect(result.keptCount + result.removedCount, result.inputCount)
        @Expect(result.records[0].chunk, clean.chunk)
        @Expect(result.outputChecksum, ckbCleanHistoricalStudentRecords(
            s1NormalizedList(clean)).outputChecksum)
        @Expect(ckbStudentCleanRejectionCount(result.rejectionCounts,
            "student_record_identity_duplicate"), 1)
        @Expect(ckbStudentCleanRejectionCount(result.rejectionCounts,
            "eval_support_not_student_visible"), 1)
        @Expect(ckbStudentCleanRejectionCount(result.rejectionCounts,
            "student_knowledge_leakage_blocked"), 2)
        @Expect(result.evidenceHash.contains("CJ-HUMANEVAL"), false)
        @Expect(result.evidenceHash.contains("Visible tests"), false)
    }

    @TestCase
    public func s1Bnd01HandlesUnicodeLongConflictSymlinkAndInvalidUtf8(): Unit {
        let empty = ckbBuildCompleteCleanStudentCandidate(
            ArrayList<RawRecord>(), ArrayList<NormalizedRecord>(),
            ArrayList<NormalizedRecord>(), ArrayList<RawRecord>(),
            ArrayList<NormalizedRecord>(), ArrayList<NormalizedRecord>(), "clean-empty-v1")
        @Expect(empty.ok, true)
        @Expect(empty.rawRecords.size, 0)

        var longText = "中文🙂"
        for (_ in 0..2048) { longText += "界" }
        let raw = s1Raw("unicode", longText)
        let normalized = s1Normalized("unicode", longText)
        let unicode = ckbBuildCompleteCleanStudentCandidate(
            s1RawList(raw), s1NormalizedList(normalized), s1NormalizedList(normalized),
            ArrayList<RawRecord>(), ArrayList<NormalizedRecord>(),
            ArrayList<NormalizedRecord>(), "clean-unicode-v1")
        @Expect(unicode.ok, true)
        @Expect(unicode.normalizedRecords[0].chunk, longText)

        let conflict = s1Normalized("unicode", "different")
        let conflictResult = ckbCleanHistoricalStudentRecords(
            s1NormalizedList(normalized, second: conflict))
        @Expect(conflictResult.ok, false)
        @Expect(conflictResult.errorCode, "student_record_identity_conflict")
        let secondChunk = s1Normalized("unicode", "second chunk")
        secondChunk.title = "Documentation unicode part 2"
        secondChunk.citation += "#part-2"
        let twoChunks = ckbBuildCompleteCleanStudentCandidate(
            s1RawList(raw), s1NormalizedList(normalized, second: secondChunk),
            s1NormalizedList(normalized, second: secondChunk), ArrayList<RawRecord>(),
            ArrayList<NormalizedRecord>(), ArrayList<NormalizedRecord>(), "clean-chunks-v1")
        @Expect(twoChunks.ok, true)
        @Expect(twoChunks.rawRecords.size, 1)
        @Expect(twoChunks.normalizedRecords.size, 2)

        let root = s1Root("boundary")
        let source = s1PersistSource("${root}/source")
        s1PersistAuthority(source, "${root}/authority-data")
        let realStaging = Path("${root}/real-staging")
        Directory.create(realStaging, recursive: true)
        let link = "${root}/staging-link"
        @Expect(launch("/bin/ln", ["-s", canonicalize(realStaging).toString(), link]).wait(), 0)
        let protected = ArrayList<String>(); protected.add(source.root.toString())
        let linkDiagnostic = ckbCleanCandidateBaseDiagnostic(
            FileKnowledgeStore(link), protectedRoots: protected)
        @Expect(linkDiagnostic.ok, false)
        @Expect(linkDiagnostic.code, "clean_candidate_staging_symlink_forbidden")

        let pointer = source.loadActiveSnapshotPointer()
        File.writeTo(source.root.join("transactions").join(pointer.txId)
            .join("raw/records.ckb"), [UInt8(0xff)])
        let options = s1Options(source.root.toString(), "${root}/invalid-staging",
            source.root.toString(), "clean-invalid-v1", false)
        let invalid = ckbRunCleanCandidateBuild(options)
        @Expect(invalid.ok, false)
        @Expect(invalid.diagnostic, "invalid_response_encoding")
        @Expect(exists(Path(options.stagingStore)), false)
    }

    @TestCase
    public func s1Pos01DryRunAndApplyAreDeterministicAndReadOnlyToSource(): Unit {
        let root = s1Root("positive")
        let source = s1PersistSource("${root}/source")
        s1PersistAuthority(source, "${root}/authority-data")
        let before = ckbActiveSnapshotPointerIdentityHash(source.loadActiveSnapshotPointer())
        let dry = s1Options(source.root.toString(), "${root}/dry-staging",
            source.root.toString(), "clean-positive-v1", false)

        let dryResult = ckbRunCleanCandidateBuild(dry)
        @Expect(dryResult.ok, true)
        @Expect(dryResult.applied, false)
        @Expect(exists(Path(dry.stagingStore)), false)

        let first = s1Options(source.root.toString(), "${root}/apply-a",
            source.root.toString(), "clean-positive-v1", true)
        let second = s1Options(source.root.toString(), "${root}/apply-b",
            source.root.toString(), "clean-positive-v1", true)
        let firstResult = ckbRunCleanCandidateBuild(first)
        let secondResult = ckbRunCleanCandidateBuild(second)

        @Expect(firstResult.ok, true)
        @Expect(secondResult.ok, true)
        @Expect(firstResult.applied, true)
        @Expect(firstResult.rawCount, firstResult.normalizedCount)
        @Expect(firstResult.normalizedCount, firstResult.activeCount)
        @Expect(firstResult.candidateChecksum, secondResult.candidateChecksum)
        @Expect(firstResult.manifestEvidenceHash, secondResult.manifestEvidenceHash)
        let firstStore = FileKnowledgeStore(first.stagingStore)
        let secondStore = FileKnowledgeStore(second.stagingStore)
        @Expect(firstStore.readText(
            "candidate-artifacts/clean-positive-v1/clean-candidate-manifest.json"),
            secondStore.readText(
                "candidate-artifacts/clean-positive-v1/clean-candidate-manifest.json"))
        @Expect(firstStore.readText(
            "raw/candidate/clean-positive-v1/records.ckb").trimAscii() != "", true)
        @Expect(firstStore.readText(
            "normalized/candidate/clean-positive-v1.ckb").trimAscii() != "", true)
        @Expect(firstStore.loadActiveSnapshotPointer().valid, false)
        @Expect(ckbActiveSnapshotPointerIdentityHash(source.loadActiveSnapshotPointer()), before)
    }

    @TestCase
    public func s1Neg01RejectsProtectedNonemptyChildAndOverlayDestinations(): Unit {
        let root = s1Root("negative")
        let source = s1PersistSource("${root}/source")
        s1PersistAuthority(source, "${root}/authority-data")
        let before = ckbActiveSnapshotPointerIdentityHash(source.loadActiveSnapshotPointer())
        let protected = ArrayList<String>(); protected.add(source.root.toString())

        let same = ckbCleanCandidateBaseDiagnostic(source, protectedRoots: protected)
        @Expect(same.ok, false)
        @Expect(same.code, "clean_candidate_base_forbidden")
        let child = ckbCleanCandidateBaseDiagnostic(
            FileKnowledgeStore("${source.root}/candidate-output"), protectedRoots: protected)
        @Expect(child.ok, false)
        @Expect(child.code, "clean_candidate_base_forbidden")

        let nonemptyRoot = "${root}/nonempty"
        Directory.create(Path(nonemptyRoot), recursive: true)
        File.writeTo(Path(nonemptyRoot).join("keep.txt"), "keep".toArray())
        let nonempty = ckbCleanCandidateBaseDiagnostic(
            FileKnowledgeStore(nonemptyRoot), protectedRoots: protected)
        @Expect(nonempty.ok, false)
        @Expect(nonempty.code, "contaminated_base_forbidden")

        let overlay = ckbCleanCandidateBaseDiagnostic(
            FileKnowledgeStore("${source.root}/normalized/candidate/overlay"),
            protectedRoots: protected)
        @Expect(overlay.ok, false)
        @Expect(overlay.code, "clean_candidate_path_invalid")
        @Expect(ckbActiveSnapshotPointerIdentityHash(source.loadActiveSnapshotPointer()), before)
        @Expect(String.fromUtf8(File.readFrom(Path(nonemptyRoot).join("keep.txt"))), "keep")
    }

    @TestCase
    public func s1Reg01LegacyOverlayRemainsSeparateFromCompleteReplacement(): Unit {
        let old = s1Normalized("old", "old knowledge")
        let incoming = s1Normalized("new", "new knowledge")
        let overlay = ckbOverlayCleanStudentRecords(
            s1NormalizedList(old), s1NormalizedList(incoming))
        @Expect(overlay.ok, true)
        @Expect(overlay.records.size, 2)

        let rawOld = s1Raw("old", "old knowledge")
        let complete = ckbBuildCompleteCleanStudentCandidate(
            s1RawList(rawOld), s1NormalizedList(old), s1NormalizedList(old),
            ArrayList<RawRecord>(), ArrayList<NormalizedRecord>(),
            ArrayList<NormalizedRecord>(), "clean-regression-v1")
        @Expect(complete.ok, true)
        @Expect(complete.normalizedRecords.size, 1)
        @Expect(complete.normalizedRecords[0].sourceId, "old")
    }
}

private func s1Normalized(id: String, content: String): NormalizedRecord {
    let record = NormalizedRecord(); record.sourceId = id
    record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    record.title = "Documentation ${id}"; record.chunk = content
    record.citation = "https://docs.cangjie-lang.cn/docs/1.0.0/${id}"
    record.metadata.sourceId = id; record.metadata.sourceType = SourceTypes.DOC
    record.metadata.sourceUrl = record.citation; record.metadata.path = "docs/${id}.md"
    record.metadata.sourceSet = CangjieSourceSets.DOCS
    record.metadata.targetVersion = "1.0.0"
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.TRUSTED
    record
}

private func s1Raw(id: String, content: String): RawRecord {
    let normalized = s1Normalized(id, content)
    let record = RawRecord(); record.sourceId = id; record.title = normalized.title
    record.content = content; record.contentHash = benchmarkGapSha256(content)
    record.metadata = normalized.metadata; record
}

private func s1Root(name: String): String {
    let root = "target/s1-clean-${name}"
    if (exists(Path(root))) { _ = launch("/bin/rm", ["-rf", root]).wait() }
    Directory.create(Path(root), recursive: true); root
}

private func s1PersistSource(root: String): FileKnowledgeStore {
    let typed = CangjieTypedRecord(); typed.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    typed.sourceId = "official-rune"; typed.title = "Rune 文档🙂"
    typed.content = "Rune uses Unicode scalar values."
    typed.citation = "https://docs.cangjie-lang.cn/docs/1.0.0/rune"
    typed.sourceSet = CangjieSourceSets.DOCS; typed.path = "docs/rune.md"
    typed.targetVersion = "1.0.0"; typed.versionResolutionId = "s1-official-rune"
    let records = ArrayList<CangjieTypedRecord>(); records.add(typed)
    let kb = KnowledgeBase(FakeClock(0))
    _ = kb.loadFirstInitializationTypedRecords(records, "s1-source-candidate")
    @Expect(kb.promoteFirstInitializationCandidate("s1-source-active"), true)
    let store = FileKnowledgeStore(root)
    @Expect(kb.persistActiveSnapshot(store).ok, true)
    store
}

private func s1PersistAuthority(store: FileKnowledgeStore, dataset: String): Unit {
    let caseRoot = Path(dataset).join("CJ-HUMANEVAL-000")
    Directory.create(caseRoot.join("starter/src"), recursive: true)
    Directory.create(caseRoot.join("tests"), recursive: true)
    File.writeTo(caseRoot.join("prompt.md"), "# Public task\nGeneral prompt.\n".toArray())
    File.writeTo(caseRoot.join("metadata.json"), "{\"task\":\"public\"}\n".toArray())
    File.writeTo(caseRoot.join("starter/src/eval_support.cj"),
        "public enum EvalValue { Number(Int64) }\n".toArray())
    File.writeTo(caseRoot.join("tests/TestMain.cj"),
        "public func visibleHelper(): Int64 { 1 }\n".toArray())
    let authority = buildVersionedEvalSupportSnapshot(dataset, "s1-authority-v1")
    @Expect(authority.ok, true)
    @Expect(persistVersionedEvalSupportSnapshot(store, authority), true)
}

private func s1Options(source: String, staging: String, authority: String,
    version: String, apply: Bool): CkbCleanCandidateBuildOptions {
    let options = CkbCleanCandidateBuildOptions()
    options.sourceStore = source; options.stagingStore = staging
    options.authorityStore = authority; options.version = version
    options.apply = apply; options
}

private func s1NormalizedList(first: NormalizedRecord,
    second!: NormalizedRecord = NormalizedRecord()): ArrayList<NormalizedRecord> {
    let records = ArrayList<NormalizedRecord>(); records.add(first)
    if (second.sourceId != "" || second.title != "" || second.chunk != "") { records.add(second) }
    records
}

private func s1RawList(first: RawRecord): ArrayList<RawRecord> {
    let records = ArrayList<RawRecord>(); records.add(first); records
}
