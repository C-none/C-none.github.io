---
title:  "Practical ray traced GI on WebGPU"
category: post
layout: post
excerpt_separator: <!--more-->
---

This [project](https://c-none.github.io/Web-RTRT) is still under developing.

<!--more-->

## requirements

I have only tested [https://c-none.github.io/Web-RTRT](https://c-none.github.io/Web-RTRT) on android 14 and windows 11 with both latest chrome and edge.

For windows, if you have multiple GPUs, you may need to set system -> display -> graphic settings -> choose your browser to set preference -> high performance to have a better experience.

## Introduction

This project is based on WebGPU, a new web API that provides a low-level abstraction of modern graphics APIs like Vulkan and Metal. It utilizes ReSTIR to accelerate the direct illumination (DI) and global illumination (GI) computations. Additionally, it incorporates a denoiser and an upscaler to enhance practicality for web-based applications.

