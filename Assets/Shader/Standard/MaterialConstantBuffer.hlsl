#include "LightingInput.hlsl"
cbuffer UnityPerMaterial
{
    
    float _IsDoubleSide;
    //4 channel
    Texture2D _BaseColorTexture;
    SamplerState sampler_BaseColorTexture;
    float4 _BaseColor;
    
    float _Roughness;
    float _Metallic;
    
    Texture2D _NormalTexture;
    SamplerState sampler_NormalTexture;
    
    TextureCube _EnvSpecularTexture;
    SamplerState sampler_EnvSpecularTexture;
    
    float3 _EnvSpecularColor;
    float _EnvSpecularRoughness;
    float _EnvSpecularFactor;
    float _EnvSpecularExposure;
    
    //3 channel
    Texture2D _RoughnessMetallicEnvRoughnessTexture;
    SamplerState sampler_RoughnessMetallicEnvRoughnessTexture;
    
    
    //float _ClearCoatMin;
    float _ClearCoatMask;
    float _ClearCoatRoughness;
    
    float _Scatter;
    
        
    float _Anisotropic;
    float3 _AnisotropicAxis;
    
    
    //3 channel
    Texture2D _TransmissionTexture;
    SamplerState sampler_TransmissionTexture;
    float _Transmission;
    float _TransmissionChroma;
    float _TransmissionScatter;
    
    
    //4 channel
    Texture2D _SheenTexture;
    SamplerState sampler_SheenTexture;
    
    float3 _SheenColor; 
    float _Sheen;
    

    
	SamplerState _linear_clamp_sampler;
	
};


float PerceptualRoughnessToMipmapLevel(float perceptualRoughness, uint maxMipLevel)
{
    perceptualRoughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);

    return perceptualRoughness * maxMipLevel;
}

//duplicate to remove redifinition here
float3 AnisotropicNormal(
    in float3 normalWS,
    in float3 dirWS,
    in float3 anisotropicAxisWS,
    in float _Anisotropic
)
{
    
    //float3 halfwayVL = normalize(lightDir + viewDir);
    //dirWS = normalize(dirWS);
    
    //simple axis-based tangent reconstruct
    float3 tangentDir = normalize(cross(anisotropicAxisWS, normalWS));
    //normal-defined plane
    float3 tangentPlane = dot(tangentDir, dirWS) * tangentDir;
    float3 bitangentDir = normalize(cross(normalWS, tangentDir));
    float3 bitangentPlane = dot(bitangentDir, dirWS) * bitangentDir;
    float3 anisoPlane = _Anisotropic <= 0 ? bitangentPlane : tangentPlane;
    //surface normal vs. anisotropic planar projection vector
    float3 anNormal = (lerp(normalWS, normalize(dirWS - anisoPlane), abs(_Anisotropic)));
    anNormal = length(anNormal) <= 0 ? 0 : normalize(anNormal);
    
    return anNormal;
}
//frag only
MaterialInput SampleMaterial(
    float2 uv,
    float3 anisotropicAxisWS,
    float3 viewDir,
    float3 normalWS
)
{
    MaterialInput input;
    
    float4 baseColorSample = _BaseColorTexture.Sample(sampler_BaseColorTexture, uv);
    #ifdef _AlphaClip
    clip(baseColor.a - _AlphaClipCutoff);
    #endif
    input._Alpha = baseColorSample.a * _BaseColor.a;
    input._IsDoubleSide = _IsDoubleSide;
    input._BaseColor = baseColorSample.rgb * _BaseColor.rgb;
    float3 roughnessMetallicEnvRoughness = _RoughnessMetallicEnvRoughnessTexture.Sample(sampler_RoughnessMetallicEnvRoughnessTexture, uv).xyz;
    input._RoughnessLinear = _Roughness * roughnessMetallicEnvRoughness.r;
    input._Metallic = _Metallic * roughnessMetallicEnvRoughness.g;
    
    //input._ClearCoatMin = _ClearCoatMin;
    
    input._ClearCoatMask = _ClearCoatMask;
    input._ClearCoatRoughnessLinear = _ClearCoatRoughness;\
    
    input._Scatter = _Scatter;
    
    
    float3 transmissionTexture = _TransmissionTexture.Sample(sampler_TransmissionTexture, uv).xyz;
    input._Transmission = _Transmission * transmissionTexture.r;
    input._TransmissionChroma = _TransmissionChroma * transmissionTexture.g;
    input._TransmissionScatter = _TransmissionScatter * transmissionTexture.b;
    
    
    float4 sheenTexture = _SheenTexture.Sample(sampler_SheenTexture, uv);
    input._SheenColor = _SheenColor * sheenTexture.rgb;
    input._Sheen = _Sheen * sheenTexture.a;
    
    
    input._Anisotropic = _Anisotropic;
    
    input.anisotropicAxisWS = anisotropicAxisWS;
    
    float3 minusViewDir = -viewDir;
    float3 sampleDir = reflect(minusViewDir, AnisotropicNormal(normalWS, minusViewDir, anisotropicAxisWS, input._Anisotropic));
    input._EnvSpecularSample = _EnvSpecularTexture.SampleLevel(
        sampler_EnvSpecularTexture, 
        sampleDir, 
        PerceptualRoughnessToMipmapLevel(_EnvSpecularRoughness, 6)).xyz 
    * _EnvSpecularFactor 
    * _EnvSpecularColor
    * pow(2, _EnvSpecularExposure);
    
    input._EnvSpecularRoughness = _EnvSpecularRoughness * roughnessMetallicEnvRoughness.b;
    input._EnvSpecularFactor = _EnvSpecularFactor;
    
    
    return input;

}