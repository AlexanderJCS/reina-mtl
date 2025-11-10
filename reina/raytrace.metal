#include <metal_stdlib>
using namespace metal;
using namespace metal::raytracing;

kernel void raytraceMain(
                         acceleration_structure<> as[[buffer(0)]],
                         texture2d<float, access::write> outTex [[texture(0)]],
                         uint2 gid [[thread_position_in_grid]]
                         ) {
    // Get texture size
    uint width  = outTex.get_width();
    uint height = outTex.get_height();

    // Check bounds
    if (gid.x >= width || gid.y >= height)
        return;

    intersector<> i;
    ray r(float3(0, 0, 0), float3(0, 0, 1));
    intersection_result<> result = i.intersect(r, as);
    
    if (result.type == intersection_type::triangle) {
        outTex.write(float4(1.0, 0.0, 0.0, 1.0), gid);
    } else {
        outTex.write(float4(0.0, 0.0, 0.0, 1.0), gid);
    }
}
