---
title:  "Neural material notes: priors, sampling, and filtering"
category: post
layout: post
excerpt_separator: <!--more-->
mathjax: true
---

<table style="width:100%;">
	<tr>
		<td class="td-img">
				<img src="../assets/pic/nerual-material/pipeline.jpg" title="Neural material pipeline"/>
		</td>
		<td class="td-text">
			Learning notes on neural materials, focused on two papers: Real-Time Neural Appearance Models and Filtering After Shading With Stochastic Texture Filtering.
		</td>
	</tr>
</table>

<!--more-->

<div class="more"><a href="https://research.nvidia.com/labs/rtr/neural_appearance_models/">Real-Time Neural Appearance Models</a> | <a href="https://research.nvidia.com/labs/rtr/publication/pharr2024stochtex/">Filtering After Shading</a></div>

## Introduction

This note records what matters most for my Newbie-Renderer roadmap: how to make neural material fitting easier, and how to make filtering/sampling mathematically meaningful in a nonlinear shading pipeline.

The key message is simple: for neural fitting, strong priors and problem decomposition are not options. They are the reason the model can fit complex appearance efficiently.

## Paper 1: Real-Time Neural Appearance Models

Reference: [Real-Time Neural Appearance Models](https://research.nvidia.com/labs/rtr/neural_appearance_models/)

### Problem it solves

The paper targets a practical gap: real-time renderers need film-style layered materials, but classic material graphs and layered BSDF evaluation are too expensive to run directly at interactive rates.

More specifically, the system must do all of the following at once:

- preserve complex appearance (anisotropy, layered effects, mesoscale detail),
- provide low-noise importance sampling,
- support stable level-of-detail behavior,
- and run fast enough inside a real-time path tracer.

So the core problem is not just "fit a BRDF". It is building a compact representation that can be evaluated and sampled efficiently under real-time constraints.

### High-level method

The solution combines learned representation with graphics priors.

- A hierarchical latent texture stores local material state.
- At shading time, the renderer fetches latent code and runs neural decoders.
- One decoder predicts BRDF-related quantities.
- Another decoder predicts parameters of an analytic sampling distribution (a microfacet-style prior) to generate/evaluate sampling PDFs.
- The decoders are executed inline in the path tracer using hardware-accelerated tensor operations.

Conceptually, the model learns a decomposition: latent textures encode "what material is here", and decoders map that state plus directions to reflectance and sampling behavior.

### Small takeaway from shading frames

A key insight is to transform directions into learned local shading frames before MLP decoding. If $T_f(\cdot)$ is the frame transform and $z(x)$ is latent code, the decoder effectively learns:

$$
g \approx D\left(z(x),\,T_f(\omega_i),\,T_f(\omega_o)\right)
$$

instead of learning directly from raw global-space directions.

This is a useful neural-material lesson: when directional structure is strong, first choose a better coordinate system, then let the network fit the residual complexity.


## Paper 2: Filtering After Shading With Stochastic Texture Filtering

References:

- [NVIDIA page](https://research.nvidia.com/labs/rtr/publication/pharr2024stochtex/)

This work argues that in general we should filter after shading, not before BSDF evaluation.

For nonlinear shading, replacing the expected shaded value by shading of expected parameters is generally invalid:

$$
\mathbb{E}[f(X)] \neq f\left(\mathbb{E}[X]\right)
$$

Filtering-after-shading targets the filtered shaded signal itself. If $S(u)$ is the shaded quantity at texture sample location $u$ and $K(u)$ is a filter kernel, the target is:

$$
C = \int K(u)\,S(u)\,du
$$

A stochastic estimator is:

$$
\hat{C} = \frac{1}{N}\sum_{i=1}^{N}\frac{K(u_i)}{p(u_i)}S(u_i),\quad u_i\sim p(u)
$$

When designed well, this provides a mathematically valid estimator of the filtered shaded result, and the paper shows the additional stochastic error is manageable.

In the neural-material setting, this resolves the core mismatch that appears when nonlinear shading is driven by latent features: pre-filtered parameters generally do not correspond to filtered rendered appearance. By shifting the estimator target to filtered shaded radiance itself, the method keeps the math aligned with what we actually display, while remaining compatible with compressed and neural texture representations.

## Neural material context: why this matters

In neural materials, many intermediate quantities are nonlinear functions of latent code, directions, and frame transforms.

That is why naive linear interpolation in parameter/latent space often has no clear physical or mathematical meaning for final BRDF behavior. It can produce mixtures that do not correspond to the intended shaded outcome.

By contrast, stochastic filtering after shading keeps the integration target aligned with the rendered quantity. In that sense, the method remains mathematically meaningful in the neural-material pipeline.
