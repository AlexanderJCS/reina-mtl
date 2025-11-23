#include "model.hpp"

#define TINYOBJLOADER_IMPLEMENTATION
#include <tinyobjloader/tinyobjloader.h>

#include <iostream>

Model::Model(MTL::Device* device, const std::string& filepath) {
    tinyobj::ObjReaderConfig readerConfig;
    tinyobj::ObjReader reader;
    if (!reader.ParseFromFile(filepath, readerConfig)) {
      if (!reader.Error().empty()) {
          std::cerr << "TinyObjReader: " << reader.Error();
      }
      exit(1);
    }
    
    auto& attrib = reader.GetAttrib();
    auto& shapes = reader.GetShapes();
    
    const tinyobj::shape_t& shape = shapes[0];
    
    vertexBuffer = device->newBuffer(
        attrib.vertices.data(),
        attrib.vertices.size() * sizeof(float),
        MTL::ResourceStorageModeShared
    );

    indices = std::vector<uint32_t>(shape.mesh.indices.size());
    for (int i = 0; i < shape.mesh.indices.size(); i++) {
        indices[i] = shape.mesh.indices[i].vertex_index;
    }
    
    indexBuffer = device->newBuffer(
        indices.data(),
        indices.size() * sizeof(uint32_t),
        MTL::ResourceStorageModeShared
    );
    
    triangleCount = indices.size() / 3;
    vertexCount = attrib.vertices.size() / 3;
}

MTL::Buffer* Model::getVertexBuffer() const {
    return vertexBuffer;
}

MTL::Buffer* Model::getIndexBuffer() const {
    return indexBuffer;
}

size_t Model::getTriangleCount() const {
    return triangleCount;
}

size_t Model::getVertexCount() const {
    return vertexCount;
}

const std::vector<uint32_t> Model::getIndices() const {
    return indices;
}
