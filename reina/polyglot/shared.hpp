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

struct VertexData {
    MATH_PREFIX::float4 position;
    MATH_PREFIX::float2 textureCoordinate;
};

struct Material {
    uint32_t materialID;
    MATH_PREFIX::float3 color;
    MATH_PREFIX::float3 emission;
    float roughness;
};

struct InstanceData {
    uint32_t indexOffset;
    uint32_t materialIdx;
};

#endif // !SHARED
