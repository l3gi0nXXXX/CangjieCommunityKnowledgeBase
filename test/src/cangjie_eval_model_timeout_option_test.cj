package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*
import std.fs.*
import std.process.launch

@Test
public class CangjieEvalModelTimeoutOptionTest {
    @TestCase
    public func p5TimeoutUt01DefaultIs180AndCustomValueReachesTimeoutShell(): Unit {
        let defaults = parseCkbAbcdeRunnerOptions(["cangjie-eval-abcde"])
        @Expect(defaults.modelTimeoutSeconds, 180)
        let custom = parseCkbAbcdeRunnerOptions(["cangjie-eval-abcde", "--model-timeout-seconds", "321"])
        @Expect(custom.modelTimeoutSeconds, 321)
        let shell = ckbAbcdeClaudeTimeoutShellForOptionsForTest("claude -p", "/tmp/model-timeout-中文😀.err", custom)
        @Expect(shell.contains("-ge 321"), true)
        @Expect(shell.contains("claude_timeout_after_321s"), true)
        @Expect(shell.contains("code=124"), true)
    }

    @TestCase
    public func p5TimeoutBnd01OnlyIntegerRange1Through3600IsAccepted(): Unit {
        @Expect(ckbAbcdeModelTimeoutDiagnostic("1"), "ok")
        @Expect(ckbAbcdeModelTimeoutDiagnostic("3600"), "ok")
        for (value in ["", "abc", "1.5", "0", "-1", "3601", " 180 ", "中文😀"]) {
            @Expect(ckbAbcdeModelTimeoutDiagnostic(value), "invalid_argument_value:--model-timeout-seconds")
        }
    }

    @TestCase
    public func p5TimeoutNeg01MissingInvalidAndDuplicateArgumentsFailClosed(): Unit {
        @Expect(ckbAbcdeStrictUsageDiagnostic(["cangjie-eval-abcde", "--model-timeout-seconds"]), "missing_argument_value:--model-timeout-seconds")
        @Expect(ckbAbcdeStrictUsageDiagnostic(["cangjie-eval-abcde", "--model-timeout-seconds", "nope"]), "invalid_argument_value:--model-timeout-seconds")
        @Expect(ckbAbcdeStrictUsageDiagnostic(["cangjie-eval-abcde", "--model-timeout-seconds", "180", "--model-timeout-seconds", "240"]), "duplicate_argument:--model-timeout-seconds")
    }

    @TestCase
    public func p5TimeoutPos01TransportTimeoutStillConsumesNoSample(): Unit {
        let incomplete = ckbAbcdeAssessSample("{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"GLM-5.2\"}\n", "GLM-5.2")
        @Expect(incomplete.completeResult, false)
        @Expect(incomplete.sampleAttempt, 0)
        let attempts = "{\"attempt\":1,\"transportAttempt\":1,\"sampleAttempt\":0,\"exitCode\":124,\"completeResult\":false,\"identityMatched\":false}\n"
        @Expect(ckbAbcdeUnitPassAt1FromAttemptsForTest(true, attempts), false)
    }

    @TestCase
    public func p5TimeoutE2e01CertificationTimeoutDoesNotGrantAnyRetryBudget(): Unit {
        let options = parseCkbAbcdeRunnerOptions(["cangjie-eval-abcde", "--run-mode", "certification", "--model-timeout-seconds", "600"])
        let budget = ckbAbcdeCertificationBudget(options)
        @Expect(options.modelTimeoutSeconds, 600)
        @Expect(budget.agentAttempts, 1)
        @Expect(budget.providerRetries, 0)
        @Expect(budget.sdkRetries, 0)
        let complete = ckbAbcdeAssessSample("{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"GLM-5.2\"}\n{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false}\n", "GLM-5.2")
        @Expect(ckbAbcdeShouldRetryTransport(0, complete), false)
    }

    @TestCase
    public func p5TimeoutE2eKillsIsolatedProcessTreeAndNextRunContinues():Unit {
        let root="target/model-timeout-中文😀"
        if(exists(Path(root))){remove(Path(root),recursive:true)};Directory.create(Path(root),recursive:true)
        try {
            let absolute=canonicalize(Path(root)).toString()
            let leader="${absolute}/leader.pid";let child="${absolute}/child.pid";let grand="${absolute}/grand.pid";let stderr="${absolute}/claude.err"
            let nested="printf %s \"$$\" > ${child}; sleep 30 & printf %s \"$!\" > ${grand}; wait"
            let command="printf %s \"$$\" > ${leader}; /bin/zsh -lc '${nested}' & wait"
            let result=ckbAbcdeRunClaudeTimeoutShellForTest(command,stderr,1,absolute)
            @Expect(result.exitCode,124)
            @Expect(String.fromUtf8(File.readFrom(Path(stderr))).contains("claude_timeout_after_1s"),true)
            for(path in [leader,child,grand]){let pid=String.fromUtf8(File.readFrom(Path(path))).trimAscii();@Expect(launch("/bin/kill",["-0",pid]).wait()!=0,true)}
            let next=ckbAbcdeRunClaudeTimeoutShellForTest("/usr/bin/true",stderr,1,absolute)
            @Expect(next.exitCode,0)
        } finally { try { remove(Path(root),recursive:true) } catch (_:Exception) {} }
    }
}
