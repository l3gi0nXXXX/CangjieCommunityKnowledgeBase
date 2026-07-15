package cangjie_community_knowledge_base_test

import std.fs.{Directory, File, Path, exists}
import std.process.launch
import std.time.DateTime
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieEvalTransportSampleAttemptTest {
    @TestCase
    public func p5AttemptUt01OnlyCompleteIdentityMatchedResultCreatesSample(): Unit {
        let complete = ckbAbcdeAssessSample(p5AttemptTranscript("GLM-5.2", true), "GLM-5.2")
        @Expect(complete.completeResult, true); @Expect(complete.identityMatched, true); @Expect(complete.sampleAttempt, 1)
        let timeout = ckbAbcdeAssessSample("{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"GLM-5.2\"}\n", "GLM-5.2")
        @Expect(timeout.completeResult, false); @Expect(timeout.sampleAttempt, 0)
    }

    @TestCase
    public func p5AttemptBnd01MalformedInterruptedAndIdentityMismatchDoNotConsumeSample(): Unit {
        let malformed = ckbAbcdeAssessSample("{\"type\":\"result\" 中文😀", "GLM-5.2")
        @Expect(malformed.completeResult, false); @Expect(malformed.identityMatched, false)
        let mismatch = ckbAbcdeAssessSample(p5AttemptTranscript("other-model", true), "GLM-5.2")
        @Expect(mismatch.completeResult, true); @Expect(mismatch.identityMatched, false); @Expect(mismatch.sampleAttempt, 0)
        let errored = ckbAbcdeAssessSample(p5AttemptTranscript("GLM-5.2", false), "GLM-5.2")
        @Expect(errored.completeResult, false)
    }

    @TestCase
    public func p5AttemptPos01TransportFailureThenFirstSamplePassIsPassAt1(): Unit {
        let attempts = "{\"attempt\":1,\"transportAttempt\":1,\"sampleAttempt\":0,\"exitCode\":124,\"completeResult\":false}\n{\"attempt\":2,\"transportAttempt\":2,\"sampleAttempt\":1,\"exitCode\":0,\"completeResult\":true,\"identityMatched\":true}\n"
        @Expect(ckbAbcdeUnitPassAt1FromAttemptsForTest(true, attempts), true)
        @Expect(ckbAbcdeUnitPassAt1FromAttemptsForTest(false, attempts), false)
    }

    @TestCase
    public func p5AttemptNeg01CompleteSampleNeverRetriesToForgePassAt1(): Unit {
        let sample = ckbAbcdeAssessSample(p5AttemptTranscript("GLM-5.2", true), "GLM-5.2")
        @Expect(ckbAbcdeShouldRetryTransport(0, sample), false)
        @Expect(ckbAbcdeUnitPassAt1FromAttemptsForTest(false, "{\"attempt\":1,\"transportAttempt\":1,\"sampleAttempt\":1,\"exitCode\":0}\n"), false)
        let incomplete = ckbAbcdeAssessSample("", "GLM-5.2")
        @Expect(ckbAbcdeShouldRetryTransport(124, incomplete), true)
    }

    @TestCase
    public func p5AttemptE2e01DirtyTimeoutWorkspaceIsReplacedFromAuthority(): Unit {
        let suffix = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let root = "target/p5-attempt-恢复😀-${suffix}"
        let authority = "${root}/权威😀"
        let workspace = "${root}/工作区😀"
        Directory.create(Path(authority).join("src"), recursive: true)
        Directory.create(Path(workspace).join("src"), recursive: true)
        File.writeTo(Path(authority).join("src/solution.cj"), "// 权威中文😀\npublic func answer(): Int64 { 1 }\n".toArray())
        File.writeTo(Path(workspace).join("src/solution.cj"), "// timeout 脏修改😀\npublic func answer(): Int64 { 999 }\n".toArray())
        File.writeTo(Path(workspace).join("timeout-dirty-secret.txt"), "must disappear".toArray())
        let evidence = ckbAbcdeRestoreWorkspaceForRetry(workspace, authority, 2)
        @Expect(evidence.contains("\"restored\":true"), true)
        @Expect(evidence.contains("\"evidenceHash\":\"sha256:"), true)
        @Expect(String.fromUtf8(File.readFrom(Path(workspace).join("src/solution.cj"))).contains("权威中文😀"), true)
        @Expect(exists(Path(workspace).join("timeout-dirty-secret.txt")), false)
        _ = launch("/bin/rm", ["-rf", root]).wait()
    }
}

private func p5AttemptTranscript(model: String, success: Bool): String {
    "{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"${model}\"}\n{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":${!success},\"result\":\"完成中文😀\"}\n"
}
