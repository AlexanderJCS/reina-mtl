#include <metal_stdlib>

#include "../../polyglot/shared.hpp"
#include "random.h"
#include "sampling.h"

using namespace metal;
using namespace metal::raytracing;

struct HitInfo {
    bool hit;
    bool backface;
    float3 pos;
    float3 geomNormal;
    float3x3 tbn;
    float3x3 mappedTBN;
    float roughness;
    uint32_t materialIdx;
    float2 uv;
};

float3 computeGeometryNormal(float3 v0, float3 v1, float3 v2) {
    return normalize(cross(v1 - v0, v2 - v0));
}

template <typename T>
T geomInterpolate(float3 bary, T a, T b, T c) {
    return a * bary.x + b * bary.y + c * bary.z;
}

HitInfo intersectScene(ray r, intersector<triangle_data, instancing> i, acceleration_structure<instancing> as, device const ModelVertexData* vertices, device const uint* indices, device const Material* materials, device const InstanceData* instanceData, const array<texture2d<float>, NUM_TEXTURES> textures) {
    intersection_result<triangle_data, instancing> hitResult = i.intersect(r, as);
    
    HitInfo hitInfo;
    
    if (hitResult.type != intersection_type::triangle) {
        hitInfo.hit = false;
        return hitInfo;
    }
    
    hitInfo.hit = true;
    hitInfo.materialIdx = instanceData[hitResult.instance_id].materialIdx;
    
    float3 bary = float3(0, hitResult.triangle_barycentric_coord);
    bary.x = 1.0 - bary.y - bary.z;
    
    float4x4 modelMatrix = instanceData[hitResult.instance_id].transform;
    int idxOffset = instanceData[hitResult.instance_id].indexOffset;
    
    int i0 = indices[idxOffset + hitResult.primitive_id * 3];
    int i1 = indices[idxOffset + hitResult.primitive_id * 3 + 1];
    int i2 = indices[idxOffset + hitResult.primitive_id * 3 + 2];
    
    ModelVertexData v0 = vertices[i0];
    ModelVertexData v1 = vertices[i1];
    ModelVertexData v2 = vertices[i2];
    
    // Transform the vertices into world space to account for instance rotation
    v0.pos = float3(modelMatrix * float4(v0.pos, 1));
    v1.pos = float3(modelMatrix * float4(v1.pos, 1));
    v2.pos = float3(modelMatrix * float4(v2.pos, 1));
    
    hitInfo.pos = r.origin + r.direction * hitResult.distance;
    
    hitInfo.geomNormal = computeGeometryNormal(v0.pos, v1.pos, v2.pos);
    hitInfo.backface = dot(hitInfo.geomNormal, r.direction) > 0;
    if (hitInfo.backface) {
        hitInfo.geomNormal *= -1;
    }
    
    hitInfo.uv = geomInterpolate(bary, v0.uv, v1.uv, v2.uv);
    
    float w = geomInterpolate(bary, v0.sign, v1.sign, v2.sign);
    hitInfo.tbn = float3x3(
        geomInterpolate(bary, v0.tangent, v1.tangent, v2.tangent),
        float3(0),
        geomInterpolate(bary, v0.normal, v1.normal, v2.normal)
    );
    
    hitInfo.tbn[1] = w * cross(hitInfo.tbn[2], hitInfo.tbn[0]);
    
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    
    hitInfo.mappedTBN = hitInfo.tbn;
    int normalMapID = materials[hitInfo.materialIdx].normalMapID;
    if (normalMapID >= 0) {
        float3 normalMapValue = float3(textures[normalMapID].sample(s, hitInfo.uv)) * 2.0 - 1.0;
        
        float3 N = normalize(hitInfo.tbn * normalMapValue);
        float3 T = hitInfo.tbn[0];
        T = normalize(T - N * dot(T, N));
        float3 B = cross(N, T);

        hitInfo.mappedTBN = float3x3(T, B, N);
    }
    
    hitInfo.roughness = materials[hitInfo.materialIdx].roughness;
    int roughnessMapID = materials[hitInfo.materialIdx].roughnessMapID;
    if (roughnessMapID >= 0) {
        hitInfo.roughness = textures[normalMapID].sample(s, hitInfo.uv).r;
    }
    
    return hitInfo;
}

void buildONB(float3 n, thread float3& T, thread float3& B) {
    float sign = copysign(1.0f, n.z);
    float a = -1.0f / (sign + n.z);
    float b = n.x * n.y * a;
    T = float3(1.0f + sign * n.x * n.x * a, sign * b, -sign * n.x);
    B = float3(b, sign + n.y * n.y * a, -n.y);
    
    T = normalize(T);
    B = normalize(B);
}

float2 concentricSampleDisk(float u1, float u2) {
    // map to [-1,1]^2
    float sx = 2.0f * u1 - 1.0f;
    float sy = 2.0f * u2 - 1.0f;

    // handle degeneracy at the origin
    if (sx == 0.0f && sy == 0.0f) {
        return float2(0.0f, 0.0f);
    }

    float r, theta;
    if (abs(sx) > abs(sy)) {
        r = sx;
        theta = (M_PI_F / 4.0f) * (sy / sx);
    } else {
        r = sy;
        theta = (M_PI_F / 2.0f) - (M_PI_F / 4.0f) * (sx / sy);
    }

    return float2(r * cos(theta), r * sin(theta));
}

// RNG: uses your rand(thread uint& seed) existing function
inline float3 sampleCosineHemisphere(float3 N, thread uint& seed) {
    // generate two uniforms
    float u1 = rand(seed);
    float u2 = rand(seed);

    // sample concentric disk
    float2 d = concentricSampleDisk(u1, u2);
    float x = d.x;
    float y = d.y;
    float z = sqrt(max(0.0f, 1.0f - x*x - y*y)); // hemisphere z

    // local-space direction (z = up)
    float3 localDir = float3(x, y, z); // already normalized approximately

    // build ONB and transform to world
    float3 T, B;
    buildONB(N, T, B);
    float3 worldDir = localDir.x * T + localDir.y * B + localDir.z * N;
    return normalize(worldDir); // unit length
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
#ifdef DEBUG_SKY_COLOR_GRAY
    return float3(0.5);
#endif
    
    return mix(float3(0), float3(1), saturate(dir.y * 0.5 + 0.5));
}

float3 runRaytrace(ray r, intersector<triangle_data, instancing> i, device const ModelVertexData* vertices, device const InstanceData* instanceData, device const uint* indices, device const Material* materials, acceleration_structure<instancing> as, thread uint& seed, const array<texture2d<float>, NUM_TEXTURES> textures) {
    float3 throughput = float3(1);
    float3 incomingLight = float3(0);
    
    for (int tracedSegments = 0; tracedSegments < 10; tracedSegments++) {
        HitInfo hit = intersectScene(r, i, as, vertices, indices, materials, instanceData, textures);
        
        if (!hit.hit) {
            incomingLight += skyColor(r.direction) * throughput;
            break;
        }
        
#ifdef DEBUG_SHOW_NORMALS
        return hit.tbn[2] * 0.5 + 0.5;
#endif
        
        Material mat = materials[hit.materialIdx];
        
        float3 color = mat.color;
        if (mat.textureID >= 0) {
            constexpr sampler s(address::repeat, filter::linear);
            color *= float3(textures[mat.textureID].sample(s, hit.uv));
        }
        
        r.origin = hit.pos + hit.tbn[2] * 0.0001;
        
        if (mat.materialID == 0) {
            r.direction = sampleCosineHemisphere(hit.mappedTBN[2], seed);
        } else {
            float3 wi = -r.direction;
            
            // float3x3 tbn, float anisotropic, float roughness, float3 wi, thread uint& rngState)
            float3 h = sampleMetal(hit.mappedTBN, 0.0f, hit.roughness, -r.direction, seed);
            
            float3 wo = reflect(-wi, h);
            r.direction = wo;
            
            // float3x3 tbn, float3 baseColor, float anisotropic, float roughness, float3 n, float3 wi, float3 wo, float3 h
            float3 f = evalMetal(hit.mappedTBN, color, 0.0f, hit.roughness, hit.mappedTBN[2], wi, wo, h);
            
            // float3x3 tbn, float3 wi_world, float3 wo_world, float anisotropic, float roughness
            float pdf = pdfMetal(hit.mappedTBN, wi, wo, 0.0f, hit.roughness);
            
            float cosThetaI = saturate(dot(wi, hit.mappedTBN[2]));
            
            color = f * cosThetaI / max(pdf, EPS);
        }
        
        throughput *= color;
        incomingLight += mat.emission * throughput;
    }
    
    return incomingLight;
}

kernel void raytraceMain(acceleration_structure<instancing> as[[buffer(ACC_STRUCT_BUFFER_IDX)]],
                         constant CameraData& matrices [[buffer(CAMERA_BUFFER_IDX)]],
                         device const ModelVertexData* vertices [[buffer(VERTICES_BUFFER_IDX)]],
                         device const uint* indices [[buffer(INDICES_BUFFER_IDX)]],
                         device const InstanceData* instanceData [[buffer(INSTANCE_DATA_BUFFER_IDX)]],
                         device const Material* materials [[buffer(MATERIAL_BUFFER_IDX)]],
                         constant FrameParams& frameParams [[buffer(FRAME_PARAMS_BUFFER_IDX)]],
                         texture2d<float, access::read_write> inTex [[texture(INPUT_TEXTURE_IDX)]],
                         texture2d<float, access::read_write> outTex [[texture(OUTPUT_TEXTURE_IDX)]],
                         const array<texture2d<float>, NUM_TEXTURES> textures [[texture(TEXTURE_ARRAY_IDX)]],
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
        sum += runRaytrace(r, intersect, vertices, instanceData, indices, materials, as, seed, textures);
    }
    
    float4 thisColor = float4(sum / raysPerBatch, 1);
    
    float4 newColor;
    if (frameParams.frameIndex == 0) {
        newColor = thisColor;
    } else {
        float4 oldColor = inTex.read(gid.xy);
        newColor = (oldColor * frameParams.frameIndex + thisColor) / float(frameParams.frameIndex + 1);
    }

    if (any(isinf(newColor))) {
        newColor = float4(1, 1, 0, 1);
    } else if (any(isnan(newColor))) {
        newColor = float4(1, 0, 0, 1);
    }
    
    outTex.write(newColor, gid.xy);
}
