package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.convert.Parsable

public class CkbMcpDispatchResult {
    public var shouldWrite: Bool = true
    public var payload: String = ""

    public init() {}
}

public func ckbMcpDispatchResponse(payload: String): CkbMcpDispatchResult {
    let result = CkbMcpDispatchResult()
    result.shouldWrite = true
    result.payload = payload
    result
}

public func ckbMcpDispatchNoOutput(): CkbMcpDispatchResult {
    let result = CkbMcpDispatchResult()
    result.shouldWrite = false
    result.payload = ""
    result
}

public class CkbMcpStdioServer {
    private let service: CkbCommandLoopService
    private let maxRequestChars: Int64 = 65536
    private let maxTextChars: Int64 = CangjieCapabilityLimits.MAX_TEXT_CHARS

    public init(service: CkbCommandLoopService) {
        this.service = service
    }

    public func handleLine(line: String): CkbMcpDispatchResult {
        this.handleMessage(line, ckbMcpProtocolVersionFromInitialize(line, "2024-11-05"), "ckb-cangjie-mcp-stdio")
    }

    public func handleRequest(request: String): String {
        this.handleMessage(request, ckbMcpProtocolVersionFromInitialize(request, "2024-11-05"), "ckb-cangjie-mcp-stdio").payload
    }

    public func handleMessage(request: String, protocolVersion: String, serverName: String): CkbMcpDispatchResult {
        if (request.size > this.maxRequestChars) {
            return ckbMcpDispatchResponse(this.errorResponse("null", -32600, "request_too_large", "{\"limit\":${this.maxRequestChars}}"))
        }
        let id = ckbMcpJsonId(request)
        let hasId = ckbMcpJsonHasId(request)
        let method = ckbMcpJsonStringField(request, "method")
        if (!hasId) {
            return ckbMcpDispatchNoOutput()
        }
        if (method == "initialize") {
            return ckbMcpDispatchResponse(this.resultResponse(id, this.initializeResult(protocolVersion, serverName)))
        }
        if (method == "ping") {
            return ckbMcpDispatchResponse(this.resultResponse(id, "{}"))
        }
        if (method == "tools/list") {
            return ckbMcpDispatchResponse(this.resultResponse(id, "{\"tools\":${this.toolsJson()}}"))
        }
        if (method == "tools/call") {
            return ckbMcpDispatchResponse(this.handleToolCall(id, ckbMcpJsonObjectField(request, "params")))
        }
        if (method == "resources/list") {
            return ckbMcpDispatchResponse(this.resultResponse(id, "{\"resources\":${this.resourcesJson()}}"))
        }
        if (method == "resources/read") {
            return ckbMcpDispatchResponse(this.handleResourceRead(id, ckbMcpJsonObjectField(request, "params")))
        }
        if (method == "prompts/list") {
            return ckbMcpDispatchResponse(this.resultResponse(id, "{\"prompts\":${this.promptsJson()}}"))
        }
        if (method == "prompts/get") {
            return ckbMcpDispatchResponse(this.handlePromptGet(id, ckbMcpJsonObjectField(request, "params")))
        }
        ckbMcpDispatchResponse(this.errorResponse(id, -32601, "method_not_found", "{\"method\":\"${ckbMcpJsonEscape(method)}\"}"))
    }

    private func handleToolCall(id: String, params: String): String {
        let name = ckbMcpJsonStringField(params, "name")
        if (!ckbMcpAllowedTool(name)) {
            let message = if (name == "verify-snippet" || name == "cangjie_verify_snippet") { "not_enabled" } else { "not_allowed" }
            return this.errorResponse(id, -32601, message, "{\"tool\":\"${ckbMcpJsonEscape(name)}\"}")
        }
        let args = ckbMcpJsonObjectField(params, "arguments")
        let tooLong = ckbMcpOversizedToolArguments(name, args, this.maxTextChars)
        if (tooLong != "") {
            return this.errorResponse(id, -32602, "parameter_too_long", "{\"field\":\"${ckbMcpJsonEscape(tooLong)}\",\"limit\":${this.maxTextChars}}")
        }

        if (name == "cangjie_knowledge_pack") {
            let task = ckbMcpJsonStringField(args, "task").trimAscii()
            if (task == "") { return this.errorResponse(id, -32602, "task_required", "{}") }
            return this.toolResult(id, this.packJson(this.service.cangjieKnowledgePack(task,
                targetVersion: ckbMcpJsonStringField(args, "targetVersion"),
                budget: ckbMcpJsonIntField(args, "budget", CangjieCapabilityLimits.DEFAULT_BUDGET),
                includeExamples: ckbMcpJsonBoolFieldDefault(args, "includeExamples", true) && !ckbMcpJsonBoolField(args, "excludeExamples"),
                includeAntiPatterns: ckbMcpJsonBoolFieldDefault(args, "includeAntiPatterns", true) && !ckbMcpJsonBoolField(args, "excludeAntiPatterns"))))
        }
        if (name == "cangjie_version_resolve") {
            return this.toolResult(id, cangjieVersionResolutionJson(this.service.cangjieResolveVersion(this.versionSelectorFromArgs(args))))
        }
        if (name == "cangjie_task_knowledge_pack") {
            let request = this.taskKnowledgeRequestFromArgs(args)
            let validation = validateCangjieTaskKnowledgeRequest(request)
            if (validation != "") { return this.errorResponse(id, -32602, validation, "{}") }
            return this.toolResult(id, cangjieTaskKnowledgePackJson(this.service.cangjieTaskKnowledgePack(request)))
        }
        if (name == "cangjie_knowledge_coverage") {
            let request = this.taskKnowledgeRequestFromArgs(args)
            let validation = validateCangjieTaskKnowledgeRequest(request)
            if (validation != "") { return this.errorResponse(id, -32602, validation, "{}") }
            return this.toolResult(id, cangjieKnowledgeCoverageJson(this.service.cangjieKnowledgeCoverage(request)))
        }
        if (name == "cangjie_compile_diagnose_v2") {
            let compilerOutput = ckbMcpJsonStringField(args, "compilerOutput").trimAscii()
            let context = ckbMcpJsonStringField(args, "context").trimAscii()
            if (compilerOutput == "" && context == "") { return this.errorResponse(id, -32602, "diagnostic_context_required", "{}") }
            return this.toolResult(id, cangjieTaskKnowledgePackJson(this.service.cangjieCompileDiagnoseV2(ckbMcpJsonStringField(args, "code"),
                compilerOutput,
                context: context,
                targetVersion: ckbMcpJsonStringField(args, "targetVersion"),
                sourceSet: ckbMcpJsonStringField(args, "sourceSet"),
                sourceRef: ckbMcpJsonStringField(args, "sourceRef"),
                budget: ckbMcpJsonIntField(args, "budget", CangjieCapabilityLimits.DEFAULT_BUDGET))))
        }
        if (name == "cangjie_syntax_query") {
            let q = ckbMcpFirstNonEmpty(ckbMcpJsonStringField(args, "q"), ckbMcpJsonStringField(args, "query")).trimAscii()
            if (q == "") { return this.errorResponse(id, -32602, "query_required", "{}") }
            return this.toolResult(id, this.packJson(this.service.cangjieSyntaxQuery(q,
                targetVersion: ckbMcpJsonStringField(args, "targetVersion"),
                budget: ckbMcpJsonIntField(args, "budget", CangjieCapabilityLimits.DEFAULT_BUDGET))))
        }
        if (name == "cangjie_api_search") {
            let q = ckbMcpFirstNonEmpty(ckbMcpJsonStringField(args, "q"), ckbMcpJsonStringField(args, "query")).trimAscii()
            let module = ckbMcpJsonStringField(args, "module").trimAscii()
            let symbol = ckbMcpJsonStringField(args, "symbol").trimAscii()
            if (q == "" && module == "" && symbol == "") { return this.errorResponse(id, -32602, "query_required", "{}") }
            return this.toolResult(id, this.packJson(this.service.cangjieApiSearch(q,
                module: module,
                symbol: symbol,
                sourceSet: ckbMcpJsonStringField(args, "sourceSet"),
                targetVersion: ckbMcpJsonStringField(args, "targetVersion"),
                budget: ckbMcpJsonIntField(args, "budget", CangjieCapabilityLimits.DEFAULT_BUDGET))))
        }
        if (name == "cangjie_cookbook") {
            let task = ckbMcpJsonStringField(args, "task").trimAscii()
            if (task == "") { return this.errorResponse(id, -32602, "task_required", "{}") }
            return this.toolResult(id, this.packJson(this.service.cangjieCookbook(task,
                constraints: ckbMcpJsonStringField(args, "constraints"),
                targetVersion: ckbMcpJsonStringField(args, "targetVersion"),
                style: ckbMcpJsonStringField(args, "style"),
                budget: ckbMcpJsonIntField(args, "budget", CangjieCapabilityLimits.DEFAULT_BUDGET))))
        }
        if (name == "cangjie_diagnose") {
            let compilerOutput = ckbMcpJsonStringField(args, "compilerOutput").trimAscii()
            let context = ckbMcpJsonStringField(args, "context").trimAscii()
            if (compilerOutput == "" && context == "") { return this.errorResponse(id, -32602, "diagnostic_context_required", "{}") }
            return this.toolResult(id, this.packJson(this.service.cangjieDiagnose(ckbMcpJsonStringField(args, "code"),
                compilerOutput,
                context: context,
                targetVersion: ckbMcpJsonStringField(args, "targetVersion"),
                budget: ckbMcpJsonIntField(args, "budget", CangjieCapabilityLimits.DEFAULT_BUDGET))))
        }
        if (name == "cangjie_examples") {
            let q = ckbMcpFirstNonEmpty(ckbMcpJsonStringField(args, "q"), ckbMcpJsonStringField(args, "query")).trimAscii()
            let module = ckbMcpJsonStringField(args, "module").trimAscii()
            let symbol = ckbMcpJsonStringField(args, "symbol").trimAscii()
            if (q == "" && module == "" && symbol == "") { return this.errorResponse(id, -32602, "query_required", "{}") }
            return this.toolResult(id, this.packJson(this.service.cangjieExamples(q,
                module: module,
                symbol: symbol,
                maxExamples: ckbMcpJsonIntField(args, "maxExamples", CangjieCapabilityLimits.DEFAULT_EXAMPLE_LIMIT),
                targetVersion: ckbMcpJsonStringField(args, "targetVersion"))))
        }
        this.toolResult(id, this.corpusStatusJson(this.service.cangjieCorpusStatus()))
    }

    private func handleResourceRead(id: String, params: String): String {
        let uri = ckbMcpJsonStringField(params, "uri")
        if (uri == "ckb://cangjie/corpus/status") {
            return this.resourceTextResult(id, uri, "application/json", this.corpusStatusJson(this.service.cangjieCorpusStatus()))
        }
        if (uri == "ckb://cangjie/llms.txt") {
            return this.resourceTextResult(id, uri, "text/markdown", this.markdownText(this.service.cangjieKnowledgePack("Cangjie language quick context", budget: 5), "llms.txt"))
        }
        if (uri == "ckb://cangjie/llms-full.txt") {
            return this.resourceTextResult(id, uri, "text/markdown", this.markdownText(this.service.cangjieKnowledgePack("Cangjie language full context", budget: 20), "llms-full.txt"))
        }
        if (uri.startsWith("ckb://cangjie/syntax/")) {
            let q = ckbMcpUriTail(uri, "ckb://cangjie/syntax/")
            return this.resourceTextResult(id, uri, "text/markdown", this.markdownText(this.service.cangjieSyntaxQuery(q, budget: 5), "syntax"))
        }
        if (uri.startsWith("ckb://cangjie/api/")) {
            let q = ckbMcpUriTail(uri, "ckb://cangjie/api/")
            return this.resourceTextResult(id, uri, "text/markdown", this.markdownText(this.service.cangjieApiSearch(q, symbol: q, budget: 5), "api"))
        }
        if (uri.startsWith("ckb://cangjie/cookbook/")) {
            let task = ckbMcpUriTail(uri, "ckb://cangjie/cookbook/")
            return this.resourceTextResult(id, uri, "text/markdown", this.markdownText(this.service.cangjieCookbook(task, budget: 5), "cookbook"))
        }
        this.errorResponse(id, -32602, "resource_not_found", "{\"uri\":\"${ckbMcpJsonEscape(uri)}\"}")
    }

    private func handlePromptGet(id: String, params: String): String {
        let name = ckbMcpJsonStringField(params, "name")
        if (!ckbMcpAllowedPrompt(name)) {
            return this.errorResponse(id, -32602, "prompt_not_found", "{\"name\":\"${ckbMcpJsonEscape(name)}\"}")
        }
        let text = ckbMcpPromptText(name)
        this.resultResponse(id, "{\"description\":\"${ckbMcpJsonEscape(ckbMcpPromptDescription(name))}\",\"messages\":[{\"role\":\"user\",\"content\":{\"type\":\"text\",\"text\":\"${ckbMcpJsonEscape(text)}\"}}]}")
    }

    private func toolResult(id: String, structured: String): String {
        this.resultResponse(id, "{\"content\":[{\"type\":\"text\",\"text\":\"${ckbMcpJsonEscape(structured)}\"}],\"structuredContent\":${structured},\"isError\":false}")
    }

    private func resourceTextResult(id: String, uri: String, mimeType: String, text: String): String {
        this.resultResponse(id, "{\"contents\":[{\"uri\":\"${ckbMcpJsonEscape(uri)}\",\"mimeType\":\"${ckbMcpJsonEscape(mimeType)}\",\"text\":\"${ckbMcpJsonEscape(text)}\"}]}")
    }

    private func resultResponse(id: String, result: String): String {
        "{\"jsonrpc\":\"2.0\",\"id\":${id},\"result\":${redactSensitive(result)}}"
    }

    private func errorResponse(id: String, code: Int64, message: String, data: String): String {
        "{\"jsonrpc\":\"2.0\",\"id\":${id},\"error\":{\"code\":${code},\"message\":\"${ckbMcpJsonEscape(message)}\",\"data\":${redactSensitive(data)}}}"
    }

    public func initializeResult(protocolVersion: String, serverName: String): String {
        "{\"protocolVersion\":\"${ckbMcpJsonEscape(protocolVersion)}\",\"capabilities\":{\"tools\":{\"listChanged\":false},\"resources\":{\"subscribe\":false,\"listChanged\":false},\"prompts\":{\"listChanged\":false}},\"serverInfo\":{\"name\":\"${ckbMcpJsonEscape(serverName)}\",\"version\":\"0.1.0\"}}"
    }

    private func toolsJson(): String {
        var out = "["
        let tools = ckbMcpToolNames()
        for (i in 0..tools.size) {
            if (i > 0) { out += "," }
            let name = tools[i]
            out += "{\"name\":\"${name}\",\"description\":\"${ckbMcpJsonEscape(ckbMcpToolDescription(name))}\",\"inputSchema\":${ckbMcpToolSchema(name)}}"
        }
        out += "]"
        out
    }

    private func resourcesJson(): String {
        "[{\"uri\":\"ckb://cangjie/corpus/status\",\"name\":\"Cangjie corpus status\",\"mimeType\":\"application/json\"},{\"uri\":\"ckb://cangjie/llms.txt\",\"name\":\"Cangjie llms.txt\",\"mimeType\":\"text/markdown\"},{\"uri\":\"ckb://cangjie/llms-full.txt\",\"name\":\"Cangjie llms-full.txt\",\"mimeType\":\"text/markdown\"},{\"uri\":\"ckb://cangjie/syntax/{query}\",\"name\":\"Cangjie syntax query resource\",\"mimeType\":\"text/markdown\"},{\"uri\":\"ckb://cangjie/api/{symbol}\",\"name\":\"Cangjie API search resource\",\"mimeType\":\"text/markdown\"},{\"uri\":\"ckb://cangjie/cookbook/{task}\",\"name\":\"Cangjie cookbook resource\",\"mimeType\":\"text/markdown\"}]"
    }

    private func promptsJson(): String {
        var out = "["
        let prompts = ckbMcpPromptNames()
        for (i in 0..prompts.size) {
            if (i > 0) { out += "," }
            let name = prompts[i]
            out += "{\"name\":\"${name}\",\"description\":\"${ckbMcpJsonEscape(ckbMcpPromptDescription(name))}\",\"arguments\":[{\"name\":\"task\",\"required\":false},{\"name\":\"targetVersion\",\"required\":false}]}"
        }
        out += "]"
        out
    }

    private func packJson(pack: CangjieKnowledgePack): String {
        var out = "{\"queryId\":\"${ckbMcpJsonEscape(pack.queryId)}\",\"task\":\"${ckbMcpJsonEscape(pack.task)}\",\"knowledgeVersion\":\"${ckbMcpJsonEscape(pack.knowledgeVersion)}\",\"targetVersion\":\"${ckbMcpJsonEscape(pack.targetVersion)}\",\"versionResolutionId\":\"${ckbMcpJsonEscape(pack.versionResolutionId)}\",\"truncated\":${pack.truncated},\"degraded\":${pack.degraded},\"executed\":${pack.executed}"
        out += ",\"items\":["
        for (i in 0..pack.items.size) {
            if (i > 0) { out += "," }
            let item = pack.items[i]
            out += "{\"kind\":\"${ckbMcpJsonEscape(item.kind)}\",\"title\":\"${ckbMcpJsonEscape(item.title)}\",\"content\":\"${ckbMcpJsonEscape(item.content)}\",\"module\":\"${ckbMcpJsonEscape(item.module)}\",\"symbol\":\"${ckbMcpJsonEscape(item.symbol)}\",\"importLine\":\"${ckbMcpJsonEscape(item.importLine)}\",\"signature\":\"${ckbMcpJsonEscape(item.signature)}\",\"example\":\"${ckbMcpJsonEscape(item.example)}\",\"citation\":\"${ckbMcpJsonEscape(item.citation)}\",\"sourceId\":\"${ckbMcpJsonEscape(item.sourceId)}\",\"knowledgeVersion\":\"${ckbMcpJsonEscape(item.knowledgeVersion)}\",\"targetVersion\":\"${ckbMcpJsonEscape(item.targetVersion)}\",\"trustLevel\":\"${ckbMcpJsonEscape(item.trustLevel)}\",\"reviewState\":\"${ckbMcpJsonEscape(item.reviewState)}\",\"requiresReview\":${item.requiresReview}}"
        }
        out += "],\"apiItems\":["
        for (i in 0..pack.apiItems.size) {
            if (i > 0) { out += "," }
            let item = pack.apiItems[i]
            out += "{\"module\":\"${ckbMcpJsonEscape(item.module)}\",\"symbol\":\"${ckbMcpJsonEscape(item.symbol)}\",\"importLine\":\"${ckbMcpJsonEscape(item.importLine)}\",\"signature\":\"${ckbMcpJsonEscape(item.signature)}\",\"summary\":\"${ckbMcpJsonEscape(item.summary)}\",\"example\":\"${ckbMcpJsonEscape(item.example)}\",\"citation\":\"${ckbMcpJsonEscape(item.citation)}\",\"sourceId\":\"${ckbMcpJsonEscape(item.sourceId)}\",\"knowledgeVersion\":\"${ckbMcpJsonEscape(item.knowledgeVersion)}\",\"targetVersion\":\"${ckbMcpJsonEscape(item.targetVersion)}\",\"trustLevel\":\"${ckbMcpJsonEscape(item.trustLevel)}\",\"reviewState\":\"${ckbMcpJsonEscape(item.reviewState)}\",\"requiresReview\":${item.requiresReview}}"
        }
        out += "],\"examples\":["
        for (i in 0..pack.examples.size) {
            if (i > 0) { out += "," }
            let item = pack.examples[i]
            out += "{\"title\":\"${ckbMcpJsonEscape(item.title)}\",\"code\":\"${ckbMcpJsonEscape(item.code)}\",\"explanation\":\"${ckbMcpJsonEscape(item.explanation)}\",\"module\":\"${ckbMcpJsonEscape(item.module)}\",\"symbol\":\"${ckbMcpJsonEscape(item.symbol)}\",\"citation\":\"${ckbMcpJsonEscape(item.citation)}\",\"sourceId\":\"${ckbMcpJsonEscape(item.sourceId)}\",\"knowledgeVersion\":\"${ckbMcpJsonEscape(item.knowledgeVersion)}\",\"targetVersion\":\"${ckbMcpJsonEscape(item.targetVersion)}\",\"trustLevel\":\"${ckbMcpJsonEscape(item.trustLevel)}\",\"reviewState\":\"${ckbMcpJsonEscape(item.reviewState)}\",\"requiresReview\":${item.requiresReview}}"
        }
        out += "],\"diagnostics\":["
        for (i in 0..pack.diagnostics.size) {
            if (i > 0) { out += "," }
            let item = pack.diagnostics[i]
            out += "{\"rule\":\"${ckbMcpJsonEscape(item.rule)}\",\"message\":\"${ckbMcpJsonEscape(item.message)}\",\"relatedSyntax\":\"${ckbMcpJsonEscape(item.relatedSyntax)}\",\"suggestedQuery\":\"${ckbMcpJsonEscape(item.suggestedQuery)}\",\"citation\":\"${ckbMcpJsonEscape(item.citation)}\",\"sourceId\":\"${ckbMcpJsonEscape(item.sourceId)}\",\"knowledgeVersion\":\"${ckbMcpJsonEscape(item.knowledgeVersion)}\",\"targetVersion\":\"${ckbMcpJsonEscape(item.targetVersion)}\",\"trustLevel\":\"${ckbMcpJsonEscape(item.trustLevel)}\",\"reviewState\":\"${ckbMcpJsonEscape(item.reviewState)}\",\"executed\":${item.executed}}"
        }
        out += "],\"notes\":${ckbMcpStringArrayJson(pack.notes)},\"citations\":${ckbMcpCitationsJson(pack.citations)}}"
        out
    }

    private func versionSelectorFromArgs(args: String): CangjieVersionSelector {
        cangjieVersionSelector(
            targetVersion: ckbMcpJsonStringField(args, "targetVersion"),
            sourceSet: ckbMcpJsonStringField(args, "sourceSet"),
            sourceFamily: ckbMcpJsonStringField(args, "sourceFamily"),
            sourceRepo: ckbMcpJsonStringField(args, "sourceRepo"),
            sourceRef: ckbMcpJsonStringField(args, "sourceRef"),
            refKind: ckbMcpJsonStringField(args, "refKind"),
            versionPolicy: ckbMcpJsonStringField(args, "versionPolicy"),
            includePrerelease: ckbMcpJsonBoolField(args, "includePrerelease"))
    }

    private func taskKnowledgeRequestFromArgs(args: String): CangjieTaskKnowledgeRequest {
        let request = CangjieTaskKnowledgeRequest()
        request.taskId = ckbMcpJsonStringField(args, "taskId")
        request.benchmark = ckbMcpJsonStringField(args, "benchmark")
        request.taskText = ckbMcpFirstNonEmpty(ckbMcpJsonStringField(args, "taskText"), ckbMcpJsonStringField(args, "task"))
        request.signature = ckbMcpJsonStringField(args, "signature")
        request.imports = ckbMcpJsonStringArrayField(args, "imports")
        request.argTypes = ckbMcpJsonStringArrayField(args, "argTypes")
        request.returnType = ckbMcpJsonStringField(args, "returnType")
        request.expectedKnowledgeTags = ckbMcpJsonStringArrayField(args, "expectedKnowledgeTags")
        request.starterCodeExcerpt = ckbMcpJsonStringField(args, "starterCodeExcerpt")
        request.compilerOutput = ckbMcpJsonStringField(args, "compilerOutput")
        request.versionSelector = this.versionSelectorFromArgs(args)
        request.budget = ckbMcpJsonIntField(args, "budget", CangjieCapabilityLimits.DEFAULT_BUDGET)
        request.responseMode = ckbMcpJsonStringField(args, "responseMode")
        request
    }

    private func corpusStatusJson(status: CangjieCorpusStatus): String {
        "{\"activeKnowledgeVersion\":\"${ckbMcpJsonEscape(status.activeKnowledgeVersion)}\",\"knowledgeVersion\":\"${ckbMcpJsonEscape(status.activeKnowledgeVersion)}\",\"targetVersion\":\"${ckbMcpJsonEscape(status.targetVersion)}\",\"docsUrls\":${ckbMcpStringArrayJson(status.docsUrls)},\"stdSources\":${ckbMcpStringArrayJson(status.stdSources)},\"rawCount\":${status.rawCount},\"normalizedCount\":${status.normalizedCount},\"indexCount\":${status.indexCount},\"degraded\":${status.degraded},\"diagnostics\":${ckbMcpStringArrayJson(status.diagnostics)}}"
    }

    private func markdownText(pack: CangjieKnowledgePack, kind: String): String {
        var markdown = "# Cangjie ${kind}\n\nknowledgeVersion: ${pack.knowledgeVersion}\ntargetVersion: ${pack.targetVersion}\ndocs: https://docs.cangjie-lang.cn/docs/1.0.0/\n\n"
        for (item in pack.items) {
            markdown += "## ${item.title}\n${item.content}\n\ncitation: ${item.citation}\n\n"
        }
        for (item in pack.apiItems) {
            markdown += "## ${item.symbol}\n${item.summary}\n\nimport: ${item.importLine}\ncitation: ${item.citation}\n\n"
        }
        for (item in pack.examples) {
            markdown += "## ${item.title}\n```cangjie\n${item.code}\n```\n\ncitation: ${item.citation}\n\n"
        }
        if (pack.citations.size == 0) {
            markdown += "citation: https://docs.cangjie-lang.cn/docs/1.0.0/\n"
        }
        markdown
    }
}

public func ckbMcpProtocolVersionFromInitialize(request: String, fallback: String): String {
    if (ckbMcpJsonStringField(request, "method") != "initialize") {
        return fallback
    }
    let params = ckbMcpJsonObjectField(request, "params")
    let requested = ckbMcpJsonStringField(params, "protocolVersion").trimAscii()
    if (requested == "") {
        return fallback
    }
    requested
}

private func ckbMcpToolNames(): ArrayList<String> {
    let tools = ArrayList<String>()
    tools.add("cangjie_knowledge_pack")
    tools.add("cangjie_version_resolve")
    tools.add("cangjie_task_knowledge_pack")
    tools.add("cangjie_knowledge_coverage")
    tools.add("cangjie_compile_diagnose_v2")
    tools.add("cangjie_syntax_query")
    tools.add("cangjie_api_search")
    tools.add("cangjie_cookbook")
    tools.add("cangjie_diagnose")
    tools.add("cangjie_examples")
    tools.add("cangjie_corpus_status")
    tools
}

private func ckbMcpAllowedTool(name: String): Bool {
    ckbMcpToolNames().contains(name)
}

private func ckbMcpToolDescription(name: String): String {
    if (name == "cangjie_knowledge_pack") { return "Return a citation-backed Cangjie knowledge pack for a coding task." }
    if (name == "cangjie_version_resolve") { return "Resolve Cangjie target version and source refs without default-branch fallback for exact refs." }
    if (name == "cangjie_task_knowledge_pack") { return "Return a version-aware task knowledge contract with query plan and coverage fields." }
    if (name == "cangjie_knowledge_coverage") { return "Return required Cangjie knowledge coverage for a task request." }
    if (name == "cangjie_compile_diagnose_v2") { return "Return version-aware compile diagnostic query plan; does not execute code." }
    if (name == "cangjie_syntax_query") { return "Search citation-backed Cangjie syntax guidance." }
    if (name == "cangjie_api_search") { return "Search citation-backed Cangjie API and module knowledge." }
    if (name == "cangjie_cookbook") { return "Return grounded Cangjie implementation steps and examples." }
    if (name == "cangjie_diagnose") { return "Diagnose Cangjie compiler output using knowledge only; does not execute code." }
    if (name == "cangjie_examples") { return "Return reviewed Cangjie examples." }
    "Return read-only Cangjie corpus status."
}

private func ckbMcpToolSchema(name: String): String {
    if (name == "cangjie_corpus_status") {
        return "{\"type\":\"object\",\"properties\":{},\"additionalProperties\":false}"
    }
    "{\"type\":\"object\",\"properties\":{\"q\":{\"type\":\"string\"},\"query\":{\"type\":\"string\"},\"task\":{\"type\":\"string\"},\"taskText\":{\"type\":\"string\"},\"taskId\":{\"type\":\"string\"},\"benchmark\":{\"type\":\"string\"},\"signature\":{\"type\":\"string\"},\"imports\":{\"type\":\"array\",\"items\":{\"type\":\"string\"}},\"argTypes\":{\"type\":\"array\",\"items\":{\"type\":\"string\"}},\"expectedKnowledgeTags\":{\"type\":\"array\",\"items\":{\"type\":\"string\"}},\"starterCodeExcerpt\":{\"type\":\"string\"},\"code\":{\"type\":\"string\"},\"compilerOutput\":{\"type\":\"string\"},\"context\":{\"type\":\"string\"},\"module\":{\"type\":\"string\"},\"symbol\":{\"type\":\"string\"},\"sourceSet\":{\"type\":\"string\"},\"sourceFamily\":{\"type\":\"string\"},\"sourceRepo\":{\"type\":\"string\"},\"sourceRef\":{\"type\":\"string\"},\"refKind\":{\"type\":\"string\"},\"versionPolicy\":{\"type\":\"string\"},\"targetVersion\":{\"type\":\"string\"},\"budget\":{\"type\":\"integer\",\"minimum\":1,\"maximum\":20},\"maxExamples\":{\"type\":\"integer\",\"minimum\":1,\"maximum\":20}},\"additionalProperties\":true}"
}

private func ckbMcpPromptNames(): ArrayList<String> {
    let prompts = ArrayList<String>()
    prompts.add("cangjie_write_code_with_ckb")
    prompts.add("cangjie_fix_compile_error")
    prompts.add("cangjie_explain_api")
    prompts.add("cangjie_generate_tests")
    prompts
}

private func ckbMcpAllowedPrompt(name: String): Bool {
    ckbMcpPromptNames().contains(name)
}

private func ckbMcpPromptDescription(name: String): String {
    if (name == "cangjie_write_code_with_ckb") { return "Write Cangjie code using only CKB-cited syntax, API, cookbook, and example evidence." }
    if (name == "cangjie_fix_compile_error") { return "Fix a Cangjie compile error by consulting CKB diagnose, syntax, and API tools." }
    if (name == "cangjie_explain_api") { return "Explain a Cangjie API using CKB citations." }
    "Generate Cangjie tests from CKB-cited examples and syntax."
}

private func ckbMcpPromptText(name: String): String {
    if (name == "cangjie_write_code_with_ckb") {
        return "Before writing Cangjie code, call cangjie_task_knowledge_pack with taskText, signature, expectedKnowledgeTags, and targetVersion to resolve the version and required coverage. Then call cangjie_syntax_query or cangjie_api_search for each planned knowledge area. Use ckb://cangjie/llms.txt for baseline context. Do not state syntax or API facts unless they appear in returned citations."
    }
    if (name == "cangjie_fix_compile_error") {
        return "Call cangjie_compile_diagnose_v2 with compilerOutput, context, and targetVersion, then call cangjie_syntax_query or cangjie_api_search for each planned fix area. Propose changes only when supported by CKB citations; do not run or claim verification unless another explicit tool performs it."
    }
    if (name == "cangjie_explain_api") {
        return "Call cangjie_api_search with module or symbol, read ckb://cangjie/api/{symbol} when useful, and explain only citation-backed behavior. Include citations for each API fact."
    }
    "Call cangjie_examples and cangjie_syntax_query for the target behavior, then generate tests only from cited examples and syntax rules. Do not invent unsupported assertions."
}

private func ckbMcpOversizedToolArguments(name: String, args: String, limit: Int64): String {
    let fields = ["task", "taskText", "q", "query", "signature", "code", "compilerOutput", "context", "constraints"]
    for (field in fields) {
        if (ckbMcpJsonStringField(args, field).size > limit) {
            return field
        }
    }
    ""
}

private func ckbMcpCitationsJson(citations: ArrayList<SourceReference>): String {
    var out = "["
    for (i in 0..citations.size) {
        if (i > 0) { out += "," }
        let citation = citations[i]
        out += "{\"sourceId\":\"${ckbMcpJsonEscape(citation.sourceId)}\",\"citation\":\"${ckbMcpJsonEscape(citation.citation)}\",\"knowledgeVersion\":\"${ckbMcpJsonEscape(citation.knowledgeVersion)}\"}"
    }
    out += "]"
    out
}

private func ckbMcpStringArrayJson(values: ArrayList<String>): String {
    var out = "["
    for (i in 0..values.size) {
        if (i > 0) { out += "," }
        out += "\"${ckbMcpJsonEscape(values[i])}\""
    }
    out += "]"
    out
}

public func ckbMcpJsonEscape(raw: String): String {
    let text = redactSensitive(raw)
    let out = StringBuilder()
    for (ch in text.toRuneArray()) {
        if (ch == r'"') {
            out.append("\\\"")
        } else if (ch == r'\\') {
            out.append("\\\\")
        } else if (ch == r'\n') {
            out.append("\\n")
        } else if (ch == r'\r') {
            out.append("\\r")
        } else if (ch == r'\t') {
            out.append("\\t")
        } else {
            out.append(ch)
        }
    }
    out.toString()
}

private class CkbMcpJsonStringScan {
    var ok: Bool = false
    var value: String = ""
    var end: Int64 = 0

    init() {}
}

public func ckbMcpJsonId(raw: String): String {
    let start = ckbMcpJsonValueStart(raw, "id")
    let chars = raw.toRuneArray()
    if (start < 0) {
        return "null"
    }
    if (start < chars.size && chars[start] == r'"') {
        let scan = ckbMcpReadJsonStringAt(chars, start)
        if (scan.ok) {
            return "\"${ckbMcpJsonEscape(scan.value)}\""
        }
    }
    var end = start
    while (end < chars.size && chars[end] != r',' && chars[end] != r'}' && chars[end] != r']' && !ckbMcpIsJsonWhitespace(chars[end])) {
        end += 1
    }
    let value = ckbMcpRunesToString(chars, start, end).trimAscii()
    if (value == "") { return "null" }
    value
}

public func ckbMcpJsonHasId(raw: String): Bool {
    ckbMcpJsonValueStart(raw, "id") >= 0
}

public func ckbMcpJsonStringField(raw: String, key: String): String {
    let start = ckbMcpJsonValueStart(raw, key)
    let chars = raw.toRuneArray()
    if (start < 0 || start >= chars.size || chars[start] != r'"') {
        return ""
    }
    let scan = ckbMcpReadJsonStringAt(chars, start)
    if (scan.ok) { scan.value } else { "" }
}

public func ckbMcpJsonObjectField(raw: String, key: String): String {
    let start = ckbMcpJsonValueStart(raw, key)
    let chars = raw.toRuneArray()
    if (start < 0 || start >= chars.size || chars[start] != r'{') {
        return ""
    }
    ckbMcpJsonEnclosedAt(chars, start, r'{', r'}')
}

private func ckbMcpJsonStringArrayField(raw: String, key: String): ArrayList<String> {
    let values = ArrayList<String>()
    let start = ckbMcpJsonValueStart(raw, key)
    let chars = raw.toRuneArray()
    if (start < 0 || start >= chars.size || chars[start] != r'[') {
        return values
    }
    var i = start + 1
    while (i < chars.size) {
        i = ckbMcpSkipJsonWhitespace(chars, i)
        if (i >= chars.size || chars[i] == r']') {
            break
        }
        if (chars[i] == r'"') {
            let scan = ckbMcpReadJsonStringAt(chars, i)
            if (scan.ok) {
                values.add(scan.value)
                i = scan.end
            } else {
                break
            }
        } else {
            i += 1
        }
        i = ckbMcpSkipJsonWhitespace(chars, i)
        if (i < chars.size && chars[i] == r',') {
            i += 1
        }
    }
    values
}

private func ckbMcpJsonIntField(raw: String, key: String, fallback: Int64): Int64 {
    let start = ckbMcpJsonValueStart(raw, key)
    let chars = raw.toRuneArray()
    if (start < 0) { return fallback }
    if (start < chars.size && chars[start] == r'"') {
        return try { Int64.parse(ckbMcpJsonStringField(raw, key).trimAscii()) } catch (_: Exception) { fallback }
    }
    var end = start
    while (end < chars.size && ckbMcpIsDigit(chars[end])) {
        end += 1
    }
    if (end == start) { return fallback }
    try { Int64.parse(ckbMcpRunesToString(chars, start, end)) } catch (_: Exception) { fallback }
}

private func ckbMcpJsonBoolField(raw: String, key: String): Bool {
    let start = ckbMcpJsonValueStart(raw, key)
    let chars = raw.toRuneArray()
    start >= 0 && ckbMcpRunesStartWith(chars, start, "true")
}

private func ckbMcpJsonBoolFieldDefault(raw: String, key: String, fallback: Bool): Bool {
    let start = ckbMcpJsonValueStart(raw, key)
    if (start < 0) { return fallback }
    ckbMcpRunesStartWith(raw.toRuneArray(), start, "true")
}

private func ckbMcpJsonValueStart(raw: String, key: String): Int64 {
    let chars = raw.toRuneArray()
    var i: Int64 = 0
    var depth: Int64 = 0
    var inString = false
    var escaped = false
    while (i < chars.size) {
        let ch = chars[i]
        if (inString) {
            if (escaped) {
                escaped = false
            } else if (ch == r'\\') {
                escaped = true
            } else if (ch == r'"') {
                inString = false
            }
            i += 1
            continue
        }
        if (ch == r'"') {
            let scan = ckbMcpReadJsonStringAt(chars, i)
            if (scan.ok && scan.value == key && depth == 1) {
                var colon = ckbMcpSkipJsonWhitespace(chars, scan.end)
                if (colon < chars.size && chars[colon] == r':') {
                    return ckbMcpSkipJsonWhitespace(chars, colon + 1)
                }
            }
            i = if (scan.ok) { scan.end } else { i + 1 }
            continue
        }
        if (ch == r'{' || ch == r'[') { depth += 1 }
        if (ch == r'}' || ch == r']') { depth -= 1 }
        i += 1
    }
    -1
}

private func ckbMcpReadJsonStringAt(chars: Array<Rune>, start: Int64): CkbMcpJsonStringScan {
    let scan = CkbMcpJsonStringScan()
    if (start < 0 || start >= chars.size || chars[start] != r'"') {
        return scan
    }
    var i = start + 1
    var escaped = false
    let out = StringBuilder()
    while (i < chars.size) {
        let ch = chars[i]
        if (escaped) {
            out.append(ckbMcpJsonUnescapeChar(ch))
            escaped = false
        } else if (ch == r'\\') {
            escaped = true
        } else if (ch == r'"') {
            scan.ok = true
            scan.value = out.toString()
            scan.end = i + 1
            return scan
        } else {
            out.append(ch)
        }
        i += 1
    }
    scan
}

private func ckbMcpJsonUnescapeChar(ch: Rune): String {
    if (ch == r'n') { return "\n" }
    if (ch == r'r') { return "\r" }
    if (ch == r't') { return "\t" }
    if (ch == r'"') { return "\"" }
    if (ch == r'\\') { return "\\" }
    ckbMcpRunesToString([ch], 0, 1)
}

private func ckbMcpSkipJsonWhitespace(chars: Array<Rune>, start: Int64): Int64 {
    var i = start
    while (i < chars.size && ckbMcpIsJsonWhitespace(chars[i])) {
        i += 1
    }
    i
}

private func ckbMcpJsonEnclosedAt(chars: Array<Rune>, start: Int64, open: Rune, close: Rune): String {
    var i = start
    var depth: Int64 = 0
    var inString = false
    var escaped = false
    while (i < chars.size) {
        let ch = chars[i]
        if (inString) {
            if (escaped) {
                escaped = false
            } else if (ch == r'\\') {
                escaped = true
            } else if (ch == r'"') {
                inString = false
            }
        } else if (ch == r'"') {
            inString = true
        } else if (ch == open) {
            depth += 1
        } else if (ch == close) {
            depth -= 1
            if (depth == 0) {
                return ckbMcpRunesToString(chars, start, i + 1)
            }
        }
        i += 1
    }
    ""
}

private func ckbMcpFirstNonEmpty(a: String, b: String): String {
    if (a != "") { a } else { b }
}

private func ckbMcpRunesStartWith(chars: Array<Rune>, start: Int64, literal: String): Bool {
    let expected = literal.toRuneArray()
    if (start < 0 || start + expected.size > chars.size) {
        return false
    }
    for (i in 0..expected.size) {
        if (chars[start + i] != expected[i]) {
            return false
        }
    }
    true
}

private func ckbMcpRunesToString(chars: Array<Rune>, start: Int64, end: Int64): String {
    let out = StringBuilder()
    var i = start
    while (i < end && i < chars.size) {
        out.append(chars[i])
        i += 1
    }
    out.toString()
}

private func ckbMcpIsJsonWhitespace(ch: Rune): Bool {
    ch == r' ' || ch == r'\n' || ch == r'\r' || ch == r'\t'
}

private func ckbMcpIsDigit(ch: Rune): Bool {
    let value = UInt32(ch)
    value >= UInt32(r'0') && value <= UInt32(r'9')
}

private func ckbMcpUriTail(uri: String, prefix: String): String {
    if (uri.size <= prefix.size) { return "" }
    uri[prefix.size..uri.size].replace("-", " ").replace("_", " ")
}
