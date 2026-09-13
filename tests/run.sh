#!/usr/bin/env bash
# QuarkLangLibs-Style 单测入口
# 用法：QUARK=/tmp/quark ./tests/run.sh [过滤词 ...]
# 依赖：style.qk（仓库根）；纯 qk，无 json、无 native
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QUARK="${QUARK:-quark}"
if [ ! -x "$QUARK" ] && ! command -v "$QUARK" >/dev/null 2>&1; then
  echo "quark 解释器不可用：QUARK=$QUARK" >&2
  exit 2
fi
BUILD="$(mktemp -d /tmp/qlstyle-tests.XXXXXX)"
trap 'rm -rf "$BUILD"' EXIT
cp "$ROOT/style.qk" "$BUILD/style.qk"

fail=0
libout="$(cd "$BUILD" && "$QUARK" style.qk 2>&1)"
if printf '%s' "$libout" | grep -q "cannot run a library"; then
  echo "PASS style.qk (parse+typecheck；library 不可运行 = 通过)"
else
  fail=$((fail + 1))
  echo "FAIL style.qk"
  printf '%s\n' "$libout" | head -4
fi

total=0
for t in "$ROOT"/tests/*.qk; do
  name="$(basename "$t" .qk)"
  if [ "$#" -gt 0 ]; then
    match=0
    for f in "$@"; do case "$name" in *"$f"*) match=1 ;; esac; done
    [ "$match" = 1 ] || continue
  fi
  total=$((total + 1))
  cp "$t" "$BUILD/$name.qk"
  out="$(cd "$BUILD" && "$QUARK" "$name.qk" 2>&1)"
  rc=$?
  ok="$(printf '%s\n' "$out" | grep -c '^OK')"
  bad="$(printf '%s\n' "$out" | grep -c '^FAIL')"
  if [ "$rc" -ne 0 ] || [ "$bad" -ne 0 ]; then
    fail=$((fail + 1))
    echo "FAIL $name (rc=$rc ok=$ok bad=$bad)"
    printf '%s\n' "$out" | grep -E '^FAIL|error|Error' | head -4
  else
    echo "PASS $name ($ok assertions)"
  fi
done
echo "tests: $total files, failures=$fail"
[ "$fail" -eq 0 ]
