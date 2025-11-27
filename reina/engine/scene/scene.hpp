#ifndef scene_hpp
#define scene_hpp

#include <vector>
#include <simd/simd.h>
#include <Metal/Metal.hpp>

#include "shared.hpp"
#include "model.hpp"
#include "tri_acc_struct.hpp"
#include "instance_acc_struct.hpp"


class Scene {
public:
    Scene() {}
    
    void addObject(const std::shared_ptr<Model>& model, const std::shared_ptr<Material>& material, simd::float4x4 transform);
    
    void build(MTL::Device* device, MTL::CommandQueue* cmdQueue);
    
    MTL::Buffer* getVertexBuffer() const;
    MTL::Buffer* getIndexBuffer() const;
    MTL::Buffer* getInstanceDataBuffer() const;
    MTL::Buffer* getMaterialBuffer() const;
    const std::vector<TriangleAccelerationStructure>& getChildAccStructs() const;
    const InstanceAccelerationStructure& getInstanceAccStruct() const;
    
private:
    void buildModelDataBuffers(MTL::Device* device, MTL::CommandQueue* cmdQueue);
    void buildChildAccStructs(MTL::Device* device, MTL::CommandQueue* cmdQueue);
    void buildInstanceAccStruct(MTL::Device* device, MTL::CommandQueue* cmdQueue);
    
    std::vector<std::shared_ptr<Material>> materials;
    std::vector<std::shared_ptr<Model>> models;
    std::vector<int> modelIndices;
    std::vector<TriangleAccelerationStructure> childAccStructs;
    std::unique_ptr<InstanceAccelerationStructure> instanceAccStruct;
    std::vector<InstanceData> instanceDataVec;
    std::vector<simd::float4x4> instanceTransforms;
    
    MTL::Buffer* vertexBuffer;
    MTL::Buffer* indexBuffer;
    MTL::Buffer* instanceDataBuffer;
    MTL::Buffer* materialBuffer;
};

#endif /* scene_hpp */
