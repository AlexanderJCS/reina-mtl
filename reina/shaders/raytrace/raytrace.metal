#include <metal_stdlib>

#include "../../polyglot/shared.hpp"

using namespace metal;
using namespace metal::raytracing;

ray getStartingRay(
    float2 pixel,
    float2 resolution,
    float4x4 invView,
    float4x4 invProjection
) {
    float2 randomPixelCenter = pixel + float2(0.5); // + 0.375 * randomGaussian(pld.rngState);  // For antialiasing

    float2 ndc = float2(
        (randomPixelCenter.x / resolution.x) * 2.0 - 1.0,
        -((randomPixelCenter.y / resolution.y) * 2.0 - 1.0)  // Flip y-coordinate so image isn't upside down
    );

    float4 clipPos = float4(ndc, -1.0, 1.0);

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

struct HitInfo {
    bool hit;
    bool backface;
    float3 pos;
    float3 normal;
};

HitInfo intersectScene(ray r, intersector<triangle_data> i, acceleration_structure<> as, constant packed_float3* vertices, constant int* indices) {
    intersection_result<triangle_data> result = i.intersect(r, as);
    
    if (result.type != intersection_type::triangle) {
        return {false, false, float3(0), float3(0)};
    }
    
//    float2 bary = result.triangle_barycentric_coord;
    
    int i0 = indices[result.primitive_id * 3];
    int i1 = indices[result.primitive_id * 3 + 1];
    int i2 = indices[result.primitive_id * 3 + 2];
    
    float3 v0 = vertices[i0];
    float3 v1 = vertices[i1];
    float3 v2 = vertices[i2];
    
    float3 pos = r.origin + r.direction * result.distance;
    
    float3 norm = normalize(cross(v1 - v0, v2 - v0));
    bool backface = dot(norm, r.direction) > 0;
    norm = faceforward(norm, -r.direction, norm);
    
    return {true, backface, pos, norm};
}

float rand(thread uint& seed) {
    /// Condensed version of pcg_output_rxs_m_xs_32_32, with simple conversion to floating-point [0,1].
    seed = seed * 747796405 + 1;
    uint word = ((seed >> ((seed >> 28) + 4)) ^ seed) * 277803737;
    word = (word >> 22) ^ word;
    return float(word) / 4294967295.0f;
}

float3 bsdfSampleDiffuse(float3 n, thread uint& seed) {
    float theta = 2.0 * M_PI_F * rand(seed);  // Random in [0, 2pi]
    float u = 2.0 * rand(seed) - 1.0;   // Random in [-1, 1]
    float r = sqrt(1.0 - u * u);
    float3 direction = n + float3(r * cos(theta), r * sin(theta), u);
    
    return normalize(direction);
}

kernel void raytraceMain(acceleration_structure<> as[[buffer(ACC_STRUCT_BUFFER_IDX)]],
                         constant CameraData& matrices [[buffer(CAMERA_BUFFER_IDX)]],
                         constant packed_float3* vertices [[buffer(VERTICES_BUFFER_IDX)]],
                         constant int* indices [[buffer(INDICES_BUFFER_IDX)]],
                         constant FrameParams& frameParams [[buffer(FRAME_PARAMS_BUFFER_IDX)]],
                         texture2d<float, access::read_write> outTex [[texture(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    uint width  = outTex.get_width();
    uint height = outTex.get_height();

    if (gid.x >= width || gid.y >= height) {
        return;
    }

    uint seed = (height + gid.y) * width + gid.x;
    
    intersector<triangle_data> i;
    
    ray r = getStartingRay(float2(gid), float2(width, height), matrices.invView, matrices.invProj);
    
    float3 throughput = float3(1);
    float3 incomingLight = float3(0);
    
    for (int tracedSegments = 0; tracedSegments < 16; tracedSegments++) {
        HitInfo hit = intersectScene(r, i, as, vertices, indices);
        
        if (!hit.hit) {
            incomingLight += float3(0.4, 0.7, 1.0) * throughput;
            break;
        }
        
        float3 albedo = float3(0.9, 0.3, 0.2);
        throughput *= albedo;
        incomingLight += float3(0) * throughput;
        
        r.origin = hit.pos + hit.normal * 0.0001;
        r.direction = bsdfSampleDiffuse(hit.normal, seed);
    }
    
    float4 oldColor = outTex.read(gid.xy);
    float4 thisColor = float4(incomingLight, 1);
    float4 newColor = frameParams.frameIndex == 0 ? thisColor : mix(oldColor, thisColor, 1 / frameParams.frameIndex);
    
    outTex.write(newColor, gid.xy);
}
