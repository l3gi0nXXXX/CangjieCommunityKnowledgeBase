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
    public func p5Bnd001SymbolLookupRejectsEmptySymbol(): Unit {
        let response = ckbApiHandle(this.service("p5-http-bnd"), "POST", "/v1/cangjie/symbol-lookup", "{}", [])

        @Expect(response.contains("\"ok\":false"), true)
        @Expect(response.contains("\"code\":\"ckb.bad_request\""), true)
        @Expect(response.contains("symbol must not be empty"), true)
    }

    @TestCase
    public func p5Pos001FreshnessRouteReturnsCorpusStatus(): Unit {
        let response = ckbApiHandle(this.service("p5-http-freshness"), "GET", "/v1/cangjie/corpus/freshness", "", [])

        @Expect(response.contains("\"ok\":true"), true)
        @Expect(response.contains("\"activeKnowledgeVersion\""), true)
        @Expect(response.contains("\"targetVersion\""), true)
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
}
