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
    public func runP3(args: Array<String>): CkbReproMainCliResult {
        this.calls.add("p3:${args[0]}")
        CkbReproMainCliResult(true, 0, "p3 human\n")
    }
    public func runP4(args: Array<String>): CkbReproMainCliResult {
        this.calls.add("p4:${args[0]}")
        CkbReproMainCliResult(true, 0, "p4 human\n")
    }
    public func runPublicEvidence(args: Array<String>): CkbReproMainCliResult {
        this.calls.add("evidence:${args[0]}")
        CkbReproMainCliResult(true, 0, "evidence human\n")
    }
    public func runPreflight(args: Array<String>): CkbReproMainCliResult {
        this.calls.add("preflight:${args[0]}")
        CkbReproMainCliResult(true, 1, "preflight human\n")
    }
    public func runBundle(args: Array<String>): CkbReproMainCliResult {
        this.calls.add("bundle:${args[0]}")
        CkbReproMainCliResult(true, 0, "bundle human\n")
    }
    public func runPublishGate(args: Array<String>): CkbReproMainCliResult {
        this.calls.add("publish:${args[0]}")
        CkbReproMainCliResult(true, 1, "publish human\n")
    }
    public func runP8(args: Array<String>): CkbReproMainCliResult {
        this.calls.add("p8:${args[0]}")
        CkbReproMainCliResult(true, 0, "p8 human\n")
    }
}

@Test
public class CkbReproMainCliTest {
    @TestCase
    public func p3P4AndP8CommandsRouteThroughOwnedProductionBoundaries(): Unit {
        let adapter = P0MainCliAdapter()
        for (command in ["ckb-portable-vector-build", "ckb-qdrant-snapshot",
            "ckb-retrieval-parity", "ckb-repro-build", "ckb-repro-promote",
            "ckb-repro-verify"]) {
            let result = executeCkbReproMainCli(command, [command], adapter)
            @Expect(result.handled, true)
        }
        @Expect(adapter.calls.toArray(), [
            "p3:ckb-portable-vector-build", "p3:ckb-qdrant-snapshot",
            "p3:ckb-retrieval-parity", "p4:ckb-repro-build",
            "p4:ckb-repro-promote", "p8:ckb-repro-verify"])
    }

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
    public func p5P6AndP9CommandsRouteBeforeKnowledgeBaseLoading(): Unit {
        let adapter = P0MainCliAdapter()
        for (command in ["ckb-public-evidence-export", "ckb-repro-preflight",
            "ckb-repro-bundle"]) {
            let result = executeCkbReproMainCli(command, [command], adapter)
            @Expect(result.handled, true)
        }
        @Expect(adapter.calls.toArray(), [
            "evidence:ckb-public-evidence-export",
            "preflight:ckb-repro-preflight",
            "bundle:ckb-repro-bundle"])
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
        for (command in ["ckb-release-export", "ckb-public-evidence-export",
            "ckb-repro-preflight", "ckb-repro-bundle",
            "ckb-repro-publish-gate", "ckb-portable-vector-build",
            "ckb-qdrant-snapshot", "ckb-retrieval-parity",
            "ckb-repro-build", "ckb-repro-promote", "ckb-repro-verify"]) {
            let human = runCkbReproMainCli(command, [command])
            @Expect(human.handled, true)
            @Expect(human.exitCode, 2)
            @Expect(human.output.startsWith("{"), false)
            @Expect(human.output.startsWith("{"), false)

            let json = runCkbReproMainCli(command, [command, "--json"])
            @Expect(json.handled, true)
            @Expect(json.exitCode, 2)
            @Expect(json.output.startsWith("{"), true)
            @Expect(json.output.contains("\"diagnostic\""), true)
        }
    }
}
