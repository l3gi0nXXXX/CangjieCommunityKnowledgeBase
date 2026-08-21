package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}
import std.time.DateTime
import std.process.launch
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.json.*

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

    @TestCase
    public func derivedSkillUsesTeacherDerivedOnlyInVisibleFrontmatter(): Unit {
        let root=p2WriteDerivedSkillCandidateForTest("derived-visible","teacher_derived")
        let candidate=parseStudentSkillCandidateDirectory(root.toString(),false)
        @Expect(candidate.verified,true);@Expect(candidate.diagnostic,"ok")
        @Expect(candidate.lineage,"humaneval_164_derived")
        @Expect(candidate.skillContent.contains("lineage: teacher_derived\n"),true)
        @Expect(candidate.skillContent.toAsciiLower().contains("humaneval"),false)
        @Expect(cangjieStudentVisibleTextDiagnostic("derivedSkill",candidate.skillContent).ok,true)
        @Expect(String.fromUtf8(File.readFrom(root.join("candidate-manifest.json"))).contains(
            "\"lineage\":\"humaneval_164_derived\""),true)
        @Expect(String.fromUtf8(File.readFrom(root.join("test-bundle.json"))).contains(
            "\"lineage\":\"humaneval_164_derived\""),true)
        let bundle=compileStudentSkillBundle("derived-visible-v1",
            ArrayList<CkbStudentSkillCandidate>([candidate]))
        @Expect(bundle.ok,true)
        @Expect(bundle.json.contains("\"lineage\":\"humaneval_164_derived\""),true)
        @Expect(parseStudentSkillBundle((bundle.json+"\n").toArray()).diagnostic,"ok")
    }

    @TestCase
    public func derivedSkillRejectsInternalLineageInVisibleFrontmatter(): Unit {
        let root=p2WriteDerivedSkillCandidateForTest("derived-visible-leak","humaneval_164_derived")
        let candidate=parseStudentSkillCandidateDirectory(root.toString(),false)
        @Expect(candidate.verified,false)
        @Expect(candidate.diagnostic,"skill_markdown_semantic_mismatch")
        let visible=String.fromUtf8(File.readFrom(root.join("SKILL.md")))
        @Expect(cangjieStudentVisibleTextDiagnostic("derivedSkillLeak",visible).ok,false)
    }

    @TestCase
    public func independentSkillKeepsIndependentVisibleLineage(): Unit {
        let candidate=parseStudentSkillCandidateDirectory(
            "fixtures/teacher_skill_candidate/static-boundary-review",true)
        @Expect(candidate.verified,true)
        @Expect(ckbStudentSkillVisibleLineage(candidate.lineage),"independent")
        @Expect(candidate.skillContent.contains("lineage: independent\n"),true)
        @Expect(candidate.skillContent.contains("lineage: teacher_derived\n"),false)
    }

    @TestCase
    public func unknownInternalSkillLineageIsRejectedFailClosed(): Unit {
        var rejected=false
        try{_=ckbStudentSkillVisibleLineage("teacher_derived")}
        catch(e:Exception){rejected=e.message=="skill_source_lineage_invalid"}
        @Expect(rejected,true)
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
        let sixteen=ArrayList<CkbStudentSkillCandidate>();for(i in 0..16){sixteen.add(p2GateCandidate("exact-${i}","exact-procedure-${i}"))};@Expect(auditStudentSkillBundle(sixteen),"ok")
        @Expect(compileStudentSkillBundle("exact-sixteen",sixteen).skillCount,16)
        let exactBytes=p2GateCandidate("exact-bytes","exact-bytes");let exactBody=StringBuilder();for(_ in 0..24576){exactBody.append("x")};exactBytes.skillContent=exactBody.toString();@Expect(auditStudentSkillBundle(ArrayList<CkbStudentSkillCandidate>([exactBytes])),"ok")
        let large=p2GateCandidate("large","large");let body=StringBuilder();for(_ in 0..24577){body.append("x")};large.skillContent=body.toString()
        @Expect(auditStudentSkillBundle(ArrayList<CkbStudentSkillCandidate>([large])),"student_skill_content_budget_exceeded")
        @Expect(ckbStudentSkillFixturePathUniquenessDiagnostic(["tests/a.json","tests/b.json","tests/c.json"]),"ok")
        @Expect(ckbStudentSkillFixturePathUniquenessDiagnostic(["tests/a.json","tests/a.json","tests/c.json"]),"duplicate_skill_fixture_path")
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
        @Expect(parseStudentSkillBundle((" "+built.json+"\n").toArray()).diagnostic,"skill_bundle_noncanonical")
        @Expect(parseStudentSkillBundle((built.json+"\n\n").toArray()).diagnostic,"skill_bundle_noncanonical")
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

public func p2WriteDerivedSkillCandidateForTest(name:String,visibleLineage:String,
    sourcePath!:String="fixtures/teacher_skill_candidate/static-boundary-review",
    targetParent!:String="target",targetPath!:String=""):Path {
    let source=Path(sourcePath)
    let target=if(targetPath==""){Path(targetParent).join(
        "p2-${name}-${DateTime.now().toUnixTimeStamp().toMilliseconds()}")}else{Path(targetPath)}
    if(!exists(target.parent)){Directory.create(target.parent,recursive:true)}
    if(launch("/bin/cp",["-R",source.toString(),target.toString()]).wait()!=0){
        throw IllegalStateException("p2_derived_skill_copy_failed")
    }
    let original=parseStudentSkillCandidateDirectory(source.toString(),true)
    if(!original.verified){throw IllegalStateException("p2_derived_skill_source_invalid")}
    let bundlePath=target.join("test-bundle.json")
    let bundleRaw=String.fromUtf8(File.readFrom(bundlePath)).trimAscii()
    let bundle=JsonValue.fromStr(bundleRaw).asObject()
    let oldEvidence=bundle.get("evidenceHash").getOrThrow().asString().getValue()
    let withLineage=bundleRaw.replace("\"lineage\":\"independent\"",
        "\"lineage\":\"humaneval_164_derived\"")
    let evidence=withLineage.replace(",\"evidenceHash\":\"${oldEvidence}\"}","}")
    let evidenceHash=benchmarkGapSha256(evidence)
    let evidenceRunes=evidence.toRuneArray()
    let sealedBundle=String(evidenceRunes[..evidenceRunes.size-1])+
        ",\"evidenceHash\":\"${evidenceHash}\"}"
    File.writeTo(bundlePath,(sealedBundle+"\n").toArray())

    original.sourceCategory="teacher_derived";original.lineage="humaneval_164_derived"
    original.testEvidenceHash=evidenceHash;original.testBundleHash=benchmarkGapSha256(sealedBundle)
    let identity=p2Part(original.id)+p2Part(original.version)+p2Part(original.title)+
        p2Part(original.procedure)+p2Part(original.sourceCategory)+p2Part(original.applicability)+
        p2Part(original.lineage)+p2Part(original.testEvidenceHash)
    original.candidateContentHash=benchmarkGapSha256(identity)
    original.skillContent="---\nname: ${original.id}\nversion: ${original.version}\n"+
        "source: ${original.sourceCategory}\nlineage: ${visibleLineage}\n"+
        "content-hash: ${original.candidateContentHash}\n---\n\n# ${original.title}\n\n"+
        "Applicability: ${original.applicability}\n\n${original.procedure}\n"
    original.skillContentHash=benchmarkGapSha256(original.skillContent)
    let manifestEvidence=p2SkillManifest(original,false)
    original.artifactHash=benchmarkGapSha256(manifestEvidence)
    File.writeTo(target.join("SKILL.md"),original.skillContent.toArray())
    File.writeTo(target.join("candidate-manifest.json"),
        (p2SkillManifest(original,true)+"\n").toArray())
    if(exists(target.join("operation.json"))){
        let operation="{\"schemaVersion\":\"teacher-context-asset-operation-v1\","+
            "\"assetRole\":\"skills\",\"assetId\":\"${original.id}\","+
            "\"operation\":\"replace\",\"expectedOldHash\":\"${parseStudentSkillCandidateDirectory(source.toString(),true).candidateContentHash}\","+
            "\"newHash\":\"${original.candidateContentHash}\"}\n"
        File.writeTo(target.join("operation.json"),operation.toArray())
    }
    target
}

private func p2SkillManifest(skill:CkbStudentSkillCandidate,sealed:Bool):String {
    let fields="\"schemaVersion\":\"cangjie-teacher-skill-candidate-v1\","+
        "\"id\":\"${p2Escape(skill.id)}\",\"version\":\"${p2Escape(skill.version)}\","+
        "\"title\":\"${p2Escape(skill.title)}\",\"procedure\":\"${p2Escape(skill.procedure)}\","+
        "\"sourceCategory\":\"${skill.sourceCategory}\",\"applicability\":\"${p2Escape(skill.applicability)}\","+
        "\"lineage\":\"${skill.lineage}\",\"skillPath\":\"SKILL.md\","+
        "\"skillContentHash\":\"${skill.skillContentHash}\",\"testBundlePath\":\"test-bundle.json\","+
        "\"testBundleHash\":\"${skill.testBundleHash}\",\"testEvidenceHash\":\"${skill.testEvidenceHash}\","+
        "\"candidateContentHash\":\"${skill.candidateContentHash}\""
    if(sealed){"{${fields},\"artifactHash\":\"${skill.artifactHash}\"}"}else{"{${fields}}"}
}

private func p2Part(value:String):String{"${value.toArray().size}:${value}"}
private func p2Escape(value:String):String{value.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t")}
