package cangjie_community_knowledge_base_test

public func ckbNativeTlsBootstrapEnvScript(caFile!: String = ""): String {
    // Matches Metis by exposing Homebrew OpenSSL 3, Cangjie runtime, stdx, and
    // project ffi fallback paths to dyld. CA files are only used when explicitly
    // configured; CKB does not generate CA bundles.
    var script = "export CKB_NATIVE_TLS_BOOTSTRAPPED=1; " +
        "CKB_CJPM_SKIP_BUILD_MAGIC_ROOT=\"" + "$" + "{MAGIC_PATH:-" + "$" + "{CKB_MAGIC_ROOT:-}}\"; " +
        "CKB_CJPM_SKIP_BUILD_CANGJIE_ROOT=\"" + "$" + "{CANGJIE_HOME:-" + "$" + "{CKB_CANGJIE_ROOT:-}}\"; " +
        "CKB_DYLD_EXTRA=\"/opt/homebrew/opt/openssl@3/lib:/opt/homebrew/opt/openssl@3.5/lib:/usr/local/opt/openssl@3/lib\"; " +
        "if [ -n \"" + "$" + "{CKB_CJPM_SKIP_BUILD_CANGJIE_ROOT}\" ]; then CKB_DYLD_EXTRA=\"" + "$" + "{CKB_DYLD_EXTRA}:" + "$" + "{CKB_CJPM_SKIP_BUILD_CANGJIE_ROOT}/runtime/lib/darwin_aarch64_llvm\"; fi; " +
        "if [ -n \"" + "$" + "{CKB_CJPM_SKIP_BUILD_MAGIC_ROOT}\" ]; then CKB_DYLD_EXTRA=\"" + "$" + "{CKB_DYLD_EXTRA}:" + "$" + "{CKB_CJPM_SKIP_BUILD_MAGIC_ROOT}/libs/cangjie-stdx-mac-aarch64-1.0.0.1/darwin_aarch64_llvm/dynamic/stdx\"; fi; " +
        "export DYLD_LIBRARY_PATH=\"" +
        "$" + "{CKB_DYLD_EXTRA}:" +
        "$" + "{DYLD_LIBRARY_PATH}\"; "
    let trimmedCaFile = caFile.trimAscii()
    if (trimmedCaFile != "") {
        script += "export SSL_CERT_FILE=" + ckbNativeTlsShellQuote(trimmedCaFile) + "; "
    }
    script
}

public func ckbNativeTlsBootstrapScript(command: String, args: Array<String>,
    caFile!: String = ""): String {
    var script = ckbNativeTlsBootstrapEnvScript(caFile: caFile) +
        "exec " + ckbNativeTlsShellQuote(command)
    for (arg in args) {
        script += " " + ckbNativeTlsShellQuote(arg)
    }
    script
}

public func ckbCommandNeedsNativeTlsBootstrap(command: String): Bool {
    command == "native-http-smoke" ||
        command == "sync-live" ||
        command == "source_analysis" ||
        command == "source-analysis" ||
        command == "service" ||
        command == "start" ||
        command == "service-http" ||
        command == "http-service" ||
        command == "certification-http" ||
        command == "service-once" ||
        command == "scheduler-run" ||
        command == "scheduler-task-worker" ||
        command == "vector-bootstrap" ||
        command == "vector-clean-derived" ||
        command == "vector-reconcile" ||
        command == "routine-repair" ||
        command == "rebuild-index" ||
        command == "cangjie-update-promotion-smoke" ||
        command == "status" ||
        command == "doctor" ||
        command == "metrics" ||
        command == "cangjie-landing-status" ||
        command == "cangjie-corpus-status" ||
        command == "ckb-portable-vector-build" ||
        command == "ckb-qdrant-snapshot" ||
        command == "ckb-retrieval-parity" ||
        command == "ckb-repro-composition-seal" ||
        command == "ckb-repro-composition-stage" ||
        command == "ckb-repro-build" ||
        command == "ckb-repro-promote" ||
        command == "ckb-repro-verify"
}

private func ckbNativeTlsShellQuote(value: String): String {
    "'" + value.replace("'", "'\\''") + "'"
}
