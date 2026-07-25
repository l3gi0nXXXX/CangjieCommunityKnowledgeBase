package cangjie_community_knowledge_base_test

import std.time.DateTime
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbCertificationHttpTest {
    @TestCase
    public func r7Neg00CertificationHttpRejectsNonLoopbackBind():Unit{@Expect(ckbCertificationHttpBindDiagnostic("0.0.0.0"),"certification_http_loopback_required");@Expect(ckbCertificationHttpBindDiagnostic("192.168.1.2"),"certification_http_loopback_required");@Expect(ckbCertificationHttpBindDiagnostic("127.0.0.1"),"ok");@Expect(ckbCertificationHttpBindDiagnostic("::1"),"ok")}
    private func root(name: String): String {
        "target/${name}-${DateTime.now().toUnixTimeStamp().toMilliseconds()}"
    }

    private func service(store: FileKnowledgeStore): CkbCommandLoopService {
        CkbCommandLoopService(CkbRuntimeConfig(), store)
    }

    private func activeStore(name: String): FileKnowledgeStore {
        let store = FileKnowledgeStore(this.root(name))
        let persisted = newOfflineKnowledgeBase().persistActiveSnapshot(store)
        @Expect(persisted.ok, true)
        store
    }

    private func initHeaders(): Array<String> {
        ["Content-Type: application/json", "Accept: application/json, text/event-stream"]
    }

    private func sessionId(response: CkbMcpHttpResponse): String {
        for (header in response.headers) {
            if (header.toAsciiLower().startsWith("mcp-session-id:")) {
                return header["mcp-session-id:".size..header.size].trimAscii()
            }
        }
        ""
    }

    @TestCase
    public func r7UtIdentityIsBoundToServiceMemoryAndStore(): Unit {
        let store = this.activeStore("r7-cert-http-ut")
        let service = this.service(store)
        let pointer = store.loadActiveSnapshotPointer()
        let snapshot = store.loadActiveSnapshot()
        let projection = service.prepareStudentServingProjection()
        @Expect(projection.index.diagnostics.size, 0)
        if (projection.index.diagnostics.size > 0) {
            @Expect(projection.index.diagnostics[0], "")
        }
        let identity = prepareCkbCertificationHttpIdentity(service, store)
        @Expect(identity.diagnostic, "ok")
        let response = handlePreparedCkbCertificationHttpRequest(identity, store, "GET",
            "/v1/certification/identity", "", [], CkbHttpServiceConfig())

        @Expect(response.statusCode, 200)
        @Expect(response.body.contains("\"schemaVersion\":\"ckb-certification-identity-v1\""), true)
        @Expect(response.body.contains("\"activeVersion\":\"${pointer.activeVersion}\""), true)
        @Expect(response.body.contains("\"pointerIdentityHash\":\"${ckbActiveSnapshotPointerIdentityHash(pointer)}\""), true)
        @Expect(response.body.contains("\"candidateChecksum\":\"${ckbCertifiedNormalizedRecordsChecksum(snapshot.normalizedRecords)}\""), true)
        @Expect(response.body.contains(store.root.toString()), false)
        @Expect(response.body.contains("token"), false)
        @Expect(response.body.contains("secret"), false)
        let unrelated = this.service(FileKnowledgeStore(this.root("r7-cert-http-unrelated")))
        @Expect(handleCkbCertificationHttpRequest(unrelated, store, "GET",
            "/v1/certification/identity", "", [], CkbHttpServiceConfig()).statusCode, 409)
    }

    @TestCase
    public func r7BndIdentityRejectsMissingStoreAndRequestBodyWithoutLeakingPath(): Unit {
        let store = FileKnowledgeStore(this.root("r7-cert-http-missing-private"))
        let missing = handleCkbCertificationHttpRequest(this.service(store), store, "GET",
            "/v1/certification/identity", "", [], CkbHttpServiceConfig())
        let body = handleCkbCertificationHttpRequest(this.service(store), store, "GET",
            "/v1/certification/identity", "{}", [], CkbHttpServiceConfig())

        @Expect(missing.statusCode, 409)
        @Expect(missing.body.contains("certification_identity_unavailable"), true)
        @Expect(missing.body.contains(store.root.toString()), false)
        @Expect(body.statusCode, 400)
        @Expect(body.body.contains("ckb.bad_request"), true)
    }

    @TestCase
    public func r7NegWriteAdminSchedulerAndOrdinaryReadRoutesAreUnavailable(): Unit {
        let store = this.activeStore("r7-cert-http-neg")
        let service = this.service(store)
        let before = ckbActiveSnapshotPointerIdentityHash(store.loadActiveSnapshotPointer())
        for ((method, path) in [
            ("POST", "/v1/admin/rebuild"),
            ("POST", "/v1/admin/scheduler/run"),
            ("POST", "/v1/events/gitcode/repository-changed"),
            ("POST", "/v1/cangjie/task-knowledge-pack"),
            ("GET", "/v1/status")
        ]) {
            let response = handleCkbCertificationHttpRequest(service, store, method, path, "", [], CkbHttpServiceConfig())
            @Expect(response.statusCode, 404)
            @Expect(response.body.contains("ckb.not_found"), true)
        }
        let wrongMethod = handleCkbCertificationHttpRequest(service, store, "POST",
            "/v1/certification/identity", "", [], CkbHttpServiceConfig())
        @Expect(wrongMethod.statusCode, 405)
        @Expect(ckbActiveSnapshotPointerIdentityHash(store.loadActiveSnapshotPointer()), before)
    }

    @TestCase
    public func r7PosCertificationMcpExposesReadOnlyKnowledgeTools(): Unit {
        let store = this.activeStore("r7-cert-http-pos")
        let sessions = CkbMcpHttpSessionStore()
        let service = this.service(store)
        let before = ckbActiveSnapshotPointerIdentityHash(store.loadActiveSnapshotPointer())
        let initialize = handleCkbMcpHttpRequest(service, "POST", "/mcp",
            "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"certification-test\",\"version\":\"1\"}}}",
            this.initHeaders(), CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), sessions)
        let sessionId = this.sessionId(initialize)
        let sessionHeaders = [
            "Content-Type: application/json",
            "Accept: application/json, text/event-stream",
            "MCP-Protocol-Version: 2025-06-18",
            "Mcp-Session-Id: ${sessionId}"
        ]
        _ = handleCkbMcpHttpRequest(service, "POST", "/mcp",
            "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\",\"params\":{}}",
            sessionHeaders, CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), sessions)
        let tools = handleCkbMcpHttpRequest(service, "POST", "/mcp",
            "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\",\"params\":{}}",
            sessionHeaders, CkbHttpServiceConfig(), CkbMcpHttpServiceConfig(), sessions)

        @Expect(initialize.statusCode, 200)
        @Expect(initialize.body.contains("\"protocolVersion\":\"2025-06-18\""), true)
        @Expect(sessionId != "", true)
        @Expect(tools.statusCode, 200)
        @Expect(tools.body.contains("\"name\":\"cangjie_task_knowledge_pack\""), true)
        @Expect(tools.body.contains("admin"), false)
        @Expect(tools.body.contains("scheduler"), false)
        @Expect(tools.body.contains("rebuild"), false)
        @Expect(tools.body.contains("sync"), false)
        @Expect(ckbActiveSnapshotPointerIdentityHash(store.loadActiveSnapshotPointer()), before)
        @Expect(ckbCommandNeedsNativeTlsBootstrap("certification-http"), true)
    }
}
