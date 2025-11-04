#include "mtl_engine.hpp"

#include <stb/stb_image.h>

int main() {
    MTLEngine engine;
    engine.init();
    engine.run();
    engine.cleanup();

    return 0;
}
