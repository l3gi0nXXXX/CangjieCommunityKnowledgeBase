# 从固定源码重建

状态：W7 的源码与知识身份已冻结；最终 tag 由 W11 定稿。

## 测试目标

目的：从固定源码和公开输入重建 `ckb-first-init-1-0-0-candidate`，不依赖发布快照内容。

## 测试结论怎么判定

| 项目 | 必须结果 |
|---|---|
| run-critical | manifest 与 tree hash 一致 |
| records | 7,817 |
| vector points / dimension | 7,817 / 1,024 |
| portable path findings | 0 |
| knowledge leakage findings | 0 |

通过标准：重建证明与 reference manifest 绑定，输出位于新的隔离目录。

失败处理：源码、输入或 hash 漂移时标记 `hash_mismatch_stop`，不替换生产知识。

## 重要边界

只读取 manifest 列出的公开输入；不读取 HOME、生产 store、评测答案或 Teacher 工件。路径可包含空格。

## 第 1 步：准备构建环境

目的：验证源码与 run-critical 清单。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cd "${CKB_ROOT:?set CKB_ROOT}"
export REPRO_ROOT="${REPRO_ROOT:-${TMPDIR:-/tmp}/ckb repro rebuild}"
mkdir -p "${REPRO_ROOT}"
source "${CANGJIE_SDK_ROOT:?set CANGJIE_SDK_ROOT}/envsetup.sh"
export OPENSSL_ROOT="${OPENSSL_ROOT:-$(brew --prefix openssl@3)}"
export DYLD_LIBRARY_PATH="${OPENSSL_ROOT}/lib:${DYLD_LIBRARY_PATH:-}"
cjpm build -i
```

预期输出：构建成功。

通过标准：退出码为 0，工作树版本与 W11 发布身份一致。

失败处理：停止并核对发布说明，不用其他分支替代。

## 第 2 步：执行 portable 构建

目的：通过已注册的生产构建入口生成隔离候选。

工作目录：`${CKB_ROOT}`。

命令：

```bash
cjpm run --skip-build --run-args   "ckb-repro-build --composition-manifest ${CKB_COMPOSITION_MANIFEST:?set composition manifest} --json"
```

预期输出：JSON 中 `ok=true`，记录数和知识版本与 W7 冻结值一致。

通过标准：7,817 条记录、portable finding=0，构建证明 hash 有效。

失败处理：任一门禁失败即停止，不复制部分输出到生产环境。

## 第 3 步：核对 reference

目的：确认重建结果对应已冻结的参考运行。

工作目录：`${CKB_ROOT}`。

命令：

```bash
jq -e '.knowledgeVersion == "ckb-first-init-1-0-0-candidate" and
       .strictPassed == 158'   reproducibility/manifests/reference-run.json >/dev/null
echo "exit=$?"
```

预期输出：

```text
exit=0
```

通过标准：reference 与重建知识身份一致。

失败处理：停止 promotion，不修改 reference manifest。
