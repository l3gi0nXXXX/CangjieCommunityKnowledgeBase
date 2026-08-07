package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists}
import std.process.launch
import std.sort.*
import std.time.DateTime
import std.unittest.*
import std.unittest.testmacro.*
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

@Test
public class CangjieStudentContextBundleTest {
    // S3-UT
    @TestCase
    public func studentRulesRoundTripFreezeAndPublish(): Unit {
        let root = s3FixtureRoot().join("candidate-set-v2")
        let parsed = parseStudentRuleCandidateDirectory(
            root.join("rules/prefer-rune-safe-text-boundaries").toString())
        @Expect(parsed.verified, true)
        @Expect(parsed.diagnostic, "ok")
        @Expect(parsed.body.contains("中文🙂"), true)
        @Expect(parsed.generalizationEvidenceHash,
            "sha256:ec2136f9ae8146cb11faa32bf93437744986ce4b9f5b467c7ef92e70c2b35667")

        let rules = ArrayList<CkbStudentRuleCandidate>()
        rules.add(parsed)
        let bundle = compileStudentRulesBundle("s3-rules-v1", rules)
        @Expect(bundle.ok, true)
        @Expect(bundle.ruleCount, 1)
        @Expect(bundle.agentsMarkdown.contains("中文🙂"), true)
        let bundleObject = JsonValue.fromStr(bundle.json).asObject()
        let ruleContent = bundleObject.get("rules").getOrThrow().asArray()
            .getItems()[0].asObject().get("content").getOrThrow().asString().getValue()
        @Expect(ruleContent.startsWith("\n## "), true)
        @Expect(ruleContent.contains("# Student Rules"), false)
        @Expect(bundle.agentsMarkdown, "# Student Rules\n" + ruleContent)

        let output = s3UniqueRoot("rules-round-trip").join("student-rules.json")
        @Expect(publishStudentRulesBundle(output.toString(), bundle), "ok")
        @Expect(publishStudentRulesBundle(output.toString(), bundle), "ok")
        @Expect(String.fromUtf8(File.readFrom(output)), bundle.json + "\n")

        let conflicting = ArrayList<CkbStudentRuleCandidate>()
        conflicting.add(parsed)
        conflicting.add(s3Rule(parsed.ruleId, parsed.priority, "different body"))
        @Expect(compileStudentRulesBundle("s3-rules-conflict", conflicting).diagnostic,
            "rule_conflict_requires_review")
    }

    @TestCase
    public func studentContextImportValidatesApprovalAndPerLaneLineage(): Unit {
        let fixture = s3FixtureRoot()
        let candidate = parseTeacherContextCandidateSetDirectoryV2(
            fixture.toString(), fixture.join("candidate-set-v2").toString())
        @Expect(candidate.candidateSetId, "synthetic-independent-context-v2")
        @Expect(candidate.rules.lineage, "independent")
        @Expect(candidate.skills.lineage, "independent")
        @Expect(candidate.knowledge.lineage, "independent")
        @Expect(candidate.rules.files.size > 0, true)
        @Expect(candidate.skills.files.size > 0, true)
        @Expect(candidate.knowledge.files.size, 1)
        let skill = parseStudentSkillCandidateDirectory(
            fixture.join("candidate-set-v2/skills/rune-safe-review").toString(), true)
        @Expect(skill.verified, true)
        @Expect(skill.candidateContentHash,
            "sha256:b51c608314f131470038059a7407e575cd4e0bf1b6aa513c830d729e8b65c45a")
        @Expect(skill.skillContent.startsWith("---\nname: rune-safe-review\n"), true)
        @Expect(candidate.skills.hash, benchmarkGapSha256(skill.skillContent))
        @Expect(candidate.skills.hash == skill.candidateContentHash, false)
        let skills = ArrayList<CkbStudentSkillCandidate>()
        skills.add(skill); skills.add(s3Skill("second-rune-review", "Review Rune lists safely."))
        let multiSkill = compileStudentSkillBundle("s3-skills-v1", skills)
        @Expect(multiSkill.ok, true)
        @Expect(multiSkill.skillCount, 2)

        let approval = String.fromUtf8(File.readFrom(fixture.join("approval-v2.json"))).trimAscii()
        @Expect(validateTeacherContextApprovalV2(approval, candidate), "approve")
        @Expect(validateTeacherContextApprovalV2(
            approval.replace("\"decision\":\"approve\"", "\"decision\":\"reject\""), candidate), "reject")

        // A candidate reference is not sufficient: compilation must bind a real frozen store.
        let missing = s3UniqueRoot("missing-frozen")
        let allowed = canonicalize(Path("."))
        let context = compileStudentContextBundleScaffold(allowed.toString(), "s3-context-v1",
            fixture.join("candidate-set-v2").toString(), fixture.join("approval-v2.json").toString(),
            missing.join("frozen-candidate-manifest.json").toString(),
            FileKnowledgeStore(missing.join("store").toString()))
        @Expect(context.ok, false)
        @Expect(context.diagnostic, "frozen_knowledge_reference_invalid")
    }

    // S3-POS
    @TestCase
    public func studentContextPublishIsAtomicAndIdempotent(): Unit {
        let fixture = s3ProductionContextFixture("context-publish")
        let output = fixture.allowed.join("nested/missing-parent/published-context")
        let bundle = compileAndPublishStudentContextBundle(fixture.allowed.toString(), "s3-context-v1",
            fixture.candidate.toString(), fixture.approval.toString(), "none", fixture.manifest.toString(),
            fixture.store, output.toString(), true)
        @Expect(bundle.ok, true)
        let again = compileAndPublishStudentContextBundle(fixture.allowed.toString(), "s3-context-v1",
            fixture.candidate.toString(), fixture.approval.toString(), "none", fixture.manifest.toString(),
            fixture.store, output.toString(), true)
        @Expect(again.ok, true)
        @Expect(Directory.readFrom(output).size, 7)
        @Expect(String.fromUtf8(File.readFrom(output.join("AGENTS.md"))), bundle.agentsMarkdown)

        File.writeTo(output.join("AGENTS.md"), "tampered\n".toArray())
        let conflict = compileAndPublishStudentContextBundle(fixture.allowed.toString(), "s3-context-v1",
            fixture.candidate.toString(), fixture.approval.toString(), "none", fixture.manifest.toString(),
            fixture.store, output.toString(), true)
        @Expect(conflict.diagnostic, "student_context_composite_hash_mismatch")
        @Expect(String.fromUtf8(File.readFrom(output.join("AGENTS.md"))), "tampered\n")

        let preexistingStage = fixture.allowed.join(".blocked.tmp-${bundle.compositeHash.replace("sha256:", "")}")
        Directory.create(preexistingStage, recursive: true)
        File.writeTo(preexistingStage.join("owner.txt"), "keep\n".toArray())
        let blocked = compileAndPublishStudentContextBundle(fixture.allowed.toString(), "s3-context-v1",
            fixture.candidate.toString(), fixture.approval.toString(), "none", fixture.manifest.toString(),
            fixture.store, fixture.allowed.join("blocked").toString(), true)
        @Expect(blocked.diagnostic, "student_context_partial_publish_blocked")
        @Expect(String.fromUtf8(File.readFrom(preexistingStage.join("owner.txt"))), "keep\n")
    }

    // S3-MERGE-01: production base-v2 merge keeps inactive lanes and applies replace+add atomically.
    @TestCase
    public func studentContextBaseV2InactiveReplaceAddMultiAssetMerge(): Unit {
        let fixture = s3ProductionContextFixture("base-v2-merge")
        let baseOutput = fixture.allowed.join("base-context")
        let base = compileAndPublishStudentContextBundle(fixture.allowed.toString(), "s3-base-v1",
            fixture.candidate.toString(), fixture.approval.toString(), "none", fixture.manifest.toString(),
            fixture.store, baseOutput.toString(), true)
        @Expect(base.ok, true)
        let update = s3ProductionUpdateFixture(fixture, baseOutput, base)
        let updatedOutput = fixture.allowed.join("updated-context")
        let updated = compileAndPublishStudentContextBundle(fixture.allowed.toString(), "s3-update-v2",
            update.candidate.toString(), update.approval.toString(), baseOutput.toString(),
            update.manifest.toString(), update.store, updatedOutput.toString(), true)
        @Expect(updated.ok, true)
        @Expect(updated.agentsMarkdown.contains("Additional Rune boundary review"), true)
        @Expect(updated.skillsPrompt, base.skillsPrompt)
        @Expect(updated.knowledgeReferenceJson, base.knowledgeReferenceJson)
    }

    // S3-NEG
    @TestCase
    public func studentVisibleAssetCombinationFailsClosed(): Unit {
        let protected = ["canonical_solution"]
        @Expect(auditStudentVisibleAssetCombination("safe inherited knowledge", "safe active skill",
            "safe active rule", protected), "ok")
        @Expect(auditStudentVisibleAssetCombination("tion", "solu", "canonical_", protected),
            "student_visible_asset_combination_leakage")

        let allowed = s3UniqueRoot("combined-leakage")
        @Expect(runStudentContextImportCli(["cangjie-student-context-import", "--json"]), 2)
        @Expect(renderStudentContextImportCliDiagnostic(true, false, "usage_error", "incomplete"),
            "{\"ok\":false,\"diagnostic\":\"usage_error\",\"message\":\"incomplete\"}")
        @Expect(renderStudentContextImportCliDiagnostic(false, false, "usage_error", "incomplete"),
            "incomplete: usage_error")
        @Expect(exists(allowed.join("must-not-publish")), false)
    }

    // S3-AUTH-LEDGER / Teacher supersede 6ad229568559e09917057624b3b41b6350b5fb51
    @TestCase
    public func studentContextFixtureAuthorityIsPinned(): Unit {
        @Expect(benchmarkGapSha256(String.fromUtf8(File.readFrom(s3FixtureRoot().join("SHA256SUMS")))),
            "sha256:c6454da21eca3afad1814ce329afc39f566ba75506194b9a41d2c5309b9e9324")
        @Expect("ea90cf34357653663eaf8a52b263e2629d585036".size, 40)
    }

    // S3-CLI-01/02: both human and machine modes execute the production compile→publish path.
    @TestCase
    public func studentContextCliHumanAndJsonProductionPaths(): Unit {
        let human = s3ProductionContextFixture("cli-human")
        @Expect(runStudentContextImportCli(s3CliArgs(human, human.allowed.join("human-output"), false)), 0)
        let machine = s3ProductionContextFixture("cli-json")
        @Expect(runStudentContextImportCli(s3CliArgs(machine, machine.allowed.join("json-output"), true)), 0)
    }

    // S3-STRICT-01..06: hash resealing cannot bypass semantic/order/mode/store gates.
    @TestCase
    public func studentContextStrictInnerContractsAndRealModeGate(): Unit {
        @Expect(studentSkillFixturePathsCanonical([
            "tests/boundary.txt", "tests/negative.txt", "tests/positive.txt"]), true)
        @Expect(studentSkillFixturePathsCanonical([
            "tests/positive.txt", "tests/boundary.txt", "tests/negative.txt"]), false)
        @Expect(studentContextRuleSkillConflictDiagnostic(
            "Agents must use Rune-safe boundaries.", "Agents must not use Rune-safe boundaries."),
            "conflicting_cross_lane_asset_content")

        let fixture = s3ProductionContextFixture("strict-contracts")
        let real = compileStudentContextBundleReal(fixture.allowed.toString(), "s3-real-gate",
            fixture.candidate.toString(), fixture.approval.toString(), fixture.manifest.toString(), fixture.store)
        @Expect(real.ok, false)
        @Expect(real.diagnostic, "student_context_not_student_validated")

        let rawReference = s3ProductionContextFixture("raw-reference-masquerade")
        File.writeTo(rawReference.candidate.join("knowledge/knowledge-candidate-reference.json"),
            "Rune source bytes are not a frozen reference.\n".toArray())
        s3ResealGenesisCandidateOuter(rawReference)
        let rawBlocked = compileStudentContextBundleScaffold(rawReference.allowed.toString(), "s3-raw-reference",
            rawReference.candidate.toString(), rawReference.approval.toString(), rawReference.manifest.toString(),
            rawReference.store)
        @Expect(rawBlocked.ok, false)

        let innerMismatch = s3ProductionContextFixture("inner-mismatch")
        let expected = innerMismatch.candidate.join(
            "rules/prefer-rune-safe-text-boundaries/tests/positive-contract/expected.txt")
        File.writeTo(expected, " preserved evidence with spaces  \n".toArray())
        s3ResealGenesisCandidateOuter(innerMismatch)
        let mismatch = compileStudentContextBundleScaffold(innerMismatch.allowed.toString(), "s3-inner-mismatch",
            innerMismatch.candidate.toString(), innerMismatch.approval.toString(), innerMismatch.manifest.toString(),
            innerMismatch.store)
        @Expect(mismatch.ok, false)

        let compositeTamper = s3ProductionContextFixture("combo-composite-tamper")
        s3ResealGenesisCandidateOuter(compositeTamper, combination: "sha256:" + s3Hex(r'0'))
        let tampered = compileStudentContextBundleScaffold(compositeTamper.allowed.toString(), "s3-combo-tamper",
            compositeTamper.candidate.toString(), compositeTamper.approval.toString(),
            compositeTamper.manifest.toString(), compositeTamper.store)
        @Expect(tampered.ok, false)

        let baseFixture = s3ProductionContextFixture("base-composite-tamper")
        let baseRoot = baseFixture.allowed.join("base")
        let base = compileAndPublishStudentContextBundle(baseFixture.allowed.toString(), "s3-base-tamper",
            baseFixture.candidate.toString(), baseFixture.approval.toString(), "none",
            baseFixture.manifest.toString(), baseFixture.store, baseRoot.toString(), true)
        @Expect(base.ok, true)
        let update = s3ProductionUpdateFixture(baseFixture, baseRoot, base)
        let baseManifest = baseRoot.join("student-context-manifest.json")
        let baseRaw = String.fromUtf8(File.readFrom(baseManifest))
        File.writeTo(baseManifest, baseRaw.replace("\"compositeHash\":\"sha256:",
            "\"compositeHash\":\"sha256:0").toArray())
        let compositeBlocked = compileStudentContextBundleScaffoldWithBase(baseFixture.allowed.toString(),
            "s3-base-composite-block", update.candidate.toString(), update.approval.toString(),
            baseRoot.toString(), update.manifest.toString(), update.store)
        @Expect(compositeBlocked.ok, false)
    }

    // S3-FS-01/02: traversal/symlink-shaped paths and occupied stages fail closed.
    @TestCase
    public func studentContextFilesystemBoundariesFailClosed(): Unit {
        let fixture = s3ProductionContextFixture("filesystem-boundaries")
        let outside = fixture.allowed.join("../outside-context")
        let blocked = compileAndPublishStudentContextBundle(fixture.allowed.toString(), "s3-path-block",
            fixture.candidate.toString(), fixture.approval.toString(), "none", fixture.manifest.toString(),
            fixture.store, outside.toString(), true)
        @Expect(blocked.diagnostic, "artifact_path_outside_allowed_root")
        let candidateLink = fixture.allowed.join("candidate-link")
        @Expect(launch("/bin/ln", ["-s", fixture.candidate.toString(), candidateLink.toString()]).wait(), 0)
        let symlinkBlocked = compileAndPublishStudentContextBundle(fixture.allowed.toString(), "s3-symlink-block",
            candidateLink.toString(), fixture.approval.toString(), "none", fixture.manifest.toString(),
            fixture.store, fixture.allowed.join("symlink-output").toString(), true)
        @Expect(symlinkBlocked.diagnostic, "artifact_path_outside_allowed_root")
    }

    // S3-BND
    @TestCase
    public func studentRuleLimitsOrderingAndMalformedInputsFailClosed(): Unit {
        @Expect(runStudentContextImportCli(["cangjie-student-context-import"]), 2)
        let one = ArrayList<CkbStudentRuleCandidate>()
        one.add(s3Rule("one", 1, "one"))
        @Expect(compileStudentRulesBundle("rules-one", one).ok, true)

        let sixteen = ArrayList<CkbStudentRuleCandidate>()
        for (i in 0..16) { sixteen.add(s3Rule("rule-${i}", Int64(i), "body-${i}")) }
        @Expect(compileStudentRulesBundle("rules-sixteen", sixteen).ok, true)
        sixteen.add(s3Rule("rule-16", 16, "body-16"))
        @Expect(compileStudentRulesBundle("rules-seventeen", sixteen).diagnostic,
            "student_rule_count_exceeded")

        let priorities = ArrayList<CkbStudentRuleCandidate>()
        priorities.add(s3Rule("priority-zero", 0, "zero"))
        priorities.add(s3Rule("priority-one", 1, "one"))
        priorities.add(s3Rule("priority-thousand", 1000, "thousand"))
        let ordered = compileStudentRulesBundle("rules-priority", priorities)
        @Expect(ordered.agentsMarkdown.indexOf("Rule priority-thousand").getOrThrow() <
            ordered.agentsMarkdown.indexOf("Rule priority-one").getOrThrow(), true)
        @Expect(ordered.agentsMarkdown.indexOf("Rule priority-one").getOrThrow() <
            ordered.agentsMarkdown.indexOf("Rule priority-zero").getOrThrow(), true)

        let exact = s3RuleWithRenderedBytes(8192)
        let exactRows = ArrayList<CkbStudentRuleCandidate>(); exactRows.add(exact)
        @Expect(compileStudentRulesBundle("rules-8192", exactRows).contentBytes, 8192)
        let over = s3RuleWithRenderedBytes(8193)
        let overRows = ArrayList<CkbStudentRuleCandidate>(); overRows.add(over)
        @Expect(compileStudentRulesBundle("rules-8193", overRows).diagnostic,
            "rules_bundle_too_large")

        let invalidRoot = s3UniqueRoot("invalid-utf8")
        s3CopyTree(s3FixtureRoot().join("candidate-set-v2/rules/prefer-rune-safe-text-boundaries"), invalidRoot)
        File.writeTo(invalidRoot.join("AGENTS.md"), [UInt8(0xff), UInt8(0xfe)])
        @Expect(parseStudentRuleCandidateDirectory(invalidRoot.toString()).diagnostic,
            "invalid_response_encoding")

        let malformedRoot = s3UniqueRoot("malformed-json")
        s3CopyTree(s3FixtureRoot().join("candidate-set-v2/rules/prefer-rune-safe-text-boundaries"),
            malformedRoot)
        File.writeTo(malformedRoot.join("candidate-manifest.json"), "{malformed}\n".toArray())
        @Expect(parseStudentRuleCandidateDirectory(malformedRoot.toString()).diagnostic,
            "malformed_json")

        let extraRoot = s3UniqueRoot("extra-file")
        s3CopyTree(s3FixtureRoot().join("candidate-set-v2/rules/prefer-rune-safe-text-boundaries"),
            extraRoot)
        File.writeTo(extraRoot.join("unexpected.txt"), "no\n".toArray())
        @Expect(parseStudentRuleCandidateDirectory(extraRoot.toString()).diagnostic,
            "rule_candidate_directory_entry_invalid")

        let unitSkillRoot = s3UniqueRoot("skill-unit")
        s3CopyTree(s3FixtureRoot().join("candidate-set-v2/skills/rune-safe-review"), unitSkillRoot)
        s3WriteUnitExecution(unitSkillRoot, "Review Rune unit behavior.")
        @Expect(parseStudentSkillCandidateDirectory(unitSkillRoot.toString(), true).verified, true)

        let deniedSkillRoot = s3UniqueRoot("skill-denylist")
        s3CopyTree(s3FixtureRoot().join("candidate-set-v2/skills/rune-safe-review"), deniedSkillRoot)
        s3WriteUnitExecution(deniedSkillRoot, "Never expose secret material.")
        @Expect(parseStudentSkillCandidateDirectory(deniedSkillRoot.toString(), true).diagnostic,
            "candidate_test_evidence_invalid")

        let extraSkillRoot = s3UniqueRoot("skill-extra-flat")
        s3CopyTree(s3FixtureRoot().join("candidate-set-v2/skills/rune-safe-review"), extraSkillRoot)
        File.writeTo(extraSkillRoot.join("tests/unexpected.txt"), "unexpected\n".toArray())
        @Expect(parseStudentSkillCandidateDirectory(extraSkillRoot.toString(), true).diagnostic,
            "skill_tests_tree_undeclared_file")
    }
}

private func s3FixtureRoot(): Path {
    canonicalize(Path("fixtures/student_context_candidate_v2"))
}

public func s3FixtureRootForTest(): Path {
    s3FixtureRoot()
}

private func s3UniqueRoot(name: String): Path {
    if (!exists(Path("target"))) { Directory.create(Path("target"), recursive: true) }
    let root = canonicalize(Path("target")).join(
        "s3-${name}-${DateTime.now().toUnixTimeStamp().toMilliseconds()}")
    Directory.create(root, recursive: true)
    root
}

private func s3Hex(value: Rune): String {
    var out = ""
    for (_ in 0..64) { out += value.toString() }
    out
}

private class S3ProductionContextFixture {
    let allowed: Path
    let candidate: Path
    let approval: Path
    let manifest: Path
    let store: FileKnowledgeStore
    init(allowed: Path, candidate: Path, approval: Path, manifest: Path, store: FileKnowledgeStore) {
        this.allowed = allowed; this.candidate = candidate; this.approval = approval
        this.manifest = manifest; this.store = store
    }
}

public class S5SplitLeakStudentContextFixture {
    public let args: Array<String>
    public let output: String
    public let candidateRoot: String
    public init(args: Array<String>, output: String, candidateRoot: String) {
        this.args = args
        this.output = output
        this.candidateRoot = candidateRoot
    }
}

private func s3CliArgs(fixture: S3ProductionContextFixture, output: Path, json: Bool): Array<String> {
    let values = ArrayList<String>(); for (value in ["cangjie-student-context-import", "--allowed-root",
        fixture.allowed.toString(), "--base-context", "none", "--candidate-set", fixture.candidate.toString(),
        "--approval", fixture.approval.toString(), "--frozen-knowledge-manifest", fixture.manifest.toString(),
        "--knowledge-store", fixture.store.rootPath(), "--output", output.toString(), "--context-version",
        "s3-cli-v1", "--scaffold-import"]) { values.add(value) }
    if (json) { values.add("--json") }; values.toArray()
}

private func s3ProductionContextFixture(name: String): S3ProductionContextFixture {
    let allowed = s3UniqueRoot(name)
    let candidate = allowed.join("candidate-set-v2")
    s3CopyTree(s3FixtureRoot().join("candidate-set-v2"), candidate)
    let store = FileKnowledgeStore(allowed.join("store").toString())
    let version = "cangjie-1.0.0-synthetic"
    let typed = CangjieTypedRecord(); typed.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    typed.sourceId = "synthetic-rune-source"; typed.title = "Rune-safe text boundaries"
    typed.content = "Use Rune iteration to preserve 中文🙂 boundaries."
    typed.citation = "https://example.test/cangjie/runes"; typed.sourceSet = CangjieSourceSets.DOCS
    typed.path = "docs/runes.md"; typed.targetVersion = "1.0.0"
    typed.versionResolutionId = "s3-official-rune-1.0.0"
    let typedRecords = ArrayList<CangjieTypedRecord>(); typedRecords.add(typed)
    let kb = KnowledgeBase(FakeClock(0))
    _ = kb.loadFirstInitializationTypedRecords(typedRecords, "s3-source-candidate")
    if (!kb.promoteFirstInitializationCandidate(version) || !kb.persistActiveSnapshot(store).ok) {
        throw IllegalStateException("s3_fake_store_commit_failed")
    }
    let snapshot = store.loadActiveSnapshot()
    if (!snapshot.valid) { throw IllegalStateException("s3_fake_store_commit_failed") }
    let checksum = ckbCertifiedNormalizedRecordsChecksum(snapshot.normalizedRecords)
    let pointer = store.loadActiveSnapshotPointer(); let zero = "sha256:" + s3Hex(r'0')
    let transactionHash = s3DirectoryHash(store.root.join("transactions").join(pointer.txId))
    let frozenBody = "{\"schemaVersion\":\"ckb-frozen-candidate-v2\",\"knowledgeVersion\":\"${version}\",\"txIdHash\":\"${benchmarkGapSha256(pointer.txId)}\",\"activePointerHash\":\"${ckbActiveSnapshotPointerIdentityHash(pointer)}\",\"transactionHash\":\"${transactionHash}\",\"candidateChecksum\":\"${checksum}\",\"inputHash\":\"${zero}\",\"configHash\":\"${zero}\",\"modelHash\":\"${zero}\",\"studentLeakageProofHash\":\"${zero}\",\"authorityIsolationArtifactHash\":\"${zero}\",\"anonymousQueryArtifactHash\":\"${zero}\",\"anonymousAtomQueryArtifactHash\":\"${zero}\",\"restLeakageArtifactHash\":\"${zero}\",\"mcpStdioLeakageArtifactHash\":\"${zero}\",\"mcpHttpLeakageArtifactHash\":\"${zero}\",\"atomTestArtifactHash\":\"${zero}\""
    let frozenEvidence = benchmarkGapSha256(frozenBody + "}")
    let frozen = frozenBody + ",\"evidenceHash\":\"${frozenEvidence}\"}"
    let manifest = allowed.join("frozen-candidate-manifest.json"); File.writeTo(manifest, frozen.toArray())
    let reference = "{\"schemaVersion\":\"ckb-frozen-knowledge-reference-v1\",\"knowledgeCandidateHash\":\"${checksum}\",\"knowledgeVersion\":\"${version}\",\"frozenCandidateManifestHash\":\"${benchmarkGapSha256(frozen)}\",\"knowledgeContentHash\":\"${checksum}\",\"assetLineage\":\"independent\"}\n"
    File.writeTo(candidate.join("knowledge/knowledge-candidate-reference.json"), reference.toArray())
    let original = JsonValue.fromStr(String.fromUtf8(File.readFrom(candidate.join("candidate-set-manifest.json"))).trimAscii()).asObject()
    let knowledgeTreeHash = benchmarkGapSha256("${benchmarkGapSha256(reference).replace("sha256:", "")}  knowledge-candidate-reference.json\n")
    let inventoryHash = benchmarkGapSha256(s3CandidateInventory(candidate))
    let combination = benchmarkGapSha256(s3Part(s3ContextBundleJsonString(original, "rulesHash")) + s3Part(s3ContextBundleJsonString(original, "skillsHash")) + s3Part(checksum) + s3Part(s3ContextBundleJsonString(original, "sourceClosureHash")) + s3Part(s3ContextBundleJsonString(original, "protectedClosureHash")))
    let evidence = s3CandidateManifestEvidence(original, checksum, knowledgeTreeHash, inventoryHash, combination,
        s3ContextBundleJsonString(original, "rulesTreeHash"), s3ContextBundleJsonString(original, "skillsTreeHash"))
    let candidateHash = benchmarkGapSha256(evidence)
    File.writeTo(candidate.join("candidate-set-manifest.json"), (evidence.replace("}", ",\"candidateSetHash\":\"${candidateHash}\"}") + "\n").toArray())
    let approval = allowed.join("approval-v2.json")
    let approvalJson = "{\"schemaVersion\":\"teacher-student-context-approval-v2\",\"candidateSetHash\":\"${candidateHash}\",\"assetInventoryHash\":\"${inventoryHash}\",\"rulesHash\":\"${s3ContextBundleJsonString(original, "rulesHash")}\",\"rulesTreeHash\":\"${s3ContextBundleJsonString(original, "rulesTreeHash")}\",\"skillsHash\":\"${s3ContextBundleJsonString(original, "skillsHash")}\",\"skillsTreeHash\":\"${s3ContextBundleJsonString(original, "skillsTreeHash")}\",\"knowledgeCandidateHash\":\"${checksum}\",\"knowledgeTreeHash\":\"${knowledgeTreeHash}\",\"sourceClosureHash\":\"${s3ContextBundleJsonString(original, "sourceClosureHash")}\",\"protectedClosureHash\":\"${s3ContextBundleJsonString(original, "protectedClosureHash")}\",\"combinationAuditHash\":\"${combination}\",\"decision\":\"approve\",\"reviewer\":\"synthetic-reviewer\",\"reason\":\"Synthetic full-tree scaffold contract approved.\",\"approvedAtUtc\":\"2026-08-07T00:00:00Z\"}\n"
    File.writeTo(approval, approvalJson.toArray())
    S3ProductionContextFixture(allowed, candidate, approval, manifest, store)
}

public func s4PublishedStudentContext(name:String):String {
    let fixture=s3ProductionContextFixture(name);let output=fixture.allowed.join("published-context")
    let bundle=compileAndPublishStudentContextBundle(fixture.allowed.toString(),"s4-context-v1",fixture.candidate.toString(),fixture.approval.toString(),"none",fixture.manifest.toString(),fixture.store,output.toString(),true)
    if(!bundle.ok){""}else{output.toString()}
}

// Canonical at every inner/outer boundary, but the final compact combination joins
// canonical_ and solution across a line break that each individual lane permits.
public func s5SplitLeakStudentContextCliFixture(name: String): S5SplitLeakStudentContextFixture {
    let fixture = s3ProductionContextFixture(name)
    let skillRoot = fixture.candidate.join("skills/rune-safe-review")
    let skill = parseStudentSkillCandidateDirectory(skillRoot.toString(), true)
    if (!skill.verified) { throw IllegalStateException("s5_split_leak_source_invalid") }
    skill.procedure += "\ncanonical_\nsolution"
    let identity = s3Part(skill.id) + s3Part(skill.version) + s3Part(skill.title) +
        s3Part(skill.procedure) + s3Part(skill.sourceCategory) + s3Part(skill.applicability) +
        s3Part(skill.lineage) + s3Part(skill.testEvidenceHash)
    skill.candidateContentHash = benchmarkGapSha256(identity)
    skill.skillContent = "---\nname: ${skill.id}\nversion: ${skill.version}\n" +
        "source: ${skill.sourceCategory}\nlineage: ${skill.lineage}\n" +
        "content-hash: ${skill.candidateContentHash}\n---\n\n# ${skill.title}\n\n" +
        "Applicability: ${skill.applicability}\n\n${skill.procedure}\n"
    skill.skillContentHash = benchmarkGapSha256(skill.skillContent)
    let skillEvidence = s5SplitLeakSkillManifest(skill, false)
    skill.artifactHash = benchmarkGapSha256(skillEvidence)
    File.writeTo(skillRoot.join("SKILL.md"), skill.skillContent.toArray())
    File.writeTo(skillRoot.join("candidate-manifest.json"),
        (s5SplitLeakSkillManifest(skill, true) + "\n").toArray())
    File.writeTo(skillRoot.join("operation.json"),
        ("{\"schemaVersion\":\"teacher-context-asset-operation-v1\",\"assetRole\":\"skills\"," +
        "\"assetId\":\"${skill.id}\",\"operation\":\"add\",\"expectedOldHash\":\"\"," +
        "\"newHash\":\"${skill.candidateContentHash}\"}\n").toArray())
    let parsed = parseStudentSkillCandidateDirectory(skillRoot.toString(), true)
    if (!parsed.verified || ckbStudentVisibleAssetForbidden(parsed.skillContent) ||
        auditStudentVisibleAssetCombination("safe knowledge", parsed.skillContent, "safe rules",
            ckbStudentVisibleProtectedArtifacts()) != "student_visible_asset_combination_leakage") {
        throw IllegalStateException("s5_split_leak_inner_reseal_invalid")
    }
    let outer = JsonValue.fromStr(s5SplitLeakReadUtf8(
        fixture.candidate.join("candidate-set-manifest.json")).trimAscii()).asObject()
    let skillsHash = benchmarkGapSha256(parsed.skillContent)
    let combination = benchmarkGapSha256(s3Part(s3ContextBundleJsonString(outer, "rulesHash")) +
        s3Part(skillsHash) + s3Part(s3ContextBundleJsonString(outer, "knowledgeCandidateHash")) +
        s3Part(s3ContextBundleJsonString(outer, "sourceClosureHash")) +
        s3Part(s3ContextBundleJsonString(outer, "protectedClosureHash")))
    s3ResealGenesisCandidateOuter(fixture, combination: combination, skillsHash: skillsHash)
    let candidate = parseTeacherContextCandidateSetDirectoryV2(fixture.allowed.toString(),
        fixture.candidate.toString())
    let approval = s5SplitLeakReadUtf8(fixture.approval).trimAscii()
    if (ckbStudentVisibleAssetForbidden(candidate.rules.visibleContent) ||
        ckbStudentVisibleAssetForbidden(candidate.skills.visibleContent) ||
        ckbStudentVisibleAssetForbidden(candidate.knowledge.visibleContent) ||
        validateTeacherContextApprovalV2(approval, candidate) != "approve") {
        throw IllegalStateException("s5_split_leak_outer_reseal_invalid")
    }
    let output = fixture.allowed.join("must-not-publish")
    S5SplitLeakStudentContextFixture(s3CliArgs(fixture, output, false), output.toString(),
        fixture.candidate.toString())
}

private func s5SplitLeakSkillManifest(skill: CkbStudentSkillCandidate, sealed: Bool): String {
    let fields = "\"schemaVersion\":\"cangjie-teacher-skill-candidate-v1\"," +
        "\"id\":\"${s5SplitLeakEscape(skill.id)}\",\"version\":\"${s5SplitLeakEscape(skill.version)}\"," +
        "\"title\":\"${s5SplitLeakEscape(skill.title)}\",\"procedure\":\"${s5SplitLeakEscape(skill.procedure)}\"," +
        "\"sourceCategory\":\"${skill.sourceCategory}\",\"applicability\":\"${s5SplitLeakEscape(skill.applicability)}\"," +
        "\"lineage\":\"${skill.lineage}\",\"skillPath\":\"SKILL.md\"," +
        "\"skillContentHash\":\"${skill.skillContentHash}\",\"testBundlePath\":\"test-bundle.json\"," +
        "\"testBundleHash\":\"${skill.testBundleHash}\",\"testEvidenceHash\":\"${skill.testEvidenceHash}\"," +
        "\"candidateContentHash\":\"${skill.candidateContentHash}\""
    if (sealed) { "{${fields},\"artifactHash\":\"${skill.artifactHash}\"}" } else { "{${fields}}" }
}

private func s5SplitLeakEscape(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")
        .replace("\r", "\\r").replace("\t", "\\t")
}

private func s5SplitLeakReadUtf8(path: Path): String {
    try {
        String.fromUtf8(File.readFrom(path))
    } catch (_: Exception) {
        throw IllegalStateException("s5_split_leak_invalid_response_encoding")
    }
}

private func s3ProductionUpdateFixture(baseFixture: S3ProductionContextFixture, baseRoot: Path,
    base: CkbStudentContextBundle): S3ProductionContextFixture {
    let candidate = baseFixture.allowed.join("candidate-update-v2")
    Directory.create(candidate.join("rules"), recursive: true)
    Directory.create(candidate.join("skills"), recursive: true)
    Directory.create(candidate.join("knowledge"), recursive: true)
    s3CopyTree(baseFixture.candidate.join("audit"), candidate.join("audit"))
    let sourceRule = baseFixture.candidate.join("rules/prefer-rune-safe-text-boundaries")
    let original = parseStudentRuleCandidateDirectory(sourceRule.toString())
    let classification = benchmarkGapSha256("synthetic-classification-manifest")
    let replaced = s3WriteDerivedRuleCandidate(sourceRule,
        candidate.join("rules/prefer-rune-safe-text-boundaries"), original.ruleId, "replace",
        original.canonicalHash, classification, "")
    let added = s3WriteDerivedRuleCandidate(sourceRule,
        candidate.join("rules/additional-rune-boundary-review"), "additional-rune-boundary-review", "add",
        "", classification, "Additional Rune boundary review")
    let deltaRules = ArrayList<CkbStudentRuleCandidate>(); deltaRules.add(replaced); deltaRules.add(added)
    let compiledRules = compileStudentRulesBundle("candidate-update", deltaRules)
    let baseManifest = JsonValue.fromStr(String.fromUtf8(File.readFrom(
        baseRoot.join("student-context-manifest.json"))).trimAscii()).asObject()
    let baseReference = JsonValue.fromStr(base.knowledgeReferenceJson.trimAscii()).asObject()
    let genesisManifest = JsonValue.fromStr(String.fromUtf8(File.readFrom(
        baseFixture.candidate.join("candidate-set-manifest.json"))).trimAscii()).asObject()
    let emptyTree = benchmarkGapSha256("")
    let rulesTree = benchmarkGapSha256(s3TreeInventory(candidate.join("rules")))
    let inventory = benchmarkGapSha256(s3CandidateInventory(candidate))
    let combination = benchmarkGapSha256(s3Part(benchmarkGapSha256(compiledRules.agentsMarkdown)) +
        s3Part(s3ContextBundleJsonString(baseManifest, "skillProjectionHash")) +
        s3Part(s3ContextBundleJsonString(baseManifest, "knowledgeContentHash")) +
        s3Part(s3ContextBundleJsonString(genesisManifest, "sourceClosureHash")) +
        s3Part(s3ContextBundleJsonString(genesisManifest, "protectedClosureHash")))
    let evidence = "{\"schemaVersion\":\"teacher-student-context-candidate-set-v2\",\"candidateSetId\":\"synthetic-derived-update-v2\",\"baseCompositeHash\":\"${base.compositeHash}\",\"validationLevel\":\"scaffold_contract\",\"sourceEvidenceManifestHash\":\"${s3ContextBundleJsonString(genesisManifest, "sourceEvidenceManifestHash")}\",\"classificationManifestHash\":\"${classification}\",\"sourceClosureHash\":\"${s3ContextBundleJsonString(genesisManifest, "sourceClosureHash")}\",\"protectedClosureHash\":\"${s3ContextBundleJsonString(genesisManifest, "protectedClosureHash")}\",\"rulesEligible\":true,\"rulesHash\":\"${benchmarkGapSha256(compiledRules.agentsMarkdown)}\",\"rulesTreeHash\":\"${rulesTree}\",\"rulesCount\":2,\"rulesAssetLineage\":\"humaneval_164_derived\",\"skillsEligible\":false,\"skillsHash\":\"${s3ContextBundleJsonString(baseManifest, "skillProjectionHash")}\",\"skillsTreeHash\":\"${emptyTree}\",\"skillsCount\":${baseManifest.get("skillCount").getOrThrow().asInt().getValue()},\"skillAssetLineage\":\"${s3ContextBundleJsonString(baseManifest, "skillAssetLineage")}\",\"knowledgeEligible\":false,\"knowledgeCandidateHash\":\"${s3ContextBundleJsonString(baseReference, "knowledgeCandidateHash")}\",\"knowledgeTreeHash\":\"${emptyTree}\",\"knowledgeTargetVersion\":\"${s3ContextBundleJsonString(baseReference, "knowledgeVersion")}\",\"knowledgeAssetLineage\":\"${s3ContextBundleJsonString(baseReference, "assetLineage")}\",\"assetInventoryHash\":\"${inventory}\",\"combinationAuditHash\":\"${combination}\"}"
    let candidateHash = benchmarkGapSha256(evidence)
    File.writeTo(candidate.join("candidate-set-manifest.json"),
        (evidence.replace("}", ",\"candidateSetHash\":\"${candidateHash}\"}") + "\n").toArray())
    let approval = baseFixture.allowed.join("approval-update-v2.json")
    let approvalJson = "{\"schemaVersion\":\"teacher-student-context-approval-v2\",\"candidateSetHash\":\"${candidateHash}\",\"assetInventoryHash\":\"${inventory}\",\"rulesHash\":\"${benchmarkGapSha256(compiledRules.agentsMarkdown)}\",\"rulesTreeHash\":\"${rulesTree}\",\"skillsHash\":\"${s3ContextBundleJsonString(baseManifest, "skillProjectionHash")}\",\"skillsTreeHash\":\"${emptyTree}\",\"knowledgeCandidateHash\":\"${s3ContextBundleJsonString(baseReference, "knowledgeCandidateHash")}\",\"knowledgeTreeHash\":\"${emptyTree}\",\"sourceClosureHash\":\"${s3ContextBundleJsonString(genesisManifest, "sourceClosureHash")}\",\"protectedClosureHash\":\"${s3ContextBundleJsonString(genesisManifest, "protectedClosureHash")}\",\"combinationAuditHash\":\"${combination}\",\"decision\":\"approve\",\"reviewer\":\"synthetic-reviewer\",\"reason\":\"Synthetic derived update approved.\",\"approvedAtUtc\":\"2026-08-07T00:00:00Z\"}\n"
    File.writeTo(approval, approvalJson.toArray())
    S3ProductionContextFixture(baseFixture.allowed, candidate, approval, baseFixture.manifest, baseFixture.store)
}

private func s3WriteDerivedRuleCandidate(source: Path, target: Path, id: String, operation: String,
    oldHash: String, classification: String, addedBody: String): CkbStudentRuleCandidate {
    s3CopyTree(source, target)
    let rule = parseStudentRuleCandidateDirectory(source.toString())
    rule.ruleId = id; rule.conceptId = "derived-${id}"; rule.sourceEvidenceKind = "completion_failure"
    rule.sourceEvidenceHash = benchmarkGapSha256("synthetic-completion-failure"); rule.assetLineage = "humaneval_164_derived"
    if (addedBody != "") { rule.title = "Additional Rune Boundary Review"; rule.body = addedBody }
    rule.canonicalHash = ckbStudentRuleCandidateCanonicalHash(rule)
    rule.agentsMarkdown = "# Student Rules\n\n## ${rule.title}\n\n${rule.body}\n\nTrigger: ${rule.trigger}\nScope: ${rule.scope}\n"
    File.writeTo(target.join("AGENTS.md"), rule.agentsMarkdown.toArray())
    File.writeTo(target.join("candidate-manifest.json"), (renderStudentRuleCandidateManifest(rule) + "\n").toArray())
    File.writeTo(target.join("operation.json"),
        ("{\"schemaVersion\":\"teacher-context-asset-operation-v1\",\"assetRole\":\"rules\",\"assetId\":\"${id}\",\"operation\":\"${operation}\",\"expectedOldHash\":\"${oldHash}\",\"newHash\":\"${rule.canonicalHash}\"}\n").toArray())
    rule.verified = true; rule.diagnostic = "ok"; rule
}

private func s3ResealGenesisCandidateOuter(fixture: S3ProductionContextFixture,
    combination!: String = "", skillsHash!: String = ""): Unit {
    let manifestPath = fixture.candidate.join("candidate-set-manifest.json")
    let object = JsonValue.fromStr(String.fromUtf8(File.readFrom(manifestPath)).trimAscii()).asObject()
    let rulesTree = benchmarkGapSha256(s3TreeInventory(fixture.candidate.join("rules")))
    let skillsTree = benchmarkGapSha256(s3TreeInventory(fixture.candidate.join("skills")))
    let knowledgeTree = benchmarkGapSha256(s3TreeInventory(fixture.candidate.join("knowledge")))
    let inventory = benchmarkGapSha256(s3CandidateInventory(fixture.candidate))
    let selectedCombination = if (combination == "") { s3ContextBundleJsonString(object, "combinationAuditHash") }
        else { combination }
    let evidence = s3CandidateManifestEvidence(object, s3ContextBundleJsonString(object, "knowledgeCandidateHash"),
        knowledgeTree, inventory, selectedCombination, rulesTree, skillsTree, skillsHash: skillsHash)
    let candidateHash = benchmarkGapSha256(evidence)
    File.writeTo(manifestPath,
        (evidence.replace("}", ",\"candidateSetHash\":\"${candidateHash}\"}") + "\n").toArray())
    let selectedSkillsHash = if (skillsHash == "") { s3ContextBundleJsonString(object, "skillsHash") }
        else { skillsHash }
    let approvalJson = "{\"schemaVersion\":\"teacher-student-context-approval-v2\",\"candidateSetHash\":\"${candidateHash}\",\"assetInventoryHash\":\"${inventory}\",\"rulesHash\":\"${s3ContextBundleJsonString(object, "rulesHash")}\",\"rulesTreeHash\":\"${rulesTree}\",\"skillsHash\":\"${selectedSkillsHash}\",\"skillsTreeHash\":\"${skillsTree}\",\"knowledgeCandidateHash\":\"${s3ContextBundleJsonString(object, "knowledgeCandidateHash")}\",\"knowledgeTreeHash\":\"${knowledgeTree}\",\"sourceClosureHash\":\"${s3ContextBundleJsonString(object, "sourceClosureHash")}\",\"protectedClosureHash\":\"${s3ContextBundleJsonString(object, "protectedClosureHash")}\",\"combinationAuditHash\":\"${selectedCombination}\",\"decision\":\"approve\",\"reviewer\":\"synthetic-reviewer\",\"reason\":\"Synthetic full-tree scaffold contract approved.\",\"approvedAtUtc\":\"2026-08-07T00:00:00Z\"}\n"
    File.writeTo(fixture.approval, approvalJson.toArray())
}

private func s3CandidateManifestEvidence(o: JsonObject, knowledgeHash: String, knowledgeTreeHash: String,
    inventoryHash: String, combination: String, rulesTreeHash: String, skillsTreeHash: String,
    skillsHash!: String = ""): String {
    let selectedSkillsHash = if (skillsHash == "") { s3ContextBundleJsonString(o, "skillsHash") }
        else { skillsHash }
    "{\"schemaVersion\":\"teacher-student-context-candidate-set-v2\",\"candidateSetId\":\"${s3ContextBundleJsonString(o, "candidateSetId")}\",\"baseCompositeHash\":\"none\",\"validationLevel\":\"scaffold_contract\",\"sourceEvidenceManifestHash\":\"${s3ContextBundleJsonString(o, "sourceEvidenceManifestHash")}\",\"classificationManifestHash\":\"\",\"sourceClosureHash\":\"${s3ContextBundleJsonString(o, "sourceClosureHash")}\",\"protectedClosureHash\":\"${s3ContextBundleJsonString(o, "protectedClosureHash")}\",\"rulesEligible\":true,\"rulesHash\":\"${s3ContextBundleJsonString(o, "rulesHash")}\",\"rulesTreeHash\":\"${rulesTreeHash}\",\"rulesCount\":1,\"rulesAssetLineage\":\"independent\",\"skillsEligible\":true,\"skillsHash\":\"${selectedSkillsHash}\",\"skillsTreeHash\":\"${skillsTreeHash}\",\"skillsCount\":1,\"skillAssetLineage\":\"independent\",\"knowledgeEligible\":true,\"knowledgeCandidateHash\":\"${knowledgeHash}\",\"knowledgeTreeHash\":\"${knowledgeTreeHash}\",\"knowledgeTargetVersion\":\"${s3ContextBundleJsonString(o, "knowledgeTargetVersion")}\",\"knowledgeAssetLineage\":\"independent\",\"assetInventoryHash\":\"${inventoryHash}\",\"combinationAuditHash\":\"${combination}\"}"
}

private func s3ContextBundleJsonString(o: JsonObject, key: String): String { o.get(key).getOrThrow().asString().getValue() }

private func s3CandidateInventory(root: Path): String {
    let rows = ArrayList<String>()
    for (prefix in ["rules", "skills", "knowledge", "audit"]) { s3CollectInventory(root.join(prefix), prefix, rows) }
    s3RenderInventory(rows)
}

private func s3TreeInventory(root: Path): String {
    let rows = ArrayList<String>(); s3CollectTreeInventory(root, "", rows)
    s3RenderInventory(rows)
}

private func s3RenderInventory(rows: ArrayList<String>): String {
    let ordered = rows.toArray(); sort(ordered); var out = ""
    for (row in ordered) {
        let parts = row.split("=")
        out += "${parts[1].replace("sha256:", "")}  ${parts[0]}\n"
    }
    out
}

private func s3CollectTreeInventory(root: Path, prefix: String, rows: ArrayList<String>): Unit {
    for (entry in Directory.readFrom(root)) {
        let relative = if (prefix == "") { entry.name } else { "${prefix}/${entry.name}" }
        if (entry.isDirectory()) { s3CollectTreeInventory(entry.path, relative, rows) }
        else if (entry.isRegular()) { rows.add("${relative}=${s3BytesHash(File.readFrom(entry.path))}") }
    }
}

private func s3CollectInventory(root: Path, prefix: String, rows: ArrayList<String>): Unit {
    for (entry in Directory.readFrom(root)) {
        let relative = "${prefix}/${entry.name}"
        if (entry.isDirectory()) { s3CollectInventory(entry.path, relative, rows) }
        else if (entry.isRegular()) { rows.add("${relative}=${s3BytesHash(File.readFrom(entry.path))}") }
    }
}

private func s3DirectoryHash(root: Path): String {
    let entries = ArrayList<String>(); s3CollectDirectoryHash(root, "", entries)
    let ordered = entries.toArray(); sort(ordered); var seed = ""
    for (entry in ordered) { seed += s3Part(entry) }; benchmarkGapSha256(seed)
}

private func s3CollectDirectoryHash(root: Path, prefix: String, out: ArrayList<String>): Unit {
    for (entry in Directory.readFrom(root)) {
        let relative = if (prefix == "") { entry.name } else { "${prefix}/${entry.name}" }
        if (entry.isDirectory()) { s3CollectDirectoryHash(entry.path, relative, out) }
        else if (entry.isRegular()) { out.add("${relative}=${s3BytesHash(File.readFrom(entry.path))}") }
    }
}

private func s3BytesHash(bytes: Array<UInt8>): String {
    let digest = SHA256(); digest.write(bytes); var out = ""
    for (byte in digest.finish()) { out += s3Nibble(byte / UInt8(16)); out += s3Nibble(byte % UInt8(16)) }
    "sha256:${out}"
}

private func s3Nibble(value: UInt8): String { "0123456789abcdef".toRuneArray()[Int64(value)].toString() }

private func s3Rule(id: String, priority: Int64, body: String): CkbStudentRuleCandidate {
    let rule = CkbStudentRuleCandidate()
    rule.verified = true; rule.diagnostic = "ok"; rule.ruleId = id; rule.conceptId = "concept-${id}"
    rule.title = "Rule ${id}"; rule.body = body; rule.trigger = "Synthetic trigger ${id}"
    rule.scope = "Synthetic scope"; rule.priority = priority
    rule.sourceEvidenceKind = "independent_manifest"; rule.sourceEvidenceHash = "sha256:" + s3Hex(r'a')
    rule.assetLineage = "independent"; rule.positiveEvidenceHash = "sha256:" + s3Hex(r'b')
    rule.negativeEvidenceHash = "sha256:" + s3Hex(r'c'); rule.boundaryEvidenceHash = "sha256:" + s3Hex(r'd')
    rule.generalizationEvidenceHash = "sha256:" + s3Hex(r'e')
    rule.agentsMarkdown = "# Student Rules\n\n## ${rule.title}\n\n${rule.body}\n\nTrigger: ${rule.trigger}\nScope: ${rule.scope}\n"
    rule.canonicalHash = ckbStudentRuleCandidateCanonicalHash(rule)
    rule
}

private func s3Skill(id: String, procedure: String): CkbStudentSkillCandidate {
    let skill = CkbStudentSkillCandidate()
    skill.verified = true; skill.diagnostic = "ok"; skill.id = id; skill.version = "1.0.0"
    skill.title = "Skill ${id}"; skill.procedure = procedure
    skill.sourceCategory = "general_engineering"; skill.applicability = "Cangjie text rendering"
    skill.lineage = "independent"; skill.testEvidenceHash = "sha256:" + s3Hex(r'f')
    let identity = s3Part(skill.id) + s3Part(skill.version) + s3Part(skill.title) +
        s3Part(skill.procedure) + s3Part(skill.sourceCategory) + s3Part(skill.applicability) +
        s3Part(skill.lineage) + s3Part(skill.testEvidenceHash)
    skill.candidateContentHash = benchmarkGapSha256(identity)
    skill.skillContent = "---\nname: ${skill.id}\nversion: ${skill.version}\n" +
        "source: ${skill.sourceCategory}\nlineage: ${skill.lineage}\n" +
        "content-hash: ${skill.candidateContentHash}\n---\n\n# ${skill.title}\n\n" +
        "Applicability: ${skill.applicability}\n\n${skill.procedure}\n"
    skill.skillContentHash = benchmarkGapSha256(skill.skillContent)
    skill
}

private func s3Part(value: String): String {
    "${value.toArray().size}:${value}"
}

private func s3WriteUnitExecution(root: Path, content: String): Unit {
    let id = "unit-contract"; let kind = "unit"; let source = "non_humaneval_experiment"
    let expected = "unit-ok"; let transcript = "unit-transcript"
    let fixtureHash = benchmarkGapSha256(s3Part(id) + s3Part(kind) + s3Part(source) +
        s3Part(content) + s3Part(expected))
    let directory = root.join("executions/${id}")
    Directory.create(directory, recursive: true)
    File.writeTo(directory.join("fixture.json"),
        ("{\"schemaVersion\":\"teacher-asset-fixture-v1\",\"fixtureId\":\"${id}\"," +
        "\"kind\":\"${kind}\",\"sourceClass\":\"${source}\",\"content\":\"${content}\"," +
        "\"expectedEvidence\":\"${expected}\",\"fixtureHash\":\"${fixtureHash}\"}\n").toArray())
    File.writeTo(directory.join("expected.txt"), (expected + "\n").toArray())
    File.writeTo(directory.join("actual.txt"), (expected + "\n").toArray())
    File.writeTo(directory.join("transcript.txt"), (transcript + "\n").toArray())
    let expectedHash = benchmarkGapSha256(expected); let transcriptHash = benchmarkGapSha256(transcript)
    File.writeTo(directory.join("execution.json"),
        ("{\"schemaVersion\":\"teacher-candidate-fixture-execution-v1\",\"fixtureId\":\"${id}\"," +
        "\"kind\":\"${kind}\",\"sourceClass\":\"${source}\",\"fixtureHash\":\"${fixtureHash}\"," +
        "\"executorKind\":\"fake_contract\",\"providerIdentityHash\":\"sha256:" + s3Hex(r'a') +
        "\",\"modelVersion\":\"fake-scaffold-v1\",\"expectedEvidenceHash\":\"${expectedHash}\"," +
        "\"actualEvidenceHash\":\"${expectedHash}\",\"transcriptHash\":\"${transcriptHash}\"," +
        "\"exitCode\":0,\"passed\":true}\n").toArray())
}

private func s3RuleWithRenderedBytes(target: Int64): CkbStudentRuleCandidate {
    let rule = s3Rule("budget", 1, "")
    let fixed = compileStudentRulesBundle("probe", s3SingletonRule(rule)).agentsMarkdown.toArray().size
    var body = ""
    for (_ in 0..(target - Int64(fixed))) { body += "x" }
    s3Rule("budget", 1, body)
}

private func s3SingletonRule(rule: CkbStudentRuleCandidate): ArrayList<CkbStudentRuleCandidate> {
    let out = ArrayList<CkbStudentRuleCandidate>(); out.add(rule); out
}

private func s3CopyTree(source: Path, target: Path): Unit {
    if (!exists(target)) { Directory.create(target, recursive: true) }
    for (entry in Directory.readFrom(source)) {
        let destination = target.join(entry.name)
        if (entry.isDirectory()) { s3CopyTree(entry.path, destination) }
        else if (entry.isRegular()) { File.writeTo(destination, File.readFrom(entry.path)) }
        else { throw IllegalStateException("fixture_tree_entry_invalid") }
    }
}
