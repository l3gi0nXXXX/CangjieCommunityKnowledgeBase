package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

private class P4ThrowingCompositionExecutor <:
    CkbReproP4BuildCompositionExecutor {
    public var calls: Int64 = 0
    public func execute(args: Array<String>,
        assembly: CkbReproP4BuildProductionAssembly): CkbReproMainCliResult {
        this.calls += 1; throw Exception("build failed")
    }
}

private class P4RecordingRootCleaner <: CkbReproP4OwnedRootCleaner {
    public let paths = ArrayList<String>()
    public var firstFails: Bool = false
    public func cleanup(path: String): Bool {
        this.paths.add(path)
        if (this.firstFails && this.paths.size == 1) { return false }
        true
    }
}

@Test
public class CkbReproP4CompositionCleanupTest {
    @TestCase
    public func buildFailureAlwaysAttemptsBothOwnedRootCleanups(): Unit {
        let executor = P4ThrowingCompositionExecutor()
        let cleaner = P4RecordingRootCleaner()
        cleaner.firstFails = true
        let result = ckbReproExecuteP4BuildWithCleanup(
            ["ckb-repro-build"], false,
            CkbReproP4BuildProductionAssembly(), "/tmp/cache-owned",
            "/tmp/source-owned", executor, cleaner)
        @Expect(executor.calls, 1)
        @Expect(cleaner.paths.toArray(),
            ["/tmp/cache-owned", "/tmp/source-owned"])
        @Expect(result.exitCode, 2)
        @Expect(result.output.contains("p4_source_cleanup_failed"), true)

        let successfulCleanup = P4RecordingRootCleaner()
        let failed = ckbReproExecuteP4BuildWithCleanup(
            ["ckb-repro-build"], false,
            CkbReproP4BuildProductionAssembly(), "/tmp/cache-owned",
            "/tmp/source-owned", P4ThrowingCompositionExecutor(),
            successfulCleanup)
        @Expect(successfulCleanup.paths.size, 2)
        @Expect(failed.output.contains("p4_build_execution_failed"), true)
    }
}
