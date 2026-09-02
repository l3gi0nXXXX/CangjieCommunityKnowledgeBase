package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashMap, HashSet}
import std.fs.{Directory, File, FileInfo, Path, canonicalize, exists, rename, remove}
import std.sort.*
import stdx.encoding.json.*

private class CkbTeacherContextCandidateSetV1ReadOnly {
    public var ok=false;public var diagnostic="not_parsed";public var candidateSetHash=""
    public var baseCompositeHash="";public var validationLevel="";public var rulesEligible=false
    public var rulesHash="";public var rulesCount:Int64=0;public var rulesLineage=""
    public var skillsEligible=false;public var skillsHash="";public var skillsCount:Int64=0;public var skillsLineage=""
    public var knowledgeEligible=false;public var knowledgeHash="";public var knowledgeVersion="";public var knowledgeLineage=""
    public var combinationAuditHash="";public init(){}
}
private class CkbTeacherContextApprovalV1ReadOnly {
    public var ok=false;public var diagnostic="candidate_approval_missing";public var approvalHash="";public init(){}
}
public class CkbStudentContextBundle {
    public var ok=false;public var diagnostic="not_built";public var contextVersion="";public var compositeHash=""
    public var json="";public var rulesJson="";public var skillsJson="";public var knowledgeReferenceJson=""
    public var agentsMarkdown="";public var skillsPrompt="";public var combinationAuditJson="";public init(){}
}
private class CkbContextParsedLanes {
    let rules=ArrayList<CkbStudentRuleCandidate>()
    let skills=ArrayList<CkbStudentSkillCandidate>()
    var diagnostic="ok"
    init(){}
}
public class CkbContextBaseVersion {
    public var ok=false;public var diagnostic="candidate_base_composite_mismatch";public var manifestJson=""
    public var validationLevel="";public var candidateSetHash=""
    public var rulesJson="";public var agentsMarkdown="";public var skillsJson="";public var skillsPrompt=""
    public var knowledgeReference="";public var combinationAudit="";public var compositeHash=""
    public var rulesVersion="";public var rulesHash="";public var rulesBundleHash="";public var rulesCount:Int64=0;public var rulesBytes:Int64=0;public var rulesLineage=""
    public var skillVersion="";public var skillsHash="";public var skillProjectionHash="";public var skillsCount:Int64=0;public var skillsBytes:Int64=0;public var skillsLineage=""
    public var knowledgeHash="";public var knowledgeVersion="";public var knowledgeLineage="";public var combinationAuditHash=""
    public init(){}
}
private class CkbContextOperation {
    var role="";var assetId="";var operation="";var expectedOldHash="";var newHash="";init(){}
}

public class CkbFrozenKnowledgeReferenceWriteOptions {
    public var allowedRoot="";public var selectedAtomsPath="";public var selectionProofPath=""
    public var atomTestSummaryPath="";public var frozenManifestPath="";public var outputPath=""
    public init(){}
}
public class CkbFrozenKnowledgeReferenceWriteResult {
    public var ok=false;public var diagnostic="frozen_knowledge_reference_not_written"
    public var referenceJson="";public var referenceHash="";public var knowledgeCandidateHash=""
    public init(){}
}

private func parseTeacherContextCandidateSetV1ReadOnly(path:String):CkbTeacherContextCandidateSetV1ReadOnly {
    let out=CkbTeacherContextCandidateSetV1ReadOnly();let raw=ckbContextRead(Path(path));if(raw[1]!="ok"){out.diagnostic="candidate_set_schema_invalid";return out}
    try{
        let text=raw[0].trimAscii();let o=JsonValue.fromStr(text).asObject();if(o.getFields().size!=20||ckbContextString(o,"schemaVersion")!="teacher-student-context-candidate-set-v1"){out.diagnostic="candidate_set_schema_invalid";return out}
        let parts=text.split(",\"candidateSetHash\":");if(parts.size!=2||parts[0]+"}"==text){out.diagnostic="candidate_set_schema_invalid";return out}
        out.candidateSetHash=ckbContextString(o,"candidateSetHash");if(out.candidateSetHash!=benchmarkGapSha256(parts[0]+"}")){out.diagnostic="candidate_set_hash_mismatch";return out}
        out.baseCompositeHash=ckbContextString(o,"baseCompositeHash");out.validationLevel=ckbContextString(o,"validationLevel")
        if(!["scaffold_contract","student_validated"].contains(out.validationLevel)){out.diagnostic="candidate_set_schema_invalid";return out}
        out.rulesEligible=ckbContextBool(o,"rulesEligible");out.rulesHash=ckbContextString(o,"rulesHash");out.rulesCount=ckbContextInt(o,"rulesCount");out.rulesLineage=ckbContextString(o,"rulesAssetLineage")
        out.skillsEligible=ckbContextBool(o,"skillsEligible");out.skillsHash=ckbContextString(o,"skillsHash");out.skillsCount=ckbContextInt(o,"skillsCount");out.skillsLineage=ckbContextString(o,"skillAssetLineage")
        out.knowledgeEligible=ckbContextBool(o,"knowledgeEligible");out.knowledgeHash=ckbContextString(o,"knowledgeCandidateHash");out.knowledgeVersion=ckbContextString(o,"knowledgeTargetVersion");out.knowledgeLineage=ckbContextString(o,"knowledgeAssetLineage");out.combinationAuditHash=ckbContextString(o,"combinationAuditHash")
        if(!out.rulesEligible&&!out.skillsEligible&&!out.knowledgeEligible){out.diagnostic="candidate_set_schema_invalid";return out};out.ok=true;out.diagnostic="ok";out
    }catch(_:Exception){out.diagnostic="candidate_set_schema_invalid";out}
}
private func validateTeacherContextApprovalV1ReadOnly(candidate:CkbTeacherContextCandidateSetV1ReadOnly,path:String):CkbTeacherContextApprovalV1ReadOnly {
    let out=CkbTeacherContextApprovalV1ReadOnly();if(!candidate.ok){out.diagnostic="candidate_set_schema_invalid";return out};let raw=ckbContextRead(Path(path));if(raw[1]!="ok"){return out}
    try{let text=raw[0].trimAscii();let o=JsonValue.fromStr(text).asObject();if(o.getFields().size!=9||ckbContextString(o,"schemaVersion")!="teacher-student-context-approval-v1"){out.diagnostic="candidate_approval_hash_mismatch";return out};if(ckbContextString(o,"decision")!="approve"){out.diagnostic="candidate_approval_rejected";return out};if(ckbContextString(o,"candidateSetHash")!=candidate.candidateSetHash||ckbContextString(o,"rulesHash")!=candidate.rulesHash||ckbContextString(o,"skillsHash")!=candidate.skillsHash||ckbContextString(o,"knowledgeCandidateHash")!=candidate.knowledgeHash){out.diagnostic="candidate_approval_hash_mismatch";return out};out.approvalHash=benchmarkGapSha256(raw[0]);out.ok=true;out.diagnostic="ok";out}catch(_:Exception){out.diagnostic="candidate_approval_hash_mismatch";out}
}
public func validateFrozenStudentKnowledgeReference(allowedRoot:String,reference:String,manifestPath:String,knowledgeStore:FileKnowledgeStore):String {
    if(ckbContextAllowedPath(allowedRoot,manifestPath)!="ok"||ckbContextAllowedPath(allowedRoot,knowledgeStore.rootPath())!="ok"){return "frozen_knowledge_reference_invalid"}
    ckbContextKnowledgeReferenceDiagnostic(reference,"verified",manifestPath,Some<FileKnowledgeStore>(knowledgeStore))
}
private func compileStudentContextBundleV1ReadOnly(version:String,candidate:CkbTeacherContextCandidateSetV1ReadOnly,
    approval:CkbTeacherContextApprovalV1ReadOnly,rules:CkbStudentRulesBundle,skillsJson:String,
    knowledgeReference:String):CkbStudentContextBundle {
    let out=CkbStudentContextBundle();out.contextVersion=version
    // v1 remains parseable for historical audit only; it has no full-tree or closure binding.
    out.diagnostic="student_context_not_student_validated";return out
}
public func renderStudentVisibleSkillPrompt(skillsJson:String):String {try{let o=JsonValue.fromStr(skillsJson.trimAscii()).asObject();var out="";for(v in o.get("skills").getOrThrow().asArray().getItems()){out+=ckbContextString(v.asObject(),"content")};out}catch(_:Exception){""}}
public func renderStudentVisibleContextProjection(rules:String,skills:String,knowledge:String):String {"${rules}\n${skills}\n${knowledge}"}
private func mergeStudentContextCandidateSetV1ReadOnly(base:CkbStudentContextBundle,candidate:CkbTeacherContextCandidateSetV1ReadOnly):String {if(candidate.baseCompositeHash=="none"){if(base.ok){"candidate_base_composite_mismatch"}else{"ok"}}else if(!base.ok||candidate.baseCompositeHash!=base.compositeHash){"candidate_base_composite_mismatch"}else{"ok"}}
private func publishStudentContextBundle(allowedRoot:String,output:String,bundle:CkbStudentContextBundle):String {
    if(ckbContextAllowedPath(allowedRoot,output)!="ok"){return "artifact_path_outside_allowed_root"}
    ckbPublishStudentContextBundleUnchecked(allowedRoot,output,bundle)
}
private func ckbPublishStudentContextBundleUnchecked(allowedRoot:String,output:String,bundle:CkbStudentContextBundle):String {
    if(!bundle.ok){return "student_context_partial_publish_blocked"};let root=Path(output)
    let stage=root.parent.join(".${root.fileName}.tmp-${bundle.compositeHash.replace("sha256:","")}");var created=false
    try{
        if(exists(root)){return if(ckbContextPublishedMatches(root,bundle)){"ok"}else{"student_context_composite_hash_mismatch"}}
        if(ckbContextAllowedPath(allowedRoot,stage.toString())!="ok"||stage.parent.toString()!=root.parent.toString()||exists(stage)){return "student_context_partial_publish_blocked"}
        if(!exists(root.parent)){Directory.create(root.parent,recursive:true)}
        Directory.create(stage,recursive:false);created=true
        File.writeTo(stage.join("student-context-manifest.json"),(bundle.json+"\n").toArray());File.writeTo(stage.join("student-agents-rules.json"),bundle.rulesJson.toArray());File.writeTo(stage.join("student-skills.json"),bundle.skillsJson.toArray());File.writeTo(stage.join("student-skills.prompt.md"),bundle.skillsPrompt.toArray());File.writeTo(stage.join("knowledge-reference.json"),bundle.knowledgeReferenceJson.toArray());File.writeTo(stage.join("AGENTS.md"),bundle.agentsMarkdown.toArray());File.writeTo(stage.join("combination-audit.json"),bundle.combinationAuditJson.toArray());if(!ckbContextPublishedMatches(stage,bundle)){throw IllegalStateException("stage_mismatch")};rename(stage.toString(),to:root.toString(),overwrite:false);created=false;"ok"
    }catch(_:Exception){try{if(created&&exists(stage)){remove(stage,recursive:true)}}catch(_:Exception){};"student_context_partial_publish_blocked"}
}
private func ckbContextPublishedMatches(root:Path,b:CkbStudentContextBundle):Bool {try{if(FileInfo(root).isSymbolicLink()||!FileInfo(root).isDirectory()){return false};let expected=[("student-context-manifest.json",b.json+"\n"),("student-agents-rules.json",b.rulesJson),("AGENTS.md",b.agentsMarkdown),("student-skills.json",b.skillsJson),("student-skills.prompt.md",b.skillsPrompt),("knowledge-reference.json",b.knowledgeReferenceJson),("combination-audit.json",b.combinationAuditJson)];if(Directory.readFrom(root).size!=expected.size){return false};for(item in expected){let path=root.join(item[0]);if(FileInfo(path).isSymbolicLink()||!FileInfo(path).isRegular()||ckbContextRead(path)[0]!=item[1]){return false}};true}catch(_:Exception){false}}
private func ckbContextAggregateLineageV1ReadOnly(c:CkbTeacherContextCandidateSetV1ReadOnly):String {if(c.rulesLineage=="independent"&&c.skillsLineage=="independent"&&c.knowledgeLineage=="independent"){"independent"}else{"humaneval_164_derived"}}
private func ckbContextRead(path:Path):(String,String){try{(String.fromUtf8(File.readFrom(path)),"ok")}catch(_:Exception){("","invalid_response_encoding")}}
private func ckbContextString(o:JsonObject,k:String):String{o.get(k).getOrThrow().asString().getValue()}
private func ckbContextInt(o:JsonObject,k:String):Int64{o.get(k).getOrThrow().asInt().getValue()}
private func ckbContextBool(o:JsonObject,k:String):Bool{o.get(k).getOrThrow().asBool().getValue()}
private func ckbContextEscape(v:String):String{v.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t")}

public func compileStudentContextBundleScaffold(allowedRoot:String,version:String,candidateRoot:String,approvalPath:String,frozenManifestPath:String,knowledgeStore:FileKnowledgeStore):CkbStudentContextBundle {
    ckbCompileStudentContextBundleV2(allowedRoot,version,candidateRoot,approvalPath,"none","scaffold",frozenManifestPath,Some<FileKnowledgeStore>(knowledgeStore))
}
public func compileStudentContextBundleScaffoldWithBase(allowedRoot:String,version:String,candidateRoot:String,
    approvalPath:String,baseContextRoot:String,frozenManifestPath:String,knowledgeStore:FileKnowledgeStore):CkbStudentContextBundle {
    ckbCompileStudentContextBundleV2(allowedRoot,version,candidateRoot,approvalPath,baseContextRoot,"scaffold",frozenManifestPath,Some<FileKnowledgeStore>(knowledgeStore))
}
public func compileStudentContextBundleReal(allowedRoot:String,version:String,candidateRoot:String,approvalPath:String,
    frozenManifestPath:String,store:FileKnowledgeStore):CkbStudentContextBundle {
    ckbCompileStudentContextBundleV2(allowedRoot,version,candidateRoot,approvalPath,"none","real",frozenManifestPath,Some<FileKnowledgeStore>(store))
}
public func compileStudentContextBundleRealWithBase(allowedRoot:String,version:String,candidateRoot:String,approvalPath:String,
    baseContextRoot:String,frozenManifestPath:String,store:FileKnowledgeStore):CkbStudentContextBundle {
    ckbCompileStudentContextBundleV2(allowedRoot,version,candidateRoot,approvalPath,baseContextRoot,"real",frozenManifestPath,Some<FileKnowledgeStore>(store))
}
public func compileAndPublishStudentContextBundle(allowedRoot:String,version:String,candidateRoot:String,
    approvalPath:String,baseContextRoot:String,frozenManifestPath:String,store:FileKnowledgeStore,
    output:String,scaffold:Bool):CkbStudentContextBundle {
    let built=if(scaffold){if(baseContextRoot=="none"){compileStudentContextBundleScaffold(allowedRoot,version,candidateRoot,approvalPath,frozenManifestPath,store)}else{compileStudentContextBundleScaffoldWithBase(allowedRoot,version,candidateRoot,approvalPath,baseContextRoot,frozenManifestPath,store)}}else{if(baseContextRoot=="none"){compileStudentContextBundleReal(allowedRoot,version,candidateRoot,approvalPath,frozenManifestPath,store)}else{compileStudentContextBundleRealWithBase(allowedRoot,version,candidateRoot,approvalPath,baseContextRoot,frozenManifestPath,store)}}
    if(!built.ok){return built}
    let published=publishStudentContextBundle(allowedRoot,output,built)
    if(published!="ok"){built.ok=false;built.diagnostic=published}else{built.diagnostic="ok"};built
}
private func ckbCompileStudentContextBundleV2(allowedRoot:String,version:String,candidateRoot:String,approvalPath:String,
    baseContextRoot:String,mode:String,frozenManifestPath:String,store:Option<FileKnowledgeStore>):CkbStudentContextBundle {
    let out=CkbStudentContextBundle();out.contextVersion=version
    try{
        if(!ckbContextSafeComponent(version)){out.diagnostic="candidate_set_schema_invalid";return out}
        for(path in [candidateRoot,approvalPath]){if(ckbContextAllowedPath(allowedRoot,path)!="ok"){out.diagnostic="artifact_path_outside_allowed_root";return out}}
        if(baseContextRoot!="none"&&ckbContextAllowedPath(allowedRoot,baseContextRoot)!="ok"||frozenManifestPath!=""&&ckbContextAllowedPath(allowedRoot,frozenManifestPath)!="ok"){out.diagnostic="artifact_path_outside_allowed_root";return out}
        match(store){case Some(value)=>if(ckbContextAllowedPath(allowedRoot,value.rootPath())!="ok"){out.diagnostic="artifact_path_outside_allowed_root";return out};case None=>out.diagnostic="frozen_knowledge_reference_invalid";return out}
        let candidate=parseTeacherContextCandidateSetDirectoryV2(allowedRoot,candidateRoot)
        if((mode=="scaffold"&&candidate.validationLevel!="scaffold_contract")||
            (mode=="real"&&candidate.validationLevel!="student_validated")||
            (mode!="scaffold"&&mode!="real")){out.diagnostic="student_context_not_student_validated";return out}
        let executionDiagnostic=ckbContextExecutionModeDiagnostic(candidate)
        if(executionDiagnostic!="ok"){out.diagnostic=executionDiagnostic;return out}
        let operationDiagnostic=ckbContextOperationDiagnostic(candidate,baseContextRoot)
        if(operationDiagnostic!="ok"){out.diagnostic=operationDiagnostic;return out}
        let approvalDisk=ckbContextRead(Path(approvalPath));if(approvalDisk[1]!="ok"){out.diagnostic="candidate_approval_missing";return out}
        let approvalRaw=approvalDisk[0].trimAscii();if(approvalDisk[0]!=approvalRaw+"\n"||approvalDisk[0].contains("\r")){out.diagnostic="candidate_approval_hash_mismatch";return out};let decision=validateTeacherContextApprovalV2(approvalRaw,candidate)
        if(decision!="approve"){out.diagnostic="candidate_approval_rejected";return out}
        let deltaLanes=ckbContextParseEligibleLanes(candidateRoot,candidate)
        if(deltaLanes.diagnostic!="ok"){out.diagnostic=deltaLanes.diagnostic;return out}
        let deltaRuleOps=ckbContextOperations(candidate.rules,"rules");let deltaSkillOps=ckbContextOperations(candidate.skills,"skills");if(deltaRuleOps[1]!="ok"||deltaSkillOps[1]!="ok"||deltaRuleOps[0].size!=deltaLanes.rules.size||deltaSkillOps[0].size!=deltaLanes.skills.size){out.diagnostic="candidate_operation_invalid";return out}
        let baseVersion=if(baseContextRoot=="none"){CkbContextBaseVersion()}else{ckbContextReadBaseVersion(baseContextRoot)}
        if(baseContextRoot!="none"&&!baseVersion.ok){out.diagnostic=baseVersion.diagnostic;return out}
        if(baseContextRoot!="none"&&((!candidate.rules.eligible&&(candidate.rules.hash!=baseVersion.rulesHash||candidate.rules.count!=baseVersion.rulesCount||candidate.rules.lineage!=baseVersion.rulesLineage))||
            (!candidate.skills.eligible&&(candidate.skills.hash!=baseVersion.skillProjectionHash||candidate.skills.count!=baseVersion.skillsCount||candidate.skills.lineage!=baseVersion.skillsLineage))||
            (!candidate.knowledge.eligible&&(candidate.knowledge.hash!=baseVersion.knowledgeHash||candidate.knowledgeTargetVersion!=baseVersion.knowledgeVersion||candidate.knowledge.lineage!=baseVersion.knowledgeLineage)))){
            out.diagnostic="candidate_lane_hash_mismatch";return out
        }
        let parsedLanes=if(baseVersion.ok){ckbContextMergeLanes(deltaLanes,candidate,baseVersion)}else{deltaLanes}
        if(parsedLanes.diagnostic!="ok"){out.diagnostic=parsedLanes.diagnostic;return out}
        var actualRulesLineage="independent";for(rule in parsedLanes.rules){if(rule.assetLineage!="independent"){actualRulesLineage="humaneval_164_derived"}}
        var actualSkillsLineage="independent";for(skill in parsedLanes.skills){if(skill.lineage!="independent"){actualSkillsLineage="humaneval_164_derived"}}
        if(baseVersion.ok&&((baseVersion.rulesLineage=="humaneval_164_derived"&&candidate.rules.eligible&&candidate.rules.lineage=="independent")||(baseVersion.skillsLineage=="humaneval_164_derived"&&candidate.skills.eligible&&candidate.skills.lineage=="independent"))){out.diagnostic="candidate_lane_lineage_invalid";return out}
        let crossLane=ckbContextCrossLaneDiagnostic(parsedLanes.rules,parsedLanes.skills);if(crossLane!="ok"){out.diagnostic=crossLane;return out}
        let rulesBuild=if(candidate.rules.eligible){compileStudentRulesBundle("${version}-rules",parsedLanes.rules)}
            else{CkbStudentRulesBundle()}
        let skillsBuild=if(candidate.skills.eligible){compileStudentSkillBundle("${version}-skills",parsedLanes.skills)}
            else{CkbStudentSkillBundleBuild()}
        if((candidate.rules.eligible&&!rulesBuild.ok)||(candidate.skills.eligible&&!skillsBuild.ok)){
            out.diagnostic="candidate_lane_hash_mismatch";return out
        }
        let rules=if(candidate.rules.eligible){rulesBuild.agentsMarkdown}else{baseVersion.agentsMarkdown}
        let skills=if(candidate.skills.eligible){renderStudentVisibleSkillPrompt(skillsBuild.json)}else{baseVersion.skillsPrompt}
        if((!candidate.rules.eligible&&benchmarkGapSha256(rules)!=candidate.rules.hash)||(!candidate.skills.eligible&&benchmarkGapSha256(skills)!=candidate.skills.hash)){out.diagnostic="candidate_lane_hash_mismatch";return out}
        var knowledgeReference=if(candidate.knowledge.eligible){""}else{baseVersion.knowledgeReference};if(candidate.knowledge.eligible){for(file in candidate.knowledge.files){if(file.path=="knowledge-candidate-reference.json"){knowledgeReference=file.content}}}
        if(skills.toArray().size>24576||candidate.rules.count>16||candidate.skills.count>16){out.diagnostic="candidate_lane_hash_mismatch";return out}
        let referenceDiagnostic=ckbContextKnowledgeReferenceDiagnostic(knowledgeReference,"verified",frozenManifestPath,store)
        if(referenceDiagnostic!="ok"){out.diagnostic=referenceDiagnostic;return out}
        let reference=JsonValue.fromStr(knowledgeReference.trimAscii()).asObject()
        if(knowledgeReference!=ckbContextRenderKnowledgeReference(reference)+"\n"){out.diagnostic="frozen_knowledge_reference_invalid";return out}
        if(ckbContextString(reference,"knowledgeCandidateHash")!=candidate.knowledge.hash||
            ckbContextString(reference,"knowledgeVersion")!=candidate.knowledgeTargetVersion||
            ckbContextString(reference,"assetLineage")!=candidate.knowledge.lineage){out.diagnostic="candidate_lane_hash_mismatch";return out}
        let knowledgeMaterial=ckbContextKnowledgeMaterial(store,knowledgeReference,parsedLanes.rules,parsedLanes.skills)
        if(knowledgeMaterial[1]!="ok"){out.diagnostic=knowledgeMaterial[1];return out}
        let protected=ckbStudentVisibleProtectedArtifacts()
        let audit=auditStudentVisibleAssetCombination(knowledgeMaterial[0],parsedLanes.skills,rules,protected)
        if(audit!="ok"){out.diagnostic="student_context_partial_publish_blocked";return out}
        let finalKnowledgeLineage=if(candidate.knowledge.eligible){candidate.knowledge.lineage}else{baseVersion.knowledgeLineage};let changed=ckbContextChangedLanes(candidate);let aggregate=if(actualRulesLineage=="independent"&&actualSkillsLineage=="independent"&&finalKnowledgeLineage=="independent"){"independent"}else{"humaneval_164_derived"}
        let finalRulesVersion=if(candidate.rules.eligible){"${version}-rules"}else{baseVersion.rulesVersion};let finalSkillVersion=if(candidate.skills.eligible){"${version}-skills"}else{baseVersion.skillVersion};let finalRulesHash=benchmarkGapSha256(rules);let finalRulesBundleHash=if(candidate.rules.eligible){rulesBuild.canonicalHash}else{baseVersion.rulesBundleHash};let finalSkillBundleHash=if(candidate.skills.eligible){skillsBuild.canonicalHash}else{baseVersion.skillsHash};let finalSkillProjectionHash=benchmarkGapSha256(skills)
        if(finalRulesHash!=candidate.rules.hash||Int64(parsedLanes.rules.size)!=candidate.rules.count||finalSkillProjectionHash!=candidate.skills.hash||Int64(parsedLanes.skills.size)!=candidate.skills.count){out.diagnostic="candidate_lane_hash_mismatch";return out}
        let knowledgeContentHash=ckbContextString(reference,"knowledgeContentHash")
        let knowledgeAuditHash=if(candidate.knowledge.eligible){knowledgeContentHash}else{ckbContextString(reference,"knowledgeCandidateHash")}
        let combinationHash=ckbContextCombinationAuditHash(finalRulesHash,finalSkillProjectionHash,knowledgeAuditHash,candidate.sourceClosureHash,candidate.protectedClosureHash)
        if(combinationHash!=candidate.combinationAuditHash){out.diagnostic="candidate_set_hash_mismatch";return out}
        let fields="\"schemaVersion\":\"ckb-student-context-bundle-v2\",\"contextVersion\":\"${ckbContextEscape(version)}\",\"baseCompositeHash\":\"${candidate.baseCompositeHash}\",\"candidateSetHash\":\"${candidate.candidateSetHash}\",\"approvalHash\":\"${benchmarkGapSha256(approvalDisk[0])}\",\"validationLevel\":\"${candidate.validationLevel}\",\"changedLanes\":[${changed}],\"rulesVersion\":\"${ckbContextEscape(finalRulesVersion)}\",\"rulesHash\":\"${finalRulesHash}\",\"rulesBundleHash\":\"${finalRulesBundleHash}\",\"rulesCount\":${parsedLanes.rules.size},\"rulesContentBytes\":${rules.toArray().size},\"rulesAssetLineage\":\"${actualRulesLineage}\",\"skillBundleVersion\":\"${ckbContextEscape(finalSkillVersion)}\",\"skillBundleHash\":\"${finalSkillBundleHash}\",\"skillProjectionHash\":\"${finalSkillProjectionHash}\",\"skillCount\":${parsedLanes.skills.size},\"skillContentBytes\":${skills.toArray().size},\"skillAssetLineage\":\"${actualSkillsLineage}\",\"knowledgeVersion\":\"${ckbContextString(reference,"knowledgeVersion")}\",\"knowledgeContentHash\":\"${knowledgeContentHash}\",\"frozenCandidateManifestHash\":\"${ckbContextString(reference,"frozenCandidateManifestHash")}\",\"knowledgeAssetLineage\":\"${finalKnowledgeLineage}\",\"aggregateAssetLineage\":\"${aggregate}\",\"combinationAuditHash\":\"${combinationHash}\""
        out.compositeHash=benchmarkGapSha256("{${fields}}");out.json="{${fields},\"compositeHash\":\"${out.compositeHash}\"}";out.rulesJson=if(candidate.rules.eligible){rulesBuild.json+"\n"}else{baseVersion.rulesJson};out.skillsJson=if(candidate.skills.eligible){skillsBuild.json+"\n"}else{baseVersion.skillsJson};out.knowledgeReferenceJson=knowledgeReference;out.agentsMarkdown=rules;out.skillsPrompt=if(candidate.skills.eligible){renderStudentVisibleSkillPrompt(out.skillsJson)}else{baseVersion.skillsPrompt};out.combinationAuditJson="{\"schemaVersion\":\"ckb-student-context-combination-audit-v1\",\"sourceClosureHash\":\"${candidate.sourceClosureHash}\",\"protectedClosureHash\":\"${candidate.protectedClosureHash}\",\"combinationAuditHash\":\"${combinationHash}\",\"passed\":true}\n";out.ok=true;out.diagnostic="ok";out
    }catch(e:IllegalArgumentException){let message=e.message;out.diagnostic=if(message.contains("invalid_response_encoding")){"invalid_response_encoding"}else if(message.contains("malformed_json")){"malformed_json"}else if(message.contains("approval")){"candidate_approval_hash_mismatch"}else if(message.contains("operation")){"candidate_operation_invalid"}else if(message.contains("test_evidence")){"candidate_test_evidence_invalid"}else if(message.contains("lane_lineage")){"candidate_lane_lineage_invalid"}else if(message.contains("lane_hash")){"candidate_lane_hash_mismatch"}else if(message.contains("base_composite")){"candidate_base_composite_mismatch"}else if(message.contains("hash")){"candidate_set_hash_mismatch"}else{"candidate_set_schema_invalid"};out}
    catch(_:Exception){out.diagnostic="candidate_set_schema_invalid";out}
}
private func ckbContextExecutionModeDiagnostic(candidate:TeacherContextCandidateSetV2):String {
    let expected=if(candidate.validationLevel=="scaffold_contract"){"fake_contract"}else{"student_completion_non_humaneval"}
    var provider="";var model="";var count:Int64=0
    try {for((laneName,lane) in [("rules",candidate.rules),("skills",candidate.skills)]){let projectionHash=if(laneName=="rules"){candidate.rules.hash}else{candidate.skills.hash};for(file in lane.files){if(!file.path.endsWith("/execution.json")){continue};let object=JsonValue.fromStr(file.content.trimAscii()).asObject();let executor=ckbContextString(object,"executorKind");let currentProvider=ckbContextString(object,"providerIdentityHash");let currentModel=ckbContextString(object,"modelVersion");if(executor!=expected||!ckbContextHash(currentProvider)||currentModel==""){return "candidate_test_evidence_invalid"};if(candidate.validationLevel=="student_validated"){let prefix=file.path.replace("/execution.json","");var fixture="";var actual="";var transcript="";var foundFixture=false;var foundActual=false;var foundTranscript=false;for(candidateFile in lane.files){if(candidateFile.path==prefix+"/fixture.json"){fixture=candidateFile.content;foundFixture=true}else if(candidateFile.path==prefix+"/actual.txt"){actual=candidateFile.content;foundActual=true}else if(candidateFile.path==prefix+"/transcript.txt"){transcript=candidateFile.content;foundTranscript=true}};if(!foundFixture||!foundActual||!foundTranscript||ckbStudentValidationExecutionBindingDiagnostic(fixture.toArray(),actual.toArray(),transcript.toArray(),file.content.toArray(),laneName,projectionHash,candidate.baseCompositeHash,currentProvider,currentModel)!="ok"){return "candidate_test_evidence_invalid"}};if(count==0){provider=currentProvider;model=currentModel}else if(provider!=currentProvider||model!=currentModel){return "candidate_test_evidence_invalid"};count+=1}};if((candidate.rules.eligible||candidate.skills.eligible)&&count==0){return "candidate_test_evidence_invalid"};"ok"}catch(_:Exception){"candidate_test_evidence_invalid"}
}
public class CkbStudentValidationExecutionBindingResult {
    public var ok=false;public var diagnostic="candidate_test_evidence_invalid";public var fixtureId="";public var lane=""
    public var candidateVisibleHash="";public var baseCompositeHash="";public var validationIdentityHash=""
    public var requestHash="";public var responseHash="";public var verifierEvidenceHash="";public var exitCode:Int64=0;public init(){}
}
public func parseCkbStudentValidationExecutionBinding(bytes:Array<UInt8>):CkbStudentValidationExecutionBindingResult {
    let out=CkbStudentValidationExecutionBindingResult();let raw=try{String.fromUtf8(bytes)}catch(_:Exception){out.diagnostic="invalid_response_encoding";return out}
    try {
        let text=raw.trimAscii();let object=JsonValue.fromStr(text).asObject()
        if(object.getFields().size!=10||ckbContextString(object,"schemaVersion")!="teacher-student-validation-transcript-v1"){return out}
        out.fixtureId=ckbContextString(object,"fixtureId");out.lane=ckbContextString(object,"lane");out.candidateVisibleHash=ckbContextString(object,"candidateVisibleHash");out.baseCompositeHash=ckbContextString(object,"baseCompositeHash");out.validationIdentityHash=ckbContextString(object,"validationIdentityHash");out.requestHash=ckbContextString(object,"requestHash");out.responseHash=ckbContextString(object,"responseHash");out.verifierEvidenceHash=ckbContextString(object,"verifierEvidenceHash");out.exitCode=ckbContextInt(object,"exitCode")
        let canonical="{\"schemaVersion\":\"teacher-student-validation-transcript-v1\",\"fixtureId\":\"${ckbContextEscape(out.fixtureId)}\",\"lane\":\"${out.lane}\",\"candidateVisibleHash\":\"${out.candidateVisibleHash}\",\"baseCompositeHash\":\"${out.baseCompositeHash}\",\"validationIdentityHash\":\"${out.validationIdentityHash}\",\"requestHash\":\"${out.requestHash}\",\"responseHash\":\"${out.responseHash}\",\"verifierEvidenceHash\":\"${out.verifierEvidenceHash}\",\"exitCode\":${out.exitCode}}"
        if(out.fixtureId==""||!["rules","skills"].contains(out.lane)||!ckbContextHash(out.candidateVisibleHash)||(out.baseCompositeHash!="none"&&!ckbContextHash(out.baseCompositeHash))||!ckbContextHash(out.validationIdentityHash)||!ckbContextHash(out.requestHash)||!ckbContextHash(out.responseHash)||!ckbContextHash(out.verifierEvidenceHash)||text!=canonical||raw!=canonical+"\n"){return out}
        out.ok=true;out.diagnostic="ok";out
    }catch(_:Exception){out.diagnostic="malformed_json";out}
}
public func ckbStudentValidationExecutionBindingDiagnostic(fixtureBytes:Array<UInt8>,actualBytes:Array<UInt8>,
    transcriptBytes:Array<UInt8>,executionBytes:Array<UInt8>,lane:String,candidateVisibleHash:String,
    baseCompositeHash:String,validationIdentityHash:String,modelVersion:String):String {
    let fixtureRaw=try{String.fromUtf8(fixtureBytes)}catch(_:Exception){return "invalid_response_encoding"};let actualRaw=try{String.fromUtf8(actualBytes)}catch(_:Exception){return "invalid_response_encoding"};let executionRaw=try{String.fromUtf8(executionBytes)}catch(_:Exception){return "invalid_response_encoding"}
    let parsed=parseCkbStudentValidationExecutionBinding(transcriptBytes);if(!parsed.ok){return parsed.diagnostic}
    try {
        if(!fixtureRaw.endsWith("\n")||fixtureRaw.endsWith("\n\n")||fixtureRaw.contains("\r")||!actualRaw.endsWith("\n")||actualRaw.endsWith("\n\n")||actualRaw.contains("\r")||!executionRaw.endsWith("\n")||executionRaw.endsWith("\n\n")||executionRaw.contains("\r")){return "candidate_test_evidence_invalid"}
        let fixture=JsonValue.fromStr(fixtureRaw.trimAscii()).asObject();let fixtureId=ckbContextString(fixture,"fixtureId");let kind=ckbContextString(fixture,"kind");let source=ckbContextString(fixture,"sourceClass");let content=ckbContextString(fixture,"content");let expected=ckbContextString(fixture,"expectedEvidence");let fixtureHash=benchmarkGapSha256(ckbContextPart(fixtureId)+ckbContextPart(kind)+ckbContextPart(source)+ckbContextPart(content)+ckbContextPart(expected));let fixtureCanonical="{\"schemaVersion\":\"teacher-asset-fixture-v1\",\"fixtureId\":\"${ckbContextEscape(fixtureId)}\",\"kind\":\"${kind}\",\"sourceClass\":\"${source}\",\"content\":\"${ckbContextEscape(content)}\",\"expectedEvidence\":\"${ckbContextEscape(expected)}\",\"fixtureHash\":\"${fixtureHash}\"}\n"
        let actualRunes=actualRaw.toRuneArray();var actual="";for(i in 0..(actualRunes.size-1)){actual+=actualRunes[i].toString()};let actualHash=benchmarkGapSha256(actual);let requestHash=benchmarkGapSha256(ckbContextPart(fixtureHash)+ckbContextPart(lane)+ckbContextPart(candidateVisibleHash)+ckbContextPart(baseCompositeHash)+ckbContextPart(validationIdentityHash))
        let execution=JsonValue.fromStr(executionRaw.trimAscii()).asObject();let executor=ckbContextString(execution,"executorKind");let provider=ckbContextString(execution,"providerIdentityHash");let model=ckbContextString(execution,"modelVersion");let expectedHash=benchmarkGapSha256(expected);let transcriptText=try{String.fromUtf8(transcriptBytes)}catch(_:Exception){return "invalid_response_encoding"};let transcriptHash=benchmarkGapSha256(transcriptText.trimAscii());let exitCode=ckbContextInt(execution,"exitCode");let passed=ckbContextBool(execution,"passed");let executionCanonical="{\"schemaVersion\":\"teacher-candidate-fixture-execution-v1\",\"fixtureId\":\"${ckbContextEscape(fixtureId)}\",\"kind\":\"${kind}\",\"sourceClass\":\"${source}\",\"fixtureHash\":\"${fixtureHash}\",\"executorKind\":\"${executor}\",\"providerIdentityHash\":\"${provider}\",\"modelVersion\":\"${ckbContextEscape(model)}\",\"expectedEvidenceHash\":\"${expectedHash}\",\"actualEvidenceHash\":\"${actualHash}\",\"transcriptHash\":\"${transcriptHash}\",\"exitCode\":${exitCode},\"passed\":${passed}}\n"
        if(fixture.getFields().size!=7||fixtureRaw!=fixtureCanonical||execution.getFields().size!=13||executionRaw!=executionCanonical||ckbContextString(fixture,"schemaVersion")!="teacher-asset-fixture-v1"||ckbContextString(fixture,"fixtureHash")!=fixtureHash||ckbContextString(execution,"schemaVersion")!="teacher-candidate-fixture-execution-v1"||ckbContextString(execution,"fixtureId")!=fixtureId||ckbContextString(execution,"kind")!=kind||ckbContextString(execution,"sourceClass")!=source||ckbContextString(execution,"fixtureHash")!=fixtureHash||executor!="student_completion_non_humaneval"||provider!=validationIdentityHash||model!=modelVersion||exitCode!=0||!passed){return "candidate_test_evidence_invalid"}
        if(parsed.fixtureId!=fixtureId||parsed.lane!=lane||parsed.candidateVisibleHash!=candidateVisibleHash||parsed.baseCompositeHash!=baseCompositeHash||parsed.validationIdentityHash!=validationIdentityHash){return "student_validation_identity_mismatch"}
        let responseHash=benchmarkGapSha256(ckbContextPart(actual)+ckbContextPart(parsed.verifierEvidenceHash)+ckbContextPart(exitCode.toString()))
        if(parsed.requestHash!=requestHash||parsed.responseHash!=responseHash||parsed.exitCode!=exitCode){return "candidate_test_evidence_invalid"};"ok"
    }catch(_:Exception){"candidate_test_evidence_invalid"}
}
private func ckbContextParseEligibleLanes(rootPath:String,candidate:TeacherContextCandidateSetV2):CkbContextParsedLanes {
    let out=CkbContextParsedLanes()
    try {
        for(entry in Directory.readFrom(Path(rootPath).join("rules"))){
            if(entry.isSymbolicLink()||!entry.isDirectory()){out.diagnostic="candidate_set_schema_invalid";return out}
            let parsed=parseStudentRuleCandidateDirectory(entry.path.toString())
            if(!parsed.verified){out.diagnostic=parsed.diagnostic;return out};out.rules.add(parsed)
        }
        for(entry in Directory.readFrom(Path(rootPath).join("skills"))){
            if(entry.isSymbolicLink()||!entry.isDirectory()){out.diagnostic="candidate_set_schema_invalid";return out}
            let parsed=parseStudentSkillCandidateDirectory(entry.path.toString(),candidate.skills.lineage=="independent")
            if(!parsed.verified){out.diagnostic=parsed.diagnostic;return out};out.skills.add(parsed)
        }
        if((candidate.rules.eligible&&out.rules.size==0)||(!candidate.rules.eligible&&out.rules.size!=0)||
            (candidate.skills.eligible&&out.skills.size==0)||(!candidate.skills.eligible&&out.skills.size!=0)){out.diagnostic="candidate_lane_hash_mismatch";return out}
        for(rule in out.rules){for(skill in out.skills){
            if(rule.body==skill.procedure||rule.agentsMarkdown==skill.skillContent){
                out.diagnostic="duplicate_cross_lane_asset_content";return out
            }
        }}
        out
    }catch(_:Exception){out.diagnostic="candidate_set_schema_invalid";out}
}
private func ckbContextKnowledgeMaterial(store:Option<FileKnowledgeStore>,reference:String,rules:ArrayList<CkbStudentRuleCandidate>,skills:ArrayList<CkbStudentSkillCandidate>):(String,String) {
    match(store){
        case Some(value)=>
            let snapshot=value.loadActiveSnapshot();if(!snapshot.valid){return("","frozen_knowledge_reference_invalid")};let referenceObject=try{JsonValue.fromStr(reference.trimAscii()).asObject()}catch(_:Exception){return("","frozen_knowledge_reference_invalid")};if(ckbCertifiedNormalizedRecordsChecksum(snapshot.normalizedRecords)!=ckbContextString(referenceObject,"knowledgeContentHash")){return("","frozen_knowledge_reference_invalid")}
            let rows=ArrayList<String>();for(record in snapshot.normalizedRecords){for(value in [record.title,record.chunk,record.citation]){if(value==""){continue};for(rule in rules){if(value==rule.body){return("","duplicate_cross_lane_asset_content")};if(ckbContextConflictKey(value)==ckbContextConflictKey(rule.body)&&value!=rule.body){return("","conflicting_cross_lane_asset_content")}};for(skill in skills){if(value==skill.procedure){return("","duplicate_cross_lane_asset_content")};if(ckbContextConflictKey(value)==ckbContextConflictKey(skill.procedure)&&value!=skill.procedure){return("","conflicting_cross_lane_asset_content")}}};rows.add(ckbCertifiedNormalizedRecordSeed(record))}
            let ordered=rows.toArray();sort(ordered);var content="";for(row in ordered){content+=row+"\n"};(content,"ok")
        case None=>("","frozen_knowledge_reference_invalid")
    }
}
public func readStudentContextBundleV2(rootPath:String):CkbContextBaseVersion {
    let out=CkbContextBaseVersion();let root=Path(rootPath)
    try {
        if(!exists(root)||FileInfo(root).isSymbolicLink()||!FileInfo(root).isDirectory()){return out}
        let expected=HashSet<String>(["student-context-manifest.json","student-agents-rules.json","AGENTS.md","student-skills.json","student-skills.prompt.md","knowledge-reference.json","combination-audit.json"])
        for(entry in Directory.readFrom(root)){if(entry.isSymbolicLink()||!entry.isRegular()||!expected.contains(entry.name)){return out};expected.remove(entry.name)};if(!expected.isEmpty()){return out}
        let manifest=ckbContextRead(root.join("student-context-manifest.json"));let rules=ckbContextRead(root.join("student-agents-rules.json"));let agents=ckbContextRead(root.join("AGENTS.md"));let skills=ckbContextRead(root.join("student-skills.json"));let prompt=ckbContextRead(root.join("student-skills.prompt.md"));let knowledge=ckbContextRead(root.join("knowledge-reference.json"));let audit=ckbContextRead(root.join("combination-audit.json"))
        for(read in [manifest,rules,agents,skills,prompt,knowledge,audit]){if(read[1]!="ok"){out.diagnostic="invalid_response_encoding";return out}}
        let raw=manifest[0].trimAscii();let object=JsonValue.fromStr(raw).asObject();if(object.getFields().size!=26||ckbContextString(object,"schemaVersion")!="ckb-student-context-bundle-v2"){return out}
        let canonicalManifest=ckbContextRenderManifest(object);let composite=ckbContextString(object,"compositeHash");if(canonicalManifest==""||raw!=canonicalManifest||manifest[0]!=canonicalManifest+"\n"||!ckbContextHash(composite)){return out}
        for(key in ["candidateSetHash","approvalHash","rulesHash","rulesBundleHash","skillBundleHash","skillProjectionHash","knowledgeContentHash","frozenCandidateManifestHash","combinationAuditHash"]){if(!ckbContextHash(ckbContextString(object,key))){return out}};let baseHash=ckbContextString(object,"baseCompositeHash");if(baseHash!="none"&&!ckbContextHash(baseHash)||!["scaffold_contract","student_validated"].contains(ckbContextString(object,"validationLevel"))){return out};let rulesLineage=ckbContextString(object,"rulesAssetLineage");let skillsLineage=ckbContextString(object,"skillAssetLineage");let knowledgeLineage=ckbContextString(object,"knowledgeAssetLineage");let aggregate=if(rulesLineage=="independent"&&skillsLineage=="independent"&&knowledgeLineage=="independent"){"independent"}else{"humaneval_164_derived"};if(!["independent","humaneval_164_derived"].contains(rulesLineage)||!["independent","humaneval_164_derived"].contains(skillsLineage)||!["independent","humaneval_164_derived"].contains(knowledgeLineage)||ckbContextString(object,"aggregateAssetLineage")!=aggregate){return out}
        let parsedRules=ckbContextParseStudentRules(rules[0]);if(parsedRules[1]!="ok"){return out};let rebuiltRules=compileStudentRulesBundle(ckbContextString(object,"rulesVersion"),parsedRules[0]);if(!rebuiltRules.ok||rebuiltRules.json+"\n"!=rules[0]||rebuiltRules.agentsMarkdown!=agents[0]){return out}
        let parsedSkills=ckbContextParseStudentSkills(skills[0]);if(parsedSkills[1]!="ok"){return out};let rebuiltSkills=compileStudentSkillBundle(ckbContextString(object,"skillBundleVersion"),parsedSkills[0]);if(!rebuiltSkills.ok||rebuiltSkills.json+"\n"!=skills[0]||renderStudentVisibleSkillPrompt(skills[0])!=prompt[0]){return out}
        var actualRulesLineage="independent";for(rule in parsedRules[0]){if(rule.assetLineage!="independent"){actualRulesLineage="humaneval_164_derived"}};var actualSkillsLineage="independent";for(skill in parsedSkills[0]){if(skill.lineage!="independent"){actualSkillsLineage="humaneval_164_derived"}};if(actualRulesLineage!=rulesLineage||actualSkillsLineage!=skillsLineage){return out}
        if(ckbContextKnowledgeReferenceDiagnostic(knowledge[0],"structural_read_only","",None<FileKnowledgeStore>)!="ok"){return out}
        let referenceObject=JsonValue.fromStr(knowledge[0].trimAscii()).asObject();if(knowledge[0]!=ckbContextRenderKnowledgeReference(referenceObject)+"\n"||ckbContextString(referenceObject,"knowledgeVersion")!=ckbContextString(object,"knowledgeVersion")||ckbContextString(referenceObject,"knowledgeContentHash")!=ckbContextString(object,"knowledgeContentHash")||ckbContextString(referenceObject,"frozenCandidateManifestHash")!=ckbContextString(object,"frozenCandidateManifestHash")||ckbContextString(referenceObject,"assetLineage")!=ckbContextString(object,"knowledgeAssetLineage")){return out}
        var knowledgeChanged=false;for(value in object.get("changedLanes").getOrThrow().asArray().getItems()){if(value.asString().getValue()=="knowledge"){knowledgeChanged=true}}
        let knowledgeAuditHash=if(knowledgeChanged){ckbContextString(object,"knowledgeContentHash")}else{ckbContextString(referenceObject,"knowledgeCandidateHash")}
        let auditObject=JsonValue.fromStr(audit[0].trimAscii()).asObject();if(auditObject.getFields().size!=5||ckbContextString(auditObject,"schemaVersion")!="ckb-student-context-combination-audit-v1"||!ckbContextBool(auditObject,"passed")||!ckbContextHash(ckbContextString(auditObject,"sourceClosureHash"))||!ckbContextHash(ckbContextString(auditObject,"protectedClosureHash"))){return out};let expectedAuditHash=ckbContextCombinationAuditHash(ckbContextString(object,"rulesHash"),ckbContextString(object,"skillProjectionHash"),knowledgeAuditHash,ckbContextString(auditObject,"sourceClosureHash"),ckbContextString(auditObject,"protectedClosureHash"));if(ckbContextString(auditObject,"combinationAuditHash")!=expectedAuditHash||ckbContextString(object,"combinationAuditHash")!=expectedAuditHash){return out};let canonicalAudit="{\"schemaVersion\":\"ckb-student-context-combination-audit-v1\",\"sourceClosureHash\":\"${ckbContextString(auditObject,"sourceClosureHash")}\",\"protectedClosureHash\":\"${ckbContextString(auditObject,"protectedClosureHash")}\",\"combinationAuditHash\":\"${expectedAuditHash}\",\"passed\":true}\n";if(audit[0]!=canonicalAudit){return out}
        out.manifestJson=manifest[0];out.validationLevel=ckbContextString(object,"validationLevel");out.candidateSetHash=ckbContextString(object,"candidateSetHash");out.rulesJson=rules[0];out.agentsMarkdown=agents[0];out.skillsJson=skills[0];out.skillsPrompt=prompt[0];out.knowledgeReference=knowledge[0];out.combinationAudit=audit[0];out.compositeHash=composite;out.combinationAuditHash=expectedAuditHash
        out.rulesVersion=ckbContextString(object,"rulesVersion");out.rulesHash=ckbContextString(object,"rulesHash");out.rulesBundleHash=ckbContextString(object,"rulesBundleHash");out.rulesCount=ckbContextInt(object,"rulesCount");out.rulesBytes=ckbContextInt(object,"rulesContentBytes");out.rulesLineage=ckbContextString(object,"rulesAssetLineage");out.skillVersion=ckbContextString(object,"skillBundleVersion");out.skillsHash=ckbContextString(object,"skillBundleHash");out.skillProjectionHash=ckbContextString(object,"skillProjectionHash");out.skillsCount=ckbContextInt(object,"skillCount");out.skillsBytes=ckbContextInt(object,"skillContentBytes");out.skillsLineage=ckbContextString(object,"skillAssetLineage");out.knowledgeVersion=ckbContextString(object,"knowledgeVersion");out.knowledgeLineage=ckbContextString(object,"knowledgeAssetLineage")
        let reference=JsonValue.fromStr(knowledge[0].trimAscii()).asObject();out.knowledgeHash=ckbContextString(reference,"knowledgeCandidateHash")
        if(out.rulesHash!=benchmarkGapSha256(agents[0])||out.rulesBundleHash!=rebuiltRules.canonicalHash||out.skillsHash!=rebuiltSkills.canonicalHash||out.skillProjectionHash!=benchmarkGapSha256(prompt[0])||out.rulesCount<1||out.rulesCount>16||out.skillsCount<1||out.skillsCount>16||out.rulesCount!=parsedRules[0].size||out.skillsCount!=parsedSkills[0].size||out.rulesBytes!=agents[0].toArray().size||out.skillsBytes!=prompt[0].toArray().size){return out};out.ok=true;out.diagnostic="ok";out
    }catch(_:Exception){out}
}
public func ckbStudentContextValidationIdentityDiagnostic(contextRoot:String,candidateRoot:String,
    candidateSetHash:String,providerIdentityHash:String,modelVersion:String):String {
    let context=readStudentContextBundleV2(contextRoot);if(!context.ok){return "student_validation_identity_invalid"}
    if(context.validationLevel!="student_validated"){return "student_context_not_student_validated"}
    try {
        let candidate=parseTeacherContextCandidateSetDirectoryV2(Path(candidateRoot).parent.toString(),candidateRoot)
        if(candidate.validationLevel!="student_validated"||candidate.candidateSetHash!=candidateSetHash||context.candidateSetHash!=candidateSetHash||ckbContextExecutionModeDiagnostic(candidate)!="ok"){return "student_validation_identity_invalid"}
        var count:Int64=0
        for(lane in [candidate.rules,candidate.skills]){for(file in lane.files){if(!file.path.endsWith("/execution.json")){continue};let execution=JsonValue.fromStr(file.content.trimAscii()).asObject();if(ckbContextString(execution,"providerIdentityHash")!=providerIdentityHash||ckbContextString(execution,"modelVersion")!=modelVersion){return "student_validation_identity_mismatch"};count+=1}}
        if(count==0){"student_validation_identity_invalid"}else{"ok"}
    }catch(_:Exception){"student_validation_identity_invalid"}
}
private func ckbContextReadBaseVersion(rootPath:String):CkbContextBaseVersion {readStudentContextBundleV2(rootPath)}
private func ckbContextParseStudentSkills(raw:String):(ArrayList<CkbStudentSkillCandidate>,String) {
    let out=ArrayList<CkbStudentSkillCandidate>()
    try {
        let object=JsonValue.fromStr(raw.trimAscii()).asObject();if(object.getFields().size!=6||ckbContextString(object,"schemaVersion")!="ckb-student-skill-bundle-v1"){return(out,"candidate_lane_hash_mismatch")}
        for(value in object.get("skills").getOrThrow().asArray().getItems()){
            let row=value.asObject();if(row.getFields().size!=11){return(out,"candidate_lane_hash_mismatch")};let skill=CkbStudentSkillCandidate();skill.id=ckbContextString(row,"id");skill.version=ckbContextString(row,"version");skill.title=ckbContextString(row,"title");skill.procedure=ckbContextString(row,"procedure");skill.sourceCategory=ckbContextString(row,"sourceCategory");skill.applicability=ckbContextString(row,"applicability");skill.lineage=ckbContextString(row,"lineage");skill.skillContentHash=ckbContextString(row,"skillContentHash");skill.testEvidenceHash=ckbContextString(row,"testEvidenceHash");skill.candidateContentHash=ckbContextString(row,"candidateContentHash");skill.skillContent=ckbContextString(row,"content");let identity=ckbContextPart(skill.id)+ckbContextPart(skill.version)+ckbContextPart(skill.title)+ckbContextPart(skill.procedure)+ckbContextPart(skill.sourceCategory)+ckbContextPart(skill.applicability)+ckbContextPart(skill.lineage)+ckbContextPart(skill.testEvidenceHash);let expectedContent="---\nname: ${skill.id}\nversion: ${skill.version}\nsource: ${skill.sourceCategory}\nlineage: ${ckbStudentSkillVisibleLineage(skill.lineage)}\ncontent-hash: ${skill.candidateContentHash}\n---\n\n# ${skill.title}\n\nApplicability: ${skill.applicability}\n\n${skill.procedure}\n";let lineageValid=(skill.sourceCategory=="general_engineering"&&skill.lineage=="independent")||(skill.sourceCategory=="teacher_derived"&&skill.lineage=="humaneval_164_derived");if(skill.id==""||skill.version==""||skill.title==""||skill.procedure==""||skill.applicability==""||!lineageValid||!ckbContextHash(skill.skillContentHash)||!ckbContextHash(skill.testEvidenceHash)||!ckbContextHash(skill.candidateContentHash)||skill.skillContentHash!=benchmarkGapSha256(skill.skillContent)||skill.skillContent!=expectedContent||skill.candidateContentHash!=benchmarkGapSha256(identity)||ckbStudentVisibleAssetForbidden(skill.id+"\n"+skill.title+"\n"+skill.procedure+"\n"+skill.applicability+"\n"+skill.skillContent)){return(out,"candidate_lane_hash_mismatch")};skill.verified=true;skill.diagnostic="ok";out.add(skill)
        }
        (out,"ok")
    }catch(_:Exception){(out,"candidate_lane_hash_mismatch")}
}
private func ckbContextRenderManifest(object:JsonObject):String {
    try {
        let changedValues=ArrayList<String>();for(value in object.get("changedLanes").getOrThrow().asArray().getItems()){let lane=value.asString().getValue();if(!["knowledge","rules","skills"].contains(lane)||changedValues.contains(lane)){return ""};changedValues.add(lane)};let changed=changedValues.toArray();sort(changed);var changedJson="";for(i in 0..changed.size){if(i>0){changedJson+=","};changedJson+="\""+changed[i]+"\""}
        let fields="\"schemaVersion\":\"ckb-student-context-bundle-v2\",\"contextVersion\":\""+ckbContextEscape(ckbContextString(object,"contextVersion"))+"\",\"baseCompositeHash\":\""+ckbContextString(object,"baseCompositeHash")+"\",\"candidateSetHash\":\""+ckbContextString(object,"candidateSetHash")+"\",\"approvalHash\":\""+ckbContextString(object,"approvalHash")+"\",\"validationLevel\":\""+ckbContextString(object,"validationLevel")+"\",\"changedLanes\":["+changedJson+"],\"rulesVersion\":\""+ckbContextEscape(ckbContextString(object,"rulesVersion"))+"\",\"rulesHash\":\""+ckbContextString(object,"rulesHash")+"\",\"rulesBundleHash\":\""+ckbContextString(object,"rulesBundleHash")+"\",\"rulesCount\":"+ckbContextInt(object,"rulesCount").toString()+",\"rulesContentBytes\":"+ckbContextInt(object,"rulesContentBytes").toString()+",\"rulesAssetLineage\":\""+ckbContextString(object,"rulesAssetLineage")+"\",\"skillBundleVersion\":\""+ckbContextEscape(ckbContextString(object,"skillBundleVersion"))+"\",\"skillBundleHash\":\""+ckbContextString(object,"skillBundleHash")+"\",\"skillProjectionHash\":\""+ckbContextString(object,"skillProjectionHash")+"\",\"skillCount\":"+ckbContextInt(object,"skillCount").toString()+",\"skillContentBytes\":"+ckbContextInt(object,"skillContentBytes").toString()+",\"skillAssetLineage\":\""+ckbContextString(object,"skillAssetLineage")+"\",\"knowledgeVersion\":\""+ckbContextEscape(ckbContextString(object,"knowledgeVersion"))+"\",\"knowledgeContentHash\":\""+ckbContextString(object,"knowledgeContentHash")+"\",\"frozenCandidateManifestHash\":\""+ckbContextString(object,"frozenCandidateManifestHash")+"\",\"knowledgeAssetLineage\":\""+ckbContextString(object,"knowledgeAssetLineage")+"\",\"aggregateAssetLineage\":\""+ckbContextString(object,"aggregateAssetLineage")+"\",\"combinationAuditHash\":\""+ckbContextString(object,"combinationAuditHash")+"\""
        let composite=benchmarkGapSha256("{"+fields+"}");if(ckbContextString(object,"compositeHash")!=composite){return ""};"{"+fields+",\"compositeHash\":\""+composite+"\"}"
    }catch(_:Exception){""}
}
private func ckbContextParseStudentRules(raw:String):(ArrayList<CkbStudentRuleCandidate>,String) {
    let out=ArrayList<CkbStudentRuleCandidate>()
    try {
        let object=JsonValue.fromStr(raw.trimAscii()).asObject();if(object.getFields().size!=6||ckbContextString(object,"schemaVersion")!="ckb-student-rules-bundle-v1"){return(out,"candidate_lane_hash_mismatch")}
        for(value in object.get("rules").getOrThrow().asArray().getItems()){
            let row=value.asObject();if(row.getFields().size!=19||ckbContextString(row,"schemaVersion")!="teacher-rule-candidate-v1"||ckbContextString(row,"assetRole")!="rules"){return(out,"candidate_lane_hash_mismatch")};let rule=CkbStudentRuleCandidate();rule.ruleId=ckbContextString(row,"ruleId");rule.conceptId=ckbContextString(row,"conceptId");rule.title=ckbContextString(row,"title");rule.body=ckbContextString(row,"body");rule.trigger=ckbContextString(row,"trigger");rule.scope=ckbContextString(row,"scope");rule.priority=ckbContextInt(row,"priority");rule.sourceEvidenceKind=ckbContextString(row,"sourceEvidenceKind");rule.sourceEvidenceHash=ckbContextString(row,"sourceEvidenceHash");rule.assetLineage=ckbContextString(row,"assetLineage");rule.positiveEvidenceHash=ckbContextString(row,"positiveEvidenceHash");rule.negativeEvidenceHash=ckbContextString(row,"negativeEvidenceHash");rule.boundaryEvidenceHash=ckbContextString(row,"boundaryEvidenceHash");rule.generalizationEvidenceHash=ckbContextString(row,"generalizationEvidenceHash");rule.canonicalHash=ckbContextString(row,"canonicalHash");rule.agentsMarkdown=ckbContextString(row,"content");let lineageValid=(rule.sourceEvidenceKind=="independent_manifest"&&rule.assetLineage=="independent")||(rule.sourceEvidenceKind=="completion_failure"&&rule.assetLineage=="humaneval_164_derived");let expectedContent="\n## ${rule.title}\n\n${rule.body}\n\nTrigger: ${rule.trigger}\nScope: ${rule.scope}\n";if(rule.ruleId==""||rule.conceptId==""||rule.title==""||rule.body==""||rule.trigger==""||rule.scope==""||rule.priority<0||rule.priority>1000||ckbContextString(row,"contentHash")!=benchmarkGapSha256(rule.agentsMarkdown)||rule.agentsMarkdown!=expectedContent||rule.canonicalHash!=ckbStudentRuleCandidateCanonicalHash(rule)||!ckbContextHash(rule.sourceEvidenceHash)||!ckbContextHash(rule.positiveEvidenceHash)||!ckbContextHash(rule.negativeEvidenceHash)||!ckbContextHash(rule.boundaryEvidenceHash)||!ckbContextHash(rule.generalizationEvidenceHash)||!ckbContextHash(rule.canonicalHash)||!lineageValid||ckbStudentVisibleAssetForbidden(rule.ruleId+"\n"+rule.title+"\n"+rule.body+"\n"+rule.trigger+"\n"+rule.scope)){return(out,"candidate_lane_hash_mismatch")};rule.verified=true;rule.diagnostic="ok";out.add(rule)
        }
        (out,"ok")
    }catch(_:Exception){(out,"candidate_lane_hash_mismatch")}
}
private func ckbContextMergeLanes(delta:CkbContextParsedLanes,candidate:TeacherContextCandidateSetV2,
    base:CkbContextBaseVersion):CkbContextParsedLanes {
    if(!base.ok){return delta};let out=CkbContextParsedLanes()
    let baseRules=ckbContextParseStudentRules(base.rulesJson);if(baseRules[1]!="ok"){out.diagnostic=baseRules[1];return out}
    let baseSkills=ckbContextParseStudentSkills(base.skillsJson);if(baseSkills[1]!="ok"){out.diagnostic=baseSkills[1];return out}
    let ruleOps=ckbContextOperations(candidate.rules,"rules");if(ruleOps[1]!="ok"){out.diagnostic=ruleOps[1];return out}
    let skillOps=ckbContextOperations(candidate.skills,"skills");if(skillOps[1]!="ok"){out.diagnostic=skillOps[1];return out}
    if(ruleOps[0].size!=delta.rules.size||skillOps[0].size!=delta.skills.size){out.diagnostic="candidate_operation_invalid";return out}
    let replacedRules=HashSet<String>();for(rule in delta.rules){if(!ruleOps[0].contains(rule.ruleId)){out.diagnostic="candidate_operation_invalid";return out};let operation=ruleOps[0][rule.ruleId];if(operation.newHash!=rule.canonicalHash){out.diagnostic="candidate_operation_invalid";return out};var found=false;for(old in baseRules[0]){if(old.ruleId==rule.ruleId){found=true;if(operation.operation!="replace"||operation.expectedOldHash!=old.canonicalHash){out.diagnostic="candidate_replace_hash_mismatch";return out}}};if(operation.operation=="add"&&found){out.diagnostic="candidate_operation_invalid";return out};if(operation.operation=="replace"&&!found){out.diagnostic="candidate_replace_hash_mismatch";return out};replacedRules.add(rule.ruleId)}
    for(old in baseRules[0]){if(!replacedRules.contains(old.ruleId)){out.rules.add(old)}};for(rule in delta.rules){out.rules.add(rule)}
    let replacedSkills=HashSet<String>();for(skill in delta.skills){if(!skillOps[0].contains(skill.id)){out.diagnostic="candidate_operation_invalid";return out};let operation=skillOps[0][skill.id];if(operation.newHash!=skill.candidateContentHash){out.diagnostic="candidate_operation_invalid";return out};var found=false;for(old in baseSkills[0]){if(old.id==skill.id){found=true;if(operation.operation!="replace"||operation.expectedOldHash!=old.candidateContentHash){out.diagnostic="candidate_replace_hash_mismatch";return out}}};if(operation.operation=="add"&&found){out.diagnostic="candidate_operation_invalid";return out};if(operation.operation=="replace"&&!found){out.diagnostic="candidate_replace_hash_mismatch";return out};replacedSkills.add(skill.id)}
    for(old in baseSkills[0]){if(!replacedSkills.contains(old.id)){out.skills.add(old)}};for(skill in delta.skills){out.skills.add(skill)}
    let crossLane=ckbContextCrossLaneDiagnostic(out.rules,out.skills);if(crossLane!="ok"){out.diagnostic=crossLane};out
}
public func studentContextRuleSkillConflictDiagnostic(ruleText:String,skillText:String):String {if(ruleText==skillText){"duplicate_cross_lane_asset_content"}else if(ckbContextConflictKey(ruleText)==ckbContextConflictKey(skillText)){"conflicting_cross_lane_asset_content"}else{"ok"}}
private func ckbContextCrossLaneDiagnostic(rules:ArrayList<CkbStudentRuleCandidate>,skills:ArrayList<CkbStudentSkillCandidate>):String {for(rule in rules){for(skill in skills){let diagnostic=studentContextRuleSkillConflictDiagnostic(rule.body,skill.procedure);if(diagnostic!="ok"){return diagnostic};if(rule.agentsMarkdown==skill.skillContent){return "duplicate_cross_lane_asset_content"}}};"ok"}
private func ckbContextOperations(lane:TeacherContextLaneV2,role:String):(HashMap<String,CkbContextOperation>,String) {
    let out=HashMap<String,CkbContextOperation>()
    try {
        for(file in lane.files){if(!file.path.endsWith("/operation.json")){continue};let object=JsonValue.fromStr(file.content.trimAscii()).asObject();let operation=CkbContextOperation();operation.role=ckbContextString(object,"assetRole");operation.assetId=ckbContextString(object,"assetId");operation.operation=ckbContextString(object,"operation");operation.expectedOldHash=ckbContextString(object,"expectedOldHash");operation.newHash=ckbContextString(object,"newHash");if(object.getFields().size!=6||operation.role!=role||!ckbContextSafeComponent(operation.assetId)||out.contains(operation.assetId)||!["add","replace"].contains(operation.operation)||!ckbContextHash(operation.newHash)||(operation.operation=="add"&&operation.expectedOldHash!="")||(operation.operation=="replace"&&!ckbContextHash(operation.expectedOldHash))){return(out,"candidate_operation_invalid")};out[operation.assetId]=operation}
        if(lane.eligible&&out.isEmpty()||!lane.eligible&&!out.isEmpty()){return(out,"candidate_operation_invalid")};(out,"ok")
    }catch(_:Exception){(out,"candidate_operation_invalid")}
}
public func ckbWriteDerivedFrozenKnowledgeReference(store:FileKnowledgeStore,
    options:CkbFrozenKnowledgeReferenceWriteOptions):CkbFrozenKnowledgeReferenceWriteResult {
    let out=CkbFrozenKnowledgeReferenceWriteResult()
    for(path in [options.selectedAtomsPath,options.selectionProofPath,options.atomTestSummaryPath,
        options.frozenManifestPath,store.rootPath(),options.outputPath]){
        if(ckbContextAllowedPath(options.allowedRoot,path)!="ok"){
            out.diagnostic="artifact_path_outside_allowed_root";return out
        }
    }
    let selectedDisk=ckbContextRead(Path(options.selectedAtomsPath));let proofDisk=ckbContextRead(Path(options.selectionProofPath))
    let atomDisk=ckbContextRead(Path(options.atomTestSummaryPath));let manifestDisk=ckbContextRead(Path(options.frozenManifestPath))
    for(read in [selectedDisk,proofDisk,atomDisk,manifestDisk]){if(read[1]!="ok"){out.diagnostic=read[1];return out}}
    try {
        let selectedRaw=selectedDisk[0];let lines=ArrayList<String>()
        for(line in selectedRaw.split("\n")){if(line.trimAscii()!=""){lines.add(line.trimAscii())}}
        if(lines.size!=1||selectedRaw!=lines[0]+"\n"){out.diagnostic="selected_atoms_count_invalid";return out}
        let parsed=parseBenchmarkGapInputsJsonl(selectedRaw)
        if(!parsed.ok||parsed.inputs.size!=1){out.diagnostic="selected_atoms_invalid";return out}
        let selected=parsed.inputs[0];let exactBundle=ckbMcpJsonObjectField(lines[0],"knowledgeAtomTestBundle")
        if(!selected.knowledgeAtomCandidate||exactBundle==""){out.diagnostic="selected_atoms_invalid";return out}
        selected.knowledgeAtomTestBundle=exactBundle
        if(selected.candidateHash!=canonicalBenchmarkGapCandidateHash(selected)){
            out.diagnostic="selected_atoms_invalid";return out
        }
        let curated=curateBenchmarkGapRecords(parsed.inputs)
        if(!curated.ok||curated.records.size!=1){out.diagnostic="selected_atoms_invalid";return out}
        let atom=validateKnowledgeAtomTestBundle(exactBundle)
        if(!atom.ok){out.diagnostic=atom.diagnostic;return out}
        let bundleObject=JsonValue.fromStr(exactBundle).asObject()
        let candidateHash=ckbContextString(bundleObject,"candidateHash")
        if(candidateHash!=cangjieKnowledgeAtomCandidateHash(exactBundle)){
            out.diagnostic="atom_candidate_hash_mismatch";return out
        }
        let proof=JsonValue.fromStr(proofDisk[0].trimAscii()).asObject()
        let migrations=proof.get("schemaMigrations").getOrThrow().toString()
        let proofBody="{\"schemaVersion\":\"ckb-atom-selection-proof-v2\",\"inputRows\":${ckbContextInt(proof,"inputRows")},\"selected\":${ckbContextInt(proof,"selected")},\"manifestHash\":\"${ckbContextString(proof,"manifestHash")}\",\"aggregateHash\":\"${ckbContextString(proof,"aggregateHash")}\",\"selectionSetHash\":\"${ckbContextString(proof,"selectionSetHash")}\",\"schemaMigrations\":${migrations}"
        if(proof.getFields().size!=8||ckbContextInt(proof,"inputRows")<1||ckbContextInt(proof,"selected")!=1||
            !ckbContextHash(ckbContextString(proof,"manifestHash"))||!ckbContextHash(ckbContextString(proof,"selectionSetHash"))||
            ckbContextString(proof,"aggregateHash")!=benchmarkGapSha256(selectedRaw)||
            ckbContextString(proof,"evidenceHash")!=benchmarkGapSha256(proofBody+"}")||
            proofDisk[0].trimAscii()!=proofBody+",\"evidenceHash\":\"${ckbContextString(proof,"evidenceHash")}\"}"){
            out.diagnostic="selected_atoms_proof_invalid";return out
        }
        let atomSummary=JsonValue.fromStr(atomDisk[0].trimAscii()).asObject()
        let bundleEvidence="${atom.atomId}|${candidateHash}|${benchmarkGapSha256(exactBundle.trimAscii())}"
        let expectedBundleEvidenceHash=benchmarkGapSha256("${bundleEvidence.toArray().size}:${bundleEvidence}")
        let atomBody="{\"ok\":true,\"diagnostic\":\"validated\",\"bundleCount\":1,\"testCount\":${ckbContextInt(atomSummary,"testCount")},\"passed\":${ckbContextInt(atomSummary,"passed")},\"failed\":0,\"selectedAtomsHash\":\"${benchmarkGapSha256(selectedRaw)}\",\"bundleEvidenceHash\":\"${expectedBundleEvidenceHash}\""
        if(atomSummary.getFields().size!=9||!ckbContextBool(atomSummary,"ok")||
            ckbContextString(atomSummary,"diagnostic")!="validated"||ckbContextInt(atomSummary,"bundleCount")!=1||
            ckbContextInt(atomSummary,"testCount")<=0||ckbContextInt(atomSummary,"passed")!=ckbContextInt(atomSummary,"testCount")||
            ckbContextInt(atomSummary,"failed")!=0||ckbContextString(atomSummary,"evidenceHash")!=benchmarkGapSha256(atomBody+"}")||
            atomDisk[0]!=atomBody+",\"evidenceHash\":\"${ckbContextString(atomSummary,"evidenceHash")}\"}\n"){
            out.diagnostic="atom_test_summary_invalid";return out
        }
        let manifestRaw=manifestDisk[0].trimAscii()
        if(manifestDisk[0]!=manifestRaw||ckbFrozenCandidateManifestDiagnostic(store,manifestRaw)!="ok"){
            out.diagnostic="frozen_candidate_manifest_invalid";return out
        }
        let manifest=JsonValue.fromStr(manifestRaw).asObject();let snapshot=store.loadActiveSnapshot()
        let version=ckbContextString(manifest,"knowledgeVersion");let checksum=ckbContextString(manifest,"candidateChecksum")
        if(!snapshot.valid||ckbCertifiedNormalizedRecordsChecksum(snapshot.normalizedRecords)!=checksum||
            ckbContextString(manifest,"atomTestArtifactHash")!=benchmarkGapSha256(atomDisk[0])){
            out.diagnostic="frozen_candidate_manifest_invalid";return out
        }
        out.referenceJson="{\"schemaVersion\":\"ckb-frozen-knowledge-reference-v1\",\"knowledgeCandidateHash\":\"${candidateHash}\",\"knowledgeVersion\":\"${ckbContextEscape(version)}\",\"frozenCandidateManifestHash\":\"${benchmarkGapSha256(manifestDisk[0])}\",\"knowledgeContentHash\":\"${checksum}\",\"assetLineage\":\"humaneval_164_derived\"}"
        if(ckbContextKnowledgeReferenceDiagnostic(out.referenceJson,"verified",options.frozenManifestPath,
            Some<FileKnowledgeStore>(store))!="ok"){out.diagnostic="frozen_knowledge_reference_invalid";return out}
        let published=ckbContextPublishFrozenKnowledgeReference(options.outputPath,out.referenceJson+"\n")
        if(published!="ok"){out.diagnostic=published;return out}
        out.knowledgeCandidateHash=candidateHash;out.referenceHash=benchmarkGapSha256(out.referenceJson+"\n")
        out.ok=true;out.diagnostic="ok";out
    }catch(_:Exception){out.diagnostic="malformed_json";out}
}
private func ckbContextPublishFrozenKnowledgeReference(path:String,content:String):String {
    let output=Path(path);let suffix=benchmarkGapSha256(content).replace("sha256:","");let stage=Path("${path}.tmp-${suffix}")
    try{
        if(exists(output)){let current=ckbContextRead(output);return if(current[1]=="ok"&&current[0]==content){"ok"}else{"frozen_knowledge_reference_output_conflict"}}
        if(!exists(output.parent)){Directory.create(output.parent,recursive:true)}
        if(exists(stage)){return "frozen_knowledge_reference_partial_publish_blocked"}
        File.writeTo(stage,content.toArray());rename(stage.toString(),to:output.toString(),overwrite:false);"ok"
    }catch(_:Exception){try{if(exists(stage)){remove(stage)}}catch(_:Exception){};"frozen_knowledge_reference_partial_publish_blocked"}
}
private func ckbContextKnowledgeReferenceDiagnostic(raw:String,mode:String,frozenManifestPath:String,store:Option<FileKnowledgeStore>):String {
    try{let text=raw.trimAscii();let o=JsonValue.fromStr(text).asObject();if(o.getFields().size!=6||ckbContextString(o,"schemaVersion")!="ckb-frozen-knowledge-reference-v1"){return "frozen_knowledge_reference_invalid"};for(key in ["knowledgeCandidateHash","frozenCandidateManifestHash","knowledgeContentHash"]){if(!ckbContextHash(ckbContextString(o,key))){return "frozen_knowledge_reference_invalid"}};let lineage=ckbContextString(o,"assetLineage");if(!["independent","humaneval_164_derived"].contains(lineage)||ckbContextString(o,"knowledgeVersion")==""){return "frozen_knowledge_reference_invalid"};if(text!=ckbContextRenderKnowledgeReference(o)){return "frozen_knowledge_reference_invalid"};if(mode=="verified"){let manifest=ckbContextRead(Path(frozenManifestPath));if(manifest[1]!="ok"||benchmarkGapSha256(manifest[0])!=ckbContextString(o,"frozenCandidateManifestHash")){return "frozen_knowledge_reference_invalid"};let manifestObject=JsonValue.fromStr(manifest[0].trimAscii()).asObject();if(ckbContextString(manifestObject,"knowledgeVersion")!=ckbContextString(o,"knowledgeVersion")||ckbContextString(manifestObject,"candidateChecksum")!=ckbContextString(o,"knowledgeContentHash")){return "frozen_knowledge_reference_invalid"};match(store){case Some(value)=>let snapshot=value.loadActiveSnapshot();if(ckbFrozenCandidateManifestDiagnostic(value,manifest[0].trimAscii())!="ok"||!snapshot.valid||ckbCertifiedNormalizedRecordsChecksum(snapshot.normalizedRecords)!=ckbContextString(o,"knowledgeContentHash")){return "frozen_knowledge_reference_invalid"};case None=>return "frozen_knowledge_reference_invalid"}};"ok"}catch(_:Exception){"frozen_knowledge_reference_invalid"}
}
private func ckbContextRenderKnowledgeReference(o:JsonObject):String {"{\"schemaVersion\":\"ckb-frozen-knowledge-reference-v1\",\"knowledgeCandidateHash\":\"${ckbContextString(o,"knowledgeCandidateHash")}\",\"knowledgeVersion\":\"${ckbContextEscape(ckbContextString(o,"knowledgeVersion"))}\",\"frozenCandidateManifestHash\":\"${ckbContextString(o,"frozenCandidateManifestHash")}\",\"knowledgeContentHash\":\"${ckbContextString(o,"knowledgeContentHash")}\",\"assetLineage\":\"${ckbContextString(o,"assetLineage")}\"}"}
private func ckbContextChangedLanes(candidate:TeacherContextCandidateSetV2):String {var out="";for((name,eligible) in [("knowledge",candidate.knowledge.eligible),("rules",candidate.rules.eligible),("skills",candidate.skills.eligible)]){if(eligible){if(out!=""){out+=","};out+="\"${name}\""}};out}
private func ckbContextOperationDiagnostic(candidate:TeacherContextCandidateSetV2,baseRoot:String):String {
    let genesis=candidate.baseCompositeHash=="none";if(genesis!=(baseRoot=="none")){return "candidate_base_composite_mismatch"}
    if(!genesis){let manifest=ckbContextRead(Path(baseRoot).join("student-context-manifest.json"));if(manifest[1]!="ok"){return "candidate_base_composite_mismatch"};try{let o=JsonValue.fromStr(manifest[0]).asObject();if(ckbContextString(o,"compositeHash")!=candidate.baseCompositeHash){return "candidate_base_composite_mismatch"}}catch(_:Exception){return "candidate_base_composite_mismatch"}}
    if(genesis&&(!candidate.rules.eligible||!candidate.skills.eligible||!candidate.knowledge.eligible||candidate.rules.lineage!="independent"||candidate.skills.lineage!="independent"||candidate.knowledge.lineage!="independent")){return "candidate_operation_invalid"}
    for((role,lane) in [("rules",candidate.rules),("skills",candidate.skills)]){var count:Int64=0;for(file in lane.files){if(!file.path.endsWith("/operation.json")){continue};count+=1;try{let o=JsonValue.fromStr(file.content.trimAscii()).asObject();if(o.getFields().size!=6||ckbContextString(o,"schemaVersion")!="teacher-context-asset-operation-v1"||ckbContextString(o,"assetRole")!=role||!ckbContextSafeComponent(ckbContextString(o,"assetId"))||!ckbContextHash(ckbContextString(o,"newHash"))){return "candidate_operation_invalid"};let operation=ckbContextString(o,"operation");let old=ckbContextString(o,"expectedOldHash");if(operation=="add"){if(old!=""){return "candidate_operation_invalid"}}else if(operation=="replace"){if(genesis||!ckbContextHash(old)){return "candidate_replace_hash_mismatch"}}else{return "candidate_operation_invalid"};if(genesis&&operation!="add"){return "candidate_operation_invalid"}}catch(_:Exception){return "candidate_operation_invalid"}};if(lane.eligible&&count==0){return "candidate_operation_invalid"};if(!lane.eligible&&count!=0){return "candidate_operation_invalid"}}
    "ok"
}
private func ckbContextHash(v:String):Bool{let r=v.toRuneArray();if(r.size!=71||!v.startsWith("sha256:")){return false};for(i in 7..71){let c=r[i];if(!((c>=r'0'&&c<=r'9')||(c>=r'a'&&c<=r'f'))){return false}};true}
private func ckbContextPart(v:String):String{"${v.toArray().size}:${v}"}
private func ckbContextConflictKey(v:String):String{v.toAsciiLower().replace("must not","must").replace("never","must").replace("do not","do").replace(" ","")}
private func ckbContextCombinationAuditHash(rulesHash:String,skillsHash:String,knowledgeContentHash:String,sourceClosureHash:String,protectedClosureHash:String):String {benchmarkGapSha256(ckbContextPart(rulesHash)+ckbContextPart(skillsHash)+ckbContextPart(knowledgeContentHash)+ckbContextPart(sourceClosureHash)+ckbContextPart(protectedClosureHash))}
private func ckbContextSafeComponent(v:String):Bool{v!=""&&v!="."&&v!=".."&&!v.contains("/")&&!v.contains("\\")&&!v.contains("..")}

public func runStudentContextImportCli(args:Array<String>):Int64 {
    var allowed="";var base="";var candidate="";var approval="";var frozen="";var knowledgeStore="";var output="";var version="";var scaffold=false;var json=args.contains("--json");var command=false;var parsedJson=false;var i:Int64=0;let seen=HashSet<String>()
    while(i<args.size){let a=args[i];if(a=="cangjie-student-context-import"){if(command){ckbContextCliPrint(json,false,"usage_error","duplicate student context import command");return 2};command=true;i+=1;continue};if(a=="--scaffold-import"){if(scaffold){ckbContextCliPrint(json,false,"usage_error","duplicate --scaffold-import");return 2};scaffold=true;i+=1;continue};if(a=="--json"){if(parsedJson){ckbContextCliPrint(true,false,"usage_error","duplicate --json");return 2};parsedJson=true;i+=1;continue};if(!["--allowed-root","--base-context","--candidate-set","--approval","--frozen-knowledge-manifest","--knowledge-store","--output","--context-version"].contains(a)||i+1>=args.size||seen.contains(a)){ckbContextCliPrint(json,false,"usage_error","invalid student context import argument");return 2};seen.add(a);let v=args[i+1];if(a=="--allowed-root"){allowed=v}else if(a=="--base-context"){base=v}else if(a=="--candidate-set"){candidate=v}else if(a=="--approval"){approval=v}else if(a=="--frozen-knowledge-manifest"){frozen=v}else if(a=="--knowledge-store"){knowledgeStore=v}else if(a=="--output"){output=v}else{version=v};i+=2}
    if(!command||allowed==""||base==""||candidate==""||approval==""||frozen==""||knowledgeStore==""||output==""||version==""){ckbContextCliPrint(json,false,"usage_error","student context import arguments incomplete");return 2}
    for(path in [candidate,approval,frozen,knowledgeStore,output]){if(ckbContextAllowedPath(allowed,path)!="ok"){ckbContextCliPrint(json,false,"artifact_path_outside_allowed_root","student context import blocked");return 1}};if(base!="none"&&ckbContextAllowedPath(allowed,base)!="ok"){ckbContextCliPrint(json,false,"artifact_path_outside_allowed_root","student context import blocked");return 1};let store=FileKnowledgeStore(knowledgeStore)
    let built=compileAndPublishStudentContextBundle(allowed,version,candidate,approval,base,frozen,store,output,scaffold)
    if(!built.ok){ckbContextCliPrint(json,false,built.diagnostic,"student context import blocked");return 1};println(if(json){"{\"ok\":true,\"compositeHash\":\"${built.compositeHash}\",\"validationLevel\":\"${if(scaffold){"scaffold_contract"}else{"student_validated"}}\"}"}else{"student context imported version=${version} validation=${if(scaffold){"scaffold_contract"}else{"student_validated"}}"});0
}
public func runFrozenKnowledgeReferenceWriteCli(args:Array<String>):Int64 {
    let options=CkbFrozenKnowledgeReferenceWriteOptions();var storePath="";var command=false;var json=false;var i:Int64=0;let seen=HashSet<String>()
    while(i<args.size){let arg=args[i];if(arg=="cangjie-frozen-knowledge-reference-write"){if(command){ckbContextCliPrint(json,false,"usage_error","frozen knowledge reference write blocked");return 2};command=true;i+=1;continue};if(arg=="--json"){if(json){ckbContextCliPrint(true,false,"usage_error","frozen knowledge reference write blocked");return 2};json=true;i+=1;continue};if(!["--allowed-root","--selected-atoms","--selection-proof","--atom-test-summary","--frozen-candidate-manifest","--store","--output"].contains(arg)||i+1>=args.size||seen.contains(arg)){ckbContextCliPrint(json,false,"usage_error","frozen knowledge reference write blocked");return 2};seen.add(arg);let value=args[i+1];if(arg=="--allowed-root"){options.allowedRoot=value}else if(arg=="--selected-atoms"){options.selectedAtomsPath=value}else if(arg=="--selection-proof"){options.selectionProofPath=value}else if(arg=="--atom-test-summary"){options.atomTestSummaryPath=value}else if(arg=="--frozen-candidate-manifest"){options.frozenManifestPath=value}else if(arg=="--store"){storePath=value}else{options.outputPath=value};i+=2}
    if(!command||options.allowedRoot==""||options.selectedAtomsPath==""||options.selectionProofPath==""||options.atomTestSummaryPath==""||options.frozenManifestPath==""||storePath==""||options.outputPath==""){ckbContextCliPrint(json,false,"usage_error","frozen knowledge reference write blocked");return 2}
    let result=ckbWriteDerivedFrozenKnowledgeReference(FileKnowledgeStore(storePath),options)
    if(json){println("{\"ok\":${result.ok},\"diagnostic\":\"${ckbContextEscape(result.diagnostic)}\",\"knowledgeCandidateHash\":\"${result.knowledgeCandidateHash}\",\"referenceHash\":\"${result.referenceHash}\"}")}else{println("frozen knowledge reference write ok=${result.ok} diagnostic=${result.diagnostic} referenceHash=${result.referenceHash}")}
    if(result.ok){0}else{1}
}
public func renderStudentContextImportCliDiagnostic(json:Bool,ok:Bool,diagnostic:String,message:String):String {if(json){"{\"ok\":${ok},\"diagnostic\":\"${ckbContextEscape(diagnostic)}\",\"message\":\"${ckbContextEscape(message)}\"}"}else{"${message}: ${diagnostic}"}}
private func ckbContextCliPrint(json:Bool,ok:Bool,diagnostic:String,message:String):Unit {println(renderStudentContextImportCliDiagnostic(json,ok,diagnostic,message))}
private func ckbContextAllowedPath(root:String,value:String):String {
    try {
        if(!root.startsWith("/")||!value.startsWith("/")||value.contains("\\")){
            return "artifact_path_outside_allowed_root"
        }
        var rawPrefix=""
        for(component in value.split("/")){
            if(component==""){continue}
            if(component=="."||component==".."){
                return "artifact_path_outside_allowed_root"
            }
            rawPrefix+="/"+component
            let rawPath=Path(rawPrefix)
            if(exists(rawPath)&&FileInfo(rawPath).isSymbolicLink()){
                return "artifact_path_outside_allowed_root"
            }
        }
        let canonicalRoot=canonicalize(Path(root)).toString();if(root!=canonicalRoot){return "artifact_path_outside_allowed_root"};let path=Path(value)
        let canonicalPath=if(exists(path)){canonicalize(path).toString()}else{value}
        if(canonicalPath==canonicalRoot||canonicalPath.startsWith(canonicalRoot+"/")){
            "ok"
        }else{"artifact_path_outside_allowed_root"}
    }catch(_:Exception){"artifact_path_outside_allowed_root"}
}
