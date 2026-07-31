package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbReproVerifyTest {
    @TestCase
    public func p8Ut01ModesAreParsedWithoutImplicitReleaseState(): Unit {
        let run = parseCkbReproVerifyOptions([
            "--mode", "run-certify",
            "--work-root", "/tmp/ckb p8/work",
            "--runtime-root", "/tmp/ckb p8/runtime",
            "--qdrant-root", "/tmp/ckb p8/qdrant",
            "--source-root", "/tmp/ckb p8/source",
            "--candidate-root", "/tmp/ckb p8/candidate",
            "--repository-root", "/tmp/ckb p8/repository",
            "--run-candidate-commit",
            "0123456789abcdef0123456789abcdef01234567"
        ])
        @Expect(run.ok, true)
        @Expect(run.options.mode, "run-certify")
        @Expect(run.options.releaseCommit, "")
        @Expect(run.options.tag, "")

        let release = parseCkbReproVerifyOptions([
            "--mode", "release-verify",
            "--work-root", "/tmp/ckb p8/release work",
            "--runtime-root", "/tmp/ckb p8/release runtime",
            "--qdrant-root", "/tmp/ckb p8/release qdrant",
            "--source-root", "/tmp/ckb p8/release source",
            "--candidate-root", "/tmp/ckb p8/unsigned",
            "--repository-root", "/tmp/ckb p8/repository",
            "--release-commit",
            "89abcdef0123456789abcdef0123456789abcdef"
        ])
        @Expect(release.ok, true)
        @Expect(release.options.mode, "release-verify")
        @Expect(release.options.runCandidateCommit, "")
        @Expect(release.options.tag, "")
    }
}
