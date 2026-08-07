package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashMap, HashSet}
import std.fs.{Directory, File, FileInfo, Path, exists, rename, remove}
import std.sort.*
import stdx.encoding.json.*

public class CkbStudentRuleTestRow {
    public var testId = "";
    public var kind = "";
    public var fixturePath = "";
    public var fixtureHash = ""
    public var sourceClass = "";
    public var passed = false;
    public var resultHash = "";
    public init() {}
}

public class CkbStudentRuleCandidate {
    public var verified = false;
    public var diagnostic = "not_parsed";
    public var root = ""
    public var ruleId = "";
    public var conceptId = "";
    public var title = "";
    public var body = ""
    public var trigger = "";
    public var scope = "";
    public var priority: Int64 = 0
    public var sourceEvidenceKind = "";
    public var sourceEvidenceHash = "";
    public var assetLineage = ""
    public var positiveEvidenceHash = "";
    public var negativeEvidenceHash = "";
    public var boundaryEvidenceHash = ""
    public var generalizationEvidenceHash = "";
    public var canonicalHash = "";
    public var agentsMarkdown = ""
    public init() {}
}

public class CkbStudentRulesBundle {
    public var ok = false;
    public var diagnostic = "not_built";
    public var rulesVersion = ""
    public var ruleCount: Int64 = 0;
    public var contentBytes: Int64 = 0;
    public var canonicalHash = ""
    public var json = "";
    public var agentsMarkdown = "";
    public init() {}
}

public func parseStudentRuleCandidateDirectory(rootPath: String): CkbStudentRuleCandidate {
    let c = CkbStudentRuleCandidate();
    c.root = rootPath
    let root = Path(rootPath)
    if (!exists(root)) {
        c.diagnostic = "rule_candidate_directory_missing"
        return c
    }
    try {
        if (FileInfo(root).isSymbolicLink() || !FileInfo(root).isDirectory()) {
            c.diagnostic = "rule_candidate_directory_invalid"
            return c
        }
        let expected = HashSet<String>(["AGENTS.md", "candidate-manifest.json", "operation.json", "tests"])
        for (e in Directory.readFrom(root)) {
            if (e.isSymbolicLink() || !expected.contains(e.name)) {
                c.diagnostic = "rule_candidate_directory_entry_invalid"
                return c
            };
            expected.remove(e.name)
        }
        if (!expected.isEmpty()) {
            c.diagnostic = "rule_candidate_directory_incomplete"
            return c
        }
        for (name in ["AGENTS.md", "candidate-manifest.json", "operation.json"]) {
            let p = root.join(name);
            if (FileInfo(p).isSymbolicLink() || !FileInfo(p).isRegular()) {
                c.diagnostic = "rule_candidate_regular_file_required"
                return c
            }
        }
        let markdown = ckbRuleRead(root.join("AGENTS.md"));
        let manifestDisk = ckbRuleRead(root.join("candidate-manifest.json"));
        let operationDisk = ckbRuleRead(root.join("operation.json"))
        if (markdown[1] != "ok" || manifestDisk[1] != "ok" || operationDisk[1] != "ok") {
            c.diagnostic = "invalid_response_encoding"
            return c
        }
        if (markdown[0].contains("\r") || manifestDisk[0].contains("\r") || operationDisk[0].contains("\r") ||
            !markdown[0].endsWith("\n") || !manifestDisk[0].endsWith("\n") || !operationDisk[0].endsWith("\n")) {
            c.diagnostic = "rule_candidate_lf_contract_invalid"
            return c
        }
        let o = JsonValue.fromStr(manifestDisk[0].trimAscii()).asObject();
        if (o.getFields().size != 17) {
            c.diagnostic = "rule_candidate_manifest_fields_invalid"
            return c
        }
        c.ruleId = ckbRuleString(o, "ruleId")
        c.conceptId = ckbRuleString(o, "conceptId")
        c.title = ckbRuleString(o, "title")
        c.body = ckbRuleString(o, "body")
        c.trigger = ckbRuleString(o, "trigger")
        c.scope = ckbRuleString(o, "scope")
        c.priority = ckbRuleInt(o, "priority")
        c.sourceEvidenceKind = ckbRuleString(o, "sourceEvidenceKind")
        c.sourceEvidenceHash = ckbRuleString(o, "sourceEvidenceHash")
        c.assetLineage = ckbRuleString(o, "assetLineage")
        c.positiveEvidenceHash = ckbRuleString(o, "positiveEvidenceHash")
        c.negativeEvidenceHash = ckbRuleString(o, "negativeEvidenceHash")
        c.boundaryEvidenceHash = ckbRuleString(o, "boundaryEvidenceHash")
        c.generalizationEvidenceHash = ckbRuleString(o, "generalizationEvidenceHash")
        c.canonicalHash = ckbRuleString(o, "canonicalHash")
        c.agentsMarkdown = markdown[0]
        if (ckbRuleString(o, "schemaVersion") != "teacher-rule-candidate-v1" || ckbRuleString(o, "assetRole") != "rules" ||
            !["independent_manifest", "completion_failure"].contains(c.sourceEvidenceKind) ||
            !["independent", "humaneval_164_derived"].contains(c.assetLineage) || (c.sourceEvidenceKind ==
            "completion_failure" && c.assetLineage != "humaneval_164_derived")) {
            c.diagnostic = "rule_candidate_identity_invalid"
            return c
        }
        if (c.ruleId == "" || c.conceptId == "" || c.title == "" || c.body == "" || c.trigger == "" || c.scope == "" ||
            c.priority < 0 || c.priority > 1000 || !ckbRuleHash(c.sourceEvidenceHash) ||
            !ckbRuleHash(c.positiveEvidenceHash) || !ckbRuleHash(c.negativeEvidenceHash) ||
            !ckbRuleHash(c.boundaryEvidenceHash) || !ckbRuleHash(c.generalizationEvidenceHash) ||
            (c.sourceEvidenceKind == "independent_manifest") != (c.assetLineage == "independent") || ckbRuleProtected(
            c.ruleId + "\n" + c.title + "\n" + c.body + "\n" + c.trigger + "\n" + c.scope)) {
            c.diagnostic = "rule_candidate_content_invalid"
            return c
        }
        if (renderStudentRuleCandidateManifest(c) != manifestDisk[0].trimAscii()) {
            c.diagnostic = "rule_candidate_hash_mismatch"
            return c
        }
        let operation = JsonValue.fromStr(operationDisk[0].trimAscii()).asObject()
        if (operation.getFields().size != 6 || ckbRuleString(operation, "schemaVersion") !=
            "teacher-context-asset-operation-v1" || ckbRuleString(operation, "assetRole") != "rules" ||
            ckbRuleString(operation, "assetId") != c.ruleId ||
            !["add", "replace"].contains(ckbRuleString(operation, "operation")) || ckbRuleString(operation, "newHash") !=
            c.canonicalHash || (ckbRuleString(operation, "operation") == "add" &&
            ckbRuleString(operation, "expectedOldHash") != "") || (ckbRuleString(operation, "operation") == "replace" &&
            !ckbRuleHash(ckbRuleString(operation, "expectedOldHash")))) {
            c.diagnostic = "candidate_operation_invalid"
            return c
        }
        let expectedMarkdown = "# Student Rules\n\n## ${c.title}\n\n${c.body}\n\nTrigger: ${c.trigger}\nScope: ${c.scope}\n"
        if (markdown[0] != expectedMarkdown) {
            c.diagnostic = "rule_markdown_semantic_mismatch"
            return c
        }
        let testDiagnostic = ckbRuleValidateExecutionTree(root, c);
        if (testDiagnostic != "ok") {
            c.diagnostic = testDiagnostic
            return c
        }
        c.verified = true
        c.diagnostic = "ok"
        c
    } catch (_: Exception) {
        c.diagnostic = "malformed_json"
        c
    }
}

public func validateStudentRuleCandidate(candidate: CkbStudentRuleCandidate): String {
    if (candidate.verified) {
        "ok"
    } else {
        candidate.diagnostic
    }
}

public func renderStudentRuleCandidateManifest(c: CkbStudentRuleCandidate): String {
    let fields = ckbRuleCanonicalFields(c);
    "{${fields},\"canonicalHash\":\"${ckbStudentRuleCandidateCanonicalHash(c)}\"}"
}

public func ckbStudentRuleCandidateCanonicalHash(c: CkbStudentRuleCandidate): String {
    benchmarkGapSha256(
        ckbRulePart(c.ruleId) + ckbRulePart(c.conceptId) + ckbRulePart(c.title) + ckbRulePart(c.body) + ckbRulePart(
            c.trigger) + ckbRulePart(c.scope) + ckbRulePart(c.priority.toString()) + ckbRulePart(c.sourceEvidenceKind) +
            ckbRulePart(c.sourceEvidenceHash) + ckbRulePart("rules") + ckbRulePart(c.assetLineage) + ckbRulePart(
            c.positiveEvidenceHash) + ckbRulePart(c.negativeEvidenceHash) + ckbRulePart(c.boundaryEvidenceHash) +
            ckbRulePart(c.generalizationEvidenceHash))
}

private func ckbRuleCanonicalFields(c: CkbStudentRuleCandidate): String {
    "\"schemaVersion\":\"teacher-rule-candidate-v1\",\"ruleId\":\"${ckbRuleEscape(c.ruleId)}\",\"conceptId\":\"${ckbRuleEscape(c.conceptId)}\",\"title\":\"${ckbRuleEscape(c.title)}\",\"body\":\"${ckbRuleEscape(c.body)}\",\"trigger\":\"${ckbRuleEscape(c.trigger)}\",\"scope\":\"${ckbRuleEscape(c.scope)}\",\"priority\":${c.priority},\"sourceEvidenceKind\":\"${c.sourceEvidenceKind}\",\"sourceEvidenceHash\":\"${c.sourceEvidenceHash}\",\"assetRole\":\"rules\",\"assetLineage\":\"${c.assetLineage}\",\"positiveEvidenceHash\":\"${c.positiveEvidenceHash}\",\"negativeEvidenceHash\":\"${c.negativeEvidenceHash}\",\"boundaryEvidenceHash\":\"${c.boundaryEvidenceHash}\",\"generalizationEvidenceHash\":\"${c.generalizationEvidenceHash}\""
}

public func compileStudentRulesBundle(version: String, rules: ArrayList<CkbStudentRuleCandidate>): CkbStudentRulesBundle {
    let out = CkbStudentRulesBundle();
    out.rulesVersion = version
    if (version == "") {
        out.diagnostic = "rules_version_required"
        return out
    };
    if (rules.size == 0) {
        out.diagnostic = "student_rules_bundle_empty"
        return out
    };
    if (rules.size > 16) {
        out.diagnostic = "student_rule_count_exceeded"
        return out
    }
    let identities = HashSet<String>();
    let identityContent = HashMap<String, String>();
    let ruleIds = HashMap<String, String>();
    let bodies = HashSet<String>();
    let unique = ArrayList<CkbStudentRuleCandidate>()
    for (r in rules) {
        if (!r.verified) {
            out.diagnostic = "student_rule_candidate_unverified"
            return out
        };
        if (ruleIds.contains(r.ruleId)) {
            if (ruleIds[r.ruleId] != r.canonicalHash) {
                out.diagnostic = "rule_conflict_requires_review"
                return out
            };
            continue
        };
        let identity = "rules\u{0000}${r.conceptId}\u{0000}${r.sourceEvidenceKind}\u{0000}${r.sourceEvidenceHash}";
        if (identities.contains(identity)) {
            if (identityContent[identity] != r.canonicalHash) {
                out.diagnostic = "rule_conflict_requires_review"
                return out
            };
            continue
        };
        if (bodies.contains(r.body)) {
            out.diagnostic = "duplicate_rule_body"
            return out
        };
        ruleIds[r.ruleId] = r.canonicalHash
        identities.add(identity);
        identityContent[identity] = r.canonicalHash
        bodies.add(r.body);
        unique.add(r)
    }
    let priorityOrdered = unique.toArray();
    sort(
        priorityOrdered,
        by: {
            a: CkbStudentRuleCandidate, b: CkbStudentRuleCandidate =>
            let priority = b.priority.compare(a.priority);
            if (priority != Ordering.EQ) {
                priority
            } else {
                a.ruleId.compare(b.ruleId)
            }
        }
    );
    var markdown = "# Student Rules\n";
    for (r in priorityOrdered) {
        markdown += "\n## ${r.title}\n\n${r.body}\n\nTrigger: ${r.trigger}\nScope: ${r.scope}\n"
    }
    let ordered = unique.toArray();
    sort(ordered, by: {a: CkbStudentRuleCandidate, b: CkbStudentRuleCandidate => a.ruleId.compare(b.ruleId)});
    var body = ""
    for (i in 0..ordered.size) {
        let r = ordered[i];
        if (i > 0) {
            body += ","
        };
        let content = "\n## ${r.title}\n\n${r.body}\n\nTrigger: ${r.trigger}\nScope: ${r.scope}\n"
        body += "{\"schemaVersion\":\"teacher-rule-candidate-v1\",\"ruleId\":\"${ckbRuleEscape(r.ruleId)}\",\"conceptId\":\"${ckbRuleEscape(r.conceptId)}\",\"title\":\"${ckbRuleEscape(r.title)}\",\"body\":\"${ckbRuleEscape(r.body)}\",\"trigger\":\"${ckbRuleEscape(r.trigger)}\",\"scope\":\"${ckbRuleEscape(r.scope)}\",\"priority\":${r.priority},\"sourceEvidenceKind\":\"${r.sourceEvidenceKind}\",\"sourceEvidenceHash\":\"${r.sourceEvidenceHash}\",\"assetRole\":\"rules\",\"assetLineage\":\"${r.assetLineage}\",\"positiveEvidenceHash\":\"${r.positiveEvidenceHash}\",\"negativeEvidenceHash\":\"${r.negativeEvidenceHash}\",\"boundaryEvidenceHash\":\"${r.boundaryEvidenceHash}\",\"generalizationEvidenceHash\":\"${r.generalizationEvidenceHash}\",\"contentHash\":\"${benchmarkGapSha256(content)}\",\"canonicalHash\":\"${r.canonicalHash}\",\"content\":\"${ckbRuleEscape(content)}\"}"
    }
    let bytes = Int64(markdown.toArray().size);
    if (bytes > 8192) {
        out.diagnostic = "rules_bundle_too_large"
        return out
    }
    let fields = "\"schemaVersion\":\"ckb-student-rules-bundle-v1\",\"rulesVersion\":\"${ckbRuleEscape(version)}\",\"ruleCount\":${unique.size},\"contentBytes\":${bytes},\"rules\":[${body}]";
    out.canonicalHash = benchmarkGapSha256("{${fields}}")
    out.json = "{${fields},\"canonicalHash\":\"${out.canonicalHash}\"}"
    out.agentsMarkdown = markdown
    out.ruleCount = Int64(unique.size)
    out.contentBytes = bytes
    out.ok = true
    out.diagnostic = "ok"
    out
}

public func renderStudentRulesBundle(bundle: CkbStudentRulesBundle): String {
    bundle.json
}

public func freezeStudentRulesBundle(output: String, bundle: CkbStudentRulesBundle): String {
    publishStudentRulesBundle(output, bundle)
}

public func publishStudentRulesBundle(output: String, bundle: CkbStudentRulesBundle): String {
    if (!bundle.ok) {
        return "student_rules_bundle_not_publishable"
    };
    let path = Path(output);
    let bytes = (bundle.json + "\n").toArray()
    let tmp = path.parent.join(".${path.fileName}.tmp-${bundle.canonicalHash.replace("sha256:", "")}");
    var created = false
    try {
        if (exists(path)) {
            return if (File.readFrom(path) == bytes) {
                "ok"
            } else {
                "student_rules_bundle_immutable_conflict"
            }
        };
        if (!exists(path.parent)) {
            Directory.create(path.parent, recursive: true)
        };
        if (exists(tmp)) {
            return "student_rules_bundle_publish_failed"
        };
        File.writeTo(tmp, bytes);
        created = true
        if (File.readFrom(tmp) != bytes) {
            remove(tmp);
            created = false
            return "student_rules_bundle_write_mismatch"
        };
        rename(tmp.toString(), to: path.toString(), overwrite: false);
        created = false
        "ok"
    } catch (_: Exception) {
        try {
            if (created && exists(tmp)) {
                remove(tmp)
            }
        } catch (_: Exception) {}
        "student_rules_bundle_publish_failed"
    }
}

private func ckbRuleValidateExecutionTree(root: Path, candidate: CkbStudentRuleCandidate): String {
    let tests = root.join("tests");
    if (!exists(tests) || FileInfo(tests).isSymbolicLink() || !FileInfo(tests).isDirectory()) {
        return "rule_tests_tree_invalid"
    };
    var unit: Int64 = 0;
    var positive: Int64 = 0;
    var negative: Int64 = 0;
    var boundary: Int64 = 0;
    var general: Int64 = 0;
    let ids = HashSet<String>();
    var positiveId = "";
    var negativeId = "";
    var boundaryId = "";
    var generalId = "";
    var stablePositive = "";
    var stableNegative = "";
    var stableBoundary = "";
    var stableGeneral = ""
    for (dir in Directory.readFrom(tests)) {
        if (dir.isSymbolicLink() || !dir.isDirectory() || ids.contains(dir.name)) {
            return "rule_tests_tree_invalid"
        };
        ids.add(dir.name);
        let names = HashSet<String>(["fixture.json", "expected.txt", "actual.txt", "transcript.txt", "execution.json"]);
        for (e in Directory.readFrom(dir.path)) {
            if (e.isSymbolicLink() || !e.isRegular() || !names.contains(e.name)) {
                return "rule_tests_tree_invalid"
            };
            names.remove(e.name)
        };
        if (!names.isEmpty()) {
            return "rule_tests_tree_invalid"
        };
        try {
            let fixture = ckbRuleRead(dir.path.join("fixture.json"));
            let expected = ckbRuleRead(dir.path.join("expected.txt"));
            let actual = ckbRuleRead(dir.path.join("actual.txt"));
            let transcript = ckbRuleRead(dir.path.join("transcript.txt"));
            let executionDisk = ckbRuleRead(dir.path.join("execution.json"));
            for (read in [fixture, expected, actual, transcript, executionDisk]) {
                if (read[1] != "ok" || !ckbRuleExactlyOneStructuralLf(read[0])) {
                    return "invalid_response_encoding"
                }
            };
            let expectedSemantic = ckbRuleRemoveStructuralLf(expected[0]);
            let actualSemantic = ckbRuleRemoveStructuralLf(actual[0]);
            let transcriptSemantic = ckbRuleTranscriptSemantic(ckbRuleRemoveStructuralLf(transcript[0]));
            let fixtureObject = JsonValue.fromStr(fixture[0].trimAscii()).asObject();
            let fixtureId = ckbRuleString(fixtureObject, "fixtureId");
            let fixtureKind = ckbRuleString(fixtureObject, "kind");
            let fixtureSource = ckbRuleString(fixtureObject, "sourceClass");
            let fixtureContent = ckbRuleString(fixtureObject, "content");
            let fixtureExpected = ckbRuleString(fixtureObject, "expectedEvidence");
            let fixtureHash = benchmarkGapSha256(
                ckbRulePart(fixtureId) + ckbRulePart(fixtureKind) + ckbRulePart(fixtureSource) + ckbRulePart(
                    fixtureContent) + ckbRulePart(fixtureExpected));
            let fixtureCanonical = "{\"schemaVersion\":\"teacher-asset-fixture-v1\",\"fixtureId\":\"${ckbRuleEscape(fixtureId)}\",\"kind\":\"${fixtureKind}\",\"sourceClass\":\"${fixtureSource}\",\"content\":\"${ckbRuleEscape(fixtureContent)}\",\"expectedEvidence\":\"${ckbRuleEscape(fixtureExpected)}\",\"fixtureHash\":\"${fixtureHash}\"}\n";
            let o = JsonValue.fromStr(executionDisk[0].trimAscii()).asObject();
            let kind = ckbRuleString(o, "kind");
            let source = ckbRuleString(o, "sourceClass");
            let executor = ckbRuleString(o, "executorKind");
            let provider = ckbRuleString(o, "providerIdentityHash");
            let model = ckbRuleString(o, "modelVersion");
            let expectedHash = benchmarkGapSha256(expectedSemantic);
            let actualHash = benchmarkGapSha256(actualSemantic);
            let transcriptHash = benchmarkGapSha256(transcriptSemantic);
            let executionCanonical = "{\"schemaVersion\":\"teacher-candidate-fixture-execution-v1\",\"fixtureId\":\"${ckbRuleEscape(fixtureId)}\",\"kind\":\"${kind}\",\"sourceClass\":\"${source}\",\"fixtureHash\":\"${fixtureHash}\",\"executorKind\":\"${executor}\",\"providerIdentityHash\":\"${provider}\",\"modelVersion\":\"${ckbRuleEscape(model)}\",\"expectedEvidenceHash\":\"${expectedHash}\",\"actualEvidenceHash\":\"${actualHash}\",\"transcriptHash\":\"${transcriptHash}\",\"exitCode\":${ckbRuleInt(o, "exitCode")},\"passed\":${ckbRuleBool(o, "passed")}}\n";
            if (fixtureObject.getFields().size != 7 || fixture[0] != fixtureCanonical || fixtureId != dir.name ||
                fixtureKind != kind || fixtureSource != source || fixtureExpected != expectedSemantic ||
                o.getFields().size != 13 || executionDisk[0] != executionCanonical ||
                ckbRuleString(o, "schemaVersion") != "teacher-candidate-fixture-execution-v1" ||
                ckbRuleString(o, "fixtureId") != dir.name ||
                !["unit", "positive", "negative", "boundary", "generalization"].contains(kind) ||
                !["official", "community", "non_humaneval_experiment"].contains(source) || (kind == "generalization" &&
                source != "non_humaneval_experiment") ||
                !["fake_contract", "student_completion_non_humaneval"].contains(executor) || !ckbRuleHash(provider) ||
                model == "" || fixtureHash != ckbRuleString(o, "fixtureHash") || expectedHash != ckbRuleString(o,
                "expectedEvidenceHash") || actualHash != ckbRuleString(o, "actualEvidenceHash") || transcriptHash !=
                ckbRuleString(o, "transcriptHash") || ckbRuleInt(o, "exitCode") != 0 || !ckbRuleBool(o, "passed") ||
                expectedSemantic != actualSemantic || ckbRuleProtected(fixtureContent + expectedSemantic + actualSemantic + transcriptSemantic)) {
                return "candidate_test_evidence_invalid"
            };
            if (kind == "unit") {
                unit += 1
            } else if (kind == "positive") {
                positive += 1
                if (positiveId == "" || fixtureId.compare(positiveId) == Ordering.LT) {
                    positiveId = fixtureId
                    stablePositive = transcriptHash
                }
            } else if (kind == "negative") {
                negative += 1
                if (negativeId == "" || fixtureId.compare(negativeId) == Ordering.LT) {
                    negativeId = fixtureId
                    stableNegative = transcriptHash
                }
            } else if (kind == "boundary") {
                boundary += 1
                if (boundaryId == "" || fixtureId.compare(boundaryId) == Ordering.LT) {
                    boundaryId = fixtureId
                    stableBoundary = transcriptHash
                }
            } else {
                general += 1
                if (generalId == "" || fixtureId.compare(generalId) == Ordering.LT) {
                    generalId = fixtureId
                    stableGeneral = transcriptHash
                }
            }
        } catch (_: Exception) {
            return "candidate_test_evidence_invalid"
        }
    }
    if (unit < 1 || positive < 1 || negative < 1 || boundary < 1 || general < 3) {
        return "rule_test_category_count_invalid"
    }
    if (candidate.positiveEvidenceHash != stablePositive || candidate.negativeEvidenceHash != stableNegative ||
        candidate.boundaryEvidenceHash != stableBoundary || candidate.generalizationEvidenceHash != stableGeneral) {
        return "candidate_test_evidence_invalid"
    };
    "ok"
}

private func ckbRuleRead(path: Path): (String, String) {
    try {
        (String.fromUtf8(File.readFrom(path)), "ok")
    } catch (_: Exception) {
        ("", "invalid_response_encoding")
    }
}

private func ckbRuleExactlyOneStructuralLf(v: String): Bool {
    v.endsWith("\n") && !v.endsWith("\n\n") && !v.contains("\r")
}

private func ckbRuleRemoveStructuralLf(v: String): String {
    let runes = v.toRuneArray();
    var out = ""
    for (i in 0..(runes.size - 1)) {
        out += runes[i].toString()
    };
    out
}

private func ckbRuleTranscriptSemantic(v: String): String {
    let normalized = v.replace("\r\n", "\n").replace("\r", "\n");
    let runes = normalized.toRuneArray();
    var end = runes.size
    while (end > 0 && runes[end - 1] == r'\n') {
        end -= 1
    };
    var out = ""
    for (i in 0..end) {
        out += runes[i].toString()
    };
    out
}

private func ckbRuleProtected(v: String): Bool {
    ckbStudentVisibleAssetForbidden(v)
}

private func ckbRuleString(o: JsonObject, k: String): String {
    o.get(k).getOrThrow().asString().getValue()
}

private func ckbRuleInt(o: JsonObject, k: String): Int64 {
    o.get(k).getOrThrow().asInt().getValue()
}

private func ckbRuleBool(o: JsonObject, k: String): Bool {
    o.get(k).getOrThrow().asBool().getValue()
}

private func ckbRuleHash(v: String): Bool {
    let r = v.toRuneArray();
    if (r.size != 71 || !v.startsWith("sha256:")) {
        return false
    };
    for (i in 7..71) {
        let c = r[i];
        if (!((c >= r'0' && c <= r'9') || (c >= r'a' && c <= r'f'))) {
            return false
        }
    };
    true
}

private func ckbRulePart(v: String): String {
    "${v.toArray().size}:${v}"
}

private func ckbRuleEscape(v: String): String {
    v.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
}
