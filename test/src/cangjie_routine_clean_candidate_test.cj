package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists}
import std.process.*
import std.sort.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.crypto.digest.SHA256

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

        let licenseConflict = s1Normalized("official-rune", "Rune 文档🙂")
        licenseConflict.metadata.license = "Apache-2.0"
        let completeFieldConflict = ckbCleanHistoricalStudentRecords(
            s1NormalizedList(clean, second: licenseConflict))
        @Expect(completeFieldConflict.ok, false)
        @Expect(completeFieldConflict.errorCode, "student_record_identity_conflict")

        let raw = s1Raw("raw-hash", "same content")
        let rawHashConflict = s1Raw("raw-hash", "same content")
        rawHashConflict.contentHash = "different-content-hash"
        let rawConflict = ckbCleanHistoricalStudentRawRecords(
            s1RawList(raw, second: rawHashConflict))
        @Expect(rawConflict.ok, false)
        @Expect(rawConflict.errorCode, "student_raw_content_hash_mismatch")
        let rawEvidenceDrift = s1Raw("raw-hash", "same content")
        rawEvidenceDrift.contentHash = stableSummaryHash(rawEvidenceDrift.content)
        let rawEvidenceConflict = ckbCleanHistoricalStudentRawRecords(
            s1RawList(raw, second: rawEvidenceDrift))
        @Expect(rawEvidenceConflict.ok, false)
        @Expect(rawEvidenceConflict.errorCode, "student_raw_record_identity_conflict")
        let rawTitleDrift = s1Raw("raw-hash", "same content")
        rawTitleDrift.title = "drifted raw title"
        let rawTitleConflict = ckbCleanHistoricalStudentRawRecords(
            s1RawList(raw, second: rawTitleDrift))
        @Expect(rawTitleConflict.ok, false)
        @Expect(rawTitleConflict.errorCode, "student_raw_record_identity_conflict")
        let rawMetadataDrift = s1Raw("raw-hash", "same content")
        rawMetadataDrift.metadata.targetVersion = "9.9.9"
        let rawMetadataConflict = ckbCleanHistoricalStudentRawRecords(
            s1RawList(raw, second: rawMetadataDrift))
        @Expect(rawMetadataConflict.ok, false)
        @Expect(rawMetadataConflict.errorCode, "student_raw_record_identity_conflict")
        let rawDuplicate = ckbCleanHistoricalStudentRawRecords(
            s1RawList(raw, second: raw))
        @Expect(rawDuplicate.ok, true)
        @Expect(rawDuplicate.records.size, 1)
        @Expect(ckbStudentCleanRejectionCount(rawDuplicate.rejectionCounts,
            "student_record_identity_duplicate"), 1)
        let rawSecondContent = s1Raw("raw-hash", "second content")
        let rawMultipleContents = ckbCleanHistoricalStudentRawRecords(
            s1RawList(raw, second: rawSecondContent))
        @Expect(rawMultipleContents.ok, true)
        @Expect(rawMultipleContents.records.size, 2)

        for (validHash in [benchmarkGapSha256(raw.content),
            stableSummaryHash(raw.content),
            ckbReleaseEvidenceHash(raw.content),
            cangjieTypedRecordContentHash(raw.sourceId, raw.content),
            s1LegacyContentHash(raw.sourceId, raw.content)]) {
            let valid = s1Raw("raw-valid", "中文🙂")
            valid.contentHash = if (validHash == benchmarkGapSha256(raw.content)) {
                benchmarkGapSha256(valid.content)
            } else if (validHash == stableSummaryHash(raw.content)) {
                stableSummaryHash(valid.content)
            } else if (validHash == ckbReleaseEvidenceHash(raw.content)) {
                ckbReleaseEvidenceHash(valid.content)
            } else if (validHash == cangjieTypedRecordContentHash(raw.sourceId, raw.content)) {
                cangjieTypedRecordContentHash(valid.sourceId, valid.content)
            } else {
                s1LegacyContentHash(valid.sourceId, valid.content)
            }
            @Expect(ckbCleanHistoricalStudentRawRecords(s1RawList(valid)).ok, true)
        }
        let empty = s1Raw("raw-empty", "")
        empty.contentHash = benchmarkGapSha256("")
        let emptyRaw = ckbCleanHistoricalStudentRawRecords(s1RawList(empty))
        @Expect(emptyRaw.ok, false)
        @Expect(emptyRaw.errorCode, "student_raw_content_required")
        let whitespace = s1Raw("raw-whitespace", "\u{3000}\u{00a0}\n")
        whitespace.contentHash = benchmarkGapSha256(whitespace.content)
        let whitespaceRaw = ckbCleanHistoricalStudentRawRecords(s1RawList(whitespace))
        @Expect(whitespaceRaw.ok, false)
        @Expect(whitespaceRaw.errorCode, "student_raw_content_required")
        let missingHash = s1Raw("raw-missing-hash", "中文🙂")
        missingHash.contentHash = " \t"
        let missingHashResult = ckbCleanHistoricalStudentRawRecords(
            s1RawList(missingHash))
        @Expect(missingHashResult.ok, false)
        @Expect(missingHashResult.errorCode, "student_raw_content_hash_required")
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
        let raw = s1Raw("unicode", longText + "\nsecond chunk")
        let normalized = s1Normalized("unicode", longText)
        let unicode = ckbBuildCompleteCleanStudentCandidate(
            s1RawList(raw), s1NormalizedList(normalized), s1NormalizedList(normalized),
            ArrayList<RawRecord>(), ArrayList<NormalizedRecord>(),
            ArrayList<NormalizedRecord>(), "clean-unicode-v1")
        @Expect(unicode.ok, true)
        @Expect(unicode.normalizedRecords[0].chunk, longText)

        let titleDrift = s1Normalized("unicode", longText)
        titleDrift.title = "drifted title"
        let citationDrift = s1Normalized("unicode", longText)
        citationDrift.citation += "#drift"
        let versionDrift = s1Normalized("unicode", longText)
        versionDrift.metadata.targetVersion = "9.9.9"
        for (conflict in [titleDrift, citationDrift, versionDrift]) {
            let conflictResult = ckbCleanHistoricalStudentRecords(
                s1NormalizedList(normalized, second: conflict))
            @Expect(conflictResult.ok, false)
            @Expect(conflictResult.errorCode, "student_record_identity_conflict")
        }
        let exactDuplicate = ckbCleanHistoricalStudentRecords(
            s1NormalizedList(normalized, second: normalized))
        @Expect(exactDuplicate.ok, true)
        @Expect(exactDuplicate.records.size, 1)
        @Expect(ckbStudentCleanRejectionCount(exactDuplicate.rejectionCounts,
            "student_record_identity_duplicate"), 1)
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
        let firstRawPart = s1Raw("multi-raw", "first raw part")
        let secondRawPart = s1Raw("multi-raw", "second raw part")
        let firstNormalizedPart = s1Normalized("multi-raw", "first raw part")
        let secondNormalizedPart = s1Normalized("multi-raw", "second raw part")
        let multiRaw = ckbBuildCompleteCleanStudentCandidate(
            s1RawList(firstRawPart, second: secondRawPart),
            s1NormalizedList(firstNormalizedPart, second: secondNormalizedPart),
            s1NormalizedList(firstNormalizedPart, second: secondNormalizedPart),
            ArrayList<RawRecord>(), ArrayList<NormalizedRecord>(),
            ArrayList<NormalizedRecord>(), "clean-multi-raw-v1")
        @Expect(multiRaw.ok, true)
        @Expect(multiRaw.rawRecords.size, 2)
        @Expect(multiRaw.normalizedRecords.size, 2)

        let driftRaw = s1Raw("drift", "raw A🙂")
        let driftNormalized = s1Normalized("drift", "normalized B🙂")
        let drift = ckbBuildCompleteCleanStudentCandidate(
            s1RawList(driftRaw), s1NormalizedList(driftNormalized),
            s1NormalizedList(driftNormalized), ArrayList<RawRecord>(),
            ArrayList<NormalizedRecord>(), ArrayList<NormalizedRecord>(),
            "clean-drift-v1")
        @Expect(drift.ok, false)
        @Expect(drift.diagnostic, "clean_candidate_raw_normalized_content_mismatch")

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
        let sourceTreeBefore = s1DirectoryHash(source.root)
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
        @Expect(firstResult.immutableManifestHash, secondResult.immutableManifestHash)
        @Expect(firstResult.authorityHash.startsWith("sha256:"), true)
        @Expect(firstResult.auditEvidenceHash.startsWith("sha256:"), true)
        @Expect(firstResult.cleanManifestHash.startsWith("sha256:"), true)
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
        let immutableManifest = firstStore.readText(
            "candidate-artifacts/clean-positive-v1/manifest.ckb")
        let cleanManifest = firstStore.readText(
            "candidate-artifacts/clean-positive-v1/clean-candidate-manifest.json")
        let cleanAudit = firstStore.readText(
            "candidate-artifacts/clean-positive-v1/clean-candidate-audit.json")
        @Expect(immutableManifest.contains(
            "manifestEvidenceHash=${firstResult.manifestEvidenceHash}"), true)
        @Expect(cleanManifest.contains(
            "\"materializationManifestEvidenceHash\":\"${firstResult.manifestEvidenceHash}\""), true)
        @Expect(cleanManifest.contains(
            "\"immutableManifestHash\":\"${firstResult.immutableManifestHash}\""), true)
        @Expect(cleanManifest.contains("\"authorityHash\":\"${firstResult.authorityHash}\""), true)
        @Expect(cleanManifest.contains(
            "\"auditEvidenceHash\":\"${firstResult.auditEvidenceHash}\""), true)
        @Expect(cleanManifest.contains("\"batchCount\":1"), true)
        @Expect(cleanAudit.contains("\"historicalRaw\""), true)
        @Expect(cleanAudit.contains("\"inputChecksum\""), true)
        @Expect(cleanAudit.contains("\"outputChecksum\""), true)
        @Expect(cleanAudit.contains("\"rejections\""), true)
        @Expect(benchmarkGapSha256(cleanAudit.trimAscii()),
            firstResult.auditEvidenceHash)
        @Expect(cleanAudit.contains("CJ-HUMANEVAL"), false)
        @Expect(cleanAudit.contains("Rune uses Unicode"), false)
        @Expect(firstStore.loadActiveSnapshotPointer().valid, false)
        @Expect(ckbActiveSnapshotPointerIdentityHash(source.loadActiveSnapshotPointer()), before)
        @Expect(s1DirectoryHash(source.root), sourceTreeBefore)

        let cliStaging = "${root}/cli-apply"
        @Expect(runCkbCleanCandidateBuildCli([
            "cangjie-clean-candidate-build", "--apply",
            "--source-store", source.root.toString(),
            "--staging-store", cliStaging,
            "--authority-store", source.root.toString(),
            "--candidate-version", "clean-cli-v1", "--json"
        ]), 0)
        @Expect(FileKnowledgeStore(cliStaging).readText(
            "candidate-artifacts/clean-cli-v1/manifest.ckb").trimAscii() != "", true)
        @Expect(s1DirectoryHash(source.root), sourceTreeBefore)
    }

    @TestCase
    public func s1Neg01RejectsProtectedNonemptyChildAndOverlayDestinations(): Unit {
        let root = s1Root("negative")
        let source = s1PersistSource("${root}/source")
        s1PersistAuthority(source, "${root}/authority-data")
        let before = ckbActiveSnapshotPointerIdentityHash(source.loadActiveSnapshotPointer())
        let sourceTreeBefore = s1DirectoryHash(source.root)
        let protected = ArrayList<String>(); protected.add(source.root.toString())

        let same = ckbCleanCandidateBaseDiagnostic(source, protectedRoots: protected)
        @Expect(same.ok, false)
        @Expect(same.code, "contaminated_base_forbidden")
        let child = ckbCleanCandidateBaseDiagnostic(
            FileKnowledgeStore("${source.root}/candidate-output"), protectedRoots: protected)
        @Expect(child.ok, false)
        @Expect(child.code, "contaminated_base_forbidden")

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

        let namedProduction = Path("${root}/ckb-data-production")
        Directory.create(namedProduction, recursive: true)
        let safeAlias = "${root}/safe-parent"
        @Expect(launch("/bin/ln", ["-s", canonicalize(namedProduction).toString(),
            safeAlias]).wait(), 0)
        let parentSymlink = ckbCleanCandidateBaseDiagnostic(
            FileKnowledgeStore("${safeAlias}/candidate"), protectedRoots: protected)
        @Expect(parentSymlink.ok, false)
        @Expect(parentSymlink.code, "contaminated_base_forbidden")
        @Expect(exists(namedProduction.join("candidate")), false)

        @Expect(runCkbCleanCandidateBuildCli([
            "cangjie-clean-candidate-build", "--apply",
            "--source-store", source.root.toString(),
            "--staging-store", source.root.toString(),
            "--authority-store", source.root.toString(),
            "--candidate-version", "clean-forbidden-v1"
        ]), 1)
        @Expect(ckbActiveSnapshotPointerIdentityHash(source.loadActiveSnapshotPointer()), before)
        @Expect(s1DirectoryHash(source.root), sourceTreeBefore)
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

        let exactDuplicate = ckbBuildCompleteCleanStudentCandidate(
            s1RawList(rawOld), s1NormalizedList(old), s1NormalizedList(old),
            s1RawList(s1Raw("old", "old knowledge")), s1NormalizedOnly(old),
            s1NormalizedOnly(old), "clean-deduplicated-v1")
        @Expect(exactDuplicate.ok, true)
        @Expect(exactDuplicate.rawRecords.size, 1)
        @Expect(exactDuplicate.normalizedRecords.size, 1)
        @Expect(exactDuplicate.auditJson.contains(
            "\"student_record_identity_duplicate\":1"), true)

        let metadataRaw = s1Raw("metadata", "metadata round trip")
        let metadataNormalized = s1Normalized("metadata", "metadata round trip")
        s1PopulateAllMetadata(metadataRaw.metadata)
        s1PopulateAllMetadata(metadataNormalized.metadata)
        metadataRaw.requiresReview = true
        metadataNormalized.requiresReview = true
        metadataNormalized.score = 0.75
        let metadataCandidate = ckbBuildCompleteCleanStudentCandidate(
            s1RawList(metadataRaw), s1NormalizedList(metadataNormalized),
            s1NormalizedList(metadataNormalized), ArrayList<RawRecord>(),
            ArrayList<NormalizedRecord>(), ArrayList<NormalizedRecord>(),
            "clean-metadata-v1")
        @Expect(metadataCandidate.ok, true)
        s1ExpectMetadataRoundTrip(metadataCandidate.rawRecords[0].metadata)
        s1ExpectMetadataRoundTrip(metadataCandidate.normalizedRecords[0].metadata)
        s1ExpectMetadataRoundTrip(metadataCandidate.activeRecords[0].metadata)
        @Expect(metadataCandidate.rawRecords[0].requiresReview, true)
        @Expect(metadataCandidate.normalizedRecords[0].requiresReview, true)
        @Expect(metadataCandidate.normalizedRecords[0].score, 0.75)
        @Expect(cangjieStudentRecordDiagnostic(
            metadataCandidate.normalizedRecords[0]).ok, true)
        @Expect(ckbCleanCandidateConsistencyDiagnostic(
            metadataCandidate.rawRecords, metadataCandidate.normalizedRecords,
            metadataCandidate.activeRecords, "clean-metadata-v1").ok, true)

        let derivedDoc = s1DerivedOnly("derived-doc",
            CangjieTypedRecordKinds.DOC_SECTION, CangjieSourceSets.DOCS)
        let derivedTool = s1DerivedOnly("derived-tool",
            CangjieTypedRecordKinds.TOOL_MANUAL, CangjieSourceSets.TOOLS)
        let derived = ckbBuildCompleteCleanStudentCandidate(
            ArrayList<RawRecord>(), s1NormalizedArray(derivedDoc, derivedTool),
            s1NormalizedArray(derivedDoc, derivedTool), ArrayList<RawRecord>(),
            ArrayList<NormalizedRecord>(), ArrayList<NormalizedRecord>(),
            "clean-derived-only-v1")
        @Expect(derived.ok, true)
        @Expect(derived.rawRecords.size, 0)
        @Expect(derived.normalizedRecords.size, 2)
        @Expect(derived.activeRecords.size, 2)
        @Expect(derived.auditJson.contains("\"normalizedOnly\":2"), true)
        @Expect(derived.normalizedRecords[0].metadata.derivedFrom.size, 0)

        let badSourceId = s1DerivedOnly("bad-source-id",
            CangjieTypedRecordKinds.DOC_SECTION, CangjieSourceSets.DOCS)
        badSourceId.metadata.sourceId = "different"
        let badUrl = s1DerivedOnly("bad-url",
            CangjieTypedRecordKinds.DOC_SECTION, CangjieSourceSets.DOCS)
        badUrl.metadata.sourceUrl = "https://different.invalid"
        let badPath = s1DerivedOnly("bad-path",
            CangjieTypedRecordKinds.DOC_SECTION, CangjieSourceSets.DOCS)
        badPath.metadata.path = ""
        let badVersion = s1DerivedOnly("bad-version",
            CangjieTypedRecordKinds.DOC_SECTION, CangjieSourceSets.DOCS)
        badVersion.metadata.versionResolutionId = ""
        let badTrust = s1DerivedOnly("bad-trust",
            CangjieTypedRecordKinds.DOC_SECTION, CangjieSourceSets.DOCS)
        badTrust.metadata.trustLevel = TrustLevels.WEB_CANDIDATE
        let badReview = s1DerivedOnly("bad-review",
            CangjieTypedRecordKinds.DOC_SECTION, CangjieSourceSets.DOCS)
        badReview.metadata.reviewState = ReviewStates.CANDIDATE
        let badRole = s1DerivedOnly("bad-role",
            CangjieTypedRecordKinds.DOC_SECTION, CangjieSourceSets.TOOLS)
        let blankIdentity = s1DerivedOnly("blank-identity",
            CangjieTypedRecordKinds.DOC_SECTION, CangjieSourceSets.DOCS)
        blankIdentity.sourceId = "\u{3000}"
        blankIdentity.metadata.sourceId = "\u{3000}"
        let blankCitation = s1DerivedOnly("blank-citation",
            CangjieTypedRecordKinds.DOC_SECTION, CangjieSourceSets.DOCS)
        blankCitation.citation = "\t "
        blankCitation.metadata.sourceUrl = "\t "
        let blankPath = s1DerivedOnly("blank-path",
            CangjieTypedRecordKinds.DOC_SECTION, CangjieSourceSets.DOCS)
        blankPath.metadata.path = "\u{00a0}"
        let blankTarget = s1DerivedOnly("blank-target",
            CangjieTypedRecordKinds.DOC_SECTION, CangjieSourceSets.DOCS)
        blankTarget.metadata.targetVersion = "\u{2003}"
        let blankResolution = s1DerivedOnly("blank-resolution",
            CangjieTypedRecordKinds.DOC_SECTION, CangjieSourceSets.DOCS)
        blankResolution.metadata.versionResolutionId = "\u{feff}"
        let blankSourceType = s1DerivedOnly("blank-source-type",
            CangjieTypedRecordKinds.DOC_SECTION, CangjieSourceSets.DOCS)
        blankSourceType.metadata.sourceType = " "
        let blankSourceSet = s1DerivedOnly("blank-source-set",
            CangjieTypedRecordKinds.DOC_SECTION, CangjieSourceSets.DOCS)
        blankSourceSet.metadata.sourceSet = "\t"
        let blankRecordKind = s1DerivedOnly("blank-record-kind",
            CangjieTypedRecordKinds.DOC_SECTION, CangjieSourceSets.DOCS)
        blankRecordKind.recordKind = "\u{3000}"
        var invalidIndex: Int64 = 0
        for (invalid in [badSourceId, badUrl, badPath, badVersion,
            badTrust, badReview, badRole, blankIdentity, blankCitation,
            blankPath, blankTarget, blankResolution, blankSourceType,
            blankSourceSet, blankRecordKind]) {
            let invalidResult = s1BuildSelectedNormalizedOnly(
                invalid, "clean-invalid-derived-${invalidIndex}")
            @Expect(invalidResult.ok, false)
            invalidIndex += 1
        }

        let rawOnly = s1Raw("raw-only", "raw source retained for provenance")
        let rawOnlyResult = ckbBuildCompleteCleanStudentCandidate(
            s1RawList(rawOnly), ArrayList<NormalizedRecord>(),
            ArrayList<NormalizedRecord>(), ArrayList<RawRecord>(),
            ArrayList<NormalizedRecord>(), ArrayList<NormalizedRecord>(),
            "clean-raw-only-v1")
        @Expect(rawOnlyResult.ok, true)
        @Expect(rawOnlyResult.rawRecords.size, 1)
        @Expect(rawOnlyResult.normalizedRecords.size, 0)
        @Expect(rawOnlyResult.activeRecords.size, 0)
        @Expect(rawOnlyResult.auditJson.contains("\"rawOnly\":1"), true)

        let emptyRaw = s1Raw("empty-pair", "")
        emptyRaw.contentHash = benchmarkGapSha256("")
        let emptyNormalized = s1Normalized("empty-pair", "")
        let emptyPair = ckbBuildCompleteCleanStudentCandidate(
            s1RawList(emptyRaw), s1NormalizedOnly(emptyNormalized),
            s1NormalizedOnly(emptyNormalized), ArrayList<RawRecord>(),
            ArrayList<NormalizedRecord>(), ArrayList<NormalizedRecord>(),
            "clean-empty-pair-v1")
        @Expect(emptyPair.ok, false)
        @Expect(emptyPair.diagnostic, "student_raw_content_required")

        let emptyDerived = s1DerivedOnly("empty-derived",
            CangjieTypedRecordKinds.DOC_SECTION, CangjieSourceSets.DOCS)
        emptyDerived.chunk = ""
        let emptyDerivedResult = s1BuildSelectedNormalizedOnly(
            emptyDerived, "clean-empty-derived-v1")
        @Expect(emptyDerivedResult.ok, false)
        @Expect(emptyDerivedResult.diagnostic,
            "student_normalized_content_required")

        let whitespaceDerived = s1DerivedOnly("whitespace-derived",
            CangjieTypedRecordKinds.DOC_SECTION, CangjieSourceSets.DOCS)
        whitespaceDerived.chunk = "\u{2003}\u{3000}"
        let whitespaceDerivedResult = ckbBuildCompleteCleanStudentCandidate(
            ArrayList<RawRecord>(), ArrayList<NormalizedRecord>(),
            ArrayList<NormalizedRecord>(), ArrayList<RawRecord>(),
            s1NormalizedOnly(whitespaceDerived), s1NormalizedOnly(whitespaceDerived),
            "clean-whitespace-derived-v1")
        @Expect(whitespaceDerivedResult.ok, false)
        @Expect(whitespaceDerivedResult.diagnostic,
            "student_normalized_content_required")
    }

    @TestCase
    public func s1CliRunsBuiltMainWithIsolatedPositiveAndProtectedNegative(): Unit {
        let root = s1Root("binary-cli")
        let source = s1PersistSource("${root}/source")
        s1PersistAuthority(source, "${root}/authority-data")
        let production = Path("${root}/ckb-data-production")
        Directory.create(production, recursive: true)
        File.writeTo(production.join("sentinel"), "unchanged".toArray())
        let sourceBefore = s1DirectoryHash(source.root)
        let productionBefore = s1DirectoryHash(production)

        let positive = s1RunBuiltCli(root, [
            "cangjie-clean-candidate-build", "--apply",
            "--source-store", canonicalize(source.root).toString(),
            "--staging-store", canonicalize(Path(root)).join("binary-output").toString(),
            "--authority-store", canonicalize(source.root).toString(),
            "--candidate-version", "clean-binary-cli-v1", "--json"
        ], "positive")
        @Expect(positive[0], "0")
        @Expect(positive[1].contains("\"ok\":true"), true)
        @Expect(positive[1].contains("\"applied\":true"), true)
        @Expect(FileKnowledgeStore("${root}/binary-output").readText(
            "candidate-artifacts/clean-binary-cli-v1/clean-candidate-manifest.json")
            .contains("\"materializationManifestEvidenceHash\""), true)

        let negative = s1RunBuiltCli(root, [
            "cangjie-clean-candidate-build", "--apply",
            "--source-store", canonicalize(source.root).toString(),
            "--staging-store", production.join("candidate").toString(),
            "--authority-store", canonicalize(source.root).toString(),
            "--candidate-version", "clean-binary-cli-negative-v1", "--json"
        ], "negative")
        @Expect(negative[0], "1")
        @Expect(negative[1].contains("\"ok\":false"), true)
        @Expect(negative[1].contains("contaminated_base_forbidden"), true)
        @Expect(exists(production.join("candidate")), false)
        @Expect(s1DirectoryHash(source.root), sourceBefore)
        @Expect(s1DirectoryHash(production), productionBefore)
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

private func s1LegacyContentHash(sourceId: String, content: String): String {
    var hash: Int64 = 5381; let modulus: Int64 = 1000000007
    for (byte in "${sourceId}:${content}".toArray()) {
        hash = ((hash * 33) % modulus + (Int64(byte) % modulus)) % modulus
    }
    "hash-${hash}-${content.size}"
}

private func s1DerivedOnly(id: String, kind: String, sourceSet: String): NormalizedRecord {
    let record = s1Normalized(id, "Derived ${kind} knowledge")
    record.recordKind = kind
    record.metadata.sourceSet = sourceSet
    record.metadata.sourceId = id
    record.metadata.versionResolutionId = "${id}-version-resolution"
    record.metadata.derivedFrom = []
    record
}

private func s1BuildSelectedNormalizedOnly(record: NormalizedRecord,
    version: String): CkbCompleteCleanStudentCandidate {
    ckbBuildCompleteCleanStudentCandidate(
        ArrayList<RawRecord>(), ArrayList<NormalizedRecord>(),
        ArrayList<NormalizedRecord>(), ArrayList<RawRecord>(),
        s1NormalizedOnly(record), s1NormalizedOnly(record), version)
}

private func s1PopulateAllMetadata(metadata: KnowledgeMetadata): Unit {
    metadata.sourceId = "metadata"; metadata.sourceType = SourceTypes.DOC
    metadata.sourceUrl = "https://docs.cangjie-lang.cn/metadata"
    metadata.repo = "Cangjie/cangjie_docs"; metadata.path = "docs/metadata.md"
    metadata.symbol = "Metadata"; metadata.commit = "0123456789abcdef"
    metadata.docVersion = "1.0.0"; metadata.targetVersion = "1.0.0"
    metadata.sourceSet = CangjieSourceSets.DOCS
    metadata.versionResolutionId = "metadata-version-resolution"
    metadata.crawlAt = "2026-07-25T00:00:00Z"
    metadata.indexedAt = "2026-07-25T00:01:00Z"
    metadata.knowledgeVersion = "old-active"
    metadata.candidateVersion = "old-candidate"
    metadata.contentSize = 19; metadata.trustLevel = TrustLevels.OFFICIAL
    metadata.reviewState = ReviewStates.TRUSTED
    metadata.license = "Apache-2.0"; metadata.repoVisibility = "public"
    metadata.derivedFrom = ["official-metadata-source"]
}

private func s1ExpectMetadataRoundTrip(metadata: KnowledgeMetadata): Unit {
    @Expect(metadata.sourceId, "metadata")
    @Expect(metadata.sourceType, SourceTypes.DOC)
    @Expect(metadata.sourceUrl, "https://docs.cangjie-lang.cn/metadata")
    @Expect(metadata.repo, "Cangjie/cangjie_docs")
    @Expect(metadata.path, "docs/metadata.md")
    @Expect(metadata.symbol, "Metadata")
    @Expect(metadata.commit, "0123456789abcdef")
    @Expect(metadata.docVersion, "1.0.0")
    @Expect(metadata.targetVersion, "1.0.0")
    @Expect(metadata.sourceSet, CangjieSourceSets.DOCS)
    @Expect(metadata.versionResolutionId, "metadata-version-resolution")
    @Expect(metadata.crawlAt, "2026-07-25T00:00:00Z")
    @Expect(metadata.indexedAt, "2026-07-25T00:01:00Z")
    @Expect(metadata.knowledgeVersion, "clean-metadata-v1")
    @Expect(metadata.candidateVersion, "clean-metadata-v1")
    @Expect(metadata.contentSize, 19)
    @Expect(metadata.trustLevel, TrustLevels.OFFICIAL)
    @Expect(metadata.reviewState, ReviewStates.TRUSTED)
    @Expect(metadata.license, "Apache-2.0")
    @Expect(metadata.repoVisibility, "public")
    @Expect(metadata.derivedFrom, ["official-metadata-source"])
}

private func s1RunBuiltCli(root: String, args: Array<String>,
    name: String): (String, String) {
    let stdout = Path(root).join("${name}.stdout")
    let stderr = Path(root).join("${name}.stderr")
    var command = ckbAbcdeNativeTlsBootstrapScript(
        canonicalize(Path("../target/release/bin/main")).toString(), args)
    command += " > '${stdout.toString()}' 2> '${stderr.toString()}'"
    let process = launch("/bin/zsh", ["-c", command],
        stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
    let exitCode = process.wait()
    let output = try { String.fromUtf8(File.readFrom(stdout)) }
        catch (_: Exception) { "invalid_response_encoding" }
    let error = try { String.fromUtf8(File.readFrom(stderr)) }
        catch (_: Exception) { "invalid_response_encoding" }
    ("${exitCode}", output + error)
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

private func s1RawList(first: RawRecord,
    second!: RawRecord = RawRecord()): ArrayList<RawRecord> {
    let records = ArrayList<RawRecord>(); records.add(first)
    if (second.sourceId != "" || second.title != "" || second.content != "") {
        records.add(second)
    }
    records
}

private func s1NormalizedOnly(incoming: NormalizedRecord): ArrayList<NormalizedRecord> {
    let records = ArrayList<NormalizedRecord>(); records.add(incoming); records
}

private func s1NormalizedArray(first: NormalizedRecord,
    second: NormalizedRecord): ArrayList<NormalizedRecord> {
    let records = ArrayList<NormalizedRecord>(); records.add(first); records.add(second); records
}

private func s1DirectoryHash(root: Path): String {
    let entries = ArrayList<String>()
    s1CollectDirectoryHash(root, "", entries)
    let ordered = entries.toArray(); sort(ordered)
    let seed = StringBuilder()
    for (entry in ordered) { seed.append("${entry.toArray().size}:${entry}") }
    benchmarkGapSha256(seed.toString())
}

private func s1CollectDirectoryHash(root: Path, prefix: String,
    entries: ArrayList<String>): Unit {
    for (entry in Directory.readFrom(root)) {
        let relative = if (prefix == "") { entry.name } else { "${prefix}/${entry.name}" }
        if (entry.isDirectory()) {
            s1CollectDirectoryHash(entry.path, relative, entries)
        } else if (entry.isRegular()) {
            entries.add("${relative}=${s1BytesHash(File.readFrom(entry.path))}")
        }
    }
}

private func s1BytesHash(bytes: Array<UInt8>): String {
    let digest = SHA256(); digest.write(bytes); let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(s1HexNibble(byte / UInt8(16)))
        out.append(s1HexNibble(byte % UInt8(16)))
    }
    out.toString()
}

private func s1HexNibble(value: UInt8): String {
    if (value < UInt8(10)) { return "${value}" }
    if (value == UInt8(10)) { return "a" }
    if (value == UInt8(11)) { return "b" }
    if (value == UInt8(12)) { return "c" }
    if (value == UInt8(13)) { return "d" }
    if (value == UInt8(14)) { return "e" }
    "f"
}
