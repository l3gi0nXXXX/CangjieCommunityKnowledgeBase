package cangjie_community_knowledge_base_test

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
