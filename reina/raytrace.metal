#include <metal_stdlib>
using namespace metal;

kernel void raytraceMain(texture2d<float, access::write> outTex [[texture(0)]],
                         uint2 gid [[thread_position_in_grid]])
{
    // Get texture size
    uint width  = outTex.get_width();
    uint height = outTex.get_height();

    // Check bounds
    if (gid.x >= width || gid.y >= height)
        return;

    // Write red pixel (RGBA)
    outTex.write(float4(1.0, 0.0, 0.0, 1.0), gid);
}
