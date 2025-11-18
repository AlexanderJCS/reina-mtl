#ifndef matmath_hpp
#define matmath_hpp

#include <Metal/Metal.hpp>
#include <simd/simd.h>

simd::float4x4 makePerspective(float fovyRadians, float aspect, float nearZ, float farZ);
simd::float4x4 lookAt(simd::float3 eye, simd::float3 center, simd::float3 up);
MTL::PackedFloat4x3 simdToMTL(simd::float4x4 m);

#endif /* matmath_hpp */
