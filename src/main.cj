package cangjie_community_knowledge_base

main(args: Array<String>): Int64 {
    let kb = newOfflineKnowledgeBase()
    let cli = parseCli(args)
    let config = loadCkbRuntimeConfig(cli.configPath)
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
    if (cli.command == "sync-once") {
        let store = FileKnowledgeStore("target/ckb-data")
        println(ckbSyncOnce(kb, SourceAdapter(), store))
        return 0
    }
    if (cli.command == "sync-live") {
        let options = LiveSyncOptions()
        options.dryRun = cli.dryRun
        options.apply = cli.apply
        let runner: SourceFetchRunner = if (config.networkEnabled) { HttpSourceFetchRunner(config) } else { DisabledNetworkFetchRunner() }
        let text = ckbSyncLive(kb, config, options, runner: runner, store: FileKnowledgeStore("target/ckb-data"))
        print(text)
        return if (text.startsWith("usage error")) { 2 } else { 0 }
    }
    if (cli.command == "rebuild-index") {
        let store = FileKnowledgeStore("target/ckb-data")
        let result = ckbRebuildIndex(kb, store)
        println("rebuild ok=${result.ok} activeKnowledgeVersion=${result.activeVersion} candidateKnowledgeVersion=${result.candidateVersion} count=${result.count}")
        return 0
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
    println("Usage: cangjie_community_knowledge_base [--config <path>] doctor | status | sync-once | sync-live (--dry-run|--apply) | rebuild-index | query <text> | evidence <text> | schema")
    2
}

class CliOptions {
    var command: String = ""
    var configPath: String = ""
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
        if (arg == "--config") {
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
