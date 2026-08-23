# 双语简历

本目录由一份双语 JSON 数据生成中英文 PDF 简历，并复用同一套 LaTeX 版式。

`resume.json` 是简历内容的唯一真值。请只在其中维护履历内容；PowerShell 构建脚本负责校验数据、渲染 LaTeX 并生成 PDF。`legacy/` 中的手写 TeX 仅供历史参考，不再作为发布来源。

## 构建前提

- PowerShell 7.5 或更高版本：使用 `pwsh`，不支持 Windows PowerShell 5.1。
- 可用的 `xelatex`，以及包含 CTeX 和 Fandol 字体的 TeX 发行版，例如完整安装的 TeX Live 或已配置的 MiKTeX。
- 可用的 `pdfinfo` 和 `pdftotext`，用于页数、纸张大小和文本提取验收；可由 Poppler 或 TeX 发行版提供。中文文本验收还需要相应的 CJK 映射数据。

简历构建仅使用 PowerShell 标准能力，不需要额外模块；网站构建环境与本目录彼此独立。

如需指定工具，可分别设置 `XELATEX`、`PDFINFO`、`PDFTOTEXT` 为单个可执行文件路径。未设置时，`pdfinfo` 和 `pdftotext` 会优先使用 Scoop 的 Poppler，随后才从 `PATH` 查找。

## 命令

在仓库根目录运行：

```powershell
# 校验并构建两种语言（默认）
pwsh -NoProfile -File assets/ChineseCV/build.ps1

# 显式构建全部、中文或英文版本
pwsh -NoProfile -File assets/ChineseCV/build.ps1 -Language all
pwsh -NoProfile -File assets/ChineseCV/build.ps1 -Language zh
pwsh -NoProfile -File assets/ChineseCV/build.ps1 -Language en

# 只校验 resume.json，不调用 XeLaTeX，也不改动发布 PDF
pwsh -NoProfile -File assets/ChineseCV/build.ps1 -ValidateOnly

# 运行不依赖 XeLaTeX/Poppler 的数据与模板测试
pwsh -NoProfile -File assets/ChineseCV/test_build.ps1

# 追加真实的 XeLaTeX、PDF、原子发布、失败保护和清理测试
pwsh -NoProfile -File assets/ChineseCV/test_build.ps1 -Integration

# 仅删除临时构建目录
pwsh -NoProfile -File assets/ChineseCV/build.ps1 -Clean
```

如果 Windows 将从网络下载的脚本标记为不受信任，请先对该文件执行 `Unblock-File assets/ChineseCV/build.ps1`，再使用上述命令。不要用 `powershell.exe` 替代 `pwsh`。

## 内容与输出

- `resume.json`：唯一的双语内容源。自然语言字段同时包含 `zh` 与 `en`；ID、日期、URL 和技术名等事实只保存一次。
- `build.ps1`：PowerShell 构建入口；模板和内部支持代码由它调用，不要编辑 `.build/` 中生成的 TeX 文件。
- `test_build.ps1`：不依赖 Pester；默认运行数据与模板测试，`-Integration` 追加真实 PDF 与失败保护测试。
- `lhzy_resume_zh.pdf`、`lhzy_resume_en.pdf`：提交到仓库、由网站直接引用的发布产物。
- `.build/`：按语言保存生成的 TeX、XeLaTeX 日志和辅助文件；已被 Git 忽略。

构建会校验双语字段、唯一 ID、日期、联系方式、空 bullet 和原始 LaTeX。每种语言均经两次 XeLaTeX 编译后，再检查 A4 单页、缺字、越界文本和可提取的关键文本。只有所有检查通过，候选 PDF 才会替换对应的发布 PDF；校验、编译或验收失败时，现有发布 PDF 会被保留。

`-Clean` 只删除 `assets/ChineseCV/.build/`，不会删除 `lhzy_resume_zh.pdf`、`lhzy_resume_en.pdf` 或任何历史源文件。

## 版式来源

页面布局基于 [billryan/resume](https://github.com/billryan/resume) 修改而来；相关许可证见 `LICENSE`。
