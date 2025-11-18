#ifndef scene_hpp
#define scene_hpp

#include <vector>
#include <simd/simd.h>

#include "material.hpp"
#include "model.hpp"

struct Object {
    Model& model;
};

class Scene {
public:
    Scene();
    
    void addObject(const Object& object);
    void addMaterial(const Material& material);
    
    void build();
    
private:
    std::vector<Material> materials;
    std::vector<Object> objects;
};

#endif /* scene_hpp */
