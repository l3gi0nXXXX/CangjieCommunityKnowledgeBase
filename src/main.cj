package cangjie_community_knowledge_base

import std.convert.Parsable
import std.fs.{File, OpenMode}
import std.io.*

main(args: Array<String>): Int64 {
    ckbCliMain(args)
}

public func ckbCliMain(args: Array<String>): Int64 {
    let cli = parseCli(args)
    let config = loadCkbRuntimeConfig(cli.configPath)
    let store = FileKnowledgeStore(cli.storePath)
    let kb = loadCliKnowledgeBase(cli.command, store, config)
    let input = cliInput(args)
    if (cli.command == "" || cli.command == "doctor") {
        print(renderDoctor(cangjie_knowledge_status(kb)))
        print(renderRuntimeDoctor(config))
        return 0
    }
    if (cli.command == "status") {
        print(renderDoctor(cangjie_knowledge_status(kb)))
        print(renderRuntimeDoctor(config))
        return 0
    }
    if (cli.command == "metrics") {
        print(renderMetrics(cangjie_knowledge_status(kb)))
        print(renderRuntimeDoctor(config))
        return 0
    }
    if (cli.command == "service" || cli.command == "start") {
        return runCkbServiceLoop(config, store)
    }
    if (cli.command == "service-once") {
        let service = CkbCommandLoopService(config, store, sourceRunner: if (config.networkEnabled) { HttpSourceFetchRunner(config) } else { DisabledNetworkFetchRunner() })
        print(service.start())
        let response = service.handleLine(cliTail(input, "service-once", "health"))
        print(response.text)
        return if (response.text.startsWith("error")) { 2 } else { 0 }
    }
    if (cli.command == "stop") {
        println("service protocol=ckb-stdio-v1 action=stop usage=\"send stop to the running service stdin\"")
        return 0
    }
    if (cli.command == "restart") {
        let service = CkbCommandLoopService(config, store, sourceRunner: if (config.networkEnabled) { HttpSourceFetchRunner(config) } else { DisabledNetworkFetchRunner() })
        print(service.handleLine("restart").text)
        return 0
    }
    if (cli.command == "sync-once") {
        println(ckbSyncOnce(kb, SourceAdapter(), store))
        return 0
    }
    if (cli.command == "sync-live") {
        let options = LiveSyncOptions()
        options.dryRun = cli.dryRun
        options.apply = cli.apply
        let applyOptions = parseLiveApplyOptions(args)
        options.maxRepos = applyOptions.maxRepos
        options.maxFilesPerRepo = applyOptions.maxFilesPerRepo
        options.maxItems = applyOptions.maxItems
        options.since = applyOptions.since
        let runner: SourceFetchRunner = if (config.networkEnabled) { HttpSourceFetchRunner(config) } else { DisabledNetworkFetchRunner() }
        let text = ckbSyncLive(kb, config, options, runner: runner, store: store)
        print(text)
        return if (text.startsWith("usage error")) { 2 } else { 0 }
    }
    if (cli.command == "rebuild-index") {
        let result = ckbRebuildIndex(kb, store)
        println("rebuild ok=${result.ok} activeKnowledgeVersion=${result.activeVersion} candidateKnowledgeVersion=${result.candidateVersion} count=${result.count}")
        return 0
    }
    if (cli.command == "scheduler-run") {
        let executor = SchedulerExecutor(kb.scheduler, CkbSchedulerTaskRunner(kb, config, store, sourceRunner: if (config.networkEnabled) { HttpSourceFetchRunner(config) } else { DisabledNetworkFetchRunner() }))
        let result = executor.runDue()
        store.saveScheduler(kb.scheduler.entries)
        print("scheduler ran=${result.ran} succeeded=${result.succeeded} failed=${result.failed} degraded=${result.degraded}\n")
        print(result.details)
        return if (result.failed > 0) { 1 } else { 0 }
    }
    if (cli.command == "backup") {
        let result = store.backupActiveSnapshot(cliTail(input, "backup", ""))
        print(renderBackupRestore(result))
        return if (result.ok) { 0 } else { 1 }
    }
    if (cli.command == "restore") {
        let result = store.restoreActiveSnapshotBackup(cliTail(input, "restore", ""))
        print(renderBackupRestore(result))
        return if (result.ok) { 0 } else { 1 }
    }
    if (cli.command == "schema") {
        println(CkbSchema.mcpTools())
        println(CkbSchema.httpLikeRoutes())
        return 0
    }
    if (cli.command == "query") {
        let query = cliTail(input, "query", "func syntax")
        print(renderQuery(cangjie_evidence_pack(kb, query, 5)))
        return 0
    }
    if (cli.command == "evidence") {
        let query = cliTail(input, "evidence", "HttpClient")
        print(renderQuery(cangjie_evidence_pack(kb, query, 3)))
        return 0
    }
    println("Usage: cangjie_community_knowledge_base [--config <path>] [--store <path>] doctor | status | metrics | service | service-once <command> | start | stop | restart | sync-once | sync-live (--dry-run|--apply) | scheduler-run | rebuild-index | backup <path> | restore <path> | query <text> | evidence <text> | schema")
    2
}

class CliOptions {
    var command: String = ""
    var configPath: String = ""
    var storePath: String = "target/ckb-data"
    var dryRun: Bool = false
    var apply: Bool = false

    init() {}
}

private func parseCli(args: Array<String>): CliOptions {
    let cli = CliOptions()
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "--config" && i + 1 < args.size) {
            cli.configPath = args[i + 1]
            i += 2
            continue
        }
        if (arg == "--store" && i + 1 < args.size) {
            cli.storePath = args[i + 1]
            i += 2
            continue
        }
        if (arg == "--dry-run") {
            cli.dryRun = true
            i += 1
            continue
        }
        if (arg == "--apply") {
            cli.apply = true
            i += 1
            continue
        }
        if (!arg.startsWith("--") && cli.command == "") {
            cli.command = arg
        }
        i += 1
    }
    cli
}

private func cliInput(args: Array<String>): String {
    var input = ""
    var skipNext = false
    for (arg in args) {
        if (skipNext) {
            skipNext = false
            continue
        }
        if (arg == "--config" || arg == "--store") {
            skipNext = true
            continue
        }
        if (arg == "--dry-run" || arg == "--apply") {
            continue
        }
        if (input == "") {
            input = arg
        } else {
            input += " ${arg}"
        }
    }
    input.trimAscii()
}

private func loadCliKnowledgeBase(command: String, store: FileKnowledgeStore, config: CkbRuntimeConfig): KnowledgeBase {
    if (command == "schema") {
        return newOfflineKnowledgeBase()
    }
    newKnowledgeBaseFromStoreWithRuntime(store, config).kb
}

private func cliTail(input: String, command: String, fallback: String): String {
    if (input == command) {
        return fallback
    }
    let prefixSize = command.size + 1
    if (input.size <= prefixSize) {
        return fallback
    }
    input[prefixSize..input.size].trimAscii()
}

private func parseLiveApplyOptions(args: Array<String>): LiveApplyOptions {
    let options = LiveApplyOptions()
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "--apply") {
            options.apply = true
        } else if (arg == "--max-repos") {
            options.maxRepos = parseNextInt(args, i, -1)
            i += 1
        } else if (arg == "--max-files-per-repo") {
            options.maxFilesPerRepo = parseNextInt(args, i, -1)
            i += 1
        } else if (arg == "--max-items") {
            options.maxItems = parseNextInt(args, i, -1)
            i += 1
        } else if (arg == "--since") {
            if (i + 1 < args.size) {
                options.since = args[i + 1]
            }
            i += 1
        }
        i += 1
    }
    options
}

private func hasArg(args: Array<String>, name: String): Bool {
    for (arg in args) {
        if (arg == name) {
            return true
        }
    }
    false
}

private func parseNextInt(args: Array<String>, index: Int64, fallback: Int64): Int64 {
    if (index + 1 >= args.size) {
        return fallback
    }
    try {
        Int64.parse(args[index + 1])
    } catch (_: Exception) {
        fallback
    }
}

private func runCkbServiceLoop(config: CkbRuntimeConfig, store: FileKnowledgeStore): Int64 {
    let runner: SourceFetchRunner = if (config.networkEnabled) { HttpSourceFetchRunner(config) } else { DisabledNetworkFetchRunner() }
    let service = CkbCommandLoopService(config, store, sourceRunner: runner)
    print(service.start())
    try (stdinFile = File("/dev/stdin", OpenMode.Read)) {
        let reader = StringReader(stdinFile)
        while (true) {
            let line = if (let Some(line) <- reader.readln()) {
                line
            } else {
                break
            }
            let response = service.handleLine(line)
            print(response.text)
            if (response.shouldStop) {
                break
            }
        }
    } catch (_: Exception) {
        println("log level=error event=service_stdin_closed protocol=ckb-stdio-v1")
        return 1
    }
    0
}
