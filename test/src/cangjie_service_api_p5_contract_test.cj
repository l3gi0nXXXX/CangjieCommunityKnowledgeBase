package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieServiceApiP5ContractTest {
    private func service(name: String): CkbCommandLoopService {
        CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/${name}"))
    }

    @TestCase
    public func p5Ut001SchemaAdvertisesP5RoutesAndTools(): Unit {
        let response = ckbApiHandle(this.service("p5-http-schema"), "GET", "/v1/schema", "", [])

        @Expect(response.contains("POST /v1/cangjie/symbol-lookup"), true)
        @Expect(response.contains("POST /v1/cangjie/doc-section"), true)
        @Expect(response.contains("GET /v1/cangjie/corpus/freshness"), true)
        @Expect(response.contains("POST /v1/cangjie/tool-manual"), true)
        @Expect(response.contains("POST /v1/cangjie/negative-rules"), true)
        @Expect(response.contains("cangjie_symbol_lookup"), true)
        @Expect(response.contains("cangjie_doc_section"), true)
        @Expect(response.contains("cangjie_tool_manual"), true)
        @Expect(response.contains("cangjie_negative_rules"), true)
    }

    @TestCase
    public func f2Bnd001StructuredRoutesRejectEmptySelectorsWithDiagnostics(): Unit {
        let config = CkbHttpServiceConfig()
        let service = this.service("f2-http-bnd")
        let symbol = handleCkbHttpRequest(service, "POST", "/v1/cangjie/symbol-lookup", "{}", [], config)
        let doc = handleCkbHttpRequest(service, "POST", "/v1/cangjie/doc-section", "{}", [], config)
        let tool = handleCkbHttpRequest(service, "POST", "/v1/cangjie/tool-manual", "{}", [], config)
        let negative = handleCkbHttpRequest(service, "POST", "/v1/cangjie/negative-rules", "{}", [], config)

        @Expect(symbol.statusCode, 400)
        @Expect(symbol.body.contains("\"reason\":\"empty_symbol\""), true)
        @Expect(doc.statusCode, 400)
        @Expect(doc.body.contains("\"reason\":\"empty_doc_selector\""), true)
        @Expect(tool.statusCode, 400)
        @Expect(tool.body.contains("\"reason\":\"empty_tool\""), true)
        @Expect(negative.statusCode, 400)
        @Expect(negative.body.contains("\"reason\":\"empty_query\""), true)
    }

    @TestCase
    public func p5Bnd001SymbolLookupRejectsEmptySymbol(): Unit {
        let response = ckbApiHandle(this.service("p5-http-bnd"), "POST", "/v1/cangjie/symbol-lookup", "{}", [])

        @Expect(response.contains("\"ok\":false"), true)
        @Expect(response.contains("\"code\":\"ckb.bad_request\""), true)
        @Expect(response.contains("symbol must not be empty"), true)
        @Expect(response.contains("empty_symbol"), true)
    }

    @TestCase
    public func p5Pos001FreshnessRouteReturnsCorpusStatus(): Unit {
        let response = ckbApiHandle(this.service("p5-http-freshness"), "GET", "/v1/cangjie/corpus/freshness", "", [])

        @Expect(response.contains("\"ok\":true"), true)
        @Expect(response.contains("\"activeKnowledgeVersion\""), true)
        @Expect(response.contains("\"targetVersion\""), true)
        @Expect(response.contains("\"diagnostic\":\"synthetic_freshness\""), true)
        @Expect(response.contains("\"degraded\":true"), true)
    }

    @TestCase
    public func f2Pos001StructuredDesignRoutesAreReachable(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), p6PersistExactLookupStore("f2-api-pos-store"))
        let config = CkbHttpServiceConfig()
        let symbol = handleCkbHttpRequest(service, "POST", "/v1/cangjie/symbol-lookup", "{\"symbol\":\"ArrayList.add\",\"sourceSet\":\"std\",\"targetVersion\":\"1.0.0\"}", [], config)
        let doc = handleCkbHttpRequest(service, "POST", "/v1/cangjie/doc-section", "{\"sectionId\":\"docs/dev-guide/arrays.md#0-array-section\",\"targetVersion\":\"1.0.0\"}", [], config)
        let tool = handleCkbHttpRequest(service, "POST", "/v1/cangjie/tool-manual", "{\"tool\":\"cjpm\",\"command\":\"test\",\"targetVersion\":\"1.0.0\"}", [], config)
        let negative = handleCkbHttpRequest(service, "POST", "/v1/cangjie/negative-rules", "{\"q\":\"ArrayList negative rule\",\"targetVersion\":\"1.0.0\"}", [], config)
        let freshness = handleCkbHttpRequest(service, "GET", "/v1/cangjie/corpus/freshness", "", [], config)

        this.expectStructuredHttpOk(symbol, "symbol_card")
        this.expectStructuredHttpOk(doc, "doc_section")
        this.expectStructuredHttpOk(tool, "tool_manual")
        this.expectStructuredHttpOk(negative, "negative_rules")
        this.expectStructuredHttpOk(freshness, "corpus_freshness")
        @Expect(freshness.body.contains("\"diagnostic\":\"synthetic_freshness\""), true)
    }

    @TestCase
    public func p6Pos001SymbolLookupRouteUsesExactActiveCorpus(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), p6PersistExactLookupStore("p6-api-symbol-store"))
        let body = "{\"symbol\":\"ArrayList.add\",\"sourceSet\":\"std\",\"targetVersion\":\"1.0.0\"}"

        let response = ckbApiHandle(service, "POST", "/v1/cangjie/symbol-lookup", body, [])

        @Expect(response.contains("\"ok\":true"), true)
        @Expect(response.contains("exact_symbol_lookup_endpoint"), true)
        @Expect(response.contains("\"symbol\":\"ArrayList.add\""), true)
        @Expect(response.contains("exact_miss"), false)
    }

    @TestCase
    public func p6Neg001ToolManualRouteReturnsExactMissForUnknownCommand(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), p6PersistExactLookupStore("p6-api-tool-miss-store"))
        let body = "{\"tool\":\"cjpm\",\"command\":\"publish\",\"targetVersion\":\"1.0.0\"}"

        let response = ckbApiHandle(service, "POST", "/v1/cangjie/tool-manual", body, [])

        @Expect(response.contains("\"ok\":true"), true)
        @Expect(response.contains("exact_tool_manual_endpoint"), true)
        @Expect(response.contains("exact_miss"), true)
        @Expect(response.contains("\"items\":[]"), true)
    }

    @TestCase
    public func p3E2E001RestAndMcpApiSearchShareStructuredEvidenceHash(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), p6PersistExactLookupStore("p3-rest-mcp-parity-store"))
        let config = CkbHttpServiceConfig()
        let rest = handleCkbHttpRequest(service, "POST", "/v1/cangjie/api-search", "{\"q\":\"ArrayList\",\"module\":\"std.collection\",\"symbol\":\"ArrayList\",\"targetVersion\":\"1.0.0\"}", [], config)
        let mcp = CkbMcpStdioServer(service).handleRequest("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"cangjie_api_search\",\"arguments\":{\"q\":\"ArrayList\",\"module\":\"std.collection\",\"symbol\":\"ArrayList\",\"targetVersion\":\"1.0.0\"}}}")
        let restHash = this.p3JsonStringField(rest.body, "evidenceHash")
        let mcpHash = this.p3JsonStringField(mcp, "evidenceHash")

        @Expect(rest.statusCode, 200)
        @Expect(rest.body.contains("\"resultType\":\"api_pattern\""), true)
        @Expect(mcp.contains("\"structuredContent\""), true)
        @Expect(mcp.contains("\"resultType\":\"api_pattern\""), true)
        @Expect(restHash != "", true)
        @Expect(mcpHash, restHash)
    }

    private func expectStructuredHttpOk(response: CkbHttpHandlerResponse, resultType: String): Unit {
        @Expect(response.statusCode, 200)
        @Expect(response.body.contains("\"ok\":true"), true)
        @Expect(response.body.contains("\"resultType\":\"${resultType}\""), true)
        @Expect(response.body.contains("\"interfaceId\""), true)
        @Expect(response.body.contains("\"contentFamily\""), true)
        @Expect(response.body.contains("\"updateMechanism\""), true)
        @Expect(response.body.contains("\"targetVersion\""), true)
        @Expect(response.body.contains("\"versionResolutionId\""), true)
        @Expect(response.body.contains("\"evidenceHash\""), true)
        @Expect(response.body.contains("\"citations\""), true)
        @Expect(response.body.contains("\"sourceSet\""), true)
        @Expect(response.body.contains("\"provenance\""), true)
    }

    private func p3JsonStringField(raw: String, key: String): String {
        let marker = "\"${key}\":\""
        let parts = raw.split(marker)
        if (parts.size < 2) {
            return ""
        }
        let value = parts[1].split("\"")
        if (value.size == 0) {
            return ""
        }
        value[0]
    }
}
