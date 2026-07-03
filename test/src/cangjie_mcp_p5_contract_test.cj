package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieMcpP5ContractTest {
    private func server(name: String): CkbMcpStdioServer {
        CkbMcpStdioServer(CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/${name}")))
    }

    private func toolCall(name: String, arguments: String): String {
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"${name}\",\"arguments\":${arguments}}}"
    }

    @TestCase
    public func p5Pos001ToolsListContainsP5Tools(): Unit {
        let response = this.server("p5-mcp-tools").handleRequest("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}")

        @Expect(response.contains("\"name\":\"cangjie_symbol_lookup\""), true)
        @Expect(response.contains("\"name\":\"cangjie_doc_section\""), true)
        @Expect(response.contains("\"name\":\"cangjie_corpus_freshness\""), true)
        @Expect(response.contains("\"name\":\"cangjie_tool_manual\""), true)
        @Expect(response.contains("\"name\":\"cangjie_negative_rules\""), true)
    }

    @TestCase
    public func p5Bnd001SymbolLookupRequiresSymbol(): Unit {
        let response = this.server("p5-mcp-bnd").handleRequest(this.toolCall("cangjie_symbol_lookup", "{}"))

        @Expect(response.contains("\"error\""), true)
        @Expect(response.contains("symbol_required"), true)
    }

    @TestCase
    public func p5Pos002CorpusFreshnessReturnsStructuredContent(): Unit {
        let response = this.server("p5-mcp-freshness").handleRequest(this.toolCall("cangjie_corpus_freshness", "{}"))

        @Expect(response.contains("\"structuredContent\""), true)
        @Expect(response.contains("\"activeKnowledgeVersion\""), true)
        @Expect(response.contains("\"targetVersion\""), true)
    }
}
