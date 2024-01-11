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

