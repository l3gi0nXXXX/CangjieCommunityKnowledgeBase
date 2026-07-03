package cangjie_community_knowledge_base

import std.convert.Parsable
import std.env.{getCommand, getVariable, getStdOut}
import std.fs.{File, OpenMode, Path}
import std.io.*
import std.process.*

main(args: Array<String>): Int64 {
    let bootstrap = ckbMaybeRelaunchWithNativeTlsEnv(args)
    if (bootstrap[0]) {
        return bootstrap[1]
    }
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
    if (cli.command == "service-http" || cli.command == "http-service") {
        return runCkbHttpService(config, store)
    }
    if (cli.command == "mcp-stdio") {
        return runCkbMcpStdioLoop(config, store)
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
    if (cli.command == "source_analysis" || cli.command == "source-analysis") {
        let runner: SourceFetchRunner = if (config.networkEnabled) { HttpSourceFetchRunner(config) } else { DisabledNetworkFetchRunner() }
        let request = sourceAnalysisRequestFromText(cliTail(input, cli.command, ""))
        print(renderSourceAnalysis(ckbSourceAnalysis(request, runner: runner)))
        return 0
    }
    if (cli.command == "native-http-smoke") {
        let url = cliTail(input, "native-http-smoke", "")
        if (url == "") {
            println("usage error: native-http-smoke requires an allowlist URL")
            return 2
        }
        print(ckbNativeHttpSmoke(url, config))
        return 0
    }
    if (cli.command == "cangjie-corpus-status") {
        let service = CkbCommandLoopService(config, store)
        print(service.handleLine("cangjie_corpus_status").text)
        return 0
    }
    if (cli.command == "cangjie-knowledge-pack") {
        let service = CkbCommandLoopService(config, store)
        let tail = cliTail(input, cli.command, "Cangjie language context")
        print(service.handleLine("cangjie_knowledge_pack ${tail}").text)
        return 0
    }
    if (cli.command == "cangjie-api-search") {
        let service = CkbCommandLoopService(config, store)
        let tail = cliTail(input, cli.command, "stdx JSON")
        print(service.handleLine("cangjie_api_search ${tail}").text)
        return 0
    }
    if (cli.command == "cangjie-syntax-query") {
        let service = CkbCommandLoopService(config, store)
        let tail = cliTail(input, cli.command, "function syntax")
        print(service.handleLine("cangjie_syntax_query ${tail}").text)
        return 0
    }
    if (cli.command == "cangjie-cookbook") {
        let service = CkbCommandLoopService(config, store)
        let tail = cliTail(input, cli.command, "Cangjie task")
        print(service.handleLine("cangjie_cookbook ${tail}").text)
        return 0
    }
    if (cli.command == "cangjie-diagnose") {
        let service = CkbCommandLoopService(config, store)
        let tail = cliTail(input, cli.command, "Cangjie compiler diagnostic")
        print(service.handleLine("cangjie_diagnose ${tail}").text)
        return 0
    }
    if (cli.command == "cangjie-llms") {
        let service = CkbCommandLoopService(config, store)
        let task = cliTail(input, cli.command, "Cangjie language quick context")
        print(renderCangjieLlmsTxt(service.statusSnapshot(), service.cangjieKnowledgePack(task, budget: 5)))
        return 0
    }
    if (cli.command == "cangjie-context-pack") {
        let service = CkbCommandLoopService(config, store)
        let task = cliTail(input, cli.command, "Cangjie task")
        print(renderCangjieContextPack(service.cangjieCookbook(task, budget: 5)))
        return 0
    }
    if (cli.command == "cangjie-eval-summary") {
        let manifestPath = cliTail(input, cli.command, "")
        if (manifestPath == "") {
            println("usage error: cangjie-eval-summary requires a manifest JSONL path")
            return 2
        }
        let result = renderCangjieEvalManifestFileSummary(manifestPath)
        print(result[0])
        return result[1]
    }
    if (cli.command == "cangjie-eval-abcde") {
        return runCangjieEvalAbcde(args)
    }
    if (cli.command == "cangjie-eval-knowledge-audit") {
        return runCangjieEvalKnowledgeAudit(args)
    }
    if (cli.command == "cangjie-typed-ingest-smoke") {
        return runCangjieTypedIngestSmoke(args)
    }
    if (cli.command == "cangjie-serving-feed-smoke") {
        return runCangjieServingFeedSmoke(args)
    }
    if (cli.command == "cangjie-serving-query-smoke") {
        return runCangjieServingQuerySmoke(args)
    }
    if (cli.command == "cangjie-update-promotion-smoke") {
        return runCangjieUpdatePromotionSmoke(args)
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
    println("Usage: cangjie_community_knowledge_base [--config <path>] [--store <path>] doctor | status | metrics | service | service-http | http-service | mcp-stdio | service-once <command> | start | stop | restart | sync-once | sync-live (--dry-run|--apply) | source_analysis repo=<owner/repo> ref=<ref> path=<path> | native-http-smoke <url> | cangjie-corpus-status | cangjie-knowledge-pack <task> | cangjie-api-search <query> | cangjie-syntax-query <query> | cangjie-cookbook <task> | cangjie-diagnose <compiler-output> | cangjie-llms [task] | cangjie-context-pack <task> | cangjie-eval-summary <manifest.jsonl> | cangjie-eval-abcde [--preflight-only] | cangjie-eval-knowledge-audit --run-root <path> | cangjie-typed-ingest-smoke --docs-root <path> --case-root <path> | cangjie-serving-feed-smoke | cangjie-serving-query-smoke | cangjie-update-promotion-smoke | scheduler-run | rebuild-index | backup <path> | restore <path> | query <text> | evidence <text> | schema")
    2
}

private func ckbMaybeRelaunchWithNativeTlsEnv(args: Array<String>): (Bool, Int64) {
    if (getVariable("CKB_NATIVE_TLS_BOOTSTRAPPED") == Some("1")) {
        return (false, 0)
    }
    let cli = parseCli(args)
    if (!ckbCommandNeedsNativeTlsBootstrap(cli.command)) {
        return (false, 0)
    }
    let command = getCommand()
    if (command.trimAscii() == "") {
        return (false, 0)
    }
    let config = loadCkbRuntimeConfig(cli.configPath)
    var script = ckbNativeTlsBootstrapEnvScript(caFile: config.networkCaFile) + " exec " + ckbShellQuote(command)
    for (arg in args) {
        script += " " + ckbShellQuote(arg)
    }
    try {
        let process = launch("/bin/zsh", ["-lc", script], stdIn: Inherit, stdOut: Inherit, stdErr: Inherit)
        return (true, process.wait())
    } catch (e: Exception) {
        println("native tls bootstrap failed: ${e.message}")
        return (true, 1)
    }
}

public func ckbNativeTlsBootstrapScript(command: String, args: Array<String>): String {
    var script = "export CKB_NATIVE_TLS_BOOTSTRAPPED=1; " +
        "MAGIC_ROOT=\"" + "$" + "{MAGIC_PATH:-}\"; " +
        "if [ -z \"" + "$" + "{MAGIC_ROOT}\" ]; then MAGIC_ROOT=\"" + "$" + "{CKB_MAGIC_ROOT:-}\"; fi; " +
        "CANGJIE_ROOT=\"" + "$" + "{CANGJIE_HOME:-}\"; " +
        "if [ -z \"" + "$" + "{CANGJIE_ROOT}\" ]; then CANGJIE_ROOT=\"" + "$" + "{CKB_CANGJIE_ROOT:-}\"; fi; " +
        "CKB_DYLD_EXTRA=\"/opt/homebrew/opt/openssl@3/lib:/opt/homebrew/opt/openssl@3.5/lib:/usr/local/opt/openssl@3/lib\"; " +
        "if [ -n \"" + "$" + "{CANGJIE_ROOT}\" ]; then CKB_DYLD_EXTRA=\"" + "$" + "{CKB_DYLD_EXTRA}:" + "$" + "{CANGJIE_ROOT}/runtime/lib/darwin_aarch64_llvm\"; fi; " +
        "if [ -n \"" + "$" + "{MAGIC_ROOT}\" ]; then CKB_DYLD_EXTRA=\"" + "$" + "{CKB_DYLD_EXTRA}:" + "$" + "{MAGIC_ROOT}/libs/cangjie-stdx-mac-aarch64-1.0.0.1/darwin_aarch64_llvm/dynamic/stdx\"; fi; " +
        "export DYLD_LIBRARY_PATH=\"" +
        "$" + "{CKB_DYLD_EXTRA}:" +
        "$" + "{DYLD_LIBRARY_PATH}\"; " +
        "exec " + ckbShellQuote(command)
    for (arg in args) {
        script += " " + ckbShellQuote(arg)
    }
    script
}

private func ckbCommandNeedsNativeTlsBootstrap(command: String): Bool {
    command == "native-http-smoke" || command == "sync-live" || command == "source_analysis" || command == "source-analysis" || command == "service" || command == "start" || command == "service-http" || command == "http-service" || command == "service-once" || command == "scheduler-run" || command == "cangjie-update-promotion-smoke"
}

private func ckbShellQuote(value: String): String {
    "'" + value.replace("'", "'\\''") + "'"
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
    if (command == "schema" || command == "cangjie-eval-knowledge-audit") {
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

private func renderCangjieEvalManifestFileSummary(path: String): (String, Int64) {
    try {
        let text = String.fromUtf8(File.readFrom(Path(path)))
        let summary = parseCangjieEvalManifest(text)
        return (renderCangjieEvalManifestSummary(summary), if (summary.invalidLines == 0) { 0 } else { 1 })
    } catch (e: Exception) {
        return ("CangjieEval v0 summary\nstatus=read_failed\ndiagnostic=${redactSensitive(e.message)}\n", 1)
    }
}

private func runCkbMcpStdioLoop(config: CkbRuntimeConfig, store: FileKnowledgeStore): Int64 {
    let service = CkbCommandLoopService(config, store, sourceRunner: if (config.networkEnabled) { HttpSourceFetchRunner(config) } else { DisabledNetworkFetchRunner() })
    let server = CkbMcpStdioServer(service)
    let stdout = getStdOut()
    try (stdinFile = File("/dev/stdin", OpenMode.Read)) {
        let reader = StringReader(stdinFile)
        while (true) {
            let line = if (let Some(line) <- reader.readln()) {
                line
            } else {
                break
            }
            if (line.trimAscii() == "") {
                continue
            }
            let response = server.handleLine(line)
            if (response.shouldWrite) {
                stdout.writeln(response.payload)
                stdout.flush()
            }
        }
    } catch (_: Exception) {
        return 1
    }
    0
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
