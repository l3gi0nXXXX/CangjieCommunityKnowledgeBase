package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

private class P0MainCliAdapter <: CkbReproMainCliAdapter {
    public let calls = ArrayList<String>()
    public init() {}
    public func runRelease(args: Array<String>): CkbReproMainCliResult {
        this.calls.add("release:${args[0]}")
        CkbReproMainCliResult(true, 0, "release human\n")
    }
    public func runPublishGate(args: Array<String>): CkbReproMainCliResult {
        this.calls.add("publish:${args[0]}")
        CkbReproMainCliResult(true, 1, "publish human\n")
    }
}

@Test
public class CkbReproMainCliTest {
    @TestCase
    public func p2AndP9CommandsRouteBeforeKnowledgeBaseLoading(): Unit {
        let adapter = P0MainCliAdapter()
        for (command in ["ckb-release-export", "ckb-release-import"]) {
            let result = executeCkbReproMainCli(command, [command], adapter)
            @Expect(result.handled, true)
            @Expect(result.exitCode, 0)
            @Expect(result.output, "release human\n")
        }
        let publish = executeCkbReproMainCli("ckb-repro-publish-gate",
            ["ckb-repro-publish-gate"], adapter)
        @Expect(publish.handled, true)
        @Expect(publish.exitCode, 1)
        @Expect(publish.output, "publish human\n")
        @Expect(adapter.calls.size, 3)
    }

    @TestCase
    public func unrelatedCommandsAreNotConsumedByReproRouter(): Unit {
        let adapter = P0MainCliAdapter()
        let result = executeCkbReproMainCli("status", ["status"], adapter)
        @Expect(result.handled, false)
        @Expect(result.output, "")
        @Expect(adapter.calls.size, 0)
    }

    @TestCase
    public func defaultOutputIsHumanAndJsonRequiresExplicitFlag(): Unit {
        for (command in ["ckb-release-export", "ckb-repro-publish-gate"]) {
            let human = runCkbReproMainCli(command, [command])
            @Expect(human.handled, true)
            @Expect(human.exitCode, 2)
            @Expect(human.output.startsWith("{"), false)
            @Expect(human.output.contains("diagnostic"), true)

            let json = runCkbReproMainCli(command, [command, "--json"])
            @Expect(json.handled, true)
            @Expect(json.exitCode, 2)
            @Expect(json.output.startsWith("{"), true)
            @Expect(json.output.contains("\"ok\""), true)
        }
    }
}
