#include <metal_stdlib>
using namespace metal;
using namespace metal::raytracing;

struct Matrices {
    float4x4 invView;
    float4x4 invProjection;
};

ray getStartingRay(
    float2 pixel,
    float2 resolution,
    float4x4 invView,
    float4x4 invProjection
) {
    float2 randomPixelCenter = pixel + float2(0.5); // + 0.375 * randomGaussian(pld.rngState);  // For antialiasing

    float2 ndc = float2(
        (randomPixelCenter.x / resolution.x) * 2.0 - 1.0,
        -((randomPixelCenter.y / resolution.y) * 2.0 - 1.0)  // Flip y-coordinate so image isn't upside down.
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

kernel void raytraceMain(
                         acceleration_structure<> as[[buffer(0)]],
                         constant Matrices& matrices [[buffer(1)]],
                         texture2d<float, access::write> outTex [[texture(0)]],
                         uint2 gid [[thread_position_in_grid]]
                         ) {
    // Get texture size
    uint width  = outTex.get_width();
    uint height = outTex.get_height();

    // Check bounds
    if (gid.x >= width || gid.y >= height)
        return;

    ray startingRay = getStartingRay(float2(gid), float2(width, height), matrices.invView, matrices.invProjection);
    
    intersector<> i;
    intersection_result<> result = i.intersect(startingRay, as);
    
    if (result.type == intersection_type::triangle) {
        outTex.write(float4(1.0, 0.0, 0.0, 1.0), gid);
    } else {
        outTex.write(float4(0.0, 0.0, 0.0, 1.0), gid);
    }
}
