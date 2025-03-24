---
title:  "Easy software rasterizer"
category: post
layout: post
excerpt_separator: <!--more-->
show_sidebar: false
---

<table style="width:100%;">
  <tr>
    <td class="td-img">
        <img src="../assets/pic/easy-software-rasterizer/cube.jpg" title="a colorful cube"/>
    </td>
    <td class="td-text">
      A cube with anti-aliasing
    </td>
  </tr>
</table>

<!--more-->

<div class="more"><a href="https://github.com/C-none/easy-software-rasterizer">code</a></div>

## Introduction
This simple rasterizer is based on modern CPP, mainly before c++20. It is a good example for learning how to write a software rasterizer, including the basic rasterizing pipeline--vertex processing, primitive assembly, clipping, rasterization, visibility test, and fragment processing, . 
Additionally, it supports `Blinn-Phong shading model`, `texture mapping`, and `SSAA`.

<center>
    <img style="border-radius: 0.3125em;
    box-shadow: 0 2px 4px 0 rgba(34,36,38,.12),0 2px 10px 0 rgba(34,36,38,.08);" 
    src="../assets/pic/easy-software-rasterizer/cube.jpg" width = "80%" title="a colorful cube"/>
    <br>
    <div style="color:orange;
    display: inline-block;
    color: #AAA;
    padding: 2px;">
      result
  	</div>
</center>