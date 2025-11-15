#include <metal_stdlib>
using namespace metal;

#include "vertex_data.hpp"

struct VertexOut {
    // The [[position]] attribute of this member indicates that this value
    // is the clip space position of the vertex when this structure is
    // returned from the vertex function.
    float4 position [[position]];

    // Since this member does not have a special attribute, the rasterizer
    // interpolates its value with the values of the other triangle vertices
    // and then passes the interpolated value to the fragment shader for each
    // fragment in the triangle.
    float2 textureCoordinate;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
             constant VertexData* vertexData) {
    VertexOut out;
    out.position = vertexData[vertexID].position;
    out.textureCoordinate = vertexData[vertexID].textureCoordinate;
    return out;
}

// AGX functions courtesy of: https://iolite-engine.com/blog_posts/minimal_agx_implementation
#define AGX_LOOK 0

// Mean error^2: 3.6705141e-06
float3 agxDefaultContrastApprox(float3 x) {
  float3 x2 = x * x;
  float3 x4 = x2 * x2;
  
  return + 15.5     * x4 * x2
         - 40.14    * x4 * x
         + 31.96    * x4
         - 6.868    * x2 * x
         + 0.4298   * x2
         + 0.1191   * x
         - 0.00232;
}

float3 agx(float3 val) {
  const float3x3 agx_mat = float3x3(
    0.842479062253094, 0.0423282422610123, 0.0423756549057051,
    0.0784335999999992,  0.878468636469772,  0.0784336,
    0.0792237451477643, 0.0791661274605434, 0.879142973793104);
    
  const float min_ev = -12.47393f;
  const float max_ev = 4.026069f;

  // Input transform (inset)
  val = agx_mat * val;
  
  // Log2 space encoding
  val = clamp(log2(val), min_ev, max_ev);
  val = (val - min_ev) / (max_ev - min_ev);
  
  // Apply sigmoid function approximation
  val = agxDefaultContrastApprox(val);

  return val;
}

float3 agxEotf(float3 val) {
  const float3x3 agx_mat_inv = float3x3(
    1.19687900512017, -0.0528968517574562, -0.0529716355144438,
    -0.0980208811401368, 1.15190312990417, -0.0980434501171241,
    -0.0990297440797205, -0.0989611768448433, 1.15107367264116);
    
  // Inverse input transform (outset)
  val = agx_mat_inv * val;
  
  // sRGB IEC 61966-2-1 2.2 Exponent Reference EOTF Display
  // NOTE: We're linearizing the output here. Comment/adjust when
  // *not* using a sRGB render target
  val = pow(val, float3(2.2));

  return val;
}

float3 agxLook(float3 val) {
  // Default
  float3 offset = float3(0.0);
  float3 slope = float3(1.0);
  float3 power = float3(1.0);
  float sat = 1.0;
 
#if AGX_LOOK == 1
  // Golden
  slope = float3(1.0, 0.9, 0.5);
  power = float3(0.8);
  sat = 0.8;
#elif AGX_LOOK == 2
  // Punchy
  slope = float3(1.0);
  power = float3(1.35, 1.35, 1.35);
  sat = 1.4;
#endif
  
  // ASC CDL
  val = pow(val * slope + offset, power);

  const float3 lw = float3(0.2126, 0.7152, 0.0722);
  float luma = dot(val, lw);

  return luma + sat * (val - luma);
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               texture2d<float> colorTexture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate);
    float4 tonemapped = float4(agxEotf(float3(colorSample)), 1);
    return tonemapped;
}
