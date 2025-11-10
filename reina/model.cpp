#include "model.hpp"

Model::Model(MTL::Device* device) {
    float vertices[] = {
        0.0f, 0.0f, 1.0f,
        1.0f, 0.0f, 1.0f,
        0.0f, 1.0f, 1.0f
    };
    
    int indices[] = {
        0, 1, 2
    };
    
    vertexBuffer = device->newBuffer(&vertices, sizeof(vertices), MTL::ResourceStorageModeShared);
    indexBuffer = device->newBuffer(&indices, sizeof(indices), MTL::ResourceStorageModeShared);
    triangleCount = sizeof(indices) / sizeof(int) / 3;
}

MTL::Buffer* Model::getVertexBuffer() const {
    return vertexBuffer;
}

MTL::Buffer* Model::getIndexBuffer() const {
    return indexBuffer;
}

int Model::getTriangleCount() const {
    return triangleCount;
}
