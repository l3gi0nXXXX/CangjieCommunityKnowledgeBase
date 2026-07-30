package cangjie_community_knowledge_base_test

import std.fs.{exists, File, Path, remove}
import std.unittest.*
import std.unittest.testmacro.*

private class CkbStartupServingBuildObserver <: CangjieServingIndexBuildObserver {
    public var count: Int64 = 0
    public init() {}
    public func onServingIndexBuild(recordCount: Int64): Unit {
        this.count += 1
    }
}

@Test
public class CkbServiceStartupMemoryTest {
    private func projectText(relative: String): String {
        try {
            String.fromUtf8(File.readFrom(Path(relative)))
        } catch (_: Exception) {
            ""
        }
    }

    @TestCase
    public func s1Ut01CommandLoopServiceCommandClassificationIsComplete(): Unit {
        for (command in [
            "service", "start", "service-http", "http-service", "certification-http", "mcp-stdio",
            "cangjie-landing-status", "service-once", "restart",
            "cangjie-corpus-status", "cangjie-knowledge-pack",
            "cangjie-api-search", "cangjie-syntax-query", "cangjie-cookbook",
            "cangjie-diagnose", "cangjie-llms", "cangjie-context-pack"
        ]) {
            @Expect(ckbCliCommandUsesCommandLoopService(command), true)
        }
        for (command in ["", "query", "evidence", "schema", "unknown", "SERVICE-HTTP"]) {
            @Expect(ckbCliCommandUsesCommandLoopService(command), false)
        }
    }

    @TestCase
    public func s2Ut01ServiceHeapPreflightAcceptsProductionBudget(): Unit {
        for (heap in ["4GB", "4096MB", "4096M", "5g"]) {
            let result = ckbServiceHeapPreflight(heap)
            @Expect(result.ok, true)
            @Expect(result.errorCode, "")
            @Expect(result.actualHeapMiB >= 4096, true)
        }
    }

    @TestCase
    public func s2Ut02ServiceHeapPreflightRejectsMissingInvalidAndSmallBudgets(): Unit {
        let missing = ckbServiceHeapPreflight("")
        @Expect(missing.ok, false)
        @Expect(missing.errorCode, "ckb.service_heap_not_configured")
        @Expect(missing.actualHeapMiB, 0)

        let invalid = ckbServiceHeapPreflight("仓颉🙂")
        @Expect(invalid.ok, false)
        @Expect(invalid.errorCode, "ckb.service_heap_invalid")
        @Expect(invalid.diagnostic.contains("仓颉"), false)

        for (heap in ["0", "256MB", "4095MB"]) {
            let result = ckbServiceHeapPreflight(heap)
            @Expect(result.ok, false)
            @Expect(result.errorCode, "ckb.service_heap_too_small")
        }
    }

    @TestCase
    public func s2Bd01ServiceHeapPreflightHasExact4096MiBBoundary(): Unit {
        @Expect(ckbServiceHeapPreflight("4095MB").ok, false)
        @Expect(ckbServiceHeapPreflight("4096MB").ok, true)
    }

    @TestCase
    public func s2Pos01PreloadedCommandServiceDoesNotMaterializeSnapshotAgain(): Unit {
        let root = "target/ckb-service-startup-single-materialization"
        if (exists(Path(root))) { remove(Path(root), recursive: true) }
        let store = FileKnowledgeStore(root)
        let source = r7CleanKnowledgeBase()
        @Expect(source.persistActiveSnapshot(store).ok, true)
        let loaded = newKnowledgeBaseFromStoreWithRuntime(store, CkbRuntimeConfig())
        @Expect(loaded.source, "persisted")
        let before = store.activeSnapshotMaterializationCount()
        let service = CkbCommandLoopService(CkbRuntimeConfig(), store,
            loadedKnowledgeBase: Some<KnowledgeBase>(loaded.kb))
        @Expect(store.activeSnapshotMaterializationCount(), before)
        @Expect(service.statusSnapshot().activeKnowledgeVersion,
            loaded.kb.status().activeKnowledgeVersion)
        remove(Path(root), recursive: true)
    }

    @TestCase
    public func s3Ut01LoadedSnapshotOwnershipMovesRecordContainers(): Unit {
        let root = "target/ckb-service-startup-owned-restore"
        if (exists(Path(root))) { remove(Path(root), recursive: true) }
        let store = FileKnowledgeStore(root)
        @Expect(r7CleanKnowledgeBase().persistActiveSnapshot(store).ok, true)
        let snapshot = store.loadActiveSnapshot()
        let rawCount = snapshot.rawRecords.size
        let normalizedCount = snapshot.normalizedRecords.size
        let activeCount = snapshot.activeIndex.size
        let target = KnowledgeBase(FakeClock(0))

        @Expect(target.restoreLoadedActiveSnapshot(snapshot), true)
        @Expect(snapshot.rawRecords.size, 0)
        @Expect(snapshot.normalizedRecords.size, 0)
        @Expect(snapshot.activeIndex.size, 0)
        @Expect(target.status().storage.rawCount, rawCount)
        @Expect(target.status().storage.normalizedCount, normalizedCount)
        @Expect(target.status().storage.indexCount, activeCount)
        remove(Path(root), recursive: true)
    }

    @TestCase
    public func s3Ut02PublicSnapshotRestoreKeepsCallerIsolation(): Unit {
        let root = "target/ckb-service-startup-copy-restore"
        if (exists(Path(root))) { remove(Path(root), recursive: true) }
        let store = FileKnowledgeStore(root)
        @Expect(r7CleanKnowledgeBase().persistActiveSnapshot(store).ok, true)
        let snapshot = store.loadActiveSnapshot()
        let rawCount = snapshot.rawRecords.size
        let normalizedCount = snapshot.normalizedRecords.size
        let activeCount = snapshot.activeIndex.size
        let target = KnowledgeBase(FakeClock(0))

        @Expect(target.restoreActiveSnapshot(snapshot), true)
        snapshot.rawRecords.clear()
        snapshot.normalizedRecords.clear()
        snapshot.activeIndex.clear()
        @Expect(target.status().storage.rawCount, rawCount)
        @Expect(target.status().storage.normalizedCount, normalizedCount)
        @Expect(target.status().storage.indexCount, activeCount)
        remove(Path(root), recursive: true)
    }

    @TestCase
    public func s4Pos01StreamedSnapshotPreservesUnicodeAndFinalLineWithoutNewline(): Unit {
        let root = "target/ckb-service-startup-stream-unicode"
        if (exists(Path(root))) { remove(Path(root), recursive: true) }
        let store = FileKnowledgeStore(root)
        let source = r7CleanKnowledgeBase()
        let prepared = source.activeRecordSnapshot()
        prepared[0].title = "仓颉🙂流式加载"
        prepared[0].chunk = "中文内容🙂"
        @Expect(source.persistActiveSnapshot(store).ok, true)
        remove(Path(root).join("metadata/active-snapshot.manifest"))
        let activePath = Path(root).join("index/active.ckb")
        let bytes = File.readFrom(activePath)
        @Expect(bytes.size > 0, true)
        File.writeTo(activePath, bytes[0..bytes.size - 1])

        let loaded = store.loadActiveSnapshot()
        @Expect(loaded.valid, true)
        @Expect(loaded.activeIndex[0].title, "仓颉🙂流式加载")
        @Expect(loaded.activeIndex[0].chunk, "中文内容🙂")
        remove(Path(root), recursive: true)
    }

    @TestCase
    public func s4Neg02InvalidUtf8ReturnsSnapshotDiagnosticInsteadOfThrowing(): Unit {
        let root = "target/ckb-service-startup-stream-invalid-utf8"
        if (exists(Path(root))) { remove(Path(root), recursive: true) }
        let store = FileKnowledgeStore(root)
        @Expect(r7CleanKnowledgeBase().persistActiveSnapshot(store).ok, true)
        remove(Path(root).join("metadata/active-snapshot.manifest"))
        let activePath = Path(root).join("index/active.ckb")
        File.writeTo(activePath, [0xff, 0xfe, 0xfd])

        let loaded = store.loadActiveSnapshot()
        @Expect(loaded.valid, false)
        @Expect(loaded.diagnostic, "invalid_snapshot_encoding:active_index")
        remove(Path(root), recursive: true)
    }

    @TestCase
    public func s5Ut01StudentServingProjectionIsBuiltOnlyOnceAcrossLoadAndStart(): Unit {
        let root = "target/ckb-service-startup-single-serving-build"
        if (exists(Path(root))) { remove(Path(root), recursive: true) }
        let store = FileKnowledgeStore(root)
        @Expect(r7CleanKnowledgeBase().persistActiveSnapshot(store).ok, true)
        let observer = CkbStartupServingBuildObserver()
        let loaded = newKnowledgeBaseFromStoreWithRuntime(
            store, CkbRuntimeConfig(), studentServingBuildObserver: observer)
        @Expect(observer.count, 1)
        let service = CkbCommandLoopService(CkbRuntimeConfig(), store,
            loadedKnowledgeBase: Some<KnowledgeBase>(loaded.kb),
            studentServingBuildObserver: observer)
        _ = service.start()
        @Expect(observer.count, 1)
        remove(Path(root), recursive: true)
    }

    @TestCase
    public func s6Ut01ReadmeAndOperationsRunbookDeclareServiceRuntimeContract(): Unit {
        let readme = this.projectText("../README.md")
        let operations = this.projectText("../docs/service-http-operations.md")
        for (required in [
            "source <CANGJIE_SDK_ROOT>/envsetup.sh",
            "export DYLD_LIBRARY_PATH=",
            "export cjHeapSize=4GB",
            "/v1/health"
        ]) {
            @Expect((readme + operations).contains(required), true)
        }
        for (code in [
            "ckb.service_heap_not_configured",
            "ckb.service_heap_invalid",
            "ckb.service_heap_too_small",
            "ckb.http_service_failed"
        ]) {
            @Expect(operations.contains(code), true)
        }
        @Expect(operations.contains("256MB"), true)
        @Expect(operations.contains("not stored in `ckb-live.conf`"), true)
    }

    @TestCase
    public func s6Ut02OwnedServiceChildBootstrapEnforcesProductionHeap(): Unit {
        let script = ckbAbcdeNativeTlsBootstrapScript(
            "/tmp/ckb", ["certification-http"])
        @Expect(script.contains("export cjHeapSize=4GB"), true)
        @Expect(script.contains("export CKB_NATIVE_TLS_BOOTSTRAPPED=1"), true)
    }
}
