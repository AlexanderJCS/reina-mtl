#ifdef __METAL_VERSION__
    #define SHARED_CONST constant
#else
    #define SHARED_CONST constexpr
#endif

SHARED_CONST uint ACC_STRUCT_BUFFER_IDX = 0;
SHARED_CONST uint CAMERA_BUFFER_IDX = 1;
SHARED_CONST uint VERTICES_BUFFER_IDX = 2;
SHARED_CONST uint INDICES_BUFFER_IDX = 3;
SHARED_CONST uint FRAME_PARAMS_BUFFER_IDX = 4;

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
