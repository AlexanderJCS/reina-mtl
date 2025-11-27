#include "scene.hpp"

#include <set>
#include <iostream>

#include "buffers.hpp"

void Scene::addObject(const std::shared_ptr<Model>& model, const std::shared_ptr<Material>& material, simd::float4x4 transform) {
    instanceTransforms.push_back(transform);
    
    InstanceData instanceData;
    
    bool foundMaterial = false;
    for (uint32_t i = 0; i < materials.size(); i++) {
        if (materials[i] == material) {
            foundMaterial = true;
            instanceData.materialIdx = i;
            break;
        }
    }
    
    if (!foundMaterial) {
        instanceData.materialIdx = static_cast<uint32_t>(materials.size());
        materials.push_back(material);
    }
    
    bool foundModel = false;
    uint32_t totalIndices = 0;
    for (uint32_t i = 0; i < models.size(); i++) {
        totalIndices += models[i]->getTriangleCount() * 3;
        
        if (models[i] == model) {
            foundModel = true;
            modelIndices.push_back(i);
            break;
        }
    }
    
    instanceData.indexOffset = totalIndices;
    if (!foundModel) {
        modelIndices.push_back(static_cast<uint32_t>(models.size()));
        models.push_back(model);
    }
    
    instanceDataVec.push_back(instanceData);
}

void Scene::build(MTL::Device* device, MTL::CommandQueue* cmdQueue) {
    buildModelDataBuffers(device, cmdQueue);
    buildChildAccStructs(device, cmdQueue);
    buildInstanceAccStruct(device, cmdQueue);
}

void Scene::buildChildAccStructs(MTL::Device* device, MTL::CommandQueue* cmdQueue) {
    childAccStructs = std::vector<TriangleAccelerationStructure>{};
    
    for (const auto& model : models) {
        childAccStructs.push_back(TriangleAccelerationStructure(device, cmdQueue, *model));
    }
}

void Scene::buildInstanceAccStruct(MTL::Device* device, MTL::CommandQueue* cmdQueue) {
    std::vector<MTL::AccelerationStructure*> accStructs(childAccStructs.size());
    std::vector<simd::float4x4> transforms(instanceDataVec.size());
    for (int i = 0; i < childAccStructs.size(); i++) {
        int accStructIdx = modelIndices[i];
        accStructs[i] = childAccStructs[accStructIdx].getAccelerationStructure();
        transforms[i] = instanceTransforms[i];
    }
    
    instanceAccStruct = std::make_unique<InstanceAccelerationStructure>(device, cmdQueue, accStructs, transforms);
}

void Scene::buildModelDataBuffers(MTL::Device* device, MTL::CommandQueue* cmdQueue) {
    // First pass to see vertex and index buffer size
    std::vector<size_t> modelIdxToIdxLoc(models.size());
    size_t totalVertices = 0;
    size_t totalIndices = 0;
    
    for (int i = 0; i < models.size(); i++) {
        const auto& model = models[i];
        
        modelIdxToIdxLoc[i] = totalIndices;
        totalVertices += model->getVertexCount();
        totalIndices += model->getTriangleCount() * 3;
    }
    
    // Second pass to build buffers and move data in
    vertexBuffer = device->newBuffer(totalVertices * 3 * sizeof(float), MTL::ResourceStorageModePrivate);
    vertexBuffer->setLabel(NS::String::string("Scene vertex bufer", NS::UTF8StringEncoding));
 
    MTL::CommandBuffer* cmdBuffer = cmdQueue->commandBuffer();
    MTL::BlitCommandEncoder* encoder = cmdBuffer->blitCommandEncoder();
    
    size_t currentVertex = 0;
    size_t currentIndex = 0;
    std::vector<uint32_t> idxData(totalIndices);
    for (int i = 0; i < models.size(); i++) {
        const auto& model = models[i];
        
        encoder->copyFromBuffer(model->getVertexBuffer(),
                                0,
                                vertexBuffer,
                                currentVertex * 3 * sizeof(float),
                                model->getVertexCount() * 3 * sizeof(float));
        
        const std::vector<uint32_t> modelIndices = model->getIndices();
        for (int j = 0; j < modelIndices.size(); j++) {
            idxData[j + currentIndex] = modelIndices[j] + static_cast<uint32_t>(currentVertex);
        }
        
        currentVertex += model->getVertexCount();
        currentIndex += model->getTriangleCount() * 3;
    }
    
    encoder->endEncoding();
    cmdBuffer->commit();
    cmdBuffer->waitUntilCompleted();
    
    // Create index buffer
    indexBuffer = makePrivateBuffer(device, cmdQueue, idxData.data(), static_cast<uint32_t>(idxData.size() * sizeof(uint32_t)));
    indexBuffer->setLabel(NS::String::string("Scene index buffer", NS::UTF8StringEncoding));
    
    // Create material buffer
    materialBuffer = makePrivateBuffer(device, cmdQueue, materials.data(), static_cast<uint32_t>(materials.size() * sizeof(Material)));
    
    // Create instance data buffer
    instanceDataBuffer = makePrivateBuffer(device, cmdQueue, instanceDataVec.data(), static_cast<uint32_t>(instanceDataVec.size() * sizeof(InstanceData)));
    instanceDataBuffer->setLabel(NS::String::string("Scene instance index map", NS::UTF8StringEncoding));
}

MTL::Buffer* Scene::getVertexBuffer() const {
    return vertexBuffer;
}

MTL::Buffer* Scene::getIndexBuffer() const {
    return indexBuffer;
}

MTL::Buffer* Scene::getInstanceDataBuffer() const {
    return instanceDataBuffer;
}

const std::vector<TriangleAccelerationStructure>& Scene::getChildAccStructs() const {
    return childAccStructs;
}

const InstanceAccelerationStructure& Scene::getInstanceAccStruct() const {
    return *instanceAccStruct;
}
