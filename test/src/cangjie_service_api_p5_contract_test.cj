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
}
