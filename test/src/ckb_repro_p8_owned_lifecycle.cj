package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashMap}
import std.fs.{Directory, File, Path, exists, remove}
import std.io.InputStream
import std.process.*
import std.sync.*
import std.time.*

public class CkbP8OwnedCommandResult {
    public var exitCode: Int64 = 127
    public var diagnostic: String = "process_not_run"
    public var stdoutBytes: Array<UInt8> = Array<UInt8>()
    public var stderrBytes: Array<UInt8> = Array<UInt8>()
    public init() {}
}

public interface CkbP8OwnedProcessHandle {
    func pid(): Int64
    func stop(): Bool
    func alive(): Bool
}

// Environment is intentionally absent from this interface. Production
// implementations always launch the frozen executables with an empty map.
public interface CkbP8OwnedCommandExecutor {
    func executeDocker(executable: String, args: Array<String>,
        timeoutMillis: Int64): CkbP8OwnedCommandResult
    func launchCkb(executable: String, args: Array<String>,
        timeoutMillis: Int64): (?CkbP8OwnedProcessHandle, String)
}

public class CkbP8OwnedReadinessResponse {
    public var statusCode: Int64 = 0
    public var bodyBytes: Array<UInt8> = Array<UInt8>()
    public var diagnostic: String = "not_started"
    public init() {}
}

public interface CkbP8OwnedReadinessProbe {
    func get(url: String, timeoutMillis: Int64,
        maxBytes: Int64): CkbP8OwnedReadinessResponse
}

public interface CkbP8OwnedLocalLifecycle {
    func startQdrant(options: CkbReproVerifyOptions): CkbReproContractResult
    func startParityService(runtimeRoot: String,
        expectedKnowledgeVersion: String): CkbReproContractResult
    func stopParityService(): Bool
    func conflictingProcessCount(): Int64
    func ownedConfigPath(): String
    func cleanup(options: CkbReproVerifyOptions): Bool
}

public class CkbNativeP8OwnedCommandExecutor <: CkbP8OwnedCommandExecutor {
    public init() {}
    public func executeDocker(executable: String, args: Array<String>,
        timeoutMillis: Int64): CkbP8OwnedCommandResult {
        let out = CkbP8OwnedCommandResult()
        try {
            let process = launch(executable, args,
                environment: HashMap<String, String>(),
                stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
            let stdout = spawn { => p8OwnedReadPipe(
                process.stdOutPipe, 65536) }
            let stderr = spawn { => p8OwnedReadPipe(
                process.stdErrPipe, 65536) }
            try {
                out.exitCode = process.wait(timeout:
                    Duration.millisecond * timeoutMillis)
            } catch (_: Exception) {
                out.diagnostic = "p8_owned_process_timeout"
                try { process.terminate(force: true) } catch (_: Exception) {}
                try { _ = process.wait(timeout: Duration.second) }
                catch (_: Exception) {}
            }
            let stdoutRead = try { stdout.get(Duration.second) }
                catch (_: Exception) { ("read_failed", Array<UInt8>()) }
            let stderrRead = try { stderr.get(Duration.second) }
                catch (_: Exception) { ("read_failed", Array<UInt8>()) }
            out.stdoutBytes = stdoutRead[1]; out.stderrBytes = stderrRead[1]
            if (out.diagnostic == "process_not_run") {
                out.diagnostic = if (stdoutRead[0] == "ok" &&
                    stderrRead[0] == "ok") { "ok" }
                    else { "p8_owned_process_output_invalid" }
            }
        } catch (_: Exception) {
            out.diagnostic = "p8_owned_process_launch_failed"
        }
        out
    }

    public func launchCkb(executable: String, args: Array<String>,
        timeoutMillis: Int64): (?CkbP8OwnedProcessHandle, String) {
        try {
            let process = launch(executable, args,
                environment: HashMap<String, String>(),
                stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
            (Some<CkbP8OwnedProcessHandle>(
                CkbNativeP8OwnedProcessHandle(process)), "ok")
        } catch (_: Exception) {
            (None<CkbP8OwnedProcessHandle>, "p8_ckb_launch_failed")
        }
    }
}

public class CkbNativeP8OwnedReadinessProbe <: CkbP8OwnedReadinessProbe {
    public init() {}
    public func get(url: String, timeoutMillis: Int64,
        maxBytes: Int64): CkbP8OwnedReadinessResponse {
        let out = CkbP8OwnedReadinessResponse()
        let config = CkbNativeHttpTransportConfig("", false, "", false,
            true, "", timeoutMillis)
        let request = HttpExecutionRequest(); request.method = "GET"
        request.url = url; request.retryCount = 0
        request.timeoutMillis = timeoutMillis; request.maxResponseBytes = maxBytes
        let response = NativeHttpRequestExecutor(config).execute(request)
        out.statusCode = response.statusCode
        out.bodyBytes = response.body.toArray()
        out.diagnostic = if (response.transportErrorClass == "") { "ok" }
            else { "connection_failed" }
        out
    }
}

public class CkbNativeP8OwnedLocalLifecycle <: CkbP8OwnedLocalLifecycle {
    private let authority: CkbP8OwnedLocalRuntimeAuthority
    private let qdrant: CkbQdrantSnapshotManifest
    private let commandExecutor: CkbP8OwnedCommandExecutor
    private let readinessProbe: CkbP8OwnedReadinessProbe
    private var containerId: String = ""
    private var networkName: String = ""
    private var configPath: String = ""
    private var workRoot: String = ""
    private var qdrantRoot: String = ""
    private var service: ?CkbP8OwnedProcessHandle = None

    public init(authority: CkbP8OwnedLocalRuntimeAuthority,
        qdrant: CkbQdrantSnapshotManifest,
        commandExecutor!: CkbP8OwnedCommandExecutor =
            CkbNativeP8OwnedCommandExecutor(),
        readinessProbe!: CkbP8OwnedReadinessProbe =
            CkbNativeP8OwnedReadinessProbe()) {
        this.authority = authority; this.qdrant = qdrant
        this.commandExecutor = commandExecutor
        this.readinessProbe = readinessProbe
    }

    public func startQdrant(
        options: CkbReproVerifyOptions): CkbReproContractResult {
        if (this.containerId != "" || this.networkName != "" ||
            exists(Path(options.workRoot)) || exists(Path(options.qdrantRoot)) ||
            !validateCkbP8DockerExecutableIdentity(this.authority).ok ||
            this.endpointOccupied(this.authority.qdrantEndpoint + "/readyz")) {
            return p8OwnedFailure("p8_qdrant_start_precondition_failed")
        }
        this.workRoot = options.workRoot; this.qdrantRoot = options.qdrantRoot
        let identity = p8OwnedIdentity(options.workRoot,
            this.authority.qdrantImageId)
        this.networkName = "ckb-p8-net-${identity}"
        let containerName = "ckb-p8-qdrant-${identity}"
        let result = try { this.startQdrantCore(
            identity, containerName) } catch (_: Exception) {
                p8OwnedFailure("p8_qdrant_start_failed")
            }
        if (!result.ok) { _ = this.cleanup(options) }
        result
    }

    private func startQdrantCore(identity: String,
        containerName: String): CkbReproContractResult {
        let inspected = this.docker(["image", "inspect",
                "--format={{.Id}}", this.authority.qdrantImageReference])
        let imageId = p8OwnedAsciiLine(inspected.stdoutBytes)
        if (imageId[0] == "invalid_response_encoding") {
            return p8OwnedFailure("invalid_response_encoding")
        }
        if (inspected.exitCode != 0 || inspected.diagnostic != "ok" ||
            imageId[0] != "ok" || imageId[1] != this.authority.qdrantImageId) {
            return p8OwnedFailure("p8_qdrant_image_identity_mismatch")
        }
        Directory.create(Path(this.workRoot), recursive: false)
        Directory.create(Path(this.qdrantRoot), recursive: false)
        let network = this.docker(["network", "create", "--internal",
                "--label", "ckb.repro.p8.owner=${identity}", this.networkName])
        if (network.exitCode != 0 || network.diagnostic != "ok") {
            return p8OwnedFailure("p8_qdrant_network_create_failed")
        }
        let port = p8OwnedEndpointPort(this.authority.qdrantEndpoint)
        if (port == "") {
            return p8OwnedFailure("p8_qdrant_endpoint_invalid")
        }
        let run = this.docker(["run", "--pull=never", "--rm", "-d",
                "--name", containerName, "--label",
                "ckb.repro.p8.owner=${identity}", "--network", this.networkName,
                "--publish", "127.0.0.1:${port}:6333", "--mount",
                "type=bind,source=${this.qdrantRoot},target=/qdrant/storage",
                this.authority.qdrantImageReference])
        let container = p8OwnedAsciiLine(run.stdoutBytes)
        if (container[0] == "invalid_response_encoding") {
            return p8OwnedFailure("invalid_response_encoding")
        }
        if (run.exitCode != 0 || run.diagnostic != "ok" ||
            container[0] != "ok" || !p8OwnedContainerId(container[1])) {
            return p8OwnedFailure("p8_qdrant_container_start_failed")
        }
        this.containerId = container[1]
        let actual = this.docker(["inspect", "--format={{.Image}}",
                this.containerId])
        let actualImage = p8OwnedAsciiLine(actual.stdoutBytes)
        if (actualImage[0] == "invalid_response_encoding") {
            return p8OwnedFailure("invalid_response_encoding")
        }
        if (actual.exitCode != 0 || actual.diagnostic != "ok" ||
            actualImage[0] != "ok" ||
            actualImage[1] != this.authority.qdrantImageId) {
            return p8OwnedFailure("p8_qdrant_container_identity_mismatch")
        }
        this.waitReady(this.authority.qdrantEndpoint + "/readyz", "", false)
    }

    public func startParityService(runtimeRoot: String,
        expectedKnowledgeVersion: String): CkbReproContractResult {
        if (this.service.isSome() || this.workRoot == "" ||
            !exists(Path(runtimeRoot)) || expectedKnowledgeVersion == "" ||
            !validateCkbP8BExecutableIdentity(this.authority).ok ||
            this.endpointOccupied(p8OwnedServiceHealthUrl(this.authority))) {
            return p8OwnedFailure("p8_ckb_service_start_precondition_failed")
        }
        this.configPath = Path(this.workRoot).join(
            "p8-owned-runtime.conf").toString()
        if (exists(Path(this.configPath))) {
            return p8OwnedFailure("p8_ckb_owned_config_exists")
        }
        let config = p8OwnedRuntimeConfig(this.authority, this.qdrant)
        try { File.writeTo(Path(this.configPath), config.toArray()) }
        catch (_: Exception) {
            return p8OwnedFailure("p8_ckb_owned_config_write_failed")
        }
        let launched = this.commandExecutor.launchCkb(
            this.authority.ckbExecutable,
            ["--config", this.configPath, "--store", runtimeRoot,
                "service-http"], this.authority.timeoutMillis)
        this.service = launched[0]
        if (launched[1] != "ok" || this.service.isNone()) {
            _ = this.stopParityService()
            return p8OwnedFailure("p8_ckb_service_launch_failed")
        }
        let ready = this.waitReady(p8OwnedServiceHealthUrl(this.authority),
            expectedKnowledgeVersion, true)
        if (!ready.ok) { _ = this.stopParityService() }
        ready
    }

    public func stopParityService(): Bool {
        match (this.service) {
            case Some(process) =>
                let stopped = process.stop()
                if (stopped) {
                    this.service = None<CkbP8OwnedProcessHandle>
                }
                stopped
            case None => true
        }
    }

    public func conflictingProcessCount(): Int64 {
        var count: Int64 = 0
        if (this.service.isNone() &&
            this.endpointOccupied(p8OwnedServiceHealthUrl(this.authority))) {
            count += 1
        }
        if (this.containerId == "" && this.endpointOccupied(
            this.authority.qdrantEndpoint + "/readyz")) { count += 1 }
        count
    }

    public func ownedConfigPath(): String { this.configPath }

    public func cleanup(options: CkbReproVerifyOptions): Bool {
        var ok = this.stopParityService()
        if (this.containerId != "") {
            let removed = this.docker(["rm", "-f", this.containerId])
            if (removed.exitCode != 0 || removed.diagnostic != "ok") {
                ok = false
            }
            this.containerId = ""
        }
        if (this.networkName != "") {
            let removed = this.docker(["network", "rm", this.networkName])
            if (removed.exitCode != 0 || removed.diagnostic != "ok") {
                ok = false
            }
            this.networkName = ""
        }
        for (root in [options.qdrantRoot, options.workRoot]) {
            if (exists(Path(root))) {
                try { remove(Path(root), recursive: true) }
                catch (_: Exception) { ok = false }
            }
        }
        this.configPath = ""; this.workRoot = ""; this.qdrantRoot = ""
        ok
    }

    private func docker(args: Array<String>): CkbP8OwnedCommandResult {
        if (!validateCkbP8DockerExecutableIdentity(this.authority).ok) {
            let out = CkbP8OwnedCommandResult()
            out.diagnostic = "p8_docker_executable_identity_invalid"; return out
        }
        this.commandExecutor.executeDocker(this.authority.dockerExecutable,
            args, this.authority.timeoutMillis)
    }

    private func endpointOccupied(url: String): Bool {
        let response = this.readinessProbe.get(url,
            if (this.authority.timeoutMillis < 1000) {
                this.authority.timeoutMillis
            } else { 1000 }, 4096)
        response.statusCode > 0
    }

    private func waitReady(url: String, expectedVersion: String,
        checkVersion: Bool): CkbReproContractResult {
        var attempts: Int64 = 0
        while (attempts < 50) {
            let response = this.readinessProbe.get(url,
                this.authority.timeoutMillis, 65536)
            if (response.statusCode >= 200 && response.statusCode < 300) {
                if (!checkVersion) { return p8OwnedSuccess() }
                let decoded = try { String.fromUtf8(response.bodyBytes) }
                    catch (_: Exception) {
                        return p8OwnedFailure("invalid_response_encoding")
                    }
                let marker = "\"activeKnowledgeVersion\":\"" +
                    expectedVersion + "\""
                if (decoded.contains(marker)) { return p8OwnedSuccess() }
                return p8OwnedFailure("p8_ckb_service_identity_mismatch")
            }
            attempts += 1
            if (attempts < 50) { sleep(Duration.millisecond * 20) }
        }
        p8OwnedFailure(if (checkVersion) { "p8_ckb_service_not_ready" }
            else { "p8_qdrant_not_ready" })
    }
}

public func buildCkbP8OwnedMcpStdioSpec(
    authority: CkbP8OwnedLocalRuntimeAuthority, configPath: String,
    runtimeRoot: String): (CkbReproContractResult, CkbMcpStdioCommandSpec) {
    let spec = CkbMcpStdioCommandSpec()
    if (configPath == "" || runtimeRoot == "" ||
        !validateCkbP8BExecutableIdentity(authority).ok) {
        return (p8OwnedFailure("p8_mcp_stdio_spec_invalid"), spec)
    }
    spec.schemaVersion = "ckb-mcp-stdio-command-v1"
    spec.executable = authority.ckbExecutable
    for (arg in ["--config", configPath, "--store", runtimeRoot,
        "mcp-stdio"]) { spec.args.add(arg) }
    spec.timeoutMillis = authority.timeoutMillis
    (p8OwnedSuccess(), spec)
}

private class CkbNativeP8OwnedProcessHandle <: CkbP8OwnedProcessHandle {
    private let process: SubProcess
    private let stdout: Future<Unit>
    private let stderr: Future<Unit>
    public init(process: SubProcess) {
        this.process = process
        this.stdout = spawn { => p8OwnedDrainPipe(process.stdOutPipe) }
        this.stderr = spawn { => p8OwnedDrainPipe(process.stdErrPipe) }
    }
    public func pid(): Int64 { this.process.pid }
    public func alive(): Bool { this.process.isAlive() }
    public func stop(): Bool {
        var ok = true
        if (this.process.isAlive()) {
            try { this.process.terminate(force: false) }
            catch (_: Exception) { ok = false }
            try { _ = this.process.wait(timeout: Duration.second) }
            catch (_: Exception) {
                try { this.process.terminate(force: true) }
                catch (_: Exception) { ok = false }
                try { _ = this.process.wait(timeout: Duration.second) }
                catch (_: Exception) { ok = false }
            }
        }
        try { this.stdout.get(Duration.second) } catch (_: Exception) { ok = false }
        try { this.stderr.get(Duration.second) } catch (_: Exception) { ok = false }
        ok && !this.process.isAlive()
    }
}

private func p8OwnedRuntimeConfig(authority: CkbP8OwnedLocalRuntimeAuthority,
    qdrant: CkbQdrantSnapshotManifest): String {
    let port = p8OwnedEndpointPort(authority.restEndpoint)
    "network.enabled=false\n" +
        "network.envProxyEnabled=false\n" +
        "network.allowPrivateNetwork=true\n" +
        "network.allowedHosts=127.0.0.1\n" +
        "network.retryCount=0\n" +
        "website.enabled=false\n" +
        "docs.enabled=false\n" +
        "sourceAnalysis.enabled=false\n" +
        "firstInit.enabled=false\n" +
        "scheduler.enabled=false\n" +
        "vector.backend=qdrant\n" +
        "vector.activeCollection=${qdrant.collection}\n" +
        "vector.candidateCollection=ckb_p8_unused_candidate\n" +
        "vector.endpoint=${authority.qdrantEndpoint}\n" +
        "vector.dimensions=${qdrant.dimension}\n" +
        "vector.distance=Cosine\n" +
        "vector.timeoutMillis=${authority.timeoutMillis}\n" +
        "vector.retryCount=0\n" +
        "vector.allowPrivateEndpoint=true\n" +
        "service.bind=127.0.0.1\n" +
        "service.port=${port}\n" +
        "service.readOnlyPublic=true\n"
}

private func p8OwnedServiceHealthUrl(
    authority: CkbP8OwnedLocalRuntimeAuthority): String {
    let rest = authority.restEndpoint[7..]
    let slash = rest.indexOf("/").getOrThrow()
    "http://" + rest[..slash] + "/v1/health"
}

private func p8OwnedEndpointPort(value: String): String {
    if (!value.startsWith("http://")) { return "" }
    let authority = value[7..].split("/")[0]
    let colon = authority.lastIndexOf(":").getOrThrow()
    authority[colon + 1..]
}

private func p8OwnedIdentity(workRoot: String, imageId: String): String {
    let hash = benchmarkGapSha256("${workRoot}|${imageId}")
    hash[0..16]
}

private func p8OwnedAsciiLine(bytes: Array<UInt8>): (String, String) {
    if (bytes.size == 0 || bytes.size > 4096) { return ("invalid", "") }
    let text = try { String.fromUtf8(bytes) }
        catch (_: Exception) { return ("invalid_response_encoding", "") }
    for (rune in text.runes()) {
        if (rune > r'\u{007f}' || (rune < r'\u{0020}' && rune != r'\n' &&
            rune != r'\r' && rune != r'\t')) { return ("invalid", "") }
    }
    let trimmed = text.trimAscii()
    if (trimmed == "" || trimmed.contains("\n") || trimmed.contains("\r")) {
        return ("invalid", "")
    }
    ("ok", trimmed)
}

private func p8OwnedContainerId(value: String): Bool {
    if (value.size != 64) { return false }
    for (rune in value.runes()) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) { return false }
    }
    true
}

private func p8OwnedReadPipe(pipe: InputStream,
    maxBytes: Int64): (String, Array<UInt8>) {
    let bytes = ArrayList<UInt8>(); let buffer = Array<UInt8>(8192,
        repeat: UInt8(0)); var oversized = false
    while (true) {
        let count = pipe.read(buffer)
        if (count < 0 || count > buffer.size) {
            return ("read_failed", Array<UInt8>())
        }
        if (count == 0) { break }
        for (i in 0..count) {
            if (bytes.size < maxBytes) { bytes.add(buffer[i]) }
            else { oversized = true }
        }
    }
    (if (oversized) { "too_large" } else { "ok" }, bytes.toArray())
}

private func p8OwnedDrainPipe(pipe: InputStream): Unit {
    let buffer = Array<UInt8>(8192, repeat: UInt8(0))
    while (true) {
        let count = try { pipe.read(buffer) } catch (_: Exception) { return }
        if (count <= 0 || count > buffer.size) { return }
    }
}

private func p8OwnedSuccess(): CkbReproContractResult {
    let out = CkbReproContractResult(); out.ok = true
    out.diagnostic = "ok"; out
}

private func p8OwnedFailure(code: String): CkbReproContractResult {
    let out = CkbReproContractResult(); out.diagnostic = code; out
}
