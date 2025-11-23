#include <metal_stdlib>

#include "../../polyglot/shared.hpp"

using namespace metal;
using namespace metal::raytracing;

struct HitInfo {
    bool hit;
    bool backface;
    float3 pos;
    float3 normal;
};

HitInfo intersectScene(ray r, intersector<triangle_data, instancing> i, acceleration_structure<instancing> as, device const packed_float3* vertices, device const uint* indices, device const int* instanceIdxMap) {
    intersection_result<triangle_data, instancing> result = i.intersect(r, as);
    
    if (result.type != intersection_type::triangle) {
        return {false, false, float3(0), float3(0)};
    }
    
//    float2 bary = result.triangle_barycentric_coord;
    
    int idxOffset = instanceIdxMap[result.instance_id];
    
    int i0 = indices[idxOffset + result.primitive_id * 3];
    int i1 = indices[idxOffset + result.primitive_id * 3 + 1];
    int i2 = indices[idxOffset + result.primitive_id * 3 + 2];
    
    float3 v0 = vertices[i0];
    float3 v1 = vertices[i1];
    float3 v2 = vertices[i2];
    
    float3 pos = r.origin + r.direction * result.distance;
    
    float3 norm = normalize(cross(v1 - v0, v2 - v0));
    bool backface = dot(norm, r.direction) > 0;
    if (backface) {
        norm *= -1;
    }
    
    return {true, backface, pos, norm};
}

uint hash(uint x) {
    x ^= x >> 16;
    x *= 0x7feb352d;
    x ^= x >> 15;
    x *= 0x846ca68b;
    x ^= x >> 16;
    return x;
}

float rand(thread uint& seed) {
    /// Condensed version of pcg_output_rxs_m_xs_32_32, with simple conversion to floating-point [0,1].
    seed = seed * 747796405 + 1;
    uint word = ((seed >> ((seed >> 28) + 4)) ^ seed) * 277803737;
    word = (word >> 22) ^ word;
    return float(word) / 4294967295.0f;
}

float2 randomGaussian(thread uint& seed) {
    /// Function samples a gaussian distribution with sigma=1 around 0. Taken from: https://nvpro-samples.github.io/vk_mini_path_tracer/extras.html
    
    // Almost uniform in (0,1] - make sure the value is never 0:
    float u1 = max(1e-38, rand(seed));
    float u2 = rand(seed);  // In [0, 1]
    float r = sqrt(-2.0 * log(u1));
    float theta = 2 * M_PI_F * u2;  // Random in [0, 2pi]

    return r * float2(cos(theta), sin(theta));
}

float3 randFloat3(thread uint& seed) {
    return float3(rand(seed), rand(seed), rand(seed));
}

float3 randUnitFloat3(thread uint& seed) {
    while (true) {
        float3 p = randFloat3(seed) * 2 - 1;
        float lensq = dot(p, p);
        if (1e-8 < lensq && lensq <= 1) {
            return normalize(p);
        }
    }
}

float3 bsdfSampleDiffuse(float3 n, thread uint& seed) {
    return normalize(float3(n + randUnitFloat3(seed)));
}

ray getStartingRay(
    thread uint& seed,
    float2 pixel,
    float2 resolution,
    float4x4 invView,
    float4x4 invProjection
) {
    float2 randomPixelCenter = pixel + float2(0.5) + 0.375 * randomGaussian(seed);  // For antialiasing

    float2 ndc = float2(
        (randomPixelCenter.x / resolution.x) * 2.0 - 1.0,
        (randomPixelCenter.y / resolution.y) * 2.0 - 1.0
    );

    float4 clipPos = float4(ndc, 0.0, 1.0);

    // Unproject from clip space to view space using the inverse projection matrix
    float4 viewPos = float4(invProjection * clipPos);
    viewPos /= viewPos.w;  // Perspective divide.

    float3 viewDir = normalize(viewPos.xyz);

    // Transform the view-space direction to world space using the inverse view matrix.
    // Use a w component of 0.0 to indicate that we're transforming a direction.
    float4 worldDir4 = float4(invView * float4(viewDir, 0.0));
    float3 rayDirection = normalize(worldDir4.xyz);

    float3 origin = invView[3].xyz;
    float3 focalPoint = origin + rayDirection; // * pushConstants.focusDist;
//    float2 lensOffset = randomInUnitHexagon(pld.rngState) * pushConstants.defocusMultiplier;
    float2 lensOffset(0, 0);
    
    float3 right = normalize(invView[0].xyz);
    float3 up = normalize(invView[1].xyz);

    // Offset the origin by the lens offset.
    float3 offset = right * lensOffset.x + up * lensOffset.y;
    float3 newOrigin = origin + offset;

    // Recompute the ray direction so that the ray goes through the focal point.
    float3 newDirection = normalize(focalPoint - newOrigin);

    return ray(newOrigin, newDirection);
}

float3 skyColor(float3 dir) {
    return mix(float3(1, 1, 1), float3(0.3, 0.5, 1.0), saturate(dir.y * 0.5 + 0.5));
}

float3 runRaytrace(ray r, intersector<triangle_data, instancing> i, device const packed_float3* vertices, device const int* instanceIdxMap, device const uint* indices, acceleration_structure<instancing> as, thread uint& seed) {
    float3 throughput = float3(1);
    float3 incomingLight = float3(0);
    
    for (int tracedSegments = 0; tracedSegments < 16; tracedSegments++) {
        HitInfo hit = intersectScene(r, i, as, vertices, indices, instanceIdxMap);
        
        if (!hit.hit) {
            incomingLight += skyColor(r.direction) * throughput;
            break;
        }
        
#ifdef DEBUG_SHOW_NORMALS
        return hit.normal;
#endif
        
        float3 albedo = float3(0.9, 0.9, 0.9);
        throughput *= albedo;
        incomingLight += float3(0) * throughput;
        
        r.origin = hit.pos + hit.normal * 0.0001;
        r.direction = bsdfSampleDiffuse(hit.normal, seed);
    }
    
    return incomingLight;
}

kernel void raytraceMain(acceleration_structure<instancing> as[[buffer(ACC_STRUCT_BUFFER_IDX)]],
                         constant CameraData& matrices [[buffer(CAMERA_BUFFER_IDX)]],
                         device const packed_float3* vertices [[buffer(VERTICES_BUFFER_IDX)]],
                         device const uint* indices [[buffer(INDICES_BUFFER_IDX)]],
                         device const int* instanceIdxMap [[buffer(INSTANCE_IDX_MAP_BUFFER_IDX)]],
                         constant FrameParams& frameParams [[buffer(FRAME_PARAMS_BUFFER_IDX)]],
                         texture2d<float, access::read_write> outTex [[texture(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
#ifdef DEBUG_SHOW_NORMALS
    uint raysPerBatch = 1;
#else
    uint raysPerBatch = frameParams.samplesPerBatch;
#endif
    
    uint width  = outTex.get_width();
    uint height = outTex.get_height();

    if (gid.x >= width || gid.y >= height) {
        return;
    }

    uint raw = gid.x + gid.y * width + frameParams.frameIndex * 73856093u;
    uint seed = hash(raw);
    if (seed == 0) seed = 1;
    
    intersector<triangle_data, instancing> intersect;
    ray r;
    
    float3 sum = float3(0);
    for (uint i = 0; i < raysPerBatch; i++) {
        r = getStartingRay(seed, float2(gid), float2(width, height), matrices.invView, matrices.invProj);
        sum += runRaytrace(r, intersect, vertices, instanceIdxMap, indices, as, seed);
    }
    
    float4 thisColor = float4(sum / raysPerBatch, 1);
    
    float4 newColor;
    if (frameParams.frameIndex == 0) {
        newColor = thisColor;
    } else {
        float4 oldColor = outTex.read(gid.xy);
        newColor = (oldColor * raysPerBatch + thisColor) / float(raysPerBatch + 1);
    }

    outTex.write(newColor, gid.xy);
}
