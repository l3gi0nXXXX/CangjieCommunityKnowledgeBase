package cangjie_community_knowledge_base_test

public func ckbNativeTlsBootstrapScript(command: String, args: Array<String>): String {
    var script = "export CKB_NATIVE_TLS_BOOTSTRAPPED=1; " +
        "MAGIC_ROOT=\"" + "$" + "{MAGIC_PATH:-/Users/l3gi0n/work/workspace_cangjie/CangjieMagic}\"; " +
        "CANGJIE_ROOT=\"" + "$" + "{CANGJIE_HOME:-/Users/l3gi0n/cangjie100}\"; " +
        "export DYLD_LIBRARY_PATH=\"/opt/homebrew/opt/openssl@3/lib:/opt/homebrew/opt/openssl@3.5/lib:/usr/local/opt/openssl@3/lib:" +
        "$" + "{CANGJIE_ROOT}/runtime/lib/darwin_aarch64_llvm:" +
        "$" + "{MAGIC_ROOT}/libs/cangjie-stdx-mac-aarch64-1.0.0.1/darwin_aarch64_llvm/dynamic/stdx:" +
        "$" + "{DYLD_LIBRARY_PATH}\"; " +
        "exec " + ckbShellQuote(command)
    for (arg in args) {
        script += " " + ckbShellQuote(arg)
    }
    script
}

private func ckbShellQuote(value: String): String {
    "'" + value.replace("'", "'\\''") + "'"
}
