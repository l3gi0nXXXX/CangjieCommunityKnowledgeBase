package cangjie_community_knowledge_base
import std.collection.ArrayList
import std.fs.{File,Path}
import stdx.encoding.json.*

public func parseStudentSkillBundle(bytes:Array<UInt8>):CkbStudentSkillBundleBuild{
    let failed=CkbStudentSkillBundleBuild();let raw=try{String.fromUtf8(bytes)}catch(_:Exception){failed.diagnostic="invalid_response_encoding";return failed}
    try{let root=JsonValue.fromStr(raw.trimAscii()).asObject();if(root.getFields().size!=6||ckbBundleString(root,"schemaVersion")!="ckb-student-skill-bundle-v1"){failed.diagnostic="skill_bundle_schema_fields_invalid";return failed};let candidates=ArrayList<CkbStudentSkillCandidate>()
        for(v in root.get("skills").getOrThrow().asArray().getItems()){let o=v.asObject();if(o.getFields().size!=11){failed.diagnostic="skill_entry_schema_fields_invalid";return failed};let c=CkbStudentSkillCandidate();c.id=ckbBundleString(o,"id");c.version=ckbBundleString(o,"version");c.title=ckbBundleString(o,"title");c.procedure=ckbBundleString(o,"procedure");c.sourceCategory=ckbBundleString(o,"sourceCategory");c.applicability=ckbBundleString(o,"applicability");c.lineage=ckbBundleString(o,"lineage");c.skillContentHash=ckbBundleString(o,"skillContentHash");c.testEvidenceHash=ckbBundleString(o,"testEvidenceHash");c.candidateContentHash=ckbBundleString(o,"candidateContentHash");c.skillContent=ckbBundleString(o,"content");let identity=ckbBundlePart(c.id)+ckbBundlePart(c.version)+ckbBundlePart(c.title)+ckbBundlePart(c.procedure)+ckbBundlePart(c.sourceCategory)+ckbBundlePart(c.applicability)+ckbBundlePart(c.lineage)+ckbBundlePart(c.testEvidenceHash);if(c.skillContent.contains("\r")||benchmarkGapSha256(c.skillContent)!=c.skillContentHash||benchmarkGapSha256(identity)!=c.candidateContentHash||c.lineage!="independent"||c.sourceCategory!="general_engineering"){failed.diagnostic="skill_entry_identity_invalid";return failed};c.verified=true;c.diagnostic="ok";candidates.add(c)}
        let built=compileStudentSkillBundle(ckbBundleString(root,"bundleVersion"),candidates);if(!built.ok){return built};if(built.json!=raw.trimAscii()||built.skillCount!=root.get("skillCount").getOrThrow().asInt().getValue()||built.contentBytes!=root.get("contentBytes").getOrThrow().asInt().getValue()||built.canonicalHash!=ckbBundleString(root,"canonicalHash")){failed.diagnostic="skill_bundle_canonical_hash_mismatch";return failed};built
    }catch(_:Exception){failed.diagnostic="malformed_json";failed}
}
public func validateStudentSkillBundle(bundle:CkbStudentSkillBundleBuild):String{if(!bundle.ok){bundle.diagnostic}else if(bundle.skillCount<1||bundle.skillCount>16){"student_skill_count_invalid"}else if(bundle.contentBytes>24576){"student_skill_content_budget_exceeded"}else{"ok"}}
public func freezeStudentSkillBundle(input:String,output:String):String{let bytes=try{File.readFrom(Path(input))}catch(_:Exception){return "student_skill_bundle_read_failed"};let parsed=parseStudentSkillBundle(bytes);if(validateStudentSkillBundle(parsed)!="ok"){return parsed.diagnostic};publishStudentSkillBundle(output,parsed)}
public func renderStudentSkillBundle(bundle:CkbStudentSkillBundleBuild):String{if(bundle.ok){bundle.json}else{""}}
private func ckbBundleString(o:JsonObject,k:String):String{o.get(k).getOrThrow().asString().getValue()}
private func ckbBundlePart(v:String):String{"${v.toArray().size}:${v}"}

