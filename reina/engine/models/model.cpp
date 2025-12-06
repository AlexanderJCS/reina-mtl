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
    computeTBNs();
    
    vertexBuffer = makePrivateBuffer(device, cmdQueue, finalVertices.data(), static_cast<uint32_t>(finalVertices.size() * sizeof(ModelVertexData)));
    indexBuffer = makePrivateBuffer(device, cmdQueue, finalIndices.data(), static_cast<uint32_t>(finalIndices.size() * sizeof(uint32_t)));
    
    vertexBuffer->setLabel(NS::String::string("Vertex Buffer", NS::UTF8StringEncoding));
    indexBuffer->setLabel(NS::String::string("Index Buffer", NS::UTF8StringEncoding));
}

void Model::buildVertexData(const std::vector<simd::float3>& vertices, const std::vector<simd::float3>& normals, const std::vector<simd::float2>& texcoords, const std::vector<tinyobj::index_t>& indices) {
    
    finalVertices = std::vector<ModelVertexData>{};
    finalIndices = std::vector<uint32_t>{};
    std::unordered_map<ModelVertexData, int, ModelVertexHash> idxMap;
    
    for (const tinyobj::index_t& idx : indices) {
        simd::float2 texcoord = texcoords.size() == 0 ? simd::float2(0) : texcoords[idx.texcoord_index];
        
        ModelVertexData vertex{
            .pos = vertices[idx.vertex_index],
            .normal = normals[idx.normal_index],
            .tangent = simd::float3(0),
            .uv = texcoord,
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
    
    triangleCount = finalIndices.size() / 3;
    vertexCount = finalVertices.size();
}

void Model::computeTBNs() {
    SMikkTSpaceInterface mikkInterface = {
        .m_getNumFaces = getNumFaces,
        .m_getNumVerticesOfFace = getNumVerticesOfFace,
        .m_getPosition = getPosition,
        .m_getNormal = getNormal,
        .m_getTexCoord = getTexCoord,
        .m_setTSpaceBasic = setTSpaceBasic
    };
    
    SMikkTSpaceContext mikkContext{
        .m_pInterface = &mikkInterface,
        .m_pUserData = this
    };

    genTangSpaceDefault(&mikkContext);
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

const std::vector<uint32_t>& Model::getIndices() const {
    return finalIndices;
}
const std::vector<ModelVertexData>& Model::getVertices() const {
    return finalVertices;
}

int getNumFaces(const SMikkTSpaceContext* ctx) {
    Model* mesh = (Model*)ctx->m_pUserData;
    return static_cast<int>(mesh->getTriangleCount());
}

int getNumVerticesOfFace(const SMikkTSpaceContext* ctx, int face) {
    return 3; // Always triangles
}

void getPosition(const SMikkTSpaceContext* ctx, float fvPosOut[3], int face, int vert) {
    Model* mesh = (Model*)ctx->m_pUserData;
    uint32_t idx = mesh->getIndices()[face * 3 + vert];
    
    const std::vector<ModelVertexData>& vertices = mesh->getVertices();
    fvPosOut[0] = vertices[idx].pos.x;
    fvPosOut[1] = vertices[idx].pos.y;
    fvPosOut[2] = vertices[idx].pos.z;
}

void getNormal(const SMikkTSpaceContext* ctx, float fvNormOut[3], int face, int vert) {
    Model* mesh = (Model*)ctx->m_pUserData;
    uint32_t idx = mesh->getIndices()[face * 3 + vert];
    
    const std::vector<ModelVertexData>& vertices = mesh->getVertices();
    fvNormOut[0] = vertices[idx].normal.x;
    fvNormOut[1] = vertices[idx].normal.y;
    fvNormOut[2] = vertices[idx].normal.z;
}

void getTexCoord(const SMikkTSpaceContext* ctx, float fvTexcOut[2], int face, int vert) {
    Model* mesh = (Model*)ctx->m_pUserData;
    uint32_t idx = mesh->getIndices()[face * 3 + vert];
    
    const std::vector<ModelVertexData>& vertices = mesh->getVertices();
    fvTexcOut[0] = vertices[idx].uv.x;
    fvTexcOut[1] = vertices[idx].uv.y;
}

void setTSpaceBasic(const SMikkTSpaceContext* ctx, const float fvTangent[3], float fSign, int face, int vert) {
    Model* mesh = (Model*)ctx->m_pUserData;
    uint32_t idx = mesh->getIndices()[face * 3 + vert];
    
    std::vector<ModelVertexData>& vertices = mesh->finalVertices;  // this is a friend function so we cand o this
    vertices[idx].tangent = simd::float3{fvTangent[0], fvTangent[1], fvTangent[2]};
    vertices[idx].sign = fSign;
}
