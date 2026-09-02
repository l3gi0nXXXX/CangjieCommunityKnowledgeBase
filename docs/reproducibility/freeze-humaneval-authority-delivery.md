# HumanEval+ authority delivery 冻结与验收手册

## 目标与边界

本手册只冻结 HumanEval+ authority delivery，不调用 Student 模型。认证执行只接受 `bundled`；`public_rebuild` 仅保留结构解析能力，production validator 会以 `authority_public_rebuild_not_executable` 拒绝执行。bundle 使用 CKB 的确定性 `CKBREL01` 格式，不得用 `tar` 或 `zstd` 手工替代。

固定工件包括 164 题 authority、source-lock、release attachment、两份独立 LICENSE、内部 license evidence、内部 bundle index 和 delivery manifest。任何一个字节不匹配都必须 fail-close。

目的：冻结并复核可执行的 HumanEval+ authority delivery，不调用 Student 模型。

工作目录：`${CKB_ROOT}` 指向 clean、canonical 的 CKB 仓库根目录。

命令：仅使用本文登记的 `ckb-authority-bundle` 与只读验证命令。

预期输出：生成精确两文件 delivery，并由 verify 返回 164 题有效的单个 JSON。

通过标准：固定 Git 身份、LICENSE、release attachment、source-lock、bundle 和 delivery manifest 全部匹配。

失败处理：任一身份、hash、布局或许可证口径不满足时立即停止，不进入 P5。

## 1. 准备隔离目录

```bash
set -euo pipefail
: "${CKB_ROOT:?set the current CKB repository worktree; do not reuse another checkout}"
export CKB_ROOT="$(cd "$CKB_ROOT" && pwd -P)"
cd "$CKB_ROOT"
test "$(git rev-parse --show-toplevel)" = "$CKB_ROOT"
git ls-files --error-unmatch src/ckb_repro_authority_bundle.cj >/dev/null
git diff --quiet && git diff --cached --quiet
test -z "$(git status --porcelain)"
export CKB_AUTHORITY_TMP="$(mktemp -d "${TMPDIR:-/tmp}/ckb-authority-freeze.XXXXXX")"
export CKB_AUTHORITY_TMP="$(cd "$CKB_AUTHORITY_TMP" && pwd -P)"
export CKB_AUTHORITY_DELIVERY_ROOT="$CKB_ROOT/target/repro-authority-delivery"
test ! -e "$CKB_AUTHORITY_DELIVERY_ROOT"
```

通过标准：`$CKB_ROOT` 是维护者明确指定、当前 clean 的 CKB worktree；`$CKB_AUTHORITY_TMP` 位于 `${TMPDIR:-/tmp}`，不在仓库、知识 store 或 Student workspace 内。

## 2. 验证固定 Git 身份

```bash
git init -q "$CKB_AUTHORITY_TMP/release-repo"
git -C "$CKB_AUTHORITY_TMP/release-repo" fetch -q --depth=1 \
  https://github.com/evalplus/humanevalplus_release.git refs/tags/v0.1.10
test "$(git -C "$CKB_AUTHORITY_TMP/release-repo" rev-parse FETCH_HEAD^{commit})" = \
  68cd26d53a0dec69f85eafe1f82a2a74155a2bd6
test "$(git -C "$CKB_AUTHORITY_TMP/release-repo" rev-parse FETCH_HEAD^{tree})" = \
  8134abd00a3f022a7df0d1d410d90b59ccd3e69a

git init -q "$CKB_AUTHORITY_TMP/evaluator-repo"
git -C "$CKB_AUTHORITY_TMP/evaluator-repo" fetch -q --depth=1 \
  https://github.com/evalplus/evalplus.git \
  437e6936d3fad9487e891c24e4509b9561b95e3a
test "$(git -C "$CKB_AUTHORITY_TMP/evaluator-repo" rev-parse FETCH_HEAD^{commit})" = \
  437e6936d3fad9487e891c24e4509b9561b95e3a
test "$(git -C "$CKB_AUTHORITY_TMP/evaluator-repo" rev-parse FETCH_HEAD^{tree})" = \
  f185f11ba5ccecdd1e40d9a836f9d9e7ce40eac2
```

通过标准：所有 `test` 命令退出 0。

## 3. 下载并验证固定字节

```bash
curl --fail --location --retry 5 --output "$CKB_AUTHORITY_TMP/release-LICENSE" \
  https://raw.githubusercontent.com/evalplus/humanevalplus_release/68cd26d53a0dec69f85eafe1f82a2a74155a2bd6/LICENSE
curl --fail --location --retry 5 --output "$CKB_AUTHORITY_TMP/evaluator-LICENSE" \
  https://raw.githubusercontent.com/evalplus/evalplus/437e6936d3fad9487e891c24e4509b9561b95e3a/LICENSE
curl --fail --location --retry 5 --output "$CKB_AUTHORITY_TMP/HumanEvalPlus.jsonl.gz" \
  https://github.com/evalplus/humanevalplus_release/releases/download/v0.1.10/HumanEvalPlus.jsonl.gz

test "$(wc -c < "$CKB_AUTHORITY_TMP/release-LICENSE" | tr -d ' ')" = 11549
test "$(wc -c < "$CKB_AUTHORITY_TMP/evaluator-LICENSE" | tr -d ' ')" = 11558
test "$(wc -c < "$CKB_AUTHORITY_TMP/HumanEvalPlus.jsonl.gz" | tr -d ' ')" = 925932
test "$(shasum -a 256 "$CKB_AUTHORITY_TMP/release-LICENSE" | awk '{print $1}')" = \
  b0b08821a8c2b49e0f296b0b498c17d6e19b0439d1e4dd9cdb5f37712993c8a7
test "$(shasum -a 256 "$CKB_AUTHORITY_TMP/evaluator-LICENSE" | awk '{print $1}')" = \
  fcc1f77fe5443b21bfc4dfcc3d66f7654f599b91582df771850e5e876986a103
test "$(shasum -a 256 "$CKB_AUTHORITY_TMP/HumanEvalPlus.jsonl.gz" | awk '{print $1}')" = \
  272720b90ac375502c8ed23cd791c2a93dfb22a911641a494da74a426c09f101
gzip -t "$CKB_AUTHORITY_TMP/HumanEvalPlus.jsonl.gz"
gzip -dc "$CKB_AUTHORITY_TMP/HumanEvalPlus.jsonl.gz" > \
  "$CKB_AUTHORITY_TMP/HumanEvalPlus.jsonl"
test "$(shasum -a 256 "$CKB_AUTHORITY_TMP/HumanEvalPlus.jsonl" | awk '{print $1}')" = \
  42526ec0e7d5f3ee0b06d6ced98f8c8bae3d76519151bfb3d36f79010645bd7f
test "$(wc -l < "$CKB_AUTHORITY_TMP/HumanEvalPlus.jsonl" | tr -d ' ')" = 164
```

主动证明 tag tree 内旧 gzip 不可替代 release attachment：

```bash
git -C "$CKB_AUTHORITY_TMP/release-repo" show \
  68cd26d53a0dec69f85eafe1f82a2a74155a2bd6:HumanEvalPlus.jsonl.gz > \
  "$CKB_AUTHORITY_TMP/tag-tree-HumanEvalPlus.jsonl.gz"
test "$(wc -c < "$CKB_AUTHORITY_TMP/tag-tree-HumanEvalPlus.jsonl.gz" | tr -d ' ')" = 936542
! cmp -s "$CKB_AUTHORITY_TMP/tag-tree-HumanEvalPlus.jsonl.gz" \
  "$CKB_AUTHORITY_TMP/HumanEvalPlus.jsonl.gz"
```

## 4. 封装并验证 authority bundle

维护者必须先确认 `Apache-2.0 AND MIT` 的交付口径。未确认时保留仓库中的 `mode=blocked`，不得执行本步骤或进入 P5。

```bash
: "${CANGJIE_SDK_ROOT:?set the Cangjie SDK root}"
source "$CANGJIE_SDK_ROOT/envsetup.sh"
OPENSSL_ROOT="${OPENSSL_ROOT:-$(brew --prefix openssl@3)}"
export DYLD_LIBRARY_PATH="${OPENSSL_ROOT}/lib:${DYLD_LIBRARY_PATH:-}"
cjpm build -i

export AUTHORITY_MANIFEST="$CKB_ROOT/test/cangjie_eval/cangjie_humaneval_manifest.jsonl"
export AUTHORITY_SOURCE_LOCK="$CKB_ROOT/test/cangjie_eval/authority/HumanEvalPlus-v0.1.10/source-lock.json"
cjpm run --skip-build --run-args \
  "cangjie-humaneval-manifest-build --dataset-root $CKB_ROOT/test/cangjie_eval/cases/Cangjie-HumanEval --output $CKB_AUTHORITY_TMP/repository-authority.jsonl"
cmp "$CKB_AUTHORITY_TMP/repository-authority.jsonl" "$AUTHORITY_MANIFEST"
test "$(shasum -a 256 "$AUTHORITY_MANIFEST" | awk '{print $1}')" = \
  34c9171d82e84c41e59154aca4f77b8a57bcbca6db792dcd0627a0819af35a13
test "$(shasum -a 256 "$AUTHORITY_SOURCE_LOCK" | awk '{print $1}')" = \
  42af8d986e94d8629407a04c5350da24db574abedd736205cbee914bf68f0454

cjpm run --skip-build --run-args \
  "ckb-authority-bundle seal --authority $AUTHORITY_MANIFEST --source-lock $AUTHORITY_SOURCE_LOCK --release-asset $CKB_AUTHORITY_TMP/HumanEvalPlus.jsonl.gz --release-license $CKB_AUTHORITY_TMP/release-LICENSE --evaluator-license $CKB_AUTHORITY_TMP/evaluator-LICENSE --output-root $CKB_AUTHORITY_DELIVERY_ROOT"
cjpm run --skip-build --run-args \
  "ckb-authority-bundle verify --authority $AUTHORITY_MANIFEST --delivery-root $CKB_AUTHORITY_DELIVERY_ROOT --json" | \
  jq -e '.ok == true and .presentCount == 164 and
    .authorityHash == "sha256:34c9171d82e84c41e59154aca4f77b8a57bcbca6db792dcd0627a0819af35a13" and
    .datasetVersion == "cangjie-humaneval-164-sha256:8be3a9eb4b5a9411f549420dbf201be35582fa5279a5710177948aa788cf2de1"'
```

通过标准：seal 和 verify 均退出 0；输出目录只含固定 delivery manifest 与 CKBREL01 bundle。命令不读取知识 store、不访问模型、不输出 LICENSE 或 authority 大 payload。

## 5. 自动化回归

```bash
cd "$CKB_ROOT/test"
cjpm test -j 1 --filter CkbReproEnvironmentTest
```

通过标准：bundled 正向、blocked/public fail-close、LICENSE/source-lock/index/authority/UTF-8/大小/路径篡改以及两阶段 Runner 门禁全部通过。

## 6. P5 前停止检查

```bash
jq -e '
  .mode == "bundled" and
  .licenseId == "Apache-2.0 AND MIT" and
  .redistributionAllowed == true and .anonymousPublicAccess == false and
  .authorityHash == "sha256:34c9171d82e84c41e59154aca4f77b8a57bcbca6db792dcd0627a0819af35a13" and
  .datasetVersion == "cangjie-humaneval-164-sha256:8be3a9eb4b5a9411f549420dbf201be35582fa5279a5710177948aa788cf2de1" and
  (.bundleHash | test("^sha256:[0-9a-f]{64}$")) and
  (.licenseEvidenceHash | test("^sha256:[0-9a-f]{64}$"))' \
  "$CKB_AUTHORITY_DELIVERY_ROOT/authority-delivery.json"
```

随后把仓库根目录内的三个绝对 canonical 路径分别配置为 `CKB_REPRO_AUTHORITY_DELIVERY`、`CKB_REPRO_DATASET_MANIFEST`、`CKB_REPRO_AUTHORITY_BUNDLE`，并显式 `export`。bundle 位于已被 `.gitignore` 覆盖的 `target/` 下，不得强制提交；`git status --porcelain` 必须保持 clean。再由 `ckb-repro-verify --mode run-certify` 的 production P8 链执行预检。任何字段为空、`blocked`、bundle 缺失或被替换时必须停止，模型调用数必须为 0。

## 7. 清理

验收证据另行保存后执行：

```bash
rm -rf -- "$CKB_AUTHORITY_TMP"
unset CKB_AUTHORITY_TMP CKB_AUTHORITY_DELIVERY_ROOT AUTHORITY_MANIFEST AUTHORITY_SOURCE_LOCK
```

不得把 `${TMPDIR:-/tmp}` 下载物、bundle 或许可证证据绕过 `.gitignore` 强制提交。
