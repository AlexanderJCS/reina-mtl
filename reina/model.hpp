#ifndef model_hpp
#define model_hpp

#include <Metal/Metal.hpp>
#include <QuartzCore/CAMetalLayer.hpp>
#include <simd/simd.h>

// Forward declarations to avoid exposing Objective-C types in a C++ header.
namespace MTL { class Device; class Buffer; }

class Model {
public:
    explicit Model(MTL::Device* device);

private:
    MTL::Buffer* vertexBuffer = nullptr;
    MTL::Buffer* indexBuffer = nullptr;
    int triangleCount = 0;
};

#endif /* model_hpp */
