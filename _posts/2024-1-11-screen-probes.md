---
title:  "Screen probes computing tool using Vulkan"
category: post
layout: post
excerpt_separator: <!--more-->
---

<table style="width:100%;">
    <tr>
        <td class="td-img">
                <img src="../assets/pic/screen_probes/lumen%20screen%20probe.jpg" title="Screen probes"/>
        </td>
        <td class="td-text">
            This offline tool is similar to Lumen in UE5, it can output probes in screen space from a specified viewpoint. The left pic is from the introduction of Lumen slide.
        </td>
    </tr>
</table>

<!--more-->

<div class="more"><a href="https://github.com/C-none/VK-screen-space-probe">code</a></div>

## Introduction

In real-time rendering, lighting can be roughly divided into two parts: direct lighting which is contributed by the light source via shadow map or any other techs, and indirect lighting which is simulated by a bunch of real-time GI techs. Lumen is one of them. At the end of the Lumen pipeline, it outputs a screen space light probes attaching to the surface of the objects to indicate the indirect lighting the surface receives.

To be more specific, every 16(4x4)pixels is allocated a probe, which contains two or three band Spherical Harmonics coefficients. The first band is used to represent the ambient light, and the second and third bands are used to represent the directional light.

According to the above, the tool output a JSON file including every probe's 27(9 coefficients * 3 RGB) float and the position in the screen space.

## Notes

Something worth recording during my implementation.

### Disney Principled BSDF

This [document](https://cseweb.ucsd.edu/~tzli/cse272/wi2024/homework1.pdf) sorts out the formulation of the Disney Principled BSDF clearly. It is easy to implement the BSDF step by step according to this document.

### Spherical Harmonics

The implementation of Spherical Harmonics refers to [this](https://github.com/EpicGames/UnrealEngine/blob/072300df18a94f18077ca20a14224b5d99fee872/Engine/Shaders/Private/SHCommon.ush#L226)

To project the irradiance to the SH basis,
$$
f_l^m=\int_{\Omega}I(\omega)Y_l^m(\omega)d\omega
$$
where $l$ indicates the band, $m$ indicates the order, $\omega$ is the direction of the incident light, $I(\omega)$ is the irradiance, $Y_l^m(\omega)$ is the SH basis, $\Omega$ is the solid angle, and $f_l^m$ is the corresponding SH coefficient.

To estimate coefficients, 
$$
f_l^m=\frac{1}{N}\sum_{i=1}^NI(\omega_i)Y_l^m(\omega_i)/pdf(\omega_i)
$$
where $N$ is the number of samples, and $pdf(\omega_i)$ is the probability density function of the direction $\omega_i$.

To reconstruct the irradiance from the SH basis,
$$
I(\omega)=\sum_{l=0}^L\sum_{m=-l}^lf_l^mY_l^m(\omega)
$$
where $L$ is the band number.

### Uniform sampling on a hemisphere


