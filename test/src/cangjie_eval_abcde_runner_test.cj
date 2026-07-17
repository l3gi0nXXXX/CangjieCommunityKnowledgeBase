package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.*
import std.env.getVariable
import std.fs.{Directory, File, Path, exists, canonicalize}
import std.process.*

@Test
public class CangjieEvalAbcdeRunnerTest {
    // ABCDE-CONFIG-UT/BND/POS/NEG: the frozen runtime config is an explicit
    // runner input and every stdio path receives the same safely quoted path.
    @TestCase
    public func abcdeConfigContractIsExplicitAndSharedByEveryStdioPath(): Unit {
        let root = "target/abcde config 仓颉🙂-${ckbCoreNowMillis()}"
        Directory.create(Path(root), recursive: true)
        let config = canonicalize(Path(root)).join("formal config 仓颉🙂.conf").toString()
        File.writeTo(Path(config), "network.enabled=false\n".toArray())
        let args = ["cangjie-eval-abcde", "--run-mode", "development", "--dataset-version", "dataset-v1",
            "--candidate-version", "candidate-v1", "--knowledge-version", "knowledge-v1",
            "--model-fingerprint", "claude-code-glm-5.2", "--claude-bin", "/usr/bin/true",
            "--config", config, "--groups", "C"]
        let options = parseCkbAbcdeRunnerOptions(args)
        @Expect(options.ckbConfig, config)
        @Expect(ckbAbcdeDevelopmentOptionsDiagnostic(options), "")
        let rendered = renderCkbAbcdeMcpConfig(CkbAbcdeGroups.C, "/tmp/ckb", config,
            "/tmp/store with space 仓颉🙂", "http://127.0.0.1:18890")
        @Expect(rendered.contains("'--config' '${config}' '--store' '/tmp/store with space 仓颉🙂' 'mcp-stdio'"), true)
        let stdioArgs = ckbAbcdeMcpStdioArgumentsForTest(options)
        @Expect(stdioArgs.size, 5)
        @Expect(stdioArgs[0], "--config")
        @Expect(stdioArgs[1], config)
        @Expect(stdioArgs[2], "--store")
        @Expect(stdioArgs[3], options.ckbStore)
        @Expect(stdioArgs[4], "mcp-stdio")

        let missing = parseCkbAbcdeRunnerOptions(["cangjie-eval-abcde", "--run-mode", "development",
            "--dataset-version", "dataset", "--candidate-version", "candidate", "--knowledge-version", "knowledge",
            "--model-fingerprint", "model", "--claude-bin", "/usr/bin/true", "--groups", "C"])
        @Expect(ckbAbcdeDevelopmentOptionsDiagnostic(missing), "ckb_config_required")
        missing.ckbConfig = "relative/escape 仓颉🙂.conf"
        @Expect(ckbAbcdeDevelopmentOptionsDiagnostic(missing), "ckb_config_must_be_absolute")
    }

    // CLAUDE-TMP-CHILD-UT/BND/POS/NEG: permit only the exact cwd-derived
    // Claude cache child, never its parent or a sibling.
    @TestCase
    public func claudeTempWorkspaceRuleIsExactUtf8SafeAndRejectsEscape(): Unit {
        let workspace = "/Users/test/工作 区🙂/workspace"
        let child = ckbAbcdeClaudeTempWorkspaceChildForTest("501", workspace)
        @Expect(child, "/private/tmp/claude-501/-Users-test-工作 区🙂-workspace")
        let rule = ckbAbcdeClaudeTempWorkspaceRuleForTest("501", workspace)
        @Expect(rule.contains("(subpath \"${child}\")"), true)
        @Expect(rule.contains("(subpath \"/private/tmp/claude-501\")"), false)
        @Expect(rule.contains("private-sibling-token"), false)
        @Expect(ckbAbcdeClaudeTempWorkspaceDiagnosticForTest("501", workspace, child, child, "501", "700", true, false), "ok")
        @Expect(ckbAbcdeClaudeTempWorkspaceDiagnosticForTest("501", workspace, child, child, "501", "700", true, true), "claude_temp_workspace_symlink_forbidden")
        @Expect(ckbAbcdeClaudeTempWorkspaceDiagnosticForTest("501", workspace, child, "${child}-escape", "501", "700", true, false), "claude_temp_workspace_canonical_mismatch")
        @Expect(ckbAbcdeClaudeTempWorkspaceDiagnosticForTest("501", workspace, child, child, "502", "700", true, false), "claude_temp_workspace_owner_mismatch")
        @Expect(ckbAbcdeClaudeTempWorkspaceDiagnosticForTest("501", workspace, child, child, "501", "755", true, false), "claude_temp_workspace_mode_invalid")
        @Expect(ckbAbcdeClaudeTempWorkspaceDiagnosticForTest("501", workspace, child, child, "501", "700", false, false), "claude_temp_workspace_directory_required")
        @Expect(ckbAbcdeClaudeTempWorkspaceDiagnosticForTest("501", workspace, "${child}-sibling", "${child}-sibling", "501", "700", true, false), "claude_temp_workspace_path_invalid")
        for (invalid in ["", "relative/workspace", "/Users/test/../escape", "/Users/test/line\nbreak", "/Users/test/quote\"break"]) {
            @Expect(ckbAbcdeClaudeTempWorkspaceChildForTest("501", invalid), "")
        }
        @Expect(ckbAbcdeClaudeTempWorkspaceChildForTest("用户🙂", workspace), "")
    }

    @TestCase
    public func claudeTempWorkspaceRealSandboxAllowsExactChildAndDeniesSibling(): Unit {
        if (!exists(Path("/usr/bin/sandbox-exec"))) { return }
        let rootRelative = "target/claude-temp-child-real-仓颉🙂-${ckbCoreNowMillis()}"
        Directory.create(Path(rootRelative), recursive: true)
        let root = canonicalize(Path(rootRelative)).toString()
        let workspace = "${root}/workspace"
        let home = "${root}/runtime-home"
        let store = "${root}/store"
        let caseSrc = "${root}/case"
        let config = "${root}/formal config 仓颉🙂.conf"
        let bin = "${root}/ckb-bin"
        for (path in [workspace, home, store, "${caseSrc}/tests", "${caseSrc}/translation"]) {
            Directory.create(Path(path), recursive: true)
        }
        File.writeTo(Path(config), "network.enabled=false\n".toArray())
        File.writeTo(Path(bin), "probe\n".toArray())
        let uid = ckbAbcdeCurrentUidForTest()
        let child = ckbAbcdeClaudeTempWorkspaceChildForTest(uid, workspace)
        let sibling = "/private/tmp/claude-${uid}/private-sibling-token-${ckbCoreNowMillis()}🙂"
        @Expect(exists(Path(sibling)), false)
        let sdk = match(getVariable("CANGJIE_HOME")){case Some(value)=>value case None=>""}
        let macSdk = match(getVariable("SDKROOT")){case Some(value)=>value case None=>""}
        @Expect(sdk.isEmpty(), false)
        @Expect(macSdk.isEmpty(), false)
        try {
            @Expect(ckbAbcdePrepareClaudeTempWorkspaceForTest(workspace), "ok")
            let developmentProfile = "${root}/development.sb"
            File.writeTo(Path(developmentProfile), ckbAbcdeDevelopmentSandboxProfile(CkbAbcdeGroups.C,
                workspace, home, bin, config, store, caseSrc, root, sdk, macSdk, "/usr/bin/true", "/usr/bin/true").toArray())
            let developmentScript = "printf '仓颉🙂' > '${child}/development-probe.txt' && /bin/cat '${child}/development-probe.txt' >/dev/null && ! /usr/bin/touch '${sibling}' >/dev/null 2>&1"
            @Expect(launch("/usr/bin/sandbox-exec", ["-f", developmentProfile, "/bin/zsh", "-lc", developmentScript]).wait(), 0)
            @Expect(exists(Path("${child}/development-probe.txt")), true)

            let certificationProfile = "${root}/certification.sb"
            File.writeTo(Path(certificationProfile), ckbAbcdeCertificationSandboxProfile(workspace, home,
                bin, config, store, caseSrc, "/usr/bin/true", "/usr/bin/true").toArray())
            let certificationScript = "printf '认证🙂' > '${child}/certification-probe.txt' && /bin/cat '${child}/certification-probe.txt' >/dev/null && ! /usr/bin/touch '${sibling}' >/dev/null 2>&1"
            @Expect(launch("/usr/bin/sandbox-exec", ["-f", certificationProfile, "/bin/zsh", "-lc", certificationScript]).wait(), 0)
            @Expect(exists(Path("${child}/certification-probe.txt")), true)
            @Expect(exists(Path(sibling)), false)
        } finally {
            _ = launch("/bin/rm", ["-rf", child]).wait()
            _ = launch("/bin/rm", ["-rf", rootRelative]).wait()
        }
    }

    @TestCase
    public func ckg12Ut001ParsesCaseIdGroupsAndSkipClaude(): Unit {
        let options = parseCkbAbcdeRunnerOptions(["cangjie-eval-abcde", "--case-id", "CJ-HUMANEVAL-007", "--groups", "A,C,E", "--claude-bin", "/tmp/claude", "--skip-claude"])

        @Expect(options.caseStart, 7)
        @Expect(options.caseEnd, 7)
        @Expect(options.skipClaude, true)
        @Expect(options.groups.size, 3)
        @Expect(options.groups[0], CkbAbcdeGroups.A)
        @Expect(options.groups[1], CkbAbcdeGroups.C)
        @Expect(options.groups[2], CkbAbcdeGroups.E)
        @Expect(options.claudeBin, "/tmp/claude")
    }

    // CLAUDE-BIN-UT/POS/E2E-01
    @TestCase
    public func nkUt05ExplicitClaudeExecutableBindsCommandAndSandbox(): Unit {
        let root = "target/claude-bin-contract-${ckbCoreNowMillis()}"
        _ = launch("/bin/rm", ["-rf", root]).wait()
        Directory.create(Path("${root}/install/bin"), recursive: true)
        Directory.create(Path("${root}/install/lib"), recursive: true)
        let canonical = "${root}/install/lib/claude.exe"
        File.writeTo(Path(canonical), "#!/bin/zsh\nexit 0\n".toArray())
        @Expect(launch("/bin/chmod", ["700", canonical]).wait(), 0)
        let requested = "${root}/install/bin/claude"
        @Expect(launch("/bin/ln", ["-s", "../lib/claude.exe", requested]).wait(), 0)
        let requestedAbsolute = canonicalize(Path(root)).join("install/bin/claude").toString()
        let executable = ckbAbcdeResolveClaudeExecutable(requestedAbsolute)
        @Expect(executable.valid, true)
        @Expect(executable.diagnostic, "ok")
        @Expect(executable.canonical, canonicalize(Path(canonical)).toString())
        let command = ckbAbcdeDevelopmentClaudeCommand("/tmp/group", "/tmp/home", "/tmp/profile.sb",
            executable.canonical, "GLM-5.2", "max", "", "", "--add-dir '/tmp/workspace'",
            ckbAbcdeSandboxTranscriptPath("/tmp/home"), ckbAbcdeSandboxStderrPath("/tmp/home"), 1)
        @Expect(command.contains(executable.canonical), true)
        @Expect(command.contains("/opt/homebrew/bin/claude"), false)
        let profile = ckbAbcdeDevelopmentSandboxProfile(CkbAbcdeGroups.C, "/tmp/workspace", "/tmp/home",
            "/usr/bin/true", "/tmp/config", "/tmp/store", "/tmp/case", "/tmp/docs", "/tmp/sdk", "/tmp/mac-sdk",
            requestedAbsolute, executable.canonical)
        @Expect(profile.contains(executable.canonical), true)
        @Expect(profile.contains(requestedAbsolute), true)
        @Expect(profile.contains("/opt/homebrew/bin/claude"), false)
    }

    // CLAUDE-BIN-BND/NEG-01
    @TestCase
    public func nkBnd05ClaudeExecutableRejectsUnsafeInputsWithoutLeakage(): Unit {
        let root = "target/claude-bin-negative-${ckbCoreNowMillis()}"
        _ = launch("/bin/rm", ["-rf", root]).wait()
        Directory.create(Path("${root}/install/bin"), recursive: true)
        Directory.create(Path("${root}/outside"), recursive: true)
        let nonexec = "${root}/install/bin/仓颉🙂-claude"
        File.writeTo(Path(nonexec), "not executable\n".toArray())
        @Expect(ckbAbcdeResolveClaudeExecutable("").diagnostic, "claude_executable_missing")
        @Expect(ckbAbcdeResolveClaudeExecutable("relative/claude").diagnostic, "claude_executable_must_be_absolute")
        @Expect(ckbAbcdeResolveClaudeExecutable("/private/secret-token/不存在🙂").diagnostic, "claude_executable_not_found")
        @Expect(ckbAbcdeResolveClaudeExecutable(canonicalize(Path(nonexec)).toString()).diagnostic, "claude_executable_not_executable")
        let outside = "${root}/outside/claude.exe"
        File.writeTo(Path(outside), "#!/bin/zsh\nexit 0\n".toArray())
        @Expect(launch("/bin/chmod", ["700", outside]).wait(), 0)
        let escaped = "${root}/install/bin/claude"
        @Expect(launch("/bin/ln", ["-s", "../../outside/claude.exe", escaped]).wait(), 0)
        let escapedResult = ckbAbcdeResolveClaudeExecutable(canonicalize(Path(root)).join("install/bin/claude").toString())
        @Expect(escapedResult.diagnostic, "claude_executable_symlink_escape")
        @Expect(escapedResult.diagnostic.contains("secret-token"), false)
        @Expect(escapedResult.canonical, "")
    }

    // SANDBOX-FD-UT/BND/POS/NEG/E2E-01
    @TestCase
    public func nkUt06SandboxStdioStaysInsideAttemptRuntimeHome(): Unit {
        let groupRoot = "/tmp/private-sibling-token/group🙂"
        let runtimeHome = "/tmp/运行时🙂/attempt-1"
        let transcript = ckbAbcdeSandboxTranscriptPath(runtimeHome)
        let stderr = ckbAbcdeSandboxStderrPath(runtimeHome)
        @Expect(transcript, "${runtimeHome}/claude-transcript.jsonl")
        @Expect(stderr, "${runtimeHome}/claude.stderr.log")

        let development = ckbAbcdeDevelopmentClaudeCommand(groupRoot, runtimeHome, "/tmp/profile.sb",
            "/usr/bin/true", "GLM-5.2", "max", "", "", "--add-dir '/tmp/workspace'", transcript, stderr, 1)
        let certification = ckbAbcdeCertificationClaudeCommand(groupRoot, runtimeHome, "/tmp/profile.sb",
            "/usr/bin/true", "GLM-5.2", transcript, stderr)
        for (command in [development, certification]) {
            @Expect(command.contains("> '${transcript}'"), true)
            @Expect(command.contains("2> '${stderr}'"), true)
            @Expect(command.contains("> '${groupRoot}/claude-transcript"), false)
            @Expect(command.contains("2> '${groupRoot}/claude"), false)
            @Expect(command.contains("private-sibling-token"), true)
        }
    }

    // SANDBOX-STDIN-UT/BND/POS/E2E-01
    @TestCase
    public func nkUt07SandboxPromptIsAtomicallyStagedInsideRuntimeHome(): Unit {
        let root = "target/sandbox-stdin-仓颉🙂-${ckbCoreNowMillis()}"
        let groupRoot = "${root}/group"
        let runtimeHome = "${root}/runtime-home/attempt-1"
        Directory.create(Path(groupRoot), recursive: true)
        Directory.create(Path(runtimeHome), recursive: true)
        let prompt = "请实现仓颉函数🙂\n"
        File.writeTo(Path(groupRoot).join("prompt.final.md"), prompt.toArray())

        @Expect(ckbAbcdeSandboxPromptPath(runtimeHome), "${runtimeHome}/prompt.final.md")
        @Expect(ckbAbcdePrepareSandboxPrompt(groupRoot, runtimeHome), "ok")
        @Expect(String.fromUtf8(File.readFrom(Path(ckbAbcdeSandboxPromptPath(runtimeHome)))), prompt)

        let transcript = ckbAbcdeSandboxTranscriptPath(runtimeHome)
        let stderr = ckbAbcdeSandboxStderrPath(runtimeHome)
        let development = ckbAbcdeDevelopmentClaudeCommand(groupRoot, runtimeHome, "/tmp/profile.sb",
            "/usr/bin/true", "GLM-5.2", "max", "", "", "--add-dir '/tmp/workspace'", transcript, stderr, 1)
        let certification = ckbAbcdeCertificationClaudeCommand(groupRoot, runtimeHome, "/tmp/profile.sb",
            "/usr/bin/true", "GLM-5.2", transcript, stderr)
        for (command in [development, certification]) {
            @Expect(command.contains("< '${runtimeHome}/prompt.final.md'"), true)
            @Expect(command.contains("< '${groupRoot}/prompt.final.md'"), false)
        }
    }

    // SANDBOX-STDIN-BND/NEG-01
    @TestCase
    public func nkBnd07SandboxPromptRejectsUnsafeInputWithoutPathLeakage(): Unit {
        let root = "target/sandbox-stdin-negative-${ckbCoreNowMillis()}"
        let runtimeHome = "${root}/runtime-home"
        Directory.create(Path(runtimeHome), recursive: true)
        @Expect(ckbAbcdePrepareSandboxPrompt("${root}/missing-private-token🙂", runtimeHome), "sandbox_prompt_missing")

        let invalidRoot = "${root}/invalid"
        Directory.create(Path(invalidRoot), recursive: true)
        File.writeTo(Path(invalidRoot).join("prompt.final.md"), [UInt8(0xff), UInt8(0xfe), UInt8(0x80)])
        @Expect(ckbAbcdePrepareSandboxPrompt(invalidRoot, runtimeHome), "sandbox_prompt_invalid_encoding")

        let oversizedRoot = "${root}/oversized"
        Directory.create(Path(oversizedRoot), recursive: true)
        File.writeTo(Path(oversizedRoot).join("prompt.final.md"), Array<UInt8>(1048577, repeat: UInt8(65)))
        @Expect(ckbAbcdePrepareSandboxPrompt(oversizedRoot, runtimeHome), "sandbox_prompt_too_large")

        let symlinkRoot = "${root}/symlink-source"
        Directory.create(Path(symlinkRoot), recursive: true)
        let privatePrompt = "${root}/private-token-prompt.md"
        File.writeTo(Path(privatePrompt), "secret".toArray())
        @Expect(launch("/bin/ln", ["-s", "../private-token-prompt.md", "${symlinkRoot}/prompt.final.md"]).wait(), 0)
        let sourceDiagnostic = ckbAbcdePrepareSandboxPrompt(symlinkRoot, runtimeHome)
        @Expect(sourceDiagnostic, "sandbox_prompt_source_symlink_forbidden")
        @Expect(sourceDiagnostic.contains("private-token"), false)

        let validRoot = "${root}/valid"
        Directory.create(Path(validRoot), recursive: true)
        File.writeTo(Path(validRoot).join("prompt.final.md"), "valid".toArray())
        let outside = "${root}/private-output"
        File.writeTo(Path(outside), "do-not-overwrite".toArray())
        _ = launch("/bin/rm", ["-f", ckbAbcdeSandboxPromptPath(runtimeHome)]).wait()
        @Expect(launch("/bin/ln", ["-s", "../private-output", ckbAbcdeSandboxPromptPath(runtimeHome)]).wait(), 0)
        @Expect(ckbAbcdePrepareSandboxPrompt(validRoot, runtimeHome), "sandbox_prompt_destination_symlink_forbidden")
        @Expect(String.fromUtf8(File.readFrom(Path(outside))), "do-not-overwrite")
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

    // NK-UT-01
    @TestCase
    public func nkUt01AllPromptModesRequireSameCallLocalChecksWithoutVerifierLeakage(): Unit {
        for (mode in ["development", "certification"]) {
            for (group in [CkbAbcdeGroups.A, CkbAbcdeGroups.B, CkbAbcdeGroups.C, CkbAbcdeGroups.D, CkbAbcdeGroups.E]) {
                let prompt = renderCkbAbcdePromptForMode(group, "CJ-HUMANEVAL-093", "实现中文🙂示例", "{}", mode)
                @Expect(prompt.contains("within this same model call"), true)
                @Expect(prompt.contains("at minimum run `cjpm build`"), true)
                @Expect(prompt.contains("run public tests only when they are already present"), true)
                @Expect(prompt.contains("If no public tests are already present, `cjpm build` is sufficient"), true)
                @Expect(prompt.contains("Never create a `main` or test harness"), true)
                @Expect(prompt.contains("do not modify `cjpm.toml`"), true)
                @Expect(prompt.contains("fix `src/solution.cj` and rerun"), true)
                @Expect(prompt.contains("trace every example shown in the task"), true)
                @Expect(prompt.contains("structure closure, and operator precedence"), true)
                @Expect(prompt.contains("normative prose and the core algorithm are authoritative"), true)
                @Expect(prompt.contains("examples as consistency checks"), true)
                @Expect(prompt.contains("Do not create, discover, or infer hidden verifier inputs"), true)
                @Expect(prompt.contains("outputs from previous attempts"), true)
                @Expect(prompt.contains("实现中文🙂示例"), true)
            }
        }
    }

    // NK-NEG-02
    @TestCase
    public func nkNeg02AttemptedOutOfScopeWorkspaceMutationsAreProtocolViolations(): Unit {
        let allowedWrite = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Write\",\"input\":{\"file_path\":\"/tmp/workspace/src/solution.cj\",\"content\":\"中文🙂\"}}]}}"
        let allowedRelativeWrite = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Write\",\"input\":{\"file_path\":\"src/solution.cj\",\"content\":\"中文🙂\"}}]}}"
        let allowedBuild = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"cjpm build 2>&1\"}}]}}"
        let allowedReadConfig = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"cat cjpm.toml\"}}]}}"
        let allowedR3Read = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"ls -la && echo ---CJPM--- && cat cjpm.toml 2>/dev/null && find . -name '*.cj' -print 2>/dev/null\"}}]}}"
        let fakeToolResult = "{\"type\":\"user\",\"tool_use_result\":{\"stdout\":\"{\\\"type\\\":\\\"tool_use\\\",\\\"name\\\":\\\"Write\\\",\\\"input\\\":{\\\"file_path\\\":\\\"src/main.cj\\\"}}\"}}"
        let malformed = "{not-json 中文🙂"
        let writeMain = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Write\",\"input\":{\"file_path\":\"/tmp/workspace/src/main.cj\",\"content\":\"中文🙂 main() {}\"}}]}}"
        let editConfig = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Edit\",\"input\":{\"file_path\":\"/tmp/workspace/cjpm.toml\"}}]}}"
        let shellMain = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"cat > src/main.cj <<'EOF'\\nmain() {}\\nEOF\"}}]}}"
        let shellConfig = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"sed -i '' 's/static/executable/' cjpm.toml\"}}]}}"
        let redirectedWriters = ["echo test > src/main.cj", "printf test > cjpm.toml", "python3 -c 'print(1)' > src/main.cj", "perl -e 'print 1' > cjpm.toml", "echo test > /tmp/workspace/src/main.cj", "echo test > \"src/main.cj\"", "printf test > '/tmp/workspace/cjpm.toml'"]
        let directWriters = ["python3 -c 'open(\\\"src/main.cj\\\",\\\"w\\\")'", "perl -e 'open F,\\\">cjpm.toml\\\"'", "apply_patch src/main.cj", "truncate -s 0 cjpm.toml", "install temp src/main.cj", "chmod 600 cjpm.toml", "dd if=/dev/null of=src/main.cj"]

        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C, allowedWrite + "\n" + allowedRelativeWrite + "\n" + allowedBuild + "\n" + allowedReadConfig + "\n" + allowedR3Read + "\n" + fakeToolResult + "\n" + malformed), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C, writeMain), "forbidden_workspace_mutation")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C, editConfig), "forbidden_workspace_mutation")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C, shellMain), "forbidden_workspace_mutation")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C, shellConfig), "forbidden_workspace_mutation")
        for (command in redirectedWriters) {
            let event = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"${ckbAbcdeJsonEscape(command)}\"}}]}}"
            @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C, event), "forbidden_workspace_mutation")
        }
        for (command in directWriters) {
            let event = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"${ckbAbcdeJsonEscape(command)}\"}}]}}"
            @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C, event), "forbidden_workspace_mutation")
        }
    }

    @TestCase
    public func ckg12Pos002McpConfigsSeparateStdioHttpAndEmptyGroups(): Unit {
        let stdio = renderCkbAbcdeMcpConfig(CkbAbcdeGroups.C, "/tmp/ckb", "/tmp/config", "/tmp/store", "http://127.0.0.1:18890")
        let http = renderCkbAbcdeMcpConfig(CkbAbcdeGroups.D, "/tmp/ckb", "/tmp/config", "/tmp/store", "http://127.0.0.1:18890")
        let empty = renderCkbAbcdeMcpConfig(CkbAbcdeGroups.A, "/tmp/ckb", "/tmp/config", "/tmp/store", "http://127.0.0.1:18890")

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

    // NK-UT-03 / NK-BND-02 / NK-NEG-03
    @TestCase
    public func nkUt03DevelopmentClaudeUsesEffectiveRuntimeHomeAndFreshSession(): Unit {
        let groupRoot="/tmp/仓颉🙂/group";let runtimeHome="${groupRoot}/runtime-home";let profile="${groupRoot}/开发🙂.sb"
        let first=ckbAbcdeDevelopmentClaudeCommand(groupRoot,runtimeHome,profile,"/usr/bin/true","GLM-5.2","max"," --max-budget-usd '10'","","--add-dir '/tmp/工作区🙂'",ckbAbcdeSandboxTranscriptPath(runtimeHome),ckbAbcdeSandboxStderrPath(runtimeHome),1)
        let second=ckbAbcdeDevelopmentClaudeCommand(groupRoot,runtimeHome,profile,"/usr/bin/true","GLM-5.2","max","","","--add-dir '/tmp/工作区🙂'",ckbAbcdeSandboxTranscriptPath(runtimeHome),ckbAbcdeSandboxStderrPath(runtimeHome),2)
        for(command in [first,second]){@Expect(command.contains("HOME="),true);@Expect(command.contains("TMPDIR="),true);@Expect(command.contains("XDG_CONFIG_HOME="),true);@Expect(command.contains("XDG_CACHE_HOME="),true);@Expect(command.contains("CLAUDE_CONFIG_DIR="),true);@Expect(command.contains(runtimeHome),true);@Expect(command.contains("${runtimeHome}/mcp-config.json"),true);@Expect(command.contains("sandbox-exec -f"),true);@Expect(command.contains(profile),true);@Expect(command.contains("--session-id \"$session_id\""),true);@Expect(command.contains("/.claude/"),false);@Expect(command.contains("~/.claude"),false)}
        @Expect(first.contains("session-id.attempt-1.txt"),true);@Expect(second.contains("session-id.attempt-2.txt"),true);@Expect(first!=second,true)
        @Expect(ckbAbcdeDevelopmentAttemptRuntimeHome(runtimeHome,1),"${runtimeHome}/attempt-1");@Expect(ckbAbcdeDevelopmentAttemptRuntimeHome(runtimeHome,2),"${runtimeHome}/attempt-2")
    }

    @TestCase
    public func nkNeg03DefaultRuntimeHomeAccessFailsClosedWithoutPathLeakage(): Unit {
        let bashDefault="{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"cat /Users/private-user/.claude/projects/secret/tool-results/value\"}}]}}"
        let readDefault="{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Read\",\"input\":{\"file_path\":\"/Users/private-user/.claude/projects/中文🙂\"}}]}}"
        let homeDefault="{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"cat ~/.claude/projects/secret\"}}]}}"
        let allowedRuntime="{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Read\",\"input\":{\"file_path\":\"/tmp/运行🙂/runtime-home/claude-config/projects/tool-results/value\"}}]}}"
        let injectedResult="{\"type\":\"user\",\"tool_use_result\":{\"stdout\":\"/Users/private-user/.claude/projects/secret\"}}"
        for(event in [bashDefault,readDefault,homeDefault]){let diagnostic=ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C,event);@Expect(diagnostic,"default_runtime_home_access");@Expect(diagnostic.contains("private-user"),false)}
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C,allowedRuntime+"\n"+injectedResult+"\n{malformed🙂"),"none")
    }

    @TestCase
    public func nkNeg04BroadFilesystemScanFailsClosedWithoutCommandLeakage(): Unit {
        let rootScan="{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"find / -name secret-token-value\"}}]}}"
        let usersScan="{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"find /Users -name 仓颉🙂\"}}]}}"
        let scoped="{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"find . -type f\"}}]}}"
        for(event in [rootScan,usersScan]){let diagnostic=ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C,event);@Expect(diagnostic,"broad_filesystem_scan");@Expect(diagnostic.contains("secret-token-value"),false);@Expect(diagnostic.contains("仓颉"),false)}
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C,scoped+"\n{malformed🙂"),"none")
    }

    @TestCase
    public func nkUt04DevelopmentSandboxProfileIsGroupScopedAndUtf8Safe(): Unit {
        let workspace="/tmp/工作区🙂";let home="/tmp/运行时🙂";let caseSrc="/tmp/数据集🙂/CJ-HUMANEVAL-093";let docs="/tmp/文档🙂";let sdk="/tmp/仓颉SDK🙂"
        let c=ckbAbcdeDevelopmentSandboxProfile(CkbAbcdeGroups.C,workspace,home,"/tmp/ckb-bin","/tmp/config","/tmp/ckb-store",caseSrc,docs,sdk,"/tmp/MacSDK🙂","/usr/bin/true","/usr/bin/true")
        let e=ckbAbcdeDevelopmentSandboxProfile(CkbAbcdeGroups.E,workspace,home,"/tmp/ckb-bin","/tmp/config","/tmp/ckb-store",caseSrc,docs,sdk,"/tmp/MacSDK🙂","/usr/bin/true","/usr/bin/true")
        for(profile in [c,e]){@Expect(profile.contains("(deny default)"),true);@Expect(profile.contains(workspace),true);@Expect(profile.contains(home),true);@Expect(profile.contains(sdk),true);@Expect(profile.contains("${caseSrc}/tests"),true);@Expect(profile.contains("${caseSrc}/translation"),true);@Expect(profile.contains("CangjieTeacher"),true)}
        @Expect(c.contains(docs),false);@Expect(e.contains(docs),true)
    }

    // TMP-META-UT / TMP-META-BND / TMP-META-POS / TMP-META-NEG
    @TestCase
    public func tmpMetaUtDynamicUidProducesOnlyExactMetadataLiteral(): Unit {
        let rule = ckbAbcdeClaudeTempMetadataRuleForUidForTest("501")
        @Expect(rule, " (literal \"/private/tmp/claude-501\")")
        @Expect(rule.contains("subpath"), false)
        @Expect(rule.contains("file-read*"), false)
        @Expect(rule.contains("file-write"), false)
    }

    @TestCase
    public func tmpMetaBndRejectsMalformedAndOutOfRangeUid(): Unit {
        for (uid in ["", " 501", "501 ", "-1", "+1", "0501", "501x", "用户🙂", "4294967296"]) {
            @Expect(ckbAbcdeClaudeTempMetadataRuleForUidForTest(uid), "")
        }
        @Expect(ckbAbcdeClaudeTempMetadataRuleForUidForTest("0"), " (literal \"/private/tmp/claude-0\")")
        @Expect(ckbAbcdeClaudeTempMetadataRuleForUidForTest("4294967295"), " (literal \"/private/tmp/claude-4294967295\")")
    }

    @TestCase
    public func tmpMetaNegValidationRejectsSymlinkOwnerModeAndSibling(): Unit {
        let path = "/private/tmp/claude-501"
        @Expect(ckbAbcdeClaudeTempMetadataDiagnosticForTest("501", path, path, "501", "700", true, false), "ok")
        @Expect(ckbAbcdeClaudeTempMetadataDiagnosticForTest("501", path, path, "501", "700", true, true), "claude_temp_symlink_forbidden")
        @Expect(ckbAbcdeClaudeTempMetadataDiagnosticForTest("501", path, "/private/tmp/private-token", "501", "700", true, false), "claude_temp_canonical_mismatch")
        @Expect(ckbAbcdeClaudeTempMetadataDiagnosticForTest("501", path, path, "502", "700", true, false), "claude_temp_owner_mismatch")
        for (mode in ["720", "702", "770", "707", "777", "bad🙂"]) {
            @Expect(ckbAbcdeClaudeTempMetadataDiagnosticForTest("501", path, path, "501", mode, true, false), "claude_temp_mode_invalid")
        }
        @Expect(ckbAbcdeClaudeTempMetadataDiagnosticForTest("501", path, path, "501", "700", false, false), "claude_temp_directory_required")
        @Expect(ckbAbcdeClaudeTempMetadataDiagnosticForTest("501", "/private/tmp/claude-502", "/private/tmp/claude-502", "501", "700", true, false), "claude_temp_path_invalid")
    }

    @TestCase
    public func tmpMetaPosProfilesContainCurrentExactRuleWithoutBroaderAccess(): Unit {
        let uid = ckbAbcdeCurrentUidForTest()
        @Expect(uid.isEmpty(), false)
        @Expect(ckbAbcdePrepareClaudeTempMetadataForTest(), "ok")
        let path = "/private/tmp/claude-${uid}"
        let workspace="/tmp/工作区🙂";let home="/tmp/运行时🙂";let caseSrc="/tmp/数据集🙂/CJ-HUMANEVAL-032"
        let development = ckbAbcdeDevelopmentSandboxProfile(CkbAbcdeGroups.C,workspace,home,"/tmp/ckb-bin","/tmp/config","/tmp/ckb-store",caseSrc,"/tmp/文档🙂","/tmp/仓颉SDK🙂","/tmp/MacSDK🙂","/usr/bin/true","/usr/bin/true")
        let certification = ckbAbcdeCertificationSandboxProfile(workspace,home,"/tmp/ckb-bin","/tmp/config","/tmp/ckb-store",caseSrc,"/usr/bin/true","/usr/bin/true")
        for (profile in [development, certification]) {
            @Expect(profile.contains("(allow file-read-metadata"), true)
            @Expect(profile.contains("(literal \"${path}\")"), true)
            @Expect(profile.contains("(subpath \"${path}\")"), false)
            @Expect(profile.contains("(allow file-read* (literal \"${path}\")"), false)
            @Expect(profile.contains("(allow file-write* (literal \"${path}\")"), false)
            @Expect(profile.contains("/private/tmp/claude-用户🙂"), false)
        }
    }

    // MAGIC-STDX-UT / MAGIC-STDX-BND / MAGIC-STDX-POS / MAGIC-STDX-NEG
    @TestCase
    public func magicStdxUtCanonicalRootResolvesOnlyPlatformLibraryDirectory(): Unit {
        let root = "target/Magic-仓颉🙂-${ckbCoreNowMillis()}"
        let stdx = "${root}/libs/cangjie-stdx-mac-aarch64-1.0.0.1/darwin_aarch64_llvm/dynamic/stdx"
        Directory.create(Path(stdx), recursive: true)
        let canonicalRoot = canonicalize(Path(root)).toString()
        let canonicalStdx = canonicalize(Path(stdx)).toString()
        @Expect(ckbAbcdeMagicStdxPathForTest(canonicalRoot), canonicalStdx)
        @Expect(ckbAbcdeMagicStdxPathForTest(canonicalRoot).contains("仓颉🙂"), true)
    }

    @TestCase
    public func magicStdxBndMissingRelativeAndMalformedRootsFailClosed(): Unit {
        for (root in ["", "relative/Magic", " /private/tmp/Magic", "/private/tmp/Magic ", "/private/tmp/不存在-仓颉🙂"]) {
            @Expect(ckbAbcdeMagicStdxPathForTest(root), "")
        }
    }

    @TestCase
    public func magicStdxNegSymlinkAndUnexpectedSuffixFailClosed(): Unit {
        let root = "target/Magic-negative-${ckbCoreNowMillis()}"
        let real = "${root}/real"
        let suffix = "libs/cangjie-stdx-mac-aarch64-1.0.0.1/darwin_aarch64_llvm/dynamic/stdx"
        Directory.create(Path("${real}/${suffix}"), recursive: true)
        let linkedRoot = "${root}/linked-root"
        @Expect(launch("/bin/ln", ["-s", "real", linkedRoot]).wait(), 0)
        @Expect(ckbAbcdeMagicStdxPathForTest(canonicalize(Path(root)).join("linked-root").toString()), "")
        let badRoot = "${root}/bad-root"
        Directory.create(Path("${badRoot}/libs/private-sibling-token🙂"), recursive: true)
        @Expect(ckbAbcdeMagicStdxPathForTest(canonicalize(Path(badRoot)).toString()), "")
    }

    @TestCase
    public func magicStdxPosProfilesAllowExactStdxWithoutMagicSiblingOrWrite(): Unit {
        let stdx = ckbAbcdeCurrentMagicStdxPathForTest()
        @Expect(stdx.isEmpty(), false)
        let magicRoot = match(getVariable("MAGIC_PATH")){case Some(value)=>canonicalize(Path(value)).toString() case None=>""}
        let workspace="/tmp/工作区🙂";let home="/tmp/运行时🙂";let caseSrc="/tmp/数据集🙂/CJ-HUMANEVAL-032"
        let development = ckbAbcdeDevelopmentSandboxProfile(CkbAbcdeGroups.C,workspace,home,"/tmp/ckb-bin","/tmp/config","/tmp/ckb-store",caseSrc,"/tmp/文档🙂","/tmp/仓颉SDK🙂","/tmp/MacSDK🙂","/usr/bin/true","/usr/bin/true")
        let certification = ckbAbcdeCertificationSandboxProfile(workspace,home,"/tmp/ckb-bin","/tmp/config","/tmp/ckb-store",caseSrc,"/usr/bin/true","/usr/bin/true")
        for (profile in [development, certification]) {
            @Expect(profile.contains("(subpath \"${stdx}\")"), true)
            @Expect(profile.contains("(subpath \"${magicRoot}\")"), false)
            @Expect(profile.contains("(literal \"/dev/stdin\")"), true)
            @Expect(profile.contains("(literal \"/dev/fd/0\")"), true)
            @Expect(profile.contains("(subpath \"/dev/fd\")"), false)
            @Expect(profile.contains("(literal \"/dev/fd/1\")"), false)
            @Expect(profile.contains("(literal \"/dev/fd/2\")"), false)
            @Expect(profile.contains("(literal \"/dev/stdout\")"), false)
            @Expect(profile.contains("(literal \"/dev/stderr\")"), false)
            @Expect(profile.contains("(allow file-write* (subpath \"${stdx}\")"), false)
            @Expect(profile.contains("(allow file-write* (literal \"/dev/stdin\")"), false)
            @Expect(profile.contains("(allow file-write* (literal \"/dev/fd/0\")"), false)
            @Expect(profile.contains("private-sibling-token🙂"), false)
        }
    }

    @TestCase
    public func nkPos04RealDevelopmentSandboxBuildsAndDeniesPrivateSibling(): Unit {
        if (!exists(Path("/usr/bin/sandbox-exec"))) { return }
        let root="target/development-sandbox-仓颉🙂";let workspace="${root}/workspace";let home="${root}/runtime-home";let caseSrc="${root}/case";let docs="${root}/docs";let store="${root}/store";let bin="${root}/ckb-bin"
        for(path in [workspace,home,"${caseSrc}/tests","${caseSrc}/translation",docs,store]){if(!exists(Path(path))){Directory.create(Path(path),recursive:true)}};File.writeTo(Path(bin),"probe".toArray())
        let sdk=match(getVariable("CANGJIE_HOME")){case Some(value)=>value case None=>""};let macSdk=match(getVariable("SDKROOT")){case Some(value)=>value case None=>""};@Expect(sdk.isEmpty(),false);@Expect(macSdk.isEmpty(),false)
        let profilePath="${root}/development.sb";File.writeTo(Path(profilePath),ckbAbcdeDevelopmentSandboxProfile(CkbAbcdeGroups.E,workspace,home,bin,"/tmp/config",store,caseSrc,docs,sdk,macSdk,"/usr/bin/true","/usr/bin/true").toArray())
        let probe=ckbAbcdeDevelopmentSandboxProbeForTest(profilePath,workspace,home,caseSrc,docs,CkbAbcdeGroups.E,sdk,macSdk)
        @Expect(probe.exitCode,0);@Expect(probe.stderr,"");@Expect(probe.stdout.contains("\"ok\":true"),true);@Expect(probe.stdout.contains("\"stdinReadable\":true"),true);@Expect(probe.stdout.contains("\"minimalBuildPassed\":true"),true);@Expect(probe.stdout.contains("\"deniedBroadFilesystemScan\":true"),true);@Expect(probe.stdout.contains("private-probe-value"),false)
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
