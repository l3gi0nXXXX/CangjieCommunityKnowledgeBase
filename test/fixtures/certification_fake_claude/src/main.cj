package ckb_certification_fake_claude

import std.collection.*
import std.fs.*
import std.io.*
import std.time.*
import stdx.encoding.json.*
import stdx.net.http.*

main(args: Array<String>): Int64 {
    if (args.size == 1 && args[0] == "--version") {
        println("ckb-certification-fake-claude-1.0")
        return 0
    }
    try {
        let configPath = option(args, "--mcp-config")
        let model = option(args, "--model")
        if (configPath == "" || model == "") { return 2 }
        if (configPath.contains("CJ-HUMANEVAL-000") && configPath.contains("runtime-home/attempt-1")) {
            let solutionPath = Path("src/solution.cj")
            File.writeTo(solutionPath, (String.fromUtf8(File.readFrom(solutionPath)) + "\n// first transport attempt mutated this workspace\n").toArray())
            return 124
        }
        let config = JsonValue.fromStr(String.fromUtf8(File.readFrom(Path(configPath)))).asObject()
        let server = config.get("mcpServers").getOrThrow().asObject()
            .get("ckb-cangjie-http").getOrThrow().asObject()
        let url = server.get("url").getOrThrow().asString().getValue()
        let configuredHeaders = server.get("headers").getOrThrow().asObject()
        let context = configuredHeaders.get("X-CKB-Runner-Context").getOrThrow().asString().getValue()
        let contextHash = configuredHeaders.get("X-CKB-Runner-Context-SHA256").getOrThrow().asString().getValue()
        let common = [("X-CKB-Runner-Context", context), ("X-CKB-Runner-Context-SHA256", contextHash)]
        let initializedSession = post(url, "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"ckb-certification-fake-claude\",\"version\":\"1\"}}}", common)
        if (initializedSession.status != 200 || initializedSession.session == "") { return 3 }
        let sessionHeaders = ArrayList<(String, String)>()
        for (header in common) { sessionHeaders.add(header) }
        sessionHeaders.add(("MCP-Protocol-Version", "2025-06-18"))
        sessionHeaders.add(("Mcp-Session-Id", initializedSession.session))
        let initialized = post(url, "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\",\"params\":{}}", sessionHeaders.toArray())
        if (initialized.status != 202) { return 4 }
        let called = post(url, "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"cangjie_task_knowledge_pack\",\"arguments\":{}}}", sessionHeaders.toArray())
        if (called.status != 200) { return 5 }
        let callResult = JsonValue.fromStr(called.body).asObject().get("result").getOrThrow().asObject()
        if (callResult.get("isError").getOrThrow().asBool().getValue()) { return 6 }
        let receipt = callResult.get("content").getOrThrow().asArray().getItems()[0].asObject()
            .get("text").getOrThrow().asString().getValue()
        _ = JsonValue.fromStr(receipt).asObject()
        let solutionPath = Path("src/solution.cj")
        let solution = String.fromUtf8(File.readFrom(solutionPath)).replace("return false", "return true")
        File.writeTo(solutionPath, solution.toArray())
        let escapedReceipt = escape(receipt)
        println("{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"${escape(model)}\"}")
        println("{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"call-certification\",\"name\":\"mcp__ckb-cangjie-http__cangjie_task_knowledge_pack\",\"input\":{}}]}}")
        println("{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"call-certification\",\"is_error\":false,\"content\":\"${escapedReceipt}\"}]}}")
        println("{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"write-solution\",\"name\":\"Write\",\"input\":{\"file_path\":\"src/solution.cj\",\"content\":\"${escape(solution)}\"}}]}}")
        println("{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"write-solution\",\"is_error\":false,\"content\":\"written\"}]}}")
        println("{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false,\"input_tokens\":1,\"output_tokens\":1,\"total_tokens\":2,\"num_turns\":1}")
        0
    } catch (_: Exception) {
        10
    }
}

private class Response {
    var status: Int64 = 0
    var session: String = ""
    var body: String = ""
}

private func post(url: String, body: String, headers: Array<(String, String)>): Response {
    let builder = HttpRequestBuilder().url(url).post()
    builder.header("Accept", "application/json, text/event-stream")
    builder.header("Content-Type", "application/json")
    for (header in headers) { builder.header(header[0], header[1]) }
    builder.body(body)
    let client = ClientBuilder().readTimeout(Duration.second * 5).build()
    let result = Response()
    try {
        let response = client.send(builder.build())
        result.status = Int64(response.status)
        result.session = response.headers.getFirst("Mcp-Session-Id") ?? response.headers.getFirst("mcp-session-id") ?? ""
        let bytes = ArrayList<Byte>()
        let buffer = Array<Byte>(4096, repeat: 0)
        while (true) {
            let count = response.body.read(buffer)
            if (count <= 0) { break }
            bytes.add(all: buffer[..count])
        }
        result.body = String.fromUtf8(bytes.toArray())
    } finally {
        client.close()
    }
    result
}

private func option(args: Array<String>, name: String): String {
    for (i in 0..args.size) {
        if (args[i] == name && i + 1 < args.size) { return args[i + 1] }
    }
    ""
}

private func escape(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
}
