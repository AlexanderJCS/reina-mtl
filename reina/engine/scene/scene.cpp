#include "scene.hpp"

#include <set>
#include <iostream>

void Scene::addObject(const Object& object) {
    objects.push_back(std::make_unique<Object>(object));
}

void Scene::addMaterial(const Material& material) {
    materials.push_back(std::make_unique<Material>(material));
}

void Scene::build(MTL::Device* device, MTL::CommandQueue* cmdQueue) {
    createModelsVector();
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
    std::vector<MTL::AccelerationStructure*> accStructs(objects.size());
    std::vector<simd::float4x4> transforms(objects.size());
    for (int i = 0; i < objects.size(); i++) {
        int accStructIdx = modelIndices[i];
        accStructs[i] = childAccStructs[accStructIdx].getAccelerationStructure();
        transforms[i] = objects[i]->transform;
    }
    
    instanceAccStruct = std::make_unique<InstanceAccelerationStructure>(device, cmdQueue, accStructs, transforms);
}

void Scene::createModelsVector() {
    models = std::vector<std::shared_ptr<Model>>{};
    modelIndices = std::vector<int>{};
    
    for (const auto& obj : objects) {
        int insertionIdx = -1;
        
        bool found = false;
        for (int i = 0; i < models.size(); i++) {
            if (models[i].get() == obj->model.get()) {
                insertionIdx = i;
                found = true;
                break;
            }
        }
        
        if (!found) {
            insertionIdx = static_cast<int>(models.size());
            models.push_back(obj->model);
        }
        
        modelIndices.push_back(insertionIdx);
    }
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
    indexBuffer = device->newBuffer(totalIndices * sizeof(int), MTL::ResourceStorageModePrivate);
    indexBuffer->setLabel(NS::String::string("Scene index buffer", NS::UTF8StringEncoding));
    
    MTL::CommandBuffer* cmdBuffer = cmdQueue->commandBuffer();
    MTL::BlitCommandEncoder* encoder = cmdBuffer->blitCommandEncoder();
    
    size_t currentVertex = 0;
    size_t currentIndex = 0;
    for (int i = 0; i < models.size(); i++) {
        const auto& model = models[i];
        
        encoder->copyFromBuffer(model->getVertexBuffer(),
                                0,
                                vertexBuffer,
                                currentVertex * 3 * sizeof(float),
                                model->getVertexCount() * 3 * sizeof(float));
        
        encoder->copyFromBuffer(model->getIndexBuffer(),
                                0,
                                indexBuffer,
                                currentIndex * sizeof(int),
                                model->getTriangleCount() * 3 * sizeof(int));
        
        currentVertex += model->getVertexCount();
        currentIndex += model->getTriangleCount() * 3;
    }
    
    encoder->endEncoding();
    cmdBuffer->commit();
    cmdBuffer->waitUntilCompleted();
    
    // Final pass to construct the instanceIdxToIndexBufLocBuffer
    std::vector<int> instanceIdxMap(objects.size());
    for (int i = 0; i < objects.size(); i++) {
        instanceIdxMap[i] = static_cast<int>(modelIdxToIdxLoc[modelIndices[i]]);
    }
    
    instanceIdxMapBuffer = device->newBuffer(instanceIdxMap.data(), instanceIdxMap.size() * sizeof(int), MTL::ResourceStorageModeManaged);
}

MTL::Buffer* Scene::getVertexBuffer() const {
    return vertexBuffer;
}

MTL::Buffer* Scene::getIndexBuffer() const {
    return indexBuffer;
}

MTL::Buffer* Scene::getInstanceIdxMapBuffer() const {
    return instanceIdxMapBuffer;
}

const std::vector<TriangleAccelerationStructure>& Scene::getChildAccStructs() const {
    return childAccStructs;
}

const InstanceAccelerationStructure& Scene::getInstanceAccStruct() const {
    return *instanceAccStruct;
}
