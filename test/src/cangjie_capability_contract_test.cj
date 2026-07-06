package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.*

@Test
public class CangjieCapabilityContractTest {
    private func service(name: String): CkbCommandLoopService {
        CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/${name}"))
    }

    private func request(): CangjieTaskKnowledgeRequest {
        let req = CangjieTaskKnowledgeRequest()
        req.taskId = "CJ-HUMANEVAL-000"
        req.benchmark = "Cangjie-HumanEval"
        req.taskText = "Implement an ArrayList helper."
        req.signature = "func solve(xs: ArrayList<Int64>): Int64"
        req.imports.add("std.collection.ArrayList")
        req.expectedKnowledgeTags.add("ArrayList")
        req.expectedKnowledgeTags.add("symbol")
        req.versionSelector = cangjieVersionSelector(targetVersion: "1.0.0", sourceSet: "stdx", sourceRef: "release-1.0.0", versionPolicy: "exact")
        req
    }

    @TestCase
    public func p1Pos001TaskKnowledgePackIncludesVersionPlanAndCoverage(): Unit {
        let pack = this.service("p1-pos-001").cangjieTaskKnowledgePack(this.request())

        @Expect(pack.versionResolution.ok, true)
        @Expect(pack.versionResolution.versionPolicy, "exact")
        @Expect(pack.queryPlan.size > 0, true)
        @Expect(pack.coverage.requiredCount, 2)
        @Expect(pack.coverage.missingCount, 0)
        @Expect(pack.coverage.coveragePass, true)
        @Expect(pack.notes.contains("task_knowledge_contract_skeleton"), true)
    }

    @TestCase
    public func p1Neg001EmptyTaskAndSignatureIsRejectedByValidator(): Unit {
        let req = CangjieTaskKnowledgeRequest()

        @Expect(validateCangjieTaskKnowledgeRequest(req), "task_or_signature_required")
    }

    @TestCase
    public func p1Neg002MissingExactRefDegradesTaskPack(): Unit {
        let req = this.request()
        req.versionSelector = cangjieVersionSelector(targetVersion: "1.0.0", sourceSet: "stdx", sourceRef: "missing-release", versionPolicy: "exact")
        let pack = this.service("p1-neg-002").cangjieTaskKnowledgePack(req)

        @Expect(pack.versionResolution.ok, false)
        @Expect(pack.versionResolution.diagnostic, "version_not_resolved")
        @Expect(pack.degraded, true)
        @Expect(pack.coverage.coveragePass, false)
        @Expect(pack.diagnostics.contains("version_not_resolved"), true)
    }

    @TestCase
    public func p1Bnd001OversizedStarterCodeIsTruncatedDiagnosticOnly(): Unit {
        let req = this.request()
        var text = ""
        for (_ in 0..(CangjieCapabilityLimits.MAX_TEXT_CHARS + 8)) {
            text += "x"
        }
        req.starterCodeExcerpt = text
        let pack = this.service("p1-bnd-001").cangjieTaskKnowledgePack(req)

        @Expect(pack.truncated, true)
        @Expect(pack.diagnostics.contains("starter_code_excerpt_truncated"), true)
        @Expect(pack.versionResolution.ok, true)
    }

    @TestCase
    public func p1Pos002LegacyKnowledgePackStillCallableButMarkedDegraded(): Unit {
        let pack = this.service("p1-pos-002").cangjieKnowledgePack("ArrayList usage", targetVersion: "1.0.0", budget: 1)

        @Expect(pack.queryId.startsWith("cangjie-"), true)
        @Expect(pack.notes.contains("legacy_endpoint_degraded"), true)
        @Expect(pack.degraded, true)
    }
}
