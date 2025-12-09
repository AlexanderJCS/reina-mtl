#include "random.h"

uint hash(uint x) {
    x ^= x >> 16;
    x *= 0x7feb352d;
    x ^= x >> 15;
    x *= 0x846ca68b;
    x ^= x >> 16;
    return x;
}

float rand(thread uint& seed) {
    /// Condensed version of pcg_output_rxs_m_xs_32_32, with simple conversion to floating-point [0,1].
    seed = seed * 747796405 + 1;
    uint word = ((seed >> ((seed >> 28) + 4)) ^ seed) * 277803737;
    word = (word >> 22) ^ word;
    return float(word) / 4294967295.0f;
}

float2 randomGaussian(thread uint& seed) {
    /// Function samples a gaussian distribution with sigma=1 around 0. Taken from: https://nvpro-samples.github.io/vk_mini_path_tracer/extras.html
    
    // Almost uniform in (0,1] - make sure the value is never 0:
    float u1 = max(1e-38, rand(seed));
    float u2 = rand(seed);  // In [0, 1]
    float r = sqrt(-2.0 * log(u1));
    float theta = 2 * M_PI_F * u2;  // Random in [0, 2pi]

    return r * float2(cos(theta), sin(theta));
}

float3 randFloat3(thread uint& seed) {
    return float3(rand(seed), rand(seed), rand(seed));
}

float3 randUnitFloat3(thread uint& seed) {
    while (true) {
        float3 p = randFloat3(seed) * 2 - 1;
        float lensq = dot(p, p);
        if (1e-8 < lensq && lensq <= 1) {
            return normalize(p);
        }
    }
}
