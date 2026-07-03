package cangjie_community_knowledge_base_test

import std.collection.ArrayList

public class CangjieServingRecordKinds {
    public static let DOC_SECTION: String = "serving_doc_section"
    public static let SYMBOL_CARD: String = "serving_symbol_card"
    public static let EXAMPLE: String = "serving_example"
    public static let RECIPE: String = "serving_recipe"
    public static let NEGATIVE_RULE: String = "serving_negative_rule"
}

public class CangjieServingDocument {
    public var documentId: String = ""
    public var recordKind: String = ""
    public var title: String = ""
    public var text: String = ""
    public var symbolKey: String = ""
    public var module: String = ""
    public var sourceSet: String = ""
    public var trustLevel: String = ""
    public var reviewState: String = ""
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var versionResolutionId: String = ""
    public var contentHash: String = ""
    public var citation: String = ""
    public var sourceId: String = ""
    public var rankProfile: String = "official-doc"
    public var rejected: Bool = false
    public var diagnostic: String = ""

    public init() {}
}

public class CangjieServingFeed {
    public var ok: Bool = true
    public var documents: ArrayList<CangjieServingDocument> = ArrayList<CangjieServingDocument>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}
