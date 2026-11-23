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

`data/sources/sample-items.json` 是手工整理的 13 个常见物品名称，用于工程验证；不是现有插件词库的批量导入，也不是已核验的完整 Forever 数据集。游戏名称与实体标识的权利属于各自权利人。

既定方向仍是参考现有插件准备首批正式数据。当前先用小样例完成开发与安装闭环；后续导入须固定来源、核对许可和游戏版本，再单独记录来源。本包未复制其他翻译插件的代码或词库文件。

## 接口研究参考

- [Blizzard UI 源码镜像中的提示框处理器](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua)。镜像分支会变化，不能替代目标 Forever 客户端测试。
- [Blizzard API 文档源文件：AddOns](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua)。
- [WoWeuCN Forever](https://bitbucket.org/tensorreading/forever-chinese/src/main/)，本轮阅读提交 `eaed5675659eef0635c5497ce9a1aab4c527b973` 的提示框接口使用方式；未将其代码加入本项目。

本项目代码许可证仍待选定；字体许可不决定项目代码许可证。
