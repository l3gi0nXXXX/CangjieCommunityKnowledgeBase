package cangjie_community_knowledge_base

import std.collection.*
import std.fs.*
import std.sort.*
import stdx.encoding.json.*

public class TeacherArtifactFile {
    public let path:String
    public let content:String
    public init(path:String,content:String){this.path=path;this.content=content}
}
public class TeacherContextLaneV2 {
    public let eligible:Bool
    public let hash:String
    public let treeHash:String
    public let count:Int64
    public let lineage:String
    public let visibleContent:String
    public let files:Array<TeacherArtifactFile>
    public init(eligible:Bool,hash:String,treeHash:String,count:Int64,lineage:String,
        visibleContent:String,files:Array<TeacherArtifactFile>){
        this.eligible=eligible;this.hash=hash;this.treeHash=treeHash;this.count=count
        this.lineage=lineage;this.visibleContent=visibleContent;this.files=files
    }
}
public class TeacherContextCandidateSetV2 {
    public let candidateSetId:String
    public let baseCompositeHash:String
    public let validationLevel:String
    public let sourceEvidenceManifestHash:String
    public let classificationManifestHash:String
    public let sourceClosureHash:String
    public let protectedClosureHash:String
    public let rules:TeacherContextLaneV2
    public let skills:TeacherContextLaneV2
    public let knowledge:TeacherContextLaneV2
    public let knowledgeTargetVersion:String
    public let assetInventoryHash:String
    public let combinationAuditHash:String
    public let candidateSetHash:String
    public init(candidateSetId:String,baseCompositeHash:String,validationLevel:String,
        sourceEvidenceManifestHash:String,classificationManifestHash:String,sourceClosureHash:String,
        protectedClosureHash:String,rules:TeacherContextLaneV2,skills:TeacherContextLaneV2,
        knowledge:TeacherContextLaneV2,knowledgeTargetVersion:String,assetInventoryHash:String,
        combinationAuditHash:String,candidateSetHash:String){
        this.candidateSetId=candidateSetId;this.baseCompositeHash=baseCompositeHash
        this.validationLevel=validationLevel;this.sourceEvidenceManifestHash=sourceEvidenceManifestHash
        this.classificationManifestHash=classificationManifestHash;this.sourceClosureHash=sourceClosureHash
        this.protectedClosureHash=protectedClosureHash;this.rules=rules;this.skills=skills
        this.knowledge=knowledge;this.knowledgeTargetVersion=knowledgeTargetVersion
        this.assetInventoryHash=assetInventoryHash;this.combinationAuditHash=combinationAuditHash
        this.candidateSetHash=candidateSetHash
    }
}

public func parseTeacherContextCandidateSetDirectoryV2(allowedRoot:String,path:String):TeacherContextCandidateSetV2 {
    if(ckbTeacherV2AllowedPath(allowedRoot,path)!="ok"){throw IllegalArgumentException("artifact_path_outside_allowed_root")}
    let root=Path(path)
    try{
        if(!exists(root)||FileInfo(root).isSymbolicLink()||!FileInfo(root).isDirectory()){throw IllegalArgumentException("candidate_set_schema_invalid")}
        let expected=HashSet<String>(["candidate-set-manifest.json","audit","rules","skills","knowledge"])
        for(entry in Directory.readFrom(root)){if(entry.isSymbolicLink()||!expected.contains(entry.name)){throw IllegalArgumentException("candidate_set_schema_invalid")};if(entry.name=="candidate-set-manifest.json"){if(!entry.isRegular()){throw IllegalArgumentException("candidate_set_schema_invalid")}}else if(!entry.isDirectory()){throw IllegalArgumentException("candidate_set_schema_invalid")};expected.remove(entry.name)}
        if(!expected.isEmpty()){throw IllegalArgumentException("candidate_set_schema_invalid")}
        let manifestDisk=ckbTeacherV2Read(root.join("candidate-set-manifest.json"));let raw=manifestDisk.trimAscii();let object=JsonValue.fromStr(raw).asObject()
        if(object.getFields().size!=26||ckbTeacherV2String(object,"schemaVersion")!="teacher-student-context-candidate-set-v2"){throw IllegalArgumentException("candidate_set_schema_invalid")}
        let rulesFiles=ckbTeacherV2ReadTree(root.join("rules"));let skillsFiles=ckbTeacherV2ReadTree(root.join("skills"));let knowledgeFiles=ckbTeacherV2ReadTree(root.join("knowledge"));let auditFiles=ckbTeacherV2ReadTree(root.join("audit"))
        let rules=ckbTeacherV2Lane(object,"rules",rulesFiles);let skills=ckbTeacherV2Lane(object,"skills",skillsFiles);let knowledge=ckbTeacherV2KnowledgeLane(object,knowledgeFiles)
        ckbTeacherV2ValidateCandidateDirectories(root,skills)
        let sourceHash=ckbTeacherV2String(object,"sourceEvidenceManifestHash");let sourceClosure=ckbTeacherV2String(object,"sourceClosureHash");let protectedClosure=ckbTeacherV2String(object,"protectedClosureHash")
        ckbTeacherV2ValidateAudit(auditFiles,sourceHash,sourceClosure,protectedClosure)
        let inventoryHash=ckbTeacherV2AssetInventoryHash(rulesFiles,skillsFiles,knowledgeFiles,auditFiles)
        let candidate=TeacherContextCandidateSetV2(ckbTeacherV2String(object,"candidateSetId"),ckbTeacherV2String(object,"baseCompositeHash"),ckbTeacherV2String(object,"validationLevel"),sourceHash,ckbTeacherV2String(object,"classificationManifestHash"),sourceClosure,protectedClosure,rules,skills,knowledge,ckbTeacherV2String(object,"knowledgeTargetVersion"),inventoryHash,ckbTeacherV2String(object,"combinationAuditHash"),ckbTeacherV2String(object,"candidateSetHash"))
        if(!ckbTeacherV2SafeComponent(candidate.candidateSetId)||!(candidate.baseCompositeHash=="none"||ckbTeacherV2Hash(candidate.baseCompositeHash))||!["scaffold_contract","student_validated"].contains(candidate.validationLevel)||!ckbTeacherV2Hash(candidate.sourceEvidenceManifestHash)||!(candidate.classificationManifestHash==""||ckbTeacherV2Hash(candidate.classificationManifestHash))||!ckbTeacherV2Hash(candidate.sourceClosureHash)||!ckbTeacherV2Hash(candidate.protectedClosureHash)||!ckbTeacherV2Hash(candidate.assetInventoryHash)||!ckbTeacherV2Hash(candidate.combinationAuditHash)||!ckbTeacherV2SafeVersion(candidate.knowledgeTargetVersion)||candidate.assetInventoryHash!=ckbTeacherV2String(object,"assetInventoryHash")){throw IllegalArgumentException("candidate_set_schema_invalid")}
        let canonical=ckbTeacherV2RenderManifest(candidate)
        if(candidate.candidateSetHash!=benchmarkGapSha256(ckbTeacherV2ManifestEvidence(candidate))||raw!=canonical||manifestDisk!=canonical+"\n"){throw IllegalArgumentException("candidate_set_hash_mismatch")}
        ckbTeacherV2ValidateLaneTruth(root,candidate)
        candidate
    }catch(e:IllegalArgumentException){throw e}catch(_:Exception){throw IllegalArgumentException("candidate_set_schema_invalid")}
}

private func ckbTeacherV2ValidateLaneTruth(root:Path,candidate:TeacherContextCandidateSetV2):Unit {
    let genesis=candidate.baseCompositeHash=="none"
    if(genesis&&candidate.classificationManifestHash!=""){throw IllegalArgumentException("candidate_lane_lineage_invalid")}
    if(!genesis&&((candidate.rules.eligible&&candidate.rules.lineage=="independent")||
        (candidate.skills.eligible&&candidate.skills.lineage=="independent")||
        (candidate.knowledge.eligible&&candidate.knowledge.lineage=="independent"))){throw IllegalArgumentException("candidate_lane_lineage_invalid")}
    if((candidate.rules.lineage=="humaneval_164_derived"||candidate.skills.lineage=="humaneval_164_derived"||candidate.knowledge.lineage=="humaneval_164_derived")&&!ckbTeacherV2Hash(candidate.classificationManifestHash)){throw IllegalArgumentException("candidate_lane_lineage_invalid")}
    if(candidate.rules.eligible){
        let parsed=ArrayList<CkbStudentRuleCandidate>()
        for(entry in Directory.readFrom(root.join("rules"))){let rule=parseStudentRuleCandidateDirectory(entry.path.toString());if(!rule.verified||rule.assetLineage!=candidate.rules.lineage||(rule.assetLineage=="humaneval_164_derived"&&(rule.sourceEvidenceKind!="completion_failure"||rule.sourceEvidenceHash!=candidate.classificationManifestHash))||(rule.assetLineage=="independent"&&(!genesis||rule.sourceEvidenceKind!="independent_manifest"||rule.sourceEvidenceHash!=candidate.sourceEvidenceManifestHash))){throw IllegalArgumentException("candidate_lane_lineage_invalid")};parsed.add(rule)}
        let compiled=compileStudentRulesBundle("candidate-parse",parsed)
        if(!compiled.ok||Int64(parsed.size)!=candidate.rules.count||benchmarkGapSha256(compiled.agentsMarkdown)!=candidate.rules.hash){throw IllegalArgumentException("candidate_lane_hash_mismatch")}
    }
    if(candidate.skills.eligible){
        let parsed=ArrayList<CkbStudentSkillCandidate>()
        for(entry in Directory.readFrom(root.join("skills"))){let skill=parseStudentSkillCandidateDirectory(entry.path.toString(),candidate.skills.lineage=="independent");if(!skill.verified||skill.lineage!=candidate.skills.lineage||(skill.lineage=="independent"&&!genesis)){throw IllegalArgumentException("candidate_lane_lineage_invalid")};parsed.add(skill)}
        let compiled=compileStudentSkillBundle("candidate-parse",parsed)
        if(!compiled.ok||Int64(parsed.size)!=candidate.skills.count||benchmarkGapSha256(renderStudentVisibleSkillPrompt(compiled.json))!=candidate.skills.hash){throw IllegalArgumentException("candidate_lane_hash_mismatch")}
    }
    if(candidate.knowledge.eligible){
        let raw=candidate.knowledge.files[0].content;let object=JsonValue.fromStr(raw.trimAscii()).asObject()
        let reference="{\"schemaVersion\":\"ckb-frozen-knowledge-reference-v1\",\"knowledgeCandidateHash\":\"${ckbTeacherV2String(object,"knowledgeCandidateHash")}\",\"knowledgeVersion\":\"${ckbTeacherV2Escape(ckbTeacherV2String(object,"knowledgeVersion"))}\",\"frozenCandidateManifestHash\":\"${ckbTeacherV2String(object,"frozenCandidateManifestHash")}\",\"knowledgeContentHash\":\"${ckbTeacherV2String(object,"knowledgeContentHash")}\",\"assetLineage\":\"${ckbTeacherV2String(object,"assetLineage")}\"}\n"
        if(object.getFields().size!=6||raw!=reference||ckbTeacherV2String(object,"schemaVersion")!="ckb-frozen-knowledge-reference-v1"||!ckbTeacherV2Hash(ckbTeacherV2String(object,"frozenCandidateManifestHash"))||!ckbTeacherV2Hash(ckbTeacherV2String(object,"knowledgeContentHash"))||ckbTeacherV2String(object,"knowledgeCandidateHash")!=candidate.knowledge.hash||ckbTeacherV2String(object,"knowledgeVersion")!=candidate.knowledgeTargetVersion||ckbTeacherV2String(object,"assetLineage")!=candidate.knowledge.lineage){throw IllegalArgumentException("candidate_lane_hash_mismatch")}
    }
    let expectedCombination=benchmarkGapSha256(ckbTeacherV2Part(candidate.rules.hash)+ckbTeacherV2Part(candidate.skills.hash)+ckbTeacherV2Part(candidate.knowledge.hash)+ckbTeacherV2Part(candidate.sourceClosureHash)+ckbTeacherV2Part(candidate.protectedClosureHash))
    if(candidate.combinationAuditHash!=expectedCombination){throw IllegalArgumentException("candidate_set_hash_mismatch")}
}

private func ckbTeacherV2ValidateCandidateDirectories(root:Path,skills:TeacherContextLaneV2):Unit {
    for(entry in Directory.readFrom(root.join("rules"))){
        if(entry.isSymbolicLink()||!entry.isDirectory()){throw IllegalArgumentException("candidate_set_schema_invalid")}
        let parsed=parseStudentRuleCandidateDirectory(entry.path.toString())
        if(!parsed.verified||parsed.ruleId!=entry.name){throw IllegalArgumentException(parsed.diagnostic)}
    }
    for(entry in Directory.readFrom(root.join("skills"))){
        if(entry.isSymbolicLink()||!entry.isDirectory()){throw IllegalArgumentException("candidate_set_schema_invalid")}
        let parsed=parseStudentSkillCandidateDirectory(entry.path.toString(),skills.lineage=="independent")
        if(!parsed.verified||parsed.id!=entry.name){throw IllegalArgumentException(parsed.diagnostic)}
    }
}

public func validateTeacherContextApprovalV2(raw:String,candidate:TeacherContextCandidateSetV2):String {
    try{
        let object=JsonValue.fromStr(raw).asObject();if(object.getFields().size!=16||ckbTeacherV2String(object,"schemaVersion")!="teacher-student-context-approval-v2"){throw IllegalArgumentException("candidate_approval_hash_mismatch")}
        let decision=ckbTeacherV2String(object,"decision");if(!["approve","reject"].contains(decision)){throw IllegalArgumentException("candidate_approval_rejected")}
        let expected=ckbTeacherV2RenderApproval(candidate,decision,ckbTeacherV2String(object,"reviewer"),ckbTeacherV2String(object,"reason"),ckbTeacherV2String(object,"approvedAtUtc"))
        if(raw!=expected||ckbTeacherV2String(object,"candidateSetHash")!=candidate.candidateSetHash||ckbTeacherV2String(object,"assetInventoryHash")!=candidate.assetInventoryHash||ckbTeacherV2String(object,"rulesHash")!=candidate.rules.hash||ckbTeacherV2String(object,"rulesTreeHash")!=candidate.rules.treeHash||ckbTeacherV2String(object,"skillsHash")!=candidate.skills.hash||ckbTeacherV2String(object,"skillsTreeHash")!=candidate.skills.treeHash||ckbTeacherV2String(object,"knowledgeCandidateHash")!=candidate.knowledge.hash||ckbTeacherV2String(object,"knowledgeTreeHash")!=candidate.knowledge.treeHash||ckbTeacherV2String(object,"sourceClosureHash")!=candidate.sourceClosureHash||ckbTeacherV2String(object,"protectedClosureHash")!=candidate.protectedClosureHash||ckbTeacherV2String(object,"combinationAuditHash")!=candidate.combinationAuditHash){throw IllegalArgumentException("candidate_approval_hash_mismatch")}
        decision
    }catch(e:IllegalArgumentException){throw e}catch(_:Exception){throw IllegalArgumentException("candidate_approval_hash_mismatch")}
}

private func ckbTeacherV2Lane(object:JsonObject,name:String,files:Array<TeacherArtifactFile>):TeacherContextLaneV2 {
    let eligible=ckbTeacherV2Bool(object,"${name}Eligible");if(eligible!=(!files.isEmpty())){throw IllegalArgumentException("candidate_lane_hash_mismatch")}
    let hash=ckbTeacherV2String(object,"${name}Hash");let treeHash=ckbTeacherV2String(object,"${name}TreeHash");let count=ckbTeacherV2Int(object,"${name}Count");let lineage=ckbTeacherV2String(object,if(name=="skills"){"skillAssetLineage"}else{"rulesAssetLineage"})
    if(!ckbTeacherV2Hash(hash)||!ckbTeacherV2Hash(treeHash)||treeHash!=ckbTeacherV2TreeHash(files)||count<1||count>16||!["independent","humaneval_164_derived"].contains(lineage)){throw IllegalArgumentException("candidate_lane_hash_mismatch")}
    var visible="";for(file in files){if((name=="rules"&&file.path.endsWith("/AGENTS.md"))||(name=="skills"&&file.path.endsWith("/SKILL.md"))){visible+=file.content}}
    TeacherContextLaneV2(eligible,hash,treeHash,count,lineage,visible,files)
}
private func ckbTeacherV2KnowledgeLane(object:JsonObject,files:Array<TeacherArtifactFile>):TeacherContextLaneV2 {
    let eligible=ckbTeacherV2Bool(object,"knowledgeEligible");if(eligible!=(!files.isEmpty())||(eligible&&(files.size!=1||files[0].path!="knowledge-candidate-reference.json"))){throw IllegalArgumentException("candidate_lane_hash_mismatch")}
    let hash=ckbTeacherV2String(object,"knowledgeCandidateHash");let treeHash=ckbTeacherV2String(object,"knowledgeTreeHash");let lineage=ckbTeacherV2String(object,"knowledgeAssetLineage");if(!ckbTeacherV2Hash(hash)||!ckbTeacherV2Hash(treeHash)||treeHash!=ckbTeacherV2TreeHash(files)||!["independent","humaneval_164_derived"].contains(lineage)){throw IllegalArgumentException("candidate_lane_hash_mismatch")}
    TeacherContextLaneV2(eligible,hash,treeHash,1,lineage,if(eligible){files[0].content}else{""},files)
}
private func ckbTeacherV2ValidateAudit(files:Array<TeacherArtifactFile>,sourceManifestHash:String,sourceClosureHash:String,protectedClosureHash:String):Unit {
    if(files.size!=2||files[0].path!="protected-closure.json"||files[1].path!="source-closure.json"){throw IllegalArgumentException("candidate_set_schema_invalid")}
    let sourceRaw=files[1].content;let sourceText=sourceRaw.trimAscii();let source=JsonValue.fromStr(sourceText).asObject();if(source.getFields().size!=4||ckbTeacherV2String(source,"schemaVersion")!="teacher-context-source-closure-v2"||ckbTeacherV2String(source,"sourceEvidenceManifestHash")!=sourceManifestHash){throw IllegalArgumentException("candidate_set_schema_invalid")}
    let inventory=ckbTeacherV2SourceInventory(source);let inventoryJson=ckbTeacherV2JsonArray(inventory);let prefix="{\"schemaVersion\":\"teacher-context-source-closure-v2\",\"sourceEvidenceManifestHash\":\"${sourceManifestHash}\",\"sourceInventory\":[${inventoryJson}]}";let expectedSource=benchmarkGapSha256(prefix);let fullSource="{\"schemaVersion\":\"teacher-context-source-closure-v2\",\"sourceEvidenceManifestHash\":\"${sourceManifestHash}\",\"sourceInventory\":[${inventoryJson}],\"sourceClosureHash\":\"${expectedSource}\"}";if(sourceClosureHash!=expectedSource||ckbTeacherV2String(source,"sourceClosureHash")!=expectedSource||sourceText!=fullSource||sourceRaw!=fullSource+"\n"){throw IllegalArgumentException("candidate_set_hash_mismatch")}
    let protectedRaw=files[0].content;let protectedText=protectedRaw.trimAscii();let protected=JsonValue.fromStr(protectedText).asObject();if(protected.getFields().size!=3||ckbTeacherV2String(protected,"schemaVersion")!="teacher-context-protected-closure-v1"){throw IllegalArgumentException("candidate_set_schema_invalid")};let hashes=ckbTeacherV2HashArray(protected,"protectedHashes");let hashesJson=ckbTeacherV2JsonArray(hashes);let protectedPrefix="{\"schemaVersion\":\"teacher-context-protected-closure-v1\",\"protectedHashes\":[${hashesJson}]}";let expectedProtected=benchmarkGapSha256(protectedPrefix);let fullProtected="{\"schemaVersion\":\"teacher-context-protected-closure-v1\",\"protectedHashes\":[${hashesJson}],\"protectedClosureHash\":\"${expectedProtected}\"}";if(protectedClosureHash!=expectedProtected||ckbTeacherV2String(protected,"protectedClosureHash")!=expectedProtected||protectedText!=fullProtected||protectedRaw!=fullProtected+"\n"){throw IllegalArgumentException("candidate_set_hash_mismatch")}
}
private func ckbTeacherV2SourceInventory(object:JsonObject):Array<String> {
    let rows=ArrayList<String>();for(value in object.get("sourceInventory").getOrThrow().asArray().getItems()){rows.add(value.asString().getValue())};if(rows.isEmpty()){throw IllegalArgumentException("candidate_set_schema_invalid")};let paths=ArrayList<String>();let seen=HashSet<String>();for(row in rows){let parts=row.split("  ");if(parts.size!=2||!ckbTeacherV2LowerHex(parts[0])||!ckbTeacherV2Relative(parts[1])||seen.contains(parts[1])){throw IllegalArgumentException("candidate_set_schema_invalid")};seen.add(parts[1]);paths.add(parts[1])};let sorted=paths.toArray().clone();sort(sorted);if(paths.toArray()!=sorted){throw IllegalArgumentException("candidate_set_schema_invalid")};rows.toArray()
}
private func ckbTeacherV2HashArray(object:JsonObject,name:String):Array<String> {let out=ArrayList<String>();for(value in object.get(name).getOrThrow().asArray().getItems()){out.add(value.asString().getValue())};let values=out.toArray();let sorted=values.clone();sort(sorted);let seen=HashSet<String>();if(values.isEmpty()||values!=sorted){throw IllegalArgumentException("candidate_set_schema_invalid")};for(value in values){if(!ckbTeacherV2Hash(value)||seen.contains(value)){throw IllegalArgumentException("candidate_set_schema_invalid")};seen.add(value)};values}
private func ckbTeacherV2ReadTree(root:Path):Array<TeacherArtifactFile> {let out=ArrayList<TeacherArtifactFile>();ckbTeacherV2Collect(root,"",out);ckbTeacherV2Sorted(out.toArray())}
private func ckbTeacherV2Collect(root:Path,relative:String,out:ArrayList<TeacherArtifactFile>):Unit {if(FileInfo(root).isSymbolicLink()||!FileInfo(root).isDirectory()){throw IllegalArgumentException("candidate_set_schema_invalid")};for(entry in Directory.readFrom(root)){if(entry.isSymbolicLink()){throw IllegalArgumentException("candidate_set_schema_invalid")};let path=if(relative==""){entry.name}else{"${relative}/${entry.name}"};if(!ckbTeacherV2Relative(path)){throw IllegalArgumentException("candidate_set_schema_invalid")};if(entry.isDirectory()){ckbTeacherV2Collect(entry.path,path,out)}else if(entry.isRegular()){out.add(TeacherArtifactFile(path,ckbTeacherV2Read(entry.path)))}else{throw IllegalArgumentException("candidate_set_schema_invalid")}}}
private func ckbTeacherV2Sorted(files:Array<TeacherArtifactFile>):Array<TeacherArtifactFile> {let paths=files.map({file:TeacherArtifactFile=>file.path});sort(paths);let out=ArrayList<TeacherArtifactFile>();let seen=HashSet<String>();for(path in paths){if(seen.contains(path)){throw IllegalArgumentException("candidate_set_schema_invalid")};seen.add(path);for(file in files){if(file.path==path){out.add(file);break}}};out.toArray()}
private func ckbTeacherV2TreeHash(files:Array<TeacherArtifactFile>):String {benchmarkGapSha256(ckbTeacherV2Inventory(files,""))}
private func ckbTeacherV2AssetInventoryHash(rules:Array<TeacherArtifactFile>,skills:Array<TeacherArtifactFile>,knowledge:Array<TeacherArtifactFile>,audit:Array<TeacherArtifactFile>):String {let all=ArrayList<TeacherArtifactFile>();for((prefix,files) in [("rules",rules),("skills",skills),("knowledge",knowledge),("audit",audit)]){for(file in files){all.add(TeacherArtifactFile("${prefix}/${file.path}",file.content))}};benchmarkGapSha256(ckbTeacherV2Inventory(all.toArray(),""))}
private func ckbTeacherV2Inventory(files:Array<TeacherArtifactFile>,prefix:String):String {var out="";for(file in ckbTeacherV2Sorted(files)){let path=if(prefix==""){file.path}else{"${prefix}/${file.path}"};out+="${benchmarkGapSha256(file.content).replace("sha256:","")}  ${path}\n"};out}
private func ckbTeacherV2ManifestEvidence(c:TeacherContextCandidateSetV2):String {"{\"schemaVersion\":\"teacher-student-context-candidate-set-v2\",\"candidateSetId\":\"${ckbTeacherV2Escape(c.candidateSetId)}\",\"baseCompositeHash\":\"${c.baseCompositeHash}\",\"validationLevel\":\"${c.validationLevel}\",\"sourceEvidenceManifestHash\":\"${c.sourceEvidenceManifestHash}\",\"classificationManifestHash\":\"${c.classificationManifestHash}\",\"sourceClosureHash\":\"${c.sourceClosureHash}\",\"protectedClosureHash\":\"${c.protectedClosureHash}\",\"rulesEligible\":${c.rules.eligible},\"rulesHash\":\"${c.rules.hash}\",\"rulesTreeHash\":\"${c.rules.treeHash}\",\"rulesCount\":${c.rules.count},\"rulesAssetLineage\":\"${c.rules.lineage}\",\"skillsEligible\":${c.skills.eligible},\"skillsHash\":\"${c.skills.hash}\",\"skillsTreeHash\":\"${c.skills.treeHash}\",\"skillsCount\":${c.skills.count},\"skillAssetLineage\":\"${c.skills.lineage}\",\"knowledgeEligible\":${c.knowledge.eligible},\"knowledgeCandidateHash\":\"${c.knowledge.hash}\",\"knowledgeTreeHash\":\"${c.knowledge.treeHash}\",\"knowledgeTargetVersion\":\"${ckbTeacherV2Escape(c.knowledgeTargetVersion)}\",\"knowledgeAssetLineage\":\"${c.knowledge.lineage}\",\"assetInventoryHash\":\"${c.assetInventoryHash}\",\"combinationAuditHash\":\"${c.combinationAuditHash}\"}"}
private func ckbTeacherV2RenderManifest(c:TeacherContextCandidateSetV2):String {let prefix=ckbTeacherV2ManifestEvidence(c);prefix.replace("}",",\"candidateSetHash\":\"${c.candidateSetHash}\"}")}
private func ckbTeacherV2RenderApproval(c:TeacherContextCandidateSetV2,decision:String,reviewer:String,reason:String,approved:String):String {if(reviewer==""||reason==""||approved==""){throw IllegalArgumentException("candidate_approval_rejected")};"{\"schemaVersion\":\"teacher-student-context-approval-v2\",\"candidateSetHash\":\"${c.candidateSetHash}\",\"assetInventoryHash\":\"${c.assetInventoryHash}\",\"rulesHash\":\"${c.rules.hash}\",\"rulesTreeHash\":\"${c.rules.treeHash}\",\"skillsHash\":\"${c.skills.hash}\",\"skillsTreeHash\":\"${c.skills.treeHash}\",\"knowledgeCandidateHash\":\"${c.knowledge.hash}\",\"knowledgeTreeHash\":\"${c.knowledge.treeHash}\",\"sourceClosureHash\":\"${c.sourceClosureHash}\",\"protectedClosureHash\":\"${c.protectedClosureHash}\",\"combinationAuditHash\":\"${c.combinationAuditHash}\",\"decision\":\"${decision}\",\"reviewer\":\"${ckbTeacherV2Escape(reviewer)}\",\"reason\":\"${ckbTeacherV2Escape(reason)}\",\"approvedAtUtc\":\"${ckbTeacherV2Escape(approved)}\"}"}
private func ckbTeacherV2JsonArray(values:Array<String>):String {var out="";for(i in 0..values.size){if(i>0){out+=","};out+="\"${ckbTeacherV2Escape(values[i])}\""};out}
private func ckbTeacherV2Read(path:Path):String {try{String.fromUtf8(File.readFrom(path))}catch(_:Exception){throw IllegalArgumentException("invalid_response_encoding")}}
private func ckbTeacherV2String(o:JsonObject,k:String):String{o.get(k).getOrThrow().asString().getValue()}
private func ckbTeacherV2Int(o:JsonObject,k:String):Int64{o.get(k).getOrThrow().asInt().getValue()}
private func ckbTeacherV2Bool(o:JsonObject,k:String):Bool{o.get(k).getOrThrow().asBool().getValue()}
private func ckbTeacherV2Escape(v:String):String{v.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t")}
private func ckbTeacherV2Hash(v:String):Bool{v.startsWith("sha256:")&&ckbTeacherV2LowerHex(v.replace("sha256:",""))}
private func ckbTeacherV2Part(v:String):String{"${v.toArray().size}:${v}"}
private func ckbTeacherV2LowerHex(v:String):Bool{let runes=v.toRuneArray();if(runes.size!=64){return false};for(rune in runes){if(!((rune>=r'0'&&rune<=r'9')||(rune>=r'a'&&rune<=r'f'))){return false}};true}
private func ckbTeacherV2SafeComponent(v:String):Bool{v!=""&&v!="."&&v!=".."&&!v.contains("/")&&!v.contains("\\")&&!v.contains("..")}
private func ckbTeacherV2SafeVersion(v:String):Bool{let runes=v.toRuneArray();if(runes.isEmpty()||runes.size>128){return false};for(rune in runes){if(!((rune>=r'a'&&rune<=r'z')||(rune>=r'A'&&rune<=r'Z')||(rune>=r'0'&&rune<=r'9')||rune==r'.'||rune==r'-'||rune==r'_'||rune==r'+')){return false}};true}
private func ckbTeacherV2Relative(v:String):Bool{if(v==""||v.startsWith("/")||v.endsWith("/")||v.contains("\\")){return false};for(component in v.split("/")){if(!ckbTeacherV2SafeComponent(component)){return false};for(rune in component.toRuneArray()){if(!((rune>=r'a'&&rune<=r'z')||(rune>=r'A'&&rune<=r'Z')||(rune>=r'0'&&rune<=r'9')||rune==r'-'||rune==r'_'||rune==r'.')){return false}}};true}
private func ckbTeacherV2AllowedPath(root:String,value:String):String {try{if(!root.startsWith("/")||!value.startsWith("/")||value.contains("\\")){return "artifact_path_outside_allowed_root"};for(raw in [root,value]){var prefix="";for(component in raw.split("/")){if(component==""){continue};if(component=="."||component==".."){return "artifact_path_outside_allowed_root"};prefix+="/${component}";let current=Path(prefix);if(exists(current)&&FileInfo(current).isSymbolicLink()){return "artifact_path_outside_allowed_root"}}};let canonicalRoot=canonicalize(Path(root)).toString();let path=Path(value);let canonical=if(exists(path)){canonicalize(path).toString()}else{canonicalize(path.parent).join(path.fileName).toString()};if(canonical==canonicalRoot||canonical.startsWith(canonicalRoot+"/")){"ok"}else{"artifact_path_outside_allowed_root"}}catch(_:Exception){"artifact_path_outside_allowed_root"}}
