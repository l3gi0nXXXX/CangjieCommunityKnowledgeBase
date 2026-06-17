package cangjie_community_knowledge_base

import std.collection.ArrayList

public class CangjieEvalCategories {
    public static let COMPILE: String = "compile"
    public static let UNIT: String = "unit"
    public static let REPAIR: String = "repair"
    public static let API_HALLUCINATION: String = "api_hallucination"
}

public class CangjieEvalCase {
    public var id: String = ""
    public var category: String = ""
    public var targetVersion: String = ""
    public var prompt: String = ""
    public var entryPoint: String = ""
    public var testCommand: String = ""
    public var expectedKnowledgeTags: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CangjieEvalResult {
    public var ok: Bool = false
    public var status: String = "invalid"
    public var diagnostic: String = ""
    public var evalCase: CangjieEvalCase = CangjieEvalCase()

    public init() {}
}

public func parseCangjieEvalManifestLine(line: String): CangjieEvalResult {
    let result = CangjieEvalResult()
    let raw = line.trimAscii()
    if (raw == "") {
        result.status = "invalid"
        result.diagnostic = "empty_manifest_line"
        return result
    }
    if (!raw.startsWith("{") || !raw.endsWith("}")) {
        result.status = "invalid"
        result.diagnostic = "manifest_line_must_be_json_object"
        return result
    }
    let safe = cangjieEvalAsciiJsonProjection(raw)
    if (cangjieEvalContainsForbiddenSecretField(safe)) {
        result.status = "invalid"
        result.diagnostic = "forbidden_secret_field"
        return result
    }
    if (safe.contains("/Users/")) {
        result.status = "invalid"
        result.diagnostic = "forbidden_user_path"
        return result
    }

    let evalCase = CangjieEvalCase()
    evalCase.id = cangjieEvalJsonStringField(safe, "id").trimAscii()
    evalCase.category = cangjieEvalJsonStringField(safe, "category").trimAscii()
    evalCase.targetVersion = cangjieEvalJsonStringField(safe, "targetVersion").trimAscii()
    evalCase.prompt = cangjieEvalJsonStringField(safe, "prompt")
    evalCase.entryPoint = cangjieEvalJsonStringField(safe, "entryPoint").trimAscii()
    evalCase.testCommand = cangjieEvalJsonStringField(safe, "testCommand").trimAscii()
    evalCase.expectedKnowledgeTags = cangjieEvalJsonStringArrayField(safe, "expectedKnowledgeTags")

    if (evalCase.id == "" || evalCase.testCommand == "") {
        result.status = "bad_request"
        result.diagnostic = "missing_required_field"
        return result
    }
    if (evalCase.category == "" || evalCase.targetVersion == "" || evalCase.prompt == "" || evalCase.entryPoint == "") {
        result.status = "bad_request"
        result.diagnostic = "missing_manifest_metadata"
        return result
    }
    if (!cangjieEvalKnownCategory(evalCase.category)) {
        result.status = "bad_request"
        result.diagnostic = "unsupported_category"
        return result
    }

    result.ok = true
    result.status = "ok"
    result.evalCase = evalCase
    result
}

public func classifyCangjieEvalFailure(output: String): String {
    let text = output.toAsciiLower()
    if (text.contains("unknown package") || text.contains("no such member") || text.contains("not found") || text.contains("undefined")) {
        return CangjieEvalCategories.API_HALLUCINATION
    }
    if (text.contains("expected") || text.contains("actual") || text.contains("assert") || text.contains("test failed")) {
        return CangjieEvalCategories.UNIT
    }
    if (text.contains("repair") || text.contains("patch") || text.contains("diagnostic")) {
        return CangjieEvalCategories.REPAIR
    }
    CangjieEvalCategories.COMPILE
}

public func renderCangjieEvalSummary(cases: ArrayList<CangjieEvalCase>): String {
    var compileCount: Int64 = 0
    var unitCount: Int64 = 0
    var repairCount: Int64 = 0
    var apiHallucinationCount: Int64 = 0

    for (evalCase in cases) {
        if (evalCase.category == CangjieEvalCategories.COMPILE) {
            compileCount += 1
        } else if (evalCase.category == CangjieEvalCategories.UNIT) {
            unitCount += 1
        } else if (evalCase.category == CangjieEvalCategories.REPAIR) {
            repairCount += 1
        } else if (evalCase.category == CangjieEvalCategories.API_HALLUCINATION) {
            apiHallucinationCount += 1
        }
    }

    let total = compileCount + unitCount + repairCount + apiHallucinationCount
    var out = "CangjieEval v0 summary\n"
    out += "totalCases=${total}\n"
    out += "compileCases=${compileCount}\n"
    out += "unitCases=${unitCount}\n"
    out += "repairCases=${repairCount}\n"
    out += "apiHallucinationCases=${apiHallucinationCount}\n"
    out += "compilePassRate=0\n"
    out += "unitPassRate=0\n"
    out += "repairPassRate=0\n"
    out += "apiHallucinationRate=0\n"
    out += "executionMode=parse_only_offline\n"
    out
}

private class CangjieEvalJsonStringScan {
    public var ok: Bool = false
    public var value: String = ""
    public var end: Int64 = 0

    public init() {}
}

private func cangjieEvalKnownCategory(category: String): Bool {
    category == CangjieEvalCategories.COMPILE ||
        category == CangjieEvalCategories.UNIT ||
        category == CangjieEvalCategories.REPAIR ||
        category == CangjieEvalCategories.API_HALLUCINATION
}

private func cangjieEvalContainsForbiddenSecretField(raw: String): Bool {
    cangjieEvalJsonTopLevelValueStart(raw, "token") >= 0 ||
        cangjieEvalJsonTopLevelValueStart(raw, "accessToken") >= 0 ||
        cangjieEvalJsonTopLevelValueStart(raw, "apiKey") >= 0 ||
        cangjieEvalJsonTopLevelValueStart(raw, "password") >= 0 ||
        cangjieEvalJsonTopLevelValueStart(raw, "secret") >= 0
}

private func cangjieEvalAsciiJsonProjection(raw: String): String {
    let out = StringBuilder()
    for (ch in raw.toRuneArray()) {
        if (UInt32(ch) <= 0x7Fu32) {
            out.append(ch)
        } else {
            out.append(r' ')
        }
    }
    out.toString()
}

private func cangjieEvalJsonStringField(raw: String, key: String): String {
    let start = cangjieEvalJsonTopLevelValueStart(raw, key)
    if (start < 0 || start >= raw.size || raw[start..start + 1] != "\"") {
        return ""
    }
    let scan = cangjieEvalReadJsonStringAt(raw, start)
    if (scan.ok) {
        return scan.value
    }
    ""
}

private func cangjieEvalJsonStringArrayField(raw: String, key: String): ArrayList<String> {
    let values = ArrayList<String>()
    let start = cangjieEvalJsonTopLevelValueStart(raw, key)
    if (start < 0 || start >= raw.size || raw[start..start + 1] != "[") {
        return values
    }
    var i = start + 1
    while (i < raw.size) {
        i = cangjieEvalSkipJsonWhitespace(raw, i)
        if (i >= raw.size || raw[i..i + 1] == "]") {
            break
        }
        if (raw[i..i + 1] == "\"") {
            let scan = cangjieEvalReadJsonStringAt(raw, i)
            if (scan.ok) {
                values.add(scan.value)
                i = scan.end
            } else {
                break
            }
        } else {
            i += 1
        }
        i = cangjieEvalSkipJsonWhitespace(raw, i)
        if (i < raw.size && raw[i..i + 1] == ",") {
            i += 1
        }
    }
    values
}

private func cangjieEvalJsonTopLevelValueStart(raw: String, key: String): Int64 {
    var i: Int64 = 0
    var depth: Int64 = 0
    var inString = false
    var escaped = false
    while (i < raw.size) {
        let ch = raw[i..i + 1]
        if (inString) {
            if (escaped) {
                escaped = false
            } else if (ch == "\\") {
                escaped = true
            } else if (ch == "\"") {
                inString = false
            }
            i += 1
            continue
        }
        if (ch == "\"") {
            if (depth == 1) {
                let scan = cangjieEvalReadJsonStringAt(raw, i)
                if (scan.ok && scan.value == key) {
                    var colon = cangjieEvalSkipJsonWhitespace(raw, scan.end)
                    if (colon < raw.size && raw[colon..colon + 1] == ":") {
                        return cangjieEvalSkipJsonWhitespace(raw, colon + 1)
                    }
                }
                i = if (scan.ok) { scan.end } else { i + 1 }
                continue
            }
            inString = true
        } else if (ch == "{" || ch == "[") {
            depth += 1
        } else if (ch == "}" || ch == "]") {
            depth -= 1
        }
        i += 1
    }
    -1
}

private func cangjieEvalReadJsonStringAt(raw: String, start: Int64): CangjieEvalJsonStringScan {
    let scan = CangjieEvalJsonStringScan()
    if (start < 0 || start >= raw.size || raw[start..start + 1] != "\"") {
        return scan
    }
    var i = start + 1
    var escaped = false
    var value = ""
    while (i < raw.size) {
        let ch = raw[i..i + 1]
        if (escaped) {
            value += cangjieEvalJsonUnescapeChar(ch)
            escaped = false
        } else if (ch == "\\") {
            escaped = true
        } else if (ch == "\"") {
            scan.ok = true
            scan.value = value
            scan.end = i + 1
            return scan
        } else {
            value += ch
        }
        i += 1
    }
    scan
}

private func cangjieEvalJsonUnescapeChar(ch: String): String {
    if (ch == "\"") { return "\"" }
    if (ch == "\\") { return "\\" }
    if (ch == "/") { return "/" }
    if (ch == "n") { return "\n" }
    if (ch == "r") { return "\r" }
    if (ch == "t") { return "\t" }
    ch
}

private func cangjieEvalSkipJsonWhitespace(raw: String, start: Int64): Int64 {
    var i = start
    while (i < raw.size) {
        let ch = raw[i..i + 1]
        if (ch != " " && ch != "\n" && ch != "\r" && ch != "\t") {
            break
        }
        i += 1
    }
    i
}
