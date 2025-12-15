#include "sampling.h"

#include <metal_stdlib>
using namespace metal;

#include "random.h"

float3 sampleGGXVNDF(float3 V, float ax, float ay, thread uint& rngState) {
    bool flip = V.z < 0.0;

    if (flip) {
        V.z *= -1;
    }

    float r1 = rand(rngState);
    float r2 = rand(rngState);

    // https://github.com/knightcrawler25/GLSL-PathTracer/blob/291c1fdc3f97b2a2602c946b41cecca9c3092af7/src/shaders/common/sampling.glsl#L70
    float3 Vh = normalize(float3(ax * V.x, ay * V.y, V.z));

    float lensq = Vh.x * Vh.x + Vh.y * Vh.y;
    float3 T1 = lensq > 0 ? float3(-Vh.y, Vh.x, 0) * (1 / sqrt(lensq)) : float3(1, 0, 0);
    float3 T2 = cross(Vh, T1);

    float r = sqrt(r1);
    float phi = 2.0 * M_PI_F * r2;
    float t1 = r * cos(phi);
    float t2 = r * sin(phi);
    float s = 0.5 * (1.0 + Vh.z);
    t2 = (1.0 - s) * sqrt(1.0 - t1 * t1) + s * t2;

    float3 Nh = t1 * T1 + t2 * T2 + sqrt(max(0.0, 1.0 - t1 * t1 - t2 * t2)) * Vh;

    if (flip) {
        Nh.z *= -1;
    }

    return normalize(float3(ax * Nh.x, ay * Nh.y, max(0.0, Nh.z)));
}

float D_GGX_Aniso(float3 m, float alphax, float alphay) {
    float NoM = max(m.z, 0.0);
    float Tm  = m.x;
    float Bm  = m.y;
    float inv = 1.0 / ((Tm / alphax) * (Tm / alphax) + (Bm / alphay) * (Bm / alphay) + NoM * NoM);
    return inv * inv / (M_PI_F * alphax * alphay);
}

float D(float3 m, float2 alpha) {
    // anisotropic form:
    return D_GGX_Aniso(m, alpha.x, alpha.y);
}

float pdfGGXReflection(float3 i, float3 o, float2 alpha) {
    // https://dl.acm.org/doi/10.1145/3610543.3626163

    float3 m = normalize(i + o);
    float ndf = D(m, alpha );
    float2 ai = alpha * i.xy ;
    float len2 = dot(ai, ai);
    float t = sqrt(len2 + i.z * i.z);
    if (i.z >= 0.0) {
        float a = saturate(min(alpha .x, alpha.y)); // Eq . 6
        float s = 1.0 + length(float2(i.x, i.y)); // Omit sgn for a <=1
        float a2 = a * a; float s2 = s * s;
        float k = (1.0 - a2 ) * s2 / ( s2 + a2 * i.z * i.z); // Eq . 5
        return ndf / (2.0 * (k * i.z + t)); // Eq . 8 * || dm / do ||
    }

    // Numerically stable form of the previous PDF for i.z < 0
    return ndf * (t - i.z) / (2.0 * len2); // = Eq . 7 * || dm / do ||
}

float evalR0(float ior) {
    return (ior - 1) * (ior - 1) / ((ior + 1) * (ior + 1));
}

float luminance(float3 color) {
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

float3 evalFm(float3 baseColor, float3 h, float3 wo) {
    return baseColor + (1 - baseColor) * pow(1 - abs(dot(h, wo)), 5);
}

float evalDm(float3 hl, float alphax, float alphay) {
    float k = (M_PI_F * alphax * alphay);
    float otherTerm = pow(pow(hl.x, 2) / pow(alphax, 2) + pow(hl.y, 2) / pow(alphay, 2) + pow(hl.z, 2), 2);

    return 1 / (k * otherTerm);
}

float lambda(float3 wl, float alphax, float alphay) {
    float sqrtTerm = sqrt(1 + (pow(wl.x * alphax, 2) + pow(wl.y * alphay, 2)) / pow(wl.z, 2));
    return (sqrtTerm - 1) / 2;
}

float smithG(float3 wl, float alphax, float alphay) {
    // wl is in tangent space
    return 1 / (1 + lambda(wl, alphax, alphay));
}

float evalGm(float3 wi, float3 wo, float alphax, float alphay) {
    float g1 = smithG(wi, alphax, alphay);
    float g2 = smithG(wo, alphax, alphay);
    return g1 * g2;
}

float3 evalMetal(float3x3 tbn, float3 baseColor, float anisotropic, float roughness, float3 n, float3 wi, float3 wo, float3 h) {
    const float alphamin = 0.0001;

    float aspect = sqrt(1.0 - 0.9 * anisotropic);
    float alphax = max(alphamin, roughness * roughness / aspect);
    float alphay = max(alphamin, roughness * roughness * aspect);

    float3 fm = evalFm(baseColor, h, wo);

    float3 wiTangent = normalize(float3(transpose(tbn) * wi));
    float3 woTangent = normalize(float3(transpose(tbn) * wo));
    float3 hTangent = normalize(float3(transpose(tbn) * h));

    float dm = evalDm(hTangent, alphax, alphay);
    float gm = evalGm(wiTangent, woTangent, alphax, alphay);

    float NdotWi = abs(wiTangent.z);
    float NdotWo = abs(woTangent.z);

    return fm * dm * gm / (4.0 * NdotWi * NdotWo);
}

float3 sampleMetal(float3x3 tbn, float anisotropic, float roughness, float3 wi, thread uint& rngState) {
    // TODO: reused computation between sampling and evaluation should be eliminated
    const float alphamin = 0.0001;

    float aspect = float(sqrt(1 - 0.9 * anisotropic));
    float alphax = max(alphamin, roughness * roughness / aspect);
    float alphay = max(alphamin, roughness * roughness * aspect);

    float3 wiTangent = float3(transpose(tbn) * wi);
    float3 h = sampleGGXVNDF(wiTangent, alphax, alphay, rngState);

    // transform h back to world space
    h = normalize(float3(tbn * h));
    float3 wo = reflect(-wi, h);

    return wo;
}

float pdfMetal(float3x3 tbn, float3 wi_world, float3 wo_world, float anisotropic, float roughness) {
    const float alpha_min = 1e-4;
    float aspect = sqrt(1.0 - 0.9 * anisotropic);
    float alphax = max(alpha_min, roughness*roughness / aspect);
    float alphay = max(alpha_min, roughness*roughness * aspect);

    float3 wiTangent = float3(transpose(tbn) * wi_world);
    float3 woTangent = float3(transpose(tbn) * wo_world);

    float2 alpha = float2(alphax, alphay);

    return pdfGGXReflection(wiTangent, woTangent, alpha);
}
