package cangjie_community_knowledge_base_test

import std.collection.*
import stdx.encoding.json.*

public class CkbS4ControlDeltaV5 {
    public var ok = false
    public var diagnostic = "not_parsed"
    public var studentContextManifestPath = ""
    public var studentContextManifestHash = ""
    public var studentContextCompositeHash = ""
    public var aggregateAssetLineage = ""
    public var providerPromptCapabilityPath = ""
    public var providerPromptCapabilityHash = ""
    public var effectivePromptByteBudget: Int64 = 0
    public init() {}
}

public func parseCkbS4ControlDeltaV5(bytes: Array<UInt8>): CkbS4ControlDeltaV5 {
    let out = CkbS4ControlDeltaV5()
    let raw = try {
        String.fromUtf8(bytes)
    } catch (_: Exception) {
        out.diagnostic = "invalid_response_encoding"
        return out
    }
    try {
        let o = JsonValue.fromStr(raw).asObject()
        if (o.getFields().size != 7) {
            out.diagnostic = "control_v5_schema_invalid"
            return out
        }
        out.studentContextManifestPath = ckbS4String(o, "studentContextManifestPath")
        out.studentContextManifestHash = ckbS4String(o, "studentContextManifestHash")
        out.studentContextCompositeHash = ckbS4String(o, "compositeHash")
        out.aggregateAssetLineage = ckbS4String(o, "aggregateAssetLineage")
        out.providerPromptCapabilityPath = ckbS4String(o, "providerPromptCapabilityPath")
        out.providerPromptCapabilityHash = ckbS4String(o, "providerPromptCapabilityHash")
        out.effectivePromptByteBudget = ckbS4Int(o, "effectivePromptByteBudget")
        if (out.studentContextManifestPath == "" || !ckbS4Hash(out.studentContextManifestHash) ||
            !ckbS4Hash(out.studentContextCompositeHash) ||
            !["independent", "humaneval_164_derived"].contains(out.aggregateAssetLineage) ||
            out.providerPromptCapabilityPath == "" || !ckbS4Hash(out.providerPromptCapabilityHash) ||
            out.effectivePromptByteBudget < 1) {
            out.diagnostic = "control_v5_binding_invalid"
            return out
        }
        let canonical = renderCkbS4ControlDeltaV5(out)
        if (raw != canonical && raw != canonical + "\n") {
            out.diagnostic = "control_v5_noncanonical"
            return out
        }
        out.ok = true
        out.diagnostic = "ok"
        out
    } catch (_: Exception) {
        out.diagnostic = "control_v5_malformed_json"
        out
    }
}

public func renderCkbS4ControlDeltaV5(value: CkbS4ControlDeltaV5): String {
    "{\"studentContextManifestPath\":\"${ckbS4Escape(value.studentContextManifestPath)}\",\"studentContextManifestHash\":\"${value.studentContextManifestHash}\",\"compositeHash\":\"${value.studentContextCompositeHash}\",\"aggregateAssetLineage\":\"${value.aggregateAssetLineage}\",\"providerPromptCapabilityPath\":\"${ckbS4Escape(value.providerPromptCapabilityPath)}\",\"providerPromptCapabilityHash\":\"${value.providerPromptCapabilityHash}\",\"effectivePromptByteBudget\":${value.effectivePromptByteBudget}}"
}

public func ckbS4PreflightFingerprint(compositeHash: String, combinationAuditHash: String): String {
    benchmarkGapSha256(ckbS4Part(compositeHash) + ckbS4Part(combinationAuditHash))
}

public func ckbS4PreflightBindingDiagnostic(mode: String, compositeHash: String, combinationAuditHash: String,
    providerCount: Int64): String {
    if (!ckbS4Hash(compositeHash) || !ckbS4Hash(combinationAuditHash)) {
        return "student_context_binding_invalid"
    }
    if (mode != "scaffold" && mode != "certification") {
        return "generation_mode_invalid"
    }
    if (mode == "scaffold" && providerCount != 0) {
        return "scaffold_provider_forbidden"
    }
    if (mode == "certification" && providerCount != 1) {
        return "provider_count_must_equal_one"
    }
    "ok"
}

public class CkbS4ProviderPromptCapability {
    public var ok = false
    public var diagnostic = "not_parsed"
    public var model = ""
    public var maxPromptBytes: Int64 = 0
    public var capabilityHash = ""
    public init() {}
}

public func parseCkbS4ProviderPromptCapability(bytes: Array<UInt8>, expectedModel: String, prompt: String): CkbS4ProviderPromptCapability {
    let out = CkbS4ProviderPromptCapability()
    let raw = try {
        String.fromUtf8(bytes)
    } catch (_: Exception) {
        out.diagnostic = "invalid_response_encoding"
        return out
    }
    try {
        let o = JsonValue.fromStr(raw).asObject()
        if (o.getFields().size != 7 || ckbS4String(o, "schemaVersion") != "ckb-provider-prompt-capability-v1") {
            out.diagnostic = "provider_prompt_capability_schema_invalid"
            return out
        }
        out.model = ckbS4String(o, "modelVersion")
        let maxContext = ckbS4Int(o, "maxContextTokens");
        let reserved = ckbS4Int(o, "reservedOutputTokens")
        out.maxPromptBytes = maxContext - reserved
        out.capabilityHash = ckbS4String(o, "capabilityHash")
        let evidence = "{\"schemaVersion\":\"ckb-provider-prompt-capability-v1\",\"modelVersion\":\"${ckbS4Escape(out.model)}\",\"maxContextTokens\":${maxContext},\"reservedOutputTokens\":${reserved},\"sourceEvidence\":\"${ckbS4Escape(ckbS4String(o, "sourceEvidence"))}\",\"observedAtUtc\":\"${ckbS4Escape(ckbS4String(o, "observedAtUtc"))}\"}"
        if (out.model != expectedModel || maxContext <= reserved || reserved < 1 || out.capabilityHash !=
            benchmarkGapSha256(evidence)) {
            out.diagnostic = "provider_prompt_capability_binding_invalid"
            return out
        }
        if (prompt.toArray().size > out.maxPromptBytes) {
            out.diagnostic = "provider_prompt_budget_exceeded"
            return out
        }
        let canonical = evidence.replace("}", ",\"capabilityHash\":\"${out.capabilityHash}\"}")
        if (raw != canonical && raw != canonical + "\n") {
            out.diagnostic = "provider_prompt_capability_noncanonical"
            return out
        }
        out.ok = true
        out.diagnostic = "ok"
        out
    } catch (_: Exception) {
        out.diagnostic = "provider_prompt_capability_malformed_json"
        out
    }
}

public class CkbS4FrozenContextAssets {
    public var protocol = ""
    public var rules = ""
    public var skill = ""
    public var knowledge = ""
    public var providerCapability = ""
    public var publicTask = ""
    public var compositeHash = ""
    public var combinationAuditHash = ""
    public init() {}
}

public func ckbS4FrozenAssetsDiagnostic(assets: CkbS4FrozenContextAssets): String {
    for (value in [assets.protocol, assets.rules, assets.skill, assets.knowledge, assets.providerCapability,
            assets.publicTask]) {
        if (value == "") {
            return "frozen_context_asset_missing"
        }
    }
    if (!ckbS4Hash(assets.compositeHash) || !ckbS4Hash(assets.combinationAuditHash)) {
        return "context_evidence_binding_invalid"
    }
    let visible = assets.protocol + assets.rules + assets.skill + assets.knowledge + assets.publicTask
    if (visible.contains("\"caseId\"") || visible.contains("\"generationProtocol\"")) {
        return "private_protocol_field_forbidden"
    }
    "ok"
}

public func renderCkbS4CompletionPrompt(assets: CkbS4FrozenContextAssets): String {
    if (ckbS4FrozenAssetsDiagnostic(assets) != "ok") {
        return ""
    }
    "## Generation protocol\n\n${assets.protocol}\n\n## Public task\n\n${assets.publicTask}\n\n## Student rules\n\n${assets.rules}\n\n## Student skill\n\n${assets.skill}\n\n## Frozen knowledge\n\n${assets.knowledge}\n\n## Pre-submit checklist\n\nUse the public task to select and apply the relevant supplied rules, skill guidance, and frozen knowledge. Verify the required Cangjie syntax and API usage, boundary behavior, arithmetic definedness and overflow, and exact output contract. Submit exactly one completion.\n"
}

public func renderCkbS4ContextEvidenceV2(assets: CkbS4FrozenContextAssets): String {
    let hashes = [benchmarkGapSha256(assets.protocol), benchmarkGapSha256(assets.rules),
        benchmarkGapSha256(assets.skill), benchmarkGapSha256(assets.knowledge),
        benchmarkGapSha256(assets.providerCapability), benchmarkGapSha256(assets.publicTask)]
    "{\"schemaVersion\":\"ckb-completion-context-evidence-v2\",\"protocolHash\":\"${hashes[0]}\",\"rulesHash\":\"${hashes[1]}\",\"skillHash\":\"${hashes[2]}\",\"knowledgeHash\":\"${hashes[3]}\",\"providerCapabilityHash\":\"${hashes[4]}\",\"publicTaskHash\":\"${hashes[5]}\",\"studentContextCompositeHash\":\"${assets.compositeHash}\",\"combinationAuditHash\":\"${assets.combinationAuditHash}\"}"
}

public func ckbS4FrozenContextEvidenceDiagnostic(assets: CkbS4FrozenContextAssets, evidence: String): String {
    if (ckbS4FrozenAssetsDiagnostic(assets) != "ok") {
        return ckbS4FrozenAssetsDiagnostic(assets)
    }
    if (evidence != renderCkbS4ContextEvidenceV2(assets)) {
        return "context_evidence_drift"
    }
    "ok"
}

public func ckbS4GenerationProtocolDiagnostic(protocol: String, completionCount: Int64, knowledgeEntryCount: Int64,
    toolCallCount: Int64): String {
    if (protocol == "historical-agentic-v1") {
        return "ok"
    }
    if (protocol != "completion-only-v1") {
        return "generation_protocol_invalid"
    }
    if (completionCount != 1) {
        return "single_completion_required"
    }
    if (knowledgeEntryCount != 1) {
        return "completion_knowledge_entry_count_invalid"
    }
    if (toolCallCount != 0) {
        return "completion_tool_call_forbidden"
    }
    "ok"
}

public func ckbS4RulesIdentityDiagnostic(rulesHash: String, rulesTreeHash: String, rulesCount: Int64): String {
    if (!ckbS4Hash(rulesHash) || !ckbS4Hash(rulesTreeHash) || rulesCount < 1 || rulesCount > 16) {
        "rules_identity_invalid"
    } else {
        "ok"
    }
}

private func ckbS4String(o: JsonObject, key: String): String {
    o.get(key).getOrThrow().asString().getValue()
}

private func ckbS4Int(o: JsonObject, key: String): Int64 {
    o.get(key).getOrThrow().asInt().getValue()
}

private func ckbS4Part(value: String): String {
    "${value.toArray().size}:${value}"
}

private func ckbS4Hash(value: String): Bool {
    let runes = value.toRuneArray();
    if (runes.size != 71 || !value.startsWith("sha256:")) {
        return false
    }
    for (i in 7..71) {
        let c = runes[i];
        if (!((c >= r'0' && c <= r'9') || (c >= r'a' && c <= r'f'))) {
            return false
        }
    }
    true
}

private func ckbS4Escape(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
}
