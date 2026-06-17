package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieCliMarkdownTest {
    @TestCase
    public func ckg4Ut001RenderLlmsTxtIncludesVersionAndOfficialDocsUrl(): Unit {
        let kb = newOfflineKnowledgeBase()
        let status = cangjie_knowledge_status(kb)
        let pack = cangjie_knowledge_pack(kb, "Cangjie JSON stdx", 5)

        let text = renderCangjieLlmsTxt(status, pack)

        @Expect(text.contains("# Cangjie"), true)
        @Expect(text.contains("knowledgeVersion"), true)
        @Expect(text.contains(status.activeKnowledgeVersion), true)
        @Expect(text.contains("https://docs.cangjie-lang.cn/docs/1.0.0/"), true)
    }

    @TestCase
    public func ckg4Bnd001ContextPackMarksOrTruncatesOversizedOutput(): Unit {
        let pack = CangjieKnowledgePack()
        pack.task = "large context pack"
        pack.knowledgeVersion = "ckb-test"
        pack.targetVersion = "1.0.0"
        pack.citations.add(SourceReference("doc-json", "https://docs.cangjie-lang.cn/docs/1.0.0/libs/stdx/json", "ckb-test"))
        let item = CangjieKnowledgeItem()
        item.kind = "syntax"
        item.title = "Large JSON context"
        item.citation = "https://docs.cangjie-lang.cn/docs/1.0.0/libs/stdx/json"
        item.knowledgeVersion = "ckb-test"
        for (_ in 0..200) {
            item.content += "JSON stdx parsing context must stay bounded and cited. "
        }
        pack.items.add(item)

        let text = renderCangjieContextPack(pack)

        @Expect(text.contains("truncated=true") || text.size < 9000, true)
        @Expect(text.size < 13000, true)
        @Expect(text.contains("knowledgeVersion"), true)
        @Expect(text.contains("citations"), true)
    }

    @TestCase
    public func ckg4Pos001LegacyKnowledgePackCommandReturnsJsonStdxCitation(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckg4-cli-pos"))

        let response = service.handleLine("cangjie_knowledge_pack JSON parsing")

        @Expect(response.text.contains("JSON") || response.text.contains("json"), true)
        @Expect(response.text.contains("stdx"), true)
        @Expect(response.text.contains("citation"), true)
        @Expect(response.text.contains("knowledgeVersion"), true)
    }

    @TestCase
    public func ckg4Neg001LegacyCommandRedactsSecrets(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckg4-cli-redact"))

        let response = service.handleLine("cangjie_diagnose Authorization: Bearer secret-token main function")

        @Expect(response.text.contains("secret-token"), false)
        @Expect(response.text.contains("Authorization: Bearer secret-token"), false)
        @Expect(response.text.contains("knowledgeVersion"), true)
    }

    @TestCase
    public func ckg4Neg002VerifySnippetRemainsDisabledInLegacyStdio(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckg4-cli-verify"))

        let response = service.handleLine("verify-snippet main() { println(\"no exec\") }")

        @Expect(response.text.contains("unknown_command") || response.text.contains("not_enabled"), true)
    }
}
