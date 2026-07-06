package cangjie_community_knowledge_base

import std.collection.ArrayList

public class CangjieQueryCacheKey {
    public var versionResolutionId: String = ""
    public var activeKnowledgeVersion: String = ""
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var sourceSet: String = ""
    public var interfaceId: String = ""
    public var selectorHash: String = ""
    public var queryPlanHash: String = ""
    public var budget: Int64 = 0
    public var responseMode: String = "knowledge-pack"

    public init() {}

    public func valid(): Bool {
        this.activeKnowledgeVersion != "" &&
            this.targetVersion != "" &&
            this.interfaceId != "" &&
            this.selectorHash != "" &&
            this.queryPlanHash != "" &&
            this.budget > 0
    }

    public func text(): String {
        "${this.versionResolutionId}|${this.activeKnowledgeVersion}|${this.targetVersion}|${this.sourceSet}|${this.interfaceId}|${this.responseMode}|${this.selectorHash}|${this.queryPlanHash}|${this.budget}"
    }
}

public class CangjieQueryCacheEntry {
    public var key: CangjieQueryCacheKey = CangjieQueryCacheKey()
    public var valueHash: String = ""
    public var hitCount: Int64 = 0

    public init() {}
}

public class CangjieQueryCacheLookup {
    public var hit: Bool = false
    public var valueHash: String = ""
    public var diagnostic: String = ""

    public init() {}
}

public class CangjieQueryCache {
    private let capacity: Int64
    private var entries: ArrayList<CangjieQueryCacheEntry> = ArrayList<CangjieQueryCacheEntry>()

    public init(capacity: Int64) {
        this.capacity = if (capacity < 1) { 1 } else { capacity }
    }

    public func put(key: CangjieQueryCacheKey, valueHash: String): String {
        if (!key.valid()) {
            return "invalid_cache_key"
        }
        for (entry in this.entries) {
            if (entry.key.text() == key.text()) {
                entry.valueHash = valueHash
                return "updated"
            }
        }
        while (this.entries.size >= this.capacity) {
            this.entries.remove(at: 0)
        }
        let entry = CangjieQueryCacheEntry()
        entry.key = key
        entry.valueHash = valueHash
        this.entries.add(entry)
        "stored"
    }

    public func get(key: CangjieQueryCacheKey): CangjieQueryCacheLookup {
        let lookup = CangjieQueryCacheLookup()
        if (!key.valid()) {
            lookup.diagnostic = "invalid_cache_key"
            return lookup
        }
        for (entry in this.entries) {
            if (entry.key.text() == key.text()) {
                lookup.hit = true
                lookup.valueHash = entry.valueHash
                entry.hitCount += 1
                return lookup
            }
        }
        lookup.diagnostic = "cache_miss"
        lookup
    }

    public func size(): Int64 {
        this.entries.size
    }

    public func invalidateOnActiveVersionChange(activeKnowledgeVersion: String): Int64 {
        var removed: Int64 = 0
        var i: Int64 = 0
        while (i < this.entries.size) {
            if (this.entries[i].key.activeKnowledgeVersion != activeKnowledgeVersion) {
                this.entries.remove(at: i)
                removed += 1
            } else {
                i += 1
            }
        }
        removed
    }
}

public func cangjieServingCacheKey(versionResolutionId: String, activeKnowledgeVersion: String, sourceSet: String, query: String, budget: Int64, responseMode: String, targetVersion!: String = "", interfaceId!: String = "", selector!: String = ""): CangjieQueryCacheKey {
    let key = CangjieQueryCacheKey()
    key.versionResolutionId = versionResolutionId
    key.activeKnowledgeVersion = activeKnowledgeVersion
    key.targetVersion = cangjieNormalizeTargetVersion(targetVersion)
    key.sourceSet = sourceSet
    key.interfaceId = if (interfaceId.trimAscii() == "") { responseMode } else { interfaceId.trimAscii() }
    key.selectorHash = cangjieQueryCacheHash(if (selector.trimAscii() == "") { query } else { selector })
    key.queryPlanHash = cangjieQueryCacheHash(query)
    key.budget = budget
    key.responseMode = responseMode
    key
}

private func cangjieQueryCacheHash(raw: String): String {
    var hash: Int64 = 5381
    let modulus: Int64 = 2147483647
    for (b in raw.toArray()) {
        hash = ((hash * 33) % modulus + (Int64(b) % modulus)) % modulus
    }
    if (hash == 0) {
        hash = 1
    }
    "qh${hash}-${raw.size}"
}
