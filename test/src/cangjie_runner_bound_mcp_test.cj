package cangjie_community_knowledge_base_test

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.base64.*
import stdx.net.http.*

@Test
public class CangjieRunnerBoundMcpTest {
    // RBMCP-BND-01
    @TestCase
    public func rbmcpBnd01EncodingSizeUtf8AndContractBoundariesFailClosed(): Unit {
        let unicode = rbmcpTestContext("中文🙂 task", "[]")
        @Expect(ckbMcpBoundTaskContextFromBase64(toBase64String(unicode.toArray()), expectedHash: benchmarkGapSha256(unicode)).valid, true)
        @Expect(ckbMcpBoundTaskContextFromBase64("%%%", expectedHash: "sha256:x").diagnostic, "malformed_bound_task_context_base64")
        @Expect(ckbMcpBoundTaskContextFromBase64("/w==", expectedHash: "sha256:x").diagnostic, "invalid_response_encoding")
        let malformed = "{"; @Expect(ckbMcpBoundTaskContextFromBase64(toBase64String(malformed.toArray()), expectedHash: benchmarkGapSha256(malformed)).diagnostic, "malformed_bound_task_context_json")
        let missing = unicode.replace("\"promptHash\":\"sha256:prompt\",", "")
        @Expect(ckbMcpBoundTaskContextFromBase64(toBase64String(missing.toArray()), expectedHash: benchmarkGapSha256(missing)).diagnostic, "bound_task_context_contract_invalid")
        let extra = unicode.replace("\"responseMode\":\"evidence\"", "\"responseMode\":\"evidence\",\"extra\":true")
        @Expect(ckbMcpBoundTaskContextFromBase64(toBase64String(extra.toArray()), expectedHash: benchmarkGapSha256(extra)).diagnostic, "bound_task_context_contract_invalid")
        @Expect(ckbMcpBoundTaskContextFromBase64(toBase64String(unicode.toArray()), expectedHash: benchmarkGapSha256(unicode + "x")).diagnostic, "bound_task_context_hash_mismatch")
        let huge = rbmcpTestContext(rbmcpTestRepeat("界", 9000), "[]")
        @Expect(ckbMcpBoundTaskContextFromBase64(toBase64String(huge.toArray()), expectedHash: benchmarkGapSha256(huge)).diagnostic, "bound_task_context_too_large")
    }

    // RBMCP-POS-01
    @TestCase
    public func rbmcpPos01BoundStdioUsesEmptySchemaAndServerRequest(): Unit {
        let context = rbmcpTestContext("敏感任务中文🙂", "[\"String\"]"); let hash = benchmarkGapSha256(context)
        let server = CkbMcpStdioServer(rbmcpTestService("pos"), boundTaskContextBase64: toBase64String(context.toArray()), boundTaskContextHash: hash)
        let listed = server.handleRequest("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}")
        @Expect(listed.contains("\"name\":\"cangjie_task_knowledge_pack\",\"description\""), true)
        @Expect(listed.contains("\"properties\":{},\"additionalProperties\":false"), true)
        let response = server.handleRequest(rbmcpTestCall("cangjie_task_knowledge_pack", "{}"))
        @Expect(response.contains("\"bindingMode\":\"runner_immutable\""), true); @Expect(response.contains(hash), true)
        @Expect(response.contains("敏感任务中文🙂"), false)
        @Expect(server.handleRequest(rbmcpTestCall("cangjie_task_knowledge_pack", "{\"taskId\":\"forged\"}")).contains("bound_tool_arguments_must_be_empty"), true)
    }

    // RBMCP-NEG-01
    @TestCase
    public func rbmcpNeg01ReceiptAndPairTamperingFailClosed(): Unit {
        let context = rbmcpTestContext("negative 中文🙂", "[\"String\"]")
        let validReceipt = rbmcpTestReceipt(context, "h342434", "knowledge-v1")
        @Expect(ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, rbmcpTestTranscript("{}", validReceipt, "call-neg"), context).valid, true)
        @Expect(ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, rbmcpTestTranscript("{\"taskId\":\"forged\"}", validReceipt, "call-neg"), context).diagnostic, "bound_tool_arguments_not_empty")
        @Expect(ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, rbmcpTestTranscript("{}", validReceipt.replace("\"requestHash\":\"${benchmarkGapSha256(context)}\"", "\"requestHash\":\"sha256:wrong\""), "call-neg"), context).diagnostic, "request_binding_hash_mismatch")
        @Expect(ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, rbmcpTestTranscript("{}", validReceipt.replace("\"taskId\":\"CJ-HUMANEVAL-145\"}}", "\"taskId\":\"CJ-HUMANEVAL-145\",\"unexpected\":true}}"), "call-neg"), context).diagnostic, "request_binding_invalid")
        @Expect(ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, rbmcpTestTranscript("{}", validReceipt, "call-neg") + "\n" + rbmcpTestTranscript("{}", validReceipt, "call-neg"), context).diagnostic, "task_knowledge_tool_use_not_unique")
        @Expect(ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, rbmcpTestTranscript("{}", validReceipt, "call-other").replace("\"tool_use_id\":\"call-other\"", "\"tool_use_id\":\"wrong\""), context).diagnostic, "paired_tool_result_missing")
        @Expect(ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, rbmcpTestTranscript("{}", validReceipt.replace("knowledge-v1", ""), "call-neg"), context).diagnostic, "knowledge_version_missing")
    }

    // RBMCP-HTTP-01
    @TestCase
    public func rbmcpHttp01SessionBindingRejectsHeaderSmugglingAndDrift(): Unit {
        let service = rbmcpTestService("http"); let sessions = CkbMcpHttpSessionStore(); let context = rbmcpTestContext("HTTP 中文🙂", "[]")
        let encoded = toBase64String(context.toArray()); let hash = benchmarkGapSha256(context)
        let initRequest = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"rbmcp\",\"version\":\"1\"}}}"
        let initHeaders = rbmcpTestHttpHeaders(encoded, hash, "")
        let initialized = handleCkbMcpHttpRequest(service, "POST", "/mcp", initRequest, initHeaders, CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), sessions)
        @Expect(initialized.statusCode, 200); let sid = rbmcpTestSessionId(initialized.headers); @Expect(sid != "", true)
        let boundHeaders = rbmcpTestHttpHeaders(encoded, hash, sid)
        let call = handleCkbMcpHttpRequest(service, "POST", "/mcp", rbmcpTestCall("cangjie_task_knowledge_pack", "{}"), boundHeaders, CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), sessions)
        @Expect(call.statusCode, 200); @Expect(call.body.contains("\"requestBinding\""), true); @Expect(call.body.contains("HTTP 中文🙂"), false)
        let duplicate = ArrayList<String>(); for (h in initHeaders) { duplicate.add(h) }; duplicate.add("x-ckb-runner-context: ${encoded}")
        @Expect(handleCkbMcpHttpRequest(service, "POST", "/mcp", initRequest.replace("\"id\":1", "\"id\":2"), duplicate.toArray(), CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), sessions).body.contains("duplicate_bound_task_context_header"), true)
        let networkHeaders = HttpHeaders()
        networkHeaders.set("X-CKB-Runner-Context", encoded)
        networkHeaders.add("x-ckb-runner-context", encoded)
        networkHeaders.set("X-CKB-Runner-Context-SHA256", hash)
        let flattened = ckbHttpRunnerBindingHeadersForTest(networkHeaders)
        @Expect(flattened.size, 3)
        let networkRequestHeaders = ArrayList<String>()
        networkRequestHeaders.add("Content-Type: application/json")
        networkRequestHeaders.add("Accept: application/json, text/event-stream")
        for (header in flattened) { networkRequestHeaders.add(header) }
        @Expect(handleCkbMcpHttpRequest(service, "POST", "/mcp", initRequest.replace("\"id\":1", "\"id\":3"), networkRequestHeaders.toArray(), CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), sessions).body.contains("duplicate_bound_task_context_header"), true)
        let smuggled = rbmcpTestHttpHeaders(encoded + ",forged", hash, "")
        @Expect(handleCkbMcpHttpRequest(service, "POST", "/mcp", initRequest.replace("\"id\":1", "\"id\":4"), smuggled, CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), sessions).body.contains("bound_task_context_header_smuggling"), true)
        let malformed = rbmcpTestHttpHeaders("%%%", hash, "")
        @Expect(handleCkbMcpHttpRequest(service, "POST", "/mcp", initRequest.replace("\"id\":1", "\"id\":5"), malformed, CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), sessions).body.contains("malformed_bound_task_context_base64"), true)
        let driftHeaders = rbmcpTestHttpHeaders(encoded, benchmarkGapSha256(context + "drift"), sid)
        @Expect(handleCkbMcpHttpRequest(service, "POST", "/mcp", rbmcpTestCall("cangjie_task_knowledge_pack", "{}"), driftHeaders, CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), sessions).body.contains("bound_task_context_session_drift"), true)
        let noBinding = ["Content-Type: application/json", "Accept: application/json, text/event-stream", "MCP-Protocol-Version: 2025-06-18", "Mcp-Session-Id: ${sid}"]
        @Expect(handleCkbMcpHttpRequest(service, "DELETE", "/mcp", "", noBinding, CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), sessions).body.contains("bound_task_context_session_drift"), true)
        @Expect(handleCkbMcpHttpRequest(service, "DELETE", "/mcp", "", boundHeaders, CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), sessions).statusCode, 202)
        @Expect(handleCkbMcpHttpRequest(service, "POST", "/mcp", rbmcpTestCall("cangjie_task_knowledge_pack", "{}"), boundHeaders, CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), sessions).statusCode, 404)
    }

    // RBMCP-CERT-01
    @TestCase
    public func rbmcpCert01StrictCdConfigsAndEvidenceStayBound(): Unit {
        let context = rbmcpTestContext("cert 中文🙂", "[\"String\"]")
        let c = renderCkbAbcdeMcpConfig(CkbAbcdeGroups.C, "/tmp/ckb", "/tmp/config", "/tmp/store", "http://127.0.0.1:18890", taskContextJson: context)
        let d = renderCkbAbcdeMcpConfig(CkbAbcdeGroups.D, "/tmp/ckb", "/tmp/config", "/tmp/store", "http://127.0.0.1:18890", taskContextJson: context)
        @Expect(c.contains("--bound-task-context-base64"), true); @Expect(c.contains("--bound-task-context-sha256"), true)
        @Expect(d.contains("X-CKB-Runner-Context"), true); @Expect(d.contains("X-CKB-Runner-Context-SHA256"), true)
        let receipt = rbmcpTestReceipt(context, "h342434", "knowledge-v1")
        @Expect(ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, rbmcpTestTranscript("{}", receipt, "call-c"), context).valid, true)
        @Expect(ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.D, rbmcpTestTranscript("{}", receipt, "call-d", http: true), context).valid, true)
    }

    // RBMCP-REG-01
    @TestCase
    public func rbmcpReg01GenericMcpRetainsFullArgumentsAndOtherTools(): Unit {
        let server = CkbMcpStdioServer(rbmcpTestService("reg")); let context = rbmcpTestContext("generic task", "[\"String\"]")
        let task = server.handleRequest(rbmcpTestCall("cangjie_task_knowledge_pack", context))
        @Expect(task.contains("\"requestBinding\""), false); @Expect(task.contains("\"structuredContent\""), true)
        let api = server.handleRequest(rbmcpTestCall("cangjie_api_search", "{\"q\":\"ArrayList\",\"targetVersion\":\"1.0.0\"}"))
        @Expect(api.contains("\"structuredContent\""), true); @Expect(api.contains("bound_tool_arguments_must_be_empty"), false)
    }

    @TestCase
    public func r3Arch002BoundTaskPackBlocksPollutionAndKeepsReceiptOutsideEvidence(): Unit {
        let context = rbmcpTestContext("private benchmark fragment", "[\"String\"]")
        let server = CkbMcpStdioServer(r3PollutedMcpService("r3-bound"),
            boundTaskContextBase64: toBase64String(context.toArray()),
            boundTaskContextHash: benchmarkGapSha256(context))

        let response = server.handleRequest(rbmcpTestCall("cangjie_task_knowledge_pack", "{}"))

        @Expect(response.contains("student_knowledge_leakage_blocked"), true)
        @Expect(response.contains("private benchmark fragment"), false)
        @Expect(response.contains("CJ-HUMANEVAL-145"), false)
        @Expect(response.contains("\"structuredContent\""), false)
    }
}

private func rbmcpTestService(name: String): CkbCommandLoopService {
    let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/rbmcp-${name}")); _ = service.start(); service
}

private func rbmcpTestContext(task: String, tags: String): String {
    "{\"taskId\":\"CJ-HUMANEVAL-145\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"${ckbMcpJsonEscape(task)}\",\"signature\":\"func solve(s: String): String\",\"datasetVersion\":\"dataset-v1\",\"promptHash\":\"sha256:prompt\",\"starterHash\":\"sha256:starter\",\"expectedKnowledgeTags\":${tags},\"targetVersion\":\"1.0.0\",\"sourceSet\":\"all\",\"versionPolicy\":\"default\",\"budget\":10,\"responseMode\":\"evidence\"}"
}

private func rbmcpTestRepeat(part: String, count: Int64): String { let out = StringBuilder(); for (_ in 0..count) { out.append(part) }; out.toString() }
private func rbmcpTestCall(name: String, args: String): String { "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"${name}\",\"arguments\":${args}}}" }
private func rbmcpTestReceipt(context: String, evidence: String, version: String): String { "{\"taskId\":\"CJ-HUMANEVAL-145\",\"resultType\":\"task_knowledge_pack\",\"evidenceHash\":\"${evidence}\",\"knowledgeVersion\":\"${version}\",\"coverage\":{\"coveragePass\":true},\"citations\":[{\"citation\":\"official\"}],\"requestBinding\":{\"schemaVersion\":\"ckb-runner-bound-mcp-v1\",\"bindingMode\":\"runner_immutable\",\"requestHash\":\"${benchmarkGapSha256(context)}\",\"effectiveRequestHash\":\"${benchmarkGapSha256(context)}\",\"modelArgumentsHash\":\"${benchmarkGapSha256("{}")}\",\"taskId\":\"CJ-HUMANEVAL-145\"}}" }
private func rbmcpTestTranscript(input: String, receipt: String, id: String, http!: Bool = false): String { let tool=if(http){"mcp__ckb-cangjie-http__cangjie_task_knowledge_pack"}else{"mcp__ckb-cangjie__cangjie_task_knowledge_pack"};"{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"${id}\",\"name\":\"${tool}\",\"input\":${input}}]}}\n{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"${id}\",\"content\":\"${ckbMcpJsonEscape(receipt)}\"}]}}" }
private func rbmcpTestHttpHeaders(encoded: String, hash: String, sid: String): Array<String> { let h=ArrayList<String>();h.add("Content-Type: application/json");h.add("Accept: application/json, text/event-stream");h.add("X-CKB-Runner-Context: ${encoded}");h.add("X-CKB-Runner-Context-SHA256: ${hash}");if(sid!=""){h.add("MCP-Protocol-Version: 2025-06-18");h.add("Mcp-Session-Id: ${sid}")};h.toArray() }
private func rbmcpTestSessionId(headers: ArrayList<String>): String { for(h in headers){if(h.toAsciiLower().startsWith("mcp-session-id:")){return h.split(":")[1].trimAscii()}};"" }
