# Windows 内部测试指南

适用安装包：`WoWFeTranslator-0.2.0-alpha.1.zip`。这是 13 个物品名称的核心验证版，还没有任务翻译、NPC／技能翻译或术语注释界面。相对 `0.1.0-alpha.1` 的变化：提示框刷新时译文不再闪烁，EllesmereUI 隐藏提示框时不做处理，中文通过字体族始终使用随包字体（设置中的字体改为“英文字体”），报告增加 `owner_set`、`content_cleared` 计数、`render=` 字体模式和 `C_AddOnProfiler` 指标。本轮重点验证这些变化，并在原版界面与 EllesmereUI 下各测一遍。开发环境测试与游戏内验收分开记录；当前游戏内结果待测。

## 1. 通过 Git 同步或传输安装包

### 通过 Git 同步

Windows 安装 Git 后，在准备保存源码的位置打开 PowerShell，首次运行：

```powershell
git clone https://github.com/HongyouZhou/WoWFeTranslator.git
cd WoWFeTranslator
```

也可以使用已配置 SSH 密钥的地址 `git@github.com:HongyouZhou/WoWFeTranslator.git`。私有仓库需要使用有访问权限的 GitHub 账号认证。

仓库的 `addon` 目录已经包含可安装的 Lua 文件、生成词库和字体，不需要在 Windows 安装 Python 或运行构建。退出游戏后，把以下两个目录复制到下一节确认的 `Interface\AddOns` 中：

```text
addon\WoWFeTranslator
addon\WoWFeTranslator_Data_Items
```

以后在 Windows 的仓库目录中运行：

```powershell
git pull --ff-only
```

然后退出游戏，备份并替换游戏目录中这两个插件文件夹，再启动游戏。只执行 `git pull` 不会自动更新已经复制到游戏目录的文件。不要把整个 Git 仓库放进 AddOns；本机账号设置仍由游戏保存，不纳入 Git。遇到本地修改导致 pull 拒绝时先保留修改，不要直接强制覆盖。

### 用目录联接代替复制（可选）

在 `AddOns` 中为两个插件目录创建指向仓库的目录联接（junction），以后 `git pull --ff-only` 后不再需要复制，`/reload` 即可加载新的 Lua 文件；TOC 有变化时（例如新增文件）需要完全重启游戏。目录联接不需要管理员权限，只能指向本机磁盘上的目录。

退出游戏后，在 PowerShell 中按实际位置修改前两行再运行。Forever 实例的位置以第 2 节确认的结果为准：

```powershell
$Repo   = "C:\Users\你的用户名\source\WoWFeTranslator"
$AddOns = "D:\Games\World of Warcraft\_forever_\Interface\AddOns"
foreach ($name in "WoWFeTranslator", "WoWFeTranslator_Data_Items") {
    $link = Join-Path $AddOns $name
    # 已有的复制版先改名备份；同名备份已存在时这一步会报错，请先处理旧备份。
    if (Test-Path $link) { Rename-Item $link "$name.bak" }
    New-Item -ItemType Junction -Path $link -Target (Join-Path $Repo "addon\$name") | Out-Null
}
Get-Item (Join-Path $AddOns "WoWFeTranslator*") | Select-Object Name, LinkType, Target
```

最后一条命令应列出两个 `LinkType` 为 `Junction` 的目录，`Target` 指向仓库的 `addon` 子目录。确认插件正常后，再删除 `.bak` 备份目录。

注意：

- 删除联接请用 `cmd /c rmdir "<AddOns 路径>\WoWFeTranslator"`，它只删除联接本身。不要用 `Remove-Item -Recurse` 或其他递归删除命令，可能连仓库里的文件一起删掉。
- 游戏运行时执行 `git pull` 不会立即生效，需要 `/reload`；拉取前最好先退出游戏或至少不在战斗中。
- 不要把整个仓库联接或复制到 `AddOns`，只联接这两个目录。

### 传输 ZIP

开发机的文件是 `dist/WoWFeTranslator-0.2.0-alpha.1.zip`。通过你现有的文件传输方式、共享文件夹或 U 盘复制到 Windows；Windows 端无需 Git、Python 或 Lua 解释器。不必将开发仓库整个复制过去。

仓库尚未发布 CurseForge 项目，也没有自动更新或 GitHub Release。不要在 CurseForge 搜索此名称作为安装前提；继续用 CurseForge 管理其他插件，本测试包手动安装。

## 2. 找准游戏目录并安装

1. 完全退出 WoW。
2. 在 CurseForge 中选择你实际玩的 **Forever 游戏实例**，通过该实例的菜单或设置找到游戏安装目录。也可从战网打开该版本游戏的位置。不要仅凭 `_retail_`、`_classic_` 等目录名猜测。
3. 进入这个实例的 `Interface\AddOns`。这里应能看到你通过 CurseForge 安装、并且游戏中确实在使用的其他插件目录。CurseForge 的[官方故障排查说明](https://support.curseforge.com/support/solutions/articles/9000198422-world-of-warcraft-addons-faq-and-troubleshooting)说明了不同游戏目录与插件识别问题。
4. 将 ZIP 中的两个插件目录，或 Git 仓库 `addon` 下的两个目录，直接复制到 `AddOns`，得到以下结构。不要把 ZIP、仓库根目录或额外嵌套的同名文件夹当作插件目录。

```text
<实际 Forever 实例>\Interface\AddOns\
  WoWFeTranslator\
    WoWFeTranslator.toc
    Core.lua
    ...
    Fonts\
      LXGWWenKaiLite-Regular.ttf
      OFL.txt
  WoWFeTranslator_Data_Items\
    WoWFeTranslator_Data_Items.toc
    Data.lua
```

5. 启动游戏，在角色选择界面的插件列表中启用这两个插件。数据包是按需加载，登录时尚未加载是预期行为。
6. 第一轮测试暂时关闭其他翻译插件和改变提示框的插件，建立原版界面的基线；确认本插件正常后再逐步恢复其他插件。

当前 TOC 的接口号为 `16001`，来自此前提供的客户端快照。如果被标为过期，先记录当前版本和提示；可通过游戏自身的“加载过期插件”选项试测，但这不证明兼容。不要为了消除提示随意修改接口号。若出现“依赖缺失”，检查第二个目录和两项启用状态。

可选：用 Windows PowerShell 的 `Get-FileHash -Algorithm SHA256 .\WoWFeTranslator-0.2.0-alpha.1.zip` 与旁边的 `.zip.sha256` 文件比较，确认传输完整。

## 3. 五分钟功能检查

登录英文客户端后，屏幕上方应有 **WFT: ON** 按钮。点击打开设置窗口，按钮可拖动；本版按钮位置不持久保存。设置界面暂用英文，避免将界面本地化与翻译功能混在第一轮验收中。

| 操作 | 预期结果 |
| --- | --- |
| 悬停 `Hover: Hearthstone` | 提示框标题行左边是英文 “Hearthstone”，右边是中文“炉石”，颜色与英文标题相同（默认 `In tooltip`、`Style: native`） |
| 悬停 `Hover: no translation` | 显示原版物品提示，没有中文卡片，也不残留上一件物品的译文 |
| 反复在两个按钮之间移动 | 不重复叠加、不串词、不累积卡片 |
| 点击 `Translation: OFF` | 已显示的翻译清除；后续悬停不再翻译 |
| 重新开启后点击 `pvp` | 总开关仍为 ON，但有效翻译关闭，顶部显示 WFT: OFF |
| 切到 `story` 或 `minimal` | 名称翻译恢复；这两个模式在当前小版本效果相同 |
| 点 `Style: native` 切换为 `Style: custom`，再用 `-` / `+` 改字号 | 中文改用随包字体和设置的字号（范围 10–30）；切回 `Style: native` 后恢复与提示框一致 |
| 在 `Style: custom` 下输入六位颜色，如 `00FF88`，点击旁边的 Apply | 中文颜色改变；英文保持原色 |
| 切换模式再切回 | 字号、颜色等个人设置保留 |
| 点击 `Items: ON` 关闭物品模块 | 显示 `Items: OFF`，已显示的译文清除，悬停不再翻译；再点一次恢复，字号、颜色、模式不变 |
| 物品模块开着时切到 `pvp` | 按钮显示 `Items: paused`（暂停而不是关闭）；切回后恢复 `Items: ON` |
| 查看 `Spells`、`NPCs`、`Quests` 按钮 | 显示 `n/a`，不可点击 |
| 关闭原版物品提示 | 附属卡片同步隐藏 |
| 鼠标停在背包中的炉石上 10 秒 | 中文持续显示，不闪烁 |
| 点 `In tooltip` 切换为 `Separate card` | 中文改为显示在提示框下方的独立卡片中（卡片总是使用设置的字体与颜色）；再点一次切回 |

默认把中文写进原版提示框：标题行右侧有空位时写在右侧，被其他内容占用时在提示框末尾追加一行。可选的独立卡片放在原版提示框下方，靠近屏幕底部时尝试放到上方，卡片内部是左右双栏，不改写原版内容。两者都不是后续的任务逐句阅读器。

再测试背包中的炉石、亚麻布等样例，以及聊天中的已知物品链接：鼠标悬停使用 GameTooltip，点击物品链接使用 ItemRefTooltip。比较装备专用提示框等其他界面暂不支持。首次物品信息未缓存时，等原版信息出现后重新悬停。

英文字体：中文始终使用随包字体，设置里只能更换英文部分的字体，字体文件不需要包含中文字形。将你有权使用的字体放进此插件的 Fonts 目录，输入游戏内相对路径，例如 `Interface\AddOns\WoWFeTranslator\Fonts\MyFont.ttf`，点击 `Apply English font`。新放入字体后完全重启游戏再测试。路径无法加载时，英文会回退到随包字体，报告中出现 `English font failed to load`。

字体检查：换成一种只有拉丁字母的英文字体（例如游戏自带的 `Fonts\FRIZQT__.TTF`），卡片中文仍应正常显示，没有方框。报告中 `Font=` 一行末尾的 `render=family` 表示使用了字体族；如果是 `render=plain`，说明客户端不支持字体族，英文和中文分别用各自的字体，请在反馈中注明。

## 4. 设置保存与边界检查

- 改变字号、颜色、模式或总开关，执行游戏原生命令 `/reload`，确认设置保留。
- 在同一 WoW 账号下换角色，再检查设置是否共享。这里的账号共享基于本机游戏 SavedVariables，不是不同电脑之间自动同步。
- 在安全的测试场景检查战斗前后悬停和模式切换。本版首次加载词库若发生在战斗中会延后，脱战后恢复。词库已加载后可继续处理允许读取的提示；受限信息应跳过。
- 快速开关、切换物品、关闭提示，确认旧刷新没有重新显示译文。
- 尝试屏幕四角、不同 UI 缩放和最大字号，检查是否遮挡、超出屏幕或截字。这些布局结果必须在真实客户端确认。

## 5. 性能测试与复制报告

诊断默认关闭，并且不跨重载保持开启。测量时点击 `Diagnostics: ON`，随后可点 `Reset measurements` 清空计数。`Copy report` 会打开可复制的文本框，按 Ctrl+A、Ctrl+C 后粘贴到反馈中。

分别保留三份报告：

1. **首次加载**：先 `/reload`，不要悬停物品，直接打开设置并启用诊断；悬停炉石一次，再复制报告。应看到 `data_load`，它只包含加载数据插件的耗时。字体、控件首次创建等成本在 `process` 内另有影响。
2. **重复悬停**：保持诊断开启，清空计数，在炉石／无翻译按钮之间交替悬停约 50 次。复制报告；这轮不应再次加载数据包。若游戏连续更新同一个可见提示，可看到 `repeat_skipped`；不是每次移出再移入都应该命中它。另做一轮：清空计数后把鼠标停在背包中的炉石上约 10 秒，再复制报告。`content_cleared` 和 `repeat_skipped` 应持续增加，而 `owner_set`、`render`、`lookup` 基本不增加；这用于确认“刷新不经过 SetOwner”的假设，结果与此不符时请附上报告反馈。
3. **关闭／竞技模式**：关闭翻译，清空计数后重复悬停，再复制报告；之后也可对 pvp 单独测一轮。`lookup`、`render`、`process` 不应增加；`disabled_callback` 允许增加，这是常驻钩子的提前返回。此前加载的数据不会立即卸载，内存不回到零是正常现象。

报告字段：

- `callback`：接入回调自身的计时，异步 `process` 时间另列。
- `process`：读取当前物品、查表与显示的总处理时间；首次可包含 `data_load`，不能简单把两者相加。
- `lookup` / `render` 等计数项只关注 `n`，没有耗时采样时 avg/max/p95 为零。
- avg、max 使用本轮累计样本；P95 只用最近最多 256 个样本，单位毫秒。
- memory 是点击报告时查询的插件 Lua 内存，不等于字体纹理或进程总内存；报告动作本身不计入提示框耗时。
- `Engine profiler` 及其后两行是客户端 `C_AddOnProfiler` 对两个插件的计时（毫秒）：recent 为近期平均，session 为本次登录平均，peak 为峰值，encounter 为首领战平均，over1ms／over5ms 为超过 1／5 毫秒的次数。它只在点击报告时读取，与本插件的诊断开关无关。引擎把挂在暴雪框体上的钩子耗时算给暴雪，这些数值可能偏低；判断本插件成本时以上面的自有计时为准。显示 `unavailable` 表示客户端没有这个接口。

### 原版界面与 EllesmereUI 对照

上面三份报告先在只启用本插件的原版界面下完成，再启用 EllesmereUI 重复一遍。两轮保持同一角色、地点、UI 缩放和操作步骤，并记录 EllesmereUI 的版本与启用的模块。EllesmereUI 下额外检查：

- 使用其“隐藏提示框”选项（例如战斗中隐藏）时，看不见的提示框不应让本插件继续增加 `process`、`render` 计数。
- 开启提示框跟随鼠标后，移动到屏幕底部和边缘，检查译文显示的位置。

两轮报告都附带 `Engine profiler` 一节，可与 EllesmereUI 设置面板中显示的 CPU 数值对照。引擎数值可能不包含挂在暴雪框体上的钩子耗时，判断本插件成本时以报告中的自有计时为准。

记录测试机器的 CPU、内存、分辨率、UI 缩放及同时启用的插件。诊断有额外开销，测完应关闭；帧率对比需要在相同位置和条件下进行，不能把主观流畅或模拟测试数据当成游戏性能结论。13 条词库也不能证明大词库性能。

## 6. 遇到问题时

需要 Lua 错误信息时，可使用游戏原生命令：

```text
/console scriptErrors 1
/reload
```

复现后记录第一条错误的完整内容和调用栈；测试结束可用 `/console scriptErrors 0` 关闭。这个设置不是本插件的翻译开关。

| 现象 | 先检查 |
| --- | --- |
| 插件列表找不到 | 游戏实例是否正确、目录是否多嵌套一层、TOC 是否在对应目录根部 |
| 没有 WFT 按钮 | 主插件是否启用、是否有初始化错误 |
| 炉石有原版提示但无中文 | 总开关、模式、两个插件是否启用；报告中的 Hooks、Data 和客户端信息 |
| `load failed: DISABLED` 或其他加载错误 | 启用或修复数据包后 `/reload`；失败不会在每次悬停无限重试 |
| 中文方框或乱码 | Fonts 文件是否齐全；报告中是否有 `Bundled font failed to load`，以及 `render=` 的值 |
| 大多数物品没有翻译 | 此包只有 13 条，这是预期覆盖范围 |
| 报告 `deferred in combat` | 脱战后重新悬停；若仍不恢复，反馈报告 |

反馈时可以直接使用：

```text
安装包版本：
客户端版本（报告内）：
测试角色/场景（不需要账号名）：
CPU / 内存 / 分辨率 / UI 缩放：
其他启用插件：
复现步骤：
期望 / 实际：
第一条 Lua 错误及调用栈（如有）：
诊断报告：
```

不需要提供整个 WTF 目录或账号信息。截图有助于定位布局问题，报告文本更适合分析计时和加载错误。

## 7. 更新、回退与卸载

关闭游戏，备份这两个插件目录，然后用新安装包替换它们。自行加入的字体另行备份。用户设置存储在游戏实例的 `WTF\Account\<账号目录>\SavedVariables\WoWFeTranslator.lua`，通常不需要修改。

回退时恢复上一个包的两个目录；如果设置来自未来格式，本版使用临时默认值并保留原设置，报告会提示。例如本版把设置升级为格式 v2 后再回退到 `0.2.0-alpha.1`，旧版会使用临时默认值，不改动已保存的设置。需要重置本插件设置时，退出游戏后先备份，再移走该插件专属的 `WoWFeTranslator.lua` 和 `.lua.bak`；不要删除整个 WTF 目录。

卸载只需在退出游戏后移走这两个插件目录。手动安装的测试版不会自动获得 CurseForge 更新。
