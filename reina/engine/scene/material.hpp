#ifndef material_hpp
#define material_hpp

#include <simd/simd.h>


struct Material {
    unsigned int materialID;
    simd::float3 color;
};

#endif /* material_hpp */
