package cangjie_community_knowledge_base

import stdx.encoding.json.*

public class CkbCompletionRetrievalRequest{public var taskText="";public var starterSignature="";public var targetVersion="";public var json="";public var requestHash="";public var diagnostic="not_built";public init(){}}
public class CkbCompletionKnowledgePack{public var ok=false;public var diagnostic="not_prefetched";public var knowledgeVersion="";public var knowledgePack="";public var requestHash="";public var responseHash="";public var packHash="";public init(){}}
public open class CkbCompletionKnowledgePrefetcher{public open func fetch(requestJson:String):Array<UInt8>{[]}}

public class CkbCompletionRpcAdapterResult {
    public var ok = false;
    public var diagnostic = "not_parsed";
    public var terminalCount: Int64 = 0;
    public var normalizedBytes: Array<UInt8> = [];
    public init() {}
}


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
public func adaptCompletionKnowledgeRpc(responseBytes: Array<UInt8>, mediaType: String, expectedId: String,
    expectedRequestHash: String, expectedVersion: String): CkbCompletionRpcAdapterResult {
    let out = CkbCompletionRpcAdapterResult();
    let raw = try {
        String.fromUtf8(responseBytes)
    } catch (_: Exception) {
        out.diagnostic = "invalid_response_encoding"
        return out
    }
    if (responseBytes.size > 131072) {
        out.diagnostic = "knowledge_response_too_large"
        return out
    }
    var terminal = ""
    if (mediaType == "application/json") {
        terminal = raw.trimAscii()
        out.terminalCount = if (terminal == "") {
            0
        } else {
            1
        }
    } else if (mediaType == "text/event-stream") {
        for (line in raw.replace("\r\n", "\n").split("\n")) {
            if (line.startsWith("data:")) {
                let payload = ckbCompletionAfterDataPrefix(line).trimAscii();
                if (payload != "" && payload != "[DONE]") {
                    out.terminalCount += 1
                    terminal = payload
                }
            } else if (line != "" && !line.startsWith(":") && !line.startsWith("event:") && !line.startsWith("id:") &&
                !line.startsWith("retry:")) {
                out.diagnostic = "sse_frame_invalid"
                return out
            }
        }
    } else {
        out.diagnostic = "knowledge_response_media_type_invalid"
        return out
    }
    if (out.terminalCount != 1) {
        out.diagnostic = if (out.terminalCount == 0) {
            "json_rpc_terminal_missing"
        } else {
            "json_rpc_multiple_terminals"
        };
        return out
    }
    try {
        let envelope = JsonValue.fromStr(terminal).asObject()
        match (envelope.get("error")) {
            case Some(_) =>
                out.diagnostic = "json_rpc_error"
                return out;
            case None => ()
        }
        if (envelope.getFields().size != 3 ||
            !ckbCompletionRpcUnique(terminal,
            ["jsonrpc", "id", "result", "structuredContent", "knowledgeVersion", "knowledgePack", "requestHash",
                "contentHash"]) || ckbCompletionRpcString(envelope, "jsonrpc") != "2.0") {
            out.diagnostic = "json_rpc_envelope_invalid"
            return out
        }
        if (envelope.get("id").getOrThrow().toString() != expectedId) {
            out.diagnostic = "json_rpc_id_mismatch"
            return out
        }
        let result = envelope.get("result").getOrThrow().asObject();
        if (result.getFields().size != 1 && result.getFields().size != 3) {
            out.diagnostic = "json_rpc_result_invalid"
            return out
        };
        if (result.getFields().size == 3) {
            if (!ckbCompletionRpcUnique(terminal, ["content", "isError"])) {
                out.diagnostic = "json_rpc_result_invalid"
                return out
            };
            _ = result.get("content").getOrThrow()
            if (result.get("isError").getOrThrow().asBool().getValue()) {
                out.diagnostic = "json_rpc_result_error"
                return out
            }
        }
        let content = result.get("structuredContent").getOrThrow().asObject();
        if (content.getFields().size != 4) {
            out.diagnostic = "structured_content_schema_invalid"
            return out
        }
        let version = ckbCompletionRpcString(content, "knowledgeVersion");
        let pack = ckbCompletionRpcString(content, "knowledgePack");
        let requestHash = ckbCompletionRpcString(content, "requestHash");
        let contentHash = ckbCompletionRpcString(content, "contentHash")
        if (requestHash != expectedRequestHash) {
            out.diagnostic = "structured_content_request_hash_mismatch"
            return out
        }
        if (version != expectedVersion) {
            out.diagnostic = "structured_content_version_mismatch"
            return out
        }
        if (contentHash != benchmarkGapSha256(pack)) {
            out.diagnostic = "structured_content_hash_mismatch"
            return out
        }
        if (pack.toArray().size > 65536) {
            out.diagnostic = "knowledge_pack_too_large"
            return out
        }
        if (ckbCompletionContextForbidden(pack)) {
            out.diagnostic = "knowledge_pack_protected_or_secret"
            return out
        }
        let normalized = "{\"knowledgeVersion\":\"${ckbCompletionContextEscape(version)}\",\"knowledgePack\":\"${ckbCompletionContextEscape(pack)}\"}"
        out.normalizedBytes = normalized.toArray()
        out.ok = true
        out.diagnostic = "ok"
        out
    } catch (_: Exception) {
        out.diagnostic = "malformed_json"
        out
    }
}

public func parseCompletionMcpHttpBody(responseBytes: Array<UInt8>, mediaType: String, expectedId: String,
    expectedRequestHash: String, expectedVersion: String): CkbCompletionRpcAdapterResult {
    let resolved = if (mediaType == "auto") {
        let raw = try {
            String.fromUtf8(responseBytes)
        } catch (_: Exception) {
            ""
        };
        if (raw.trimAscii().startsWith("data:") || raw.trimAscii().startsWith("event:")) {
            "text/event-stream"
        } else {
            "application/json"
        }
    } else {
        mediaType
    }
    adaptCompletionKnowledgeRpc(responseBytes, resolved, expectedId, expectedRequestHash, expectedVersion)
}

public func normalizeCompletionMcpToolResponse(parsed: CkbCompletionRpcAdapterResult): Array<UInt8> {
    if (parsed.ok) {
        parsed.normalizedBytes
    } else {
        Array<UInt8>()
    }
}

private func ckbCompletionRpcString(o: JsonObject, key: String): String {
    o.get(key).getOrThrow().asString().getValue()
}

private func ckbCompletionAfterDataPrefix(line: String): String {
    let out = StringBuilder();
    let runes = line.toRuneArray();
    for (i in 5..runes.size) {
        out.append(runes[i])
    };
    out.toString()
}

private func ckbCompletionRpcUnique(raw: String, keys: Array<String>): Bool {
    for (key in keys) {
        if (raw.split("\"${key}\"").size != 2) {
            return false
        }
    };
    true
}

private func ckbCompletionContextForbidden(raw:String):Bool{let x=raw.toAsciiLower();for(term in ["\"caseid\"","expectedknowledgetags","failureclassification","historicalscore","cj-humaneval-","canonical_solution","hidden_test","authorization:","bearer ","api_key","token=","password="]){if(x.contains(term)){return true}};false}
private func ckbCompletionPublicInputForbidden(raw:String):Bool{let x=raw.toAsciiLower();for(term in ["cj-humaneval-","canonical_solution","hidden_test","/reference/","authorization:","bearer ","api_key","token="]){if(x.contains(term)){return true}};false}
private func ckbCompletionContextEscape(v:String):String{v.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t")}
