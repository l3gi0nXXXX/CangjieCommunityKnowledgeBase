package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}
import std.fs.{Directory, File, FileInfo, Path, exists, rename, remove}
import std.sort.*
import stdx.encoding.json.*

public class CkbStudentSkillCandidate {
    public var verified=false;public var diagnostic="not_parsed";public var root=""
    public var id="";public var version="";public var title="";public var procedure=""
    public var sourceCategory="";public var applicability="";public var lineage=""
    public var skillContent="";public var skillContentHash="";public var testBundleHash=""
    public var testEvidenceHash="";public var candidateContentHash="";public var artifactHash=""
    public init(){}
}
public class CkbStudentSkillBundleBuild {
    public var ok=false;public var diagnostic="not_built";public var bundleVersion=""
    public var contentBytes:Int64=0;public var skillCount:Int64=0;public var canonicalHash=""
    public var json="";public init(){}
}
private class CkbSkillTestRow{
    var testId="";var kind="";var fixturePath="";var fixtureHash="";var targetVersion=""
    var sourceClass="";var benchmarkDerived=false;var passed=false;var resultHash="";init(){}
}

public func parseStudentSkillCandidateDirectory(rootPath:String,independentSeed:Bool):CkbStudentSkillCandidate{
    let c=CkbStudentSkillCandidate();c.root=rootPath;let root=Path(rootPath)
    if(!exists(root)){c.diagnostic="skill_candidate_directory_missing";return c}
    try{
        if(FileInfo(root).isSymbolicLink()||!FileInfo(root).isDirectory()){c.diagnostic="skill_candidate_directory_invalid";return c}
        let contextCandidate=exists(root.join("operation.json"))
        let expected=if(contextCandidate){HashSet<String>(["SKILL.md","candidate-manifest.json","test-bundle.json","operation.json","tests","executions"])}
            else{HashSet<String>(["SKILL.md","candidate-manifest.json","test-bundle.json","tests"])}
        for(entry in Directory.readFrom(root)){if(entry.isSymbolicLink()||!expected.contains(entry.name)){c.diagnostic="skill_candidate_directory_entry_invalid";return c};expected.remove(entry.name)}
        if(!expected.isEmpty()){c.diagnostic="skill_candidate_directory_incomplete";return c}
        let required=if(contextCandidate){["SKILL.md","candidate-manifest.json","test-bundle.json","operation.json"]}
            else{["SKILL.md","candidate-manifest.json","test-bundle.json"]}
        for(name in required){let p=root.join(name);if(FileInfo(p).isSymbolicLink()||!FileInfo(p).isRegular()){c.diagnostic="skill_candidate_regular_file_required";return c}}
        let skill=ckbSkillReadUtf8(root.join("SKILL.md"));let manifestDisk=ckbSkillReadUtf8(root.join("candidate-manifest.json"));let bundleDisk=ckbSkillReadUtf8(root.join("test-bundle.json"))
        if(skill[1]!="ok"||manifestDisk[1]!="ok"||bundleDisk[1]!="ok"){c.diagnostic="invalid_response_encoding";return c}
        if(skill[0].contains("\r")||manifestDisk[0].contains("\r")||bundleDisk[0].contains("\r")||!skill[0].endsWith("\n")||!manifestDisk[0].endsWith("\n")||!bundleDisk[0].endsWith("\n")){c.diagnostic="skill_candidate_lf_contract_invalid";return c}
        let manifestText=manifestDisk[0].trimAscii();let manifest=JsonValue.fromStr(manifestText).asObject()
        if(manifest.getFields().size!=15){c.diagnostic="skill_candidate_manifest_fields_invalid";return c}
        c.id=ckbSkillString(manifest,"id");c.version=ckbSkillString(manifest,"version");c.title=ckbSkillString(manifest,"title");c.procedure=ckbSkillString(manifest,"procedure");c.sourceCategory=ckbSkillString(manifest,"sourceCategory");c.applicability=ckbSkillString(manifest,"applicability");c.lineage=ckbSkillString(manifest,"lineage");c.skillContent=skill[0];c.skillContentHash=ckbSkillString(manifest,"skillContentHash");c.testBundleHash=ckbSkillString(manifest,"testBundleHash");c.testEvidenceHash=ckbSkillString(manifest,"testEvidenceHash");c.candidateContentHash=ckbSkillString(manifest,"candidateContentHash");c.artifactHash=ckbSkillString(manifest,"artifactHash")
        if(ckbSkillString(manifest,"schemaVersion")!="cangjie-teacher-skill-candidate-v1"||ckbSkillString(manifest,"skillPath")!="SKILL.md"||ckbSkillString(manifest,"testBundlePath")!="test-bundle.json"){c.diagnostic="skill_candidate_manifest_identity_invalid";return c}
        if(!((c.sourceCategory=="general_engineering"&&c.lineage=="independent")||(c.sourceCategory=="teacher_derived"&&c.lineage=="humaneval_164_derived"))){c.diagnostic="skill_source_lineage_invalid";return c}
        if(independentSeed&&c.lineage!="independent"){c.diagnostic="independent_seed_lineage_required";return c}
        if(!independentSeed&&c.lineage!="humaneval_164_derived"){c.diagnostic="derived_staging_lineage_required";return c}
        if(contextCandidate&&c.version!="1.0.0"){c.diagnostic="skill_candidate_manifest_identity_invalid";return c}
        let bundleText=bundleDisk[0].trimAscii();let bundle=JsonValue.fromStr(bundleText).asObject()
        if(bundle.getFields().size!=12){c.diagnostic="skill_test_bundle_fields_invalid";return c}
        if(ckbSkillString(bundle,"candidateId")!=c.id||ckbSkillString(bundle,"candidateVersion")!=c.version||ckbSkillString(bundle,"lineage")!=c.lineage){c.diagnostic="skill_test_bundle_candidate_mismatch";return c}
        let rows=ArrayList<CkbSkillTestRow>();let fixturePaths=ArrayList<String>();for(v in bundle.get("tests").getOrThrow().asArray().getItems()){let o=v.asObject();if(o.getFields().size!=9){c.diagnostic="skill_test_row_fields_invalid";return c};let row=CkbSkillTestRow();row.testId=ckbSkillString(o,"testId");row.kind=ckbSkillString(o,"kind");row.fixturePath=ckbSkillString(o,"fixturePath");row.fixtureHash=ckbSkillString(o,"fixtureHash");row.targetVersion=ckbSkillString(o,"targetVersion");row.sourceClass=ckbSkillString(o,"sourceClass");row.benchmarkDerived=ckbSkillBool(o,"benchmarkDerived");row.passed=ckbSkillBool(o,"passed");row.resultHash=ckbSkillString(o,"resultHash");fixturePaths.add(row.fixturePath);rows.add(row)};if(!studentSkillFixturePathsCanonical(fixturePaths.toArray())){c.diagnostic="skill_test_bundle_noncanonical";return c}
        let bundleEvidence=ckbSkillRenderTestBundle(bundle,rows,false);let bundleFull=ckbSkillRenderTestBundle(bundle,rows,true)
        if(bundleFull!=bundleText||bundleDisk[0]!=bundleFull+"\n"){c.diagnostic="skill_test_bundle_noncanonical";return c}
        if(benchmarkGapSha256(bundleEvidence)!=ckbSkillString(bundle,"evidenceHash")||c.testEvidenceHash!=ckbSkillString(bundle,"evidenceHash")||benchmarkGapSha256(bundleText)!=c.testBundleHash){c.diagnostic="skill_test_bundle_hash_mismatch";return c}
        let testsDiagnostic=ckbSkillValidateTests(root,bundle,rows);if(testsDiagnostic!="ok"){c.diagnostic=testsDiagnostic;return c}
        if(contextCandidate){let executionDiagnostic=ckbSkillValidateContextExecutionTree(root,rows);if(executionDiagnostic!="ok"){c.diagnostic=executionDiagnostic;return c}}
        if(c.skillContentHash!=benchmarkGapSha256(skill[0])){c.diagnostic="skill_content_hash_mismatch";return c}
        let identity=ckbSkillPart(c.id)+ckbSkillPart(c.version)+ckbSkillPart(c.title)+ckbSkillPart(c.procedure)+ckbSkillPart(c.sourceCategory)+ckbSkillPart(c.applicability)+ckbSkillPart(c.lineage)+ckbSkillPart(c.testEvidenceHash)
        if(c.candidateContentHash!=benchmarkGapSha256(identity)){c.diagnostic="skill_candidate_content_hash_mismatch";return c}
        let expectedSkill="---\nname: ${c.id}\nversion: ${c.version}\nsource: ${c.sourceCategory}\nlineage: ${c.lineage}\ncontent-hash: ${c.candidateContentHash}\n---\n\n# ${c.title}\n\nApplicability: ${c.applicability}\n\n${c.procedure}\n"
        if(c.skillContent!=expectedSkill){c.diagnostic="skill_markdown_semantic_mismatch";return c}
        let evidence=ckbSkillRenderCandidateManifest(c,false)
        let canonicalManifest=ckbSkillRenderCandidateManifest(c,true)
        if(c.artifactHash!=benchmarkGapSha256(evidence)||canonicalManifest!=manifestText||manifestDisk[0]!=canonicalManifest+"\n"){c.diagnostic="skill_candidate_artifact_hash_mismatch";return c}
        if(contextCandidate){let operationDisk=ckbSkillReadUtf8(root.join("operation.json"));if(operationDisk[1]!="ok"||operationDisk[0].contains("\r")||!operationDisk[0].endsWith("\n")){c.diagnostic="invalid_response_encoding";return c};let operation=JsonValue.fromStr(operationDisk[0].trimAscii()).asObject();if(operation.getFields().size!=6||ckbSkillString(operation,"schemaVersion")!="teacher-context-asset-operation-v1"||ckbSkillString(operation,"assetRole")!="skills"||ckbSkillString(operation,"assetId")!=c.id||!["add","replace"].contains(ckbSkillString(operation,"operation"))||ckbSkillString(operation,"newHash")!=c.candidateContentHash||(ckbSkillString(operation,"operation")=="add"&&ckbSkillString(operation,"expectedOldHash")!="")||(ckbSkillString(operation,"operation")=="replace"&&!ckbSkillHash(ckbSkillString(operation,"expectedOldHash")))){c.diagnostic="candidate_operation_invalid";return c}}
        if(ckbSkillProtected(c.id+"\n"+c.title+"\n"+c.procedure+"\n"+c.applicability+"\n"+c.skillContent)){c.diagnostic="skill_protected_artifact_leakage";return c}
        c.verified=true;c.diagnostic="ok";c
    }catch(_:Exception){c.diagnostic="malformed_json";c}
}
public func validateStudentSkillCandidate(candidate:CkbStudentSkillCandidate):String{if(candidate.verified){candidate.diagnostic}else{if(candidate.diagnostic=="ok"){"skill_candidate_unverified"}else{candidate.diagnostic}}}
public func studentSkillFixturePathsCanonical(paths:Array<String>):Bool{var previous="";for(path in paths){if(previous!=""&&previous.compare(path)!=Ordering.LT){return false};previous=path};true}
public func auditStudentSkillBundle(skills:ArrayList<CkbStudentSkillCandidate>):String{
    if(skills.size==0){return "student_skill_bundle_empty"};if(skills.size>16){return "student_skill_count_exceeded"};let ids=HashSet<String>();let contents=HashSet<String>();var bytes:Int64=0
    for(s in skills){if(!s.verified){return "student_skill_candidate_unverified"};if(ids.contains(s.id)){return "duplicate_skill_id"};if(contents.contains(s.candidateContentHash)){return "duplicate_skill_identity"};ids.add(s.id);contents.add(s.candidateContentHash);bytes+=s.skillContent.replace("\r\n","\n").replace("\r","\n").toArray().size}
    if(bytes>24576){return "student_skill_content_budget_exceeded"};for(a in skills){for(b in skills){if(a.id!=b.id&&ckbSkillRuleKey(a.procedure)==ckbSkillRuleKey(b.procedure)&&a.procedure!=b.procedure){return "conflicting_skill_rules"}}};"ok"
}
public func auditStudentSkillBundleWithKnowledge(skills:ArrayList<CkbStudentSkillCandidate>,knowledgePack:String,authority!:CangjieBenchmarkLeakageAuthority=CangjieBenchmarkLeakageAuthority()):String{let d=auditStudentSkillBundle(skills);if(d!="ok"){return d};var skillBundle="";for(s in skills){skillBundle+="\n"+s.skillContent};if(ckbSkillCombinationProtected(knowledgePack,skillBundle,"",ckbStudentVisibleProtectedArtifacts())){return "skill_knowledge_combination_leakage"};let diagnostic=cangjieStudentVisibleTextDiagnostic("skillKnowledgeCombination",skillBundle+"\n"+knowledgePack,authority:authority);if(diagnostic.ok){"ok"}else{"skill_knowledge_combination_leakage:${diagnostic.code}"}}
public func auditStudentVisibleAssetCombination(knowledgeMaterial:String,skillBundle:String,
    rulesBundle:String,protectedArtifacts:Array<String>,authority!:CangjieBenchmarkLeakageAuthority=CangjieBenchmarkLeakageAuthority()):String{
    if(protectedArtifacts.size==0){return "student_visible_protected_closure_required"}
    let combined=rulesBundle+"\n"+skillBundle+"\n"+knowledgeMaterial
    if(ckbSkillCombinationProtected(knowledgeMaterial,skillBundle,rulesBundle,protectedArtifacts)){return "student_visible_asset_combination_leakage"}
    let diagnostic=cangjieStudentVisibleTextDiagnostic("studentVisibleAssetCombination",combined,authority:authority)
    if(diagnostic.ok){"ok"}else{"student_visible_asset_combination_leakage:${diagnostic.code}"}
}
public func auditStudentVisibleAssetCombination(knowledgeMaterial:String,
    skills:ArrayList<CkbStudentSkillCandidate>,rulesBundle:String,protectedArtifacts:Array<String>,
    authority!:CangjieBenchmarkLeakageAuthority=CangjieBenchmarkLeakageAuthority()):String{
    if(protectedArtifacts.size==0){return "student_visible_protected_closure_required"}
    let historical=auditStudentSkillBundleWithKnowledge(skills,knowledgeMaterial,authority:authority)
    if(historical!="ok"){return historical}
    var skillBundle="";for(skill in skills){skillBundle+="\n"+skill.skillContent}
    auditStudentVisibleAssetCombination(knowledgeMaterial,skillBundle,rulesBundle,
        protectedArtifacts,authority:authority)
}
public func compileStudentSkillBundle(bundleVersion:String,skills:ArrayList<CkbStudentSkillCandidate>):CkbStudentSkillBundleBuild{
    let out=CkbStudentSkillBundleBuild();out.bundleVersion=bundleVersion;let d=auditStudentSkillBundle(skills);if(bundleVersion==""){out.diagnostic="skill_bundle_version_required";return out};if(d!="ok"){out.diagnostic=d;return out}
    let rows=ArrayList<String>();var bytes:Int64=0;for(s in skills){let content=s.skillContent.replace("\r\n","\n").replace("\r","\n");bytes+=content.toArray().size;let row="{\"id\":\"${ckbSkillEscape(s.id)}\",\"version\":\"${ckbSkillEscape(s.version)}\",\"title\":\"${ckbSkillEscape(s.title)}\",\"procedure\":\"${ckbSkillEscape(s.procedure)}\",\"sourceCategory\":\"${s.sourceCategory}\",\"applicability\":\"${ckbSkillEscape(s.applicability)}\",\"lineage\":\"${s.lineage}\",\"skillContentHash\":\"${s.skillContentHash}\",\"testEvidenceHash\":\"${s.testEvidenceHash}\",\"candidateContentHash\":\"${s.candidateContentHash}\",\"content\":\"${ckbSkillEscape(content)}\"}";rows.add(s.id+"\u{0000}"+row)}
    let ordered=rows.toArray();sort(ordered);var body="";for(i in 0..ordered.size){if(i>0){body+=","};body+=ordered[i].split("\u{0000}")[1]}
    let fields="\"schemaVersion\":\"ckb-student-skill-bundle-v1\",\"bundleVersion\":\"${ckbSkillEscape(bundleVersion)}\",\"skillCount\":${skills.size},\"contentBytes\":${bytes},\"skills\":[${body}]";let seed="{${fields}}";out.canonicalHash=benchmarkGapSha256(seed);out.json="{${fields},\"canonicalHash\":\"${out.canonicalHash}\"}";out.ok=true;out.diagnostic="ok";out.skillCount=Int64(skills.size);out.contentBytes=bytes;out
}
public func publishStudentSkillBundle(output:String,bundle:CkbStudentSkillBundleBuild):String{
    if(!bundle.ok){return "student_skill_bundle_not_publishable"};let path=Path(output);let bytes=(bundle.json+"\n").toArray()
    let tmp=path.parent.join(".${path.fileName}.tmp-${bundle.canonicalHash.replace("sha256:","")}");var created=false
    try{if(exists(path)){let existing=File.readFrom(path);return if(existing==bytes){"ok"}else{"student_skill_bundle_immutable_conflict"}};if(!exists(path.parent)){Directory.create(path.parent,recursive:true)};if(exists(tmp)){return "student_skill_bundle_publish_failed"};File.writeTo(tmp,bytes);created=true;if(File.readFrom(tmp)!=bytes){remove(tmp);created=false;return "student_skill_bundle_write_mismatch"};rename(tmp.toString(),to:path.toString(),overwrite:false);created=false;"ok"}catch(_:Exception){try{if(created&&exists(tmp)){remove(tmp)}}catch(_:Exception){};"student_skill_bundle_publish_failed"}
}
private func ckbSkillValidateContextExecutionTree(root:Path,rows:ArrayList<CkbSkillTestRow>):String{
    let executions=root.join("executions")
    if(!exists(executions)||FileInfo(executions).isSymbolicLink()||!FileInfo(executions).isDirectory()){return "skill_tests_tree_invalid"}
    let seen=HashSet<String>();var nonUnit:Int64=0
    for(dir in Directory.readFrom(executions)){
        if(dir.isSymbolicLink()||!dir.isDirectory()||seen.contains(dir.name)){return "skill_tests_tree_invalid"}
        seen.add(dir.name)
        let names=HashSet<String>(["fixture.json","expected.txt","actual.txt","transcript.txt","execution.json"])
        for(entry in Directory.readFrom(dir.path)){if(entry.isSymbolicLink()||!entry.isRegular()||!names.contains(entry.name)){return "skill_tests_tree_invalid"};names.remove(entry.name)}
        if(!names.isEmpty()){return "skill_tests_tree_invalid"}
        try{
            let fixture=ckbSkillReadUtf8(dir.path.join("fixture.json"));let expected=ckbSkillReadUtf8(dir.path.join("expected.txt"));let actual=ckbSkillReadUtf8(dir.path.join("actual.txt"));let transcript=ckbSkillReadUtf8(dir.path.join("transcript.txt"));let executionDisk=ckbSkillReadUtf8(dir.path.join("execution.json"))
            for(read in [fixture,expected,actual,transcript,executionDisk]){if(read[1]!="ok"||!ckbSkillExactlyOneStructuralLf(read[0])){return "invalid_response_encoding"}}
            let expectedSemantic=ckbSkillRemoveStructuralLf(expected[0]);let actualSemantic=ckbSkillRemoveStructuralLf(actual[0]);let transcriptSemantic=ckbSkillTranscriptSemantic(ckbSkillRemoveStructuralLf(transcript[0]))
            let fixtureObject=JsonValue.fromStr(fixture[0].trimAscii()).asObject();let fixtureId=ckbSkillString(fixtureObject,"fixtureId");let kind=ckbSkillString(fixtureObject,"kind");let source=ckbSkillString(fixtureObject,"sourceClass");let content=ckbSkillString(fixtureObject,"content");let expectedEvidence=ckbSkillString(fixtureObject,"expectedEvidence");let fixtureHash=benchmarkGapSha256(ckbSkillPart(fixtureId)+ckbSkillPart(kind)+ckbSkillPart(source)+ckbSkillPart(content)+ckbSkillPart(expectedEvidence));let fixtureCanonical="{\"schemaVersion\":\"teacher-asset-fixture-v1\",\"fixtureId\":\"${ckbSkillEscape(fixtureId)}\",\"kind\":\"${kind}\",\"sourceClass\":\"${source}\",\"content\":\"${ckbSkillEscape(content)}\",\"expectedEvidence\":\"${ckbSkillEscape(expectedEvidence)}\",\"fixtureHash\":\"${fixtureHash}\"}\n"
            let execution=JsonValue.fromStr(executionDisk[0].trimAscii()).asObject();let expectedHash=benchmarkGapSha256(expectedSemantic);let actualHash=benchmarkGapSha256(actualSemantic);let transcriptHash=benchmarkGapSha256(transcriptSemantic);let executor=ckbSkillString(execution,"executorKind");let provider=ckbSkillString(execution,"providerIdentityHash");let model=ckbSkillString(execution,"modelVersion");let executionCanonical="{\"schemaVersion\":\"teacher-candidate-fixture-execution-v1\",\"fixtureId\":\"${ckbSkillEscape(fixtureId)}\",\"kind\":\"${kind}\",\"sourceClass\":\"${source}\",\"fixtureHash\":\"${fixtureHash}\",\"executorKind\":\"${executor}\",\"providerIdentityHash\":\"${provider}\",\"modelVersion\":\"${ckbSkillEscape(model)}\",\"expectedEvidenceHash\":\"${expectedHash}\",\"actualEvidenceHash\":\"${actualHash}\",\"transcriptHash\":\"${transcriptHash}\",\"exitCode\":${ckbSkillInt(execution,"exitCode")},\"passed\":${ckbSkillBool(execution,"passed")}\n"
            if(fixtureObject.getFields().size!=7||fixture[0]!=fixtureCanonical||fixtureId!=dir.name||execution.getFields().size!=13||executionDisk[0]!=executionCanonical.replace("\n","}\n")||ckbSkillString(execution,"schemaVersion")!="teacher-candidate-fixture-execution-v1"||ckbSkillString(execution,"fixtureId")!=fixtureId||ckbSkillString(execution,"kind")!=kind||ckbSkillString(execution,"sourceClass")!=source||ckbSkillString(execution,"fixtureHash")!=fixtureHash||!["unit","positive","negative","boundary","generalization"].contains(kind)||!["official","community","non_humaneval_experiment"].contains(source)||(kind=="generalization"&&source!="non_humaneval_experiment")||!["fake_contract","student_completion_non_humaneval"].contains(executor)||!ckbSkillHash(provider)||model==""||ckbSkillString(execution,"expectedEvidenceHash")!=expectedHash||ckbSkillString(execution,"actualEvidenceHash")!=actualHash||ckbSkillString(execution,"transcriptHash")!=transcriptHash||ckbSkillInt(execution,"exitCode")!=0||!ckbSkillBool(execution,"passed")||expectedEvidence!=expectedSemantic||expectedSemantic!=actualSemantic||ckbSkillProtected(content+expectedSemantic+actualSemantic+transcriptSemantic)){return "candidate_test_evidence_invalid"}
            if(kind=="unit"){continue}
            var matched=false
            for(row in rows){if(row.testId==fixtureId){if(matched||row.kind!=kind||row.sourceClass!=source||row.fixturePath!="tests/${fixtureId}.txt"||row.resultHash!=expectedHash){return "candidate_test_evidence_invalid"};matched=true}}
            if(!matched){return "candidate_test_evidence_invalid"};nonUnit+=1
            let flat=ckbSkillReadUtf8(root.join("tests/${fixtureId}.txt"));if(flat[1]!="ok"||flat[0]!="{\"schemaVersion\":\"cangjie-teacher-skill-fixture-v1\",\"task\":\"${ckbSkillEscape(content)}\",\"resultEvidence\":\"${ckbSkillEscape(expectedEvidence)}\"}\n"){return "candidate_test_evidence_invalid"}
        }catch(_:Exception){return "candidate_test_evidence_invalid"}
    }
    if(nonUnit!=rows.size){"candidate_test_evidence_invalid"}else{"ok"}
}
private func ckbSkillValidateTests(root:Path,bundle:JsonObject,rows:ArrayList<CkbSkillTestRow>):String{
    if(ckbSkillString(bundle,"schemaVersion")!="cangjie-teacher-skill-test-bundle-v1"||ckbSkillString(bundle,"testsRoot")!="tests"){return "skill_test_bundle_identity_invalid"}
    let files=ArrayList<String>();if(!ckbSkillCollectFiles(root.join("tests"),"tests",files)){return "skill_tests_tree_invalid"};let paths=files.toArray();sort(paths);let declared=HashSet<String>();let ids=HashSet<String>();let fixturePaths=ArrayList<String>();for(row in rows){fixturePaths.add(row.fixturePath)};let fixtureDiagnostic=ckbStudentSkillFixturePathUniquenessDiagnostic(fixturePaths.toArray());if(fixtureDiagnostic!="ok"){return fixtureDiagnostic};var p:Int64=0;var n:Int64=0;var b:Int64=0;var g:Int64=0;var seed=""
    for(row in rows){if(ids.contains(row.testId)||!paths.contains(row.fixturePath)||!ckbSkillSafeRelative(row.fixturePath)||row.targetVersion!=ckbSkillString(bundle,"candidateVersion")||!["positive","negative","boundary","generalization"].contains(row.kind)||!["official","community","non_humaneval_experiment"].contains(row.sourceClass)||(row.kind=="generalization"&&row.sourceClass!="non_humaneval_experiment")||row.benchmarkDerived||!row.passed){return "skill_test_row_invalid"};ids.add(row.testId);declared.add(row.fixturePath);let read=ckbSkillReadUtf8(root.join(row.fixturePath));if(read[1]!="ok"||benchmarkGapSha256(read[0])!=row.fixtureHash){return "skill_fixture_hash_mismatch"};try{let fixture=JsonValue.fromStr(read[0]).asObject();if(benchmarkGapSha256(ckbSkillString(fixture,"resultEvidence"))!=row.resultHash||ckbSkillProtected(ckbSkillString(fixture,"task")+"\n"+ckbSkillString(fixture,"resultEvidence"))){return "skill_test_result_hash_mismatch"}}catch(_:Exception){return "skill_fixture_malformed"};if(row.kind=="positive"){p+=1}else if(row.kind=="negative"){n+=1}else if(row.kind=="boundary"){b+=1}else{g+=1}}
    for(path in paths){if(!declared.contains(path)){return "skill_tests_tree_undeclared_file"};let read=ckbSkillReadUtf8(root.join(path));if(read[1]!="ok"){return "invalid_response_encoding"};let hash=benchmarkGapSha256(read[0]);seed+=ckbSkillPart(path)+ckbSkillPart(hash)}
    if(benchmarkGapSha256(seed)!=ckbSkillString(bundle,"testsTreeHash")){return "skill_tests_tree_hash_mismatch"}
    if(p!=ckbSkillInt(bundle,"positiveCount")||n!=ckbSkillInt(bundle,"negativeCount")||b!=ckbSkillInt(bundle,"boundaryCount")||g!=ckbSkillInt(bundle,"generalizationCount")||p<1||n<1||b<1||g<3){return "skill_test_category_count_invalid"};"ok"
}
public func ckbStudentSkillFixturePathUniquenessDiagnostic(paths:Array<String>):String{let seen=HashSet<String>();for(path in paths){if(seen.contains(path)){return "duplicate_skill_fixture_path"};seen.add(path)};"ok"}
private func ckbSkillCollectFiles(root:Path,relative:String,out:ArrayList<String>):Bool{try{if(!exists(root)||FileInfo(root).isSymbolicLink()||!FileInfo(root).isDirectory()){return false};for(e in Directory.readFrom(root)){if(e.isSymbolicLink()){return false};let child="${relative}/${e.name}";if(e.isDirectory()){if(!ckbSkillCollectFiles(e.path,child,out)){return false}}else if(e.isRegular()){out.add(child)}else{return false}};true}catch(_:Exception){false}}
private func ckbSkillRenderTestBundle(bundle:JsonObject,rows:ArrayList<CkbSkillTestRow>,hash:Bool):String{var body="";for(i in 0..rows.size){if(i>0){body+=","};let r=rows[i];body+="{\"testId\":\"${ckbSkillEscape(r.testId)}\",\"kind\":\"${r.kind}\",\"fixturePath\":\"${ckbSkillEscape(r.fixturePath)}\",\"fixtureHash\":\"${r.fixtureHash}\",\"targetVersion\":\"${ckbSkillEscape(r.targetVersion)}\",\"sourceClass\":\"${r.sourceClass}\",\"benchmarkDerived\":${r.benchmarkDerived},\"passed\":${r.passed},\"resultHash\":\"${r.resultHash}\"}"};let fields="\"schemaVersion\":\"${ckbSkillString(bundle,"schemaVersion")}\",\"candidateId\":\"${ckbSkillEscape(ckbSkillString(bundle,"candidateId"))}\",\"candidateVersion\":\"${ckbSkillEscape(ckbSkillString(bundle,"candidateVersion"))}\",\"lineage\":\"${ckbSkillString(bundle,"lineage")}\",\"testsRoot\":\"${ckbSkillString(bundle,"testsRoot")}\",\"testsTreeHash\":\"${ckbSkillString(bundle,"testsTreeHash")}\",\"positiveCount\":${ckbSkillInt(bundle,"positiveCount")},\"negativeCount\":${ckbSkillInt(bundle,"negativeCount")},\"boundaryCount\":${ckbSkillInt(bundle,"boundaryCount")},\"generalizationCount\":${ckbSkillInt(bundle,"generalizationCount")},\"tests\":[${body}]";if(hash){"{${fields},\"evidenceHash\":\"${ckbSkillString(bundle,"evidenceHash")}\"}"}else{"{${fields}}"}}
private func ckbSkillRenderCandidateManifest(c:CkbStudentSkillCandidate,hash:Bool):String{let fields="\"schemaVersion\":\"cangjie-teacher-skill-candidate-v1\",\"id\":\"${ckbSkillEscape(c.id)}\",\"version\":\"${ckbSkillEscape(c.version)}\",\"title\":\"${ckbSkillEscape(c.title)}\",\"procedure\":\"${ckbSkillEscape(c.procedure)}\",\"sourceCategory\":\"${c.sourceCategory}\",\"applicability\":\"${ckbSkillEscape(c.applicability)}\",\"lineage\":\"${c.lineage}\",\"skillPath\":\"SKILL.md\",\"skillContentHash\":\"${c.skillContentHash}\",\"testBundlePath\":\"test-bundle.json\",\"testBundleHash\":\"${c.testBundleHash}\",\"testEvidenceHash\":\"${c.testEvidenceHash}\",\"candidateContentHash\":\"${c.candidateContentHash}\"";if(hash){"{${fields},\"artifactHash\":\"${c.artifactHash}\"}"}else{"{${fields}}"}}
private func ckbSkillReadUtf8(path:Path):(String,String){try{(String.fromUtf8(File.readFrom(path)),"ok")}catch(_:Exception){("","invalid_response_encoding")}}
private func ckbSkillExactlyOneStructuralLf(v:String):Bool{v.endsWith("\n")&&!v.endsWith("\n\n")&&!v.contains("\r")}
private func ckbSkillRemoveStructuralLf(v:String):String{let runes=v.toRuneArray();var out="";for(i in 0..(runes.size-1)){out+=runes[i].toString()};out}
private func ckbSkillTranscriptSemantic(v:String):String{let normalized=v.replace("\r\n","\n").replace("\r","\n");let runes=normalized.toRuneArray();var end=runes.size;while(end>0&&runes[end-1]==r'\n'){end-=1};var out="";for(i in 0..end){out+=runes[i].toString()};out}
private func ckbSkillString(o:JsonObject,k:String):String{o.get(k).getOrThrow().asString().getValue()}
private func ckbSkillInt(o:JsonObject,k:String):Int64{o.get(k).getOrThrow().asInt().getValue()}
private func ckbSkillBool(o:JsonObject,k:String):Bool{o.get(k).getOrThrow().asBool().getValue()}
private func ckbSkillHash(v:String):Bool{let runes=v.toRuneArray();if(runes.size!=71||!v.startsWith("sha256:")){return false};for(i in 7..71){let rune=runes[i];if(!((rune>=r'0'&&rune<=r'9')||(rune>=r'a'&&rune<=r'f'))){return false}};true}
private func ckbSkillCompactAudit(v:String):String{v.replace("\n","").replace("\r","").replace("\t","").replace(" ","")}
private func ckbSkillCombinationProtected(knowledge:String,skills:String,rules:String,protectedArtifacts:Array<String>):Bool{
    let knowledgeCompact=ckbSkillCompactAudit(knowledge.toAsciiLower())
    let authoredCompact=ckbSkillCompactAudit((rules+"\n"+skills).toAsciiLower())
    let combinedCompact=ckbSkillCompactAudit((rules+"\n"+skills+"\n"+knowledge).toAsciiLower())
    for(raw in protectedArtifacts){
        let marker=ckbSkillCompactAudit(raw.trimAscii().toAsciiLower())
        if(marker==""){continue}
        let inKnowledge=knowledgeCompact.contains(marker)
        let inAuthored=authoredCompact.contains(marker)
        if(inAuthored||inKnowledge&&!ckbSkillKnowledgeContextMarkerAllowed(marker)||
            combinedCompact.contains(marker)&&!inKnowledge&&!inAuthored){return true}
    }
    false
}
private func ckbSkillKnowledgeContextMarkerAllowed(marker:String):Bool{
    ["expectedoutput","authorization:","authorization","bearer","api_key","token=","password","secret",
        "/users/","/home/","/private/","runcommand","readtest","readreference"].contains(marker)
}
private func ckbSkillPart(v:String):String{"${v.toArray().size}:${v}"}
private func ckbSkillSafeRelative(v:String):Bool{if(!v.startsWith("tests/")||v.startsWith("/")||v.contains("\\")||v.endsWith("/")){return false};for(p in v.split("/")){if(p==""||p=="."||p==".."){return false}};true}
public func ckbStudentVisibleProtectedArtifacts():Array<String>{["cj-humaneval-","humaneval/","caseid","题号","本题","canonical_solution","reference solution","expectedoutput","hidden_test","testmain.cj","solution_cj","/reference/","authorization:","authorization","bearer ","api_key","token=","password","secret","/users/","/home/","/private/","ignore protocol","override protocol","ignore public task","override public task","change public function signature","run command","read test","read reference"]}
public func ckbStudentVisibleAssetForbidden(v:String):Bool{let x=v.toAsciiLower();for(m in ckbStudentVisibleProtectedArtifacts()){if(x.contains(m)){return true}};false}
private func ckbSkillProtected(v:String):Bool{ckbStudentVisibleAssetForbidden(v)}
private func ckbSkillRuleKey(v:String):String{v.toAsciiLower().replace("must not","must").replace("never","must").replace("do not","do").replace(" ","")}
private func ckbSkillEscape(v:String):String{v.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t")}
