#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec3 uRow0;
uniform vec3 uRow1;
uniform vec3 uRow2;
uniform float uBias;
uniform sampler2D uTexture;

out vec4 fragColor;

vec2 uv;
vec3 centre;

// Works on straight (unpremultiplied) colour. Taps clamp to the texture, and transparent
// neighbours repeat the centre pixel, so the image border does not read as an edge.
vec3 tap(float dx, float dy) {
  vec2 halfTexel = 0.5 / uSize;
  vec4 texel = texture(uTexture, clamp(uv + vec2(dx, dy) / uSize, halfTexel, 1.0 - halfTexel));
  return texel.a > 0.0 ? texel.rgb / texel.a : centre;
}

void main() {
  uv = FlutterFragCoord().xy / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  vec4 source = texture(uTexture, uv);
  centre = source.a > 0.0 ? source.rgb / source.a : vec3(0.0);
  vec3 sum = vec3(uBias);
  sum += uRow0.x * tap(-1.0, -1.0) + uRow0.y * tap(0.0, -1.0) + uRow0.z * tap(1.0, -1.0);
  sum += uRow1.x * tap(-1.0, 0.0) + uRow1.y * centre + uRow1.z * tap(1.0, 0.0);
  sum += uRow2.x * tap(-1.0, 1.0) + uRow2.y * tap(0.0, 1.0) + uRow2.z * tap(1.0, 1.0);
  fragColor = vec4(clamp(sum, 0.0, 1.0) * source.a, source.a);
}
