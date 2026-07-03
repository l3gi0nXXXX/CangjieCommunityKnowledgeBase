package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbMcpStdioTest {
    private func server(name: String): CkbMcpStdioServer {
        CkbMcpStdioServer(CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/${name}")))
    }

    private func toolCall(name: String, arguments: String): String {
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"${name}\",\"arguments\":${arguments}}}"
    }

    private func repeatedText(count: Int64): String {
        var out = ""
        for (_ in 0..count) {
            out += "x"
        }
        out
    }

    private func countOccurrences(text: String, needle: String): Int64 {
        var count: Int64 = 0
        if (needle == "" || text.size < needle.size) {
            return count
        }
        for (i in 0..=text.size - needle.size) {
            if (text[i..i + needle.size] == needle) {
                count += 1
            }
        }
        count
    }

    @TestCase
    public func ckg5Ut001ToolsListReturnsElevenReadOnlyTools(): Unit {
        let response = this.server("ckg5-ut-001").handleRequest("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}")

        @Expect(response.contains("\"result\""), true)
        @Expect(this.countOccurrences(response, "\"name\":\"cangjie_"), 11)
        @Expect(response.contains("\"name\":\"cangjie_knowledge_pack\""), true)
        @Expect(response.contains("\"name\":\"cangjie_version_resolve\""), true)
        @Expect(response.contains("\"name\":\"cangjie_task_knowledge_pack\""), true)
        @Expect(response.contains("\"name\":\"cangjie_knowledge_coverage\""), true)
        @Expect(response.contains("\"name\":\"cangjie_compile_diagnose_v2\""), true)
        @Expect(response.contains("\"name\":\"cangjie_syntax_query\""), true)
        @Expect(response.contains("\"name\":\"cangjie_api_search\""), true)
        @Expect(response.contains("\"name\":\"cangjie_cookbook\""), true)
        @Expect(response.contains("\"name\":\"cangjie_diagnose\""), true)
        @Expect(response.contains("\"name\":\"cangjie_examples\""), true)
        @Expect(response.contains("\"name\":\"cangjie_corpus_status\""), true)
        @Expect(response.contains("admin"), false)
        @Expect(response.contains("update"), false)
        @Expect(response.contains("verify"), false)
    }

    @TestCase
    public func msh0Pos001FullHandshakeInitializeInitializedToolsList(): Unit {
        let server = this.server("msh0-pos-001")
        let initialize = server.handleLine("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"clientInfo\":{\"name\":\"manual-smoke\",\"version\":\"1\"}}}")
        let initialized = server.handleLine("{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\",\"params\":{}}")
        let tools = server.handleLine("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\",\"params\":{}}")

        @Expect(initialize.shouldWrite, true)
        @Expect(initialize.payload.contains("\"id\":1"), true)
        @Expect(initialize.payload.contains("\"protocolVersion\":\"2024-11-05\""), true)
        @Expect(initialized.shouldWrite, false)
        @Expect(initialized.payload, "")
        @Expect(tools.shouldWrite, true)
        @Expect(this.countOccurrences(tools.payload, "\"name\":\"cangjie_"), 11)
    }

    @TestCase
    public func msh0Pos002InitializeEchoesRequested20250618Protocol(): Unit {
        let initialize = this.server("msh0-pos-002").handleLine("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"claude-code\",\"version\":\"2\"}}}")

        @Expect(initialize.shouldWrite, true)
        @Expect(initialize.payload.contains("\"protocolVersion\":\"2025-06-18\""), true)
        @Expect(initialize.payload.contains("\"name\":\"ckb-cangjie-mcp-stdio\""), true)
    }

    @TestCase
    public func msh0Neg001UnknownNotificationMustNotReturnResponse(): Unit {
        let response = this.server("msh0-neg-001").handleLine("{\"jsonrpc\":\"2.0\",\"method\":\"unknown/notification\",\"params\":{}}")

        @Expect(response.shouldWrite, false)
        @Expect(response.payload, "")
    }

    @TestCase
    public func msh1Ut001InitializedNotificationMustNotReturnResponse(): Unit {
        let response = this.server("msh1-ut-001").handleLine("{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\",\"params\":{}}")

        @Expect(response.shouldWrite, false)
        @Expect(response.payload, "")
    }

    @TestCase
    public func msh1Neg002UnknownRequestStillReturnsMethodNotFound(): Unit {
        let response = this.server("msh1-neg-002").handleRequest("{\"jsonrpc\":\"2.0\",\"id\":9,\"method\":\"unknown/request\",\"params\":{}}")

        @Expect(response.contains("\"id\":9"), true)
        @Expect(response.contains("\"error\""), true)
        @Expect(response.contains("-32601"), true)
    }

    @TestCase
    public func msh1Pos001PingRequestReturnsEmptyResult(): Unit {
        let response = this.server("msh1-pos-001").handleRequest("{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"ping\",\"params\":{}}")

        @Expect(response.contains("\"id\":3"), true)
        @Expect(response.contains("\"result\":{}"), true)
    }

    @TestCase
    public func msh1Bnd001JsonScannerKeepsUtf8ToolArguments(): Unit {
        let request = "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"tools/call\",\"params\":{\"name\":\"cangjie_knowledge_pack\",\"arguments\":{\"task\":\"仓颉 ArrayList 用法 😀\",\"targetVersion\":\"1.0.0\",\"budget\":2}}}"
        let params = ckbMcpJsonObjectField(request, "params")
        let args = ckbMcpJsonObjectField(params, "arguments")

        @Expect(ckbMcpJsonStringField(args, "task"), "仓颉 ArrayList 用法 😀")
        @Expect(ckbMcpJsonStringField(args, "targetVersion"), "1.0.0")
    }

    @TestCase
    public func msh1Bnd002ToolCallWithUtf8TaskDoesNotCloseConnectionPath(): Unit {
        let response = this.server("msh1-bnd-002").handleRequest(this.toolCall("cangjie_knowledge_pack", "{\"task\":\"仓颉 ArrayList 用法 😀\",\"targetVersion\":\"1.0.0\",\"budget\":2}"))

        @Expect(response.contains("\"id\":1"), true)
        @Expect(response.contains("\"structuredContent\""), true)
        @Expect(response.contains("仓颉 ArrayList 用法 😀"), true)
        @Expect(response.contains("\"knowledgeVersion\""), true)
    }

    @TestCase
    public func msh2Ut001ProtocolServerToolsListReturnsElevenReadOnlyTools(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/msh2-ut-001"))
        let server = CkbMcpProtocolServer(service)
        let response = server.handleRequest("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}", "2025-06-18", "ckb-cangjie-mcp-http")

        @Expect(response.contains("\"result\""), true)
        @Expect(this.countOccurrences(response, "\"name\":\"cangjie_"), 11)
        @Expect(response.contains("admin"), false)
        @Expect(response.contains("verify"), false)
    }

    @TestCase
    public func ckg5Bnd001ToolCallOversizedTaskReturnsControlledError(): Unit {
        let longTask = this.repeatedText(13000)
        let response = this.server("ckg5-bnd-001").handleRequest(this.toolCall("cangjie_knowledge_pack", "{\"task\":\"${longTask}\"}"))

        @Expect(response.contains("\"error\""), true)
        @Expect(response.contains("-32602"), true)
        @Expect(response.contains("parameter_too_long"), true)
        @Expect(response.contains("\"field\":\"task\""), true)
    }

    @TestCase
    public func ckg5Pos001ApiSearchArrayListReturnsStructuredContent(): Unit {
        let response = this.server("ckg5-pos-001").handleRequest(this.toolCall("cangjie_api_search", "{\"q\":\"ArrayList\",\"module\":\"std.collection\",\"symbol\":\"ArrayList\",\"budget\":5}"))

        @Expect(response.contains("\"structuredContent\""), true)
        @Expect(response.contains("\"knowledgeVersion\""), true)
        @Expect(response.contains("\"items\""), true)
        @Expect(response.contains("\"apiItems\""), true)
        @Expect(response.contains("\"citations\""), true)
        @Expect(response.contains("ArrayList"), true)
    }

    @TestCase
    public func p1Pos001TaskKnowledgePackReturnsVersionPlanAndCoverage(): Unit {
        let args = "{\"taskId\":\"CJ-HUMANEVAL-000\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"Implement ArrayList helper\",\"signature\":\"func solve(xs: ArrayList<Int64>): Int64\",\"expectedKnowledgeTags\":[\"ArrayList\",\"symbol\"],\"targetVersion\":\"1.0.0\",\"sourceSet\":\"stdx\",\"sourceRef\":\"release-1.0.0\",\"versionPolicy\":\"exact\"}"
        let response = this.server("p1-pos-mcp-001").handleRequest(this.toolCall("cangjie_task_knowledge_pack", args))

        @Expect(response.contains("\"structuredContent\""), true)
        @Expect(response.contains("\"versionResolution\""), true)
        @Expect(response.contains("\"queryPlan\""), true)
        @Expect(response.contains("\"coverage\""), true)
        @Expect(response.contains("\"coveragePass\":true"), true)
        @Expect(response.contains("\"versionPolicy\":\"exact\""), true)
    }

    @TestCase
    public func p1Neg001VersionResolveMissingRefReturnsNoFallbackDiagnostic(): Unit {
        let args = "{\"targetVersion\":\"1.0.0\",\"sourceSet\":\"stdx\",\"sourceRef\":\"missing-release\",\"versionPolicy\":\"exact\"}"
        let response = this.server("p1-neg-mcp-001").handleRequest(this.toolCall("cangjie_version_resolve", args))

        @Expect(response.contains("\"structuredContent\""), true)
        @Expect(response.contains("\"ok\":false"), true)
        @Expect(response.contains("version_not_resolved"), true)
        @Expect(response.contains("\"sources\":[]"), true)
    }

    @TestCase
    public func ckg5Pos002LlmsTxtResourceReturnsMarkdownWithVersionAndDocsUrl(): Unit {
        let request = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"resources/read\",\"params\":{\"uri\":\"ckb://cangjie/llms.txt\"}}"
        let response = this.server("ckg5-pos-002").handleRequest(request)

        @Expect(response.contains("\"mimeType\":\"text/markdown\""), true)
        @Expect(response.contains("# Cangjie llms.txt"), true)
        @Expect(response.contains("knowledgeVersion:"), true)
        @Expect(response.contains("https://docs.cangjie-lang.cn/docs/1.0.0/"), true)
    }

    @TestCase
    public func ckg5Neg001AdminRefreshIsNotAllowedAndDoesNotCallAdmin(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckg5-neg-001"))
        let server = CkbMcpStdioServer(service)
        let response = server.handleRequest(this.toolCall("cangjie_admin_refresh", "{\"reason\":\"test\"}"))

        @Expect(response.contains("\"error\""), true)
        @Expect(response.contains("-32601"), true)
        @Expect(response.contains("not_allowed"), true)
        @Expect(service.rebuildCountForTest(), 0)
    }

    @TestCase
    public func ckg5Neg002VerifySnippetIsNotEnabledAndDoesNotExecuteExternalCommand(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckg5-neg-002"))
        let server = CkbMcpStdioServer(service)
        let response = server.handleRequest(this.toolCall("verify-snippet", "{\"code\":\"main() { println(1) }\"}"))

        @Expect(response.contains("\"error\""), true)
        @Expect(response.contains("-32601"), true)
        @Expect(response.contains("not_enabled"), true)
        @Expect(service.rebuildCountForTest(), 0)
    }
}
