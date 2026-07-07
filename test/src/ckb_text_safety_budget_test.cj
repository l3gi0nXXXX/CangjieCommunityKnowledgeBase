package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbTextSafetyBudgetTest {
    @TestCase
    public func utf8SafePrefixDoesNotCutChineseOrEmojiRune(): Unit {
        let raw = "仓颉🙂abcdef"
        let prefix = ckbUtf8SafePrefix(raw, 8)

        @Expect(prefix, "仓颉")
        @Expect(prefix.toRuneArray().size, 2)
        @Expect(ckbUtf8SafePrefix(raw, 0), "")
        @Expect(ckbUtf8SafePrefix(raw, raw.size), raw)
    }

    @TestCase
    public func utf8SafeChunksSplitsOnRuneBoundaries(): Unit {
        let chunks = ckbUtf8SafeChunks("仓颉🙂abcdef", 8)

        @Expect(chunks.size >= 2, true)
        @Expect(chunks[0], "仓颉")
        for (chunk in chunks) {
            @Expect(chunk.size <= 8, true)
            @Expect(chunk.toRuneArray().size > 0, true)
        }
    }

    @TestCase
    public func embeddingTextBudgeterHonorsItemsBytesAndSafeTruncation(): Unit {
        let budget = CkbEmbeddingTextBudget()
        budget.maxBatchItems = 2
        budget.maxBatchBytes = 16
        budget.maxTextBytes = 8
        let budgeter = CkbEmbeddingTextBudgeter(budget)
        let texts = ArrayList<String>()
        texts.add("仓颉🙂abcdef")
        texts.add("plain")
        texts.add("third")

        let batches = budgeter.batches(texts)

        @Expect(batches.size, 2)
        @Expect(batches[0].texts.size, 2)
        @Expect(batches[0].texts[0], "仓颉")
        @Expect(batches[0].truncatedCount, 1)
        @Expect(batches[0].preparedBytes <= 16, true)
        @Expect(batches[1].texts.size, 1)
    }
}
