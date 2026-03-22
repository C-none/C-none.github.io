---
title: "local preview and development"
icon: user 
permalink: "/usage/"
layout: page
---

## GitHub Pages compatibility baseline

This repository is pinned to the GitHub Pages runtime by using the `github-pages` gem.

Current baseline:

- `github-pages` `~> 232`
- `jekyll` `3.10.0` (resolved via `github-pages`)
- `jekyll-feed` `0.17.0` (resolved via `github-pages`)
- `ruby` `3.3.x` for local development

Version sources:

- https://pages.github.com/versions/
- https://github.com/github/pages-gem

## Local preview on Windows (Scoop)

### 1. Install prerequisites

```powershell
scoop install ruby33 msys2
```

Then run MSYS2 toolchain setup once:

```powershell
ridk install
```

### 2. Install project gems

```powershell
bundle install
```

### 3. Build the site

```powershell
bundle exec jekyll build
```

### 4. Serve locally

```powershell
bundle exec jekyll serve --host 127.0.0.1 --port 4000
```

Open http://127.0.0.1:4000/ in your browser.

## Notes

- A local warning about missing GitHub API authentication in `jekyll-github-metadata` is expected.
- If watch mode feels slow on Windows, you can optionally add `gem "wdm", ">= 0.1.0"` to improve file watching.
- To print the currently resolved GitHub Pages dependency set, run `bundle exec github-pages versions`.
