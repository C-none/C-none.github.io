---
title:  "Screen probes computing tool using Vulkan"
category: post
# mathjax: true
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

In real-time rendering, lighting can be roughly divided into two parts: direct lighting which is contributed by the light source with one bounce via shadow map or any other techs, and indirect lighting which is simulated by a bunch of real-time GI techs. Lumen is one of them. At the end of the Lumen pipeline, it outputs a screen space light probes attaching to the surface of the objects to indicate the indirect lighting the surface receives.

To be more specific, every 16(4x4)pixels is allocated a probe, which contains two or three bands Spherical Harmonics coefficients. The first band is used to represent the ambient light, and the second and third bands are used to represent the directional light.

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

### Uniform sampling on a hemisphere

To sample a direction on a hemisphere uniformly, we need to sample the polar angle $\theta \in [0,\frac{\pi}{2})$ and the azimuthal angle $\phi \in [0,2\pi)$ respectively, where $\theta$ is the angle between normal and incident light. The probability density function of $\phi$ should be equal to a constant. But the probability density function of $\theta$ should be proportional to $\sin\theta$. 

Imagine that we divide the hemisphere into infinite small rings, the probability of sampling a direction in a ring should be proportional to the perimeter of the ring. The perimeter of the ring is $2\pi\sin\theta$.

To normalize the pdf, we need to divide the pdf by the integral of the pdf:

$$
pdf(\theta)=\frac{\sin\theta}{\int_0^{\frac{\pi}{2}}\sin\theta d\theta}=\sin\theta
$$

Thus, the cumulative distribution function of $\theta$ is:

$$
cdf(\theta)=\int_0^{\theta}pdf(\theta)d\theta=1-\cos\theta
$$

The inverse function of $cdf(\theta)$ is:

$$
\theta=acos(1-u)=acos(u)
$$

where $u$ is a random number in $[0,1)$.

The pdf of direction is $\frac{1}{2\pi}$, because it is uniform sampling on a hemisphere.

### Importance sampling on a hemisphere

Considering the rendering equation:

$$
L_o(p,\omega_o)=L_e(p,\omega_o)+\int_{\Omega}f(p,\omega_i,\omega_o)L_i(p,\omega_i)(n\cdot\omega_i)d\omega_i
$$

In coding, I set the pdf of $\theta$ to be proportional to $(n\cdot\omega_i)=cos\theta$, which is the cosine term in the rendering equation. Thus, the pdf of $\theta$ is:

$$
pdf(\theta)=\frac{\cos\theta\sin\theta}{\int_0^{\frac{\pi}{2}}\cos\theta\sin\theta d\theta}=2\cos\theta\sin\theta=sin(2\theta)
$$

The cumulative distribution function of $\theta$ is:

$$
cdf(\theta)=\int_0^{\theta}pdf(\theta)d\theta=\frac{1}{2}(1-\cos(2\theta))=sin^2(\theta)
$$

The inverse function of $cdf(\theta)$ is:

$$
\theta=asin(\sqrt{u})=acos(\sqrt{1-u})=acos(\sqrt{u}) \tag{*}
$$

where $u$ is a random number in $[0,1)$.

\* Let $\sqrt{u}=sin\theta$, then $u=sin^2\theta$, and $sin^2\theta+cos^2\theta=1$, so $cos\theta=\sqrt{1-u}$.

The pdf of direction is $\frac{cos\theta}{\pi}$.

### Something about normal map

After applying normal map,some rays sampled on the hemisphere may be opposite to the geometry normal, which means the ray is transmitting inside the object.

To prevent this problem, I generated the samples based on the geometry normal. My friend suggested that generating rays above the surface of the geometry each time(set the start point of the ray to be the surface point plus a small offset along the geometry normal). When the ray is opposite to the geometry normal, the ray will instant hit the nearby geometry in most cases. But this method is not robust, because of the offset.(it may pass through other geometries, like very narrow furrow)

The other discussion about this problem can be found [here](https://computergraphics.stackexchange.com/questions/4374/sampling-against-geometry-normals). One way is to call BTDF, treating this ray as a transmission ray. The other way is to use displacement maps instead of normal maps.(I think it is a robust solution)
