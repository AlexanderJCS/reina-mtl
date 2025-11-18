#include "matmath.hpp"

simd::float4x4 makePerspective(float fovyRadians, float aspect, float nearZ, float farZ) {
    float yScale = 1.0f / tanf(fovyRadians * 0.5f);
    float xScale = yScale / aspect;
    float zRange = farZ - nearZ;
    float zScale = -(farZ + nearZ) / zRange;
    float wzScale = -2.0f * farZ * nearZ / zRange;

    return simd::float4x4{
        simd::float4{ xScale, 0.0f,   0.0f,  0.0f },
        simd::float4{ 0.0f,   yScale, 0.0f,  0.0f },
        simd::float4{ 0.0f,   0.0f,   zScale, -1.0f },
        simd::float4{ 0.0f,   0.0f,   wzScale, 0.0f }
    };
}

simd::float4x4 lookAt(simd::float3 eye, simd::float3 center, simd::float3 up) {
    simd::float3 f = simd::normalize(center - eye); // forward
    simd::float3 s = simd::normalize(simd::cross(f, up)); // right
    simd::float3 u = simd::cross(s, f); // recalculated up

    // Metal / C++ uses column-major simd::float4x4
    simd::float4x4 result = {
        simd::float4{ s.x, u.x, -f.x, 0.0f },
        simd::float4{ s.y, u.y, -f.y, 0.0f },
        simd::float4{ s.z, u.z, -f.z, 0.0f },
        simd::float4{ -simd::dot(s, eye), -simd::dot(u, eye), simd::dot(f, eye), 1.0f }
    };

    return result;
}

MTL::PackedFloat4x3 simdToMTL(simd::float4x4 m) {
    MTL::PackedFloat4x3 out;
    
    for (int c = 0; c < 4; c++) {
        out.columns[c] = {
            m.columns[c].x,
            m.columns[c].y,
            m.columns[c].z
        };
    }
    
    return out;
}
