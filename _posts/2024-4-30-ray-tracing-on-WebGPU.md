---
title:  "Practical ray traced GI on WebGPU"
category: post
layout: post
excerpt_separator: <!--more-->
---

This [project](https://github.com/C-none/Web-RTRT) is still under developing.

<!--more-->

## Introduction

This project is based on WebGPU, a new web API that provides a low-level abstraction of modern graphics APIs like Vulkan and Metal. It utilizes ReSTIR to accelerate the direct illumination (DI) and global illumination (GI) computations. Additionally, it incorporates a denoiser and an upscaler to enhance practicality for web-based applications.

Tested in Chrome on Windows and Android.
