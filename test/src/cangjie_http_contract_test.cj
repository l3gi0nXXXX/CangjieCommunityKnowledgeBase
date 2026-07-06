package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieHttpContractTest {
    private func service(name: String): CkbCommandLoopService {
        CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/${name}"))
    }

    @TestCase
    public func p1Pos001TaskKnowledgePackRouteReturnsVersionPlanAndCoverage(): Unit {
        let body = "{\"taskId\":\"CJ-HUMANEVAL-000\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"Implement ArrayList helper\",\"signature\":\"func solve(xs: ArrayList<Int64>): Int64\",\"expectedKnowledgeTags\":[\"ArrayList\",\"symbol\"],\"targetVersion\":\"1.0.0\",\"sourceSet\":\"stdx\",\"sourceRef\":\"release-1.0.0\",\"versionPolicy\":\"exact\"}"
        let response = ckbApiHandle(this.service("p1-http-pos-001"), "POST", "/v1/cangjie/task-knowledge-pack", body, [])

        @Expect(response.contains("\"ok\":true"), true)
        @Expect(response.contains("\"versionResolution\""), true)
        @Expect(response.contains("\"queryPlan\""), true)
        @Expect(response.contains("\"coverage\""), true)
        @Expect(response.contains("\"coveragePass\":true"), true)
    }

    @TestCase
    public func p1Neg001TaskKnowledgePackRouteRejectsEmptyTaskAndSignature(): Unit {
        let response = ckbApiHandle(this.service("p1-http-neg-001"), "POST", "/v1/cangjie/task-knowledge-pack", "{\"targetVersion\":\"1.0.0\"}", [])

        @Expect(response.contains("\"ok\":false"), true)
        @Expect(response.contains("\"code\":\"ckb.bad_request\""), true)
        @Expect(response.contains("task_or_signature_required"), true)
    }

    @TestCase
    public func p1Pos002SchemaAdvertisesNewRoutesAndTools(): Unit {
        let response = ckbApiHandle(this.service("p1-http-pos-002"), "GET", "/v1/schema", "", [])

        @Expect(response.contains("POST /v1/cangjie/version/resolve"), true)
        @Expect(response.contains("POST /v1/cangjie/task-knowledge-pack"), true)
        @Expect(response.contains("cangjie_task_knowledge_pack"), true)
        @Expect(response.contains("cangjie_compile_diagnose_v2"), true)
    }

    @TestCase
    public func p1Bnd001NestedResolutionOkFalseDoesNotBecomeHttpError(): Unit {
        let body = "{\"targetVersion\":\"1.0.0\",\"sourceSet\":\"stdx\",\"sourceRef\":\"missing-release\",\"versionPolicy\":\"exact\"}"
        let response = handleCkbHttpRequest(this.service("p1-http-bnd-001"), "POST", "/v1/cangjie/version/resolve", body, [], CkbHttpServiceConfig())

        @Expect(response.statusCode, 200)
        @Expect(response.body.contains("\"ok\":true"), true)
        @Expect(response.body.contains("\"data\":{\"ok\":false"), true)
        @Expect(response.body.contains("exact_source_ref_not_resolved"), true)
    }

    @TestCase
    public func f2Neg001UnknownRouteAndWrongMethodDoNotCallDesignHandlers(): Unit {
        let service = this.service("f2-http-neg-001")
        let config = CkbHttpServiceConfig()
        let missing = handleCkbHttpRequest(service, "POST", "/v1/cangjie/not-a-route", "{}", [], config)
        let wrongMethod = handleCkbHttpRequest(service, "GET", "/v1/cangjie/symbol-lookup", "{\"symbol\":\"ArrayList.add\"}", [], config)

        @Expect(missing.statusCode, 404)
        @Expect(missing.body.contains("\"code\":\"ckb.not_found\""), true)
        @Expect(wrongMethod.statusCode, 404)
        @Expect(wrongMethod.body.contains("\"code\":\"ckb.not_found\""), true)
        @Expect(wrongMethod.body.contains("exact_symbol_lookup_endpoint"), false)
    }
}
