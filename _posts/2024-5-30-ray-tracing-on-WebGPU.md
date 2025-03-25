---
title:  "Practical ray traced GI on WebGPU"
category: post
layout: post
excerpt_separator: <!--more-->
---
<table style="width:100%;">
    <tr>
        <td class="td-img">
                <img src="../assets/pic/ray-tracing-on-WebGPU/restir.png" title="Real-time result"/>
        </td>
        <td class="td-text">
            The picture on the left is the real-time result of the project.
            
            This is a real-time ray tracing <a href="https://c-none.github.io/Web-RTRT">project</a> based on WebGPU. The project utilizes ReSTIR to accelerate the direct illumination (DI) and global illumination (GI) computations. Additionally, it incorporates a denoiser and an upscaler to enhance practicality for web-based applications.
        </td>
    </tr>
</table>

<!--more-->

## requirements

I have only tested this [project](https://github.com/C-none/Web-RTRT) on android 14 and windows 11 with both latest chrome and edge.

For windows, if you have multiple GPUs, you may need to set system -> display -> graphic settings -> choose your browser to set preference -> high performance to have a better experience.

## Introduction

This project is based on WebGPU, a new web API that provides a low-level abstraction of modern graphics APIs like Vulkan and Metal. It utilizes ReSTIR to accelerate the direct illumination (DI) and global illumination (GI) computations. Additionally, it incorporates a denoiser and an upscaler to enhance practicality for web-based applications.

## Details

### WebGPU

Although WebGPU is more powerful than WebGL in many cases, there are many features in native APIs that are not yet supported. I have encountered some problems caused by unsupported features: Ray tracing extension; Bindless resources; Geometry shader; Global memory barrier.

_Ray tracing on WebGPU._ [This](https://github.com/maierfelix/dawn-ray-tracing) is based on hardware as an extension for Chrome (not compatible across devices). [This](https://github.com/codedhead/webrtx) is based on compute shader but only supports limited features. I maintain a ray tracing pipeline myself, based on compute shader.

_Bindless resources._ I use a texture array to store the textures and use the texture index to access them. This is a workaround for the lack of bindless resources. Another option is to use texture atlases.

_Geometry shader._ [The issue](https://github.com/gpuweb/gpuweb/issues/1786) highlighted here prompted me to flatten the vertex buffer, deriving the primitive ID by dividing the vertex index by 3.

_Global memory barrier._ It is said that [this](https://github.com/gpuweb/gpuweb/issues/3774) limitation is caused by Metal. In general, I can either use a global memory barrier or start a new pass to synchronize memory accesses between different workgroups(No explicit synchronization in WebGPU). But because of the limitation, I have to use the second solution.

It is worth mentioning that the WebGPU supports group shared memory, which is a useful for group memory accessing in filter operation.

### Visibility buffer

The visibility buffer is a screen-space buffer that stores the scene’s visibility data.

During the V-buffer stage, I also store additional data, including the motion vector, barycentric coordinates, and pixel depth.

### ray tracing

It is mainly based on [ReSTIR DI](https://research.nvidia.com/labs/rtr/publication/bitterli2020spatiotemporal/) and [ReSTIR GI](https://research.nvidia.com/publication/2021-06_restir-gi-path-resampling-real-time-path-tracing)

A key promotion of ReSTIR GI is to apply a RIS to resample lights during NEE stage when tracing a indirect lighting path, which can choose a higher quality lighting source and introduces no bias and no correlation. (Because this reservoir is not shared across pixels and disposed after use)

### Denoiser

The denoiser is based on [SVGF](https://research.nvidia.com/publication/2017-07_spatiotemporal-variance-guided-filtering-real-time-reconstruction-path-traced) and [ReLAX](https://www.nvidia.com/en-us/on-demand/session/gtcspring21-s32759/).

### Upscaler

The upscaler is based on [FSR2](https://github.com/GPUOpen-Effects/FidelityFX-FSR2).
