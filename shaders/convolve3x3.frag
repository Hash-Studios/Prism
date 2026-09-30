#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec3 uRow0;
uniform vec3 uRow1;
uniform vec3 uRow2;
uniform float uBias;
uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 uv, float dx, float dy) {
  return texture(uTexture, uv + vec2(dx, dy) / uSize).rgb;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  float alpha = texture(uTexture, uv).a;
  vec3 sum = vec3(uBias * alpha);
  sum += uRow0.x * tap(uv, -1.0, -1.0) + uRow0.y * tap(uv, 0.0, -1.0) + uRow0.z * tap(uv, 1.0, -1.0);
  sum += uRow1.x * tap(uv, -1.0, 0.0) + uRow1.y * tap(uv, 0.0, 0.0) + uRow1.z * tap(uv, 1.0, 0.0);
  sum += uRow2.x * tap(uv, -1.0, 1.0) + uRow2.y * tap(uv, 0.0, 1.0) + uRow2.z * tap(uv, 1.0, 1.0);
  fragColor = vec4(clamp(sum, vec3(0.0), vec3(alpha)), alpha);
}
