float InterleavedGradientNoise(float2 screenSpacePos)
{
    const float3 m = float3(0.06711056, 0.00583715, 52.9829189);
    float x = dot(screenSpacePos, m.xy);
    return frac(m.z * frac(x));
}

float SampleShadow(
    //config param
    float2 _ShadowSampleOffset,
    float _SurfaceSlopeDepthBiasFactor,
    float _ShadowProjectionDistanceFalloff, 
    //
    Texture2D shadowDepthMap,
    SamplerState shadowSamplerState,
    //input
    float3 shadowCoord,
    float3 shadowSpaceNormal,
    //float3 positionWS,
    float3 normalWS,
    float2 dither,
    float lambert
)
{
    const float2 o1 = (float2(-1, -1));
    const float2 o2 = (float2(1, -1));
    const float2 o3 = (float2(1, 1));
    const float2 o4 = (float2(-1, 1));
    const float2 o5 = (float2(-1, 0));
    const float2 o6 = (float2(1, 0));
    const float2 o7 = (float2(0, -1));
    const float2 o8 = (float2(0, 1));
    const float2 o9 = (float2(0, 0));
	const float perpendicular = (1 - abs(lambert));
    
    //projection distances
    float pd1 = shadowDepthMap.SampleLevel(shadowSamplerState, saturate(shadowCoord.xy + _ShadowSampleOffset * o1 * (perpendicular * 1 + dither * 1)), 0).x;
    float pd2 = shadowDepthMap.SampleLevel(shadowSamplerState, saturate(shadowCoord.xy + _ShadowSampleOffset * o2 * (perpendicular * 1 + dither * 1)), 0).x;
    float pd3 = shadowDepthMap.SampleLevel(shadowSamplerState, saturate(shadowCoord.xy + _ShadowSampleOffset * o3 * (perpendicular * 1 + dither * 1)), 0).x;
    float pd4 = shadowDepthMap.SampleLevel(shadowSamplerState, saturate(shadowCoord.xy + _ShadowSampleOffset * o4 * (perpendicular * 1 + dither * 1)), 0).x;
    float pd5 = shadowDepthMap.SampleLevel(shadowSamplerState, saturate(shadowCoord.xy + _ShadowSampleOffset * o5 * (perpendicular * 2 + dither * 2)), 0).x;
    float pd6 = shadowDepthMap.SampleLevel(shadowSamplerState, saturate(shadowCoord.xy + _ShadowSampleOffset * o6 * (perpendicular * 2 + dither * 2)), 0).x;
    float pd7 = shadowDepthMap.SampleLevel(shadowSamplerState, saturate(shadowCoord.xy + _ShadowSampleOffset * o7 * (perpendicular * 2 + dither * 2)), 0).x;
    float pd8 = shadowDepthMap.SampleLevel(shadowSamplerState, saturate(shadowCoord.xy + _ShadowSampleOffset * o8 * (perpendicular * 2 + dither * 2)), 0).x;
    float pd9 = shadowDepthMap.SampleLevel(shadowSamplerState, saturate(shadowCoord.xy + _ShadowSampleOffset * o9 * (perpendicular * 2 + dither * 2)), 0).x;
   
    
    float projectionDistance = (
		(pd1 - shadowCoord.z) +
		(pd2 - shadowCoord.z) +
		(pd3 - shadowCoord.z) +
		(pd4 - shadowCoord.z) +
		(pd5 - shadowCoord.z) +
		(pd6 - shadowCoord.z) +
		(pd7 - shadowCoord.z) +
		(pd8 - shadowCoord.z) +
		(pd9 - shadowCoord.z)
	);
    
    //depth bias for slope
	float bias = (1 - abs(lambert)) * _SurfaceSlopeDepthBiasFactor;
   
    float d1 = shadowDepthMap.SampleLevel(shadowSamplerState, saturate(shadowCoord.xy + _ShadowSampleOffset * o1 * dither * (projectionDistance + perpendicular) * 1), 0).x;
    float d2 = shadowDepthMap.SampleLevel(shadowSamplerState, saturate(shadowCoord.xy + _ShadowSampleOffset * o2 * dither * (projectionDistance + perpendicular) * 1), 0).x;
    float d3 = shadowDepthMap.SampleLevel(shadowSamplerState, saturate(shadowCoord.xy + _ShadowSampleOffset * o3 * dither * (projectionDistance + perpendicular) * 1), 0).x;
    float d4 = shadowDepthMap.SampleLevel(shadowSamplerState, saturate(shadowCoord.xy + _ShadowSampleOffset * o4 * dither * (projectionDistance + perpendicular) * 1), 0).x;
    float d5 = shadowDepthMap.SampleLevel(shadowSamplerState, saturate(shadowCoord.xy + _ShadowSampleOffset * o5 * dither * (projectionDistance + perpendicular) * 2), 0).x;
    float d6 = shadowDepthMap.SampleLevel(shadowSamplerState, saturate(shadowCoord.xy + _ShadowSampleOffset * o6 * dither * (projectionDistance + perpendicular) * 2), 0).x;
    float d7 = shadowDepthMap.SampleLevel(shadowSamplerState, saturate(shadowCoord.xy + _ShadowSampleOffset * o7 * dither * (projectionDistance + perpendicular) * 2), 0).x;
    float d8 = shadowDepthMap.SampleLevel(shadowSamplerState, saturate(shadowCoord.xy + _ShadowSampleOffset * o8 * dither * (projectionDistance + perpendicular) * 2), 0).x;
    float d9 = shadowDepthMap.SampleLevel(shadowSamplerState, saturate(shadowCoord.xy + _ShadowSampleOffset * o9 * dither * (projectionDistance + perpendicular) * 2), 0).x;
    
    //TODO:  handle Z direction
    d1 = step(d1, shadowCoord.z + bias);
    d2 = step(d2, shadowCoord.z + bias);
    d3 = step(d3, shadowCoord.z + bias);
    d4 = step(d4, shadowCoord.z + bias);
    d5 = step(d5, shadowCoord.z + bias);
    d6 = step(d6, shadowCoord.z + bias);
    d7 = step(d7, shadowCoord.z + bias);
    d8 = step(d8, shadowCoord.z + bias);
    d9 = step(d9, shadowCoord.z + bias);
    //float attenuation = 2;
    float s1 =
		(
		d1 * 1 + pow(pd1 - shadowCoord.z, 2) * _ShadowProjectionDistanceFalloff +
		d2 * 1 + pow(pd2 - shadowCoord.z, 2) * _ShadowProjectionDistanceFalloff +
		d3 * 1 + pow(pd3 - shadowCoord.z, 2) * _ShadowProjectionDistanceFalloff +
		d4 * 1 + pow(pd4 - shadowCoord.z, 2) * _ShadowProjectionDistanceFalloff +
		d9 * 1 + pow(pd5 - shadowCoord.z, 2) * _ShadowProjectionDistanceFalloff
		);
    float s2 =
		(
		d5 * 1 + pow(pd6 - shadowCoord.z, 2) * _ShadowProjectionDistanceFalloff +
		d6 * 1 + pow(pd7 - shadowCoord.z, 2) * _ShadowProjectionDistanceFalloff +
		d7 * 1 + pow(pd8 - shadowCoord.z, 2) * _ShadowProjectionDistanceFalloff +
		d8 * 1 + pow(pd9 - shadowCoord.z, 2) * _ShadowProjectionDistanceFalloff
		);

    float shadow = (s1 + s2) / 9;
    shadow = saturate(shadow);
    return shadow;
}