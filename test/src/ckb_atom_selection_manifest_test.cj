package cangjie_community_knowledge_base_test

import std.fs.{Directory, File, Path, exists, remove}
import std.process.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.json.*

@Test
public class CkbAtomSelectionManifestTest {
    @TestCase
    public func tR6UtMultiRevisionSelectionIsConsumableAndProofIsSanitized(): Unit {
        let root = r6SelectionRoot("ut")
        let first = r6WriteCandidate(root, "first.jsonl", "G-RUNE-COUNT", 1,
            "Count Unicode text by Rune boundaries 中文😀.")
        let second = r6WriteCandidate(root, "second.jsonl", "G-RUNE-COUNT", 2,
            "Count Unicode text with toRuneArray size 中文😀.", legacyHash: true)
        let manifest = r6ManifestLine("first.jsonl", first[1], first[0], "G-RUNE-COUNT", "") +
            r6ManifestLine("second.jsonl", second[1], second[0], "G-RUNE-COUNT", first[0])
        r6Write("${root}/selection.jsonl", manifest)
        let options = r6Options(root)

        let one = ckbBuildAtomSelection(options)
        let firstOutput = r6Read(options.outputPath)
        let firstProof = r6Read(options.proofPath)
        let two = ckbBuildAtomSelection(options)

        @Expect(one.ok, true)
        @Expect(one.selected, 1)
        @Expect(two.ok, true)
        @Expect(r6Read(options.outputPath), firstOutput)
        @Expect(r6Read(options.proofPath), firstProof)
        @Expect(firstOutput.contains("toRuneArray size 中文😀"), true)
        @Expect(firstOutput.contains("\"caseId\":\"PUBLIC-R6\""), true)
        @Expect(firstProof.contains("ckb-atom-selection-proof-v2"), true)
        @Expect(firstProof.contains("ckb-knowledge-atom-hash-legacy-8aa2969-parent"), true)
        @Expect(firstProof.contains("sourceBundleCandidateHash"), true)
        @Expect(firstProof.contains("normalizedBundleCandidateHash"), true)
        let normalized = parseBenchmarkGapInputsJsonl(firstOutput).inputs[0]
        let normalizedBundle = JsonValue.fromStr(normalized.knowledgeAtomTestBundle).asObject()
        @Expect(normalized.candidateHash, canonicalBenchmarkGapCandidateHash(normalized))
        @Expect(normalizedBundle.get("candidateHash").getOrThrow().asString().getValue(),
            cangjieKnowledgeAtomCandidateHash(normalized.knowledgeAtomTestBundle))
        let curated = curateBenchmarkGapRecordsFromJsonl(firstOutput)
        @Expect(curated.ok, true)
        @Expect(curated.records.size, 1)
        @Expect(curated.records[0].recordKind, CangjieTypedRecordKinds.KNOWLEDGE_ATOM)
        r6ExpectServingProjectionClean(curated.records[0])
        for (forbidden in ["caseId", "taskText", "tests", "solution", root]) {
            @Expect(firstProof.contains(forbidden), false)
        }
    }

    @TestCase
    public func tR6BndEmptyUnicodeConflictAndPathEscapeFailClosed(): Unit {
        let emptyRoot = r6SelectionRoot("empty")
        r6Write("${emptyRoot}/selection.jsonl", "")
        let empty = ckbBuildAtomSelection(r6Options(emptyRoot))
        @Expect(empty.ok, true)
        @Expect(empty.selected, 0)

        let unicodeRoot = r6SelectionRoot("unicode")
        let unicode = r6WriteCandidate(unicodeRoot, "候选😀.jsonl", "G-UNICODE", 1,
            "Rune-safe knowledge 中文😀.")
        r6Write("${unicodeRoot}/selection.jsonl",
            r6ManifestLine("候选😀.jsonl", unicode[1], unicode[0], "G-UNICODE", ""))
        @Expect(ckbBuildAtomSelection(r6Options(unicodeRoot)).ok, true)

        let conflictRoot = r6SelectionRoot("conflict")
        let left = r6WriteCandidate(conflictRoot, "left.jsonl", "G-CONFLICT", 1, "First general rule.")
        let right = r6WriteCandidate(conflictRoot, "right.jsonl", "G-CONFLICT", 1, "Second general rule.")
        r6Write("${conflictRoot}/selection.jsonl",
            r6ManifestLine("left.jsonl", left[1], left[0], "G-CONFLICT", "") +
            r6ManifestLine("right.jsonl", right[1], right[0], "G-CONFLICT", ""))
        @Expect(ckbBuildAtomSelection(r6Options(conflictRoot)).diagnostic, "selection_revision_conflict")

        let escapeRoot = r6SelectionRoot("escape")
        let outside = r6WriteCandidate("${escapeRoot}/..", "outside-r6.jsonl", "G-ESCAPE", 1, "General rule.")
        r6Write("${escapeRoot}/selection.jsonl",
            r6ManifestLine("../outside-r6.jsonl", outside[1], outside[0], "G-ESCAPE", ""))
        @Expect(ckbBuildAtomSelection(r6Options(escapeRoot)).diagnostic, "artifact_path_forbidden")
        @Expect(launch("/bin/ln", ["-s", "../outside-r6.jsonl", "${escapeRoot}/link.jsonl"]).wait(), 0)
        r6Write("${escapeRoot}/selection.jsonl",
            r6ManifestLine("link.jsonl", outside[1], outside[0], "G-ESCAPE", ""))
        @Expect(ckbBuildAtomSelection(r6Options(escapeRoot)).diagnostic, "artifact_symlink_forbidden")
    }

    @TestCase
    public func tR6PosExplicitTwoAtomSelectionWritesOneAggregateAndProof(): Unit {
        let root = r6SelectionRoot("pos")
        let rune = r6WriteCandidate(root, "rune.jsonl", "G-RUNE", 1, "Use Rune boundaries 中文😀.")
        let list = r6WriteCandidate(root, "list.jsonl", "G-LIST", 1, "Use ArrayList append for dynamic data.")
        r6Write("${root}/selection.jsonl",
            r6ManifestLine("rune.jsonl", rune[1], rune[0], "G-RUNE", "") +
            r6ManifestLine("list.jsonl", list[1], list[0], "G-LIST", ""))

        let result = ckbBuildAtomSelection(r6Options(root))

        @Expect(result.ok, true)
        @Expect(result.inputRows, 2)
        @Expect(result.selected, 2)
        @Expect(result.evidenceHash.startsWith("sha256:"), true)
        @Expect(r6Read("${root}/aggregate.jsonl").split("\n").size, 3)
        @Expect(r6Read("${root}/proof.json").contains("\"selected\":2"), true)
        let curated = curateBenchmarkGapRecordsFromJsonl(r6Read("${root}/aggregate.jsonl"))
        @Expect(curated.ok, true)
        @Expect(curated.records.size, 2)
        for (record in curated.records) {
            @Expect(record.recordKind, CangjieTypedRecordKinds.KNOWLEDGE_ATOM)
            r6ExpectServingProjectionClean(record)
        }
        @Expect(runCkbAtomSelectionCli(["cangjie-atom-selection-build", "--manifest", "${root}/selection.jsonl",
            "--teacher-export-root", root, "--output", "${root}/aggregate.jsonl", "--proof", "${root}/proof.json"]), 0)
    }

    @TestCase
    public func tR6NegTamperGraphEncodingAndLeakageAreRejected(): Unit {
        let hashRoot = r6SelectionRoot("hash")
        let valid = r6WriteCandidate(hashRoot, "candidate.jsonl", "G-HASH", 1, "General hash rule.")
        r6Write("${hashRoot}/selection.jsonl",
            r6ManifestLine("candidate.jsonl", r6Sha("wrong-file"), valid[0], "G-HASH", ""))
        @Expect(ckbBuildAtomSelection(r6Options(hashRoot)).diagnostic, "artifact_sha256_mismatch")
        r6Write("${hashRoot}/selection.jsonl",
            r6ManifestLine("candidate.jsonl", valid[1], r6Sha("wrong-candidate"), "G-HASH", ""))
        @Expect(ckbBuildAtomSelection(r6Options(hashRoot)).diagnostic, "candidate_hash_mismatch")

        let legacyHashRoot = r6SelectionRoot("legacy-wrong-hash")
        let legacyWrong = r6WriteCandidate(legacyHashRoot, "candidate.jsonl", "G-LEGACY-WRONG", 1,
            "General legacy hash rule.", legacyHash: true, bundleHashOverride: r6Sha("not-a-legacy-hash"))
        r6Write("${legacyHashRoot}/selection.jsonl",
            r6ManifestLine("candidate.jsonl", legacyWrong[1], legacyWrong[0], "G-LEGACY-WRONG", ""))
        @Expect(ckbBuildAtomSelection(r6Options(legacyHashRoot)).diagnostic, "atom_candidate_hash_mismatch")

        let migrationTamperRoot = r6SelectionRoot("migration-tamper")
        let migrationTamper = r6WriteCandidate(migrationTamperRoot, "candidate.jsonl", "G-MIGRATION-TAMPER", 1,
            "General migration binding rule.", legacyHash: true)
        let migrationTamperPath = "${migrationTamperRoot}/candidate.jsonl"
        r6Write(migrationTamperPath, r6Read(migrationTamperPath).replace(
            "\"knowledgeFamily\":\"syntax\"", "\"knowledgeFamily\":\"engineering_practice\""))
        r6Write("${migrationTamperRoot}/selection.jsonl", r6ManifestLine("candidate.jsonl",
            ckbAtomSelectionFileSha256(migrationTamperPath), migrationTamper[0], "G-MIGRATION-TAMPER", ""))
        @Expect(ckbBuildAtomSelection(r6Options(migrationTamperRoot)).diagnostic, "candidate_hash_mismatch")

        let graphRoot = r6SelectionRoot("graph")
        let a = r6WriteCandidate(graphRoot, "a.jsonl", "G-GRAPH", 1, "Graph rule one.")
        let b = r6WriteCandidate(graphRoot, "b.jsonl", "G-GRAPH", 2, "Graph rule two.")
        r6Write("${graphRoot}/selection.jsonl",
            r6ManifestLine("a.jsonl", a[1], a[0], "G-GRAPH", b[0]) +
            r6ManifestLine("b.jsonl", b[1], b[0], "G-GRAPH", a[0]))
        @Expect(ckbBuildAtomSelection(r6Options(graphRoot)).diagnostic, "selection_cycle")
        r6Write("${graphRoot}/selection.jsonl",
            r6ManifestLine("b.jsonl", b[1], b[0], "G-GRAPH", r6Sha("missing")))
        @Expect(ckbBuildAtomSelection(r6Options(graphRoot)).diagnostic, "selection_dangling_supersedes")

        let encodingRoot = r6SelectionRoot("encoding")
        File.writeTo(Path("${encodingRoot}/selection.jsonl"), [UInt8(0xff), UInt8(0xfe)])
        @Expect(ckbBuildAtomSelection(r6Options(encodingRoot)).diagnostic, "invalid_response_encoding")

        let leakRoot = r6SelectionRoot("leak")
        let leak = r6WriteCandidate(leakRoot, "candidate.jsonl", "G-LEAK", 1, "General safe rule.")
        let row = r6ManifestLine("candidate.jsonl", leak[1], leak[0], "G-LEAK", "").trimAscii()
        r6Write("${leakRoot}/selection.jsonl", row[0..(row.toRuneArray().size - 1)] + ",\"caseId\":\"forbidden\"}\n")
        @Expect(ckbBuildAtomSelection(r6Options(leakRoot)).diagnostic, "selection_field_contract_invalid")

        let hiddenRoot = r6SelectionRoot("hidden")
        let hidden = r6WriteCandidate(hiddenRoot, "candidate.jsonl", "G-HIDDEN", 1,
            "Use a hidden reference solution recipe.")
        r6Write("${hiddenRoot}/selection.jsonl",
            r6ManifestLine("candidate.jsonl", hidden[1], hidden[0], "G-HIDDEN", ""))
        @Expect(ckbBuildAtomSelection(r6Options(hiddenRoot)).diagnostic, "atom_content_contamination")

        let provenanceRoot = r6SelectionRoot("provenance")
        let provenanceA = r6WriteCandidate(provenanceRoot, "a.jsonl", "G-PROVENANCE", 1,
            "General provenance rule.", bundleExtra: "\"inventoryMarker\":\"case056-v3\"")
        let provenanceB = r6WriteCandidate(provenanceRoot, "b.jsonl", "G-PROVENANCE", 2,
            "General provenance rule.", bundleExtra: "\"inventoryMarker\":\"case061-v3\"")
        r6Write("${provenanceRoot}/selection.jsonl",
            r6ManifestLine("a.jsonl", provenanceA[1], provenanceA[0], "G-PROVENANCE", "") +
            r6ManifestLine("b.jsonl", provenanceB[1], provenanceB[0], "G-PROVENANCE", provenanceA[0]))
        @Expect(ckbBuildAtomSelection(r6Options(provenanceRoot)).diagnostic,
            "atom_identity_provenance_conflict")
    }
}

private func r6Options(root: String): CkbAtomSelectionOptions {
    let options = CkbAtomSelectionOptions()
    options.manifestPath = "${root}/selection.jsonl"
    options.teacherExportRoot = root
    options.outputPath = "${root}/aggregate.jsonl"
    options.proofPath = "${root}/proof.json"
    options
}

private func r6SelectionRoot(name: String): String {
    let root = "target/t-r6-selection-${name}"
    if (exists(Path(root))) { remove(Path(root), recursive: true) }
    Directory.create(Path(root), recursive: true)
    root
}

private func r6WriteCandidate(root: String, name: String, atomId: String, revision: Int64,
    knowledgeText: String, bundleExtra!: String = "", legacyHash!: Bool = false,
    bundleHashOverride!: String = ""): (String, String) {
    if (!exists(Path(root))) { Directory.create(Path(root), recursive: true) }
    let bundleMarker = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
    let extra = if (bundleExtra == "") { "" } else { ",${bundleExtra}" }
    let rawBundle = "{\"atomId\":\"${atomId}\",\"knowledgeFamily\":\"syntax\",\"sourceClass\":\"official\",\"citation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/\",\"targetVersion\":\"1.0.0\",\"candidateHash\":\"${bundleMarker}\",\"knowledgeText\":\"${knowledgeText}\",\"example\":\"General example 中文😀.\",\"extractor\":{\"provider\":\"codex\",\"model\":\"gpt-5.6-sol\",\"exitCode\":0,\"transcriptHash\":\"${r6Sha("public-transcript")}\"},\"purificationPassed\":true,\"tests\":[{\"category\":\"positive\",\"operation\":\"arraylist_size\",\"input\":\"[1,2,3]\",\"expected\":\"3\"},{\"category\":\"negative\",\"operation\":\"contains\",\"input\":\"stable\",\"needle\":\"unstable\",\"expected\":\"false\"},{\"category\":\"boundary\",\"operation\":\"rune_count\",\"input\":\"中文😀\",\"expected\":\"3\"}],\"execution\":{\"total\":3,\"passed\":3,\"failed\":0,\"status\":\"passed\",\"commandEvidence\":\"public\",\"commandEvidenceHash\":\"${r6Sha("public")}\"}${extra}}"
    let computedBundleHash = if (legacyHash) { r6LegacyAtomHash(rawBundle) } else {
        cangjieKnowledgeAtomCandidateHash(rawBundle)
    }
    let declaredBundleHash = if (bundleHashOverride == "") { computedBundleHash } else { bundleHashOverride }
    let bundle = rawBundle.replace(bundleMarker, declaredBundleHash)
    let input = CangjieBenchmarkGapInput()
    input.schemaVersion = "ckb-benchmark-gap-v1"
    input.datasetVersion = r6DatasetVersion()
    input.teacherRunId = "teacher-r6-public"
    input.evidence = "public atomic knowledge evidence"
    input.evidenceHash = benchmarkGapSha256(input.evidence)
    input.candidatePath = "candidate-knowledge/ckb-benchmark-gap.jsonl"
    input.revision = revision
    input.attempt = 1
    input.failureTaxonomy = "knowledge_gap"
    input.knowledgeGapConfirmations = 2
    input.caseId = "PUBLIC-R6"
    input.benchmark = "public-cangjie-regression"
    input.taskText = "General public Cangjie task."
    input.compilerOutput = "public compile diagnostic"
    input.missingKnowledge = "G-ARRAYLIST"
    input.interfaceId = "KI-02"
    input.contentFamily = "KC-02"
    input.updateMechanism = "KU-11"
    input.targetVersion = "1.0.0"
    input.officialCitation = "https://docs.cangjie-lang.cn/docs/1.0.0/"
    input.knowledgeAtomCandidate = true
    input.knowledgeAtomTestBundle = bundle
    input.candidateHash = canonicalBenchmarkGapCandidateHash(input)
    let line = "{\"schemaVersion\":\"ckb-benchmark-gap-v1\",\"datasetVersion\":\"${input.datasetVersion}\",\"teacherRunId\":\"${input.teacherRunId}\",\"evidenceHash\":\"${input.evidenceHash}\",\"evidence\":\"${input.evidence}\",\"candidateHash\":\"${input.candidateHash}\",\"candidatePath\":\"${input.candidatePath}\",\"revision\":${revision},\"attempt\":1,\"failureTaxonomy\":\"knowledge_gap\",\"knowledgeGapConfirmations\":2,\"caseId\":\"PUBLIC-R6\",\"benchmark\":\"public-cangjie-regression\",\"taskText\":\"General public Cangjie task.\",\"compilerOutput\":\"public compile diagnostic\",\"missingKnowledge\":\"G-ARRAYLIST\",\"interfaceId\":\"KI-02\",\"contentFamily\":\"KC-02\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"1.0.0\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/\",\"knowledgeAtomCandidate\":true,\"knowledgeAtomTestBundle\":${bundle}}\n"
    r6Write("${root}/${name}", line)
    (input.candidateHash, ckbAtomSelectionFileSha256("${root}/${name}"))
}

private func r6ManifestLine(path: String, fileHash: String, candidateHash: String,
    atomId: String, supersedes: String): String {
    "{\"artifactPath\":\"${path}\",\"fileSha256\":\"${fileHash}\",\"candidateHash\":\"${candidateHash}\",\"atomId\":\"${atomId}\",\"datasetVersion\":\"${r6DatasetVersion()}\",\"supersedes\":\"${supersedes}\"}\n"
}

private func r6DatasetVersion(): String {
    "cangjie-humaneval-164-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
}

private func r6Write(path: String, text: String): Unit { File.writeTo(Path(path), text.toArray()) }
private func r6Read(path: String): String { String.fromUtf8(File.readFrom(Path(path))) }
private func r6Sha(value: String): String { benchmarkGapSha256(value) }

private func r6LegacyAtomHash(bundle: String): String {
    let object = JsonValue.fromStr(bundle).asObject()
    let tests = object.get("tests").getOrThrow().toString()
    r6Sha(r6Part(object.get("atomId").getOrThrow().asString().getValue()) +
        r6Part(object.get("sourceClass").getOrThrow().asString().getValue().toAsciiLower()) +
        r6Part(object.get("citation").getOrThrow().asString().getValue().toAsciiLower()) +
        r6Part(object.get("targetVersion").getOrThrow().asString().getValue()) +
        r6Part(object.get("knowledgeText").getOrThrow().asString().getValue()) +
        r6Part("true") + r6Part(tests))
}

private func r6Part(value: String): String { "${value.toArray().size}:${value}" }

private func r6ExpectServingProjectionClean(record: NormalizedRecord): Unit {
    let serving = "${record.sourceId}\n${record.title}\n${record.chunk}\n${record.citation}\n${record.metadata.path}\n${record.metadata.symbol}".toAsciiLower()
    for (forbidden in ["public-r6", "caseid", "tasktext", "tests", "solution", "humaneval"]) {
        @Expect(serving.contains(forbidden), false)
    }
}
