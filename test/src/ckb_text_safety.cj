package cangjie_community_knowledge_base_test

import std.collection.ArrayList

public func ckbUtf8SafePrefix(raw: String, maxBytes: Int64): String {
    if (maxBytes <= 0) {
        return ""
    }
    if (raw.size <= maxBytes) {
        return raw
    }
    let out = StringBuilder()
    var used: Int64 = 0
    for (ch in raw.toRuneArray()) {
        let piece = "${ch}"
        let next = used + piece.size
        if (next > maxBytes) {
            break
        }
        out.append(ch)
        used = next
    }
    out.toString()
}

public func ckbUtf8SafeChunks(raw: String, maxChunkBytes: Int64): ArrayList<String> {
    let chunks = ArrayList<String>()
    if (maxChunkBytes <= 0) {
        chunks.add("")
        return chunks
    }
    if (raw.size <= maxChunkBytes) {
        chunks.add(raw)
        return chunks
    }
    var current = StringBuilder()
    var used: Int64 = 0
    for (ch in raw.toRuneArray()) {
        let piece = "${ch}"
        let pieceSize = piece.size
        if (pieceSize > maxChunkBytes) {
            if (used > 0) {
                chunks.add(current.toString())
                current = StringBuilder()
                used = 0
            }
            continue
        }
        if (used > 0 && used + pieceSize > maxChunkBytes) {
            chunks.add(current.toString())
            current = StringBuilder()
            used = 0
        }
        current.append(ch)
        used += pieceSize
    }
    if (used > 0 || chunks.size == 0) {
        chunks.add(current.toString())
    }
    chunks
}
