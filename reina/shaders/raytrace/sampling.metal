//#include <metal_stdlib>
//using namespace metal;
//
//float evalR0(float ior) {
//    return (ior - 1) * (ior - 1) / ((ior + 1) * (ior + 1));
//}
//
//float luminance(float3 color) {
//    return dot(color, float3(0.2126, 0.7152, 0.0722));
//}
//
//float3 evalFm(float3 baseColor, float3 h, float3 wo, float specular, float3 specularTint, float metallic, float eta) {
//    float lum = luminance(baseColor);
//    float3 ctint = lum > 0.0 ? baseColor / lum : float3(1);
//    float3 ks = (1 - ctint) + specularTint * ctint;
//    float3 c0 = specular * evalR0(eta) * (1 - metallic) * ks + metallic * baseColor;
//
//    return c0 + (1 - c0) * pow(1 - abs(dot(h, wo)), 5);
//}
//
//float evalDm(float3 hl, float alphax, float alphay) {
//    float k = (M_PI_F * alphax * alphay);
//    float otherTerm = pow(pow(hl.x, 2) / pow(alphax, 2) + pow(hl.y, 2) / pow(alphay, 2) + pow(hl.z, 2), 2);
//
//    return 1 / (k * otherTerm);
//}
//
//float lambda(float3 wl, float alphax, float alphay) {
//    float sqrtTerm = sqrt(1 + (pow(wl.x * alphax, 2) + pow(wl.y * alphay, 2)) / pow(wl.z, 2));
//    return (sqrtTerm - 1) / 2;
//}
//
//float smithG(float3 wl, float alphax, float alphay) {
//    // wl is in tangent space
//    return 1 / (1 + lambda(wl, alphax, alphay));
//}
//
//float evalGm(float3 wi, float3 wo, float alphax, float alphay) {
//    float g1 = smithG(wi, alphax, alphay);
//    float g2 = smithG(wo, alphax, alphay);
//    return g1 * g2;
//}
//
//float3 evalMetal(float3x3 tbn, float3 baseColor, float anisotropic, float roughness, float3 n, float3 wi, float3 wo, float3 h, float specular, float3 specularTint, float metallic, float eta) {
//    const float alphamin = 0.0001;
//
//    float aspect = sqrt(1.0 - 0.9 * anisotropic);
//    float alphax = max(alphamin, roughness * roughness / aspect);
//    float alphay = max(alphamin, roughness * roughness * aspect);
//
//    float3 fm = evalFm(baseColor, h, wo, specular, specularTint, metallic, eta);
//
//    float3 wiTangent = normalize(float3(transpose(tbn) * wi));
//    float3 woTangent = normalize(float3(transpose(tbn) * wo));
//    float3 hTangent = normalize(float3(transpose(tbn) * h));
//
//    float dm = evalDm(hTangent, alphax, alphay);
//    float gm = evalGm(wiTangent, woTangent, alphax, alphay);
//
//    float NdotWi = abs(dot(n, wi));
//    float NdotWo = abs(dot(n, wo));
//
//    return fm * dm * gm / (4.0 * NdotWi * NdotWo);
//}
//
//float3 sampleMetal(float3x3 tbn, float3 baseColor, float anisotropic, float roughness, vec3 n, float3 wi, thread uint& rngState) {
//    // TODO: reused computation between sampling and evaluation should be eliminated
//    const float alphamin = 0.0001;
//
//    float aspect = float(sqrt(1 - 0.9 * anisotropic));
//    float alphax = max(alphamin, roughness * roughness / aspect);
//    float alphay = max(alphamin, roughness * roughness * aspect);
//
//    float3 wiTangent = float3(transpose(tbn) * wi);
//    float3 h = sampleGGXVNDF(wiTangent, alphax, alphay, rngState);
//
//    // transform h back to world space
//    h = normalize(float3(tbn * h));
//    float3 wo = reflect(-wi, h);
//
//    return wo;
//}
//
//float pdfMetal(float3x3 tbn, float3 wi_world, float3 wo_world, float anisotropic, float roughness) {
//    const float alpha_min = 1e-4;
//    float aspect = sqrt(1.0 - 0.9 * anisotropic);
//    float alphax = max(alpha_min, roughness*roughness / aspect);
//    float alphay = max(alpha_min, roughness*roughness * aspect);
//
//    float3 wiTangent = float3(transpose(tbn) * wi_world);
//    float3 woTangent = float3(transpose(tbn) * wo_world);
//
//    float3 alpha = float2(alphax, alphay);
//
//    return pdfGGXReflection(wiTangent, woTangent, alpha);
//}
