#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

#include "../Lighting.hlsl"
#include "../LightingInput.hlsl"
#include "../Shadow.hlsl"


//half AdditionalLightRealtimeShadow(int lightIndex, float3 positionWS, half3 lightDirection)
//{
//    #if defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS)
//    ShadowSamplingData shadowSamplingData = GetAdditionalLightShadowSamplingData(lightIndex);
//
//    half4 shadowParams = GetAdditionalLightShadowParams(lightIndex);
//
//    int shadowSliceIndex = shadowParams.w;
//    if (shadowSliceIndex < 0)
//        return 1.0;
//
//    half isPointLight = shadowParams.z;
//
//    UNITY_BRANCH
//    if (isPointLight)
//    {
//        // This is a point light, we have to find out which shadow slice to sample from
//        float cubemapFaceId = CubeMapFaceID(-lightDirection);
//        shadowSliceIndex += cubemapFaceId;
//    }
//
//    #if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
//        float4 shadowCoord = mul(_AdditionalLightsWorldToShadow_SSBO[shadowSliceIndex], float4(positionWS, 1.0));
//    #else
//        float4 shadowCoord = mul(_AdditionalLightsWorldToShadow[shadowSliceIndex], float4(positionWS, 1.0));
//    #endif
//
//    return SampleShadowmap(TEXTURE2D_ARGS(_AdditionalLightsShadowmapTexture, sampler_LinearClampCompare), shadowCoord, shadowSamplingData, shadowParams, true);
//    #else
//        return half(1.0);
//    #endif
//}

float _CubeMapFaceID(float3 dir)
{
    float faceID;

    if (abs(dir.z) >= abs(dir.x) && abs(dir.z) >= abs(dir.y))
    {
        faceID = (dir.z < 0.0) ? 5 : 4;
    }
    else if (abs(dir.y) >= abs(dir.x))
    {
        faceID = (dir.y < 0.0) ? 3 : 2;
    }
    else
    {
        faceID = (dir.x < 0.0) ? 1 : 0;
    }

    return faceID;
}


void Forward(

    in float3 positionCS,
    in float3 positionWS,
    in float3 normalWS,
    in bool isFrontFace,
    //
    in float _IsDoubleSide,
    in float3 _BaseColor,
    in float _RoughnessLinear,
    in float _Metallic,
    in float3 _EnvSpecularSample,
    in float _EnvSpecularRoughness,
    in float _EnvSpecularFactor,
    in float _ClearCoatMask,
    //in float _ClearCoatMin,
    in float _ClearCoatRoughnessLinear,
    in float _Transmission,
    in float _TransmissionChroma,
    in float _TransmissionScatter,
    in float3 _SheenColor,
    in float _Sheen,
    in float _Scatter,

    in float _Anisotropic,
    in float3 anisotropicAxisWS,

    //shadow
    in float _ShadowSampleOffset,
    in float _ShadowSurfaceBiasFactor,
    in float _ShadowProjectionDistanceFalloff,
    //in Texture2D shadowDepthMap,
    in SamplerState shadowSamplerState,
    in float _Time,
    
    //out
    out float3 diffuseOut, 
    out float3 specularOut,
    out float3 clearcoatSpecularOut,
    out float3 transmissionOut,
    out float3 envSpecularOut
    //out float4 _dbg
)
{

    #if defined(DEBUG_DISPLAY)
    half4 debugColor;

    if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
    {
        return debugColor;
    }
    #endif

    //BRDFData brdfDataClearCoat = CreateClearCoatBRDFData(surfaceData, brdfData);
    //float4 shadowMask = CalculateShadowMask(inputData);
    //AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    // MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    /* lightingData.giColor = GlobalIllumination(brdfData, brdfDataClearCoat, surfaceData.clearCoatMask,
                                              inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS,
                                              inputData.normalWS, inputData.viewDirectionWS, inputData.normalizedScreenSpaceUV);
    */
    
    //_dbg = 0;
    
    float3 diffuseAcc = 0;
    float3 specularAcc = 0;
    float3 clearcoatSpecularAcc = 0;
    float3 transmissionAcc = 0;

    //pre-convert to perceptual color space
    const float3 _BaseColorPerceptual = toOklab(_BaseColor);
    const float3 _BaseColorPerceptualA2 = toOklab(_BaseColor * _BaseColor);
    
    const float3 _SheenColorPerceptual = toOklab(_SheenColor);
    
    const float _RoughnessPerceptual = _RoughnessLinear * _RoughnessLinear;
    
    //_ClearCoatMin + clearCoatMaskSample * _ClearCoatMask;
    float _ClearCoatPerceptual = _ClearCoatMask * _ClearCoatMask;
    //_ClearCoatPerceptual *= _ClearCoatPerceptual;
    const float _ClearCoatRoughnessPerceptual = _ClearCoatRoughnessLinear * _ClearCoatRoughnessLinear;
    
    const float ditherAmount = 2.5;
    
    float tdi = frac(InterleavedGradientNoise(positionCS.xy + frac(_Time) * 600)) * 2 - 1;
    
  
    float3 viewDir = GetWorldSpaceNormalizeViewDir(positionWS);
    
    //const float fresnal = dot(viewDir, normalWS);
    //const float fresnalFactor = saturate(fresnal);
    //const float inverseFresnalFactor = saturate(1-fresnal);
    //uint meshRenderingLayers = GetMeshRenderingLayer();
    Light mainLight = GetMainLight();
    
    #ifdef _LIGHT_LAYERS
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    #endif
    {
        
            
        float3 specular;
        float3 diffuse;
        float3 clearCoatSpecular;
        float3 transmission;
        
        
        float3 shadowCoord = TransformWorldToShadowCoord(positionWS).xyz;
        float3 shadowSpaceNormal = TransformWorldToShadowCoord(positionWS + normalWS).xyz - shadowCoord.xyz;
        float2 dither = shadowSpaceNormal.xy + tdi * ditherAmount.xx;
        
        float lambert = dot(mainLight.direction, normalWS);
        float shadow = SampleShadow(
            _ShadowSampleOffset,
            _ShadowSurfaceBiasFactor,
            _ShadowProjectionDistanceFalloff,
            // 
            _MainLightShadowmapTexture,
            shadowSamplerState,
            //input
            shadowCoord,
            shadowSpaceNormal,
            normalWS,
            dither,
            lambert
        );
        
        float3 dir = normalize(viewDir + mainLight.direction);
       // float3 an = AnisotropicBentNormal(normalWS, dir, anisotropicAxisWS, _Anisotropic);
        const float3 lightColorPerceptual = toOklab(mainLight.color);
        
        DirectLighting(
            mainLight.distanceAttenuation,
            shadow,
            normalWS,
            mainLight.direction,
            viewDir,
            
            mainLight.color,
            lightColorPerceptual,
        
            _IsDoubleSide,
            
            _BaseColorPerceptual,
            _BaseColorPerceptualA2,
        
            _RoughnessPerceptual,
            _Metallic,
        
            _ClearCoatPerceptual,
            //_ClearCoatMin,
            _ClearCoatRoughnessPerceptual,
        
            _Transmission,
            _TransmissionChroma,
            _TransmissionScatter,
            
            _SheenColorPerceptual,
            _Sheen,
        
            _Scatter,
        
            _Anisotropic,    
            anisotropicAxisWS,
            
            specular,
            diffuse,
            clearCoatSpecular,
            transmission
        );
        
        diffuseAcc += diffuse;
        specularAcc += specular;
        clearcoatSpecularAcc += clearCoatSpecular;
        transmissionAcc += transmission;
        
    }

    //--#ADDITIONAL_LIGHTS#--
    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();


    //----@if USE_FORWARD_PLUS----
    
   
    #if USE_FORWARD_PLUS
    for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK

        Light secondaryLight = GetAdditionalLight(lightIndex, positionWS);
        
        #ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(secondaryLight.layerMask, meshRenderingLayers))
        #endif
        {
            float3 specular;
            float3 diffuse;
            float3 clearCoatSpecular;
            float3 transmission;
    
            float3 lightColorPerceptual = toOklab(secondaryLight.color);
            float4 shadowParams = GetAdditionalLightShadowParams(lightIndex);
    
            //float3 shadowCoord = TransformWorldToShadowCoord(positionWS);
	        
            
            //TODO: additional shadow
            float shadow = 0;
            if(shadowParams.w < 0){
                shadow = 1; 
            } else {
                float faceId = 0;
                if(shadowParams.z > 0){
                     faceId = _CubeMapFaceID(-secondaryLight.direction);
                }
                float4 shadowCoord = mul(_AdditionalLightsWorldToShadow[shadowParam.w + faceId], float4(positionWS, 1.0));
                float3 shadowSpaceNormal = mul(_AdditionalLightsWorldToShadow[shadowParams.w + faceId], float4(positionWS + normalWS, 1.0)).xyz 
                                           - shadowCoord.xyz;
                float2 dither = shadowSpaceNormal.xy + tdi * ditherAmount.xx;
                float lambert = dot(secondaryLight.direction, normalWS);
                shadow = SampleShadow(
                    _ShadowSampleOffset,
                    _ShadowSurfaceBiasFactor,
                    _ShadowProjectionDistanceFalloff,
                    //input 
                    _AdditionalLightsShadowmapTexture,
                    shadowSamplerState,
                    shadowCoord,
                    shadowSpaceNormal,
                    normalWS,
                    dither,
                    lambert
                );
               
    
            }
          
           
            //float3 an = AnisotropicBentNormal(normalWS, dir, anisotropicAxisWS, _Anisotropic);
            
    
           float3 dir = normalize(viewDir + secondaryLight.direction);
           float3 an = AnisotropicBentNormal(normalWS, dir, anisotropicAxisWS, _Anisotropic);
           DirectLighting(
                secondaryLight.distanceAttenuation,
                shadow,
                normalWS,
                secondaryLight.direction,
                viewDir,
                
                secondaryLight.color,
                lightColorPerceptual,
            
                _IsDoubleSide,
                
                _BaseColorPerceptual,
                _BaseColorPerceptualA2,
            
                _RoughnessPerceptual,
                _Metallic,
            
                _ClearCoatPerceptual,
                //_ClearCoatMin,
                _ClearCoatRoughnessPerceptual,
            
                _Transmission,
                _TransmissionChroma,
                _TransmissionScatter,
                
                _SheenColorPerceptual,
                _Sheen,
            
                _Scatter,
            
                _Anisotropic,    
                anisotropicAxisWS,
                
                specular,
                diffuse,
                clearCoatSpecular,
                transmission
            );
    
            diffuseAcc += diffuse;
            specularAcc += specular;
            clearcoatSpecularAcc += clearCoatSpecular;
            transmissionAcc += transmission;
        }
    }
    #endif
    //----@if USE_FORWARD_PLUS----

    
    //clustered loop
    
    //----@clustered----
    LIGHT_LOOP_BEGIN(pixelLightCount)
        //FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK
    
        Light secondaryLight = GetAdditionalLight(lightIndex, positionWS);

        #ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(secondaryLight.layerMask, meshRenderingLayers))
        #endif
        {
           float3 specular;
           float3 diffuse;
           float3 clearCoatSpecular;
           float3 transmission;
    
           float3 lightColorPerceptual = toOklab(secondaryLight.color);
           float4 size = _AdditionalShadowmapSize;
           float4 shadowParams = _AdditionalShadowParams[lightIndex];
           float4 additionalShadowCoord = 0;
           float additionalShadow = 0;
           if(shadowParams.w < 0) 
           {
                additionalShadow = 1; 
           }
           else 
           {
                float faceId = 0;
                //XXX: dither sampling, falloff cause issue when across cube faces
                float factor = 1;
                if(shadowParams.z){
                     faceId = _CubeMapFaceID(-secondaryLight.direction);
                     factor = 0;           
                }
                additionalShadowCoord = mul(_AdditionalLightsWorldToShadow[(shadowParams.w + faceId)], float4(positionWS, 1.0));
                
                float4 shadowSpaceNormal = mul(_AdditionalLightsWorldToShadow[(shadowParams.w + faceId)], float4(positionWS + normalWS, 1.0))
                            - additionalShadowCoord;
                additionalShadowCoord.xyz /= additionalShadowCoord.w;
                
                float2 dither = shadowSpaceNormal.xy + tdi * ditherAmount.xx;
                float lambert = dot(secondaryLight.direction, normalWS);
                additionalShadow = SampleShadow(
                    _ShadowSampleOffset * 16,
                    _ShadowSurfaceBiasFactor,
                    _ShadowProjectionDistanceFalloff * factor,
                    //input 
                    _AdditionalLightsShadowmapTexture,
                    shadowSamplerState,
                    additionalShadowCoord.xyz,
                    shadowSpaceNormal.xyz,
                    normalWS,
                    dither * factor,
                    lambert
                );
                if(additionalShadowCoord.z <= 0 || additionalShadowCoord.z >= 1.0)
                {
                    additionalShadow = 1;
                }
                //additionalShadow = secondaryLight.shadowAttenuation;
    
            }
        
           float3 dir = normalize(viewDir + secondaryLight.direction);
           float3 an = AnisotropicBentNormal(normalWS, dir, anisotropicAxisWS, _Anisotropic);
           
           DirectLighting(
                secondaryLight.distanceAttenuation,
                additionalShadow,
                normalWS,
                secondaryLight.direction,
                viewDir,
                
                secondaryLight.color,
                lightColorPerceptual,
            
                _IsDoubleSide,
                
                _BaseColorPerceptual,
                _BaseColorPerceptualA2,
            
                _RoughnessPerceptual,
                _Metallic,
            
                _ClearCoatPerceptual,
                //_ClearCoatMin,
                _ClearCoatRoughnessPerceptual,
            
                _Transmission,
                _TransmissionChroma,
                _TransmissionScatter,
                
                _SheenColorPerceptual,
                _Sheen,
            
                _Scatter,
            
                _Anisotropic,    
                anisotropicAxisWS,
                
                specular,
                diffuse,
                clearCoatSpecular,
                transmission
            );
    
            diffuseAcc += diffuse;
            //diffuseAcc += additionalShadowCoord.w;
            specularAcc += specular;
            clearcoatSpecularAcc += clearCoatSpecular;
            transmissionAcc += transmission;
            
        }
    LIGHT_LOOP_END
    //----@clustered----

    #endif
    //--#ADDITIONAL_LIGHTS#--
    
    float3 envSpecularAcc = 0;
    
    //float3 minusViewDir = -viewDir;
    //float3 sampleDir = reflect(minusViewDir, AnisotropicBentNormal(normalWS, minusViewDir, anisotropicAxisWS, _Anisotropic));
    //float3 _EnvSpecularSample = _EnvSpecularTexture.SampleLevel(sampler_EnvSpecularTexture, sampleDir, PerceptualRoughnessToMipmapLevel(_EnvSpecularRoughness, 6)).xyz;
    //float inverseAbsFresnalFactor = ;
    ImageBasedLighting(
        (1 - abs(dot(viewDir, normalWS))),
        _BaseColor,
        _EnvSpecularSample,
        _EnvSpecularRoughness,
        _EnvSpecularFactor,
        _Metallic,
        _ClearCoatPerceptual,
        _SheenColor,
        _Sheen,
        envSpecularAcc
    );
    
    diffuseOut = diffuseAcc;
    specularOut = specularAcc;
    clearcoatSpecularOut = clearcoatSpecularAcc;
    transmissionOut = transmissionAcc;
    envSpecularOut = envSpecularAcc;


    return;

}

void Forward(
    in LightingInput lightingInput,
    in MaterialInput materialInput,
    in ShadowSamplingInput shadowSamplingInput,
    out float3 diffuseOut,
    out float3 specularOut,
    out float3 clearcoatSpecularOut,
    out float3 transmissionOut,
    out float3 envSpecularOut
    //out float4 _dbg
)
{
    Forward(
         lightingInput.positionCS,
         lightingInput.positionWS,
         lightingInput.normalWS,
         lightingInput.isFrontFace,
         //
         materialInput._IsDoubleSide,
    
         materialInput._BaseColor,
         materialInput._RoughnessLinear,
         materialInput._Metallic,
    
         materialInput._EnvSpecularSample,
         materialInput._EnvSpecularRoughness,
         materialInput._EnvSpecularFactor,
    
         materialInput._ClearCoatMask,
         //materialInput._ClearCoatMin,
         materialInput._ClearCoatRoughnessLinear,
    
         materialInput._Transmission,
         materialInput._TransmissionChroma,
         materialInput._TransmissionScatter,
    
         materialInput._SheenColor,
         materialInput._Sheen,
         materialInput._Scatter,
    
         materialInput._Anisotropic,
         materialInput.anisotropicAxisWS,
         //
         shadowSamplingInput._ShadowSampleOffset,
         shadowSamplingInput._ShadowSurfaceBiasFactor,
         shadowSamplingInput._ShadowProjectionDistanceFalloff,
         //shadowSamplingInput.shadowDepthMap,
         shadowSamplingInput.shadowSamplerState,
         shadowSamplingInput._Time,
         //
         diffuseOut, 
         specularOut,
         clearcoatSpecularOut,
         transmissionOut,
         envSpecularOut
         //_dbg
    );
    return;

}