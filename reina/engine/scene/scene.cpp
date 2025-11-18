#include "scene.hpp"

#include <set>

void Scene::addObject(const Object& object) {
    // TODO: these need to be shared ptrs
    objects.push_back(object);
}

void Scene::addMaterial(const Material& material) {
    materials.push_back(material);
}

void Scene::build() {
//    std::vector<Model*> models;
//    std::vector<int> modelIndices;
//    
//    for (const Object& obj : objects) {
//        int insertionIdx = -1;
//        
//        bool found = false;
//        for (int i = 0; i < models.size(); i++) {
//            if (models[i] == &obj.model) {
//                insertionIdx = i;
//                found = true;
//                break;
//            }
//        }
//        
//        if (!found) {
//            insertionIdx = models.size();
//            models.push_back(&obj.model);
//        }
//    }
//    
//    
}
