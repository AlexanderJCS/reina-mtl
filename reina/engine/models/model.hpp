#ifndef model_hpp
#define model_hpp

#include <Metal/Metal.hpp>
#include <QuartzCore/CAMetalLayer.hpp>
#include <simd/simd.h>
#include <cstdint>
#include <mikktspace/mikktspace.h>

#include <tinyobjloader/tinyobjloader.h>

#include "shared.hpp"

namespace MTL { class Device; class Buffer; }

int getNumFaces(const SMikkTSpaceContext* ctx);
int getNumVerticesOfFace(const SMikkTSpaceContext* ctx, int face);
void getPosition(const SMikkTSpaceContext* ctx, float fvPosOut[3], int face, int vert);
void getNormal(const SMikkTSpaceContext* ctx, float fvNormOut[3], int face, int vert);
void getTexCoord(const SMikkTSpaceContext* ctx, float fvTexcOut[2], int face, int vert);
void setTSpaceBasic(const SMikkTSpaceContext* ctx, const float fvTangent[3], float fSign, int face, int vert);

struct ModelVertexHash {
    size_t operator()(const ModelVertexData& v) const noexcept {
        auto h = std::hash<float>{};

        size_t seed = 0;
        auto combine = [&](float f) {
            seed ^= h(f) + 0x9e3779b97f4a7c15ULL + (seed << 6) + (seed >> 2);
        };

        combine(v.pos.x); combine(v.pos.y); combine(v.pos.z);
        combine(v.normal.x); combine(v.normal.y); combine(v.normal.z);
        combine(v.uv.x); combine(v.uv.y);
        combine(v.sign);

        return seed;
    }
};

class Model {
public:
    Model(MTL::Device* device, MTL::CommandQueue* cmdQueue, const std::string& filepath);

    [[nodiscard]] MTL::Buffer* getVertexBuffer() const;
    [[nodiscard]] MTL::Buffer* getIndexBuffer() const;
    [[nodiscard]] const std::vector<uint32_t>& getIndices() const;
    [[nodiscard]] const std::vector<ModelVertexData>& getVertices() const;
    [[nodiscard]] size_t getTriangleCount() const;
    [[nodiscard]] size_t getVertexCount() const;
    
    friend void setTSpaceBasic(const SMikkTSpaceContext* ctx, const float fvTangent[3], float fSign, int face, int vert);
    
private:
    // MikkTSpace Callback:
    void buildVertexData(const std::vector<simd::float3>& vertices, const std::vector<simd::float3>& normals, const std::vector<simd::float2>& texcoords, const std::vector<tinyobj::index_t>& indices);
    
    void computeTBNs();
    
    std::vector<uint32_t> finalIndices;
    std::vector<ModelVertexData> finalVertices;
    
    MTL::Buffer* vertexBuffer = nullptr;
    MTL::Buffer* indexBuffer = nullptr;
    size_t triangleCount = 0;
    size_t vertexCount = 0;
};

#endif /* model_hpp */
