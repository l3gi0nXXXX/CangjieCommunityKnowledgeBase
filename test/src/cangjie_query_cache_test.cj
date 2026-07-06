package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieQueryCacheTest {
    @TestCase
    public func p4Bnd001InvalidCacheKeyIsRejected(): Unit {
        let cache = CangjieQueryCache(2)
        let key = CangjieQueryCacheKey()

        @Expect(cache.put(key, "hash"), "invalid_cache_key")
        @Expect(cache.get(key).diagnostic, "invalid_cache_key")
        @Expect(cache.size(), 0)
    }

    @TestCase
    public func stN1001ActiveVersionIsPartOfCacheKey(): Unit {
        let cache = CangjieQueryCache(2)
        let keyA = cangjieServingCacheKey("vr1", "active-a", "docs", "ArrayList.add", 2, "evidence")
        let keyB = cangjieServingCacheKey("vr1", "active-b", "docs", "ArrayList.add", 2, "evidence")

        @Expect(cache.put(keyA, "hash-a"), "stored")
        @Expect(cache.get(keyB).hit, false)
        @Expect(cache.get(keyB).diagnostic, "cache_miss")
        @Expect(cache.get(keyA).valueHash, "hash-a")
    }

    @TestCase
    public func f4Neg01ActiveVersionChangeInvalidatesOldCacheEntries(): Unit {
        let cache = CangjieQueryCache(4)
        let oldKey = cangjieServingCacheKey("vr1", "active-a", "std", "ArrayList.add", 2, "evidence", targetVersion: "1.0.0", interfaceId: "KI-09", selector: "std:ArrayList.add")
        let newKey = cangjieServingCacheKey("vr1", "active-b", "std", "ArrayList.add", 2, "evidence", targetVersion: "1.0.0", interfaceId: "KI-09", selector: "std:ArrayList.add")

        @Expect(oldKey.text().contains("active-a"), true)
        @Expect(oldKey.text().contains("1.0.0"), true)
        @Expect(oldKey.text().contains("std"), true)
        @Expect(oldKey.text().contains("KI-09"), true)
        @Expect(cache.put(oldKey, "hash-old"), "stored")
        @Expect(cache.invalidateOnActiveVersionChange("active-b"), 1)
        @Expect(cache.get(oldKey).diagnostic, "cache_miss")
        @Expect(cache.put(newKey, "hash-new"), "stored")
        @Expect(cache.get(newKey).hit, true)
        @Expect(cache.get(newKey).valueHash, "hash-new")
    }

    @TestCase
    public func p4Pos001CacheStoresStructuredResultMetadata(): Unit {
        let cache = CangjieQueryCache(2)
        let key = cangjieServingCacheKey("vr1", "active-a", "std", "ArrayList.add", 2, "knowledge-pack", targetVersion: "1.0.0", interfaceId: "KI-03", selector: "ArrayList.add")
        let hitIds = ArrayList<String>()
        hitIds.add("serving-symbol-arraylist-add")

        @Expect(cache.putResult(key, "hash-a", resultSummary: "ok=true;hits=1", hitIds: hitIds, createdAt: 42), "stored")
        let lookup = cache.get(key)

        @Expect(lookup.hit, true)
        @Expect(lookup.valueHash, "hash-a")
        @Expect(lookup.resultSummary, "ok=true;hits=1")
        @Expect(lookup.hitIds.size, 1)
        @Expect(lookup.hitIds[0], "serving-symbol-arraylist-add")
        @Expect(lookup.createdAt, 42)
        @Expect(lookup.activeKnowledgeVersion, "active-a")
    }

    @TestCase
    public func p4Bnd002CacheCapacityEvictsOldest(): Unit {
        let cache = CangjieQueryCache(1)
        let keyA = cangjieServingCacheKey("vr1", "active-a", "docs", "A", 1, "evidence")
        let keyB = cangjieServingCacheKey("vr1", "active-a", "docs", "B", 1, "evidence")

        @Expect(cache.put(keyA, "hash-a"), "stored")
        @Expect(cache.put(keyB, "hash-b"), "stored")
        @Expect(cache.size(), 1)
        @Expect(cache.get(keyA).diagnostic, "cache_miss")
        @Expect(cache.get(keyB).valueHash, "hash-b")
    }
}
