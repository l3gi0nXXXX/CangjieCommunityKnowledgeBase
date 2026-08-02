package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.time.DateTime
import std.unittest.*
import std.unittest.testmacro.*
import stdx.crypto.digest.SHA256

@Test
public class CkbReproP8OwnedLifecycleTest {
    @TestCase
    public func startsPinnedQdrantOnInternalLoopbackNetwork(): Unit {
        let fixture = p8LifecycleFixture("qdrant-start")
        let commands = P8FakeOwnedCommandExecutor()
        commands.results.add(p8CommandOk(fixture.authority.qdrantImageId))
        commands.results.add(p8CommandOk("network-id"))
        commands.results.add(p8CommandOk(p8ContainerId()))
        commands.results.add(p8CommandOk(fixture.authority.qdrantImageId))
        let readiness = P8FakeOwnedReadinessProbe()
        readiness.responses.add(p8ReadyUnavailable())
        readiness.responses.add(p8Ready(200, "ready".toArray()))
        let lifecycle = CkbNativeP8OwnedLocalLifecycle(fixture.authority,
            fixture.qdrant, commandExecutor: commands,
            readinessProbe: readiness)

        @Expect(lifecycle.startQdrant(fixture.options).diagnostic, "ok")
        @Expect(commands.calls.size, 4)
        @Expect(commands.calls[0].args,
            ["image", "inspect", "--format={{.Id}}",
                fixture.authority.qdrantImageReference])
        @Expect(commands.calls[1].args.contains("--internal"), true)
        @Expect(commands.calls[2].args.contains("--pull=never"), true)
        @Expect(commands.calls[2].args.contains(
            "127.0.0.1:6333:6333"), true)
        @Expect(commands.calls[2].args.contains(
            fixture.authority.qdrantImageReference), true)
        @Expect(lifecycle.cleanup(fixture.options), true)
        p8RemoveFixture(fixture.root)
    }

    @TestCase
    public func startsCkbWithOwnedConfigAndEmptyEnvironment(): Unit {
        let fixture = p8LifecycleFixture("ckb-start")
        let commands = P8FakeOwnedCommandExecutor()
        p8QueueQdrantSuccess(commands, fixture)
        commands.process = Some<CkbP8OwnedProcessHandle>(P8FakeOwnedProcess())
        let readiness = P8FakeOwnedReadinessProbe()
        readiness.responses.add(p8ReadyUnavailable())
        readiness.responses.add(p8Ready(200, "ready".toArray()))
        readiness.responses.add(p8ReadyUnavailable())
        readiness.responses.add(p8Ready(200,
            ("{\"ok\":true,\"data\":{\"activeKnowledgeVersion\":\"" +
                fixture.knowledgeVersion + "\"}}" ).toArray()))
        let lifecycle = CkbNativeP8OwnedLocalLifecycle(fixture.authority,
            fixture.qdrant, commandExecutor: commands,
            readinessProbe: readiness)

        @Expect(lifecycle.startQdrant(fixture.options).diagnostic, "ok")
        @Expect(lifecycle.startParityService(fixture.options.runtimeRoot,
            fixture.knowledgeVersion).diagnostic, "ok")
        @Expect(commands.launches.size, 1)
        @Expect(commands.launches[0].args,
            ["--config", lifecycle.ownedConfigPath(), "--store",
                fixture.options.runtimeRoot, "service-http"])
        let config = String.fromUtf8(
            File.readFrom(Path(lifecycle.ownedConfigPath())))
        @Expect(config.contains("network.enabled=false"), true)
        @Expect(config.contains("scheduler.enabled=false"), true)
        @Expect(config.contains("vector.backend=qdrant"), true)
        @Expect(config.contains("vector.endpoint=http://127.0.0.1:6333"), true)
        for (forbidden in ["token", "credential", "provider", "model",
            "proxy="]) {
            @Expect(config.toAsciiLower().contains(forbidden), false)
        }
        @Expect(lifecycle.stopParityService(), true)
        p8RemoveFixture(fixture.root)
    }

    @TestCase
    public func buildsOnlyFixedEmptyEnvironmentMcpSpec(): Unit {
        let fixture = p8LifecycleFixture("mcp-spec")
        let built = buildCkbP8OwnedMcpStdioSpec(fixture.authority,
            "${fixture.options.workRoot}/owned.conf",
            fixture.options.runtimeRoot)
        @Expect(built[0].diagnostic, "ok")
        @Expect(built[1].executable, fixture.authority.ckbExecutable)
        @Expect(built[1].args.toArray(), ["--config",
            "${fixture.options.workRoot}/owned.conf", "--store",
            fixture.options.runtimeRoot, "mcp-stdio"])
        @Expect(built[1].environment.size, 0)
        p8RemoveFixture(fixture.root)
    }

    @TestCase
    public func readinessIdentityAndUtf8FailuresStopOwnedProcess(): Unit {
        for (response in [
            p8Ready(200, "{\"activeKnowledgeVersion\":\"wrong\"}".toArray()),
            p8Ready(200, [UInt8(0xff)])
        ]) {
            let fixture = p8LifecycleFixture("ready-fail")
            let process = P8FakeOwnedProcess()
            let commands = P8FakeOwnedCommandExecutor()
            p8QueueQdrantSuccess(commands, fixture)
            commands.process = Some<CkbP8OwnedProcessHandle>(process)
            let readiness = P8FakeOwnedReadinessProbe()
            readiness.responses.add(p8ReadyUnavailable())
            readiness.responses.add(p8Ready(200, "ready".toArray()))
            readiness.responses.add(p8ReadyUnavailable())
            readiness.responses.add(response)
            let lifecycle = CkbNativeP8OwnedLocalLifecycle(fixture.authority,
                fixture.qdrant, commandExecutor: commands,
                readinessProbe: readiness)
            @Expect(lifecycle.startQdrant(fixture.options).ok, true)
            @Expect(lifecycle.startParityService(fixture.options.runtimeRoot,
                fixture.knowledgeVersion).ok, false)
            @Expect(process.stopCalls, 1)
            p8RemoveFixture(fixture.root)
        }
    }

    @TestCase
    public func cleanupContinuesAfterEachIndependentFailure(): Unit {
        let fixture = p8LifecycleFixture("cleanup")
        let commands = P8FakeOwnedCommandExecutor()
        commands.results.add(p8CommandOk(fixture.authority.qdrantImageId))
        commands.results.add(p8CommandOk("network-id"))
        commands.results.add(p8CommandOk(p8ContainerId()))
        commands.results.add(p8CommandOk(fixture.authority.qdrantImageId))
        commands.cleanupFails = true
        let readiness = P8FakeOwnedReadinessProbe()
        readiness.responses.add(p8ReadyUnavailable())
        readiness.responses.add(p8Ready(200, "ready".toArray()))
        let lifecycle = CkbNativeP8OwnedLocalLifecycle(fixture.authority,
            fixture.qdrant, commandExecutor: commands,
            readinessProbe: readiness)
        @Expect(lifecycle.startQdrant(fixture.options).ok, true)
        @Expect(lifecycle.cleanup(fixture.options), false)
        @Expect(commands.cleanupCalls, 2)
        @Expect(exists(Path(fixture.options.qdrantRoot)), false)
        p8RemoveFixture(fixture.root)
    }

    @TestCase
    public func failedServiceStopKeepsHandleForCleanupRetry(): Unit {
        let fixture = p8LifecycleFixture("stop-retry")
        let process = P8FakeOwnedProcess(); process.stopFailures = 1
        let commands = P8FakeOwnedCommandExecutor()
        p8QueueQdrantSuccess(commands, fixture)
        commands.process = Some<CkbP8OwnedProcessHandle>(process)
        let readiness = P8FakeOwnedReadinessProbe()
        readiness.responses.add(p8ReadyUnavailable())
        readiness.responses.add(p8Ready(200, "ready".toArray()))
        readiness.responses.add(p8ReadyUnavailable())
        readiness.responses.add(p8Ready(200,
            "{\"activeKnowledgeVersion\":\"${fixture.knowledgeVersion}\"}"
                .toArray()))
        let lifecycle = CkbNativeP8OwnedLocalLifecycle(fixture.authority,
            fixture.qdrant, commandExecutor: commands,
            readinessProbe: readiness)
        @Expect(lifecycle.startQdrant(fixture.options).ok, true)
        @Expect(lifecycle.startParityService(fixture.options.runtimeRoot,
            fixture.knowledgeVersion).ok, true)
        @Expect(lifecycle.stopParityService(), false)
        @Expect(lifecycle.cleanup(fixture.options), true)
        @Expect(process.stopCalls, 2)
        p8RemoveFixture(fixture.root)
    }

    @TestCase
    public func qdrantFailurePreservesEncodingAndCleansOwnedState(): Unit {
        let fixture = p8LifecycleFixture("qdrant-invalid-utf8")
        let commands = P8FakeOwnedCommandExecutor()
        let invalid = p8CommandOk(""); invalid.stdoutBytes = [UInt8(0xff)]
        commands.results.add(invalid)
        let readiness = P8FakeOwnedReadinessProbe()
        readiness.responses.add(p8ReadyUnavailable())
        let lifecycle = CkbNativeP8OwnedLocalLifecycle(fixture.authority,
            fixture.qdrant, commandExecutor: commands,
            readinessProbe: readiness)
        @Expect(lifecycle.startQdrant(fixture.options).diagnostic,
            "invalid_response_encoding")
        @Expect(commands.cleanupCalls, 1)
        @Expect(exists(Path(fixture.options.workRoot)), false)
        @Expect(exists(Path(fixture.options.qdrantRoot)), false)
        p8RemoveFixture(fixture.root)
    }
}

private class P8LifecycleFixture {
    var root: String = ""
    var authority: CkbP8OwnedLocalRuntimeAuthority =
        CkbP8OwnedLocalRuntimeAuthority()
    var qdrant: CkbQdrantSnapshotManifest = CkbQdrantSnapshotManifest()
    var options: CkbReproVerifyOptions = CkbReproVerifyOptions()
    var knowledgeVersion: String = "ckb-portable-test"
    init() {}
}

private class P8FakeOwnedCall {
    var executable: String = ""
    var args: Array<String> = Array<String>()
    init() {}
}

private class P8FakeOwnedCommandExecutor <: CkbP8OwnedCommandExecutor {
    let calls = ArrayList<P8FakeOwnedCall>()
    let launches = ArrayList<P8FakeOwnedCall>()
    let results = ArrayList<CkbP8OwnedCommandResult>()
    var process: ?CkbP8OwnedProcessHandle = None
    var cleanupFails: Bool = false
    var cleanupCalls: Int64 = 0
    public init() {}
    public func executeDocker(executable: String, args: Array<String>,
        timeoutMillis: Int64): CkbP8OwnedCommandResult {
        let call = P8FakeOwnedCall(); call.executable = executable
        call.args = args; this.calls.add(call)
        if (args.size > 0 && (args[0] == "rm" || args[0] == "network" &&
            args.size > 1 && args[1] == "rm")) {
            this.cleanupCalls += 1
            if (this.cleanupFails) { return p8CommandFailed("cleanup_failed") }
        }
        if (this.results.size == 0) { return p8CommandOk("") }
        this.results.remove(at: 0)
    }
    public func launchCkb(executable: String, args: Array<String>,
        timeoutMillis: Int64): (?CkbP8OwnedProcessHandle, String) {
        let call = P8FakeOwnedCall(); call.executable = executable
        call.args = args; this.launches.add(call)
        (this.process, if (this.process.isSome()) { "ok" }
            else { "p8_ckb_launch_failed" })
    }
}

private class P8FakeOwnedProcess <: CkbP8OwnedProcessHandle {
    var stopCalls: Int64 = 0
    var stopFailures: Int64 = 0
    var running: Bool = true
    public init() {}
    public func pid(): Int64 { 1234 }
    public func stop(): Bool {
        this.stopCalls += 1
        if (this.stopFailures > 0) { this.stopFailures -= 1; return false }
        this.running = false; true
    }
    public func alive(): Bool { this.running }
}

private class P8FakeOwnedReadinessProbe <: CkbP8OwnedReadinessProbe {
    let responses = ArrayList<CkbP8OwnedReadinessResponse>()
    public init() {}
    public func get(url: String, timeoutMillis: Int64,
        maxBytes: Int64): CkbP8OwnedReadinessResponse {
        if (this.responses.size == 0) { return p8ReadyUnavailable() }
        this.responses.remove(at: 0)
    }
}

private func p8LifecycleFixture(label: String): P8LifecycleFixture {
    let out = P8LifecycleFixture()
    let suffix = DateTime.now().toUnixTimeStamp().toString()
    out.root = "/tmp/p8-owned-${label}-${suffix}"
    if (exists(Path(out.root))) { remove(Path(out.root), recursive: true) }
    Directory.create(Path(out.root), recursive: true)
    out.options.workRoot = "${out.root}/work"
    out.options.runtimeRoot = "${out.root}/runtime"
    out.options.qdrantRoot = "${out.root}/qdrant"
    Directory.create(Path(out.options.runtimeRoot), recursive: true)
    let executable = canonicalize(Path("/usr/bin/true")).toString()
    out.authority.ckbExecutable = executable
    out.authority.ckbExecutableSha256 = p8TestFileHash(executable)
    out.authority.dockerExecutable = executable
    out.authority.dockerExecutableSha256 = p8TestFileHash(executable)
    out.authority.qdrantEndpoint = "http://127.0.0.1:6333"
    out.authority.restEndpoint =
        "http://127.0.0.1:18081/v1/cangjie/syntax-query"
    out.authority.mcpHttpEndpoint = "http://127.0.0.1:18081/mcp"
    out.authority.qdrantImageReference = "qdrant/qdrant@sha256:" +
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    out.authority.qdrantImageId = "sha256:" +
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    out.authority.timeoutMillis = 10000
    out.qdrant.collection = "ckb_active_test"
    out.qdrant.dimension = 1024
    out
}

private func p8QueueQdrantSuccess(commands: P8FakeOwnedCommandExecutor,
    fixture: P8LifecycleFixture): Unit {
    commands.results.add(p8CommandOk(fixture.authority.qdrantImageId))
    commands.results.add(p8CommandOk("network-id"))
    commands.results.add(p8CommandOk(p8ContainerId()))
    commands.results.add(p8CommandOk(fixture.authority.qdrantImageId))
}

private func p8CommandOk(text: String): CkbP8OwnedCommandResult {
    let out = CkbP8OwnedCommandResult(); out.exitCode = 0
    out.diagnostic = "ok"; out.stdoutBytes = text.toArray(); out
}

private func p8CommandFailed(code: String): CkbP8OwnedCommandResult {
    let out = CkbP8OwnedCommandResult(); out.diagnostic = code; out
}

private func p8Ready(status: Int64,
    bytes: Array<UInt8>): CkbP8OwnedReadinessResponse {
    let out = CkbP8OwnedReadinessResponse(); out.statusCode = status
    out.bodyBytes = bytes; out.diagnostic = "ok"; out
}

private func p8ReadyUnavailable(): CkbP8OwnedReadinessResponse {
    let out = CkbP8OwnedReadinessResponse()
    out.diagnostic = "connection_failed"; out
}

private func p8ContainerId(): String {
    "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
}

private func p8TestFileHash(path: String): String {
    let digest = SHA256(); digest.write(File.readFrom(Path(path)))
    let out = StringBuilder(); let digits = "0123456789abcdef".toRuneArray()
    for (byte in digest.finish()) {
        out.append(digits[Int64(byte / UInt8(16))])
        out.append(digits[Int64(byte % UInt8(16))])
    }
    "sha256:${out.toString()}"
}

private func p8RemoveFixture(root: String): Unit {
    if (exists(Path(root))) { remove(Path(root), recursive: true) }
}
