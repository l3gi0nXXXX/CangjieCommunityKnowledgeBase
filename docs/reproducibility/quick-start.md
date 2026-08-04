# 快速开始

状态：W7 参考结果已冻结；W11 将补充普通 tag 与 Release URL，不使用 GPG 签名。

## 测试目标

目的：用最短路径确认源码、参考结果和运行环境可用于后续恢复或独立复现。

## 测试结论怎么判定

| 项目 | 必须结果 |
|---|---|
| reference | strict=158、raw=160、total=164 |
| knowledgeVersion | `ckb-first-init-1-0-0-candidate` |
| records / vectors | 7,817 / 7,817 |
| public evidence | hash 与导航页一致 |
| 环境 | SDK、OpenSSL、`cjHeapSize=4GB` 已设置 |

通过标准：reference manifest 校验通过且项目构建成功。

失败处理：输出不一致时停止，不猜测 tag、URL、hash 或版本。

## 重要边界

路径可包含空格；测试根使用 `${REPRO_ROOT}`，不得指向生产 `ckb-data`。

## 第 1 步：准备环境

目的：隔离日志并加载构建环境。

工作目录：`${CKB_ROOT}`。

命令：

```bash
export CKB_ROOT="${CKB_ROOT:?set CKB_ROOT}"
export REPRO_ROOT="${REPRO_ROOT:-${TMPDIR:-/tmp}/ckb repro quick}"
mkdir -p "${REPRO_ROOT}/logs"
cd "${CKB_ROOT}"
source "${CANGJIE_SDK_ROOT:?set CANGJIE_SDK_ROOT}/envsetup.sh"
export OPENSSL_ROOT="${OPENSSL_ROOT:-$(brew --prefix openssl@3)}"
export DYLD_LIBRARY_PATH="${OPENSSL_ROOT}/lib:${DYLD_LIBRARY_PATH:-}"
export cjHeapSize=4GB
cjpm build -i >"${REPRO_ROOT}/logs/build.stdout" 2>"${REPRO_ROOT}/logs/build.stderr"
echo "exit=$?"
```

预期输出：

```text
exit=0
```

通过标准：构建成功，日志无动态库错误。

失败处理：查看隔离日志，并参考[故障处理](troubleshooting.md)和[服务运维](../service-http-operations.md)。

## 第 2 步：检查 W7 参考结果

目的：确认公开文档引用的是同一轮 portable 结果。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT}"
jq -e '.totalCases == 164 and .strictPassed == 158 and
       .rawPassed == 160 and .strictFailed == 6 and
       .businessFailed == 2 and .protocolInvalid == 2 and
       .transportUnresolved == 2 and
       .knowledgeVersion == "ckb-first-init-1-0-0-candidate"'   reproducibility/manifests/reference-run.json >/dev/null
echo "exit=$?"
```

预期输出：

```text
exit=0
```

通过标准：退出码为 0；158/164 大于等于发布门槛 151。

失败处理：标记 `hash_mismatch_stop` 并停止，不能手改 manifest。
