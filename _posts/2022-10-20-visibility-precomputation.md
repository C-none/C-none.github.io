---
title:  "VK precomputed visibility"
category: post
layout: post
excerpt_separator: <!--more-->
---

## Introduction

This is a simple implementation of precomputed visibility in Vulkan based on modern CPP.

<!--more-->

<div class="more"><a href="https://github.com/C-none/vk-precompute">code</a></div>

## Purpose

While observing 3D world on web, it is a challenge to load so many models instantly, which means we need to load the models selectively. Intuitively, we can load the models that are visible to the camera. However, it is time-consuming to compute the visibility of each model in real-time. Therefore, we can precompute the visibility of each model and store the result in a file. Then, we can load the models selectively according to the visibility data.

--------

the followings are 'input':

1. OBJ model with vertex only
2. instances data
3. sample range and frequency

All the things above should be set in 'main.cpp' file

After running, the program will write the visibility data into a folder, where there are visibility(Solid angle or pixel count) in each sample point.

Features:
- [x] CPU multi-threading(read, write, count)
- [ ] GPU culling
- [ ] optimization for CPU multi-threading
