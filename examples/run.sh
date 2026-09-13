#!/usr/bin/env bash
# QuarkLangLibs-Style 示例入口（纯 qk：无需 json.qk / libclegrt.so）
# 用法：QUARK=/tmp/quark ./examples/run.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QUARK="${QUARK:-quark}"
BUILD="$(mktemp -d /tmp/qlstyle-examples.XXXXXX)"
trap 'rm -rf "$BUILD"' EXIT
cp "$ROOT/style.qk" "$BUILD/style.qk"
cp "$ROOT/examples/style-demo.qk" "$BUILD/style-demo.qk"
fail=0
out="$(cd "$BUILD" && "$QUARK" style-demo.qk 2>&1)"
rc=$?
if [ "$rc" -ne 0 ] || ! printf '%s' "$out" | grep -q "style demo ok"; then
  fail=$((fail + 1))
  echo "FAIL example style-demo (rc=$rc)"
  printf '%s\n' "$out" | tail -6
else
  echo "PASS example style-demo"
  printf '%s\n' "$out"
fi
echo "examples: failures=$fail"
[ "$fail" -eq 0 ]
