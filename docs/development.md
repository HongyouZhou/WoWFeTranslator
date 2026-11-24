# 核心开发与本地验证

当前版本 `0.1.0-alpha.1`。Python 仅用于离线构建，游戏端只分发 Lua、TOC、字体和说明文件；没有外部进程、网络请求或 Python 调用。

## 工具与命令

开发环境需要 Python 3.10+ 标准库、Lua 5.1 的 `lua5.1` / `luac5.1`。不需要安装 Python 第三方依赖。Lua 5.1 语法及接口替身测试是兼容基线，不证明实际 Forever API 可用。

在仓库根目录运行：

```sh
python3 tools/build.py
python3 -m unittest discover -s tests -v
lua5.1 tests/runtime.lua
python3 tools/forever_api.py
python3 tools/check.py
python3 tools/build.py --package
```

`tools/check.py` 汇总数据一致性、所有 Lua 文件语法、Forever 缺失的旧全局函数、Python 与 Lua 行为测试，并检查生成包结构及重复打包一致性。

`tools/forever_api.py` 检查插件 Lua 中直接调用的旧全局函数（如 `GetItemInfo`、`LoadAddOn`、`GetSpellInfo`）。Forever 使用 12.1 引擎，不加载正式服保留这些函数的兼容插件，直接调用会报错，应改用 `C_Item`、`C_AddOns`、`C_Spell` 等命名空间接口。同一行内的判断（`X and X()`、`if X then`、`type(X)`）和作为备用值的读取（`C_AddOns.LoadAddOn or LoadAddOn`）允许通过；其他确认安全的情况可在该行加 `-- forever-api-ok: 原因`。检查按行进行，看不到前几行的判断。遇到缺少工具或测试失败会以非零状态退出。`--package` 单独运行会校验数据和字体，但不会替代完整测试。

输出 ZIP 位于 `dist/`，包含两个直接可安装的插件目录，附 `.zip.sha256`；该目录不纳入 Git。测试 ZIP 不包含 Python、测试样例正文或开发工具。数据包的生成 Lua 文件纳入版本控制，用生成器更新，不手工编辑。

## 当前模块边界

- `Core.lua`：账号设置、样式值校验、有效模式与刷新代数。
- `Repository.lua`：按需加载数据插件、格式检查、按实体类型／数字 ID／语言查找；首版直接表查询，无额外名称缓存。
- `Tooltips.lua`：只接入 GameTooltip 与 ItemRefTooltip，兼顾可用的物品 post-call 和旧脚本回调；同帧合并，重新读取当前物品。`SetOwner` 和隐藏视为新的提示框，立即清除显示并使旧回调失效；`OnTooltipCleared` 视为同一提示框刷新内容，只使旧回调失效，保留显示并在下一帧重新核对。判断是否显示使用 `IsVisible()`；物品 ID 优先取物品回调数据中的 `id`，其次取 `GetItem` 的第三个返回值，最后解析链接。
- `Fonts.lua`：客户端支持 `CreateFontFamily` 时，按“英文字体 + 字号”建立字体族：拉丁字母用用户选择的英文字体，简体和繁体中文字母表用随包字体，其他字母表用客户端默认字体；每个组合只创建一次。不支持字体族时，英文列用英文字体，中文列用随包字体。字体路径在首次使用时用隐藏的 FontString 检测一次，无法加载时依次回退到随包字体和客户端标准字体，并在报告中提示。
- `Presenter.lua`：拥有自己的双语卡片，不改写原版标题、属性或按钮；每个支持的提示框最多一个卡片。
- `UI.lua`：界面开关、三个模式、字号、颜色、自定义字体、两个悬停样例与诊断报告。
- `Diagnostics.lua`：默认关闭，有界采样；只在显式报告动作中排序和查询内存。
- `Init.lua`：账号设置与登录生命周期，脱战刷新。

没有全局 SetText 钩子、全界面扫描或常驻 OnUpdate。排队任务只在有效功能开启时创建。样式变化只刷新显示；数据包不会因为换颜色重新加载。内存中的两个显示状态有固定上界，按需加载后的词库本版不卸载。

## 数据契约 v1

`data/sources/sample-items.json` 是当前安装包的数据入口。包级包含 `schemaVersion`、`game`、`interface`、来源清单、实体、术语及正文数组。生成器以规范化 JSON 的 SHA-256 作为整包 `dataRevision`。

实体具有 `type`、数字 `id`、多语言 `names` 和 `source`；生成后按类型和数字 ID 建表。术语具有与语言无关的 `key`、多语言名称／别名、来源，以及可选实体引用。

正文契约已经由合成样例测试，但尚未接入游戏 UI：每种语言保存有稳定 ID 的片段，每个片段由字面文本、`{variable: "player"}` 或 `{term: "稳定键", text: "原文"}` 组成。对齐行引用各语言片段 ID，支持一句对多句；没有可靠对齐时保留空对齐数组。没有字符偏移，避免 UTF-8 字节与字符坐标混淆。

正文的 `contentFingerprint` 绑定完整多语言片段内容，编辑后必须核对标注再更新指纹。校验器检查来源、重复 ID、术语与实体引用、跨语言占位符数量、对齐覆盖和指纹；未知正文片段形状拒绝生成。游戏链接／颜色等标记当前只能作为原样字面片段保留，不支持在它们内部标注术语。后续正式导入时需要补充标记解析与保护验证。

用于验证正文、术语和变量的合成样例在 `tests/test_build.py` 中，不当作真实游戏剧情分发。正式第三方词库导入尚未完成；当前 13 条数据仅用于安装和核心链路测试，详情见[来源说明](../THIRD-PARTY.md)。

## 验证边界

接口替身可以验证关闭、失效、回退、设置、加载次数和统计容量；不能验证游戏安全状态、真实 Hook 行为、字体引擎、物品缓存和屏幕布局。必须按 [Windows 测试指南](windows-testing.md) 补充游戏内结果。

`lua5.1 benchmarks/runtime.lua` 给出开发机上的固定负载结果。这里运行的是替身 UI 与标准 Lua；只能定位逻辑回归，不能作为游戏毫秒预算。真实首次／重复查询、内存和关闭状态开销由游戏内报告记录。
