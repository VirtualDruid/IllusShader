#pragma once
struct LightingInput
{
    float3 positionCS;
    float3 positionWS;
    float3 normalWS;
    bool isFrontFace;
};

struct MaterialInput
{
    
    float _IsDoubleSide;
    
    float _Alpha;
    float3 _BaseColor;
    float _RoughnessLinear;
    float _Metallic;
    
    float3 _EnvSpecularSample;
    //TextureCube _EnvSpecularTexture;
    //SamplerState sampler_EnvSpecularTexture;
    float _EnvSpecularRoughness;
    float _EnvSpecularFactor;
    
    float _ClearCoatMask;
    //float _ClearCoatMin;
    float _ClearCoatRoughnessLinear;
    
    float _Transmission;
    float _TransmissionChroma;
    float _TransmissionScatter;
    
    float3 _SheenColor;
    float _Sheen;
    float _Scatter;
    
    float _Anisotropic;
    float3 anisotropicAxisWS;
};

struct ShadowSamplingInput
{
    float _ShadowSampleOffset;
    float _ShadowSurfaceBiasFactor;
    float _ShadowProjectionDistanceFalloff;
    //Texture2D shadowDepthMap;
    SamplerState shadowSamplerState;
    //for temporal dithering
    float _Time;
};

