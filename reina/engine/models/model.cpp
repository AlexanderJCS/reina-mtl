#include "model.hpp"

#include "buffers.hpp"

#define TINYOBJLOADER_IMPLEMENTATION
#include <tinyobjloader/tinyobjloader.h>

#include <unordered_map>
#include <iostream>
#include <vector>
#include <string>
#include <unordered_map>
#include <functional>   // std::hash
#include <cstddef>      // size_t

Model::Model(MTL::Device* device, MTL::CommandQueue* cmdQueue, const std::string& filepath) {
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
    
    std::vector<simd::float3> vertices(attrib.vertices.size() / 3);
    for (size_t i = 0; i < attrib.vertices.size(); i += 3) {
        vertices[i / 3] = simd::float3{attrib.vertices[i], attrib.vertices[i + 1], attrib.vertices[i + 2]};
    }
    
    std::vector<simd::float3> normals(attrib.normals.size() / 3);
    for (size_t i = 0; i < attrib.normals.size(); i += 3) {
        normals[i / 3] = simd::float3{attrib.normals[i], attrib.normals[i + 1], attrib.normals[i + 2]};
    }
    
    std::vector<simd::float2> texcoords(attrib.texcoords.size() / 2);
    for (size_t i = 0; i < attrib.texcoords.size(); i += 2) {
        texcoords[i / 2] = simd::float2{attrib.texcoords[i], attrib.texcoords[i + 1]};
    }
    
    buildVertexData(vertices, normals, texcoords, shape.mesh.indices);
    
    vertexBuffer = makePrivateBuffer(device, cmdQueue, finalVertices.data(), static_cast<uint32_t>(finalVertices.size() * sizeof(ModelVertexData)));
    indexBuffer = makePrivateBuffer(device, cmdQueue, finalIndices.data(), static_cast<uint32_t>(finalIndices.size() * sizeof(uint32_t)));
    
    vertexBuffer->setLabel(NS::String::string("Vertex Buffer", NS::UTF8StringEncoding));
    indexBuffer->setLabel(NS::String::string("Index Buffer", NS::UTF8StringEncoding));
    
    triangleCount = finalIndices.size() / 3;
    vertexCount = finalVertices.size() / 3;
}

void Model::buildVertexData(const std::vector<simd::float3>& vertices, const std::vector<simd::float3>& normals, const std::vector<simd::float2>& texcoords, const std::vector<tinyobj::index_t>& indices) {
    
    finalVertices = std::vector<ModelVertexData>{};
    finalIndices = std::vector<uint32_t>{};
    std::unordered_map<ModelVertexData, int, ModelVertexHash> idxMap;
    
    for (const tinyobj::index_t& idx : indices) {
        ModelVertexData vertex{
            .pos = vertices[idx.vertex_index],
            .normal = normals[idx.normal_index],
            .tangent = simd::float3(0),
            .uv = texcoords[idx.texcoord_index],
            .sign = 1
        };
        
        auto it = idxMap.find(vertex);
        if (it == idxMap.end()) {
            finalVertices.push_back(vertex);
            finalIndices.push_back(static_cast<uint32_t>(finalVertices.size() - 1));
            idxMap[vertex] = finalIndices.back();
        } else {
            finalIndices.push_back(it->second);
        }
    }
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
    return finalIndices;
}
