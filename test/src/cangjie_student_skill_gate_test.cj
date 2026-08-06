package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}
import std.time.DateTime
import std.process.launch
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbR1StudentSkillCandidateContractTest {
    // P2-CKB-POS-01
    @TestCase
    public func frozenIndependentTeacherCandidateParsesWithExactHashes(): Unit {
        let root="fixtures/teacher_skill_candidate/static-boundary-review"
        let candidate=parseStudentSkillCandidateDirectory(root,true)
        @Expect(candidate.verified,true);@Expect(candidate.diagnostic,"ok")
        @Expect(candidate.skillContentHash,"sha256:a336604425fd37b5100fb2ea74ca67d2226093121b94e240b124d40d6d639eb5")
        @Expect(candidate.testBundleHash,"sha256:b23c9adb1aa4d50440f90229593f8067aefd3cc500b71b646407b7a7570af801")
        @Expect(candidate.testEvidenceHash,"sha256:7d7e6b68af9137b502f8e122777a51fbe54960d313f8afba36b029e9b96ed5c1")
        @Expect(candidate.candidateContentHash,"sha256:7a7fa5b2c6d23fcf7eea67eef0fd9de26fe61f7c6f4e6e707e33e2fbb4dbaed0")
        @Expect(candidate.artifactHash,"sha256:f16d7384e707d6848c319522aff1cea14ed90cb46db97f1fccc1ffdee8bcc204")
        @Expect(parseStudentSkillCandidateDirectory(root,false).diagnostic,"derived_staging_lineage_required")
    }

    // P2-CKB-UT-01
    @TestCase
    public func independentSkillBundleCompilationIsDeterministic(): Unit {
        let candidate=parseStudentSkillCandidateDirectory("fixtures/teacher_skill_candidate/static-boundary-review",true)
        let skills=ArrayList<CkbStudentSkillCandidate>([candidate])
        let first=compileStudentSkillBundle("student-skills-v1",skills);let second=compileStudentSkillBundle("student-skills-v1",skills)
        @Expect(first.ok,true);@Expect(first.json,second.json);@Expect(first.canonicalHash,second.canonicalHash)
        @Expect(first.skillCount,1);@Expect(first.contentBytes,Int64(candidate.skillContent.toArray().size))
        @Expect(parseStudentSkillBundle((first.json+"\n").toArray()).canonicalHash,first.canonicalHash)
    }

    // P2-CKB-BND-01
    @TestCase
    public func emptyDuplicateOversizeAndCountBoundariesFailClosed(): Unit {
        @Expect(auditStudentSkillBundle(ArrayList<CkbStudentSkillCandidate>()),"student_skill_bundle_empty")
        let seed=parseStudentSkillCandidateDirectory("fixtures/teacher_skill_candidate/static-boundary-review",true)
        let duplicate=ArrayList<CkbStudentSkillCandidate>([seed,seed]);@Expect(auditStudentSkillBundle(duplicate),"duplicate_skill_id")
        let many=ArrayList<CkbStudentSkillCandidate>();for(i in 0..17){let c=p2GateCandidate("skill-${i}","procedure-${i}");many.add(c)}
        @Expect(auditStudentSkillBundle(many),"student_skill_count_exceeded")
        let large=p2GateCandidate("large","large");let body=StringBuilder();for(_ in 0..24577){body.append("x")};large.skillContent=body.toString()
        @Expect(auditStudentSkillBundle(ArrayList<CkbStudentSkillCandidate>([large])),"student_skill_content_budget_exceeded")
    }

    // P2-CKB-NEG-01
    @TestCase
    public func immutablePublishAndCanonicalBundleTamperAreRejected(): Unit {
        let seed=parseStudentSkillCandidateDirectory("fixtures/teacher_skill_candidate/static-boundary-review",true)
        let built=compileStudentSkillBundle("student-skills-v1",ArrayList<CkbStudentSkillCandidate>([seed]))
        let root=Path("target/p2-skill-gate-${DateTime.now().toUnixTimeStamp().toMilliseconds()}");Directory.create(root,recursive:true);let output=root.join("bundle.json")
        @Expect(publishStudentSkillBundle(output.toString(),built),"ok");@Expect(publishStudentSkillBundle(output.toString(),built),"ok")
        File.writeTo(output,"tampered\n".toArray());@Expect(publishStudentSkillBundle(output.toString(),built),"student_skill_bundle_immutable_conflict")
        @Expect(parseStudentSkillBundle([UInt8(0xff),UInt8(0xfe)]).diagnostic,"invalid_response_encoding")
        @Expect(parseStudentSkillBundle("{".toArray()).diagnostic,"malformed_json")
        @Expect(parseStudentSkillBundle((built.json.replace("general_engineering","teacher_derived")+"\n").toArray()).diagnostic,"skill_entry_identity_invalid")
        let copied=root.join("candidate-copy");@Expect(launch("/bin/cp",["-R","fixtures/teacher_skill_candidate/static-boundary-review",copied.toString()]).wait(),0)
        let manifestPath=copied.join("candidate-manifest.json");let manifest=String.fromUtf8(File.readFrom(manifestPath));File.writeTo(manifestPath,(manifest+"\n").toArray())
        @Expect(parseStudentSkillCandidateDirectory(copied.toString(),true).diagnostic,"skill_candidate_artifact_hash_mismatch")
        let copiedBundle=root.join("candidate-copy-bundle");@Expect(launch("/bin/cp",["-R","fixtures/teacher_skill_candidate/static-boundary-review",copiedBundle.toString()]).wait(),0)
        let bundlePath=copiedBundle.join("test-bundle.json");let bundle=String.fromUtf8(File.readFrom(bundlePath));File.writeTo(bundlePath,(" "+bundle).toArray())
        @Expect(parseStudentSkillCandidateDirectory(copiedBundle.toString(),true).diagnostic,"skill_test_bundle_noncanonical")
    }

    // P2-CKB-NEG-02
    @TestCase
    public func protectedCombinationUsesExistingLeakageAuthority(): Unit {
        let seed=parseStudentSkillCandidateDirectory("fixtures/teacher_skill_candidate/static-boundary-review",true)
        let skills=ArrayList<CkbStudentSkillCandidate>([seed])
        @Expect(auditStudentSkillBundleWithKnowledge(skills,"Safe public Rune guidance 中文😀"),"ok")
        @Expect(auditStudentSkillBundleWithKnowledge(skills,"canonical_solution must stay hidden").startsWith("skill_knowledge_combination_leakage"),true)
    }
}

private func p2GateCandidate(id:String,procedure:String):CkbStudentSkillCandidate{let c=CkbStudentSkillCandidate();c.id=id;c.version="1";c.procedure=procedure;c.skillContent="content-${id}";c.candidateContentHash=benchmarkGapSha256(id);c.verified=true;c.diagnostic="ok";c}
