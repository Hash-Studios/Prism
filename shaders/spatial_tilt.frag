#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec2 uImageSize;
// Phone tilt, -1 to 1 on each axis.
uniform vec2 uTilt;
// Largest shift as a share of the visible image. Keep it small: the map is low resolution.
uniform float uStrength;
uniform sampler2D uImage;
// Grey depth map, bright is near.
uniform sampler2D uDepth;

out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy / uSize;
  float viewAspect = uSize.x / uSize.y;
  float imageAspect = uImageSize.x / uImageSize.y;
  vec2 visible = viewAspect > imageAspect ? vec2(1.0, imageAspect / viewAspect) : vec2(viewAspect / imageAspect, 1.0);
  // Zoom in by the largest shift so a shifted sample never leaves the image.
  visible *= 1.0 - 2.0 * uStrength;
  vec2 uv = 0.5 + (p - 0.5) * visible;
  float near = texture(uDepth, uv).r - 0.5;
  fragColor = texture(uImage, uv + uTilt * near * 2.0 * uStrength);
}
