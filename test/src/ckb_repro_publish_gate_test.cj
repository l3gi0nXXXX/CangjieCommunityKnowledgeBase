package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*

private class P9FakeGitProvider <: CkbReproGitEvidenceProvider {
    public let evidence: CkbReproGitEvidence
    public var calls: Int64 = 0
    public init(value: CkbReproGitEvidence) { this.evidence = value }
    public func inspect(): CkbReproGitEvidence {
        this.calls += 1
        this.evidence
    }
}

private class P9FakeSignatureVerifier <: CkbReproSignatureVerifier {
    public let evidence: CkbReproSignatureEvidence
    public var calls: Int64 = 0
    public init(value: CkbReproSignatureEvidence) { this.evidence = value }
    public func verify(): CkbReproSignatureEvidence {
        this.calls += 1
        this.evidence
    }
}

@Test
public class CkbReproPublishGateTest {
    @TestCase
    public func p9Pos01PublishGateContractComponent(): Unit {
        let options = p9GateOptions("pre-tag")
        let git = P9FakeGitProvider(p9GitEvidence(false))
        let signature = P9FakeSignatureVerifier(p9SignatureEvidence(false))
        let result = validateCkbReproPublishBundle(options,
            p9PublishEvidence(), git, signature)
        @Expect(result.componentReady, true)
        @Expect(result.publishable, false)
        @Expect(result.diagnostic, "component_ready_external_proofs_required")
        @Expect(git.calls, 1)
        @Expect(signature.calls, 1)

        let post = p9GateOptions("post-tag")
        let postResult = validateCkbReproPublishBundle(post,
            p9PublishEvidence(),
            P9FakeGitProvider(p9GitEvidence(true)),
            P9FakeSignatureVerifier(p9SignatureEvidence(true)))
        @Expect(postResult.componentReady, true)
        @Expect(postResult.publishable, false)
    }

    @TestCase
    public func p9Neg01PublishGateContractComponent(): Unit {
        let bad = p9PublishEvidence()
        bad.leakageFindingCount = 1
        let result = validateCkbReproPublishBundle(p9GateOptions("pre-tag"),
            bad, P9FakeGitProvider(p9GitEvidence(false)),
            P9FakeSignatureVerifier(p9SignatureEvidence(false)))
        @Expect(result.componentReady, false)
        @Expect(result.diagnostic, "publish_leakage_gate_failed")
        let drift = p9GitEvidence(false)
        drift.originRepository = "other/repository"
        @Expect(validateCkbTagReleaseBindingEvidence(p9GateOptions("pre-tag"),
            drift, p9SignatureEvidence(false)).diagnostic,
            "publish_repository_mismatch")
        let invalidIdentity = p9GateOptions("pre-tag")
        invalidIdentity.signingFingerprint = "short"
        @Expect(validateCkbTagReleaseBindingEvidence(invalidIdentity,
            p9GitEvidence(false), p9SignatureEvidence(false)).diagnostic,
            "publish_identity_invalid")
        let rendered = renderCkbReproPublishGateReport(result)
        @Expect(rendered.contains("/Users/"), false)
        @Expect(rendered.contains("Authorization"), false)
        let handcrafted = p9PublishEvidence()
        handcrafted.externalProofsVerified = true
        let blocked = validateCkbReproPublishBundle(p9GateOptions("pre-tag"),
            handcrafted, P9FakeGitProvider(p9GitEvidence(false)),
            P9FakeSignatureVerifier(p9SignatureEvidence(false)))
        @Expect(blocked.componentReady, true)
        @Expect(blocked.publishable, false)
    }
}

private func p9GateOptions(mode: String): CkbReproPublishGateOptions {
    let options = CkbReproPublishGateOptions()
    options.mode = mode
    options.releaseRepository = "l3gi0nXXXX/CangjieCommunityKnowledgeBase"
    options.releaseCommit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    options.tagName = "ckb-repro-v1"
    options.releaseTitle = "CKB reproducible knowledge v1"
    options.signingFingerprint =
        "0123456789ABCDEF0123456789ABCDEF01234567"
    options
}

private func p9GitEvidence(tagExists: Bool): CkbReproGitEvidence {
    let evidence = CkbReproGitEvidence()
    evidence.originRepository = "git@github.com:l3gi0nXXXX/CangjieCommunityKnowledgeBase.git"
    evidence.headCommit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    evidence.originMainCommit = evidence.headCommit
    evidence.tagExistsLocal = tagExists
    evidence.tagExistsRemote = tagExists
    evidence.tagCommit = if (tagExists) { evidence.headCommit } else { "" }
    evidence
}

private func p9SignatureEvidence(tagSigned: Bool): CkbReproSignatureEvidence {
    let evidence = CkbReproSignatureEvidence()
    evidence.shaSumsVerified = true
    evidence.shaSumsFingerprint =
        "0123456789ABCDEF0123456789ABCDEF01234567"
    evidence.tagSigned = tagSigned
    evidence.tagFingerprint = if (tagSigned) {
        evidence.shaSumsFingerprint
    } else { "" }
    evidence
}

private func p9PublishEvidence(): CkbReproPublishEvidence {
    let evidence = CkbReproPublishEvidence()
    evidence.inputSetHashMatches = true
    evidence.manifestCoverageComplete = true
    evidence.shaCoverageComplete = true
    evidence.noSelfReference = true
    evidence.p8BindingMatches = true
    evidence.runCriticalTreeMatches = true
    evidence.strictPassed = 151
    evidence.transportUnresolved = 0
    evidence.leakageFindingCount = 0
    evidence.fullTestsPassed = true
    evidence.licenseComplete = true
    evidence.externalProofsVerified = false
    evidence
}
