package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.convert.Parsable
import std.env.getVariable
import std.fs.{Directory, File, Path, exists}
import std.io.*
import std.process.*

public class CkbAbcdeGroups {
    public static let A: String = "A-no-ckb"
    public static let B: String = "B-ckb-context"
    public static let C: String = "C-ckb-mcp-stdio"
    public static let D: String = "D-ckb-mcp-http"
    public static let E: String = "E-local-cangjie-docs"
}

public class CkbAbcdeRunnerOptions {
    public var repoRoot: String = ckbAbcdeDefaultRepoRoot()
    public var runsRoot: String = "/Users/l3gi0n/Downloads/ckbtest"
    public var runId: String = ""
    public var datasetRoot: String = ""
    public var manifestPath: String = ""
    public var ckbBin: String = ""
    public var ckbStore: String = ""
    public var ckbHttpBase: String = "http://127.0.0.1:18890"
    public var docsRoot: String = "/Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs"
    public var caseStart: Int64 = 0
    public var caseEnd: Int64 = 163
    public var groups: ArrayList<String> = ArrayList<String>()
    public var preflightOnly: Bool = false
    public var skipClaude: Bool = false
    public var help: Bool = false

    public init() {
        this.datasetRoot = "${this.repoRoot}/test/cangjie_eval/cases/Cangjie-HumanEval"
        this.manifestPath = "${this.repoRoot}/test/cangjie_eval/cangjie_humaneval_manifest.jsonl"
        this.ckbBin = "${this.repoRoot}/target/release/bin/main"
        this.ckbStore = "${this.repoRoot}/ckb-data"
        this.groups.add(CkbAbcdeGroups.A)
        this.groups.add(CkbAbcdeGroups.B)
        this.groups.add(CkbAbcdeGroups.C)
        this.groups.add(CkbAbcdeGroups.D)
        this.groups.add(CkbAbcdeGroups.E)
    }
}

public class CkbAbcdeCommandResult {
    public var exitCode: Int64 = 1
    public var stdout: String = ""
    public var stderr: String = ""

    public init() {}
}

public class CkbAbcdeUsageStats {
    public var usageParseStatus: String = "missing_result"
    public var modelInputTokens: Int64 = 0
    public var modelOutputTokens: Int64 = 0
    public var modelCacheReadTokens: Int64 = 0
    public var modelCacheCreationTokens: Int64 = 0
    public var modelTotalTokens: Int64 = 0
    public var llmTurnCount: Int64 = 0
    public var usageSourcePath: String = ""

    public init() {}
}

public class CkbAbcdePreflightResult {
    public var ok: Bool = true
    public var checks: ArrayList<String> = ArrayList<String>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func add(name: String, passed: Bool, diagnostic: String): Unit {
        this.checks.add("{\"name\":\"${ckbAbcdeJsonEscape(name)}\",\"ok\":${passed},\"diagnostic\":\"${ckbAbcdeJsonEscape(diagnostic)}\"}")
        if (!passed) {
            this.ok = false
            this.diagnostics.add("${name}: ${diagnostic}")
        }
    }
}

public func parseCkbAbcdeRunnerOptions(args: Array<String>): CkbAbcdeRunnerOptions {
    let options = CkbAbcdeRunnerOptions()
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "cangjie-eval-abcde") {
            i += 1
            continue
        }
        if (arg == "--help" || arg == "-h") {
            options.help = true
            i += 1
            continue
        }
        if (arg == "--preflight-only") {
            options.preflightOnly = true
            i += 1
            continue
        }
        if (arg == "--skip-claude") {
            options.skipClaude = true
            i += 1
            continue
        }
        if (arg == "--run-id" && i + 1 < args.size) {
            options.runId = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--repo-root" && i + 1 < args.size) {
            options.repoRoot = args[i + 1].trimAscii()
            options.datasetRoot = "${options.repoRoot}/test/cangjie_eval/cases/Cangjie-HumanEval"
            options.manifestPath = "${options.repoRoot}/test/cangjie_eval/cangjie_humaneval_manifest.jsonl"
            options.ckbBin = "${options.repoRoot}/target/release/bin/main"
            options.ckbStore = "${options.repoRoot}/ckb-data"
            i += 2
            continue
        }
        if (arg == "--runs-root" && i + 1 < args.size) {
            options.runsRoot = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--dataset-root" && i + 1 < args.size) {
            options.datasetRoot = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--manifest" && i + 1 < args.size) {
            options.manifestPath = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--ckb-bin" && i + 1 < args.size) {
            options.ckbBin = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--ckb-store" && i + 1 < args.size) {
            options.ckbStore = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--ckb-http-base" && i + 1 < args.size) {
            options.ckbHttpBase = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--docs-root" && i + 1 < args.size) {
            options.docsRoot = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--case-start" && i + 1 < args.size) {
            options.caseStart = ckbAbcdeParseInt(args[i + 1], options.caseStart)
            i += 2
            continue
        }
        if (arg == "--case-end" && i + 1 < args.size) {
            options.caseEnd = ckbAbcdeParseInt(args[i + 1], options.caseEnd)
            i += 2
            continue
        }
        if (arg == "--case-id" && i + 1 < args.size) {
            let parsed = ckbAbcdeParseCaseIndex(args[i + 1])
            options.caseStart = parsed
            options.caseEnd = parsed
            i += 2
            continue
        }
        if (arg == "--groups" && i + 1 < args.size) {
            options.groups = ckbAbcdeParseGroups(args[i + 1])
            i += 2
            continue
        }
        i += 1
    }
    options
}

public func runCangjieEvalAbcde(args: Array<String>): Int64 {
    let options = parseCkbAbcdeRunnerOptions(args)
    if (options.help) {
        print(ckbAbcdeUsage())
        return 0
    }
    if (options.runId == "") {
        options.runId = "abcde-${ckbAbcdeGeneratedRunId()}"
    }
    let safetyDiagnostic = ckbAbcdeOptionsSafetyDiagnostic(options)
    if (safetyDiagnostic != "ok") {
        println("ABCDE safety check failed: ${safetyDiagnostic}")
        return 1
    }
    let runRoot = "${options.runsRoot}/${options.runId}"
    ckbAbcdeEnsureDir(runRoot)

    let preflight = ckbAbcdePreflight(options, runRoot)
    ckbAbcdeWriteText("${runRoot}/preflight.json", ckbAbcdeRenderPreflightJson(options, runRoot, preflight))
    ckbAbcdeWriteText("${runRoot}/preflight.md", ckbAbcdeRenderPreflightMarkdown(options, runRoot, preflight))
    if (!preflight.ok) {
        println("ABCDE preflight failed: ${runRoot}/preflight.md")
        return 1
    }
    if (options.preflightOnly) {
        println("ABCDE preflight ok: ${runRoot}")
        return 0
    }

    ckbAbcdeWriteText("${runRoot}/case-usage-summary.csv", "caseId,usageParseOkGroupCount,caseTotalModelTokens,caseAverageModelTokensPerGroup,caseTotalLlmTurns,caseAverageLlmTurnsPerGroup,usageParseFailedGroups\n")
    var failed: Int64 = 0
    var caseIndex = options.caseStart
    while (caseIndex <= options.caseEnd) {
        let caseId = ckbAbcdeCaseId(caseIndex)
        let caseRoot = "${runRoot}/cases/${caseId}"
        ckbAbcdeEnsureDir(caseRoot)
        let summaries = ArrayList<String>()
        var previousGroup = ""
        for (group in options.groups) {
            let resultLine = ckbAbcdeRunCaseGroup(options, runRoot, caseId, group, previousGroup)
            summaries.add(resultLine)
            ckbAbcdeAppendText("${runRoot}/results.jsonl", "${resultLine}\n")
            if (resultLine.contains("\"status\":\"failed\"")) {
                failed += 1
            }
            previousGroup = group
        }
        ckbAbcdeWriteText("${caseRoot}/case-summary.json", ckbAbcdeRenderCaseSummary(options, runRoot, caseId, summaries))
        ckbAbcdeAppendText("${runRoot}/case-usage-summary.csv", ckbAbcdeRenderCaseUsageSummaryCsvRow(caseId, summaries) + "\n")
        caseIndex += 1
    }
    ckbAbcdeWriteSummary(runRoot)
    println("ABCDE run complete: ${runRoot}")
    if (failed > 0) { 1 } else { 0 }
}

public func renderCkbAbcdePrompt(group: String, caseId: String, modelTask: String, contextText: String): String {
    var out = "# ${caseId} ${group}\n\n"
    out += "You are completing one Cangjie HumanEval case. Modify only `src/solution.cj` in the current workspace. Keep the public function signature unchanged. The copied workspace root is your current directory; if the task text below mentions `starter/src/solution.cj`, still edit exactly `src/solution.cj`. Do not read hidden tests, reference solutions, unrelated repositories, or files outside the allowed paths. Use at most three knowledge or documentation lookup tool calls before editing; do not perform prolonged research. If documentation is inconclusive, implement directly from the starter signature, examples, and common Cangjie syntax. After editing, reply with a short completion note.\n\n"
    if (group == CkbAbcdeGroups.A) {
        out += "Knowledge policy for this run: No CKB baseline. Do not use CKB HTTP APIs, MCP tools, local cangjie_docs, web search, or external source repositories.\n\n"
    } else if (group == CkbAbcdeGroups.B) {
        out += "Knowledge policy for this run: use only the CKB REST context embedded below. Do not use MCP tools, local cangjie_docs, web search, or external source repositories.\n\n"
        out += "## CKB REST Context\n\n```json\n${contextText}\n```\n\n"
    } else if (group == CkbAbcdeGroups.C) {
        out += "Knowledge policy for this run: use the configured stdio MCP server `ckb-cangjie`. Before reading or editing `src/solution.cj`, you must call `mcp__ckb-cangjie__cangjie_knowledge_pack` at least once with this case and task context. This run is invalid without that real tool call, even if the task looks trivial. Do not use CKB REST context, HTTP MCP, local cangjie_docs, web search, or external source repositories.\n\n"
    } else if (group == CkbAbcdeGroups.D) {
        out += "Knowledge policy for this run: use the configured Streamable HTTP MCP server `ckb-cangjie-http`. Before reading or editing `src/solution.cj`, you must call `mcp__ckb-cangjie-http__cangjie_knowledge_pack` at least once with this case and task context. This run is invalid without that real tool call, even if the task looks trivial. Do not use CKB REST context, stdio MCP, local cangjie_docs, web search, or external source repositories.\n\n"
    } else if (group == CkbAbcdeGroups.E) {
        out += "Knowledge policy for this run: 当前这个项目是仓颉语言开发的项目。You may use local official Cangjie docs under /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs when Cangjie syntax, standard library, stdx, or tool usage knowledge is needed. Start from /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs/dev-guide/summary_cjnative_EN.md and /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs/tools/summary_cjnative_EN.md when they are useful, and prefer targeted read-only Bash rg queries or focused Read calls over loading large documents. You may use Bash only for read-only inspection inside the current temporary workspace or read-only documentation queries under /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs. For documentation Bash queries, prefer absolute paths such as `rg \"ArrayList\" /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs`; do not rely on `cd` followed by later relative documentation queries. Do not use CKB REST APIs, MCP tools, web search, network commands, shell commands that write/delete/move files, or external source repositories.\n\n"
    }
    out += "## Task\n\n"
    out += modelTask
    if (!modelTask.endsWith("\n")) {
        out += "\n"
    }
    out
}

public func renderCkbAbcdeMcpConfig(group: String, ckbBin: String, ckbStore: String, ckbHttpBase: String): String {
    if (group == CkbAbcdeGroups.C) {
        let stdioScript = ckbAbcdeNativeTlsBootstrapScript(ckbBin, ["--store", ckbStore, "mcp-stdio"])
        return "{\n  \"mcpServers\": {\n    \"ckb-cangjie\": {\n      \"command\": \"/bin/zsh\",\n      \"args\": [\"-lc\", \"${ckbAbcdeJsonEscape(stdioScript)}\"]\n    }\n  }\n}\n"
    }
    if (group == CkbAbcdeGroups.D) {
        return "{\n  \"mcpServers\": {\n    \"ckb-cangjie-http\": {\n      \"type\": \"http\",\n      \"url\": \"${ckbAbcdeJsonEscape(ckbHttpBase)}/mcp\"\n    }\n  }\n}\n"
    }
    "{\n  \"mcpServers\": {}\n}\n"
}

public func ckbAbcdeJsonEscape(value: String): String {
    let out = StringBuilder()
    for (ch in value.toRuneArray()) {
        if (ch == r'"') {
            out.append("\\\"")
        } else if (ch == r'\\') {
            out.append("\\\\")
        } else if (ch == r'\n') {
            out.append("\\n")
        } else if (ch == r'\r') {
            out.append("\\r")
        } else if (ch == r'\t') {
            out.append("\\t")
        } else {
            out.append(ch)
        }
    }
    out.toString()
}

private func ckbAbcdeRunCaseGroup(options: CkbAbcdeRunnerOptions, runRoot: String, caseId: String, group: String, previousGroup: String): String {
    let caseSrc = "${options.datasetRoot}/${caseId}"
    let groupRoot = "${runRoot}/cases/${caseId}/${group}"
    let workspace = "${groupRoot}/workspace"
    ckbAbcdeEnsureDir(groupRoot)
    ckbAbcdeWriteText("${groupRoot}/switch-gate.json", "{\"caseId\":\"${caseId}\",\"group\":\"${group}\",\"status\":\"entered\"}\n")
    ckbAbcdeAppendText("${runRoot}/cases/${caseId}/env-switch-checks.jsonl", ckbAbcdeRenderEnvSwitchCheck(caseId, previousGroup, group, workspace, groupRoot) + "\n")

    let copy = ckbAbcdeRunShell("rm -rf ${ckbAbcdeShellQuote(workspace)} && cp -R ${ckbAbcdeShellQuote("${caseSrc}/starter")} ${ckbAbcdeShellQuote(workspace)}", "")
    ckbAbcdeWriteText("${groupRoot}/workspace-copy.stdout.log", copy.stdout)
    ckbAbcdeWriteText("${groupRoot}/workspace-copy.stderr.log", copy.stderr)

    var contextText = ""
    var knowledgeReady = true
    if (group == CkbAbcdeGroups.B) {
        let body = "{\"task\":\"${ckbAbcdeJsonEscape(caseId)} Cangjie HumanEval implementation\",\"targetVersion\":\"1.0.0\",\"budget\":5,\"includeExamples\":true,\"includeAntiPatterns\":true}"
        ckbAbcdeWriteText("${groupRoot}/ckb-rest-request.json", body)
        let rest = ckbAbcdeRunShell("curl ${ckbAbcdeCurlRetryFlags()} --max-time 20 -fsS -X POST -H 'Content-Type: application/json' --data-binary @${ckbAbcdeShellQuote("${groupRoot}/ckb-rest-request.json")} ${ckbAbcdeShellQuote("${options.ckbHttpBase}/v1/cangjie/knowledge-pack")}", "")
        contextText = rest.stdout
        knowledgeReady = rest.exitCode == 0 && rest.stdout.contains("\"ok\":true")
        ckbAbcdeWriteText("${groupRoot}/ckb-rest-response.json", rest.stdout)
        ckbAbcdeWriteText("${groupRoot}/ckb-knowledge-pack.json", rest.stdout)
        ckbAbcdeWriteText("${groupRoot}/ckb-rest.stderr.log", rest.stderr)
        let contextRest = ckbAbcdeRunShell("curl ${ckbAbcdeCurlRetryFlags()} --max-time 20 -fsS -X POST -H 'Content-Type: application/json' --data-binary @${ckbAbcdeShellQuote("${groupRoot}/ckb-rest-request.json")} ${ckbAbcdeShellQuote("${options.ckbHttpBase}/v1/cangjie/context-pack")}", "")
        ckbAbcdeWriteText("${groupRoot}/ckb-context-pack.json", contextRest.stdout)
        ckbAbcdeWriteText("${groupRoot}/ckb-context-pack.stderr.log", contextRest.stderr)
        if (contextRest.stdout != "") {
            contextText += "\n${contextRest.stdout}"
        }
    }

    if (group == CkbAbcdeGroups.C) {
        ckbAbcdeRunMcpStdioSmoke(options, groupRoot)
    }
    if (group == CkbAbcdeGroups.D) {
        ckbAbcdeRunMcpHttpSmoke(options, groupRoot)
    }

    let mcpConfig = renderCkbAbcdeMcpConfig(group, options.ckbBin, options.ckbStore, options.ckbHttpBase)
    ckbAbcdeWriteText("${groupRoot}/mcp-config.json", mcpConfig)
    if (group != CkbAbcdeGroups.C && group != CkbAbcdeGroups.D) {
        ckbAbcdeWriteText("${groupRoot}/empty-mcp.json", mcpConfig)
    } else if (group == CkbAbcdeGroups.C) {
        ckbAbcdeWriteText("${groupRoot}/ckb-mcp-stdio.json", mcpConfig)
    } else if (group == CkbAbcdeGroups.D) {
        ckbAbcdeWriteText("${groupRoot}/ckb-mcp-http.json", mcpConfig)
    }

    let prompt = renderCkbAbcdePrompt(group, caseId, ckbAbcdeReadText("${caseSrc}/prompt.md"), contextText)
    ckbAbcdeWriteText("${groupRoot}/prompt.final.md", prompt)

    var claudeExit: Int64 = 0
    if (options.skipClaude) {
        ckbAbcdeWriteText("${groupRoot}/claude-transcript.jsonl", "{\"event\":\"skipped\",\"reason\":\"skip-claude\"}\n")
        ckbAbcdeWriteText("${groupRoot}/claude.stdout.log", "")
        ckbAbcdeWriteText("${groupRoot}/claude.stderr.log", "")
    } else {
        let claude = ckbAbcdeRunClaude(group, groupRoot, workspace, options.docsRoot)
        claudeExit = claude.exitCode
    }
    let usage = ckbAbcdeParseClaudeUsageFile("${groupRoot}/claude-transcript.jsonl")
    ckbAbcdeWriteText("${groupRoot}/usage.json", ckbAbcdeRenderUsageJson(usage) + "\n")

    let inject = ckbAbcdeRunShell("cp ${ckbAbcdeShellQuote("${caseSrc}/tests/TestMain.cj")} ${ckbAbcdeShellQuote("${workspace}/src/main.cj")} && cp ${ckbAbcdeShellQuote("${caseSrc}/tests/cjpm.executable.toml")} ${ckbAbcdeShellQuote("${workspace}/cjpm.toml")}", "")
    ckbAbcdeWriteText("${groupRoot}/hidden-test-inject.stdout.log", inject.stdout)
    ckbAbcdeWriteText("${groupRoot}/hidden-test-inject.stderr.log", inject.stderr)
    ckbAbcdeWriteText("${groupRoot}/hidden-test-inject.log", inject.stdout + inject.stderr)
    let test = ckbAbcdeRunShell("cjpm run", workspace)
    let testLog = test.stdout + test.stderr
    ckbAbcdeWriteText("${groupRoot}/test.log", testLog)

    let transcript = ckbAbcdeReadText("${groupRoot}/claude-transcript.jsonl") + ckbAbcdeReadText("${groupRoot}/claude.stdout.log") + ckbAbcdeReadText("${groupRoot}/claude.stderr.log")
    let toolEvidence = ckbAbcdeToolEvidence(group, transcript)
    let violation = ckbAbcdeForbiddenEvidence(group, transcript)
    let unitPass = test.exitCode == 0 && !ckbAbcdeTestLogContainsFailure(testLog)
    let unitPassAt1 = ckbAbcdeUnitPassAt1(unitPass, groupRoot)
    let toolReady = ckbAbcdeRequiredKnowledgeReady(group, knowledgeReady, toolEvidence)
    let failureType = ckbAbcdeFailureType(claudeExit, test.exitCode, unitPass, violation, testLog, toolReady)
    let protocolViolation = violation != "none"
    let status = if (copy.exitCode == 0 && inject.exitCode == 0 && claudeExit == 0 && unitPass && violation == "none" && toolReady) { "passed" } else { "failed" }
    ckbAbcdeWriteText("${groupRoot}/test-result.json", "{\"testExitCode\":${test.exitCode},\"unitPassAt1\":${unitPassAt1},\"failureType\":\"${failureType}\",\"testLogPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/test.log")}\"}\n")
    ckbAbcdeWriteText("${groupRoot}/protocol-audit.json", "{\"protocolViolation\":${protocolViolation},\"protocolViolationReason\":\"${ckbAbcdeJsonEscape(violation)}\",\"knowledgeEntry\":\"${ckbAbcdeKnowledgeEntry(group)}\",\"toolTransport\":\"${ckbAbcdeToolTransport(group)}\",\"toolEvidence\":\"${ckbAbcdeJsonEscape(toolEvidence)}\"}\n")
    if (group == CkbAbcdeGroups.E) {
        ckbAbcdeWriteText("${groupRoot}/docs-path-audit.json", "{\"docsRoot\":\"${ckbAbcdeJsonEscape(options.docsRoot)}\",\"summaryFiles\":[\"${ckbAbcdeJsonEscape("${options.docsRoot}/dev-guide/summary_cjnative_EN.md")}\",\"${ckbAbcdeJsonEscape("${options.docsRoot}/tools/summary_cjnative_EN.md")}\"],\"allowed\":${exists(Path("${options.docsRoot}/dev-guide/summary_cjnative_EN.md")) && exists(Path("${options.docsRoot}/tools/summary_cjnative_EN.md"))}}\n")
    }
    let result = ckbAbcdeRenderCaseResult(options, runRoot, caseId, group, status, claudeExit, test.exitCode, unitPass, unitPassAt1, failureType, toolEvidence, violation, groupRoot)
    ckbAbcdeWriteText("${groupRoot}/case-result.json", result + "\n")
    ckbAbcdeWriteText("${groupRoot}/audit.json", "{\"toolEvidence\":\"${toolEvidence}\",\"violation\":\"${violation}\"}\n")
    result
}

private func ckbAbcdeRunClaude(group: String, groupRoot: String, workspace: String, docsRoot: String): CkbAbcdeCommandResult {
    var last = CkbAbcdeCommandResult()
    for (attempt in 1..=2) {
        let current = ckbAbcdeRunClaudeOnce(group, groupRoot, workspace, docsRoot, attempt)
        last = current
        ckbAbcdeAppendText("${groupRoot}/claude-attempts.jsonl", "{\"attempt\":${attempt},\"exitCode\":${current.exitCode}}\n")
        ckbAbcdePublishClaudeAttemptArtifacts(groupRoot, attempt)
        if (current.exitCode == 0) {
            return current
        }
    }
    last
}

private func ckbAbcdeRunClaudeOnce(group: String, groupRoot: String, workspace: String, docsRoot: String, attempt: Int64): CkbAbcdeCommandResult {
    var addDir = "--add-dir ${ckbAbcdeShellQuote(workspace)}"
    if (group == CkbAbcdeGroups.E) {
        addDir += " --add-dir ${ckbAbcdeShellQuote(docsRoot)}"
    }
    let toolLimit = ckbAbcdeClaudeToolLimitForGroup(group)
    let modelEnvGuard = "env -u ANTHROPIC_MODEL -u ANTHROPIC_DEFAULT_OPUS_MODEL -u ANTHROPIC_DEFAULT_SONNET_MODEL -u ANTHROPIC_DEFAULT_HAIKU_MODEL -u CLAUDE_CODE_SUBAGENT_MODEL"
    let transcript = "${groupRoot}/claude-transcript.attempt-${attempt}.jsonl"
    let stderr = "${groupRoot}/claude.attempt-${attempt}.stderr.log"
    let command = "${modelEnvGuard} claude -p --verbose --no-session-persistence --output-format stream-json --strict-mcp-config --mcp-config ${ckbAbcdeShellQuote("${groupRoot}/mcp-config.json")} ${ckbAbcdeClaudePermissionFlag()} ${toolLimit} ${addDir} < ${ckbAbcdeShellQuote("${groupRoot}/prompt.final.md")} > ${ckbAbcdeShellQuote(transcript)} 2> ${ckbAbcdeShellQuote(stderr)}"
    let script = ckbAbcdeClaudeTimeoutShell(command, stderr, 180) + "; cp ${ckbAbcdeShellQuote(transcript)} ${ckbAbcdeShellQuote("${groupRoot}/claude-transcript.jsonl")} 2>/dev/null || true; cp ${ckbAbcdeShellQuote(transcript)} ${ckbAbcdeShellQuote("${groupRoot}/claude.stdout.log")} 2>/dev/null || true; cp ${ckbAbcdeShellQuote(stderr)} ${ckbAbcdeShellQuote("${groupRoot}/claude.stderr.log")} 2>/dev/null || true; exit $code"
    ckbAbcdeRunShell(script, workspace)
}

private func ckbAbcdePublishClaudeAttemptArtifacts(groupRoot: String, attemptCount: Int64): Unit {
    let transcript = ckbAbcdeMergedClaudeAttemptText(groupRoot, "claude-transcript.attempt-", ".jsonl", attemptCount)
    let stderr = ckbAbcdeMergedClaudeAttemptText(groupRoot, "claude.attempt-", ".stderr.log", attemptCount)
    ckbAbcdeWriteText("${groupRoot}/claude-transcript.jsonl", transcript)
    ckbAbcdeWriteText("${groupRoot}/claude.stdout.log", transcript)
    ckbAbcdeWriteText("${groupRoot}/claude.stderr.log", stderr)
}

private func ckbAbcdeMergedClaudeAttemptText(groupRoot: String, prefix: String, suffix: String, attemptCount: Int64): String {
    let out = StringBuilder()
    for (attempt in 1..=attemptCount) {
        ckbAbcdeAppendAttemptText(out, ckbAbcdeReadText("${groupRoot}/${prefix}${attempt}${suffix}"))
    }
    out.toString()
}

private func ckbAbcdeAppendAttemptText(out: StringBuilder, text: String): Unit {
    if (text == "") {
        return
    }
    out.append(text)
    if (!text.endsWith("\n")) {
        out.append("\n")
    }
}

public func ckbAbcdeJoinClaudeAttemptTextForTest(first: String, second: String): String {
    let out = StringBuilder()
    ckbAbcdeAppendAttemptText(out, first)
    ckbAbcdeAppendAttemptText(out, second)
    out.toString()
}

private func ckbAbcdeClaudeTimeoutShell(command: String, stderrPath: String, timeoutSeconds: Int64): String {
    let quotedStderr = ckbAbcdeShellQuote(stderrPath)
    "${command} & child=$!; elapsed=0; timed_out=0; while kill -0 \"$child\" 2>/dev/null; do if [ \"$elapsed\" -ge ${timeoutSeconds} ]; then echo claude_timeout_after_${timeoutSeconds}s >> ${quotedStderr}; pkill -TERM -P \"$child\" 2>/dev/null || true; kill -TERM \"$child\" 2>/dev/null || true; sleep 2; pkill -KILL -P \"$child\" 2>/dev/null || true; kill -KILL \"$child\" 2>/dev/null || true; timed_out=1; break; fi; sleep 1; elapsed=$((elapsed + 1)); done; if [ \"$timed_out\" -eq 1 ]; then wait \"$child\" 2>/dev/null || true; code=124; else wait \"$child\"; code=$?; fi"
}

public func ckbAbcdeClaudeTimeoutShellForTest(command: String, stderrPath: String, timeoutSeconds: Int64): String {
    ckbAbcdeClaudeTimeoutShell(command, stderrPath, timeoutSeconds)
}

private func ckbAbcdeClaudePermissionFlag(): String {
    "--dangerously-skip-permissions"
}

public func ckbAbcdeClaudePermissionFlagForTest(): String {
    ckbAbcdeClaudePermissionFlag()
}

public func ckbAbcdeClaudeToolLimitForGroup(group: String): String {
    ""
}

private func ckbAbcdeCurlRetryFlags(): String {
    "--retry 3 --retry-delay 2 --retry-connrefused"
}

public func ckbAbcdeCurlRetryFlagsForTest(): String {
    ckbAbcdeCurlRetryFlags()
}

private func ckbAbcdeRunMcpStdioSmoke(options: CkbAbcdeRunnerOptions, groupRoot: String): Unit {
    let requests = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"ckb-abcde-runner\",\"version\":\"1.0\"}}}\n" +
        "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\",\"params\":{}}\n" +
        "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\",\"params\":{}}\n" +
        "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"cangjie_knowledge_pack\",\"arguments\":{\"task\":\"Cangjie ArrayList basic syntax\",\"targetVersion\":\"1.0.0\",\"budget\":2}}}\n"
    ckbAbcdeWriteText("${groupRoot}/mcp-stdio-smoke-requests.jsonl", requests)
    let script = "cat ${ckbAbcdeShellQuote("${groupRoot}/mcp-stdio-smoke-requests.jsonl")} | ( " +
        ckbAbcdeNativeTlsBootstrapScript(options.ckbBin, ["--store", options.ckbStore, "mcp-stdio"]) +
        " ) > ${ckbAbcdeShellQuote("${groupRoot}/mcp-stdio-smoke.stdout.jsonl")} 2> ${ckbAbcdeShellQuote("${groupRoot}/mcp-stdio-smoke.stderr.log")}"
    let result = ckbAbcdeRunShell(script, "")
    let stdout = ckbAbcdeReadText("${groupRoot}/mcp-stdio-smoke.stdout.jsonl")
    let ok = result.exitCode == 0 && stdout.contains("cangjie_knowledge_pack")
    ckbAbcdeWriteText("${groupRoot}/mcp-stdio-tools-list.json", "{\"exitCode\":${result.exitCode},\"knowledgePackCallOk\":${ok},\"toolNamesContainsKnowledgePack\":${stdout.contains("cangjie_knowledge_pack")}}\n")
}

private func ckbAbcdeRunMcpHttpSmoke(options: CkbAbcdeRunnerOptions, groupRoot: String): Unit {
    let initBody = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"ckb-abcde-runner\",\"version\":\"1.0\"}}}"
    ckbAbcdeWriteText("${groupRoot}/mcp-http-initialize-request.json", initBody)
    let script = "curl --max-time 5 -i -sS -X POST -H 'Accept: application/json, text/event-stream' -H 'Content-Type: application/json' --data-binary @${ckbAbcdeShellQuote("${groupRoot}/mcp-http-initialize-request.json")} ${ckbAbcdeShellQuote("${options.ckbHttpBase}/mcp")} > ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-initialize-response.txt")} 2> ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-initialize.stderr.log")}; " +
        "sid=$(grep -i '^mcp-session-id:' ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-initialize-response.txt")} | head -n1 | cut -d' ' -f2 | tr -d '\\r'); " +
        "printf '%s\\n' \"$sid\" > ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-session-id.txt")}; " +
        "if [ -z \"$sid\" ]; then exit 4; fi; " +
        "curl --max-time 5 -fsS -N -H 'Accept: text/event-stream' -H \"Mcp-Session-Id: $sid\" -H 'MCP-Protocol-Version: 2025-06-18' ${ckbAbcdeShellQuote("${options.ckbHttpBase}/mcp")}"
    let get = ckbAbcdeRunShell(script, "")
    ckbAbcdeWriteText("${groupRoot}/mcp-http-smoke.stdout.log", get.stdout)
    ckbAbcdeWriteText("${groupRoot}/mcp-http-smoke.stderr.log", get.stderr)
    let ready = get.stdout.contains("event") || get.stdout.contains("ready")
    ckbAbcdeWriteText("${groupRoot}/mcp-http-smoke.json", "{\"exitCode\":${get.exitCode},\"ok\":${get.exitCode == 0 || ready},\"sseReady\":${ready}}\n")
}

private func ckbAbcdePreflight(options: CkbAbcdeRunnerOptions, runRoot: String): CkbAbcdePreflightResult {
    let result = CkbAbcdePreflightResult()
    result.add("runs_root", exists(Path(options.runsRoot)), options.runsRoot)
    result.add("run_root_created", exists(Path(runRoot)), runRoot)
    result.add("ckb_bin", exists(Path(options.ckbBin)), options.ckbBin)
    result.add("ckb_store", exists(Path(options.ckbStore)), options.ckbStore)
    result.add("dataset_root", exists(Path(options.datasetRoot)), options.datasetRoot)
    result.add("manifest", exists(Path(options.manifestPath)) && ckbAbcdeManifestLineCount(options.manifestPath) == 164, "lines=${ckbAbcdeManifestLineCount(options.manifestPath)}")
    result.add("humaneval_cases", ckbAbcdeCaseLayoutOk(options.datasetRoot), "CJ-HUMANEVAL-000..163 required files")
    result.add("docs_root", exists(Path(options.docsRoot)) && exists(Path("${options.docsRoot}/dev-guide/summary_cjnative_EN.md")) && exists(Path("${options.docsRoot}/tools/summary_cjnative_EN.md")), options.docsRoot)
    result.add("claude_cli", ckbAbcdeRunShell("command -v claude >/dev/null && claude --version >/dev/null", "").exitCode == 0, "claude command available")
    result.add("claude_glm52_settings", ckbAbcdeClaudeSettingsLooksGlm52(), "~/.claude/settings.json model keys")
    result.add("cjpm_cli", ckbAbcdeRunShell("command -v cjpm >/dev/null && cjpm --version >/dev/null", "").exitCode == 0, "cjpm command available")
    result.add("ckb_http_health", ckbAbcdeRunShell("curl --max-time 5 -fsS ${ckbAbcdeShellQuote("${options.ckbHttpBase}/v1/health")} >/dev/null", "").exitCode == 0, options.ckbHttpBase)
    result.add("ckb_http_schema", ckbAbcdeRunShell("curl --max-time 5 -fsS ${ckbAbcdeShellQuote("${options.ckbHttpBase}/v1/schema")} | grep -q cangjie_knowledge_pack", "").exitCode == 0, "${options.ckbHttpBase}/v1/schema")
    let stdioRoot = "${runRoot}/preflight-stdio"
    ckbAbcdeEnsureDir(stdioRoot)
    ckbAbcdeRunMcpStdioSmoke(options, stdioRoot)
    let stdioJson = ckbAbcdeReadText("${stdioRoot}/mcp-stdio-tools-list.json")
    result.add("mcp_stdio", stdioJson.contains("\"knowledgePackCallOk\":true"), "${stdioRoot}/mcp-stdio-tools-list.json")
    let httpRoot = "${runRoot}/preflight-http"
    ckbAbcdeEnsureDir(httpRoot)
    ckbAbcdeRunMcpHttpSmoke(options, httpRoot)
    let httpJson = ckbAbcdeReadText("${httpRoot}/mcp-http-smoke.json")
    result.add("mcp_http", httpJson.contains("\"ok\":true"), "${httpRoot}/mcp-http-smoke.json")
    result
}

private func ckbAbcdeRenderPreflightJson(options: CkbAbcdeRunnerOptions, runRoot: String, result: CkbAbcdePreflightResult): String {
    var checks = ""
    for (i in 0..result.checks.size) {
        if (i > 0) {
            checks += ","
        }
        checks += result.checks[i]
    }
    "{\"ok\":${result.ok},\"runRoot\":\"${ckbAbcdeJsonEscape(runRoot)}\",\"runsRoot\":\"${ckbAbcdeJsonEscape(options.runsRoot)}\",\"model\":\"GLM-5.2\",\"caseStart\":${options.caseStart},\"caseEnd\":${options.caseEnd},\"checks\":[${checks}]}\n"
}

private func ckbAbcdeRenderPreflightMarkdown(options: CkbAbcdeRunnerOptions, runRoot: String, result: CkbAbcdePreflightResult): String {
    var out = "# CKB ABCDE Benchmark Preflight\n\n"
    out += "- ok: ${result.ok}\n"
    out += "- runRoot: `${runRoot}`\n"
    out += "- runsRoot: `${options.runsRoot}`\n"
    out += "- model: `GLM-5.2`\n"
    out += "- cases: `${options.caseStart}..${options.caseEnd}`\n\n"
    out += "## Checks\n\n"
    for (check in result.checks) {
        out += "- `${check}`\n"
    }
    if (result.diagnostics.size > 0) {
        out += "\n## Diagnostics\n\n"
        for (diagnostic in result.diagnostics) {
            out += "- ${diagnostic}\n"
        }
    }
    out
}

private func ckbAbcdeWriteSummary(runRoot: String): Unit {
    let results = ckbAbcdeReadText("${runRoot}/results.jsonl")
    let lines = results.split("\n")
    let total = ckbAbcdeSummaryTotalForGroup(lines, "ALL")
    let passed = ckbAbcdeSummaryPassedForGroup(lines, "ALL")
    let passAt1 = ckbAbcdeSummaryPassAt1ForGroup(lines, "ALL")
    var csv = "group,total,passed,failed,pass_at_1,average_token_per_case,average_llm_turns_per_case,usage_parse_failed\n"
    csv += ckbAbcdeRenderSummaryCsvRow("ALL", lines)
    csv += ckbAbcdeRenderSummaryCsvRow(CkbAbcdeGroups.A, lines)
    csv += ckbAbcdeRenderSummaryCsvRow(CkbAbcdeGroups.B, lines)
    csv += ckbAbcdeRenderSummaryCsvRow(CkbAbcdeGroups.C, lines)
    csv += ckbAbcdeRenderSummaryCsvRow(CkbAbcdeGroups.D, lines)
    csv += ckbAbcdeRenderSummaryCsvRow(CkbAbcdeGroups.E, lines)
    ckbAbcdeWriteText("${runRoot}/summary.csv", csv)

    var md = "# CKB ABCDE Benchmark Summary\n\n"
    md += "- total: ${total}\n"
    md += "- passed: ${passed}\n"
    md += "- failed: ${total - passed}\n"
    md += "- pass@1: ${passAt1}\n"
    md += "- results: `${runRoot}/results.jsonl`\n"
    md += "- case usage summary: `${runRoot}/case-usage-summary.csv`\n\n"
    md += "| Group | total | passed | failed | pass@1 | avg token/case | avg llm turns/case | usage parse failed |\n"
    md += "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n"
    md += ckbAbcdeRenderSummaryMarkdownRow("ALL", lines)
    md += ckbAbcdeRenderSummaryMarkdownRow(CkbAbcdeGroups.A, lines)
    md += ckbAbcdeRenderSummaryMarkdownRow(CkbAbcdeGroups.B, lines)
    md += ckbAbcdeRenderSummaryMarkdownRow(CkbAbcdeGroups.C, lines)
    md += ckbAbcdeRenderSummaryMarkdownRow(CkbAbcdeGroups.D, lines)
    md += ckbAbcdeRenderSummaryMarkdownRow(CkbAbcdeGroups.E, lines)
    ckbAbcdeWriteText("${runRoot}/summary.md", md)
}

private func ckbAbcdeRenderSummaryCsvRow(group: String, lines: Array<String>): String {
    let total = ckbAbcdeSummaryTotalForGroup(lines, group)
    let passed = ckbAbcdeSummaryPassedForGroup(lines, group)
    let passAt1 = ckbAbcdeSummaryPassAt1ForGroup(lines, group)
    let usageOk = ckbAbcdeSummaryUsageOkForGroup(lines, group)
    let tokenTotal = ckbAbcdeSummaryTokenTotalForGroup(lines, group)
    let turnTotal = ckbAbcdeSummaryTurnTotalForGroup(lines, group)
    "${group},${total},${passed},${total - passed},${passAt1},${ckbAbcdeAverageText(tokenTotal, usageOk)},${ckbAbcdeAverageText(turnTotal, usageOk)},${total - usageOk}\n"
}

private func ckbAbcdeRenderSummaryMarkdownRow(group: String, lines: Array<String>): String {
    let total = ckbAbcdeSummaryTotalForGroup(lines, group)
    let passed = ckbAbcdeSummaryPassedForGroup(lines, group)
    let passAt1 = ckbAbcdeSummaryPassAt1ForGroup(lines, group)
    let usageOk = ckbAbcdeSummaryUsageOkForGroup(lines, group)
    let tokenTotal = ckbAbcdeSummaryTokenTotalForGroup(lines, group)
    let turnTotal = ckbAbcdeSummaryTurnTotalForGroup(lines, group)
    "| ${group} | ${total} | ${passed} | ${total - passed} | ${passAt1} | ${ckbAbcdeAverageText(tokenTotal, usageOk)} | ${ckbAbcdeAverageText(turnTotal, usageOk)} | ${total - usageOk} |\n"
}

private func ckbAbcdeSummaryTotalForGroup(lines: Array<String>, group: String): Int64 {
    var total: Int64 = 0
    for (line in lines) {
        if (line.trimAscii() == "") {
            continue
        }
        if (ckbAbcdeSummaryLineMatchesGroup(line, group)) {
            total += 1
        }
    }
    total
}

private func ckbAbcdeSummaryPassedForGroup(lines: Array<String>, group: String): Int64 {
    var passed: Int64 = 0
    for (line in lines) {
        if (line.trimAscii() != "" && ckbAbcdeSummaryLineMatchesGroup(line, group) && line.contains("\"status\":\"passed\"")) {
            passed += 1
        }
    }
    passed
}

private func ckbAbcdeSummaryPassAt1ForGroup(lines: Array<String>, group: String): Int64 {
    var passAt1: Int64 = 0
    for (line in lines) {
        if (line.trimAscii() != "" && ckbAbcdeSummaryLineMatchesGroup(line, group) && line.contains("\"unitPassAt1\":true")) {
            passAt1 += 1
        }
    }
    passAt1
}

private func ckbAbcdeSummaryUsageOkForGroup(lines: Array<String>, group: String): Int64 {
    var ok: Int64 = 0
    for (line in lines) {
        if (line.trimAscii() != "" && ckbAbcdeSummaryLineMatchesGroup(line, group) && line.contains("\"usageParseStatus\":\"ok\"")) {
            ok += 1
        }
    }
    ok
}

private func ckbAbcdeSummaryTokenTotalForGroup(lines: Array<String>, group: String): Int64 {
    var total: Int64 = 0
    for (line in lines) {
        if (line.trimAscii() != "" && ckbAbcdeSummaryLineMatchesGroup(line, group) && line.contains("\"usageParseStatus\":\"ok\"")) {
            total += ckbAbcdeJsonIntField(line, "modelTotalTokens", 0)
        }
    }
    total
}

private func ckbAbcdeSummaryTurnTotalForGroup(lines: Array<String>, group: String): Int64 {
    var total: Int64 = 0
    for (line in lines) {
        if (line.trimAscii() != "" && ckbAbcdeSummaryLineMatchesGroup(line, group) && line.contains("\"usageParseStatus\":\"ok\"")) {
            total += ckbAbcdeJsonIntField(line, "llmTurnCount", 0)
        }
    }
    total
}

private func ckbAbcdeSummaryLineMatchesGroup(line: String, group: String): Bool {
    group == "ALL" || line.contains("\"group\":\"${group}\"")
}

public func ckbAbcdeRenderEnvSwitchCheck(caseId: String, fromGroup: String, toGroup: String, workspace: String, groupRoot: String): String {
    let fromValue = if (fromGroup == "") { "START" } else { fromGroup }
    "{\"caseId\":\"${caseId}\",\"fromGroup\":\"${fromValue}\",\"toGroup\":\"${toGroup}\",\"cwd\":\"${ckbAbcdeJsonEscape(workspace)}\",\"mcpConfigPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/mcp-config.json")}\",\"knowledgeEntry\":\"${ckbAbcdeKnowledgeEntry(toGroup)}\",\"toolTransport\":\"${ckbAbcdeToolTransport(toGroup)}\",\"cleanupAction\":\"fresh_group_workspace_and_strict_mcp_config\",\"ok\":true}\n".trimAscii()
}

public func ckbAbcdeRenderCaseResult(
    options: CkbAbcdeRunnerOptions,
    runRoot: String,
    caseId: String,
    group: String,
    status: String,
    claudeExitCode: Int64,
    testExitCode: Int64,
    unitPass: Bool,
    unitPassAt1: Bool,
    failureType: String,
    toolEvidence: String,
    violation: String,
    groupRoot: String
): String {
    let protocolViolation = violation != "none"
    let modelRunStatus = if (claudeExitCode == 0) { "ok" } else { "failed" }
    let toolCallCount = ckbAbcdeToolCallCount(group, toolEvidence)
    let firstClaudeExitCode = ckbAbcdeFirstClaudeAttemptExitCode(groupRoot)
    let claudeAttemptCount = ckbAbcdeClaudeAttemptCount(groupRoot)
    let usage = ckbAbcdeParseClaudeUsageFile("${groupRoot}/claude-transcript.jsonl")
    "{\"runId\":\"${ckbAbcdeJsonEscape(options.runId)}\",\"benchmark\":\"Cangjie-HumanEval\",\"caseId\":\"${caseId}\",\"group\":\"${group}\",\"model\":\"GLM-5.2\",\"claudeCodeVersion\":\"${ckbAbcdeJsonEscape(ckbAbcdeClaudeVersion())}\",\"knowledgeEntry\":\"${ckbAbcdeKnowledgeEntry(group)}\",\"preflightStatus\":\"ok\",\"modelRunStatus\":\"${modelRunStatus}\",\"status\":\"${status}\",\"claudeExitCode\":${claudeExitCode},\"firstClaudeExitCode\":${firstClaudeExitCode},\"claudeAttemptCount\":${claudeAttemptCount},\"testExitCode\":${testExitCode},\"unitPass\":${unitPass},\"unitPassAt1\":${unitPassAt1},\"failureType\":\"${failureType}\",\"usageParseStatus\":\"${usage.usageParseStatus}\",\"modelInputTokens\":${usage.modelInputTokens},\"modelOutputTokens\":${usage.modelOutputTokens},\"modelCacheReadTokens\":${usage.modelCacheReadTokens},\"modelCacheCreationTokens\":${usage.modelCacheCreationTokens},\"modelTotalTokens\":${usage.modelTotalTokens},\"llmTurnCount\":${usage.llmTurnCount},\"usageSourcePath\":\"${ckbAbcdeJsonEscape(usage.usageSourcePath)}\",\"ckbUsed\":${ckbAbcdeUsesCkb(group)},\"localDocsUsed\":${group == CkbAbcdeGroups.E},\"toolTransport\":\"${ckbAbcdeToolTransport(group)}\",\"toolCallCount\":${toolCallCount},\"toolEvidence\":\"${ckbAbcdeJsonEscape(toolEvidence)}\",\"knowledgeVersion\":\"${ckbAbcdeJsonEscape(ckbAbcdeKnowledgeVersion(groupRoot))}\",\"citationCount\":${ckbAbcdeCitationCount(groupRoot)},\"docsPathCount\":${if (group == CkbAbcdeGroups.E) { 2 } else { 0 }},\"protocolViolation\":${protocolViolation},\"protocolViolationReason\":\"${ckbAbcdeJsonEscape(violation)}\",\"durationMs\":0,\"promptPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/prompt.final.md")}\",\"transcriptPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/claude-transcript.jsonl")}\",\"testLogPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/test.log")}\",\"resultPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/case-result.json")}\",\"notes\":\"${ckbAbcdeJsonEscape(ckbAbcdeResultNotes(status, violation, toolEvidence))}\"}"
}

private func ckbAbcdeRenderCaseSummary(options: CkbAbcdeRunnerOptions, runRoot: String, caseId: String, summaries: ArrayList<String>): String {
    var rows = ""
    var failed: Int64 = 0
    var violations: Int64 = 0
    var usageOk: Int64 = 0
    var tokenTotal: Int64 = 0
    var turnTotal: Int64 = 0
    var usageFailedGroups = ""
    for (i in 0..summaries.size) {
        if (i > 0) {
            rows += ","
        }
        rows += summaries[i]
        if (summaries[i].contains("\"status\":\"failed\"")) {
            failed += 1
        }
        if (summaries[i].contains("\"protocolViolation\":true")) {
            violations += 1
        }
        if (summaries[i].contains("\"usageParseStatus\":\"ok\"")) {
            usageOk += 1
            tokenTotal += ckbAbcdeJsonIntField(summaries[i], "modelTotalTokens", 0)
            turnTotal += ckbAbcdeJsonIntField(summaries[i], "llmTurnCount", 0)
        } else {
            if (usageFailedGroups != "") {
                usageFailedGroups += ","
            }
            usageFailedGroups += "\"${ckbAbcdeJsonEscape(ckbAbcdeJsonStringField(summaries[i], "group"))}\""
        }
    }
    "{\"runId\":\"${ckbAbcdeJsonEscape(options.runId)}\",\"caseId\":\"${caseId}\",\"benchmark\":\"Cangjie-HumanEval\",\"completedGroups\":${summaries.size},\"failedGroups\":${failed},\"protocolViolationGroups\":${violations},\"usageParseOkGroupCount\":${usageOk},\"caseTotalModelTokens\":${tokenTotal},\"caseAverageModelTokensPerGroup\":${ckbAbcdeAverageText(tokenTotal, usageOk)},\"caseTotalLlmTurns\":${turnTotal},\"caseAverageLlmTurnsPerGroup\":${ckbAbcdeAverageText(turnTotal, usageOk)},\"usageParseFailedGroups\":[${usageFailedGroups}],\"resultRows\":[${rows}],\"caseResultPaths\":\"${ckbAbcdeJsonEscape("${runRoot}/cases/${caseId}")}\",\"envSwitchChecksPath\":\"${ckbAbcdeJsonEscape("${runRoot}/cases/${caseId}/env-switch-checks.jsonl")}\"}\n"
}

private func ckbAbcdeRenderCaseUsageSummaryCsvRow(caseId: String, summaries: ArrayList<String>): String {
    var usageOk: Int64 = 0
    var tokenTotal: Int64 = 0
    var turnTotal: Int64 = 0
    var failedGroups = ""
    for (summary in summaries) {
        if (summary.contains("\"usageParseStatus\":\"ok\"")) {
            usageOk += 1
            tokenTotal += ckbAbcdeJsonIntField(summary, "modelTotalTokens", 0)
            turnTotal += ckbAbcdeJsonIntField(summary, "llmTurnCount", 0)
        } else {
            if (failedGroups != "") {
                failedGroups += "|"
            }
            failedGroups += ckbAbcdeJsonStringField(summary, "group")
        }
    }
    "${caseId},${usageOk},${tokenTotal},${ckbAbcdeAverageText(tokenTotal, usageOk)},${turnTotal},${ckbAbcdeAverageText(turnTotal, usageOk)},${failedGroups}"
}

public func ckbAbcdeRenderCaseSummaryForTest(options: CkbAbcdeRunnerOptions, runRoot: String, caseId: String, summaries: ArrayList<String>): String {
    ckbAbcdeRenderCaseSummary(options, runRoot, caseId, summaries)
}

public func ckbAbcdeRenderCaseUsageSummaryCsvRowForTest(caseId: String, summaries: ArrayList<String>): String {
    ckbAbcdeRenderCaseUsageSummaryCsvRow(caseId, summaries)
}

private func ckbAbcdeToolEvidence(group: String, transcript: String): String {
    if (group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D) {
        for (line in transcript.split("\n")) {
            if (line.contains("\"subtype\":\"init\"")) {
                continue
            }
            if (line.contains("mcp__ckb-cangjie__cangjie_knowledge_pack") ||
                line.contains("mcp__ckb-cangjie-http__cangjie_knowledge_pack") ||
                line.contains("\"name\":\"cangjie_knowledge_pack\"")) {
                return "cangjie_knowledge_pack"
            }
        }
        return "manual_required"
    }
    "none"
}

public func ckbAbcdeToolEvidenceForTest(group: String, transcript: String): String {
    ckbAbcdeToolEvidence(group, transcript)
}

private func ckbAbcdeKnowledgeEntry(group: String): String {
    if (group == CkbAbcdeGroups.B) { return "ckb_rest" }
    if (group == CkbAbcdeGroups.C) { return "mcp_stdio" }
    if (group == CkbAbcdeGroups.D) { return "mcp_http" }
    if (group == CkbAbcdeGroups.E) { return "local_docs" }
    "none"
}

private func ckbAbcdeToolTransport(group: String): String {
    if (group == CkbAbcdeGroups.C) { return "stdio" }
    if (group == CkbAbcdeGroups.D) { return "streamable_http" }
    "none"
}

private func ckbAbcdeUsesCkb(group: String): Bool {
    group == CkbAbcdeGroups.B || group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D
}

private func ckbAbcdeToolCallCount(group: String, toolEvidence: String): Int64 {
    if ((group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D) && toolEvidence == "cangjie_knowledge_pack") {
        return 1
    }
    0
}

private func ckbAbcdeRequiredKnowledgeReady(group: String, knowledgeReady: Bool, toolEvidence: String): Bool {
    if (group == CkbAbcdeGroups.B) {
        return knowledgeReady
    }
    if (group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D) {
        return toolEvidence == "cangjie_knowledge_pack"
    }
    true
}

private func ckbAbcdeFailureType(claudeExitCode: Int64, testExitCode: Int64, unitPass: Bool, violation: String, testLog: String, toolReady: Bool): String {
    if (violation != "none") {
        return "protocol_violation"
    }
    if (claudeExitCode == 124) {
        return "timeout"
    }
    if (!toolReady) {
        return "tool_unavailable"
    }
    if (claudeExitCode != 0) {
        return "model_error"
    }
    if (unitPass) {
        return "none"
    }
    let lowered = testLog.toAsciiLower()
    if (testExitCode != 0 && (lowered.contains("compile") || lowered.contains("syntax") || lowered.contains("error:"))) {
        return "compile_error"
    }
    "unit_failure"
}

public func ckbAbcdeFailureTypeForTest(claudeExitCode: Int64, testExitCode: Int64, unitPass: Bool, violation: String, testLog: String, toolReady: Bool): String {
    ckbAbcdeFailureType(claudeExitCode, testExitCode, unitPass, violation, testLog, toolReady)
}

private func ckbAbcdeResultNotes(status: String, violation: String, toolEvidence: String): String {
    if (violation != "none") {
        return violation
    }
    if (toolEvidence == "manual_required") {
        return "tool evidence requires manual transcript review"
    }
    if (status == "failed") {
        return "see transcript and test log"
    }
    ""
}

private func ckbAbcdeClaudeVersion(): String {
    let result = ckbAbcdeRunShell("claude --version 2>/dev/null | head -n1", "")
    result.stdout.trimAscii()
}

private func ckbAbcdeKnowledgeVersion(groupRoot: String): String {
    let text = ckbAbcdeReadText("${groupRoot}/ckb-knowledge-pack.json") +
        ckbAbcdeReadText("${groupRoot}/ckb-context-pack.json") +
        ckbAbcdeReadText("${groupRoot}/claude-transcript.jsonl") +
        ckbAbcdeReadText("${groupRoot}/claude.stdout.log")
    ckbAbcdeJsonStringField(text, "knowledgeVersion")
}

private func ckbAbcdeCitationCount(groupRoot: String): Int64 {
    ckbAbcdeCountOccurrences(ckbAbcdeReadText("${groupRoot}/ckb-knowledge-pack.json") +
        ckbAbcdeReadText("${groupRoot}/ckb-context-pack.json") +
        ckbAbcdeReadText("${groupRoot}/claude-transcript.jsonl"), "\"citation\"")
}

private func ckbAbcdeCountOccurrences(text: String, needle: String): Int64 {
    if (needle == "" || text.size < needle.size) {
        return 0
    }
    let parts = text.split(needle)
    if (parts.size <= 1) { 0 } else { parts.size - 1 }
}

private func ckbAbcdeJsonStringField(text: String, field: String): String {
    let marker = "\"${field}\":\""
    let parts = text.split(marker)
    if (parts.size <= 1) {
        return ""
    }
    let tail = parts[1]
    match (tail.indexOf("\"")) {
        case Some(end) => tail[..end]
        case None => ""
    }
}

public func ckbAbcdeJsonStringFieldForTest(text: String, field: String): String {
    ckbAbcdeJsonStringField(text, field)
}

public func ckbAbcdeCountOccurrencesForTest(text: String, needle: String): Int64 {
    ckbAbcdeCountOccurrences(text, needle)
}

private func ckbAbcdeUnitPassAt1(unitPass: Bool, groupRoot: String): Bool {
    unitPass && ckbAbcdeFirstClaudeAttemptExitCode(groupRoot) == 0
}

private func ckbAbcdeFirstClaudeAttemptExitCode(groupRoot: String): Int64 {
    ckbAbcdeFirstClaudeAttemptExitCodeFromText(ckbAbcdeReadText("${groupRoot}/claude-attempts.jsonl"))
}

private func ckbAbcdeClaudeAttemptCount(groupRoot: String): Int64 {
    var count: Int64 = 0
    for (line in ckbAbcdeReadText("${groupRoot}/claude-attempts.jsonl").split("\n")) {
        if (line.contains("\"attempt\":")) {
            count += 1
        }
    }
    count
}

private func ckbAbcdeFirstClaudeAttemptExitCodeFromText(attempts: String): Int64 {
    for (line in attempts.split("\n")) {
        if (line.contains("\"attempt\":1")) {
            return ckbAbcdeJsonIntField(line, "exitCode", -1)
        }
    }
    -1
}

private func ckbAbcdeJsonIntField(text: String, field: String, fallback: Int64): Int64 {
    let parts = text.split("\"${field}\":")
    if (parts.size <= 1) {
        return fallback
    }
    var raw = parts[1]
    let commaParts = raw.split(",")
    if (commaParts.size > 0) {
        raw = commaParts[0]
    }
    let braceParts = raw.split("}")
    if (braceParts.size > 0) {
        raw = braceParts[0]
    }
    ckbAbcdeParseInt(raw.trimAscii(), fallback)
}

private func ckbAbcdeParseClaudeUsageFile(path: String): CkbAbcdeUsageStats {
    ckbAbcdeParseClaudeUsageFromText(ckbAbcdeReadText(path), path)
}

public func ckbAbcdeParseClaudeUsageFromText(transcript: String, sourcePath: String): CkbAbcdeUsageStats {
    let stats = CkbAbcdeUsageStats()
    stats.usageSourcePath = sourcePath
    var resultLine = ""
    for (line in transcript.split("\n")) {
        if (ckbAbcdeTranscriptLineIsResult(line)) {
            resultLine = line
        }
    }
    if (resultLine == "") {
        stats.usageParseStatus = "missing_result"
        return stats
    }

    let inputTokens = ckbAbcdeJsonIntFieldAny(resultLine, "input_tokens", "inputTokens", "modelInputTokens", -1)
    let outputTokens = ckbAbcdeJsonIntFieldAny(resultLine, "output_tokens", "outputTokens", "modelOutputTokens", -1)
    let cacheReadTokens = ckbAbcdeJsonIntFieldAny(resultLine, "cache_read_input_tokens", "cacheReadInputTokens", "modelCacheReadTokens", 0)
    let cacheCreationTokens = ckbAbcdeJsonIntFieldAny(resultLine, "cache_creation_input_tokens", "cacheCreationInputTokens", "modelCacheCreationTokens", 0)
    let explicitTotal = ckbAbcdeJsonIntFieldAny(resultLine, "total_tokens", "totalTokens", "modelTotalTokens", -1)
    let turns = ckbAbcdeJsonIntFieldAny(resultLine, "num_turns", "numTurns", "llmTurnCount", -1)

    let computedTotal = ckbAbcdeNonNegative(inputTokens) + ckbAbcdeNonNegative(outputTokens) + cacheReadTokens + cacheCreationTokens
    let total = if (explicitTotal >= 0) { explicitTotal } else { computedTotal }
    if (turns < 0 || total <= 0 || inputTokens < 0 || outputTokens < 0) {
        stats.usageParseStatus = "missing_usage"
        return stats
    }

    stats.usageParseStatus = "ok"
    stats.modelInputTokens = inputTokens
    stats.modelOutputTokens = outputTokens
    stats.modelCacheReadTokens = cacheReadTokens
    stats.modelCacheCreationTokens = cacheCreationTokens
    stats.modelTotalTokens = total
    stats.llmTurnCount = turns
    stats
}

public func ckbAbcdeRenderUsageJson(stats: CkbAbcdeUsageStats): String {
    "{\"usageParseStatus\":\"${stats.usageParseStatus}\",\"modelInputTokens\":${stats.modelInputTokens},\"modelOutputTokens\":${stats.modelOutputTokens},\"modelCacheReadTokens\":${stats.modelCacheReadTokens},\"modelCacheCreationTokens\":${stats.modelCacheCreationTokens},\"modelTotalTokens\":${stats.modelTotalTokens},\"llmTurnCount\":${stats.llmTurnCount},\"usageSourcePath\":\"${ckbAbcdeJsonEscape(stats.usageSourcePath)}\"}"
}

private func ckbAbcdeTranscriptLineIsResult(line: String): Bool {
    (line.contains("\"type\":\"result\"") || line.contains("\"type\": \"result\"")) &&
        !line.contains("\"subtype\":\"init\"")
}

private func ckbAbcdeJsonIntFieldAny(text: String, fieldA: String, fieldB: String, fieldC: String, fallback: Int64): Int64 {
    let a = ckbAbcdeJsonIntField(text, fieldA, fallback)
    if (a != fallback) {
        return a
    }
    let b = ckbAbcdeJsonIntField(text, fieldB, fallback)
    if (b != fallback) {
        return b
    }
    ckbAbcdeJsonIntField(text, fieldC, fallback)
}

private func ckbAbcdeNonNegative(value: Int64): Int64 {
    if (value < 0) { 0 } else { value }
}

private func ckbAbcdeAverageText(total: Int64, count: Int64): String {
    if (count <= 0) {
        return "null"
    }
    let whole = total / count
    let remainder = total % count
    if (remainder == 0) {
        return "${whole}"
    }
    let tenth = (remainder * 10) / count
    "${whole}.${tenth}"
}

public func ckbAbcdeAverageTextForTest(total: Int64, count: Int64): String {
    ckbAbcdeAverageText(total, count)
}

public func ckbAbcdeUnitPassAt1FromAttemptsForTest(unitPass: Bool, attempts: String): Bool {
    unitPass && ckbAbcdeFirstClaudeAttemptExitCodeFromText(attempts) == 0
}

private func ckbAbcdeTestLogContainsFailure(testLog: String): Bool {
    testLog.contains("CangjieEval failure") ||
        testLog.contains("An exception has occurred") ||
        testLog.contains("FAILED") ||
        testLog.contains("Error: cjpm run failed")
}

private func ckbAbcdeForbiddenEvidence(group: String, transcript: String): String {
    let lowered = transcript.toAsciiLower()
    if (group == CkbAbcdeGroups.A && (lowered.contains("cangjie_knowledge_pack") || lowered.contains("/v1/cangjie") || lowered.contains("cangjie_docs-release"))) {
        return "forbidden_knowledge_entry"
    }
    if (group == CkbAbcdeGroups.B && (lowered.contains("mcp__") || lowered.contains("cangjie_docs-release"))) {
        return "forbidden_tool_or_docs_entry"
    }
    if ((group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D) && lowered.contains("cangjie_docs-release")) {
        return "forbidden_local_docs_entry"
    }
    if (group == CkbAbcdeGroups.E && (lowered.contains("mcp__") || lowered.contains("/v1/cangjie"))) {
        return "forbidden_ckb_entry"
    }
    if (group == CkbAbcdeGroups.E) {
        let eViolation = ckbAbcdeForbiddenLocalDocsEvidence(transcript)
        if (eViolation != "none") {
            return eViolation
        }
    }
    "none"
}

public func ckbAbcdeForbiddenEvidenceForTest(group: String, transcript: String): String {
    ckbAbcdeForbiddenEvidence(group, transcript)
}

private func ckbAbcdeForbiddenLocalDocsEvidence(transcript: String): String {
    for (line in transcript.split("\n")) {
        let lowered = line.toAsciiLower()
        if (lowered.contains("\"type\":\"tool_use\"") &&
            (lowered.contains("\"name\":\"webfetch\"") || lowered.contains("\"name\":\"websearch\"") ||
             lowered.contains("\"name\":\"task\"") || lowered.contains("\"name\":\"askuserquestion\""))) {
            return "forbidden_e_tool_use"
        }
    }
    "none"
}

private func ckbAbcdeRunShell(script: String, cwd: String): CkbAbcdeCommandResult {
    let result = CkbAbcdeCommandResult()
    let finalScript = if (cwd == "") { script } else { "cd ${ckbAbcdeShellQuote(cwd)} && ${script}" }
    try {
        let process = launch("/bin/zsh", ["-lc", finalScript], stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
        result.stdout = ckbAbcdeSafeReadPipe(process.stdOutPipe)
        result.stderr = ckbAbcdeSafeReadPipe(process.stdErrPipe)
        result.exitCode = process.wait()
    } catch (e: Exception) {
        result.exitCode = 127
        result.stderr = "launch_failed"
    }
    result
}

private func ckbAbcdeSafeReadPipe(pipe: InputStream): String {
    try {
        StringReader<InputStream>(pipe).readToEnd()
    } catch (_: Exception) {
        "invalid_response_encoding"
    }
}

private func ckbAbcdeReadText(path: String): String {
    try {
        String.fromUtf8(File.readFrom(Path(path)))
    } catch (_: Exception) {
        ""
    }
}

private func ckbAbcdeWriteText(path: String, text: String): Unit {
    let target = Path(path)
    if (!exists(target.parent)) {
        Directory.create(target.parent, recursive: true)
    }
    File.writeTo(target, text.toArray())
}

private func ckbAbcdeAppendText(path: String, text: String): Unit {
    let existing = if (exists(Path(path))) { ckbAbcdeReadText(path) } else { "" }
    ckbAbcdeWriteText(path, existing + text)
}

private func ckbAbcdeEnsureDir(path: String): Unit {
    if (!exists(Path(path))) {
        Directory.create(Path(path), recursive: true)
    }
}

private func ckbAbcdeCaseLayoutOk(datasetRoot: String): Bool {
    for (i in 0..164) {
        let caseRoot = "${datasetRoot}/${ckbAbcdeCaseId(i)}"
        if (!exists(Path("${caseRoot}/metadata.json")) ||
            !exists(Path("${caseRoot}/prompt.md")) ||
            !exists(Path("${caseRoot}/starter/cjpm.toml")) ||
            !exists(Path("${caseRoot}/starter/src/solution.cj")) ||
            !exists(Path("${caseRoot}/starter/src/eval_support.cj")) ||
            !exists(Path("${caseRoot}/tests/TestMain.cj")) ||
            !exists(Path("${caseRoot}/tests/cjpm.executable.toml"))) {
            return false
        }
    }
    true
}

private func ckbAbcdeManifestLineCount(path: String): Int64 {
    var count: Int64 = 0
    for (line in ckbAbcdeReadText(path).split("\n")) {
        if (line.trimAscii() != "") {
            count += 1
        }
    }
    count
}

private func ckbAbcdeClaudeSettingsLooksGlm52(): Bool {
    let home = match (getVariable("HOME")) {
        case Some(value) => value
        case None => ""
    }
    if (home == "") {
        return false
    }
    let text = ckbAbcdeReadText("${home}/.claude/settings.json")
    text.contains("GLM-5.2") &&
        text.contains("ANTHROPIC_MODEL") &&
        text.contains("ANTHROPIC_DEFAULT_OPUS_MODEL") &&
        text.contains("ANTHROPIC_DEFAULT_SONNET_MODEL") &&
        text.contains("ANTHROPIC_DEFAULT_HAIKU_MODEL") &&
        text.contains("CLAUDE_CODE_SUBAGENT_MODEL")
}

private func ckbAbcdeGeneratedRunId(): String {
    let result = ckbAbcdeRunShell("date +%Y%m%d-%H%M%S", "")
    let value = result.stdout.trimAscii()
    if (value == "") { "manual" } else { value }
}

private func ckbAbcdeDefaultRepoRoot(): String {
    match (getVariable("CKB_REPO_ROOT")) {
        case Some(value) => value
        case None => "/Users/l3gi0n/work/workspace_cangjie/CangjieCommunityKnowledgeBase"
    }
}

public func ckbAbcdeOptionsSafetyDiagnostic(options: CkbAbcdeRunnerOptions): String {
    if (options.runsRoot != "/Users/l3gi0n/Downloads/ckbtest") {
        return "runs_root_must_be_/Users/l3gi0n/Downloads/ckbtest"
    }
    if (!ckbAbcdeSafePathSegment(options.runId)) {
        return "unsafe_run_id"
    }
    if (options.caseStart < 0 || options.caseEnd > 163 || options.caseStart > options.caseEnd) {
        return "case_range_must_be_0_163"
    }
    if (options.groups.size == 0) {
        return "groups_must_not_be_empty"
    }
    if (!options.ckbHttpBase.startsWith("http://127.0.0.1:") && !options.ckbHttpBase.startsWith("http://localhost:")) {
        return "ckb_http_base_must_be_loopback_http"
    }
    "ok"
}

private func ckbAbcdeSafePathSegment(value: String): Bool {
    let trimmed = value.trimAscii()
    if (trimmed == "" || trimmed == "." || trimmed == "..") {
        return false
    }
    if (trimmed.contains("/") || trimmed.contains("\\") || trimmed.contains("..") ||
        trimmed.contains("$") || trimmed.contains("'") || trimmed.contains("\"") ||
        trimmed.contains("`") || trimmed.contains("\n") || trimmed.contains("\r")) {
        return false
    }
    true
}

private func ckbAbcdeParseInt(value: String, fallback: Int64): Int64 {
    try {
        Int64.parse(value)
    } catch (_: Exception) {
        fallback
    }
}

private func ckbAbcdeParseCaseIndex(value: String): Int64 {
    let trimmed = value.trimAscii()
    if (trimmed.startsWith("CJ-HUMANEVAL-")) {
        return ckbAbcdeParseInt(trimmed.replace("CJ-HUMANEVAL-", ""), 0)
    }
    ckbAbcdeParseInt(trimmed, 0)
}

private func ckbAbcdeParseGroups(value: String): ArrayList<String> {
    let groups = ArrayList<String>()
    for (raw in value.split(",")) {
        let item = raw.trimAscii()
        let group = if (item == "A" || item == CkbAbcdeGroups.A) {
            CkbAbcdeGroups.A
        } else if (item == "B" || item == CkbAbcdeGroups.B) {
            CkbAbcdeGroups.B
        } else if (item == "C" || item == CkbAbcdeGroups.C) {
            CkbAbcdeGroups.C
        } else if (item == "D" || item == CkbAbcdeGroups.D) {
            CkbAbcdeGroups.D
        } else if (item == "E" || item == CkbAbcdeGroups.E) {
            CkbAbcdeGroups.E
        } else {
            ""
        }
        if (group != "") {
            groups.add(group)
        }
    }
    groups
}

private func ckbAbcdeCaseId(index: Int64): String {
    if (index < 10) {
        return "CJ-HUMANEVAL-00${index}"
    }
    if (index < 100) {
        return "CJ-HUMANEVAL-0${index}"
    }
    "CJ-HUMANEVAL-${index}"
}

private func ckbAbcdeShellQuote(value: String): String {
    "'" + value.replace("'", "'\\''") + "'"
}

public func ckbAbcdeNativeTlsBootstrapScript(command: String, args: Array<String>): String {
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
        "exec " + ckbAbcdeShellQuote(command)
    for (arg in args) {
        script += " " + ckbAbcdeShellQuote(arg)
    }
    script
}

private func ckbAbcdeUsage(): String {
    "Usage: cangjie_community_knowledge_base cangjie-eval-abcde [--preflight-only] [--skip-claude] [--run-id <id>] [--case-id CJ-HUMANEVAL-000|--case-start 0 --case-end 9] [--groups A,B,C,D,E] [--runs-root /Users/l3gi0n/Downloads/ckbtest] [--ckb-http-base http://127.0.0.1:18890] [--ckb-bin <path>] [--ckb-store <path>] [--dataset-root <path>] [--manifest <path>] [--docs-root <path>]\n"
}
