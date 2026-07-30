package cangjie_community_knowledge_base_integration_test

import cangjie_community_knowledge_base_test.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbFull164IntegrationTest {
    @TestCase
    public func tsE2e01SingleRunnerProofCoversPublicationAndPollution(): Unit {
        let kb = r7CleanKnowledgeBase()
        let records = r7CertifiedKnowledgeRecords(kb.activeRecordSnapshot())
        let fixture = r7BuildRealRunnerProof(records)
        @Expect(fixture.diagnostic, "ok")
        @Expect(fixture.ok, true)
        @Expect(fixture.runnerExitCode, 0)
        if (!fixture.ok) { return }

        s3IntegrationPollutedCandidateCannotChangeActiveVersion(fixture)
        p8IntegrationRunnerGeneratedArtifactsPublishAndTamperFailsClosed(
            fixture)
    }
}
