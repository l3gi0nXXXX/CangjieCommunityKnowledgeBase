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

    // S3-UT-01 / S3-POS-01 / E2E-03
    @TestCase
    public func derivedFrozenReferenceIsCanonicalImmutableAndImporterVerified(): Unit {
        let fixture=s3DerivedReferenceFixture("derived-reference-positive")
        let first=ckbWriteDerivedFrozenKnowledgeReference(fixture.context.store,fixture.options)
        @Expect(first.ok,true);@Expect(first.diagnostic,"ok")
        @Expect(first.knowledgeCandidateHash,fixture.candidateHash)
        let disk=String.fromUtf8(File.readFrom(Path(fixture.options.outputPath)))
        @Expect(disk,first.referenceJson+"\n")
        @Expect(JsonValue.fromStr(first.referenceJson).asObject().getFields().size,6)
        @Expect(first.referenceJson.contains("\"assetLineage\":\"humaneval_164_derived\""),true)
        @Expect(validateFrozenStudentKnowledgeReference(fixture.context.allowed.toString(),
            first.referenceJson,fixture.context.manifest.toString(),fixture.context.store),"ok")
        let replay=ckbWriteDerivedFrozenKnowledgeReference(fixture.context.store,fixture.options)
        @Expect(replay.ok,true);@Expect(replay.referenceHash,first.referenceHash)
        @Expect(runFrozenKnowledgeReferenceWriteCli(s3DerivedReferenceCliArgs(fixture,true)),0)
    }

    // S3-BND-01
    @TestCase
    public func derivedFrozenReferencePreservesUnicodeAndRejectsInvalidUtf8AndMultipleAtoms(): Unit {
        let fixture=s3DerivedReferenceFixture("derived-reference-boundary")
        let valid=ckbWriteDerivedFrozenKnowledgeReference(fixture.context.store,fixture.options)
        @Expect(valid.ok,true)
        @Expect(String.fromUtf8(File.readFrom(Path(fixture.options.selectedAtomsPath))).contains("中文😀"),true)

        let invalid=s3DerivedReferenceFixture("derived-reference-invalid-utf8")
        File.writeTo(Path(invalid.options.selectionProofPath),[UInt8(255),UInt8(254)])
        @Expect(ckbWriteDerivedFrozenKnowledgeReference(invalid.context.store,invalid.options).diagnostic,
            "invalid_response_encoding")
        @Expect(exists(Path(invalid.options.outputPath)),false)

        let multiple=s3DerivedReferenceFixture("derived-reference-multiple")
        let selected=String.fromUtf8(File.readFrom(Path(multiple.options.selectedAtomsPath)))
        File.writeTo(Path(multiple.options.selectedAtomsPath),(selected+selected).toArray())
        @Expect(ckbWriteDerivedFrozenKnowledgeReference(multiple.context.store,multiple.options).diagnostic,
            "selected_atoms_count_invalid")
        @Expect(exists(Path(multiple.options.outputPath)),false)
    }

    // S3-NEG-01
    @TestCase
    public func derivedFrozenReferenceFailsClosedOnEvidenceStoreAndOutputTamper(): Unit {
        let proof=s3DerivedReferenceFixture("derived-reference-proof-tamper")
        let proofText=String.fromUtf8(File.readFrom(Path(proof.options.selectionProofPath)))
        File.writeTo(Path(proof.options.selectionProofPath),proofText.replace("\"selected\":1","\"selected\":2").toArray())
        @Expect(ckbWriteDerivedFrozenKnowledgeReference(proof.context.store,proof.options).diagnostic,
            "selected_atoms_proof_invalid")
        @Expect(exists(Path(proof.options.outputPath)),false)

        let manifest=s3DerivedReferenceFixture("derived-reference-manifest-tamper")
        let manifestText=String.fromUtf8(File.readFrom(Path(manifest.options.frozenManifestPath)))
        File.writeTo(Path(manifest.options.frozenManifestPath),manifestText.replace("\"modelHash\":","\"extra\":true,\"modelHash\":").toArray())
        @Expect(ckbWriteDerivedFrozenKnowledgeReference(manifest.context.store,manifest.options).diagnostic,
            "frozen_candidate_manifest_invalid")
        @Expect(exists(Path(manifest.options.outputPath)),false)

        let pointer=s3DerivedReferenceFixture("derived-reference-pointer-tamper")
        File.writeTo(Path(pointer.context.store.rootPath()).join("metadata/active-snapshot.manifest"),
            "schema=ckb-active-pointer-v2\ntxId=stale\nactive=stale-version\n".toArray())
        @Expect(ckbWriteDerivedFrozenKnowledgeReference(pointer.context.store,pointer.options).diagnostic,
            "frozen_candidate_manifest_invalid")
        @Expect(exists(Path(pointer.options.outputPath)),false)

        let conflict=s3DerivedReferenceFixture("derived-reference-output-conflict")
        File.writeTo(Path(conflict.options.outputPath),"owner-content\n".toArray())
        @Expect(ckbWriteDerivedFrozenKnowledgeReference(conflict.context.store,conflict.options).diagnostic,
            "frozen_knowledge_reference_output_conflict")
        @Expect(String.fromUtf8(File.readFrom(Path(conflict.options.outputPath))),"owner-content\n")

        let escape=s3DerivedReferenceFixture("derived-reference-path-escape")
        escape.options.outputPath=escape.context.allowed.parent.join("escaped-reference.json").toString()
        @Expect(ckbWriteDerivedFrozenKnowledgeReference(escape.context.store,escape.options).diagnostic,
            "artifact_path_outside_allowed_root")

        let linked=s3DerivedReferenceFixture("derived-reference-symlink")
        let outside=linked.context.allowed.parent.join("outside-selected-atoms.jsonl")
        File.writeTo(outside,String.fromUtf8(File.readFrom(Path(linked.options.selectedAtomsPath))).toArray())
        @Expect(launch("/bin/rm",["-f",linked.options.selectedAtomsPath]).wait(),0)
        @Expect(launch("/bin/ln",["-s",outside.toString(),linked.options.selectedAtomsPath]).wait(),0)
        @Expect(ckbWriteDerivedFrozenKnowledgeReference(linked.context.store,linked.options).diagnostic,
            "artifact_path_outside_allowed_root")

        let partial=s3DerivedReferenceFixture("derived-reference-partial")
        let built=ckbWriteDerivedFrozenKnowledgeReference(partial.context.store,partial.options)
        @Expect(built.ok,true)
        @Expect(launch("/bin/rm",["-f",partial.options.outputPath]).wait(),0)
        let stage=Path("${partial.options.outputPath}.tmp-${built.referenceHash.replace("sha256:","")}")
        File.writeTo(stage,"owner\n".toArray())
        @Expect(ckbWriteDerivedFrozenKnowledgeReference(partial.context.store,partial.options).diagnostic,
            "frozen_knowledge_reference_partial_publish_blocked")
        @Expect(exists(Path(partial.options.outputPath)),false)
        @Expect(String.fromUtf8(File.readFrom(stage)),"owner\n")
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

    // RBM-C-P01: a rules lane above the former limit imports, publishes and reopens canonically.
    @TestCase
    public func expandedStudentRulesPublishAndReadBackCanonically(): Unit {
        let fixture = s3ProductionContextFixture("expanded-rules-publish")
        s3ExpandGenesisRules(fixture, 12557)
        let output = fixture.allowed.join("expanded-rules-context")
        let published = compileAndPublishStudentContextBundle(fixture.allowed.toString(),
            "expanded-rules-v1", fixture.candidate.toString(), fixture.approval.toString(), "none",
            fixture.manifest.toString(), fixture.store, output.toString(), true)
        @Expect(published.ok, true)
        @Expect(published.agentsMarkdown.toArray().size, 12557)
        let reopened = readStudentContextBundleV2(output.toString())
        @Expect(reopened.ok, true)
        @Expect(reopened.rulesBytes, 12557)
        @Expect(reopened.rulesHash, benchmarkGapSha256(published.agentsMarkdown))
        @Expect(reopened.agentsMarkdown, published.agentsMarkdown)
        @Expect(reopened.rulesJson, published.rulesJson)

        let assets = CkbS4FrozenContextAssets()
        assets.protocol = "One completion only.\n"; assets.rules = reopened.agentsMarkdown
        assets.skill = reopened.skillsPrompt; assets.knowledge = "Verified frozen knowledge."
        assets.providerCapability = "Verified provider capability."
        assets.publicTask = "Implement a public synthetic task."
        assets.compositeHash = reopened.compositeHash; assets.combinationAuditHash = reopened.combinationAuditHash
        let finalPrompt = renderCkbS4CompletionPrompt(assets)
        let capabilityEvidence = "{\"schemaVersion\":\"ckb-provider-prompt-capability-v1\"," +
            "\"modelVersion\":\"synthetic-model\",\"maxContextTokens\":200000," +
            "\"reservedOutputTokens\":1000,\"sourceEvidence\":\"synthetic-test\"," +
            "\"observedAtUtc\":\"2026-09-01T00:00:00Z\"}"
        let capability = capabilityEvidence.replace("}",
            ",\"capabilityHash\":\"${benchmarkGapSha256(capabilityEvidence)}\"}")
        let capabilityPath = fixture.allowed.join("provider-prompt-capability.json")
        File.writeTo(capabilityPath, (capability + "\n").toArray())
        let promptOptions = CkbAbcdeRunnerOptions()
        promptOptions.providerPromptCapabilityPath = capabilityPath.toString()
        promptOptions.providerPromptCapabilityHash = benchmarkGapSha256(capability + "\n")
        promptOptions.expectedModelVersion = "synthetic-model"
        promptOptions.effectivePromptByteBudget = 188416
        @Expect(ckbAbcdeProviderPromptGate(promptOptions, finalPrompt), "ok")
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
        @Expect(updated.diagnostic, "ok")
        @Expect(updated.ok, true)
        @Expect(updated.agentsMarkdown.contains("Additional Rune boundary review"), true)
        @Expect(updated.skillsPrompt, base.skillsPrompt)
        @Expect(updated.knowledgeReferenceJson, base.knowledgeReferenceJson)
        @Expect(readStudentContextBundleV2(updatedOutput.toString()).ok, true)
        let tamperedUpdate = s3ProductionUpdateFixture(fixture, baseOutput, base,
            combinationOverride: "sha256:" + s3Hex(r'0'))
        let blocked = compileStudentContextBundleScaffoldWithBase(fixture.allowed.toString(),
            "s3-update-combination-tamper", tamperedUpdate.candidate.toString(),
            tamperedUpdate.approval.toString(), baseOutput.toString(), tamperedUpdate.manifest.toString(),
            tamperedUpdate.store)
        @Expect(blocked.diagnostic, "candidate_set_hash_mismatch")
    }

    // S3-NEG
    @TestCase
    public func studentVisibleAssetCombinationFailsClosed(): Unit {
        let protected = ["canonical_solution"]
        @Expect(auditStudentVisibleAssetCombination("safe inherited knowledge", "safe active skill",
            "safe active rule", protected), "ok")
        @Expect(auditStudentVisibleAssetCombination(
            "Official examples may discuss /home/ paths, password policies, and expected output. ",
            "safe active skill", "safe active rule", ckbStudentVisibleProtectedArtifacts()), "ok")
        @Expect(auditStudentVisibleAssetCombination("canonical_solution", "safe active skill",
            "safe active rule", protected), "student_visible_asset_combination_leakage")
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

    @TestCase
    public func derivedSkillContextImportKeepsInternalLineageOutOfVisiblePrompt(): Unit {
        let fixture=s3ProductionContextFixture("derived-skill-cli")
        let baseRoot=fixture.allowed.join("base-context")
        let base=compileAndPublishStudentContextBundle(fixture.allowed.toString(),"derived-base-v1",
            fixture.candidate.toString(),fixture.approval.toString(),"none",fixture.manifest.toString(),
            fixture.store,baseRoot.toString(),true)
        @Expect(base.ok,true)
        let update=s3ProductionSkillUpdateFixture(fixture,baseRoot,base)
        let output=fixture.allowed.join("derived-context")
        @Expect(runStudentContextImportCli(s3UpdateCliArgs(update,baseRoot,output)),0)
        let published=readStudentContextBundleV2(output.toString())
        @Expect(published.ok,true)
        @Expect(published.skillsLineage,"humaneval_164_derived")
        @Expect(published.skillsPrompt.contains("lineage: teacher_derived\n"),true)
        @Expect(published.skillsPrompt.toAsciiLower().contains("humaneval"),false)
        @Expect(cangjieStudentVisibleTextDiagnostic("derivedSkillPrompt",published.skillsPrompt).ok,true)
        @Expect(published.skillsJson.contains("\"lineage\":\"humaneval_164_derived\""),true)
        let manifest=JsonValue.fromStr(published.manifestJson.trimAscii()).asObject()
        @Expect(s3ContextBundleJsonString(manifest,"aggregateAssetLineage"),
            "humaneval_164_derived")
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

    @TestCase
    public func studentValidationTranscriptBindsIdentityModelAndEnvelope(): Unit {
        let binding = s3ValidationBinding()
        @Expect(ckbStudentValidationExecutionBindingDiagnostic(binding.fixture.toArray(), binding.actual.toArray(),
            binding.transcript.toArray(), binding.execution.toArray(), binding.lane, binding.candidateVisibleHash,
            binding.baseCompositeHash, binding.validationIdentityHash, binding.modelVersion), "ok")

        let otherIdentity = "sha256:" + s3Hex(r'c')
        @Expect(ckbStudentValidationExecutionBindingDiagnostic(binding.fixture.toArray(), binding.actual.toArray(),
            binding.transcript.toArray(), binding.execution.replace(binding.validationIdentityHash, otherIdentity).toArray(),
            binding.lane, binding.candidateVisibleHash, binding.baseCompositeHash, binding.validationIdentityHash,
            binding.modelVersion), "candidate_test_evidence_invalid")
        @Expect(ckbStudentValidationExecutionBindingDiagnostic(binding.fixture.toArray(), binding.actual.toArray(),
            binding.transcript.toArray(), binding.execution.replace(binding.modelVersion, "drifted-model").toArray(),
            binding.lane, binding.candidateVisibleHash, binding.baseCompositeHash, binding.validationIdentityHash,
            binding.modelVersion), "candidate_test_evidence_invalid")

        let driftedTranscript = binding.transcript.replace(binding.requestHash, "sha256:" + s3Hex(r'd'))
        let driftedExecution = binding.execution.replace(benchmarkGapSha256(binding.transcript.trimAscii()),
            benchmarkGapSha256(driftedTranscript.trimAscii()))
        @Expect(ckbStudentValidationExecutionBindingDiagnostic(binding.fixture.toArray(), binding.actual.toArray(),
            driftedTranscript.toArray(), driftedExecution.toArray(), binding.lane, binding.candidateVisibleHash,
            binding.baseCompositeHash, binding.validationIdentityHash, binding.modelVersion),
            "candidate_test_evidence_invalid")
    }

    @TestCase
    public func strictStudentValidationBindingRejectsFrozenControlTamper(): Unit {
        let root=s3UniqueRoot("r6-strict-student-binding")
        let runtime=root.join("provider-runtime");File.writeTo(runtime,"runtime bytes 中文🙂\n".toArray())
        let runtimeEvidence="{\"runtime\":\"frozen 中文🙂\"}\n"
        let sampling="{\"schemaVersion\":\"ckb-completion-sampling-capability-v1\",\"samplingControl\":\"provider_default_not_client_exposed\"}\n"
        let capability="{\"schemaVersion\":\"ckb-provider-prompt-capability-v1\",\"capability\":\"strict fixture 中文🙂\"}\n"
        let model="GLM-5.2";let claude="claude-code-1.0";let transport=CkbAbcdeGroups.D
        let completion="{\"schemaVersion\":\"ckb-student-completion-control-v1\","+
            "\"certificationTransport\":\"${transport}\",\"generationProtocol\":\"completion-only-v1\","+
            "\"samplesPerCase\":1,\"outputSchemaHash\":\"${benchmarkGapSha256(ckbAbcdeCompletionOutputSchema())}\","+
            "\"samplingCapabilityHash\":\"${benchmarkGapSha256(sampling)}\",\"effectivePromptByteBudget\":188416,"+
            "\"transportRetryBudget\":2,\"modelTimeoutSeconds\":30,"+
            "\"runtimeConfigHash\":\"${benchmarkGapSha256(runtimeEvidence)}\","+
            "\"completionCommandHash\":\"${ckbStudentCompletionCommandHash(model)}\"}\n"
        let completionHash=benchmarkGapSha256(completion);let capabilityHash=benchmarkGapSha256(capability)
        let provider="{\"schemaVersion\":\"ckb-student-validation-provider-identity-v1\","+
            "\"provider\":\"strict-fixture\",\"model\":\"${model}\",\"claudeCodeVersion\":\"${claude}\","+
            "\"runtimeExecutableHash\":\"${ckbAbcdeBinaryHash(runtime.toString())}\","+
            "\"completionControlHash\":\"${completionHash}\","+
            "\"providerPromptCapabilityHash\":\"${capabilityHash}\"}\n"
        let providerHash=benchmarkGapSha256(provider)
        let context=s4PublishedStudentValidatedContext("strict-binding",providerHash,model)
        s3CopyTree(Path(context.contextRoot),root.join("student-context"))
        s3CopyTree(Path(context.candidateRoot),root.join("student-context-candidate"))
        File.writeTo(root.join("completion-control.json"),completion.toArray())
        File.writeTo(root.join("completion-runtime-config.json"),runtimeEvidence.toArray())
        File.writeTo(root.join("completion-sampling-capability.json"),sampling.toArray())
        File.writeTo(root.join("provider-prompt-capability.json"),capability.toArray())
        let manifest="{\"studentContextCandidateSetHash\":\"${context.candidateSetHash}\","+
            "\"completionControlHash\":\"${completionHash}\",\"providerPromptCapabilityHash\":\"${capabilityHash}\","+
            "\"providerRuntimeExecutablePath\":\"${runtime}\",\"modelVersion\":\"${model}\","+
            "\"claudeCodeVersion\":\"${claude}\",\"providerIdentityHash\":\"${providerHash}\","+
            "\"samplingCapabilityHash\":\"${benchmarkGapSha256(sampling)}\","+
            "\"certificationTransport\":\"${transport}\",\"generationProtocol\":\"completion-only-v1\","+
            "\"samplesPerCase\":1,\"outputSchemaHash\":\"${benchmarkGapSha256(ckbAbcdeCompletionOutputSchema())}\","+
            "\"effectivePromptByteBudget\":188416,\"transportRetryBudget\":2,\"modelTimeoutSeconds\":30}"
        @Expect(ckbStrictStudentValidationBindingDiagnostic(root.toString(),manifest,provider),"ok")
        File.writeTo(root.join("completion-control.json"),completion.replace("\"samplesPerCase\":1",
            "\"samplesPerCase\":2").toArray())
        @Expect(ckbStrictStudentValidationBindingDiagnostic(root.toString(),manifest,provider),
            "student_completion_control_invalid")
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
        @Expect(compileStudentRulesBundle("rules-8193", overRows).contentBytes, 8193)
        let expanded = s3RuleWithRenderedBytes(12557)
        let expandedRows = ArrayList<CkbStudentRuleCandidate>(); expandedRows.add(expanded)
        @Expect(compileStudentRulesBundle("rules-12557", expandedRows).contentBytes, 12557)

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

private class S3DerivedReferenceFixture {
    let context:S3ProductionContextFixture
    let options:CkbFrozenKnowledgeReferenceWriteOptions
    let candidateHash:String
    init(context:S3ProductionContextFixture,options:CkbFrozenKnowledgeReferenceWriteOptions,
        candidateHash:String){this.context=context;this.options=options;this.candidateHash=candidateHash}
}

private func s3DerivedReferenceFixture(name:String):S3DerivedReferenceFixture {
    let context=s3ProductionContextFixture(name);let root=context.allowed
    let marker="sha256:"+s3Hex(r'0')
    let rawBundle="{\"atomId\":\"scaffold-abi-contract\",\"knowledgeFamily\":\"syntax\",\"sourceClass\":\"official\",\"citation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/\",\"targetVersion\":\"cangjie-language-1.0.0\",\"candidateHash\":\"${marker}\",\"knowledgeText\":\"Inspect the public scaffold ABI before coding 中文😀.\",\"example\":\"Use declared collection properties and tagged-class fields.\",\"extractor\":{\"provider\":\"fixture\",\"model\":\"offline\",\"exitCode\":0,\"transcriptHash\":\"${benchmarkGapSha256("public-transcript")}\"},\"purificationPassed\":true,\"tests\":[{\"category\":\"positive\",\"operation\":\"arraylist_size\",\"input\":\"[1,2,3]\",\"expected\":\"3\"},{\"category\":\"negative\",\"operation\":\"contains\",\"input\":\"class\",\"needle\":\"enum\",\"expected\":\"false\"},{\"category\":\"boundary\",\"operation\":\"rune_count\",\"input\":\"中文😀\",\"expected\":\"3\"}],\"execution\":{\"total\":3,\"passed\":3,\"failed\":0,\"status\":\"passed\",\"commandEvidence\":\"public\",\"commandEvidenceHash\":\"${benchmarkGapSha256("public")}\"}}"
    let candidateHash=cangjieKnowledgeAtomCandidateHash(rawBundle)
    let bundle=rawBundle.replace(marker,candidateHash)
    let input=CangjieBenchmarkGapInput();input.schemaVersion="ckb-benchmark-gap-v1";input.datasetVersion="cangjie-humaneval-164-sha256:${s3Hex(r'a')}"
    input.teacherRunId="public-s3-run";input.evidence="public scaffold ABI evidence";input.evidenceHash=benchmarkGapSha256(input.evidence)
    input.candidatePath="candidate-knowledge/ckb-benchmark-gap.jsonl";input.revision=1;input.attempt=1;input.failureTaxonomy="knowledge_gap"
    input.knowledgeGapConfirmations=2;input.caseId="PUBLIC-S3";input.benchmark="public-cangjie-regression"
    input.taskText="Implement against a public Cangjie scaffold.";input.visibleTestExcerpt="public fixture"
    input.compilerOutput="public compiler diagnostic";input.missingKnowledge="G-ARRAYLIST"
    input.interfaceId="KI-02";input.contentFamily="KC-02";input.updateMechanism="KU-11"
    input.targetVersion="cangjie-language-1.0.0";input.officialCitation="https://docs.cangjie-lang.cn/docs/1.0.0/"
    input.knowledgeAtomCandidate=true;input.knowledgeAtomTestBundle=bundle
    input.candidateHash=canonicalBenchmarkGapCandidateHash(input)
    let selected="{\"schemaVersion\":\"${input.schemaVersion}\",\"datasetVersion\":\"${input.datasetVersion}\",\"teacherRunId\":\"${input.teacherRunId}\",\"evidenceHash\":\"${input.evidenceHash}\",\"evidence\":\"${input.evidence}\",\"candidateHash\":\"${input.candidateHash}\",\"candidatePath\":\"${input.candidatePath}\",\"revision\":1,\"attempt\":1,\"failureTaxonomy\":\"knowledge_gap\",\"knowledgeGapConfirmations\":2,\"caseId\":\"PUBLIC-S3\",\"benchmark\":\"public-cangjie-regression\",\"taskText\":\"Implement against a public Cangjie scaffold.\",\"visibleTestExcerpt\":\"public fixture\",\"compilerOutput\":\"public compiler diagnostic\",\"missingKnowledge\":\"G-ARRAYLIST\",\"interfaceId\":\"KI-02\",\"contentFamily\":\"KC-02\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"cangjie-language-1.0.0\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/\",\"knowledgeAtomTestBundle\":${bundle},\"knowledgeAtomCandidate\":true}\n"
    let selectedPath=root.join("selected-atoms.jsonl");File.writeTo(selectedPath,selected.toArray())
    let proofBody="{\"schemaVersion\":\"ckb-atom-selection-proof-v2\",\"inputRows\":1,\"selected\":1,\"manifestHash\":\"${benchmarkGapSha256("manifest")}\",\"aggregateHash\":\"${benchmarkGapSha256(selected)}\",\"selectionSetHash\":\"${benchmarkGapSha256("selection-set")}\",\"schemaMigrations\":[]"
    let proof=proofBody+",\"evidenceHash\":\"${benchmarkGapSha256(proofBody+"}")}\"}"
    let proofPath=root.join("selection-proof.json");File.writeTo(proofPath,proof.toArray())
    let evidence="scaffold-abi-contract|${candidateHash}|${benchmarkGapSha256(bundle)}"
    let atomBody="{\"ok\":true,\"diagnostic\":\"validated\",\"bundleCount\":1,\"testCount\":3,\"passed\":3,\"failed\":0,\"selectedAtomsHash\":\"${benchmarkGapSha256(selected)}\",\"bundleEvidenceHash\":\"${benchmarkGapSha256("${evidence.toArray().size}:${evidence}")}\""
    let atomSummary=atomBody+",\"evidenceHash\":\"${benchmarkGapSha256(atomBody+"}")}\"}\n"
    let atomPath=root.join("atom-test-summary.json");File.writeTo(atomPath,atomSummary.toArray())
    let original=String.fromUtf8(File.readFrom(context.manifest));let object=JsonValue.fromStr(original).asObject()
    let oldHash=object.get("atomTestArtifactHash").getOrThrow().asString().getValue()
    let updated=original.replace("\"atomTestArtifactHash\":\"${oldHash}\"","\"atomTestArtifactHash\":\"${benchmarkGapSha256(atomSummary)}\"")
    let parts=updated.split(",\"evidenceHash\":");let body=parts[0]
    let resealed=body+",\"evidenceHash\":\"${benchmarkGapSha256(body+"}")}\"}"
    File.writeTo(context.manifest,resealed.toArray())
    let options=CkbFrozenKnowledgeReferenceWriteOptions();options.allowedRoot=root.toString()
    options.selectedAtomsPath=selectedPath.toString();options.selectionProofPath=proofPath.toString()
    options.atomTestSummaryPath=atomPath.toString();options.frozenManifestPath=context.manifest.toString()
    options.outputPath=root.join("derived-reference.json").toString()
    S3DerivedReferenceFixture(context,options,candidateHash)
}

private func s3DerivedReferenceCliArgs(fixture:S3DerivedReferenceFixture,json:Bool):Array<String>{
    let values=ArrayList<String>();for(value in ["cangjie-frozen-knowledge-reference-write","--allowed-root",
        fixture.options.allowedRoot,"--selected-atoms",fixture.options.selectedAtomsPath,"--selection-proof",
        fixture.options.selectionProofPath,"--atom-test-summary",fixture.options.atomTestSummaryPath,
        "--frozen-candidate-manifest",fixture.options.frozenManifestPath,"--store",fixture.context.store.rootPath(),
        "--output",fixture.options.outputPath]){values.add(value)};if(json){values.add("--json")};values.toArray()
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

public class S4StudentValidatedContextFixture {
    public let contextRoot: String
    public let candidateRoot: String
    public let candidateSetHash: String
    public init(contextRoot: String, candidateRoot: String, candidateSetHash: String) {
        this.contextRoot = contextRoot
        this.candidateRoot = candidateRoot
        this.candidateSetHash = candidateSetHash
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

private func s3UpdateCliArgs(fixture:S3ProductionContextFixture,base:Path,output:Path):Array<String>{
    ["cangjie-student-context-import","--allowed-root",fixture.allowed.toString(),
        "--base-context",base.toString(),"--candidate-set",fixture.candidate.toString(),
        "--approval",fixture.approval.toString(),"--frozen-knowledge-manifest",
        fixture.manifest.toString(),"--knowledge-store",fixture.store.rootPath(),"--output",
        output.toString(),"--context-version","derived-skill-v2","--scaffold-import"]
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
    let knowledgeCandidateHash = benchmarkGapSha256("candidate:" + checksum)
    let pointer = store.loadActiveSnapshotPointer(); let zero = "sha256:" + s3Hex(r'0')
    let transactionHash = s3DirectoryHash(store.root.join("transactions").join(pointer.txId))
    let frozenBody = "{\"schemaVersion\":\"ckb-frozen-candidate-v2\",\"knowledgeVersion\":\"${version}\",\"txIdHash\":\"${benchmarkGapSha256(pointer.txId)}\",\"activePointerHash\":\"${ckbActiveSnapshotPointerIdentityHash(pointer)}\",\"transactionHash\":\"${transactionHash}\",\"candidateChecksum\":\"${checksum}\",\"inputHash\":\"${zero}\",\"configHash\":\"${zero}\",\"modelHash\":\"${zero}\",\"studentLeakageProofHash\":\"${zero}\",\"authorityIsolationArtifactHash\":\"${zero}\",\"anonymousQueryArtifactHash\":\"${zero}\",\"anonymousAtomQueryArtifactHash\":\"${zero}\",\"restLeakageArtifactHash\":\"${zero}\",\"mcpStdioLeakageArtifactHash\":\"${zero}\",\"mcpHttpLeakageArtifactHash\":\"${zero}\",\"atomTestArtifactHash\":\"${zero}\""
    let frozenEvidence = benchmarkGapSha256(frozenBody + "}")
    let frozen = frozenBody + ",\"evidenceHash\":\"${frozenEvidence}\"}"
    let manifest = allowed.join("frozen-candidate-manifest.json"); File.writeTo(manifest, frozen.toArray())
    let reference = "{\"schemaVersion\":\"ckb-frozen-knowledge-reference-v1\",\"knowledgeCandidateHash\":\"${knowledgeCandidateHash}\",\"knowledgeVersion\":\"${version}\",\"frozenCandidateManifestHash\":\"${benchmarkGapSha256(frozen)}\",\"knowledgeContentHash\":\"${checksum}\",\"assetLineage\":\"independent\"}\n"
    File.writeTo(candidate.join("knowledge/knowledge-candidate-reference.json"), reference.toArray())
    let original = JsonValue.fromStr(String.fromUtf8(File.readFrom(candidate.join("candidate-set-manifest.json"))).trimAscii()).asObject()
    let knowledgeTreeHash = benchmarkGapSha256("${benchmarkGapSha256(reference).replace("sha256:", "")}  knowledge-candidate-reference.json\n")
    let inventoryHash = benchmarkGapSha256(s3CandidateInventory(candidate))
    let combination = benchmarkGapSha256(s3Part(s3ContextBundleJsonString(original, "rulesHash")) + s3Part(s3ContextBundleJsonString(original, "skillsHash")) + s3Part(checksum) + s3Part(s3ContextBundleJsonString(original, "sourceClosureHash")) + s3Part(s3ContextBundleJsonString(original, "protectedClosureHash")))
    let evidence = s3CandidateManifestEvidence(original, knowledgeCandidateHash, knowledgeTreeHash, inventoryHash, combination,
        s3ContextBundleJsonString(original, "rulesTreeHash"), s3ContextBundleJsonString(original, "skillsTreeHash"))
    let candidateHash = benchmarkGapSha256(evidence)
    File.writeTo(candidate.join("candidate-set-manifest.json"), (evidence.replace("}", ",\"candidateSetHash\":\"${candidateHash}\"}") + "\n").toArray())
    let approval = allowed.join("approval-v2.json")
    let approvalJson = "{\"schemaVersion\":\"teacher-student-context-approval-v2\",\"candidateSetHash\":\"${candidateHash}\",\"assetInventoryHash\":\"${inventoryHash}\",\"rulesHash\":\"${s3ContextBundleJsonString(original, "rulesHash")}\",\"rulesTreeHash\":\"${s3ContextBundleJsonString(original, "rulesTreeHash")}\",\"skillsHash\":\"${s3ContextBundleJsonString(original, "skillsHash")}\",\"skillsTreeHash\":\"${s3ContextBundleJsonString(original, "skillsTreeHash")}\",\"knowledgeCandidateHash\":\"${knowledgeCandidateHash}\",\"knowledgeTreeHash\":\"${knowledgeTreeHash}\",\"sourceClosureHash\":\"${s3ContextBundleJsonString(original, "sourceClosureHash")}\",\"protectedClosureHash\":\"${s3ContextBundleJsonString(original, "protectedClosureHash")}\",\"combinationAuditHash\":\"${combination}\",\"decision\":\"approve\",\"reviewer\":\"synthetic-reviewer\",\"reason\":\"Synthetic full-tree scaffold contract approved.\",\"approvedAtUtc\":\"2026-08-07T00:00:00Z\"}\n"
    File.writeTo(approval, approvalJson.toArray())
    S3ProductionContextFixture(allowed, candidate, approval, manifest, store)
}

public func s4PublishedStudentContext(name:String):String {
    let fixture=s3ProductionContextFixture(name);let output=fixture.allowed.join("published-context")
    let bundle=compileAndPublishStudentContextBundle(fixture.allowed.toString(),"s4-context-v1",fixture.candidate.toString(),fixture.approval.toString(),"none",fixture.manifest.toString(),fixture.store,output.toString(),true)
    if(!bundle.ok){""}else{output.toString()}
}

public func s4PublishedStudentValidatedContext(name: String, providerIdentityHash: String,
    modelVersion: String): S4StudentValidatedContextFixture {
    let fixture = s3ProductionContextFixture(name)
    let manifestPath = fixture.candidate.join("candidate-set-manifest.json")
    let manifest = JsonValue.fromStr(String.fromUtf8(File.readFrom(manifestPath)).trimAscii()).asObject()
    let rulesHash = s3ContextBundleJsonString(manifest, "rulesHash")
    let skillsHash = s3ContextBundleJsonString(manifest, "skillsHash")
    let ruleRoot = fixture.candidate.join("rules/prefer-rune-safe-text-boundaries")
    let rule = parseStudentRuleCandidateDirectory(ruleRoot.toString())
    if (!rule.verified) { throw IllegalStateException("s4_student_validated_rule_source_invalid") }
    let stable = s4RewriteStudentValidationExecutions(ruleRoot.join("tests"), "rules", rulesHash,
        providerIdentityHash, modelVersion)
    rule.positiveEvidenceHash = stable.positive
    rule.negativeEvidenceHash = stable.negative
    rule.boundaryEvidenceHash = stable.boundary
    rule.generalizationEvidenceHash = stable.generalization
    rule.canonicalHash = ckbStudentRuleCandidateCanonicalHash(rule)
    File.writeTo(ruleRoot.join("candidate-manifest.json"),
        (renderStudentRuleCandidateManifest(rule) + "\n").toArray())
    File.writeTo(ruleRoot.join("operation.json"),
        ("{\"schemaVersion\":\"teacher-context-asset-operation-v1\",\"assetRole\":\"rules\"," +
        "\"assetId\":\"${rule.ruleId}\",\"operation\":\"add\",\"expectedOldHash\":\"\"," +
        "\"newHash\":\"${rule.canonicalHash}\"}\n").toArray())
    _ = s4RewriteStudentValidationExecutions(
        fixture.candidate.join("skills/rune-safe-review/executions"), "skills", skillsHash,
        providerIdentityHash, modelVersion)
    s3ResealGenesisCandidateOuter(fixture, validationLevel: "student_validated")
    let output = fixture.allowed.join("published-student-validated-context")
    let bundle = compileAndPublishStudentContextBundle(fixture.allowed.toString(), "s4-real-context-v1",
        fixture.candidate.toString(), fixture.approval.toString(), "none", fixture.manifest.toString(),
        fixture.store, output.toString(), false)
    if (!bundle.ok) { throw IllegalStateException("s4_student_validated_publish_failed:${bundle.diagnostic}") }
    let resealedManifest = JsonValue.fromStr(
        String.fromUtf8(File.readFrom(manifestPath)).trimAscii()).asObject()
    S4StudentValidatedContextFixture(output.toString(), fixture.candidate.toString(),
        s3ContextBundleJsonString(resealedManifest, "candidateSetHash"))
}

private class S4StableValidationEvidence {
    var positive = ""
    var positiveId = ""
    var negative = ""
    var negativeId = ""
    var boundary = ""
    var boundaryId = ""
    var generalization = ""
    var generalizationId = ""
    init() {}
}

private func s4RewriteStudentValidationExecutions(root: Path, lane: String, candidateVisibleHash: String,
    providerIdentityHash: String, modelVersion: String): S4StableValidationEvidence {
    let stable = S4StableValidationEvidence()
    for (directory in Directory.readFrom(root)) {
        if (!directory.isDirectory() || directory.isSymbolicLink()) {
            throw IllegalStateException("s4_student_validation_execution_tree_invalid")
        }
        let fixtureRaw = String.fromUtf8(File.readFrom(directory.path.join("fixture.json")))
        let actualRaw = String.fromUtf8(File.readFrom(directory.path.join("actual.txt")))
        let fixture = JsonValue.fromStr(fixtureRaw.trimAscii()).asObject()
        let fixtureId = s3ContextBundleJsonString(fixture, "fixtureId")
        let kind = s3ContextBundleJsonString(fixture, "kind")
        let source = s3ContextBundleJsonString(fixture, "sourceClass")
        let fixtureHash = s3ContextBundleJsonString(fixture, "fixtureHash")
        let expected = s3ContextBundleJsonString(fixture, "expectedEvidence")
        let actual = s4RemoveStructuralLf(actualRaw)
        let evidenceHash = benchmarkGapSha256(actual)
        let requestHash = benchmarkGapSha256(s3Part(fixtureHash) + s3Part(lane) +
            s3Part(candidateVisibleHash) + s3Part("none") + s3Part(providerIdentityHash))
        let responseHash = benchmarkGapSha256(s3Part(actual) + s3Part(evidenceHash) + s3Part("0"))
        let transcript = "{\"schemaVersion\":\"teacher-student-validation-transcript-v1\"," +
            "\"fixtureId\":\"${fixtureId}\",\"lane\":\"${lane}\"," +
            "\"candidateVisibleHash\":\"${candidateVisibleHash}\",\"baseCompositeHash\":\"none\"," +
            "\"validationIdentityHash\":\"${providerIdentityHash}\",\"requestHash\":\"${requestHash}\"," +
            "\"responseHash\":\"${responseHash}\",\"verifierEvidenceHash\":\"${evidenceHash}\"," +
            "\"exitCode\":0}"
        let transcriptHash = benchmarkGapSha256(transcript)
        let execution = "{\"schemaVersion\":\"teacher-candidate-fixture-execution-v1\"," +
            "\"fixtureId\":\"${fixtureId}\",\"kind\":\"${kind}\",\"sourceClass\":\"${source}\"," +
            "\"fixtureHash\":\"${fixtureHash}\",\"executorKind\":\"student_completion_non_humaneval\"," +
            "\"providerIdentityHash\":\"${providerIdentityHash}\",\"modelVersion\":\"${modelVersion}\"," +
            "\"expectedEvidenceHash\":\"${benchmarkGapSha256(expected)}\"," +
            "\"actualEvidenceHash\":\"${evidenceHash}\",\"transcriptHash\":\"${transcriptHash}\"," +
            "\"exitCode\":0,\"passed\":true}\n"
        File.writeTo(directory.path.join("transcript.txt"), (transcript + "\n").toArray())
        File.writeTo(directory.path.join("execution.json"), execution.toArray())
        if (kind == "positive" && (stable.positiveId == "" || fixtureId.compare(stable.positiveId) == Ordering.LT)) {
            stable.positiveId = fixtureId; stable.positive = transcriptHash
        } else if (kind == "negative" && (stable.negativeId == "" || fixtureId.compare(stable.negativeId) == Ordering.LT)) {
            stable.negativeId = fixtureId; stable.negative = transcriptHash
        } else if (kind == "boundary" && (stable.boundaryId == "" || fixtureId.compare(stable.boundaryId) == Ordering.LT)) {
            stable.boundaryId = fixtureId; stable.boundary = transcriptHash
        } else if (kind == "generalization" && (stable.generalizationId == "" || fixtureId.compare(stable.generalizationId) == Ordering.LT)) {
            stable.generalizationId = fixtureId; stable.generalization = transcriptHash
        }
    }
    stable
}

private func s4RemoveStructuralLf(value: String): String {
    let runes = value.toRuneArray()
    if (runes.size == 0 || runes[runes.size - 1] != r'\n') {
        throw IllegalStateException("s4_student_validation_structural_lf_invalid")
    }
    var out = ""
    for (i in 0..(runes.size - 1)) { out += runes[i].toString() }
    out
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
    let knowledgeReference = JsonValue.fromStr(s5SplitLeakReadUtf8(
        fixture.candidate.join("knowledge/knowledge-candidate-reference.json")).trimAscii()).asObject()
    let skillsHash = benchmarkGapSha256(parsed.skillContent)
    let combination = benchmarkGapSha256(s3Part(s3ContextBundleJsonString(outer, "rulesHash")) +
        s3Part(skillsHash) + s3Part(s3ContextBundleJsonString(knowledgeReference, "knowledgeContentHash")) +
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
    base: CkbStudentContextBundle, combinationOverride!: String = ""): S3ProductionContextFixture {
    let candidate = baseFixture.allowed.join(if (combinationOverride == "") {
        "candidate-update-v2"
    } else {
        "candidate-update-v2-combination-override"
    })
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
    let expectedCombination = benchmarkGapSha256(s3Part(benchmarkGapSha256(compiledRules.agentsMarkdown)) +
        s3Part(s3ContextBundleJsonString(baseManifest, "skillProjectionHash")) +
        s3Part(s3ContextBundleJsonString(baseReference, "knowledgeCandidateHash")) +
        s3Part(s3ContextBundleJsonString(genesisManifest, "sourceClosureHash")) +
        s3Part(s3ContextBundleJsonString(genesisManifest, "protectedClosureHash")))
    let combination = if (combinationOverride == "") { expectedCombination } else { combinationOverride }
    let evidence = "{\"schemaVersion\":\"teacher-student-context-candidate-set-v2\",\"candidateSetId\":\"synthetic-derived-update-v2\",\"baseCompositeHash\":\"${base.compositeHash}\",\"validationLevel\":\"scaffold_contract\",\"sourceEvidenceManifestHash\":\"${s3ContextBundleJsonString(genesisManifest, "sourceEvidenceManifestHash")}\",\"classificationManifestHash\":\"${classification}\",\"sourceClosureHash\":\"${s3ContextBundleJsonString(genesisManifest, "sourceClosureHash")}\",\"protectedClosureHash\":\"${s3ContextBundleJsonString(genesisManifest, "protectedClosureHash")}\",\"rulesEligible\":true,\"rulesHash\":\"${benchmarkGapSha256(compiledRules.agentsMarkdown)}\",\"rulesTreeHash\":\"${rulesTree}\",\"rulesCount\":2,\"rulesAssetLineage\":\"humaneval_164_derived\",\"skillsEligible\":false,\"skillsHash\":\"${s3ContextBundleJsonString(baseManifest, "skillProjectionHash")}\",\"skillsTreeHash\":\"${emptyTree}\",\"skillsCount\":${baseManifest.get("skillCount").getOrThrow().asInt().getValue()},\"skillAssetLineage\":\"${s3ContextBundleJsonString(baseManifest, "skillAssetLineage")}\",\"knowledgeEligible\":false,\"knowledgeCandidateHash\":\"${s3ContextBundleJsonString(baseReference, "knowledgeCandidateHash")}\",\"knowledgeTreeHash\":\"${emptyTree}\",\"knowledgeTargetVersion\":\"${s3ContextBundleJsonString(baseReference, "knowledgeVersion")}\",\"knowledgeAssetLineage\":\"${s3ContextBundleJsonString(baseReference, "assetLineage")}\",\"assetInventoryHash\":\"${inventory}\",\"combinationAuditHash\":\"${combination}\"}"
    let candidateHash = benchmarkGapSha256(evidence)
    File.writeTo(candidate.join("candidate-set-manifest.json"),
        (evidence.replace("}", ",\"candidateSetHash\":\"${candidateHash}\"}") + "\n").toArray())
    let approval = baseFixture.allowed.join("approval-update-v2.json")
    let approvalJson = "{\"schemaVersion\":\"teacher-student-context-approval-v2\",\"candidateSetHash\":\"${candidateHash}\",\"assetInventoryHash\":\"${inventory}\",\"rulesHash\":\"${benchmarkGapSha256(compiledRules.agentsMarkdown)}\",\"rulesTreeHash\":\"${rulesTree}\",\"skillsHash\":\"${s3ContextBundleJsonString(baseManifest, "skillProjectionHash")}\",\"skillsTreeHash\":\"${emptyTree}\",\"knowledgeCandidateHash\":\"${s3ContextBundleJsonString(baseReference, "knowledgeCandidateHash")}\",\"knowledgeTreeHash\":\"${emptyTree}\",\"sourceClosureHash\":\"${s3ContextBundleJsonString(genesisManifest, "sourceClosureHash")}\",\"protectedClosureHash\":\"${s3ContextBundleJsonString(genesisManifest, "protectedClosureHash")}\",\"combinationAuditHash\":\"${combination}\",\"decision\":\"approve\",\"reviewer\":\"synthetic-reviewer\",\"reason\":\"Synthetic derived update approved.\",\"approvedAtUtc\":\"2026-08-07T00:00:00Z\"}\n"
    File.writeTo(approval, approvalJson.toArray())
    S3ProductionContextFixture(baseFixture.allowed, candidate, approval, baseFixture.manifest, baseFixture.store)
}

private func s3ProductionSkillUpdateFixture(baseFixture:S3ProductionContextFixture,baseRoot:Path,
    base:CkbStudentContextBundle):S3ProductionContextFixture {
    let candidate=baseFixture.allowed.join("candidate-skill-update-v2")
    Directory.create(candidate.join("rules"),recursive:true)
    Directory.create(candidate.join("skills"),recursive:true)
    Directory.create(candidate.join("knowledge"),recursive:true)
    s3CopyTree(baseFixture.candidate.join("audit"),candidate.join("audit"))
    let sourceSkill=baseFixture.candidate.join("skills/rune-safe-review")
    let targetSkill=candidate.join("skills/rune-safe-review")
    let derivedRoot=p2WriteDerivedSkillCandidateForTest("context-derived","teacher_derived",
        sourcePath:sourceSkill.toString(),targetPath:targetSkill.toString())
    let derived=parseStudentSkillCandidateDirectory(derivedRoot.toString(),false)
    if(!derived.verified){throw IllegalStateException("s3_derived_skill_candidate_invalid:${derived.diagnostic}")}
    let skills=ArrayList<CkbStudentSkillCandidate>();skills.add(derived)
    let compiled=compileStudentSkillBundle("candidate-skill-update",skills)
    if(!compiled.ok){throw IllegalStateException("s3_derived_skill_bundle_invalid")}
    let baseManifest=JsonValue.fromStr(String.fromUtf8(File.readFrom(
        baseRoot.join("student-context-manifest.json"))).trimAscii()).asObject()
    let baseReference=JsonValue.fromStr(base.knowledgeReferenceJson.trimAscii()).asObject()
    let genesis=JsonValue.fromStr(String.fromUtf8(File.readFrom(
        baseFixture.candidate.join("candidate-set-manifest.json"))).trimAscii()).asObject()
    let classification=benchmarkGapSha256("synthetic-derived-skill-classification")
    let emptyTree=benchmarkGapSha256("")
    let skillProjection=benchmarkGapSha256(renderStudentVisibleSkillPrompt(compiled.json))
    let skillsTree=benchmarkGapSha256(s3TreeInventory(candidate.join("skills")))
    let inventory=benchmarkGapSha256(s3CandidateInventory(candidate))
    let combination=benchmarkGapSha256(s3Part(s3ContextBundleJsonString(baseManifest,"rulesHash"))+
        s3Part(skillProjection)+s3Part(s3ContextBundleJsonString(baseReference,"knowledgeCandidateHash"))+
        s3Part(s3ContextBundleJsonString(genesis,"sourceClosureHash"))+
        s3Part(s3ContextBundleJsonString(genesis,"protectedClosureHash")))
    let evidence="{\"schemaVersion\":\"teacher-student-context-candidate-set-v2\","+
        "\"candidateSetId\":\"synthetic-derived-skill-update-v2\","+
        "\"baseCompositeHash\":\"${base.compositeHash}\",\"validationLevel\":\"scaffold_contract\","+
        "\"sourceEvidenceManifestHash\":\"${s3ContextBundleJsonString(genesis,"sourceEvidenceManifestHash")}\","+
        "\"classificationManifestHash\":\"${classification}\","+
        "\"sourceClosureHash\":\"${s3ContextBundleJsonString(genesis,"sourceClosureHash")}\","+
        "\"protectedClosureHash\":\"${s3ContextBundleJsonString(genesis,"protectedClosureHash")}\","+
        "\"rulesEligible\":false,\"rulesHash\":\"${s3ContextBundleJsonString(baseManifest,"rulesHash")}\","+
        "\"rulesTreeHash\":\"${emptyTree}\",\"rulesCount\":${s3ContextBundleJsonInt(baseManifest,"rulesCount")},"+
        "\"rulesAssetLineage\":\"${s3ContextBundleJsonString(baseManifest,"rulesAssetLineage")}\","+
        "\"skillsEligible\":true,\"skillsHash\":\"${skillProjection}\","+
        "\"skillsTreeHash\":\"${skillsTree}\",\"skillsCount\":${s3ContextBundleJsonInt(baseManifest,"skillCount")},"+
        "\"skillAssetLineage\":\"humaneval_164_derived\",\"knowledgeEligible\":false,"+
        "\"knowledgeCandidateHash\":\"${s3ContextBundleJsonString(baseReference,"knowledgeCandidateHash")}\","+
        "\"knowledgeTreeHash\":\"${emptyTree}\","+
        "\"knowledgeTargetVersion\":\"${s3ContextBundleJsonString(baseReference,"knowledgeVersion")}\","+
        "\"knowledgeAssetLineage\":\"${s3ContextBundleJsonString(baseReference,"assetLineage")}\","+
        "\"assetInventoryHash\":\"${inventory}\",\"combinationAuditHash\":\"${combination}\"}"
    let candidateHash=benchmarkGapSha256(evidence)
    File.writeTo(candidate.join("candidate-set-manifest.json"),
        (String(evidence.toRuneArray()[..evidence.toRuneArray().size-1])+
        ",\"candidateSetHash\":\"${candidateHash}\"}\n").toArray())
    let approval=baseFixture.allowed.join("approval-skill-update-v2.json")
    let approvalJson="{\"schemaVersion\":\"teacher-student-context-approval-v2\","+
        "\"candidateSetHash\":\"${candidateHash}\",\"assetInventoryHash\":\"${inventory}\","+
        "\"rulesHash\":\"${s3ContextBundleJsonString(baseManifest,"rulesHash")}\","+
        "\"rulesTreeHash\":\"${emptyTree}\",\"skillsHash\":\"${skillProjection}\","+
        "\"skillsTreeHash\":\"${skillsTree}\","+
        "\"knowledgeCandidateHash\":\"${s3ContextBundleJsonString(baseReference,"knowledgeCandidateHash")}\","+
        "\"knowledgeTreeHash\":\"${emptyTree}\","+
        "\"sourceClosureHash\":\"${s3ContextBundleJsonString(genesis,"sourceClosureHash")}\","+
        "\"protectedClosureHash\":\"${s3ContextBundleJsonString(genesis,"protectedClosureHash")}\","+
        "\"combinationAuditHash\":\"${combination}\",\"decision\":\"approve\","+
        "\"reviewer\":\"synthetic-reviewer\",\"reason\":\"Synthetic derived skill update approved.\","+
        "\"approvedAtUtc\":\"2026-08-07T00:00:00Z\"}\n"
    File.writeTo(approval,approvalJson.toArray())
    S3ProductionContextFixture(baseFixture.allowed,candidate,approval,baseFixture.manifest,baseFixture.store)
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

private func s3ExpandGenesisRules(fixture: S3ProductionContextFixture, targetBytes: Int64): Unit {
    let root = fixture.candidate.join("rules/prefer-rune-safe-text-boundaries")
    let rule = parseStudentRuleCandidateDirectory(root.toString())
    if (!rule.verified) { throw IllegalStateException("expanded_rule_source_invalid") }
    rule.body = ""
    let fixedMarkdown = "# Student Rules\n\n## ${rule.title}\n\n\n\nTrigger: ${rule.trigger}\nScope: ${rule.scope}\n"
    if (Int64(fixedMarkdown.toArray().size) > targetBytes) {
        throw IllegalStateException("expanded_rule_target_too_small")
    }
    var body = ""
    for (_ in 0..(targetBytes - Int64(fixedMarkdown.toArray().size))) { body += "x" }
    rule.body = body
    rule.canonicalHash = ckbStudentRuleCandidateCanonicalHash(rule)
    rule.agentsMarkdown = "# Student Rules\n\n## ${rule.title}\n\n${rule.body}\n\nTrigger: ${rule.trigger}\nScope: ${rule.scope}\n"
    File.writeTo(root.join("AGENTS.md"), rule.agentsMarkdown.toArray())
    File.writeTo(root.join("candidate-manifest.json"),
        (renderStudentRuleCandidateManifest(rule) + "\n").toArray())
    File.writeTo(root.join("operation.json"),
        ("{\"schemaVersion\":\"teacher-context-asset-operation-v1\",\"assetRole\":\"rules\"," +
        "\"assetId\":\"${rule.ruleId}\",\"operation\":\"add\",\"expectedOldHash\":\"\"," +
        "\"newHash\":\"${rule.canonicalHash}\"}\n").toArray())
    let verified = parseStudentRuleCandidateDirectory(root.toString())
    if (!verified.verified || Int64(verified.agentsMarkdown.toArray().size) != targetBytes) {
        throw IllegalStateException("expanded_rule_candidate_invalid")
    }
    let rules = ArrayList<CkbStudentRuleCandidate>(); rules.add(verified)
    let compiled = compileStudentRulesBundle("expanded-rules", rules)
    if (!compiled.ok || compiled.contentBytes != targetBytes) {
        throw IllegalStateException("expanded_rule_bundle_invalid")
    }
    let manifest = JsonValue.fromStr(String.fromUtf8(File.readFrom(
        fixture.candidate.join("candidate-set-manifest.json"))).trimAscii()).asObject()
    let reference = JsonValue.fromStr(String.fromUtf8(File.readFrom(
        fixture.candidate.join("knowledge/knowledge-candidate-reference.json"))).trimAscii()).asObject()
    let rulesHash = benchmarkGapSha256(compiled.agentsMarkdown)
    let combination = benchmarkGapSha256(s3Part(rulesHash) +
        s3Part(s3ContextBundleJsonString(manifest, "skillsHash")) +
        s3Part(s3ContextBundleJsonString(reference, "knowledgeContentHash")) +
        s3Part(s3ContextBundleJsonString(manifest, "sourceClosureHash")) +
        s3Part(s3ContextBundleJsonString(manifest, "protectedClosureHash")))
    s3ResealGenesisCandidateOuter(fixture, combination: combination, rulesHash: rulesHash)
}

private func s3ResealGenesisCandidateOuter(fixture: S3ProductionContextFixture,
    combination!: String = "", skillsHash!: String = "",
    validationLevel!: String = "scaffold_contract", rulesHash!: String = ""): Unit {
    let manifestPath = fixture.candidate.join("candidate-set-manifest.json")
    let object = JsonValue.fromStr(String.fromUtf8(File.readFrom(manifestPath)).trimAscii()).asObject()
    let rulesTree = benchmarkGapSha256(s3TreeInventory(fixture.candidate.join("rules")))
    let skillsTree = benchmarkGapSha256(s3TreeInventory(fixture.candidate.join("skills")))
    let knowledgeTree = benchmarkGapSha256(s3TreeInventory(fixture.candidate.join("knowledge")))
    let inventory = benchmarkGapSha256(s3CandidateInventory(fixture.candidate))
    let selectedCombination = if (combination == "") { s3ContextBundleJsonString(object, "combinationAuditHash") }
        else { combination }
    let evidence = s3CandidateManifestEvidence(object, s3ContextBundleJsonString(object, "knowledgeCandidateHash"),
        knowledgeTree, inventory, selectedCombination, rulesTree, skillsTree, skillsHash: skillsHash,
        validationLevel: validationLevel, rulesHash: rulesHash)
    let candidateHash = benchmarkGapSha256(evidence)
    File.writeTo(manifestPath,
        (evidence.replace("}", ",\"candidateSetHash\":\"${candidateHash}\"}") + "\n").toArray())
    let selectedSkillsHash = if (skillsHash == "") { s3ContextBundleJsonString(object, "skillsHash") }
        else { skillsHash }
    let selectedRulesHash = if (rulesHash == "") { s3ContextBundleJsonString(object, "rulesHash") }
        else { rulesHash }
    let approvalJson = "{\"schemaVersion\":\"teacher-student-context-approval-v2\",\"candidateSetHash\":\"${candidateHash}\",\"assetInventoryHash\":\"${inventory}\",\"rulesHash\":\"${selectedRulesHash}\",\"rulesTreeHash\":\"${rulesTree}\",\"skillsHash\":\"${selectedSkillsHash}\",\"skillsTreeHash\":\"${skillsTree}\",\"knowledgeCandidateHash\":\"${s3ContextBundleJsonString(object, "knowledgeCandidateHash")}\",\"knowledgeTreeHash\":\"${knowledgeTree}\",\"sourceClosureHash\":\"${s3ContextBundleJsonString(object, "sourceClosureHash")}\",\"protectedClosureHash\":\"${s3ContextBundleJsonString(object, "protectedClosureHash")}\",\"combinationAuditHash\":\"${selectedCombination}\",\"decision\":\"approve\",\"reviewer\":\"synthetic-reviewer\",\"reason\":\"Synthetic full-tree scaffold contract approved.\",\"approvedAtUtc\":\"2026-08-07T00:00:00Z\"}\n"
    File.writeTo(fixture.approval, approvalJson.toArray())
}

private func s3CandidateManifestEvidence(o: JsonObject, knowledgeHash: String, knowledgeTreeHash: String,
    inventoryHash: String, combination: String, rulesTreeHash: String, skillsTreeHash: String,
    skillsHash!: String = "", validationLevel!: String = "scaffold_contract",
    rulesHash!: String = ""): String {
    let selectedSkillsHash = if (skillsHash == "") { s3ContextBundleJsonString(o, "skillsHash") }
        else { skillsHash }
    let selectedRulesHash = if (rulesHash == "") { s3ContextBundleJsonString(o, "rulesHash") }
        else { rulesHash }
    "{\"schemaVersion\":\"teacher-student-context-candidate-set-v2\",\"candidateSetId\":\"${s3ContextBundleJsonString(o, "candidateSetId")}\",\"baseCompositeHash\":\"none\",\"validationLevel\":\"${validationLevel}\",\"sourceEvidenceManifestHash\":\"${s3ContextBundleJsonString(o, "sourceEvidenceManifestHash")}\",\"classificationManifestHash\":\"\",\"sourceClosureHash\":\"${s3ContextBundleJsonString(o, "sourceClosureHash")}\",\"protectedClosureHash\":\"${s3ContextBundleJsonString(o, "protectedClosureHash")}\",\"rulesEligible\":true,\"rulesHash\":\"${selectedRulesHash}\",\"rulesTreeHash\":\"${rulesTreeHash}\",\"rulesCount\":1,\"rulesAssetLineage\":\"independent\",\"skillsEligible\":true,\"skillsHash\":\"${selectedSkillsHash}\",\"skillsTreeHash\":\"${skillsTreeHash}\",\"skillsCount\":1,\"skillAssetLineage\":\"independent\",\"knowledgeEligible\":true,\"knowledgeCandidateHash\":\"${knowledgeHash}\",\"knowledgeTreeHash\":\"${knowledgeTreeHash}\",\"knowledgeTargetVersion\":\"${s3ContextBundleJsonString(o, "knowledgeTargetVersion")}\",\"knowledgeAssetLineage\":\"independent\",\"assetInventoryHash\":\"${inventoryHash}\",\"combinationAuditHash\":\"${combination}\"}"
}

private func s3ContextBundleJsonString(o: JsonObject, key: String): String { o.get(key).getOrThrow().asString().getValue() }
private func s3ContextBundleJsonInt(o:JsonObject,key:String):Int64{o.get(key).getOrThrow().asInt().getValue()}

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

private class S3ValidationBinding {
    var fixture="";var actual="";var transcript="";var execution="";var lane="rules"
    var candidateVisibleHash="";var baseCompositeHash="none";var validationIdentityHash=""
    var modelVersion="student-model-v1";var requestHash="";init(){}
}

private func s3ValidationBinding(): S3ValidationBinding {
    let out=S3ValidationBinding();let fixtureId="validation-unit";let kind="unit"
    let source="non_humaneval_experiment";let content="校验候选上下文🙂";let evidence="验证通过🙂"
    out.candidateVisibleHash="sha256:"+s3Hex(r'b');out.validationIdentityHash="sha256:"+s3Hex(r'a')
    let fixtureHash=benchmarkGapSha256(s3Part(fixtureId)+s3Part(kind)+s3Part(source)+s3Part(content)+s3Part(evidence))
    out.fixture="{\"schemaVersion\":\"teacher-asset-fixture-v1\",\"fixtureId\":\"${fixtureId}\",\"kind\":\"${kind}\",\"sourceClass\":\"${source}\",\"content\":\"${content}\",\"expectedEvidence\":\"${evidence}\",\"fixtureHash\":\"${fixtureHash}\"}\n"
    out.actual=evidence+"\n";let evidenceHash=benchmarkGapSha256(evidence)
    out.requestHash=benchmarkGapSha256(s3Part(fixtureHash)+s3Part(out.lane)+s3Part(out.candidateVisibleHash)+s3Part(out.baseCompositeHash)+s3Part(out.validationIdentityHash))
    let responseHash=benchmarkGapSha256(s3Part(evidence)+s3Part(evidenceHash)+s3Part("0"))
    out.transcript="{\"schemaVersion\":\"teacher-student-validation-transcript-v1\",\"fixtureId\":\"${fixtureId}\",\"lane\":\"${out.lane}\",\"candidateVisibleHash\":\"${out.candidateVisibleHash}\",\"baseCompositeHash\":\"${out.baseCompositeHash}\",\"validationIdentityHash\":\"${out.validationIdentityHash}\",\"requestHash\":\"${out.requestHash}\",\"responseHash\":\"${responseHash}\",\"verifierEvidenceHash\":\"${evidenceHash}\",\"exitCode\":0}\n"
    out.execution="{\"schemaVersion\":\"teacher-candidate-fixture-execution-v1\",\"fixtureId\":\"${fixtureId}\",\"kind\":\"${kind}\",\"sourceClass\":\"${source}\",\"fixtureHash\":\"${fixtureHash}\",\"executorKind\":\"student_completion_non_humaneval\",\"providerIdentityHash\":\"${out.validationIdentityHash}\",\"modelVersion\":\"${out.modelVersion}\",\"expectedEvidenceHash\":\"${evidenceHash}\",\"actualEvidenceHash\":\"${evidenceHash}\",\"transcriptHash\":\"${benchmarkGapSha256(out.transcript.trimAscii())}\",\"exitCode\":0,\"passed\":true}\n";out
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
