package cangjie_community_knowledge_base

import std.collection.ArrayList
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
    if (cli.command == "vector-bootstrap") {
        let result = ckbVectorBootstrapWithStoreAndKnowledgeStore(config, store, vectorStoreFromRuntime(config))
        if (ckbCliWantsJson(args)) {
            println(renderCkbVectorBootstrapJson(result))
        } else {
            print(renderCkbVectorBootstrapText(result))
        }
        return if (result.ok) { 0 } else { 1 }
    }
    if (cli.command == "vector-clean-derived") {
        let result = ckbCleanDerivedVectorArtifacts(config, store, hasArg(args, "--force"))
        if (ckbCliWantsJson(args)) {
            println(renderCkbDerivedVectorCleanupJson(result))
        } else {
            print(renderCkbDerivedVectorCleanupText(result))
        }
        return if (result.ok) { 0 } else { 1 }
    }
    let kb = loadCliKnowledgeBase(cli.command, store, config)
    let input = cliInput(args)
    if (cli.command == "scheduler-task-worker") {
        let taskName = ckbCliOption(args, "--task")
        let resultRelativePath = ckbCliOption(args, "--result-rel")
        if (taskName == "" || resultRelativePath == "") {
            println("usage error: scheduler-task-worker requires --task and --result-rel")
            return 2
        }
        let task = ckbRunSchedulerTaskWorker(kb, config, store, taskName, ckbCliOption(args, "--since"), ckbCliOptionInt(args, "--deadline", 0), resultRelativePath)
        return if (task.ok) { 0 } else { 1 }
    }
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
    if (cli.command == "cangjie-initialize") {
        let options = parseCkbFirstInitOptions(args)
        options.storeRoot = cli.storePath
        if (!options.apply && !options.dryRun) {
            println("usage error: cangjie-initialize requires --dry-run or --apply")
            return 2
        }
        let result = runCkbFirstInitializationWithActiveGuard(options, store)
        print(renderCkbFirstInitResult(result))
        return if (result.ok) { 0 } else { 1 }
    }
    if (cli.command == "cangjie-landing-status") {
        let service = CkbCommandLoopService(config, store)
        service.start()
        let report = collectCkbLandingStatus(service)
        if (ckbCliWantsJson(args)) {
            println(renderCkbLandingStatusJson(report))
        } else {
            print(renderCkbLandingStatusMarkdown(report))
        }
        return 0
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
    if (cli.command == "cangjie-abcde-parity-smoke") {
        return runCangjieAbcdeParitySmoke(args)
    }
    if (cli.command == "cangjie-humaneval-pass1-gate") {
        return runCangjieHumanEvalPass1Gate(args)
    }
    if (cli.command == "cangjie-humaneval-pass1-gate-smoke") {
        return runCangjieHumanEvalPass1GateSmoke(args)
    }
    if (cli.command == "cangjie-knowledge-release-gate") {
        return runCangjieKnowledgeReleaseGate(args, config: config, store: store, sourceRunner: if (config.networkEnabled) { HttpSourceFetchRunner(config) } else { DisabledNetworkFetchRunner() })
    }
    if (cli.command == "ollama-embedding-benchmark") {
        let result = ckbRunOllamaEmbeddingBenchmark(kb, config, ckbCliSampleSize(args))
        if (ckbCliWantsJson(args)) {
            println(renderCkbOllamaEmbeddingBenchmarkJson(result))
        } else {
            print("ollama embedding benchmark ok=${result.ok} status=${result.status} sampleSize=${result.sampleSize} p50Bytes=${result.p50Bytes} p95Bytes=${result.p95Bytes} p99Bytes=${result.p99Bytes} maxBytes=${result.maxBytes} measuredLatencyMillis=${result.measuredLatencyMillis} recommendation maxBatchItems=${result.maxBatchItems} maxBatchBytes=${result.maxBatchBytes} maxTextBytes=${result.maxTextBytes} diagnostic=${result.diagnostic}\n")
        }
        return if (result.ok) { 0 } else { 1 }
    }
    if (cli.command == "vector-reconcile") {
        let result = ckbVectorReconcile(kb, store, config, hasArg(args, "--force"))
        if (ckbCliWantsJson(args)) {
            println(renderCkbVectorReconcileJson(result))
        } else {
            print(renderCkbVectorReconcileText(result))
        }
        return if (result.ok) { 0 } else { 1 }
    }
    if (cli.command == "routine-repair") {
        let result = ckbRoutineRepair(kb, store, config, cli.storePath, hasArg(args, "--force"))
        if (ckbCliWantsJson(args)) {
            println(renderCkbRoutineRepairJson(result))
        } else {
            print(renderCkbRoutineRepairText(result))
        }
        return if (result.ok) { 0 } else { 1 }
    }
    if (cli.command == "rebuild-index") {
        let result = ckbRebuildIndex(kb, store)
        println("rebuild ok=${result.ok} activeKnowledgeVersion=${result.activeVersion} candidateKnowledgeVersion=${result.candidateVersion} count=${result.count}")
        return 0
    }
    if (cli.command == "scheduler-run") {
        let preRepair = store.repairActiveLiveShadowFromManifest()
        var schedulerKb = kb
        if (preRepair.repairPerformed) {
            schedulerKb = newKnowledgeBaseFromStoreWithRuntime(store, config).kb
        }
        let recovery = ckbRecoverStaleSchedulerRunsWithVectorStore(store, vectorStoreFromRuntime(config))
        let lock = ckbAcquireSchedulerRunLock(store, "scheduler-cli-${ckbCoreNowMillis()}", ckbCoreNowMillis() + ckbCliSchedulerRunLockBudgetMillis(args), stableSummaryHash(getCommand()))
        if (!lock.ok) {
            let busy = SchedulerExecutorResult()
            busy.runId = lock.runId
            busy.startedAtMillis = ckbCoreNowMillis()
            busy.endedAtMillis = busy.startedAtMillis
            busy.failed = 1
            busy.details = "scheduler lock ok=false status=${lock.status} diagnostic=${lock.diagnostic}\n"
            busy.validationDiagnostics.add("scheduler_lock:${lock.diagnostic}")
            ckbCliPopulateSchedulerRunEvidence(busy, config, cli.storePath)
            if (ckbCliWantsJson(args)) {
                println(ckbCliSchedulerRunJson(busy))
            } else {
                print("scheduler ran=0 succeeded=0 failed=1 degraded=0 forced=false\n")
                print(busy.details)
            }
            return 1
        }
        ckbApplySchedulerProfileBudgets(schedulerKb.scheduler)
        let runner = ckbSchedulerTaskRunnerForRuntime(schedulerKb, config, store, cli.configPath, cli.storePath, if (config.networkEnabled) { HttpSourceFetchRunner(config) } else { DisabledNetworkFetchRunner() })
        let executor = SchedulerExecutor(schedulerKb.scheduler, runner, FileSchedulerProgressSink(store), 300000)
        let taskNames = ckbCliSchedulerTaskNames(args)
        let gateTaskNames = if (hasArg(args, "--force-all")) {
            ckbSchedulerAllowlistTaskNames()
        } else {
            taskNames
        }
        let gate = ckbSchedulerPreRunGate(config, store, vectorStoreFromRuntime(config), gateTaskNames)
        if (!gate.ok) {
            let blocked = ckbSchedulerPreRunGateFailureResult(gate, gateTaskNames, hasArg(args, "--force") || hasArg(args, "--force-all"))
            blocked.runId = lock.runId
            ckbAppendSnapshotRepairDiagnostic(blocked, "pre", preRepair)
            for (diagnostic in recovery.diagnostics) {
                blocked.validationDiagnostics.add("recovery:${diagnostic}")
                blocked.details += "recovery ${diagnostic}\n"
            }
            ckbCliPopulateSchedulerRunEvidence(blocked, config, cli.storePath)
            store.saveSchedulerLoopMetadata("failed", config.schedulerEnabled, config.schedulerLoopIntervalMillis, if (blocked.forced) { "cli_forced" } else { "cli_due" }, 0, 0, blocked.taskNames, "scheduler_pre_run_gate_failed")
            ckbReleaseSchedulerRunLock(store, lock, blocked.runId, "failed")
            if (ckbCliWantsJson(args)) {
                println(ckbCliSchedulerRunJson(blocked))
            } else {
                print("scheduler ran=0 succeeded=0 failed=1 degraded=0 forced=${blocked.forced}\n")
                print(blocked.details)
            }
            return 1
        }
        let result = if (hasArg(args, "--force-all")) {
            executor.runTaskNames(ckbSchedulerAllowlistTaskNames(), force: true)
        } else if (taskNames.size > 0) {
            executor.runTaskNames(taskNames, force: hasArg(args, "--force"))
        } else {
            executor.runDue()
        }
        for (diagnostic in recovery.diagnostics) {
            result.validationDiagnostics.add("recovery:${diagnostic}")
            result.details += "recovery ${diagnostic}\n"
        }
        if (lock.diagnostic != "") {
            result.validationDiagnostics.add("scheduler_lock:${lock.diagnostic}")
            result.details += "scheduler_lock ${lock.diagnostic}\n"
        }
        ckbAppendSnapshotRepairDiagnostic(result, "pre", preRepair)
        let finalKb = newKnowledgeBaseFromStoreWithRuntime(store, config).kb
        ckbCliApplyFinalSchedulerConsistency(result, finalKb, store, config, cli.storePath)
        let postRepair = store.repairActiveLiveShadowFromManifest()
        ckbAppendSnapshotRepairDiagnostic(result, "post", postRepair)
        ckbCliPopulateSchedulerRunEvidence(result, config, cli.storePath)
        store.saveScheduler(schedulerKb.scheduler.entries)
        store.saveSchedulerLoopMetadata(if (result.failed == 0 && result.degraded == 0) { "running" } else { "failed" }, config.schedulerEnabled, config.schedulerLoopIntervalMillis, if (result.forced) { "cli_forced" } else { "cli_due" }, 0, result.ran, result.taskNames, if (result.failed == 0 && result.degraded == 0) { "ok" } else { "scheduler_cli_run_degraded" })
        ckbReleaseSchedulerRunLock(store, lock, result.runId, if (result.failed == 0 && result.degraded == 0) { "succeeded" } else { "failed" })
        if (ckbCliWantsJson(args)) {
            println(ckbCliSchedulerRunJson(result))
        } else {
            print("scheduler ran=${result.ran} succeeded=${result.succeeded} failed=${result.failed} degraded=${result.degraded} forced=${result.forced}\n")
            print(result.details)
        }
        return if (result.failed > 0 || result.degraded > 0) { 1 } else { 0 }
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
    println("Usage: cangjie_community_knowledge_base [--config <path>] [--store <path>] doctor | status | metrics | service | service-http | http-service | mcp-stdio | cangjie-initialize (--dry-run|--apply) --docs-root <path> --std-root <path> --stdx-root <path> --eval-root <path> | cangjie-landing-status [--format json] | service-once <command> | start | stop | restart | sync-once | sync-live (--dry-run|--apply) | source_analysis repo=<owner/repo> ref=<ref> path=<path> | native-http-smoke <url> | cangjie-corpus-status | cangjie-knowledge-pack <task> | cangjie-api-search <query> | cangjie-syntax-query <query> | cangjie-cookbook <task> | cangjie-diagnose <compiler-output> | cangjie-llms [task] | cangjie-context-pack <task> | cangjie-eval-summary <manifest.jsonl> | cangjie-eval-abcde [--preflight-only] | cangjie-eval-knowledge-audit --run-root <path> | cangjie-humaneval-pass1-gate --run-root <path> | cangjie-knowledge-release-gate --run-root <path> --manifest <manifest.jsonl> | cangjie-typed-ingest-smoke --docs-root <path> --case-root <path> | cangjie-serving-feed-smoke | cangjie-serving-query-smoke | cangjie-update-promotion-smoke | cangjie-abcde-parity-smoke | cangjie-humaneval-pass1-gate-smoke | vector-bootstrap [--json] | vector-clean-derived [--force] [--json] | vector-reconcile [--force] [--json] | routine-repair --force [--json] | ollama-embedding-benchmark [--json] [--sample-size <n>] | scheduler-run [--force-all|--task <name> [--force]] [--json] | rebuild-index | backup <path> | restore <path> | query <text> | evidence <text> | schema")
    2
}

private func ckbCliWantsJson(args: Array<String>): Bool {
    var i: Int64 = 0
    while (i < args.size) {
        if (args[i] == "--json") {
            return true
        }
        if (args[i] == "--format" && i + 1 < args.size && args[i + 1] == "json") {
            return true
        }
        i += 1
    }
    false
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
        "CKB_DYLD_EXTRA=\"/opt/homebrew/opt/openssl@3/lib:/opt/homebrew/opt/openssl@3.5/lib:/usr/local/opt/openssl@3/lib:/Users/l3gi0n/cangjie100/runtime/lib/darwin_aarch64_llvm:/Users/l3gi0n/work/workspace_cangjie/CangjieMagic/libs/cangjie-stdx-mac-aarch64-1.0.0.1/darwin_aarch64_llvm/dynamic/stdx:/Users/l3gi0n/work/workspace_cangjie/Metis/ffi\"; " +
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

private func ckbCliOption(args: Array<String>, name: String): String {
    var i: Int64 = 0
    while (i < args.size) {
        if (args[i] == name && i + 1 < args.size) {
            return args[i + 1]
        }
        i += 1
    }
    ""
}

private func ckbCliOptionInt(args: Array<String>, name: String, fallback: Int64): Int64 {
    let value = ckbCliOption(args, name)
    if (value == "") {
        return fallback
    }
    try {
        Int64.parse(value)
    } catch (_: Exception) {
        fallback
    }
}

private func ckbCliSchedulerTaskNames(args: Array<String>): ArrayList<String> {
    let names = ArrayList<String>()
    var i: Int64 = 0
    while (i < args.size) {
        if (args[i] == "--task" && i + 1 < args.size) {
            names.add(args[i + 1])
            i += 2
            continue
        }
        i += 1
    }
    names
}

private func ckbCliSchedulerRunJson(result: SchedulerExecutorResult): String {
    let ok = result.failed == 0 && result.degraded == 0
    "{\"ok\":${ok},\"errorCode\":\"${if (ok) { "" } else { "ckb.scheduler_run_degraded" }}\",\"runId\":\"${ckbCliJsonEscape(result.runId)}\",\"progressPath\":\"${ckbCliJsonEscape(result.progressPath)}\",\"startedAtMillis\":${result.startedAtMillis},\"endedAtMillis\":${result.endedAtMillis},\"timedOut\":${result.timedOut},\"partial\":${result.partial},\"ran\":${result.ran},\"succeeded\":${result.succeeded},\"failed\":${result.failed},\"degraded\":${result.degraded},\"forced\":${result.forced},\"buildCommit\":\"${ckbCliJsonEscape(result.buildCommit)}\",\"configHash\":\"${ckbCliJsonEscape(result.configHash)}\",\"storeHash\":\"${ckbCliJsonEscape(result.storeHash)}\",\"taskNames\":${ckbCliStringArrayJson(result.taskNames)},\"tasks\":${ckbSchedulerRunTaskRecordsJson(result.taskRecords)},\"details\":\"${ckbCliJsonEscape(result.details)}\",\"validationSummaries\":${ckbCliStringArrayJson(result.validationSummaries)},\"validationDiagnostics\":${ckbCliStringArrayJson(result.validationDiagnostics)},\"validationEvidenceHashes\":${ckbCliStringArrayJson(result.validationEvidenceHashes)},\"finalPreflightOk\":${result.finalPreflightOk},\"finalPreflightDiagnostics\":${ckbCliStringArrayJson(result.finalPreflightDiagnostics)},\"postRepairAttempted\":${result.postRepairAttempted},\"postRepairOk\":${result.postRepairOk},\"failedTasks\":${ckbCliSchedulerFailedTasksJson(ckbSchedulerFailureSummaries(result))}}"
}

private func ckbCliPopulateSchedulerRunEvidence(result: SchedulerExecutorResult, config: CkbRuntimeConfig, storePath: String): Unit {
    result.buildCommit = ckbCliBuildCommitEvidence()
    result.configHash = stableSummaryHash(config.redactedSummary())
    result.storeHash = stableSummaryHash(storePath)
}

private func ckbCliBuildCommitEvidence(): String {
    if (let Some(value) <- getVariable("CKB_BUILD_COMMIT")) {
        let trimmed = value.trimAscii()
        if (trimmed != "") {
            return trimmed
        }
    }
    "command:${stableSummaryHash(getCommand())}"
}

private func ckbCliSchedulerRunLockBudgetMillis(args: Array<String>): Int64 {
    if (hasArg(args, "--force-all")) {
        return 7200000
    }
    1800000
}

private func ckbCliApplyFinalSchedulerConsistency(result: SchedulerExecutorResult, kb: KnowledgeBase, store: FileKnowledgeStore, config: CkbRuntimeConfig, storePath: String): Unit {
    let preflight = ckbRoutineRuntimePreflightFromEnvWithBootstrap(config, storePath)
    result.finalPreflightOk = preflight.ok
    for (diagnostic in preflight.diagnostics) {
        result.finalPreflightDiagnostics.add("preflight:${diagnostic}")
    }
    if (preflight.ok || !ckbCliPreflightNeedsVectorRepair(preflight.diagnostics)) {
        if (!preflight.ok) {
            result.degraded += 1
            result.details += "final_preflight ok=false diagnostics=${ckbCliJoinStrings(preflight.diagnostics, ",")}\n"
        }
        return
    }
    result.postRepairAttempted = true
    let repair = ckbRoutineRepair(kb, store, config, storePath, true)
    result.postRepairOk = repair.ok
    for (diagnostic in repair.diagnostics) {
        result.finalPreflightDiagnostics.add("repair:${diagnostic}")
    }
    let after = ckbRoutineRuntimePreflightFromEnvWithBootstrap(config, storePath)
    result.finalPreflightOk = after.ok
    for (diagnostic in after.diagnostics) {
        result.finalPreflightDiagnostics.add("post_preflight:${diagnostic}")
    }
    if (!after.ok) {
        result.degraded += 1
        result.details += "final_preflight ok=false repairAttempted=true repairOk=${repair.ok} diagnostics=${ckbCliJoinStrings(after.diagnostics, ",")}\n"
    } else {
        result.details += "final_preflight ok=true repairAttempted=true repairOk=${repair.ok}\n"
    }
}

private func ckbCliPreflightNeedsVectorRepair(diagnostics: ArrayList<String>): Bool {
    for (diagnostic in diagnostics) {
        if (diagnostic.contains("qdrant_active_count_mismatch") || diagnostic.contains("qdrant_active_dimension_mismatch") || diagnostic.contains("qdrant_active_distance_mismatch") || diagnostic.contains("repair_required:vector_reconcile")) {
            return true
        }
    }
    false
}

private func ckbCliJoinStrings(values: ArrayList<String>, separator: String): String {
    var out = ""
    var first = true
    for (value in values) {
        if (!first) {
            out += separator
        }
        out += value
        first = false
    }
    out
}

private func ckbCliSchedulerFailedTasksJson(values: ArrayList<CkbSchedulerFailedTaskSummary>): String {
    var out = "["
    for (i in 0..values.size) {
        if (i > 0) {
            out += ","
        }
        let summary = values[i]
        out += "{\"taskName\":\"${ckbCliJsonEscape(summary.taskName)}\",\"status\":\"${ckbCliJsonEscape(summary.status)}\",\"primaryFailure\":\"${ckbCliJsonEscape(summary.primaryFailure)}\",\"failedSources\":${ckbCliStringArrayJson(summary.failedSources)},\"missingArtifacts\":${ckbCliStringArrayJson(summary.missingArtifacts)}}"
    }
    out + "]"
}

private func ckbCliStringArrayJson(values: ArrayList<String>): String {
    var out = "["
    for (i in 0..values.size) {
        if (i > 0) {
            out += ","
        }
        out += "\"${ckbCliJsonEscape(values[i])}\""
    }
    out + "]"
}

private func ckbCliJsonEscape(raw: String): String {
    redactSensitive(raw).replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
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

private func ckbCliSampleSize(args: Array<String>): Int64 {
    var i: Int64 = 0
    while (i < args.size) {
        if (args[i] == "--sample-size") {
            return parseNextInt(args, i, 64)
        }
        i += 1
    }
    64
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
