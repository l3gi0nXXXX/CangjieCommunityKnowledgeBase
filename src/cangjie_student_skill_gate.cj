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
        let expected=HashSet<String>(["SKILL.md","candidate-manifest.json","test-bundle.json","tests"])
        for(entry in Directory.readFrom(root)){if(entry.isSymbolicLink()||!expected.contains(entry.name)){c.diagnostic="skill_candidate_directory_entry_invalid";return c};expected.remove(entry.name)}
        if(!expected.isEmpty()){c.diagnostic="skill_candidate_directory_incomplete";return c}
        for(name in ["SKILL.md","candidate-manifest.json","test-bundle.json"]){let p=root.join(name);if(FileInfo(p).isSymbolicLink()||!FileInfo(p).isRegular()){c.diagnostic="skill_candidate_regular_file_required";return c}}
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
        let bundleText=bundleDisk[0].trimAscii();let bundle=JsonValue.fromStr(bundleText).asObject();if(bundle.getFields().size!=12){c.diagnostic="skill_test_bundle_fields_invalid";return c}
        if(ckbSkillString(bundle,"candidateId")!=c.id||ckbSkillString(bundle,"candidateVersion")!=c.version||ckbSkillString(bundle,"lineage")!=c.lineage){c.diagnostic="skill_test_bundle_candidate_mismatch";return c}
        let rows=ArrayList<CkbSkillTestRow>();for(v in bundle.get("tests").getOrThrow().asArray().getItems()){let o=v.asObject();if(o.getFields().size!=9){c.diagnostic="skill_test_row_fields_invalid";return c};let row=CkbSkillTestRow();row.testId=ckbSkillString(o,"testId");row.kind=ckbSkillString(o,"kind");row.fixturePath=ckbSkillString(o,"fixturePath");row.fixtureHash=ckbSkillString(o,"fixtureHash");row.targetVersion=ckbSkillString(o,"targetVersion");row.sourceClass=ckbSkillString(o,"sourceClass");row.benchmarkDerived=ckbSkillBool(o,"benchmarkDerived");row.passed=ckbSkillBool(o,"passed");row.resultHash=ckbSkillString(o,"resultHash");rows.add(row)}
        let bundleEvidence=ckbSkillRenderTestBundle(bundle,rows,false);let bundleFull=ckbSkillRenderTestBundle(bundle,rows,true)
        if(bundleFull!=bundleText||bundleDisk[0]!=bundleFull+"\n"){c.diagnostic="skill_test_bundle_noncanonical";return c}
        if(benchmarkGapSha256(bundleEvidence)!=ckbSkillString(bundle,"evidenceHash")||c.testEvidenceHash!=ckbSkillString(bundle,"evidenceHash")||benchmarkGapSha256(bundleText)!=c.testBundleHash){c.diagnostic="skill_test_bundle_hash_mismatch";return c}
        let testsDiagnostic=ckbSkillValidateTests(root,bundle,rows);if(testsDiagnostic!="ok"){c.diagnostic=testsDiagnostic;return c}
        if(c.skillContentHash!=benchmarkGapSha256(skill[0])){c.diagnostic="skill_content_hash_mismatch";return c}
        let identity=ckbSkillPart(c.id)+ckbSkillPart(c.version)+ckbSkillPart(c.title)+ckbSkillPart(c.procedure)+ckbSkillPart(c.sourceCategory)+ckbSkillPart(c.applicability)+ckbSkillPart(c.lineage)+ckbSkillPart(c.testEvidenceHash)
        if(c.candidateContentHash!=benchmarkGapSha256(identity)){c.diagnostic="skill_candidate_content_hash_mismatch";return c}
        let expectedSkill="---\nname: ${c.id}\nversion: ${c.version}\nsource: ${c.sourceCategory}\nlineage: ${c.lineage}\ncontent-hash: ${c.candidateContentHash}\n---\n\n# ${c.title}\n\nApplicability: ${c.applicability}\n\n${c.procedure}\n"
        if(c.skillContent!=expectedSkill){c.diagnostic="skill_markdown_semantic_mismatch";return c}
        let evidence=ckbSkillRenderCandidateManifest(c,false)
        let canonicalManifest=ckbSkillRenderCandidateManifest(c,true)
        if(c.artifactHash!=benchmarkGapSha256(evidence)||canonicalManifest!=manifestText||manifestDisk[0]!=canonicalManifest+"\n"){c.diagnostic="skill_candidate_artifact_hash_mismatch";return c}
        if(ckbSkillProtected(c.id+"\n"+c.title+"\n"+c.procedure+"\n"+c.applicability+"\n"+c.skillContent)){c.diagnostic="skill_protected_artifact_leakage";return c}
        c.verified=true;c.diagnostic="ok";c
    }catch(_:Exception){c.diagnostic="malformed_json";c}
}
public func validateStudentSkillCandidate(candidate:CkbStudentSkillCandidate):String{if(candidate.verified){candidate.diagnostic}else{if(candidate.diagnostic=="ok"){"skill_candidate_unverified"}else{candidate.diagnostic}}}
public func auditStudentSkillBundle(skills:ArrayList<CkbStudentSkillCandidate>):String{
    if(skills.size==0){return "student_skill_bundle_empty"};if(skills.size>16){return "student_skill_count_exceeded"};let ids=HashSet<String>();let contents=HashSet<String>();var bytes:Int64=0
    for(s in skills){if(!s.verified){return "student_skill_candidate_unverified"};if(ids.contains(s.id)){return "duplicate_skill_id"};if(contents.contains(s.candidateContentHash)){return "duplicate_skill_identity"};ids.add(s.id);contents.add(s.candidateContentHash);bytes+=s.skillContent.replace("\r\n","\n").replace("\r","\n").toArray().size}
    if(bytes>24576){return "student_skill_content_budget_exceeded"};for(a in skills){for(b in skills){if(a.id!=b.id&&ckbSkillRuleKey(a.procedure)==ckbSkillRuleKey(b.procedure)&&a.procedure!=b.procedure){return "conflicting_skill_rules"}}};"ok"
}
public func auditStudentSkillBundleWithKnowledge(skills:ArrayList<CkbStudentSkillCandidate>,knowledgePack:String,authority!:CangjieBenchmarkLeakageAuthority=CangjieBenchmarkLeakageAuthority()):String{let d=auditStudentSkillBundle(skills);if(d!="ok"){return d};var combined=knowledgePack;for(s in skills){combined+="\n"+s.skillContent};if(ckbSkillProtected(combined)){return "skill_knowledge_combination_leakage"};let diagnostic=cangjieStudentVisibleTextDiagnostic("skillKnowledgeCombination",combined,authority:authority);if(diagnostic.ok){"ok"}else{"skill_knowledge_combination_leakage:${diagnostic.code}"}}
public func compileStudentSkillBundle(bundleVersion:String,skills:ArrayList<CkbStudentSkillCandidate>):CkbStudentSkillBundleBuild{
    let out=CkbStudentSkillBundleBuild();out.bundleVersion=bundleVersion;let d=auditStudentSkillBundle(skills);if(bundleVersion==""){out.diagnostic="skill_bundle_version_required";return out};if(d!="ok"){out.diagnostic=d;return out}
    let rows=ArrayList<String>();var bytes:Int64=0;for(s in skills){let content=s.skillContent.replace("\r\n","\n").replace("\r","\n");bytes+=content.toArray().size;let row="{\"id\":\"${ckbSkillEscape(s.id)}\",\"version\":\"${ckbSkillEscape(s.version)}\",\"title\":\"${ckbSkillEscape(s.title)}\",\"procedure\":\"${ckbSkillEscape(s.procedure)}\",\"sourceCategory\":\"${s.sourceCategory}\",\"applicability\":\"${ckbSkillEscape(s.applicability)}\",\"lineage\":\"${s.lineage}\",\"skillContentHash\":\"${s.skillContentHash}\",\"testEvidenceHash\":\"${s.testEvidenceHash}\",\"candidateContentHash\":\"${s.candidateContentHash}\",\"content\":\"${ckbSkillEscape(content)}\"}";rows.add(s.id+"\u{0000}"+row)}
    let ordered=rows.toArray();sort(ordered);var body="";for(i in 0..ordered.size){if(i>0){body+=","};body+=ordered[i].split("\u{0000}")[1]}
    let fields="\"schemaVersion\":\"ckb-student-skill-bundle-v1\",\"bundleVersion\":\"${ckbSkillEscape(bundleVersion)}\",\"skillCount\":${skills.size},\"contentBytes\":${bytes},\"skills\":[${body}]";let seed="{${fields}}";out.canonicalHash=benchmarkGapSha256(seed);out.json="{${fields},\"canonicalHash\":\"${out.canonicalHash}\"}";out.ok=true;out.diagnostic="ok";out.skillCount=Int64(skills.size);out.contentBytes=bytes;out
}
public func publishStudentSkillBundle(output:String,bundle:CkbStudentSkillBundleBuild):String{
    if(!bundle.ok){return "student_skill_bundle_not_publishable"};let path=Path(output);let bytes=(bundle.json+"\n").toArray()
    try{if(exists(path)){let existing=File.readFrom(path);return if(existing==bytes){"ok"}else{"student_skill_bundle_immutable_conflict"}};if(!exists(path.parent)){Directory.create(path.parent,recursive:true)};let tmp=path.parent.join(".${path.fileName}.tmp-${bundle.canonicalHash.replace("sha256:","")}");File.writeTo(tmp,bytes);if(File.readFrom(tmp)!=bytes){remove(tmp);return "student_skill_bundle_write_mismatch"};rename(tmp.toString(),to:path.toString(),overwrite:false);"ok"}catch(_:Exception){"student_skill_bundle_publish_failed"}
}
private func ckbSkillValidateTests(root:Path,bundle:JsonObject,rows:ArrayList<CkbSkillTestRow>):String{
    if(ckbSkillString(bundle,"schemaVersion")!="cangjie-teacher-skill-test-bundle-v1"||ckbSkillString(bundle,"testsRoot")!="tests"){return "skill_test_bundle_identity_invalid"}
    let files=ArrayList<String>();if(!ckbSkillCollectFiles(root.join("tests"),"tests",files)){return "skill_tests_tree_invalid"};let paths=files.toArray();sort(paths);let declared=HashSet<String>();let ids=HashSet<String>();var p:Int64=0;var n:Int64=0;var b:Int64=0;var g:Int64=0;var seed=""
    for(row in rows){if(ids.contains(row.testId)||!paths.contains(row.fixturePath)||!ckbSkillSafeRelative(row.fixturePath)||!["positive","negative","boundary","generalization"].contains(row.kind)||!["official","community","non_humaneval_experiment"].contains(row.sourceClass)||(row.kind=="generalization"&&row.sourceClass!="non_humaneval_experiment")||row.benchmarkDerived||!row.passed){return "skill_test_row_invalid"};ids.add(row.testId);declared.add(row.fixturePath);let read=ckbSkillReadUtf8(root.join(row.fixturePath));if(read[1]!="ok"||benchmarkGapSha256(read[0])!=row.fixtureHash){return "skill_fixture_hash_mismatch"};try{let fixture=JsonValue.fromStr(read[0]).asObject();if(benchmarkGapSha256(ckbSkillString(fixture,"resultEvidence"))!=row.resultHash||ckbSkillProtected(ckbSkillString(fixture,"task")+"\n"+ckbSkillString(fixture,"resultEvidence"))){return "skill_test_result_hash_mismatch"}}catch(_:Exception){return "skill_fixture_malformed"};if(row.kind=="positive"){p+=1}else if(row.kind=="negative"){n+=1}else if(row.kind=="boundary"){b+=1}else{g+=1}}
    for(path in paths){if(!declared.contains(path)){return "skill_tests_tree_undeclared_file"};let read=ckbSkillReadUtf8(root.join(path));if(read[1]!="ok"){return "invalid_response_encoding"};let hash=benchmarkGapSha256(read[0]);seed+=ckbSkillPart(path)+ckbSkillPart(hash)}
    if(benchmarkGapSha256(seed)!=ckbSkillString(bundle,"testsTreeHash")){return "skill_tests_tree_hash_mismatch"}
    if(p!=ckbSkillInt(bundle,"positiveCount")||n!=ckbSkillInt(bundle,"negativeCount")||b!=ckbSkillInt(bundle,"boundaryCount")||g!=ckbSkillInt(bundle,"generalizationCount")||p<1||n<1||b<1||g<3){return "skill_test_category_count_invalid"};"ok"
}
private func ckbSkillCollectFiles(root:Path,relative:String,out:ArrayList<String>):Bool{try{if(!exists(root)||FileInfo(root).isSymbolicLink()||!FileInfo(root).isDirectory()){return false};for(e in Directory.readFrom(root)){if(e.isSymbolicLink()){return false};let child="${relative}/${e.name}";if(e.isDirectory()){if(!ckbSkillCollectFiles(e.path,child,out)){return false}}else if(e.isRegular()){out.add(child)}else{return false}};true}catch(_:Exception){false}}
private func ckbSkillRenderTestBundle(bundle:JsonObject,rows:ArrayList<CkbSkillTestRow>,hash:Bool):String{var body="";for(i in 0..rows.size){if(i>0){body+=","};let r=rows[i];body+="{\"testId\":\"${ckbSkillEscape(r.testId)}\",\"kind\":\"${r.kind}\",\"fixturePath\":\"${ckbSkillEscape(r.fixturePath)}\",\"fixtureHash\":\"${r.fixtureHash}\",\"targetVersion\":\"${ckbSkillEscape(r.targetVersion)}\",\"sourceClass\":\"${r.sourceClass}\",\"benchmarkDerived\":${r.benchmarkDerived},\"passed\":${r.passed},\"resultHash\":\"${r.resultHash}\"}"};let fields="\"schemaVersion\":\"${ckbSkillString(bundle,"schemaVersion")}\",\"candidateId\":\"${ckbSkillEscape(ckbSkillString(bundle,"candidateId"))}\",\"candidateVersion\":\"${ckbSkillEscape(ckbSkillString(bundle,"candidateVersion"))}\",\"lineage\":\"${ckbSkillString(bundle,"lineage")}\",\"testsRoot\":\"${ckbSkillString(bundle,"testsRoot")}\",\"testsTreeHash\":\"${ckbSkillString(bundle,"testsTreeHash")}\",\"positiveCount\":${ckbSkillInt(bundle,"positiveCount")},\"negativeCount\":${ckbSkillInt(bundle,"negativeCount")},\"boundaryCount\":${ckbSkillInt(bundle,"boundaryCount")},\"generalizationCount\":${ckbSkillInt(bundle,"generalizationCount")},\"tests\":[${body}]";if(hash){"{${fields},\"evidenceHash\":\"${ckbSkillString(bundle,"evidenceHash")}\"}"}else{"{${fields}}"}}
private func ckbSkillRenderCandidateManifest(c:CkbStudentSkillCandidate,hash:Bool):String{let fields="\"schemaVersion\":\"cangjie-teacher-skill-candidate-v1\",\"id\":\"${ckbSkillEscape(c.id)}\",\"version\":\"${ckbSkillEscape(c.version)}\",\"title\":\"${ckbSkillEscape(c.title)}\",\"procedure\":\"${ckbSkillEscape(c.procedure)}\",\"sourceCategory\":\"${c.sourceCategory}\",\"applicability\":\"${ckbSkillEscape(c.applicability)}\",\"lineage\":\"${c.lineage}\",\"skillPath\":\"SKILL.md\",\"skillContentHash\":\"${c.skillContentHash}\",\"testBundlePath\":\"test-bundle.json\",\"testBundleHash\":\"${c.testBundleHash}\",\"testEvidenceHash\":\"${c.testEvidenceHash}\",\"candidateContentHash\":\"${c.candidateContentHash}\"";if(hash){"{${fields},\"artifactHash\":\"${c.artifactHash}\"}"}else{"{${fields}}"}}
private func ckbSkillReadUtf8(path:Path):(String,String){try{(String.fromUtf8(File.readFrom(path)),"ok")}catch(_:Exception){("","invalid_response_encoding")}}
private func ckbSkillString(o:JsonObject,k:String):String{o.get(k).getOrThrow().asString().getValue()}
private func ckbSkillInt(o:JsonObject,k:String):Int64{o.get(k).getOrThrow().asInt().getValue()}
private func ckbSkillBool(o:JsonObject,k:String):Bool{o.get(k).getOrThrow().asBool().getValue()}
private func ckbSkillPart(v:String):String{"${v.toArray().size}:${v}"}
private func ckbSkillSafeRelative(v:String):Bool{if(!v.startsWith("tests/")||v.startsWith("/")||v.contains("\\")||v.endsWith("/")){return false};for(p in v.split("/")){if(p==""||p=="."||p==".."){return false}};true}
private func ckbSkillProtected(v:String):Bool{let x=v.toAsciiLower();for(m in ["cj-humaneval-","humaneval/","canonical_solution","hidden_test","testmain.cj","/reference/","authorization:","bearer ","api_key","token=","password","/users/","/private/"]){if(x.contains(m)){return true}};false}
private func ckbSkillRuleKey(v:String):String{v.toAsciiLower().replace("must not","must").replace("never","must").replace("do not","do").replace(" ","")}
private func ckbSkillEscape(v:String):String{v.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t")}
