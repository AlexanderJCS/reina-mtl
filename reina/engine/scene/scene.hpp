#ifndef scene_hpp
#define scene_hpp

#include <vector>
#include <simd/simd.h>
#include <Metal/Metal.hpp>

#include "material.hpp"
#include "model.hpp"
#include "tri_acc_struct.hpp"
#include "instance_acc_struct.hpp"


struct Object {
    std::shared_ptr<Model> model;
    simd::float4x4 transform;
};

class Scene {
public:
    Scene() {}
    
    void addObject(const Object& object);
    void addMaterial(const Material& material);
    
    void build(MTL::Device* device, MTL::CommandQueue* cmdQueue);
    
    MTL::Buffer* getVertexBuffer() const;
    MTL::Buffer* getIndexBuffer() const;
    MTL::Buffer* getInstanceIdxMapBuffer() const;
    const std::vector<TriangleAccelerationStructure>& getChildAccStructs() const;
    const InstanceAccelerationStructure& getInstanceAccStruct() const;
    
private:
    void createModelsVector();
    void buildModelDataBuffers(MTL::Device* device, MTL::CommandQueue* cmdQueue);
    void buildChildAccStructs(MTL::Device* device, MTL::CommandQueue* cmdQueue);
    void buildInstanceAccStruct(MTL::Device* device, MTL::CommandQueue* cmdQueue);
    
    std::vector<std::unique_ptr<Material>> materials;
    std::vector<std::unique_ptr<Object>> objects;
    
    std::vector<std::shared_ptr<Model>> models;
    std::vector<int> modelIndices;
    std::vector<TriangleAccelerationStructure> childAccStructs;
    std::unique_ptr<InstanceAccelerationStructure> instanceAccStruct;
    
    MTL::Buffer* vertexBuffer;
    MTL::Buffer* indexBuffer;
    MTL::Buffer* instanceIdxMapBuffer;
};

#endif /* scene_hpp */
