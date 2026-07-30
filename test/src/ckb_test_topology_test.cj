package cangjie_community_knowledge_base_test

import std.fs.*
import std.unittest.*
import std.unittest.testmacro.*

private let FULL_164_CALL = "r7BuildRealRunnerProof("

public func ckbFull164TestTopologyDiagnostic(
    defaultReleaseSource: String,
    defaultContaminationSource: String,
    integrationSource: String
): String {
    if (ckbFull164CallCount(defaultReleaseSource) +
        ckbFull164CallCount(defaultContaminationSource) != 0) {
        return "default_suite_invokes_full_164"
    }
    if (ckbFull164CallCount(integrationSource) != 1) {
        return "integration_call_count_invalid"
    }
    "ok"
}

private func ckbFull164CallCount(source: String): Int64 {
    let sourceSize = source.toArray().size
    let markerSize = FULL_164_CALL.toArray().size
    let withoutMarkerSize = source.replace(FULL_164_CALL, "").toArray().size
    Int64((sourceSize - withoutMarkerSize) / markerSize)
}

private func ckbReadTopologySource(path: String): String {
    if (!exists(Path(path))) { return "" }
    try {
        String.fromUtf8(File.readFrom(Path(path)))
    } catch (_: Exception) {
        ""
    }
}

@Test
public class CkbTestTopologyTest {
    @TestCase
    public func tsUt01ValidTopologyIsAccepted(): Unit {
        @Expect(ckbFull164TestTopologyDiagnostic(
            "default release", "default contamination",
            "let fixture = r7BuildRealRunnerProof(records)"), "ok")
    }

    @TestCase
    public func tsBnd01ZeroAndDuplicateIntegrationCallsAreRejected(): Unit {
        @Expect(ckbFull164TestTopologyDiagnostic("", "", ""),
            "integration_call_count_invalid")
        @Expect(ckbFull164TestTopologyDiagnostic("", "",
            "r7BuildRealRunnerProof(a); r7BuildRealRunnerProof(b)"),
            "integration_call_count_invalid")
    }

    @TestCase
    public func tsNeg01DefaultInvocationIsRejected(): Unit {
        @Expect(ckbFull164TestTopologyDiagnostic(
            "r7BuildRealRunnerProof(records)", "",
            "r7BuildRealRunnerProof(records)"),
            "default_suite_invokes_full_164")
    }

    @TestCase
    public func tsPos01RepositoryTopologyHasOneExplicitIntegrationCall(): Unit {
        let releaseSource = ckbReadTopologySource(
            "src/cangjie_certified_production_release_test.cj")
        let contaminationSource = ckbReadTopologySource(
            "src/cangjie_student_contamination_gate_accuracy_test.cj")
        let integrationSource = ckbReadTopologySource(
            "../integration-test/src/ckb_full_164_integration_test.cj")
        @Expect(ckbFull164TestTopologyDiagnostic(releaseSource,
            contaminationSource, integrationSource), "ok")
    }
}
