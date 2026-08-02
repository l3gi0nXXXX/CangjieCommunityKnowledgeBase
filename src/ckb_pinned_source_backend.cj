package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashMap}
import std.fs.{Directory, File, OpenMode, Path, canonicalize, exists, remove}
import std.sort.*
import stdx.crypto.digest.SHA256

public interface CkbPinnedSourceCommandExecutor {
    func run(command: String, args: Array<String>, workRoot: String):
        (Int64, String, String)
}

public class CkbNativePinnedSourceCommandExecutor <:
    CkbPinnedSourceCommandExecutor {
    public func run(command: String, args: Array<String>, workRoot: String):
        (Int64, String, String) {
        ckbPinnedRunCommand(command, args, workRoot, 120000)
    }
}

private class CkbPinnedSourceFileHandle <:
    CkbReproSourceMaterialReadHandle {
    private let fd: Int32
    private let expectedIdentity: String
    private let openedIdentity: String
    private var eof: Bool = false
    private var closed: Bool = false
    public init(path: String, expectedIdentity: String) {
        let cpath = unsafe { LibC.mallocCString(path) }
        this.fd = unsafe { open(cpath, 0x104) }
        unsafe { LibC.free(cpath) }
        this.expectedIdentity = expectedIdentity
        this.openedIdentity = if (this.fd >= 0) {
            ckbPinnedDescriptorIdentity(this.fd)
        } else { "" }
    }
    public func read(maxBytes: Int64): Array<UInt8> {
        if (this.closed || this.fd < 0 || maxBytes < 1 || maxBytes > 65536) {
            throw Exception("pinned_source_read_invalid")
        }
        let buffer = Array<UInt8>(maxBytes, repeat: UInt8(0))
        let count = unsafe {
            let pointer = acquireArrayRawData(buffer)
            let value = read(this.fd, pointer.pointer, UIntNative(buffer.size))
            releaseArrayRawData(pointer); Int64(value)
        }
        if (count < 0 || count > buffer.size) {
            throw Exception("pinned_source_read_failed")
        }
        if (count == 0) { this.eof = true; return Array<UInt8>() }
        if (count == buffer.size) { buffer } else { buffer[0..count].clone() }
    }
    public func noFollow(): Bool {
        this.fd >= 0 && this.openedIdentity != ""
    }
    public func identity(): String {
        if (this.noFollow()) { this.expectedIdentity } else { "" }
    }
    public func observedIdentity(): String {
        if (!this.eof || this.closed || this.fd < 0 ||
            ckbPinnedDescriptorIdentity(this.fd) != this.openedIdentity) {
            ""
        } else { this.expectedIdentity }
    }
    public func close(): Unit {
        if (!this.closed && this.fd >= 0) { unsafe { close(this.fd) }; () }
        this.closed = true
    }
}

public class CkbPinnedSourceMaterialBackend <:
    CkbReproMaterializingSourceBackend {
    private let cacheRoot: String
    private let command: CkbPinnedSourceCommandExecutor
    private let lockValid: Bool
    private let sources = HashMap<String, CkbReproSourceLockEntry>()
    private let paths = HashMap<String, String>()
    private let repositories = HashMap<String, String>()
    public init(lock: CkbReproSourceLock, cacheRoot: String,
        command!: CkbPinnedSourceCommandExecutor =
            CkbNativePinnedSourceCommandExecutor()) {
        this.cacheRoot = cacheRoot; this.command = command
        this.lockValid = validateCkbReproBuildLocks(lock).ok
        for (entry in lock.entries) { this.sources[entry.sourceId] = entry }
    }
    public func fetch(entry: CkbReproSourceMaterialEntry): CkbReproBackendResult {
        let source = ckbPinnedSourceForMaterial(entry, this.sources)
        if (!this.lockValid || source[0] != "ok" ||
            source[1].sourceType != "external_git") {
            return CkbReproBackendResult(false, "")
        }
        if (!ckbPinnedPrepareRoot(this.cacheRoot)) {
            return CkbReproBackendResult(false, "")
        }
        let repositoryKey = benchmarkGapSha256("ckb-git-checkout-v1|" +
            source[1].repository + "|" + source[1].commit + "|" +
            source[1].tree)
        let repositoryRoot = Path(this.cacheRoot).join(
            repositoryKey.replace("sha256:", ""))
        if (!this.repositories.contains(repositoryKey)) {
            if (!ckbPinnedAcquireRepository(this.command, repositoryRoot.toString(),
                source[1])) { return CkbReproBackendResult(false, "") }
        }
        let target = repositoryRoot.join(source[1].path)
        let canonical = try { canonicalize(target).toString() }
            catch (_: Exception) { "" }
        if (canonical != target.toString() ||
            ckbPinnedFileHash(target.toString()) != source[1].fileHash) {
            _ = ckbPinnedAcquisitionFailure(repositoryRoot.toString())
            return CkbReproBackendResult(false, "")
        }
        this.repositories[repositoryKey] = repositoryRoot.toString()
        this.paths[entry.sourceId] = target.toString()
        CkbReproBackendResult(true, entry.expectedHash)
    }
    public func generate(entry: CkbReproSourceMaterialEntry): CkbReproBackendResult {
        let source = ckbPinnedSourceForMaterial(entry, this.sources)
        if (!this.lockValid || source[0] != "ok" ||
            source[1].sourceType != "generated" ||
            source[1].generatorId != "ckb-hash-manifest-v1" ||
            source[1].generatorVersion != "1" ||
            source[1].generatorSourceHash != benchmarkGapSha256(
                "ckb-hash-manifest-v1|1|sorted-input-hashes")) {
            return CkbReproBackendResult(false, "")
        }
        if (!ckbPinnedPrepareRoot(this.cacheRoot)) {
            return CkbReproBackendResult(false, "")
        }
        let inputs = source[1].inputHashes.toArray(); sort(inputs)
        var text = "# CKB pinned input hashes\n"
        for (hash in inputs) { text += "${hash}\n" }
        if (benchmarkGapSha256(text) != source[1].outputHash) {
            return CkbReproBackendResult(false, "")
        }
        let generatedRoot = Path(this.cacheRoot).join("generated")
        if (!exists(generatedRoot)) {
            try { Directory.create(generatedRoot, recursive: false) }
            catch (_: Exception) { return CkbReproBackendResult(false, "") }
        }
        let target = generatedRoot.join(
            canonicalCkbReproSourceLockEntryHash(source[1])
                .replace("sha256:", ""))
        if (exists(target)) { return CkbReproBackendResult(false, "") }
        try { File.writeTo(target, text.toArray()) }
        catch (_: Exception) { return CkbReproBackendResult(false, "") }
        this.paths[entry.sourceId] = target.toString()
        CkbReproBackendResult(true, entry.expectedHash)
    }
    public func open(entry: CkbReproSourceMaterialEntry):
        CkbReproSourceMaterialReadHandle {
        let path = match (this.paths.get(entry.sourceId)) {
            case Some(value) => value
            case None => throw Exception("pinned_source_not_acquired")
        }
        CkbPinnedSourceFileHandle(path, entry.canonicalIdentity)
    }
}

private func ckbPinnedAcquireRepository(command: CkbPinnedSourceCommandExecutor,
    root: String, source: CkbReproSourceLockEntry): Bool {
    if (exists(Path(root)) || !ckbPinnedAnonymousHttps(source.repository)) {
        return false
    }
    let workRoot = Path(root).parent.toString()
    let initResult = command.run("git", ckbPinnedGitArgs(["init", root]), workRoot)
    if (initResult[0] != 0 || initResult[1] != "ok") {
        return ckbPinnedAcquisitionFailure(root)
    }
    let remote = command.run("git", ckbPinnedGitArgs(["-C", root, "remote", "add",
        "origin", source.repository]), workRoot)
    if (remote[0] != 0 || remote[1] != "ok") {
        return ckbPinnedAcquisitionFailure(root)
    }
    let fetch = command.run("git", ckbPinnedGitArgs(["-C", root, "fetch",
        "--depth=1", "--no-tags", "origin", source.commit]), workRoot)
    if (fetch[0] != 0 || fetch[1] != "ok") {
        return ckbPinnedAcquisitionFailure(root)
    }
    let fetched = command.run("git", ckbPinnedGitArgs(["-C", root, "rev-parse",
        "--verify", "FETCH_HEAD^{commit}"]), workRoot)
    if (fetched[0] != 0 || fetched[1] != "ok" ||
        fetched[2].toAsciiLower() != source.commit) {
        return ckbPinnedAcquisitionFailure(root)
    }
    let commit = command.run("git", ckbPinnedGitArgs(["-C", root, "rev-parse",
        "--verify", "${source.commit}^{commit}"]), workRoot)
    if (commit[0] != 0 || commit[1] != "ok" ||
        commit[2].toAsciiLower() != source.commit) {
        return ckbPinnedAcquisitionFailure(root)
    }
    let tree = command.run("git", ckbPinnedGitArgs(["-C", root, "rev-parse",
        "--verify", "${source.commit}^{tree}"]), workRoot)
    if (tree[0] != 0 || tree[1] != "ok" ||
        benchmarkGapSha256("ckb-git-tree-v1|" +
            tree[2].toAsciiLower()) != source.tree) {
        return ckbPinnedAcquisitionFailure(root)
    }
    let checkout = command.run("git", ckbPinnedGitArgs(["-C", root, "checkout",
        "--detach", source.commit]), workRoot)
    if (checkout[0] != 0 || checkout[1] != "ok") {
        return ckbPinnedAcquisitionFailure(root)
    }
    true
}

private func ckbPinnedAnonymousHttps(repository: String): Bool {
    for (rune in repository.runes()) {
        if (rune < r'!' || rune > r'~') { return false }
    }
    if (!repository.startsWith("https://") || repository.contains("@") ||
        repository.contains("?") || repository.contains("#") ||
        repository.contains("\\")) { return false }
    let scheme = repository.split("://")
    if (scheme.size != 2 || scheme[0] != "https") { return false }
    let tail = scheme[1]
    let parts = tail.split("/")
    if (parts.size < 2) { return false }
    let host = parts[0].toAsciiLower()
    if (host == "" || host == "localhost" || host.startsWith("127.") ||
        host == "0.0.0.0" || host.contains(":") || host.contains("[") ||
        parts[parts.size - 1] == "") { return false }
    for (i in 1..parts.size) {
        if (parts[i] == "" || parts[i] == "." || parts[i] == "..") {
            return false
        }
    }
    true
}

private func ckbPinnedAcquisitionFailure(root: String): Bool {
    if (exists(Path(root))) {
        try { remove(Path(root), recursive: true) } catch (_: Exception) { () }
    }
    false
}

private func ckbPinnedGitArgs(extra: Array<String>): Array<String> {
    let values = ArrayList<String>()
    values.add(all: ["-c", "credential.helper=", "-c", "core.askPass=false",
        "-c", "credential.interactive=never"])
    values.add(all: extra); values.toArray()
}

public func ckbPinnedRunCommand(command: String, args: Array<String>,
    workRoot: String, timeoutMillis: Int64): (Int64, String, String) {
    if (command == "" || args.size == 0 || timeoutMillis < 1000 ||
        timeoutMillis > 300000 || !exists(Path(workRoot))) {
        return (127, "pinned_source_command_invalid", "")
    }
    let id = benchmarkGapSha256(command + "|" + args.toString())
        .replace("sha256:", "")
    let stdout = Path(workRoot).join(".${id}.stdout")
    let stderr = Path(workRoot).join(".${id}.stderr")
    let marker = Path(workRoot).join(".${id}.timeout")
    let pid = Path(workRoot).join(".${id}.pid")
    let environment = ArrayList<CkbTimedWorkerProcessEnvironment>()
    environment.add(CkbTimedWorkerProcessEnvironment(
        "GIT_TERMINAL_PROMPT", "0"))
    environment.add(CkbTimedWorkerProcessEnvironment(
        "GIT_CONFIG_NOSYSTEM", "1"))
    environment.add(CkbTimedWorkerProcessEnvironment(
        "GIT_CONFIG_GLOBAL", "/dev/null"))
    environment.add(CkbTimedWorkerProcessEnvironment(
        "GIT_ASKPASS", "/usr/bin/false"))
    environment.add(CkbTimedWorkerProcessEnvironment(
        "SSH_ASKPASS", "/usr/bin/false"))
    environment.add(CkbTimedWorkerProcessEnvironment(
        "GIT_SSH_COMMAND", "false"))
    let home = Path(workRoot).join(".git-home")
    if (!exists(home)) {
        try { Directory.create(home, recursive: false) }
        catch (_: Exception) { return (127, "pinned_source_home_failed", "") }
    }
    environment.add(CkbTimedWorkerProcessEnvironment("HOME", home.toString()))
    environment.add(CkbTimedWorkerProcessEnvironment(
        "XDG_CONFIG_HOME", home.toString()))
    let values = ArrayList<String>(); values.add(all: args)
    let result = CkbTimedWorkerProcessLauncher(command, values,
        environment: environment, workdir: workRoot,
        cutoffAtMillis: ckbCoreNowMillis() + timeoutMillis,
        pidPath: pid.toString(), timeoutMarkerPath: marker.toString(),
        stdoutPath: stdout.toString(), stderrPath: stderr.toString()).run()
    let output = if (!result.timedOut && exists(stdout)) {
        try {
            let bytes = File.readFrom(stdout)
            if (bytes.size > 65536) { "" } else {
                String.fromUtf8(bytes).trimAscii()
            }
        } catch (_: Exception) { "" }
    } else { "" }
    for (path in [stdout, stderr, marker, pid]) {
        if (exists(path)) { try { remove(path) } catch (_: Exception) { () } }
    }
    if (result.timedOut) { (124, "pinned_source_command_timeout", "") }
    else if (result.exitCode != 0) {
        (result.exitCode, "pinned_source_command_failed", "")
    } else { (0, "ok", output) }
}

private func ckbPinnedSourceForMaterial(entry: CkbReproSourceMaterialEntry,
    sources: HashMap<String, CkbReproSourceLockEntry>):
    (String, CkbReproSourceLockEntry) {
    let source = match (sources.get(entry.sourceId)) {
        case Some(value) => value
        case None => return ("pinned_source_missing", CkbReproSourceLockEntry())
    }
    let expected = if (source.sourceType == "external_git") {
        source.fileHash
    } else { source.outputHash }
    let relative = if (source.sourceType == "external_git") {
        source.path
    } else { source.outputPath }
    if (entry.expectedHash != expected || entry.relativePath != relative) {
        return ("pinned_source_material_mismatch", CkbReproSourceLockEntry())
    }
    ("ok", source)
}

private func ckbPinnedPrepareRoot(root: String): Bool {
    if (root == "" || !Path(root).isAbsolute()) { return false }
    if (exists(Path(root))) {
        return try { canonicalize(Path(root)).toString() == root }
            catch (_: Exception) { false }
    }
    let parent = try { canonicalize(Path(root).parent).toString() }
        catch (_: Exception) { return false }
    if (Path(parent).join(Path(root).fileName).toString() != root) { return false }
    try { Directory.create(Path(root), recursive: false); true }
    catch (_: Exception) { false }
}

private func ckbPinnedFileHash(path: String): String {
    let digest = SHA256()
    try {
        try (file = File(Path(path), OpenMode.Read)) {
            let buffer = Array<UInt8>(65536, repeat: UInt8(0))
            while (true) {
                let count = file.read(buffer)
                if (count < 0 || count > buffer.size) { return "" }
                if (count == 0) { break }
                digest.write(if (count == buffer.size) { buffer }
                    else { buffer[0..count].clone() })
            }
        }
    } catch (_: Exception) { return "" }
    let out = StringBuilder()
    let digits = "0123456789abcdef".toRuneArray()
    for (byte in digest.finish()) {
        out.append(digits[Int64(byte / UInt8(16))])
        out.append(digits[Int64(byte % UInt8(16))])
    }
    "sha256:${out.toString()}"
}

private func ckbPinnedDescriptorIdentity(fd: Int32): String {
    let stat = Array<UInt8>(144, repeat: UInt8(0))
    let ok = unsafe {
        let pointer = acquireArrayRawData(stat)
        let value = fstat(fd, pointer.pointer)
        releaseArrayRawData(pointer); value == 0
    }
    if (!ok || (ckbPinnedLittleEndian(stat, 4, 2) & UInt64(0xf000)) !=
        UInt64(0x8000) || ckbPinnedLittleEndian(stat, 6, 2) != UInt64(1)) {
        return ""
    }
    "dev=${ckbPinnedLittleEndian(stat, 0, 4)};" +
        "ino=${ckbPinnedLittleEndian(stat, 8, 8)};" +
        "size=${ckbPinnedLittleEndian(stat, 96, 8)};" +
        "mtime=${ckbPinnedLittleEndian(stat, 48, 8)}:" +
        "${ckbPinnedLittleEndian(stat, 56, 8)};" +
        "ctime=${ckbPinnedLittleEndian(stat, 64, 8)}:" +
        "${ckbPinnedLittleEndian(stat, 72, 8)}"
}

private func ckbPinnedLittleEndian(bytes: Array<UInt8>, offset: Int64,
    count: Int64): UInt64 {
    var value: UInt64 = 0
    for (i in 0..count) {
        value |= UInt64(bytes[offset + i]) << UInt64(i * 8)
    }
    value
}
