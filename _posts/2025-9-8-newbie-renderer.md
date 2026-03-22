---
title:  "Newbie-Renderer"
category: post
layout: post
excerpt_separator: <!--more-->
---

I have started developing [Newbie-Renderer](https://github.com/C-none/Newbie-Renderer), a real-time renderer built with C++23 modules, Slang, and Vulkan. Development is in progress, and I will share updates as it evolves.

<!--more-->

<div class="more"><a href="https://github.com/C-none/Newbie-Renderer">repository</a></div>

## Introduction

Newbie-Renderer is intentionally narrow in platform scope (Windows + Vulkan + RTX) so development can focus on rendering architecture and experimentation instead of compatibility work.

The current direction is to build a solid base for modern ray tracing workflows and then push toward neural material rendering.

## Current status (brief overview)

From the current repository structure and README:

- The host code is organized around C++23 modules, which keeps compile boundaries explicit.
- Slang compilation and reflection are already integrated for resource/layout validation and binding workflows.
- A Vulkan-centered RHI layer is in place with RAII-style management.
- A scene layer based on flecs has been integrated.
- A glTF-oriented asset import/decode foundation is already included.

In short, the base system is now strong enough to support higher-level rendering experiments.

## Future goals

Near-term and mid-term milestones, aligned with the project TODO list:

- Scene-driven BLAS/TLAS build and update flow for ray tracing.
- Light BVH / many-light sampling for scalable direct illumination.
- Neural material system for learned BRDF/BSDF evaluation.
- Texture filtering and sampling research paths: filter-after-shading, sample-reuse filtering, and ray-cone-aware LOD.
- ...

These goals are consistent with making the renderer more practical.

## Link to neural-material notes

The next key direction is neural appearance modeling. I wrote a separate learning note here:

- [Neural material learning notes](/neural-material/)