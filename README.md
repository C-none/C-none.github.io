---
title: "local preview and development"
icon: user 
permalink: "/usage/"
layout: page
---

## Environment

This repository uses a standalone Jekyll build and deploys the generated `_site` artifact to GitHub Pages. It does not use the legacy `github-pages` gem runtime.

| Component | Version | Source of truth |
| --- | --- | --- |
| Ruby | `4.0.6` | `.ruby-version`, `Gemfile`, and `Gemfile.lock` |
| RubyGems | `4.0.19` | local setup and GitHub Actions workflow |
| Bundler | `4.0.19` | `Gemfile.lock` and GitHub Actions workflow |
| Jekyll | `4.4.1` | `Gemfile` and `Gemfile.lock` |
| Jekyll Feed | `0.17.0` | `Gemfile` and `Gemfile.lock` |
| WEBrick | `1.9.2` | `Gemfile` and `Gemfile.lock` |

`Gemfile.lock` contains both the Windows (`x64-mingw-ucrt`) and GitHub Actions (`x86_64-linux`) platforms. Keep it committed so local and deployed builds use the same dependency set. Do not run `bundle update` as part of a normal build; update the lockfile only when intentionally upgrading dependencies.

## Configure Windows development environment

The commands below assume [Scoop](https://scoop.sh/) is installed.

### 1. Install Ruby and the native build toolchain

```powershell
scoop update
scoop install ruby msys2
scoop reset ruby
ridk install 3
```

If Scoop reports that an app is already installed, update it instead. Open a new terminal after installation if `ruby` still resolves to an older version.

### 2. Pin RubyGems and Bundler

```powershell
gem update --system 4.0.19
gem install bundler --version 4.0.19 --no-document
```

Verify the active environment before installing project dependencies:

```powershell
ruby --version
gem --version
bundle --version
```

Expected versions:

```text
ruby 4.0.6
4.0.19
4.0.19
```

### 3. Install locked project dependencies

Run this command from the repository root:

```powershell
bundle install
bundle check
```

## Build and run locally

Build the static site:

```powershell
bundle exec jekyll build
```

Start the local development server:

```powershell
bundle exec jekyll serve --host 127.0.0.1 --port 4000
```

Open http://127.0.0.1:4000/ in a browser. Jekyll watches source files and rebuilds automatically; refresh the browser to see changes. Press `Ctrl+C` in the server terminal to stop it. The Windows polling notice is informational and does not prevent local development.

Before deployment, run a production build:

```powershell
$env:JEKYLL_ENV = "production"
bundle exec jekyll build
```

The generated files are written to `_site`. Do not commit that directory.

## Deploy to GitHub Pages

Deployment is handled by `.github/workflows/jekyll.yml`. The workflow reads Ruby `4.0.6` from `.ruby-version`, installs RubyGems and Bundler `4.0.19`, installs the locked gems, builds with `JEKYLL_ENV=production`, uploads `_site`, and deploys it through the `github-pages` environment.

### One-time repository configuration

1. Open the repository on GitHub and go to **Settings → Pages**.
2. Under **Build and deployment**, set **Source** to **GitHub Actions**.
3. Ensure GitHub Actions is enabled for the repository. The first deployment creates the `github-pages` environment automatically.

See GitHub's documentation for [configuring the publishing source](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site) and [using a custom Pages workflow](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

### Automatic deployment

After the production build succeeds, commit all source and lockfile changes and push them to `master`:

```powershell
git status
git add --all
git commit -m "Update site"
git push origin master
```

A push to `master` starts the **Deploy Jekyll site to Pages** workflow. Follow its progress from the repository's **Actions** tab. When the deploy job succeeds, its environment URL points to the published site at https://c-none.github.io/.

### Manual deployment

The same workflow can be started without a new commit:

1. Open **Actions → Deploy Jekyll site to Pages**.
2. Select **Run workflow**.
3. Choose `master` and confirm the run.

Manual and automatic deployments use the same locked environment and build steps. Never commit `_site` or publish it through a separate branch.

### Deployment troubleshooting

- If dependency installation fails, run `bundle check`, then `bundle install`, and commit any intentional `Gemfile.lock` change.
- If no Pages deployment starts, confirm **Settings → Pages → Source** is set to **GitHub Actions**.
- If the build succeeds but deployment fails, inspect both the `build` and `deploy` jobs in the workflow run; the workflow requires `pages: write` and `id-token: write` permissions.
