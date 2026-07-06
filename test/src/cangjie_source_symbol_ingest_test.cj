package cangjie_community_knowledge_base_test

import std.collection.*
import std.fs.{Directory, File, Path, exists}
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieSourceSymbolIngestTest {
    @TestCase
    public func p2Ut001ExtendGenericReceiverGeneratesArrayListAddAlias(): Unit {
        let result = extractCangjieSourceSymbolRecords("src/std/collection/arraylist_ext.cj", """
package std.collection

extend ArrayList<T> {
    public func add(
        value: T
    ): Unit {}
}
""", CangjieSourceSets.STD, cangjieP3SourceSymbolResolution(CangjieSourceSets.STD))

        @Expect(result.ok, true)
        @Expect(cangjieP3SourceHasSymbol(result, "ArrayList.add"), true)
        @Expect(cangjieP3SourceSymbolSignature(result, "ArrayList.add"), "public func add( value: T ): Unit")
        @Expect(cangjieP3SourceFieldForSymbol(result, "ArrayList.add", "aliases").contains("std.collection.ArrayList.add"), true)
        @Expect(cangjieP3SourceFieldForSymbol(result, "ArrayList.add", "aliases").contains("add"), true)
        @Expect(cangjieP3SourceFieldForSymbol(result, "ArrayList.add", "declaringType"), "ArrayList")
    }

    @TestCase
    public func p2Bnd001Utf8CommentsMultilineGenericAndEmptyFileAreSafe(): Unit {
        let multiline = extractCangjieSourceSymbolRecords("src/std/core/string.cj", """
package std.core

extend String {
    // 中文注释😀 must not break parsing.
    public func contains(
        pattern: String
    ): Bool {}
}
""", CangjieSourceSets.STD, cangjieP3SourceSymbolResolution(CangjieSourceSets.STD))
        let empty = extractCangjieSourceSymbolRecords("src/std/empty.cj", "\n  \n", CangjieSourceSets.STD, cangjieP3SourceSymbolResolution(CangjieSourceSets.STD))

        @Expect(multiline.ok, true)
        @Expect(cangjieP3SourceHasSymbol(multiline, "String.contains"), true)
        @Expect(cangjieP3SourceSymbolSignature(multiline, "String.contains"), "public func contains( pattern: String ): Bool")
        @Expect(empty.ok, false)
        @Expect(empty.diagnostics.contains("empty_source_symbol_file"), true)
    }

    @TestCase
    public func p3Ut001ExtractsSymbolCardsAndModuleTreeFromSource(): Unit {
        let result = extractCangjieSourceSymbolRecords("src/std/collection/arraylist.cj", """
package std.collection
import std.core.*

public class ArrayList<T> {
    public func add(value: T): Unit {}
}
""", CangjieSourceSets.STD, cangjieP3SourceSymbolResolution(CangjieSourceSets.STD))

        @Expect(result.ok, true)
        @Expect(cangjieP3SourceHasKind(result, CangjieTypedRecordKinds.MODULE_TREE), true)
        @Expect(cangjieP3SourceHasSymbol(result, "ArrayList"), true)
        @Expect(cangjieP3SourceHasSymbol(result, "ArrayList.add"), true)
        @Expect(cangjieP3SourceSymbolSignature(result, "ArrayList.add"), "public func add(value: T): Unit")
    }

    @TestCase
    public func p3Bnd001ParsesUtf8CommentsAndMultilineSignature(): Unit {
        let result = extractCangjieSourceSymbolRecords("src/std/core/string.cj", """
package std.core

extend String {
    // 中文注释😀 must not break parsing.
    public func contains(
        pattern: String
    ): Bool {}
}
""", CangjieSourceSets.STD, cangjieP3SourceSymbolResolution(CangjieSourceSets.STD))

        @Expect(result.ok, true)
        @Expect(cangjieP3SourceHasSymbol(result, "String.contains"), true)
        @Expect(cangjieP3SourceSymbolSignature(result, "String.contains"), "public func contains( pattern: String ): Bool")
    }

    @TestCase
    public func p3Pos001ScansStdAndStdxFixturesForCoreSymbols(): Unit {
        let root = "target/p3-source-symbol-fixture"
        let stdDir = Path(root).join("src/std/collection")
        let stdxDir = Path(root).join("src/stdx/options")
        if (!exists(stdDir)) {
            Directory.create(stdDir, recursive: true)
        }
        if (!exists(stdxDir)) {
            Directory.create(stdxDir, recursive: true)
        }
        File.writeTo(Path(root).join("src/std/collection/hashmap.cj"), "package std.collection\npublic class HashMap<K, V> {}\n".toArray())
        File.writeTo(Path(root).join("src/stdx/options/option.cj"), "package stdx.options\npublic enum Option<T> { Some | None }\n".toArray())

        let stdResult = scanCangjieSourceSymbolsRoot(root, CangjieSourceSets.STD, cangjieP3SourceSymbolResolution(CangjieSourceSets.STD))
        let stdxResult = scanCangjieSourceSymbolsRoot(root, CangjieSourceSets.STDX, cangjieP3SourceSymbolResolution(CangjieSourceSets.STDX))

        @Expect(stdResult.ok, true)
        @Expect(stdxResult.ok, true)
        @Expect(cangjieP3SourceHasSymbol(stdResult, "HashMap"), true)
        @Expect(cangjieP3SourceHasSymbol(stdxResult, "Option"), true)
        @Expect(cangjieP3SourceFirstSet(stdxResult, "Option"), CangjieSourceSets.STDX)
    }

    @TestCase
    public func p3Neg001IncompleteFunctionProducesDiagnosticWithoutPanic(): Unit {
        let result = extractCangjieSourceSymbolRecords("src/std/broken.cj", "package std.broken\npublic func broken(value: Int64\n", CangjieSourceSets.STD, cangjieP3SourceSymbolResolution(CangjieSourceSets.STD))

        @Expect(result.ok, false)
        @Expect(cangjieP3SourceHasSymbol(result, "broken"), true)
        @Expect(cangjieP3SourceHasDiagnostic(result, "broken:symbol_signature_incomplete"), true)
    }

    @TestCase
    public func p3Neg002RejectsNonSourceRootsAndUnsupportedSourceSet(): Unit {
        let badRoot = scanCangjieSourceSymbolsRoot("/Users/l3gi0n/.ssh", CangjieSourceSets.STD, cangjieP3SourceSymbolResolution(CangjieSourceSets.STD))
        let badSet = extractCangjieSourceSymbolRecords("src/a.cj", "package a\npublic class A {}\n", CangjieSourceSets.DOCS, cangjieP3SourceSymbolResolution(CangjieSourceSets.STD))

        @Expect(badRoot.ok, false)
        @Expect(badRoot.diagnostics.contains("invalid_source_symbol_root"), true)
        @Expect(badSet.ok, false)
        @Expect(badSet.diagnostics.contains("invalid_source_symbol_source_set"), true)
    }
}

private func cangjieP3SourceSymbolResolution(sourceSet: String): CangjieVersionResolution {
    resolveCangjieVersion(cangjieVersionSelector(targetVersion: "1.0.0", sourceSet: sourceSet), defaultCangjieVersionManifest())
}

private func cangjieP3SourceHasKind(result: CangjieTypedRecordResult, kind: String): Bool {
    for (record in result.records) {
        if (record.recordKind == kind) {
            return true
        }
    }
    false
}

private func cangjieP3SourceHasSymbol(result: CangjieTypedRecordResult, symbol: String): Bool {
    for (record in result.records) {
        if (record.symbol == symbol) {
            return true
        }
    }
    false
}

private func cangjieP3SourceSymbolSignature(result: CangjieTypedRecordResult, symbol: String): String {
    cangjieP3SourceFieldForSymbol(result, symbol, "signature")
}

private func cangjieP3SourceFieldForSymbol(result: CangjieTypedRecordResult, symbol: String, field: String): String {
    for (record in result.records) {
        if (record.symbol == symbol) {
            return cangjieP3SourceField(record.content, field)
        }
    }
    ""
}

private func cangjieP3SourceFirstSet(result: CangjieTypedRecordResult, symbol: String): String {
    for (record in result.records) {
        if (record.symbol == symbol) {
            return record.sourceSet
        }
    }
    ""
}

private func cangjieP3SourceHasDiagnostic(result: CangjieTypedRecordResult, diagnostic: String): Bool {
    for (item in result.diagnostics) {
        if (item == diagnostic || item.endsWith(":${diagnostic}")) {
            return true
        }
    }
    false
}

private func cangjieP3SourceField(content: String, key: String): String {
    let prefix = "${key}="
    for (line in content.split("\n")) {
        if (line.startsWith(prefix)) {
            let parts = line.split(prefix)
            if (parts.size > 1) {
                return parts[1].trimAscii()
            }
        }
    }
    ""
}
