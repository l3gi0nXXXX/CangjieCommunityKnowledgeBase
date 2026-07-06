package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieLandingStatusTest {
    @TestCase
    public func f0Ut001NonEvidenceTaskPackIsMissingNotLanded(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/f0-landing-skeleton-store"))
        service.start()

        let report = collectCkbLandingStatus(service)

        @Expect(report.ok, false)
        @Expect(ckbLandingTestStatus(report, "F3-task-pack-evidence"), "missing")
        @Expect(ckbLandingTestDiagnostic(report, "F3-task-pack-evidence"), "task_pack_not_evidence_backed")
    }

    @TestCase
    public func f0Bnd001EmptySchedulerIsMissingNotComplete(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/f0-landing-scheduler-store"))
        service.start()

        let report = collectCkbLandingStatus(service)

        @Expect(report.ok, false)
        @Expect(ckbLandingTestStatus(report, "F5-routine-update-scheduler"), "missing")
        @Expect(ckbLandingTestDiagnostic(report, "F5-routine-update-scheduler"), "scheduler_status_missing")
    }

    @TestCase
    public func f0Bnd002SchedulerCandidateValidationFailureIsExplicit(): Unit {
        let store = FileKnowledgeStore("target/f0-landing-validation-failure")
        let entries = ArrayList<ScheduleEntry>()
        let entry = ScheduleEntry("cangjie_docs_full_weekly", 10080, 0)
        entry.lastStatus = "candidate_validation_failed"
        entry.lastRequestCount = 5
        entries.add(entry)
        store.saveScheduler(entries)
        let service = CkbCommandLoopService(CkbRuntimeConfig(), store)
        service.start()

        let report = collectCkbLandingStatus(service)

        @Expect(report.ok, false)
        @Expect(ckbLandingTestStatus(report, "F5-routine-update-scheduler"), "missing")
        @Expect(ckbLandingTestDiagnostic(report, "F5-routine-update-scheduler"), "candidate_validation_failed:cangjie_docs_full_weekly")
    }

    @TestCase
    public func f0Pos001CompleteReportRendersAsComplete(): Unit {
        let report = CkbLandingStatusReport()
        report.ok = true
        report.overallStatus = "complete"
        report.activeKnowledgeVersion = "complete-active"
        report.capabilities.add(ckbLandingTestCapability("one", "landed"))
        report.capabilities.add(ckbLandingTestCapability("two", "landed"))
        let json = renderCkbLandingStatusJson(report)
        let markdown = renderCkbLandingStatusMarkdown(report)

        @Expect(json.contains("\"overallStatus\":\"complete\""), true)
        @Expect(markdown.contains("activeKnowledgeVersion=complete-active"), true)
    }

    @TestCase
    public func f0Neg001AdminLandingStatusRequiresAuthorization(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/f0-landing-admin-store"))
        service.start()

        let denied = ckbApiHandle(service, "POST", "/v1/admin/cangjie/landing-status", "{}", [])
        let allowed = ckbApiHandle(service, "POST", "/v1/admin/cangjie/landing-status", "{}", ["X-CKB-Admin-Token: test"])

        @Expect(denied.contains("ckb.unauthorized"), true)
        @Expect(allowed.contains("\"overallStatus\""), true)
    }
}

private func ckbLandingTestStatus(report: CkbLandingStatusReport, id: String): String {
    for (item in report.capabilities) {
        if (item.id == id) {
            return item.status
        }
    }
    ""
}

private func ckbLandingTestDiagnostic(report: CkbLandingStatusReport, id: String): String {
    for (item in report.capabilities) {
        if (item.id == id) {
            return item.diagnostic
        }
    }
    ""
}

private func ckbLandingTestCapability(id: String, status: String): CkbLandingCapabilityStatus {
    let item = CkbLandingCapabilityStatus()
    item.id = id
    item.status = status
    item.diagnostic = "ok"
    item
}
