# 双语简历

本目录使用一份双语 YAML 数据生成中英文 PDF 简历，并复用同一套 LaTeX 版式。

`resume.yml` 是简历内容的唯一真值。请只在其中更新履历内容；`resume.tex.erb` 和 `build.rb` 负责把数据渲染、校验并编译为 PDF。旧的手写 TeX 文件已归档到 `legacy/`，仅供历史参考，不再作为发布来源。

## 构建前提

- Ruby 3.1 或更高版本（仅使用标准库的 YAML 和 ERB）
- 可用的 `xelatex`，以及包含 CTeX 和 Fandol 字体的 TeX 发行版（如完整安装的 TeX Live 或已配置的 MiKTeX）
- Poppler 的 `pdfinfo` 与 `pdftotext`；中文文本验收还需要 `poppler-data` 中的 CJK 映射数据

## 构建

在仓库根目录运行：

```powershell
ruby assets/ChineseCV/build.rb
ruby assets/ChineseCV/build.rb --lang all
ruby assets/ChineseCV/build.rb --lang zh
ruby assets/ChineseCV/build.rb --lang en
ruby assets/ChineseCV/build.rb --validate-only
ruby assets/ChineseCV/test_build.rb
```

默认命令生成中英文两份简历；`test_build.rb` 覆盖缺失翻译、重复 ID、非法日期、空 bullet 和非零退出状态。若本机已安装 `make`，也可以把 Makefile 当作便捷包装器：

```powershell
make -C assets/ChineseCV
make -C assets/ChineseCV zh
make -C assets/ChineseCV en
make -C assets/ChineseCV validate
make -C assets/ChineseCV clean
```

`clean` 只删除临时构建目录 `.build/`，不会删除任何发布 PDF。

## 文件与输出

- `resume.yml`：唯一的双语内容源；自然语言内容包含 `zh` 和 `en` 两种版本。
- `resume.tex.erb`：共用的 LaTeX/ERB 模板。
- `build.rb`：数据校验和 XeLaTeX 构建入口。
- `lhzy_resume_zh.pdf`、`lhzy_resume_en.pdf`：提交到仓库、由网站直接引用的发布产物。
- `.build/`：生成的 TeX、日志和 XeLaTeX 辅助文件；已被 Git 忽略。

构建在成功生成单页 PDF 后才会替换发布产物；校验或编译失败时，已有 PDF 会被保留。

## 版式来源

页面布局基于 [billryan/resume](https://github.com/billryan/resume) 修改而来；相关许可证见 `LICENSE`。
