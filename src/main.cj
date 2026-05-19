package cangjie_community_knowledge_base

import std.convert.Parsable

main(args: Array<String>): Int64 {
    let kb = newOfflineKnowledgeBase()
    let input = cliInput(args)
    if (input == "" || input == "doctor") {
        print(renderDoctor(cangjie_knowledge_status(kb)))
        return 0
    }
    if (input == "status") {
        print(renderDoctor(cangjie_knowledge_status(kb)))
        return 0
    }
    if (input == "sync-once") {
        let store = FileKnowledgeStore("target/ckb-data")
        println(ckbSyncOnce(kb, SourceAdapter(), store))
        return 0
    }
    if (input == "sync-live" || input.startsWith("sync-live ")) {
        let options = parseLiveApplyOptions(args)
        if (!options.apply && !hasArg(args, "--dry-run")) {
            println("Usage: cangjie_community_knowledge_base sync-live --dry-run|--apply [--max-repos N] [--max-files-per-repo N] [--max-items N] [--since VALUE]")
            return 2
        }
        let store = FileKnowledgeStore("target/ckb-data")
        let result = ckbSyncLiveApply(kb, SourceAdapter(), store, options)
        println("live ok=${result.ok} applied=${result.applied} requests=${result.requests} fetched=${result.fetched} failed=${result.failed} truncated=${result.truncated} activeKnowledgeVersion=${result.activeVersion} candidateKnowledgeVersion=${result.candidateVersion} failedCandidateVersion=${result.failedVersion} since=${result.since}")
        return if (result.ok) { 0 } else { 1 }
    }
    if (input == "rebuild-index") {
        let store = FileKnowledgeStore("target/ckb-data")
        let result = ckbRebuildIndex(kb, store)
        println("rebuild ok=${result.ok} activeKnowledgeVersion=${result.activeVersion} candidateKnowledgeVersion=${result.candidateVersion} count=${result.count}")
        return 0
    }
    if (input == "schema") {
        println(CkbSchema.mcpTools())
        println(CkbSchema.httpLikeRoutes())
        return 0
    }
    if (input == "query" || input.startsWith("query ")) {
        let query = cliTail(input, "query", "func syntax")
        print(renderQuery(cangjie_evidence_pack(kb, query, 5)))
        return 0
    }
    if (input == "evidence" || input.startsWith("evidence ")) {
        let query = cliTail(input, "evidence", "HttpClient")
        print(renderQuery(cangjie_evidence_pack(kb, query, 3)))
        return 0
    }
    println("Usage: cangjie_community_knowledge_base doctor | status | sync-once | sync-live --dry-run|--apply | rebuild-index | query <text> | evidence <text> | schema")
    2
}

private func cliInput(args: Array<String>): String {
    var input = ""
    for (arg in args) {
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
