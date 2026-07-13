package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashSet}
import stdx.encoding.json.*

public class CangjieKnowledgeAtomTestBundleResult { public var ok=false;public var diagnostic="invalid_atom_test_bundle";public var total:Int64=0;public var passed:Int64=0;public var failed:Int64=0;public init(){} }

public func validateKnowledgeAtomTestBundle(bundleJson:String):CangjieKnowledgeAtomTestBundleResult{
    let result=CangjieKnowledgeAtomTestBundleResult();let raw=bundleJson.trimAscii()
    if(raw==""){result.diagnostic="atom_test_bundle_required";return result};if(raw.toRuneArray().size>262144){result.diagnostic="atom_test_bundle_too_large";return result}
    try{let object=JsonValue.fromStr(raw).asObject();let atomId=atomJsonString(object,"atomId");let sourceClass=atomJsonString(object,"sourceClass").toAsciiLower();let citation=atomJsonString(object,"citation").toAsciiLower();let targetVersion=atomJsonString(object,"targetVersion");let candidateHash=atomJsonString(object,"candidateHash");let knowledgeText=atomJsonString(object,"knowledgeText")
        if(atomId==""||targetVersion==""||candidateHash==""||knowledgeText==""){result.diagnostic="atom_identity_evidence_required";return result}
        if(sourceClass!="official"&&sourceClass!="approved_trusted"){result.diagnostic="atom_source_class_not_allowed";return result}
        if(sourceClass=="official"&&!citation.startsWith("https://docs.cangjie-lang.cn/")){result.diagnostic="atom_citation_not_allowed";return result}
        if(sourceClass=="approved_trusted"&&!citation.startsWith("https://github.com/dyingchinese/cangjie-stdx")){result.diagnostic="atom_citation_not_allowed";return result}
        if(atomForbiddenContent(raw.toAsciiLower())){result.diagnostic="atom_content_contamination";return result}
        match(object.get("purificationPassed")){case Some(value)=>if(!value.asBool().getValue()){result.diagnostic="atom_purification_required";return result};case None=>result.diagnostic="atom_purification_required";return result}
        let categories=HashSet<String>();match(object.get("tests")){case Some(value)=>for(entry in value.asArray().getItems()){let test=entry.asObject();let category=atomJsonString(test,"category").toAsciiLower();let operation=atomJsonString(test,"operation").toAsciiLower();if(category!="positive"&&category!="negative"&&category!="boundary"){result.diagnostic="atom_test_category_invalid";return result};if(operation!="rune_count"&&operation!="contains"&&operation!="arraylist_size"){result.diagnostic="atom_test_operation_not_allowed";return result};categories.add(category);result.total+=1};case None=>result.diagnostic="atom_tests_required";return result}
        if(!categories.contains("positive")||!categories.contains("negative")||!categories.contains("boundary")){result.diagnostic="missing_atom_test_category";return result};result.ok=true;result.diagnostic="ok";result
    }catch(_:Exception){result.diagnostic="malformed_atom_test_bundle";result}
}
public func runKnowledgeAtomTestBundle(bundleJson:String):CangjieKnowledgeAtomTestBundleResult{let result=validateKnowledgeAtomTestBundle(bundleJson);if(!result.ok){return result};result.passed=0;try{let tests=JsonValue.fromStr(bundleJson.trimAscii()).asObject().get("tests").getOrThrow().asArray().getItems();for(entry in tests){let test=entry.asObject();let operation=atomJsonString(test,"operation").toAsciiLower();let input=atomJsonString(test,"input");let expected=atomJsonString(test,"expected");let actual=if(operation=="rune_count"){"${input.toRuneArray().size}"}else if(operation=="contains"){"${input.contains(atomJsonString(test,"needle"))}"}else{try{"${JsonValue.fromStr(input).asArray().getItems().size}"}catch(_:Exception){"invalid_input"}};if(actual==expected){result.passed+=1}else{result.failed+=1}};result.ok=result.failed==0&&result.passed==result.total;result.diagnostic=if(result.ok){"ok"}else{"atom_test_failed"}}catch(_:Exception){result.ok=false;result.failed=result.total-result.passed;result.diagnostic="atom_test_execution_failed"};result}
private func atomForbiddenContent(raw:String):Bool{raw.contains("teacher-solutions")||raw.contains("/reference/")||raw.contains("reference/")||raw.contains("/hidden/")||raw.contains("hidden_test")||raw.contains("hidden assertion")||raw.contains("cj-humaneval-")||raw.contains("canonical_solution")||raw.contains("solution n-gram")}
private func atomJsonString(object:JsonObject,field:String):String{match(object.get(field)){case Some(value)=>value.asString().getValue().trimAscii();case None=>""}}
