package cangjie_community_knowledge_base

import stdx.encoding.json.*

public class CkbCompletionRetrievalRequest{public var taskText="";public var starterSignature="";public var targetVersion="";public var json="";public var requestHash="";public var diagnostic="not_built";public init(){}}
public class CkbCompletionKnowledgePack{public var ok=false;public var diagnostic="not_prefetched";public var knowledgeVersion="";public var knowledgePack="";public var requestHash="";public var responseHash="";public var packHash="";public init(){}}
public open class CkbCompletionKnowledgePrefetcher{public open func fetch(requestJson:String):Array<UInt8>{[]}}

public func buildCompletionOnlyRetrievalRequest(taskText:String,starterSignature:String,targetVersion:String):CkbCompletionRetrievalRequest{
    let r=CkbCompletionRetrievalRequest();r.taskText=taskText;r.starterSignature=starterSignature;r.targetVersion=targetVersion
    if(taskText.trimAscii()==""||starterSignature.trimAscii()==""||targetVersion.trimAscii()==""){r.diagnostic="public_retrieval_field_required";return r}
    if(taskText.toArray().size+starterSignature.toArray().size>65536||ckbCompletionPublicInputForbidden(taskText+"\n"+starterSignature)){r.diagnostic="public_retrieval_input_invalid";return r}
    r.json="{\"schemaVersion\":\"ckb-completion-retrieval-v1\",\"taskText\":\"${ckbCompletionContextEscape(taskText)}\",\"starterSignature\":\"${ckbCompletionContextEscape(starterSignature)}\",\"targetVersion\":\"${ckbCompletionContextEscape(targetVersion)}\"}";r.requestHash=benchmarkGapSha256(r.json);r.diagnostic="ok";r
}
public func prefetchCompletionKnowledgePack(request:CkbCompletionRetrievalRequest,responseBytes:Array<UInt8>):CkbCompletionKnowledgePack{
    let out=CkbCompletionKnowledgePack();out.requestHash=request.requestHash;if(request.diagnostic!="ok"){out.diagnostic=request.diagnostic;return out}
    let raw=try{String.fromUtf8(responseBytes)}catch(_:Exception){out.diagnostic="invalid_response_encoding";return out}
    if(responseBytes.size>131072){out.diagnostic="knowledge_response_too_large";return out}
    try{let o=JsonValue.fromStr(raw).asObject();if(o.getFields().size!=2){out.diagnostic="knowledge_response_schema_invalid";return out};out.knowledgeVersion=o.get("knowledgeVersion").getOrThrow().asString().getValue();out.knowledgePack=o.get("knowledgePack").getOrThrow().asString().getValue();let canonical="{\"knowledgeVersion\":\"${ckbCompletionContextEscape(out.knowledgeVersion)}\",\"knowledgePack\":\"${ckbCompletionContextEscape(out.knowledgePack)}\"}";if(raw.trimAscii()!=canonical){out.diagnostic="knowledge_response_noncanonical";return out};if(out.knowledgeVersion==""){out.diagnostic="knowledge_version_required";return out};if(out.knowledgePack.toArray().size>65536){out.diagnostic="knowledge_pack_too_large";return out};if(ckbCompletionContextForbidden(out.knowledgePack)){out.diagnostic="knowledge_pack_protected_or_secret";return out};out.responseHash=benchmarkGapSha256(canonical);out.packHash=benchmarkGapSha256(out.knowledgePack);out.ok=true;out.diagnostic="ok";out}catch(_:Exception){out.diagnostic="malformed_json";out}
}
public func prefetchCompletionKnowledgePack(request:CkbCompletionRetrievalRequest,prefetcher:CkbCompletionKnowledgePrefetcher):CkbCompletionKnowledgePack{if(request.diagnostic!="ok"){let out=CkbCompletionKnowledgePack();out.diagnostic=request.diagnostic;return out};prefetchCompletionKnowledgePack(request,prefetcher.fetch(request.json))}
public func renderCompletionContextEvidence(pack:CkbCompletionKnowledgePack):String{"{\"schemaVersion\":\"ckb-completion-context-evidence-v1\",\"ok\":${pack.ok},\"diagnostic\":\"${ckbCompletionContextEscape(pack.diagnostic)}\",\"knowledgeVersion\":\"${ckbCompletionContextEscape(pack.knowledgeVersion)}\",\"requestHash\":\"${pack.requestHash}\",\"responseHash\":\"${pack.responseHash}\",\"packHash\":\"${pack.packHash}\",\"contentBytes\":${pack.knowledgePack.toArray().size}}"}
private func ckbCompletionContextForbidden(raw:String):Bool{let x=raw.toAsciiLower();for(term in ["\"caseid\"","expectedknowledgetags","failureclassification","historicalscore","cj-humaneval-","canonical_solution","hidden_test","authorization:","bearer ","api_key","token=","password="]){if(x.contains(term)){return true}};false}
private func ckbCompletionPublicInputForbidden(raw:String):Bool{let x=raw.toAsciiLower();for(term in ["cj-humaneval-","canonical_solution","hidden_test","/reference/","authorization:","bearer ","api_key","token="]){if(x.contains(term)){return true}};false}
private func ckbCompletionContextEscape(v:String):String{v.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t")}
