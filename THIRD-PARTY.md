# 第三方来源与素材

## 随包字体

- 字体：LXGW WenKai Lite Regular（霞鹜文楷轻便版）。
- 来源：[lxgw/LxgwWenKai-Lite](https://github.com/lxgw/LxgwWenKai-Lite)。
- 固定提交：`f87f49eb22d8c87d48982c2a19414e21a0b3ce0b`。
- 原始路径：`fonts/TTF/LXGWWenKaiLite-Regular.ttf`；文件未经修改。
- SHA-256：`f799a538a3355877e597a0ae04050e897932c9ae7689eb9227c2953c5dd549ea`。
- 许可：SIL Open Font License 1.1，原版权及附加说明随 [OFL.txt](addon/WoWFeTranslator/Fonts/OFL.txt) 完整保留。
- 字体文件约 13.3 MiB，是当前测试包大小的主要来源；这不是插件 Lua 内存占用的测量值。

## 首批词条

`data/sources/items.json` 收录 WoW Forever 客户端构建 `1.60.1.71037` 数据表 ItemSparse 中的官方英文与简体中文物品名称（17,495 条），由 wago.tools 从暴雪 CDN 导出的 CSV 生成，构建号与 CSV 的 SHA-256 记录在文件的来源清单中。这些名称是暴雪娱乐的游戏文本，仅用于在游戏内显示译文，权利属于暴雪娱乐。本包未复制其他翻译插件的代码或词库文件。

`tests/fixtures/sample-items.json` 是手工整理的 13 个物品名称和合成的术语、正文样例，只用于测试数据契约，不随安装包分发。

## 接口研究参考

- [Blizzard UI 源码镜像中的提示框处理器](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua)。镜像分支会变化，不能替代目标 Forever 客户端测试。
- [Blizzard API 文档源文件：AddOns](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua)。
- [WoWeuCN Forever](https://bitbucket.org/tensorreading/forever-chinese/src/main/)，本轮阅读提交 `eaed5675659eef0635c5497ce9a1aab4c527b973` 的提示框接口使用方式；未将其代码加入本项目。

本项目代码许可证仍待选定；字体许可不决定项目代码许可证。
