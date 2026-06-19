package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbMcpHttpTest {
    private func service(name: String): CkbCommandLoopService {
        CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/${name}"))
    }

    private func initHeaders(): Array<String> {
        [
            "Content-Type: application/json",
            "Accept: application/json, text/event-stream"
        ]
    }

    private func sessionHeaders(sessionId: String): Array<String> {
        [
            "Content-Type: application/json",
            "Accept: application/json, text/event-stream",
            "MCP-Protocol-Version: 2025-06-18",
            "Mcp-Session-Id: ${sessionId}"
        ]
    }

    private func sseHeaders(sessionId: String): Array<String> {
        [
            "Accept: text/event-stream",
            "MCP-Protocol-Version: 2025-06-18",
            "Mcp-Session-Id: ${sessionId}",
            "Last-Event-ID: 3"
        ]
    }

    private func initializeBody(id: Int64): String {
        "{\"jsonrpc\":\"2.0\",\"id\":${id},\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"mcp-http-test\",\"version\":\"1\"}}}"
    }

    private func extractSessionId(response: CkbMcpHttpResponse): String {
        for (header in response.headers) {
            if (header.toAsciiLower().startsWith("mcp-session-id:")) {
                return header["mcp-session-id:".size..header.size].trimAscii()
            }
        }
        ""
    }

    @TestCase
    public func msh3Ut001InitializeReturnsJsonAndSession(): Unit {
        let store = CkbMcpHttpSessionStore()
        let response = handleCkbMcpHttpRequest(this.service("msh3-ut-001"), "POST", "/mcp", this.initializeBody(1), this.initHeaders(), CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), store)

        @Expect(response.statusCode, 200)
        @Expect(response.contentType.contains("application/json"), true)
        @Expect(response.body.contains("\"protocolVersion\":\"2025-06-18\""), true)
        @Expect(this.extractSessionId(response) != "", true)
    }

    @TestCase
    public func msh3Ut002SseFrameHasExactFormat(): Unit {
        let frame = ckbMcpHttpSseFrame("message", "{\"jsonrpc\":\"2.0\"}", "7")

        @Expect(frame, "id: 7\nevent: message\ndata: {\"jsonrpc\":\"2.0\"}\n\n")
    }

    @TestCase
    public func msh3Neg001PostRequiresBothAcceptValues(): Unit {
        let response = handleCkbMcpHttpRequest(this.service("msh3-neg-001"), "POST", "/mcp", this.initializeBody(1), ["Content-Type: application/json", "Accept: application/json"], CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), CkbMcpHttpSessionStore())

        @Expect(response.statusCode, 406)
        @Expect(response.body.contains("not_acceptable"), true)
    }

    @TestCase
    public func msh4Pos001InitializeInitializedToolsListLifecycle(): Unit {
        let store = CkbMcpHttpSessionStore()
        let service = this.service("msh4-pos-001")
        let init = handleCkbMcpHttpRequest(service, "POST", "/mcp", this.initializeBody(1), this.initHeaders(), CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), store)
        let sessionId = this.extractSessionId(init)
        let initialized = handleCkbMcpHttpRequest(service, "POST", "/mcp", "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\",\"params\":{}}", this.sessionHeaders(sessionId), CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), store)
        let tools = handleCkbMcpHttpRequest(service, "POST", "/mcp", "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\",\"params\":{}}", this.sessionHeaders(sessionId), CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), store)

        @Expect(init.statusCode, 200)
        @Expect(sessionId != "", true)
        @Expect(initialized.statusCode, 202)
        @Expect(initialized.body, "")
        @Expect(tools.statusCode, 200)
        @Expect(tools.body.contains("\"name\":\"cangjie_knowledge_pack\""), true)
    }

    @TestCase
    public func msh4Pos002GetSseRecordsLastEventId(): Unit {
        let store = CkbMcpHttpSessionStore()
        let service = this.service("msh4-pos-002")
        let init = handleCkbMcpHttpRequest(service, "POST", "/mcp", this.initializeBody(1), this.initHeaders(), CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), store)
        let sessionId = this.extractSessionId(init)
        let sse = handleCkbMcpHttpRequest(service, "GET", "/mcp", "", this.sseHeaders(sessionId), CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), store)

        @Expect(sse.statusCode, 200)
        @Expect(sse.contentType, "text/event-stream")
        @Expect(sse.streamMode, true)
        @Expect(sse.body, ": ckb-mcp-ready\n\n")
        if (let Some(session) <- store.get(sessionId)) {
            @Expect(session.lastEventId, "3")
            @Expect(session.sseConnected, true)
        } else {
            @Expect(false, true)
        }
    }

    @TestCase
    public func msh4Neg004InitializeRejectsExistingSessionHeader(): Unit {
        let headers = [
            "Content-Type: application/json",
            "Accept: application/json, text/event-stream",
            "Mcp-Session-Id: old-session"
        ]
        let response = handleCkbMcpHttpRequest(this.service("msh4-neg-004"), "POST", "/mcp", this.initializeBody(1), headers, CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), CkbMcpHttpSessionStore())

        @Expect(response.statusCode, 400)
        @Expect(response.body.contains("session_not_allowed_on_initialize"), true)
    }
}
