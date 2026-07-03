package cangjie_community_knowledge_base

import std.collection.ArrayList

public class CangjieSymbolCardRecord {
    public var symbolKey: String = ""
    public var module: String = ""
    public var importLine: String = ""
    public var signature: String = ""
    public var receiver: String = ""
    public var params: String = ""
    public var returnType: String = ""
    public var availability: String = "stable"
    public var versionResolutionId: String = ""
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var sourceSet: String = ""
    public var sourceRef: String = ""
    public var contentHash: String = ""
    public var citation: String = ""
    public var sourceId: String = ""
    public var trustLevel: String = ""
    public var reviewState: String = ""
    public var incomplete: Bool = false
    public var diagnostic: String = ""

    public init() {}
}

public func extractCangjieSymbols(record: NormalizedRecord): ArrayList<CangjieSymbolCardRecord> {
    let cards = ArrayList<CangjieSymbolCardRecord>()
    let haystack = "${record.title}\n${record.chunk}\n${record.metadata.symbol}\n${record.metadata.path}".toAsciiLower()
    if (haystack.contains("arraylist.add") || (haystack.contains("arraylist") && haystack.contains(".add"))) {
        cards.add(cangjieKnownSymbolCard(record, "ArrayList.add", "std.collection", "import std.collection.*", "func add(value: T): Unit"))
    }
    if (haystack.contains("arraylist")) {
        cards.add(cangjieKnownSymbolCard(record, "ArrayList", "std.collection", "import std.collection.*", "class ArrayList<T>"))
    }
    if (haystack.contains("hashmap")) {
        cards.add(cangjieKnownSymbolCard(record, "HashMap", "std.collection", "import std.collection.*", "class HashMap<K, V>"))
    }
    if (haystack.contains("hashset")) {
        cards.add(cangjieKnownSymbolCard(record, "HashSet", "std.collection", "import std.collection.*", "class HashSet<T>"))
    }
    if (haystack.contains("string.contains") || (haystack.contains("string") && haystack.contains("contains"))) {
        cards.add(cangjieKnownSymbolCard(record, "String.contains", "std.core", "", "func contains(pattern: String): Bool"))
    }
    if (haystack.contains("torunearray") || haystack.contains("rune")) {
        cards.add(cangjieKnownSymbolCard(record, "String.toRuneArray", "std.core", "", "func toRuneArray(): Array<Rune>"))
    }
    if (haystack.contains("option") || haystack.contains("some<") || haystack.contains("none<")) {
        cards.add(cangjieKnownSymbolCard(record, "Option", "std.core", "", "enum Option<T>"))
    }
    if (haystack.contains("float64")) {
        cards.add(cangjieKnownSymbolCard(record, "Float64", "std.core", "", "struct Float64"))
    }
    if (haystack.contains("int64")) {
        cards.add(cangjieKnownSymbolCard(record, "Int64", "std.core", "", "struct Int64"))
    }
    if (haystack.contains("regex")) {
        cards.add(cangjieKnownSymbolCard(record, "Regex", "std.regex", "import std.regex.*", "class Regex"))
    }
    if (haystack.contains("main()")) {
        cards.add(cangjieKnownSymbolCard(record, "main", "package-entry", "", "main(): Int64 | main(): Unit"))
    }
    if (haystack.contains("cjpm")) {
        cards.add(cangjieKnownSymbolCard(record, "cjpm", "toolchain", "", "cjpm build | cjpm test"))
    }
    mergeSymbolCards(cards)
}

public func mergeSymbolCards(cards: ArrayList<CangjieSymbolCardRecord>): ArrayList<CangjieSymbolCardRecord> {
    let out = ArrayList<CangjieSymbolCardRecord>()
    for (card in cards) {
        if (card.signature.trimAscii() == "") {
            card.incomplete = true
            card.diagnostic = "symbol_signature_incomplete"
        }
        let existing = cangjieSymbolFindEquivalent(out, card)
        if (existing < 0) {
            out.add(card)
        } else if (cangjieSymbolTrustRank(card) > cangjieSymbolTrustRank(out[existing])) {
            out[existing] = card
        }
    }
    out
}

public func cangjieSymbolCardMatches(card: CangjieSymbolCardRecord, symbol: String, module: String, sourceSet: String): Bool {
    let cleanSymbol = symbol.trimAscii().toAsciiLower()
    let cleanModule = module.trimAscii().toAsciiLower()
    let cleanSourceSet = sourceSet.trimAscii().toAsciiLower()
    if (cleanSymbol != "" && card.symbolKey.toAsciiLower() != cleanSymbol && !card.symbolKey.toAsciiLower().contains(cleanSymbol)) {
        return false
    }
    if (cleanModule != "" && card.module.toAsciiLower() != cleanModule && !card.module.toAsciiLower().contains(cleanModule)) {
        return false
    }
    if (cleanSourceSet != "" && card.sourceSet.toAsciiLower() != cleanSourceSet) {
        return false
    }
    true
}

private func cangjieKnownSymbolCard(record: NormalizedRecord, symbolKey: String, module: String, importLine: String, signature: String): CangjieSymbolCardRecord {
    let card = CangjieSymbolCardRecord()
    card.symbolKey = symbolKey
    card.module = module
    card.importLine = importLine
    card.signature = signature
    card.receiver = cangjieSymbolReceiver(symbolKey)
    card.params = cangjieSymbolParams(signature)
    card.returnType = cangjieSymbolReturnType(signature)
    card.versionResolutionId = record.metadata.versionResolutionId
    card.targetVersion = record.metadata.targetVersion
    card.sourceSet = record.metadata.sourceSet
    card.sourceRef = record.metadata.docVersion
    card.contentHash = stableSummaryHash("${record.sourceId}:${symbolKey}:${signature}")
    card.citation = record.citation
    card.sourceId = record.sourceId
    card.trustLevel = record.metadata.trustLevel
    card.reviewState = record.metadata.reviewState
    card
}

private func cangjieSymbolFindEquivalent(cards: ArrayList<CangjieSymbolCardRecord>, candidate: CangjieSymbolCardRecord): Int64 {
    for (i in 0..cards.size) {
        let card = cards[i]
        if (card.symbolKey == candidate.symbolKey && card.versionResolutionId == candidate.versionResolutionId && card.sourceRef == candidate.sourceRef) {
            return i
        }
    }
    -1
}

private func cangjieSymbolTrustRank(card: CangjieSymbolCardRecord): Int64 {
    var rank: Int64 = 0
    if (card.trustLevel == TrustLevels.OFFICIAL) {
        rank += 10
    }
    if (card.reviewState == ReviewStates.TRUSTED) {
        rank += 5
    } else if (card.reviewState == ReviewStates.REVIEWED) {
        rank += 3
    }
    if (!card.incomplete) {
        rank += 1
    }
    rank
}

private func cangjieSymbolReceiver(symbolKey: String): String {
    let parts = symbolKey.split(".")
    if (parts.size > 1) { parts[0] } else { "" }
}

private func cangjieSymbolParams(signature: String): String {
    if (!signature.contains("(") || !signature.contains(")")) {
        return ""
    }
    let after = signature.split("(")
    if (after.size < 2) {
        return ""
    }
    after[1].split(")")[0]
}

private func cangjieSymbolReturnType(signature: String): String {
    if (!signature.contains(":")) {
        return ""
    }
    let parts = signature.split(":")
    if (parts.size == 0) {
        return ""
    }
    parts[parts.size - 1].trimAscii()
}
