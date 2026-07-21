package cangjie_community_knowledge_base_test

// Builds a public, case-independent atom fixture. Positive routine tests use
// this instead of the legacy case-bound evaluation projection rejected by R4.
public func ckbR4AtomicCurationInput(caseId: String, atomId: String,
    knowledgeText: String): String {
    let marker = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
    let rawBundle = "{\"atomId\":\"${atomId}\",\"sourceClass\":\"official\",\"citation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection\",\"targetVersion\":\"1.0.0\",\"candidateHash\":\"${marker}\",\"knowledgeText\":\"${knowledgeText}\",\"example\":\"Use values.add(item) to append one item.\",\"purificationPassed\":true,\"tests\":[{\"category\":\"positive\",\"operation\":\"arraylist_size\",\"input\":\"[1,2,3]\",\"expected\":\"3\"},{\"category\":\"negative\",\"operation\":\"contains\",\"input\":\"ArrayList\",\"needle\":\"HashMap\",\"expected\":\"false\"},{\"category\":\"boundary\",\"operation\":\"rune_count\",\"input\":\"中文😀\",\"expected\":\"3\"}]}"
    let bundle = rawBundle.replace(marker, cangjieKnowledgeAtomCandidateHash(rawBundle))
    "{\"caseId\":\"${caseId}\",\"benchmark\":\"public-cangjie-regression\",\"taskText\":\"Use general ArrayList append operations.\",\"compilerOutput\":\"unknown member add\",\"missingKnowledge\":\"G-ARRAYLIST\",\"interfaceId\":\"KI-02\",\"contentFamily\":\"KC-02\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"1.0.0\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection\",\"knowledgeAtomCandidate\":true,\"knowledgeAtomTestBundle\":${bundle}}\n"
}
