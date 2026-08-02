package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists, remove}
import std.process.*
import std.sort.*
import std.unittest.*
import std.unittest.testmacro.*

private class P8PinnedGitCommand <: CkbPinnedSourceCommandExecutor {
    public let calls = ArrayList<Array<String>>()
    public var content: Array<UInt8> = "# 仓颉🙂\nRune 文档\n".toArray()
    public var commit: String = "0123456789012345678901234567890123456789"
    public var treeOid: String = "abcdefabcdefabcdefabcdefabcdefabcdefabcd"
    public var failAt: Int64 = -1
    public func run(command: String, args: Array<String>, workRoot: String):
        (Int64, String, String) {
        this.calls.add(args)
        if (this.failAt == this.calls.size) {
            return (1, "pinned_source_command_failed", "")
        }
        if (args.contains("init")) {
            let root = Path(args[args.size - 1]); Directory.create(root, recursive: true)
            Directory.create(root.join("docs"), recursive: true)
            File.writeTo(root.join("docs/a.md"), this.content)
            File.writeTo(root.join("docs/b.md"), this.content)
        }
        if (args.contains("FETCH_HEAD^{commit}") ||
            args.contains("${this.commit}^{commit}")) {
            return (0, "ok", this.commit)
        }
        if (args.contains("${this.commit}^{tree}")) {
            return (0, "ok", this.treeOid)
        }
        (0, "ok", "")
    }
}

private func p8PinnedRoot(name: String): String {
    let root = "/private/tmp/ckb-pinned-source-${name}"
    if (exists(Path(root))) { remove(Path(root), recursive: true) }
    root
}

private func p8PinnedExternalLock(content: Array<UInt8>, treeOid: String):
    CkbReproSourceLock {
    let lock = CkbReproSourceLock(); let entry = CkbReproSourceLockEntry()
    entry.sourceId = "docs/a"; entry.sourceType = "external_git"
    entry.repository = "https://example.invalid/community/docs.git"
    entry.commit = "0123456789012345678901234567890123456789"
    entry.tree = benchmarkGapSha256("ckb-git-tree-v1|" + treeOid)
    entry.path = "docs/a.md"; entry.fileHash = ckbQdrantSnapshotBytesHash(content)
    entry.license = "Apache-2.0"; entry.authMode = "anonymous"
    entry.assemblyRole = "community_docs"
    entry.outputKind = CangjieTypedRecordKinds.DOC_SECTION
    lock.entries.add(entry); lock
}

private func p8PinnedGeneratedLock(generatorId: String): CkbReproSourceLock {
    let lock = CkbReproSourceLock(); let entry = CkbReproSourceLockEntry()
    entry.sourceId = "generated/hash-list"; entry.sourceType = "generated"
    entry.generatorId = generatorId; entry.generatorVersion = "1"
    entry.generatorSourceHash = benchmarkGapSha256(
        "ckb-hash-manifest-v1|1|sorted-input-hashes")
    entry.inputHashes.add(benchmarkGapSha256("b"))
    entry.inputHashes.add(benchmarkGapSha256("a"))
    let values = entry.inputHashes.toArray(); sort(values)
    var text = "# CKB pinned input hashes\n"
    for (hash in values) { text += "${hash}\n" }
    entry.outputHash = benchmarkGapSha256(text)
    entry.outputPath = "generated/hash-list.md"
    entry.license = "Apache-2.0"; entry.assemblyRole = "generated_guidance"
    entry.outputKind = CangjieTypedRecordKinds.DOC_SECTION
    lock.entries.add(entry); lock
}

private func p8PinnedSharedLock(command: P8PinnedGitCommand): CkbReproSourceLock {
    let lock = p8PinnedExternalLock(command.content, command.treeOid)
    let second = CkbReproSourceLockEntry()
    second.sourceId = "docs/b"; second.sourceType = "external_git"
    second.repository = lock.entries[0].repository
    second.commit = lock.entries[0].commit; second.tree = lock.entries[0].tree
    second.path = "docs/b.md"; second.fileHash = lock.entries[0].fileHash
    second.license = "Apache-2.0"; second.authMode = "anonymous"
    second.assemblyRole = "community_docs"
    second.outputKind = CangjieTypedRecordKinds.DOC_SECTION
    lock.entries.add(second); lock
}

@Test
public class CkbPinnedSourceBackendTest {
    @TestCase
    public func externalGitUsesExactPinsAndSameDescriptorStream(): Unit {
        let root = p8PinnedRoot("external")
        let command = P8PinnedGitCommand()
        let lock = p8PinnedExternalLock(command.content, command.treeOid)
        let material = buildCkbSourceMaterialsManifest(lock).entries[0]
        let backend = CkbPinnedSourceMaterialBackend(lock, root, command: command)
        let fetched = backend.fetch(material)
        @Expect(fetched.ok, true); @Expect(fetched.value, material.expectedHash)
        @Expect(command.calls.size, 7)
        @Expect(command.calls[0].contains("init"), true)
        @Expect(command.calls[1].contains(lock.entries[0].repository), true)
        @Expect(command.calls[2].contains(lock.entries[0].commit), true)
        @Expect(command.calls[2].contains("--no-tags"), true)
        @Expect(command.calls[2].contains("--depth=1"), true)
        for (args in command.calls) {
            let rendered = args.toString().toAsciiLower()
            @Expect(rendered.contains("authorization"), false)
            @Expect(rendered.contains("token"), false)
            @Expect(rendered.contains("password"), false)
            @Expect(rendered.contains("branch"), false)
            @Expect(rendered.contains("latest"), false)
        }
        let handle = backend.open(material)
        @Expect(handle.noFollow(), true)
        @Expect(handle.identity(), material.canonicalIdentity)
        let bytes = ArrayList<UInt8>()
        while (true) {
            let chunk = handle.read(65536)
            if (chunk.size == 0) { break }; bytes.add(all: chunk)
        }
        @Expect(bytes.toArray(), command.content)
        @Expect(handle.observedIdentity(), material.canonicalIdentity)
        handle.close(); remove(Path(root), recursive: true)
    }

    @TestCase
    public func pinsAndGeneratorAllowlistFailClosed(): Unit {
        let failedRoot = p8PinnedRoot("failed")
        let command = P8PinnedGitCommand(); command.failAt = 2
        let lock = p8PinnedExternalLock(command.content, command.treeOid)
        let material = buildCkbSourceMaterialsManifest(lock).entries[0]
        @Expect(CkbPinnedSourceMaterialBackend(lock, failedRoot,
            command: command).fetch(material).ok, false)
        if (exists(Path(failedRoot))) { remove(Path(failedRoot), recursive: true) }

        let generatedRoot = p8PinnedRoot("generated")
        let generatedLock = p8PinnedGeneratedLock("ckb-hash-manifest-v1")
        let generated = buildCkbSourceMaterialsManifest(generatedLock).entries[0]
        let backend = CkbPinnedSourceMaterialBackend(generatedLock, generatedRoot)
        @Expect(backend.generate(generated).ok, true)
        let handle = backend.open(generated); var count: Int64 = 0
        while (true) {
            let chunk = handle.read(7); if (chunk.size == 0) { break }
            count += chunk.size
        }
        @Expect(count > 0, true)
        @Expect(handle.observedIdentity(), generated.canonicalIdentity)
        handle.close(); remove(Path(generatedRoot), recursive: true)

        let unknownRoot = p8PinnedRoot("unknown")
        let unknownLock = p8PinnedGeneratedLock("unregistered-generator")
        let unknown = buildCkbSourceMaterialsManifest(unknownLock).entries[0]
        @Expect(CkbPinnedSourceMaterialBackend(unknownLock, unknownRoot)
            .generate(unknown).ok, false)
        for (mode in ["version", "source_hash", "output_hash"]) {
            let root = p8PinnedRoot("generator-${mode}")
            let lock = p8PinnedGeneratedLock("ckb-hash-manifest-v1")
            if (mode == "version") { lock.entries[0].generatorVersion = "2" }
            if (mode == "source_hash") {
                lock.entries[0].generatorSourceHash = benchmarkGapSha256("drift")
            }
            if (mode == "output_hash") {
                lock.entries[0].outputHash = benchmarkGapSha256("drift")
            }
            let manifest = buildCkbSourceMaterialsManifest(lock)
            @Expect(manifest.ready, true)
            @Expect(CkbPinnedSourceMaterialBackend(lock, root)
                .generate(manifest.entries[0]).ok, false)
        }
    }

    @TestCase
    public func sharedRepositoryFetchesOnceAndDriftFailsClosed(): Unit {
        let sharedRoot = p8PinnedRoot("shared")
        let command = P8PinnedGitCommand(); let lock = p8PinnedSharedLock(command)
        let manifest = buildCkbSourceMaterialsManifest(lock)
        let backend = CkbPinnedSourceMaterialBackend(lock, sharedRoot,
            command: command)
        @Expect(backend.fetch(manifest.entries[0]).ok, true)
        @Expect(backend.fetch(manifest.entries[1]).ok, true)
        @Expect(command.calls.size, 7)
        remove(Path(sharedRoot), recursive: true)

        let commitRoot = p8PinnedRoot("commit-drift")
        let commitCommand = P8PinnedGitCommand()
        let commitLock = p8PinnedExternalLock(commitCommand.content,
            commitCommand.treeOid)
        commitCommand.commit = "ffffffffffffffffffffffffffffffffffffffff"
        @Expect(CkbPinnedSourceMaterialBackend(commitLock, commitRoot,
            command: commitCommand).fetch(
                buildCkbSourceMaterialsManifest(commitLock).entries[0]).ok, false)

        let treeRoot = p8PinnedRoot("tree-drift")
        let treeCommand = P8PinnedGitCommand()
        let treeLock = p8PinnedExternalLock(treeCommand.content,
            treeCommand.treeOid)
        treeCommand.treeOid = "1111111111111111111111111111111111111111"
        @Expect(CkbPinnedSourceMaterialBackend(treeLock, treeRoot,
            command: treeCommand).fetch(
                buildCkbSourceMaterialsManifest(treeLock).entries[0]).ok, false)

        let fileRoot = p8PinnedRoot("file-drift")
        let fileCommand = P8PinnedGitCommand()
        let fileLock = p8PinnedExternalLock("different".toArray(),
            fileCommand.treeOid)
        @Expect(CkbPinnedSourceMaterialBackend(fileLock, fileRoot,
            command: fileCommand).fetch(
                buildCkbSourceMaterialsManifest(fileLock).entries[0]).ok, false)
    }

    @TestCase
    public func unsafeUrlsAndAcquisitionFailureAreRetryable(): Unit {
        let unsafeUrls = ["https://user@example.com/a.git",
            "https://example.com/a.git?ref=x", "https://example.com/a.git#x",
            "https://example.com:443/a.git", "https://localhost/a.git",
            "https://127.0.0.1/a.git", "file:///tmp/a.git",
            "ssh://example.com/a.git", "/tmp/a.git",
            "https://example.com/仓颉🙂.git"]
        for (url in unsafeUrls) {
            let root = p8PinnedRoot("unsafe-${url.hashCode()}")
            let command = P8PinnedGitCommand()
            let lock = p8PinnedExternalLock(command.content, command.treeOid)
            lock.entries[0].repository = url
            let manifest = buildCkbSourceMaterialsManifest(lock)
            if (manifest.ready) {
                @Expect(CkbPinnedSourceMaterialBackend(lock, root,
                    command: command).fetch(manifest.entries[0]).ok, false)
            }
            @Expect(command.calls.size, 0)
        }
        let root = p8PinnedRoot("retry")
        let command = P8PinnedGitCommand(); command.failAt = 2
        let lock = p8PinnedExternalLock(command.content, command.treeOid)
        let material = buildCkbSourceMaterialsManifest(lock).entries[0]
        let backend = CkbPinnedSourceMaterialBackend(lock, root, command: command)
        @Expect(backend.fetch(material).ok, false)
        @Expect(Directory.readFrom(Path(root)).size, 0)
        command.failAt = -1
        @Expect(backend.fetch(material).ok, true)
        remove(Path(root), recursive: true)
    }

    @TestCase
    public func commandTimeoutCleansDescendantsAndArtifacts(): Unit {
        let root = p8PinnedRoot("timeout"); Directory.create(Path(root))
        let child = Path(root).join("child.pid")
        let script = "sleep 29 & child=$!; echo $child > " +
            "${child.toString()}; wait $child"
        let result = ckbPinnedRunCommand("/bin/sh",
            ["-c", script], root, 1000)
        @Expect(result[0], 124); @Expect(result[1], "pinned_source_command_timeout")
        let childPid = try { String.fromUtf8(File.readFrom(child)).trimAscii() }
            catch (_: Exception) { "" }
        @Expect(childPid != "", true)
        @Expect(childPid == "" || launch("/bin/kill", ["-0", childPid]).wait() != 0,
            true)
        if (exists(child)) { remove(child) }
        for (entry in Directory.readFrom(Path(root))) {
            @Expect(entry.name.endsWith(".stdout") || entry.name.endsWith(".stderr") ||
                entry.name.endsWith(".pid") || entry.name.endsWith(".timeout"), false)
        }
        remove(Path(root), recursive: true)
    }
}
