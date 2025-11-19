#ifndef model_hpp
#define model_hpp

#include <Metal/Metal.hpp>
#include <QuartzCore/CAMetalLayer.hpp>
#include <simd/simd.h>

namespace MTL { class Device; class Buffer; }

class Model {
public:
    Model(MTL::Device* device, const std::string& filepath);

    [[nodiscard]] MTL::Buffer* getVertexBuffer() const;
    [[nodiscard]] MTL::Buffer* getIndexBuffer() const;
    [[nodiscard]] size_t getTriangleCount() const;
    
private:
    MTL::Buffer* vertexBuffer = nullptr;
    MTL::Buffer* indexBuffer = nullptr;
    size_t triangleCount = 0;
};

#endif /* model_hpp */
