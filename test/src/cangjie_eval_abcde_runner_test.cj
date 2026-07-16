package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.*
import std.fs.{Directory, File, Path, exists}

@Test
public class CangjieEvalAbcdeRunnerTest {
    @TestCase
    public func ckg12Ut001ParsesCaseIdGroupsAndSkipClaude(): Unit {
        let options = parseCkbAbcdeRunnerOptions(["cangjie-eval-abcde", "--case-id", "CJ-HUMANEVAL-007", "--groups", "A,C,E", "--skip-claude"])

        @Expect(options.caseStart, 7)
        @Expect(options.caseEnd, 7)
        @Expect(options.skipClaude, true)
        @Expect(options.groups.size, 3)
        @Expect(options.groups[0], CkbAbcdeGroups.A)
        @Expect(options.groups[1], CkbAbcdeGroups.C)
        @Expect(options.groups[2], CkbAbcdeGroups.E)
    }

    @TestCase
    public func ckg12Pos001PromptPoliciesAreGroupSpecific(): Unit {
        let task = "Implement `src/solution.cj`."
        let promptA = renderCkbAbcdePrompt(CkbAbcdeGroups.A, "CJ-HUMANEVAL-000", task, "")
        let canonicalContext = "{\"taskId\":\"CJ-HUMANEVAL-000\",\"targetVersion\":\"1.0.0\"}"
        let restResponse = "{\"ok\":true,\"data\":{\"versionResolution\":{\"targetVersion\":\"1.0.0\"}}}"
        let promptB = renderCkbAbcdePrompt(CkbAbcdeGroups.B, "CJ-HUMANEVAL-000", task, canonicalContext + "\n---CKB_RESPONSE---\n" + restResponse)
        let promptC = renderCkbAbcdePrompt(CkbAbcdeGroups.C, "CJ-HUMANEVAL-000", task, canonicalContext)
        let promptD = renderCkbAbcdePrompt(CkbAbcdeGroups.D, "CJ-HUMANEVAL-000", task, canonicalContext)
        let promptE = renderCkbAbcdePrompt(CkbAbcdeGroups.E, "CJ-HUMANEVAL-000", task, "")

        @Expect(promptA.contains("No CKB baseline"), true)
        @Expect(promptA.contains("cangjie_docs-release"), false)
        @Expect(promptA.contains("Use at most three knowledge or documentation lookup tool calls"), true)
        @Expect(promptA.contains("still edit exactly `src/solution.cj`"), true)
        @Expect(promptB.contains("CKB REST Context"), true)
        @Expect(promptB.contains(restResponse), true)
        @Expect(promptB.contains("Canonical CKB Task Context"), true)
        @Expect(promptB.contains(canonicalContext), true)
        @Expect(promptC.contains("must call `mcp__ckb-cangjie__cangjie_task_knowledge_pack`"), true)
        @Expect(promptC.contains(canonicalContext), true)
        @Expect(promptC.contains("invalid without that real tool call"), true)
        @Expect(promptD.contains("must call `mcp__ckb-cangjie-http__cangjie_task_knowledge_pack`"), true)
        @Expect(promptD.contains(canonicalContext), true)
        @Expect(promptD.contains("even if the task looks trivial"), true)
        @Expect(promptE.contains("summary_cjnative_EN.md"), true)
        @Expect(promptE.contains("You may use local official Cangjie docs"), true)
        @Expect(promptE.contains("targeted read-only Bash rg queries"), true)
        @Expect(promptE.contains("focused Read calls"), true)
        @Expect(promptE.contains("read-only inspection inside the current temporary workspace"), true)
        @Expect(promptE.contains("read-only documentation queries"), true)
        @Expect(promptE.contains("prefer absolute paths"), true)
        @Expect(promptE.contains("do not rely on `cd` followed by later relative documentation queries"), true)
    }

    @TestCase
    public func ckg12Pos002McpConfigsSeparateStdioHttpAndEmptyGroups(): Unit {
        let stdio = renderCkbAbcdeMcpConfig(CkbAbcdeGroups.C, "/tmp/ckb", "/tmp/store", "http://127.0.0.1:18890")
        let http = renderCkbAbcdeMcpConfig(CkbAbcdeGroups.D, "/tmp/ckb", "/tmp/store", "http://127.0.0.1:18890")
        let empty = renderCkbAbcdeMcpConfig(CkbAbcdeGroups.A, "/tmp/ckb", "/tmp/store", "http://127.0.0.1:18890")

        @Expect(stdio.contains("\"command\": \"/bin/zsh\""), true)
        @Expect(stdio.contains("mcp-stdio"), true)
        @Expect(stdio.contains("\"type\": \"stdio\""), false)
        @Expect(http.contains("\"type\": \"http\""), true)
        @Expect(http.contains("http://127.0.0.1:18890/mcp"), true)
        @Expect(empty.contains("\"mcpServers\": {}"), true)
    }

    @TestCase
    public func ckg12Bnd001JsonEscapeKeepsUtf8AndEscapesControlCharacters(): Unit {
        let escaped = ckbAbcdeJsonEscape("仓颉🙂 \"quote\" \\slash\nnext")

        @Expect(escaped.contains("仓颉"), true)
        @Expect(escaped.contains("🙂"), true)
        @Expect(escaped.contains("\\\"quote\\\""), true)
        @Expect(escaped.contains("\\\\slash"), true)
        @Expect(escaped.contains("\\nnext"), true)
    }

    @TestCase
    public func ckg12Neg001BootstrapScriptDoesNotDependOnInteractiveZshrc(): Unit {
        let script = ckbAbcdeNativeTlsBootstrapScript("/tmp/ckb bin", ["--store", "/tmp/store path", "mcp-stdio"])

        @Expect(script.contains("CKB_NATIVE_TLS_BOOTSTRAPPED=1"), true)
        @Expect(script.contains("MAGIC_ROOT"), true)
        @Expect(script.contains("cangjie-stdx-mac-aarch64"), true)
        @Expect(script.contains("/Users/l3gi0n/work/workspace_cangjie/Metis/ffi"), true)
        @Expect(script.contains("/Users/l3gi0n/cangjie100/runtime/lib/darwin_aarch64_llvm"), true)
        @Expect(script.contains("DYLD_LIBRARY_PATH"), true)
        @Expect(script.contains("exec '/tmp/ckb bin' '--store' '/tmp/store path' 'mcp-stdio'"), true)
    }

    @TestCase
    public func ckg12Pos003CaseResultCarriesBenchmarkAuditFields(): Unit {
        let options = CkbAbcdeRunnerOptions()
        options.runId = "unit-run"
        let row = ckbAbcdeRenderCaseResult(options, "/tmp/run", "CJ-HUMANEVAL-000", CkbAbcdeGroups.D, "failed", 1, 1, false, false, "model_error", "manual_required", "none", "/tmp/group")

        @Expect(row.contains("\"runId\":\"unit-run\""), true)
        @Expect(row.contains("\"knowledgeEntry\":\"mcp_http\""), true)
        @Expect(row.contains("\"toolTransport\":\"streamable_http\""), true)
        @Expect(row.contains("\"unitPassAt1\":false"), true)
        @Expect(row.contains("\"firstClaudeExitCode\":"), true)
        @Expect(row.contains("\"claudeAttemptCount\":"), true)
        @Expect(row.contains("\"usageParseStatus\":\"missing_result\""), true)
        @Expect(row.contains("\"modelTotalTokens\":0"), true)
        @Expect(row.contains("\"llmTurnCount\":0"), true)
        @Expect(row.contains("\"protocolViolation\":false"), true)
        @Expect(row.contains("\"failureType\":\"model_error\""), true)
        @Expect(row.contains("\"toolEvidenceHash\":"), true)
        @Expect(row.contains("\"toolCoveragePass\":"), true)
        @Expect(row.contains("\"transportParityPath\":\"/tmp/group/parity.jsonl\""), true)
    }

    @TestCase
    public func ckg12Pos004EnvSwitchRecordNamesBoundaryAndWorkspace(): Unit {
        let row = ckbAbcdeRenderEnvSwitchCheck("CJ-HUMANEVAL-000", CkbAbcdeGroups.C, CkbAbcdeGroups.D, "/tmp/workspace", "/tmp/group")

        @Expect(row.contains("\"fromGroup\":\"C-ckb-mcp-stdio\""), true)
        @Expect(row.contains("\"toGroup\":\"D-ckb-mcp-http\""), true)
        @Expect(row.contains("\"knowledgeEntry\":\"mcp_http\""), true)
        @Expect(row.contains("\"cleanupAction\":\"fresh_group_workspace_and_strict_mcp_config\""), true)
        @Expect(row.contains("\"ok\":true"), true)
    }

    @TestCase
    public func ckg12Neg002RejectsUnsafeRunRootRunIdAndCaseRange(): Unit {
        let options = CkbAbcdeRunnerOptions()
        options.runId = "../bad"
        @Expect(ckbAbcdeOptionsSafetyDiagnostic(options), "unsafe_run_id")

        options.runId = "safe-run"
        options.runsRoot = "/tmp/ckbtest"
        @Expect(ckbAbcdeOptionsSafetyDiagnostic(options), "runs_root_must_be_/Users/l3gi0n/Downloads/ckbtest")

        options.runsRoot = "/Users/l3gi0n/Downloads/ckbtest"
        options.caseEnd = 164
        @Expect(ckbAbcdeOptionsSafetyDiagnostic(options), "case_range_must_be_0_163")
    }

    @TestCase
    public func ckg12Neg003McpInitToolListIsNotCountedAsToolUse(): Unit {
        let initOnly = "{\"type\":\"system\",\"subtype\":\"init\",\"tools\":[\"mcp__ckb-cangjie-http__cangjie_task_knowledge_pack\"]}"
        let realUse = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"mcp__ckb-cangjie-http__cangjie_task_knowledge_pack\"}]}}"
        let failedInit = "{\"type\":\"system\",\"subtype\":\"init\",\"mcp_servers\":[{\"name\":\"ckb-cangjie-http\",\"status\":\"failed\"}]}"
        let mergedAttempts = ckbAbcdeJoinClaudeAttemptTextForTest(realUse, failedInit)

        @Expect(ckbAbcdeToolEvidenceForTest(CkbAbcdeGroups.D, initOnly), "manual_required")
        @Expect(ckbAbcdeToolEvidenceForTest(CkbAbcdeGroups.D, initOnly + "\n" + realUse), "cangjie_task_knowledge_pack")
        @Expect(ckbAbcdeToolEvidenceForTest(CkbAbcdeGroups.D, mergedAttempts), "cangjie_task_knowledge_pack")
        @Expect(mergedAttempts.contains(realUse), true)
        @Expect(mergedAttempts.contains(failedInit), true)
    }

    @TestCase
    public func ckg12Pos009CanonicalTaskContextCarriesVersionAndTags(): Unit {
        let context = CkbAbcdeTaskContext()
        context.taskId = "CJ-HUMANEVAL-999"
        context.taskText = "Use ArrayList and String."
        context.signature = "func solution(s: String): ArrayList<String>"
        context.expectedKnowledgeTags.add("ArrayList")
        context.expectedKnowledgeTags.add("String")

        let json = ckbAbcdeRenderTaskContextJson(context)

        @Expect(json.contains("\"taskId\":\"CJ-HUMANEVAL-999\""), true)
        @Expect(json.contains("\"benchmark\":\"Cangjie-HumanEval\""), true)
        @Expect(json.contains("\"targetVersion\":\"1.0.0\""), true)
        @Expect(json.contains("\"sourceSet\":\"all\""), true)
        @Expect(json.contains("\"versionPolicy\":\"default\""), true)
        @Expect(json.contains("\"expectedKnowledgeTags\":[\"ArrayList\",\"String\"]"), true)
        @Expect(json.contains("\"responseMode\":\"evidence\""), true)
    }

    @TestCase
    public func f6Ut001RestStdioAndHttpTaskPackPayloadsHaveSameEvidence(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), p6PersistExactLookupStore("f6-ut-parity-store"))
        let context = CkbAbcdeTaskContext()
        context.taskId = "CJ-HUMANEVAL-000"
        context.taskText = "Use ArrayList.add and avoid append."
        context.signature = "func solution(values: Array<Int64>): Int64"
        context.expectedKnowledgeTags.add("ArrayList.add")
        let report = ckbAbcdeProbeInProcessTransportParity(service, context.taskId, ckbAbcdeRenderTaskContextJson(context))

        @Expect(report.ok, true)
        @Expect(report.rest.evidenceHash != "", true)
        @Expect(report.rest.evidenceHash, report.stdio.evidenceHash)
        @Expect(report.rest.evidenceHash, report.http.evidenceHash)
        @Expect(report.rest.coveragePass, report.stdio.coveragePass)
        @Expect(report.rest.coveragePass, report.http.coveragePass)
        @Expect(report.rest.citationCount, report.stdio.citationCount)
        @Expect(report.rest.citationCount, report.http.citationCount)
    }

    @TestCase
    public func f6Bnd001ProtocolErrorPayloadIsNotTreatedAsBusinessSuccess(): Unit {
        let response = "{\"jsonrpc\":\"2.0\",\"id\":3,\"error\":{\"code\":-32602,\"message\":\"session_required\"}}"
        let observation = ckbAbcdeParityObservationFromResponse("CJ-HUMANEVAL-000", "mcp_http", response)

        @Expect(observation.ok, false)
        @Expect(observation.diagnostic, "missing_structured_payload")
        @Expect(observation.evidenceHash, "")
    }

    @TestCase
    public func p6Bnd001ArtifactObservationRecordsTransportExitAndPayloadPath(): Unit {
        let observation = ckbAbcdeParityObservationFromArtifactForTest("CJ-HUMANEVAL-000", "mcp_stdio", "/tmp/stdio.json", "", 127, "stdio process failed")

        @Expect(observation.ok, false)
        @Expect(observation.payloadPath, "/tmp/stdio.json")
        @Expect(observation.diagnostic.contains("transport_exit_127"), true)
        @Expect(observation.diagnostic.contains("stdio process failed"), true)
    }

    @TestCase
    public func f6Pos001ParityJsonlRecordsEachTransportAndEvidenceFields(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), p6PersistExactLookupStore("f6-pos-parity-store"))
        let root = "target/p6-parity-artifacts"
        let report = ckbAbcdeProbeInProcessTransportParityArtifacts(service, root, "CJ-HUMANEVAL-001", ckbAbcdeSmokeTaskContextJsonForTest())
        let jsonl = ckbAbcdeRenderParityJsonl(report)

        @Expect(jsonl.contains("\"transport\":\"rest\""), true)
        @Expect(jsonl.contains("\"transport\":\"mcp_stdio\""), true)
        @Expect(jsonl.contains("\"transport\":\"mcp_http\""), true)
        @Expect(jsonl.contains("\"interfaceId\":\"cangjie_task_knowledge_pack\""), true)
        @Expect(jsonl.contains("\"evidenceHash\":\""), true)
        @Expect(jsonl.contains("\"coveragePass\":"), true)
        @Expect(jsonl.contains("\"citationCount\":"), true)
        @Expect(exists(Path("${root}/transport-parity-rest.json")), true)
        @Expect(exists(Path("${root}/transport-parity-stdio.json")), true)
        @Expect(exists(Path("${root}/transport-parity-http.json")), true)
        @Expect(exists(Path("${root}/transport-parity.jsonl")), true)
        @Expect(jsonl.contains("\"payloadPath\":\"${root}/transport-parity-rest.json\""), true)
    }

    @TestCase
    public func f6Neg001EvidenceHashMismatchIsProtocolFailureInput(): Unit {
        let rest = ckbAbcdeParityObservationFromResponse("CJ-HUMANEVAL-000", "rest", "{\"ok\":true,\"data\":{\"evidenceHash\":\"h1\",\"coverage\":{\"coveragePass\":true},\"citations\":[{\"citation\":\"doc\"}]}}")
        let stdio = ckbAbcdeParityObservationFromResponse("CJ-HUMANEVAL-000", "mcp_stdio", "{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{\"structuredContent\":{\"evidenceHash\":\"h2\",\"coverage\":{\"coveragePass\":true},\"citations\":[{\"citation\":\"doc\"}]}}}")
        let http = ckbAbcdeParityObservationFromResponse("CJ-HUMANEVAL-000", "mcp_http", "{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{\"structuredContent\":{\"evidenceHash\":\"h1\",\"coverage\":{\"coveragePass\":true},\"citations\":[{\"citation\":\"doc\"}]}}}")

        @Expect(ckbAbcdeParityDiagnosticForTest(rest, stdio, http), "evidence_hash_mismatch")
    }

    @TestCase
    public func p6Neg001CitationCountMismatchFailsTransportParity(): Unit {
        let rest = ckbAbcdeParityObservationFromResponse("CJ-HUMANEVAL-000", "rest", "{\"ok\":true,\"data\":{\"evidenceHash\":\"h1\",\"coverage\":{\"coveragePass\":true},\"citations\":[{\"citation\":\"doc\"}]}}")
        let stdio = ckbAbcdeParityObservationFromResponse("CJ-HUMANEVAL-000", "mcp_stdio", "{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{\"structuredContent\":{\"evidenceHash\":\"h1\",\"coverage\":{\"coveragePass\":true},\"citations\":[{\"citation\":\"doc\"},{\"citation\":\"std\"}]}}}")
        let http = ckbAbcdeParityObservationFromResponse("CJ-HUMANEVAL-000", "mcp_http", "{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{\"structuredContent\":{\"evidenceHash\":\"h1\",\"coverage\":{\"coveragePass\":true},\"citations\":[{\"citation\":\"doc\"}]}}}")

        @Expect(ckbAbcdeParityDiagnosticForTest(rest, stdio, http), "citation_count_mismatch")
    }

    @TestCase
    public func f7Neg001RunnerWritesPass1GateAndCurationInputForFailedCdRun(): Unit {
        let root = "target/f7-runner-pass1-gate"
        if (!exists(Path(root))) {
            Directory.create(Path(root), recursive: true)
        }
        let manifestPath = "${root}/manifest.jsonl"
        let runRoot = "${root}/run"
        if (!exists(Path(runRoot))) {
            Directory.create(Path(runRoot), recursive: true)
        }
        File.writeTo(Path(manifestPath), "{\"id\":\"CJ-HUMANEVAL-000\",\"category\":\"unit\",\"targetVersion\":\"1.0.0\",\"prompt\":\"Implement ArrayList helper.\",\"entryPoint\":\"cases/CJ-HUMANEVAL-000/starter\",\"testCommand\":\"cjpm test\",\"expectedKnowledgeTags\":[\"ArrayList\"]}\n".toArray())
        File.writeTo(Path("${runRoot}/results.jsonl"), "{\"runId\":\"unit\",\"benchmark\":\"Cangjie-HumanEval\",\"caseId\":\"CJ-HUMANEVAL-000\",\"group\":\"D-ckb-mcp-http\",\"unitPassAt1\":false,\"failureType\":\"compile_error\",\"protocolViolation\":false,\"toolEvidence\":\"cangjie_task_knowledge_pack\"}\n".toArray())
        let options = CkbAbcdeRunnerOptions()
        options.manifestPath = manifestPath
        options.caseStart = 0
        options.caseEnd = 0
        options.groups.clear()
        options.groups.add(CkbAbcdeGroups.D)

        let ok = ckbAbcdeWritePass1GateArtifactsForTest(options, runRoot)

        @Expect(ok, false)
        @Expect(exists(Path("${runRoot}/pass1-gate.json")), true)
        @Expect(exists(Path("${runRoot}/pass1-gate.md")), true)
        @Expect(exists(Path("${runRoot}/gap-curation-input.jsonl")), true)
        let curation = String.fromUtf8(File.readFrom(Path("${runRoot}/gap-curation-input.jsonl")))
        @Expect(curation.contains("\"interfaceId\":\"KI-02\""), true)
        @Expect(curation.contains("\"updateMechanism\":\"KU-11\""), true)
    }

    @TestCase
    public func ckg12Neg004ClaudeDoesNotSetToolWhitelist(): Unit {
        let baseline = ckbAbcdeClaudeToolLimitForGroup(CkbAbcdeGroups.A)
        let localDocs = ckbAbcdeClaudeToolLimitForGroup(CkbAbcdeGroups.E)
        let stdio = ckbAbcdeClaudeToolLimitForGroup(CkbAbcdeGroups.C)
        let http = ckbAbcdeClaudeToolLimitForGroup(CkbAbcdeGroups.D)

        @Expect(baseline, "")
        @Expect(localDocs, "")
        @Expect(stdio, "")
        @Expect(http, "")
    }

    @TestCase
    public func ckg12Neg005ClaudeTimeoutShellRecordsAndCleansHungCalls(): Unit {
        let shell = ckbAbcdeClaudeTimeoutShellForTest("claude -p", "/tmp/claude.err", 180)

        @Expect(shell.contains("/usr/bin/perl -MPOSIX"), true)
        @Expect(shell.contains("/bin/zsh -lc"), true)
        @Expect(shell.contains("claude_timeout_after_180s"), true)
        @Expect(shell.contains("/bin/kill -TERM -- \"-$child\""), true)
        @Expect(shell.contains("/bin/kill -KILL -- \"-$child\""), true)
        @Expect(shell.contains("code=124"), true)
    }

    @TestCase
    public func ckg12Pos005ClaudeUsesDangerouslySkipPermissions(): Unit {
        @Expect(ckbAbcdeClaudePermissionFlagForTest(), "--dangerously-skip-permissions")
    }

    @TestCase
    public func ckg12Pos005bRestContextCurlRetriesConnectionRefused(): Unit {
        let flags = ckbAbcdeCurlRetryFlagsForTest()

        @Expect(flags.contains("--retry "), true)
        @Expect(flags.contains("--retry-delay "), true)
        @Expect(flags.contains("--retry-connrefused"), true)
    }

    @TestCase
    public func ckg12Neg006PassAt1DoesNotCountRetrySuccess(): Unit {
        let firstTimeoutThenSuccess = "{\"attempt\":1,\"exitCode\":124}\n{\"attempt\":2,\"exitCode\":0}\n"
        let firstSuccess = "{\"attempt\":1,\"exitCode\":0}\n"

        @Expect(ckbAbcdeUnitPassAt1FromAttemptsForTest(true, firstTimeoutThenSuccess), false)
        @Expect(ckbAbcdeUnitPassAt1FromAttemptsForTest(true, firstSuccess), true)
        @Expect(ckbAbcdeUnitPassAt1FromAttemptsForTest(false, firstSuccess), false)
    }

    @TestCase
    public func ckg12Neg007ClaudeTimeoutExitIsClassifiedAsTimeout(): Unit {
        @Expect(ckbAbcdeFailureTypeForTest(124, 1, false, "none", "", true), "timeout")
        @Expect(ckbAbcdeFailureTypeForTest(124, 1, false, "none", "", false), "timeout")
        @Expect(ckbAbcdeFailureTypeForTest(1, 1, false, "none", "", true), "model_error")
        @Expect(ckbAbcdeFailureTypeForTest(0, 1, false, "none", "", false), "tool_unavailable")
    }

    @TestCase
    public func ckg12Bnd002ResultAuditScansUtf8TranscriptSafely(): Unit {
        let transcript = "模型输出：仓颉🙂\n{\"knowledgeVersion\":\"ckb-20260519-000100-active\",\"citation\":\"doc-1\"}\n继续中文🙂 {\"citation\":\"doc-2\"}"

        @Expect(ckbAbcdeJsonStringFieldForTest(transcript, "knowledgeVersion"), "ckb-20260519-000100-active")
        @Expect(ckbAbcdeCountOccurrencesForTest(transcript, "\"citation\""), 2)
    }

    @TestCase
    public func ckg12Neg008LocalDocsGroupAllowsVisibleToolsButRejectsUnexpectedToolUse(): Unit {
        let transcript = "{\"type\":\"system\",\"subtype\":\"init\",\"tools\":[\"Read\",\"Write\",\"Bash\",\"WebFetch\"]}"
        let webSearchUse = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"WebSearch\",\"input\":{\"query\":\"Cangjie ArrayList\"}}]}}"

        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, transcript), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, webSearchUse), "forbidden_e_tool_use")
    }

    @TestCase
    public func ckg12Pos006LocalDocsGroupAllowsReadOnlyScopedShell(): Unit {
        let docsSearch = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"find /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs -name collection_arraylist.md 2>/dev/null\"}}]}}"
        let workspaceRead = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"ls /Users/l3gi0n/Downloads/ckbtest/unit-run/cases/CJ-HUMANEVAL-000/E-local-cangjie-docs/workspace/src/ && cat /Users/l3gi0n/Downloads/ckbtest/unit-run/cases/CJ-HUMANEVAL-000/E-local-cangjie-docs/workspace/src/solution.cj\"}}]}}"
        let relativeReadOnlySearch = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"rg -rn \\\"StringBuilder\\\" --type md | head -30\"}}]}}"
        let docsSearchWithArrowPattern = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"rg -rn \\\"split\\\\(String\\\\)|-> Array|: Array<String>\\\" /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs -g \\\"*.md\\\" | head -20\"}}]}}"
        let localCompute = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"python3 -c \\\"def ds(n):\\\\n    return n + 1\\\\nprint(ds(1))\\\"\"}}]}}"
        let toolProbe = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"which cjc cjpm 2>/dev/null\"}}]}}"
        let workspaceBuild = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"cjpm build 2>&1 | head -60\"}}]}}"
        let scratchSource = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"cat > /tmp/test_palindrome.cj << 'EOF'\\\\nmain(): Int64 { return 0 }\\\\nEOF\"}}]}}"
        let scratchCompile = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"cjc /tmp/test_palindrome.cj --import-path target/release/pkg -o /tmp/test_palindrome 2>&1 | head -40\"}}]}}"
        let scratchRun = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"/tmp/test_palindrome 2>&1 | head\"}}]}}"
        let scratchCleanup = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"rm -f /tmp/test_palindrome.cj /tmp/test_palindrome; echo \\\"cleaned\\\"\"}}]}}"

        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, docsSearch), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, workspaceRead), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, relativeReadOnlySearch), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, docsSearchWithArrowPattern), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, localCompute), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, toolProbe), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, workspaceBuild), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, scratchSource), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, scratchCompile), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, scratchRun), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, scratchCleanup), "none")
    }

    @TestCase
    public func ckg12Pos008LocalDocsGroupDoesNotTreatShellAsProtocolViolation(): Unit {
        let unsafeCommand = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"rm -rf /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs\"}}]}}"
        let outOfScope = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"grep -R ArrayList /etc\"}}]}}"
        let pathEscape = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"rg -rn ArrayList ../..\"}}]}}"
        let writeRedirect = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"rg ArrayList /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs > /tmp/out\"}}]}}"
        let pythonWrite = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"python3 -c \\\"open('/tmp/out','w').write('x')\\\"\"}}]}}"
        let pythonShell = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"python3 -c \\\"import os; os.system('ls')\\\"\"}}]}}"
        let scratchRealPath = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"cjc /tmp/test_palindrome.cj -o /Users/l3gi0n/Downloads/test_palindrome\"}}]}}"
        let scratchUnsafeCleanup = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"rm -f /tmp/test_palindrome /etc/passwd\"}}]}}"

        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, unsafeCommand), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, outOfScope), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, pathEscape), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, writeRedirect), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, pythonWrite), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, pythonShell), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, scratchRealPath), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, scratchUnsafeCleanup), "none")
    }

    @TestCase
    public func ckg12Pos007ParsesClaudeResultUsageAndTurns(): Unit {
        let transcript = "{\"type\":\"assistant\",\"message\":{\"content\":\"working\"}}\n" +
            "{\"type\":\"result\",\"subtype\":\"success\",\"num_turns\":7,\"usage\":{\"input_tokens\":100,\"output_tokens\":25,\"cache_read_input_tokens\":10,\"cache_creation_input_tokens\":5}}\n"
        let usage = ckbAbcdeParseClaudeUsageFromText(transcript, "/tmp/claude-transcript.jsonl")

        @Expect(usage.usageParseStatus, "ok")
        @Expect(usage.modelInputTokens, 100)
        @Expect(usage.modelOutputTokens, 25)
        @Expect(usage.modelCacheReadTokens, 10)
        @Expect(usage.modelCacheCreationTokens, 5)
        @Expect(usage.modelTotalTokens, 140)
        @Expect(usage.llmTurnCount, 7)
        @Expect(usage.usageSourcePath, "/tmp/claude-transcript.jsonl")
        @Expect(ckbAbcdeRenderUsageJson(usage).contains("\"usageParseStatus\":\"ok\""), true)
    }

    @TestCase
    public func ckg12Neg010UsageParserDoesNotEstimateMissingResult(): Unit {
        let usage = ckbAbcdeParseClaudeUsageFromText("{\"type\":\"assistant\",\"message\":{}}\n", "/tmp/missing.jsonl")

        @Expect(usage.usageParseStatus, "missing_result")
        @Expect(usage.modelTotalTokens, 0)
        @Expect(usage.llmTurnCount, 0)
    }

    @TestCase
    public func ckg12Neg011UsageParserRejectsMissingUsageFields(): Unit {
        let usage = ckbAbcdeParseClaudeUsageFromText("{\"type\":\"result\",\"subtype\":\"success\",\"num_turns\":3}\n", "/tmp/missing-usage.jsonl")

        @Expect(usage.usageParseStatus, "missing_usage")
        @Expect(usage.modelTotalTokens, 0)
        @Expect(usage.llmTurnCount, 0)
    }

    @TestCase
    public func ckg12Pos008CaseSummaryAggregatesUsageFields(): Unit {
        let options = CkbAbcdeRunnerOptions()
        options.runId = "unit-run"
        let rows = ArrayList<String>()
        rows.add("{\"caseId\":\"CJ-HUMANEVAL-000\",\"group\":\"A-no-ckb\",\"status\":\"passed\",\"unitPassAt1\":true,\"protocolViolation\":false,\"usageParseStatus\":\"ok\",\"modelTotalTokens\":100,\"llmTurnCount\":3}")
        rows.add("{\"caseId\":\"CJ-HUMANEVAL-000\",\"group\":\"B-ckb-context\",\"status\":\"failed\",\"unitPassAt1\":false,\"protocolViolation\":false,\"usageParseStatus\":\"missing_result\",\"modelTotalTokens\":0,\"llmTurnCount\":0}")

        let summary = ckbAbcdeRenderCaseSummaryForTest(options, "/tmp/run", "CJ-HUMANEVAL-000", rows)
        let usageCsv = ckbAbcdeRenderCaseUsageSummaryCsvRowForTest("CJ-HUMANEVAL-000", rows)

        @Expect(summary.contains("\"usageParseOkGroupCount\":1"), true)
        @Expect(summary.contains("\"caseTotalModelTokens\":100"), true)
        @Expect(summary.contains("\"caseAverageModelTokensPerGroup\":100"), true)
        @Expect(summary.contains("\"caseTotalLlmTurns\":3"), true)
        @Expect(summary.contains("\"usageParseFailedGroups\":[\"B-ckb-context\"]"), true)
        @Expect(usageCsv, "CJ-HUMANEVAL-000,1,100,100,3,3,B-ckb-context")
    }

    @TestCase
    public func ckg12Bnd003UsageAverageNullWhenNoGroupParsed(): Unit {
        @Expect(ckbAbcdeAverageTextForTest(0, 0), "null")
        @Expect(ckbAbcdeAverageTextForTest(42, 5), "8.4")
    }
}
