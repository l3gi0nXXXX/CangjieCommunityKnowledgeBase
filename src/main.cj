package cangjie_community_knowledge_base

main(args: Array<String>): Int64 {
    let kb = newOfflineKnowledgeBase()
    let input = cliInput(args)
    if (input == "" || input == "doctor") {
        print(renderDoctor(cangjie_knowledge_status(kb)))
        return 0
    }
    if (input == "query" || input.startsWith("query ")) {
        let query = cliTail(input, "query", "func syntax")
        print(renderQuery(cangjie_evidence_pack(kb, query, 5)))
        return 0
    }
    if (input == "evidence" || input.startsWith("evidence ")) {
        let query = cliTail(input, "evidence", "HttpClient")
        print(renderQuery(cangjie_evidence_pack(kb, query, 3)))
        return 0
    }
    println("Usage: cangjie_community_knowledge_base doctor | query <text> | evidence <text>")
    2
}

private func cliInput(args: Array<String>): String {
    var input = ""
    for (arg in args) {
        if (input == "") {
            input = arg
        } else {
            input += " ${arg}"
        }
    }
    input.trimAscii()
}

private func cliTail(input: String, command: String, fallback: String): String {
    if (input == command) {
        return fallback
    }
    let prefixSize = command.size + 1
    if (input.size <= prefixSize) {
        return fallback
    }
    input[prefixSize..input.size].trimAscii()
}
