#ifndef SHARED
#define SHARED

#ifdef __METAL_VERSION__
    #define SHARED_CONST constant
#else
    #define SHARED_CONST constexpr
#endif

// #define DEBUG_SHOW_NORMALS

SHARED_CONST uint INPUT_TEXTURE_IDX = 0;
SHARED_CONST uint OUTPUT_TEXTURE_IDX = 1;
SHARED_CONST uint ACC_STRUCT_BUFFER_IDX = 0;
SHARED_CONST uint CAMERA_BUFFER_IDX = 1;
SHARED_CONST uint VERTICES_BUFFER_IDX = 2;
SHARED_CONST uint INDICES_BUFFER_IDX = 3;
SHARED_CONST uint FRAME_PARAMS_BUFFER_IDX = 4;
SHARED_CONST uint INSTANCE_DATA_BUFFER_IDX = 5;
SHARED_CONST uint MATERIAL_BUFFER_IDX = 6;
SHARED_CONST uint TEXTURE_ARRAY_BUFFER_IDX = 7;
SHARED_CONST uint NUM_TEXTURES = 16;
SHARED_CONST uint TEXTURE_ARRAY_IDX = 2;  // Binds textures from TEXTURE_ARRAY_IDX to TEXTURE_ARRAY_IDX + NUM_TEXTURES - 1

#ifdef __METAL_VERSION__
    #include <metal_stdlib>
    #define MATH_PREFIX metal
#else
    #include <simd/simd.h>
    #define MATH_PREFIX simd
#endif

struct CameraData {
    MATH_PREFIX::float4x4 invView;
    MATH_PREFIX::float4x4 invProj;
};

struct FrameParams {
    uint frameIndex;
    uint samplesPerBatch;
};

struct FullscreenQuadVertexData {
    MATH_PREFIX::float4 position;
    MATH_PREFIX::float2 textureCoordinate;
};

struct Material {
    uint32_t materialID;
    int32_t textureID;
    MATH_PREFIX::float3 color;
    MATH_PREFIX::float3 emission;
    float roughness;
};

struct ModelVertexData {
    MATH_PREFIX::float3 pos, normal, tangent;
    MATH_PREFIX::float2 uv;
    float sign;
    
#ifndef __METAL_VERSION__
    bool operator==(const ModelVertexData& rhs) const {
        /// WARNING: tangents and signs are not included in this comparison because this is for unordered_map before MikkTSpace calculations
        
        return pos.x == rhs.pos.x && pos.y == rhs.pos.y && pos.z == rhs.pos.z &&
            normal.x == rhs.normal.x && normal.y == rhs.normal.y && normal.z == rhs.normal.z &&
            uv.x == rhs.uv.x && uv.y == rhs.uv.y &&
            sign == rhs.sign;
    }
#endif // !__METAL_VERSION__
};

struct InstanceData {
    uint32_t indexOffset;
    uint32_t materialIdx;
    MATH_PREFIX::float4x4 transform;
};

#endif // !SHARED
