# PCV · 便携代码图形化工作台

**Portable Code Visual Workbench** —— 在手机上开发、理解与更新 LINGOS 源码的独立工作台。

> 本 App 是**独立产品**：不运行在 LINGOS 上、不依赖 LINGOS 设备。
> 内置最新 LINGOS 源代码，离线即可开发；需要部署时再连接设备。

## 是什么

| 项 | 说明 |
|---|---|
| **形态** | 独立 Android App（Flutter 壳 + WebView 编辑器内核） |
| **工作对象** | **原代码源码树**——与正常开发一致（C 需编译；Python/WebUI 等解释型免编译） |
| **内置代码** | 最新 LINGOS 源码打包内置（离线开发，随 App 更新） |
| **三大能力** | 搜索 → 检查 → 理解（找到功能在哪、怎么写、往哪加） |
| **便利原则** | 零配置启动 · 少操作到底 · 即时看得到（第一设计原则） |

## 已实现（v0.2.0）

- ✅ **内置源码**：588 个文件（LINGOS v0.7.2）打包内置，首启解压到沙盒
- ✅ **多项目**：默认内置 LINGOS 项目 + 用户自建项目（新建/切换/删除）
- ✅ **文件管理**：新建文件 · 新建文件夹 · 重命名 · 删除（长按菜单）
- ✅ **代码编辑器**：CodeMirror 6 成熟内核（高亮/折叠/括号匹配/搜索/多光标）
  - 支持 10+ 语言：C/C++、Python、JS/TS、HTML/CSS、JSON、Markdown、YAML…
- ✅ **保存机制**：点「保存」直接写回源文件；草稿仅作防丢失缓冲；退出时询问
- ✅ **语法检查**：实时 lint（解析错误波浪线 + 行号标记 + JSON 完整性）
- ✅ **双拇指手势**：双指捏合调字号 · 双指横滑缩进/反缩进
- ✅ **AI 助手（双模式）**：
  - **帮助模式（只读）**：AI 只解释/总结代码——轻量模型即可
  - **编写模式（读改）**：AI 读代码并建议修改，代码块一键写入
  - 支持任意 OpenAI 兼容服务；上下文文件可附加
- ✅ **移动端优化**：触摸滚动、软键盘适配、行号、光标行列
- ✅ **全局搜索**：文件名 / 内容 / 全部（结果点击直达行）
- ✅ **外观**：深/亮双主题 · 5 种强调色 · 字号调节 · JetBrains Mono

## 技术栈（复用成熟生态——不造轮子）

| 层 | 选型 |
|---|---|
| App 壳 | Flutter（Android 优先） |
| 编辑器内核 | **CodeMirror 6**（VS Code 级编辑器框架，MIT） |
| 语法检查 | **@codemirror/lint**（官方生态） |
| WebView 桥 | **webview_flutter**（Flutter 官方插件） |
| 代码字体 | JetBrains Mono（开源 OFL） |
| AI 客户端 | dart:io（OpenAI 兼容协议——零第三方依赖） |
| 本地引擎 | Dart（解压/搜索）+ CM6（高亮/折叠/检查/手势） |

## 规划（后续批次）

- **A4 构建与部署**：C 编译构建 · 连接设备 · diff · 推送 · 备份回滚 · GitHub CI 部署
- **A5 AI 增强**：AI 直接编辑编辑器缓冲 · 多文件上下文 · 部署能力接入

## 目录结构

```
lib/                 Dart 源码（四屏 + 编辑器）
  main.dart          入口
  theme.dart         设计令牌（双主题 + 强调色 + 语法配色）
  services.dart      设置 / 工作区 / 搜索
  widgets.dart       公共组件
  editor_screen.dart 编辑器（WebView + CM6 桥）
  screens/           首页 / 文件 / 搜索 / 设置
webview/             CM6 内核源码 + 构建脚本（editor.html 产物入库）
tools/               打包器（内置源码 PAK）/ 图标生成
assets/              内置源码包 / 编辑器单文件 / 字体
android/             Android 工程
```

## 构建

```bash
# App 构建
flutter pub get
flutter build apk --release --split-per-abi

# 编辑器内核重新构建（可选——产物已入库）
cd webview && npm install && python3 build_editor.py

# 内置源码包重新打包（可选）
python3 tools/pack_source.py <LINGOS源码目录> assets/source/lingos-source-v<版本>.pak.gz \
  --name lingos-source --commit <SHA>
```

## 设计原则

1. **复用优先**：通用能力用成熟开源生态（CodeMirror/JetBrains Mono/tree-sitter…）
2. **只造自己的轮子**：PCV 只开发产品特性（工作区/桥接/部署链/界面）
3. **便利第一**：每个功能先问"开发者少操作了吗、看得见吗、丢不了吗"
4. **诚实**：能力边界标注清楚（如"检查等级：解析级/精确级"）

---
*PCV · 2026-09-25 · 独立 App 架构 · 内置源码 · 便利第一*
