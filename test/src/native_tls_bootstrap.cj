package cangjie_community_knowledge_base_test

public func ckbNativeTlsBootstrapEnvScript(caFile!: String = ""): String {
    // Matches Metis by exposing Homebrew OpenSSL 3 to dyld. The Cangjie/stdx
    // entries only support CKB's cjpm --skip-build runtime shape. CA files are
    // only used when explicitly configured; CKB does not generate CA bundles.
    var script = "export CKB_NATIVE_TLS_BOOTSTRAPPED=1; " +
        "CKB_CJPM_SKIP_BUILD_MAGIC_ROOT=\"" + "$" + "{MAGIC_PATH:-/Users/l3gi0n/work/workspace_cangjie/CangjieMagic}\"; " +
        "CKB_CJPM_SKIP_BUILD_CANGJIE_ROOT=\"" + "$" + "{CANGJIE_HOME:-/Users/l3gi0n/cangjie100}\"; " +
        "export DYLD_LIBRARY_PATH=\"/opt/homebrew/opt/openssl@3/lib:/opt/homebrew/opt/openssl@3.5/lib:/usr/local/opt/openssl@3/lib:" +
        "$" + "{CKB_CJPM_SKIP_BUILD_CANGJIE_ROOT}/runtime/lib/darwin_aarch64_llvm:" +
        "$" + "{CKB_CJPM_SKIP_BUILD_MAGIC_ROOT}/libs/cangjie-stdx-mac-aarch64-1.0.0.1/darwin_aarch64_llvm/dynamic/stdx:" +
        "$" + "{DYLD_LIBRARY_PATH}\"; "
    let trimmedCaFile = caFile.trimAscii()
    if (trimmedCaFile != "") {
        script += "export SSL_CERT_FILE=" + ckbNativeTlsShellQuote(trimmedCaFile) + "; "
    }
    script
}

private func ckbNativeTlsShellQuote(value: String): String {
    "'" + value.replace("'", "'\\''") + "'"
}
