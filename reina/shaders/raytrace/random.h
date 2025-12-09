#ifndef random_h
#define random_h

#include <metal_stdlib>
using namespace metal;

uint hash(uint x);

float rand(thread uint& seed);

float2 randomGaussian(thread uint& seed);

float3 randFloat3(thread uint& seed);

float3 randUnitFloat3(thread uint& seed);

#endif /* random_h */
