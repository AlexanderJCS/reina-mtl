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

    std::vector<uint32_t> indexArray;
    indexArray.reserve(shape.mesh.indices.size());

    for (const auto& idx : shape.mesh.indices) {
        indexArray.push_back(static_cast<uint32_t>(idx.vertex_index));
    }
    
    indexBuffer = device->newBuffer(
        indexArray.data(),
        indexArray.size() * sizeof(uint32_t),
        MTL::ResourceStorageModeShared
    );
    
    triangleCount = indexArray.size() / 3;
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
