#ifndef model_hpp
#define model_hpp

#include <Metal/Metal.hpp>
#include <QuartzCore/CAMetalLayer.hpp>
#include <simd/simd.h>

namespace MTL { class Device; class Buffer; }

class Model {
public:
    explicit Model(MTL::Device* device);

    [[nodiscard]] MTL::Buffer* getVertexBuffer() const;
    [[nodiscard]] MTL::Buffer* getIndexBuffer() const;
    [[nodiscard]] int getTriangleCount() const;
    
private:
    MTL::Buffer* vertexBuffer = nullptr;
    MTL::Buffer* indexBuffer = nullptr;
    int triangleCount = 0;
};

#endif /* model_hpp */
