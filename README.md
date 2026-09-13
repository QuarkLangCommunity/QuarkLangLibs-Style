# QuarkLangLibs-Style — QuarkLang 通用样式库

**样式与动画是通用能力，不属于任何 GUI 框架。** 本库把 cleg 里的样式引擎（QSS 值解析 / 级联求值 / 盒模型 / 关键帧动画）
抽成独立库：**纯 qk、零依赖、零 FFI、无模块级全局**，状态全部放在实例（HashTable / Theme / Animator）内。
任何渲染后端（cleg 的 native 帧缓冲、终端、Web、测试桩）都可以直接消费它；cleg 只是消费者之一。

- 契约（样式键全集 / 级联顺序 / 动画模型 / native 语义裁定）：[STYLE-SPEC.md](STYLE-SPEC.md)
- 本库与 cleg 共用同一份契约；权威副本在本仓库。

## 文件

```
style.qk                 库本体（program library；import "style" 使用）
STYLE-SPEC.md            样式键与求值语义的权威清单（通用契约）
tests/run.sh             单测入口（QUARK=/tmp/quark ./tests/run.sh）
tests/qss-parse.qk       值解析单测（长度/颜色/渐变/transform/缓动/简写/关键帧/插值）
tests/state-cascade.qk   级联/状态/选择器/盒模型/Theme 单测
tests/anim-interp.qk     Animator 关键帧 + transition 端到端单测
examples/run.sh          示例入口（纯 qk，无需 native）
examples/style-demo.qk   最小示例：解析 → 级联 → 盒模型 → 动画插值的数值输出
```

## 快速开始

```qk
import "style";

program main;

// 只要实现这 6 个方法就满足 StyleNode（结构化满足，无需声明实现关系）
type struct {
    HashTable<String, String> style;
    int x; int y; int w; int h;
} Box;

impl {
    fn new(int x, int y, int w, int h) Box { Box b; b.style = HashTable::new(); b.x = x; b.y = y; b.w = w; b.h = h; return b; }
    fn getStyle(Box self) HashTable<String, String> { return self.style; }
    fn setStyle(Box self, String jsonText) void { style::setStyle(self, jsonText); }
    fn getX(Box self) int { return self.x; }
    fn getY(Box self) int { return self.y; }
    fn getW(Box self) int { return self.w; }
    fn getH(Box self) int { return self.h; }
} Box;

fn main(IOStream io) {
    Box b = Box::new(20, 20, 160, 48);
    b.getStyle()["__type"] = "Box";                    // 选择器块匹配用的类型名
    Theme t = Theme::fromJson("{\"color\":\"#8899aa\",\"padding\":\"4\"}");
    t.apply(b);                                        // 全局层（最低优先级，除默认层外）
    b.setStyle("{\"padding\":\"8\",\"color:hover\":\"#ffcc00\",\"border-width\":\"2\"}");

    io.println(style::get(b, "padding", ""));           // 8   —— 自身 > 主题
    io.println(style::get(b, "color", "hover"));        // #ffcc00 —— 状态 > 自身
    Rect c = style::contentRect(b);                     // 盒模型（扣 margin/border/padding）
    io.println(c.x.toString() + "," + c.y.toString() + "," + c.w.toString() + "," + c.h.toString());
}
```

## API

### space qss —— 纯值解析（无节点、无状态）
| 分组 | 函数 |
|---|---|
| 长度/数值 | `len` `stripUnit` `box4`（1..4 值简写） `splitAny` `fnum` `fint` `frac` `isNum` `clamp255` |
| 时间/字号 | `time`（ms/s） `fontSize`（px/pt） `lineHeightPx`（倍数/长度） |
| 颜色 | `color`（#rgb/#rrggbb/#aarrggbb/rgb()/rgba()/具名/旧式 "r,g,b"） `cR` `cG` `cB` `cA` `mkColor` `argbStr` `mixColor` `overColor` `isColorStr` |
| 渐变 | `gradient`（linear/radial） `gradDir`（§9.1 方向裁定） `StyleGradient` |
| 变换 | `transform`（translate/scale/rotate） `transformStr` `hasTransform` `StyleTransform` |
| 缓动 | `ease`（linear/ease*/cubic-bezier 二分/steps） `bezier` |
| 简写拆解 | `tokens` `splitTop` `transitions` `animationParts` |
| 关键帧/选择器 JSON | `matchBrace` `extractBlock` `jsonPairs` `pairKey` `pairVal` `frames` `frameTime` `frameProps` `propGet` `propKeys` |
| 插值 | `interpValue` `interpColor` `interpNum` `interpTransform` `sameValue` `fmtFloat` |

### space style —— 级联求值（节点级）
```
get(node,key,state) / getBase / getD / getI / getF / getSub(node,key,sub,state) / subColor
stateOf(node) / setState(node,name,on) / hasState / stateHas / normalizeKey / setStyle(node,jsonText)
contentRect(node) / borderRect(node) / visible / isClipped / radiusOf / borderStyle / borderColor / isKeyword
globalTo(node,jsonText) / clearGlobal(node) / inherit(child,parent) / applyFontShorthand(node,v)
getThemed(theme,node,key,state)        // 先套用主题再求值
```
级联顺序（§0，从低到高）：**默认层 `__def~` < 全局层 `__g~`(Theme) < 祖先层 `__a~`(inherit) < 自身 < 选择器块 < 状态后缀 < 动画覆盖 `__anim~`**。

### type Theme —— 实例化主题（替代旧的进程级 JSON 文件）
```qk
Theme t = Theme::new();  Theme t2 = Theme::fromJson("{...}");
t.set("color", "#e6edf7");  t.get("color");  t.has("k");  t.aliased("bg");  t.remove("k");  t.clear();
t.size();  t.keys();  t.revision();
t.apply(node);          // 写入节点 "__g~" 层（rev 未变则跳过，可每帧调用）
t.applyAny(anyNode);    // 调用方持有接口类型值（如 ClegNode）时用
t.appliedTo(node);
```
主题是**实例**：两个 Theme 互不影响，也不再读写 `/tmp/*.json`。由调用方持有并传给节点求值。

### type Animator —— 关键帧 + transition（状态在实例内）
```qk
Animator an = Animator::new();
an.define("pulse", "{\"0\":{\"opacity\":\"1\"},\"0.5\":{\"opacity\":\"0.4\"},\"1\":{\"opacity\":\"1\"}}");
an.tick(nodes /* List<StyleNode> */, 16);   // 每帧推进：写入各节点 "__anim~" 覆盖层
an.tickNode(node, 16);  an.hasDef("pulse");
```

## 节点桥接（重要）

QuarkLang 的接口→接口赋值**按名字严格判定**（`ClegNode` ≠ `StyleNode`），而 struct→接口是结构化满足。
因此当调用方持有的是别的接口类型值时，先落到 `interface{}` 再传入：

```qk
interface{} anyNode = clegNode;      // ClegNode → interface{} 合法
style::get(anyNode, "color", "");    // interface{} → StyleNode 形参合法（运行时同一节点值）
```
`List<ClegNode>` → `List<StyleNode>` 也按元素桥接（见 cleg 的 `ClegAnimator::tick`）。

## 与 STYLE-SPEC.md 的关系

STYLE-SPEC.md 定义**键与语义**（唯一权威清单），style.qk 是实现，两者同步维护：
- §0 级联顺序 → `style::get` / `Theme::apply` / `inherit` / `__anim~` 覆盖
- §1 盒模型 → `borderRect` / `contentRect`（所有组件先算 contentRect 再画）
- §6 状态与选择器 → `setState` / `stateOf` / `stateKey` / `specificity` / `selMatches`
- §7 动画 → `qss::ease` / `Animator::progress` / `applyFrames` / `applyTransitions`
- §9 native 契约 → 本库**不碰**：渲染原语属于消费方（cleg 的 `clegfx`/`clegrt`）
- §9.1 语义裁定 → `qss::gradDir` 与本库的文本锚点传参约定（见规范 §9.1 新增行）

## 明确不在本库内（消费方职责）

| 能力 | 归属 |
|---|---|
| native 绘制原语（blend/gradient/border/shadow/text_ex/image/transform/clip） | cleg `clegfx` + `libclegrt.so` |
| 组件渲染配方（label/button/field/progress/slider/indicator/列表网格…） | cleg `space clegstyle` |
| 47 个组件与事件/布局/信号 | cleg |
| 具体节点类型（ClegNode / ClegButton …） | cleg |

## 运行

```bash
QUARK=/tmp/quark ./tests/run.sh        # failures=0
QUARK=/tmp/quark ./examples/run.sh     # 数值示例
cd /path/to/QuarkLangLibs-Style && "$QUARK" style.qk   # 库 parse+typecheck（只报 cannot run a library）
```
