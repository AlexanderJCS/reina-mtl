#ifndef sampling_h
#define sampling_h

#include <metal_stdlib>
using namespace metal;

float3 sampleGGXVNDF(float3 V, float ax, float ay, thread uint& rngState);

float D_GGX_Aniso(float3 m, float alphax, float alphay);
float D(float3 m, float2 alpha);

float pdfGGXReflection(float3 i, float3 o, float2 alpha);

float evalR0(float ior);

float luminance(float3 color);

float3 evalFm(float3 baseColor, float3 h, float3 wo, float specular, float3 specularTint, float metallic, float eta);

float evalDm(float3 hl, float alphax, float alphay);

float lambda(float3 wl, float alphax, float alphay);

float smithG(float3 wl, float alphax, float alphay);

float evalGm(float3 wi, float3 wo, float alphax, float alphay);

float3 evalMetal(float3x3 tbn, float3 baseColor, float anisotropic, float roughness, float3 n, float3 wi, float3 wo, float3 h);

float3 sampleMetal(float3x3 tbn, float anisotropic, float roughness, float3 wi, thread uint& rngState);

float pdfMetal(float3x3 tbn, float3 wi_world, float3 wo_world, float anisotropic, float roughness);

#endif  // sampling_h
