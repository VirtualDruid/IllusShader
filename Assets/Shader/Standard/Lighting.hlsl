float3 cuberoot(float3 v)
{
    return sign(v) * pow(abs(v), 1.0f / 3.0f);
}

float3 toOklab(float3 lsrgb)
{
    const matrix<float, 3, 3> m1 =
    {
        0.4122214708f, 0.5363325363f, 0.0514459929f,
		0.2119034982f, 0.6806995451f, 0.1073969566f,
		0.0883024619f, 0.2817188376f, 0.6299787005f
    };
	/*
	0.4122214708f * c.r + 0.5363325363f * c.g + 0.0514459929f * c.b;
	0.2119034982f * c.r + 0.6806995451f * c.g + 0.1073969566f * c.b;
	0.0883024619f * c.r + 0.2817188376f * c.g + 0.6299787005f * c.b;
	*/
    const matrix<float, 3, 3> m2 =
    {
        0.2104542553f, 0.7936177850f, -0.0040720468f,
		1.9779984951f, -2.4285922050f, 0.4505937099f,
		0.0259040371f, 0.7827717662f, -0.8086757660f
    };
	/*
	 0.2104542553f*l_ + 0.7936177850f*m_ - 0.0040720468f*s_,
	 1.9779984951f*l_ - 2.4285922050f*m_ + 0.4505937099f*s_,
	 0.0259040371f*l_ + 0.7827717662f*m_ - 0.8086757660f*s_,
	*/

    float3 cbrt = mul(m2, cuberoot(mul(m1, lsrgb)));
    return cbrt;

}


float3 toLsrgb(float3 oklab)
{
    const matrix<float, 3, 3> m1 =
    {
        1.0f, 0.3963377774f, 0.2158037573f,
		1.0f, -0.1055613458f, -0.0638541728f,
		1.0f, -0.0894841775f, -1.2914855480f
    };
	/*
	c.L + 0.3963377774f * c.a + 0.2158037573f * c.b;
	c.L - 0.1055613458f * c.a - 0.0638541728f * c.b;
	c.L - 0.0894841775f * c.a - 1.2914855480f * c.b;
	*/
    const matrix<float, 3, 3> m2 =
    {
        4.0767416621f, -3.3077115913f, 0.2309699292f,
		-1.2684380046f, 2.6097574011f, -0.3413193965f,
		-0.0041960863f, -0.7034186147f, 1.7076147010f
    };
	/*
	+4.0767416621f * l - 3.3077115913f * m + 0.2309699292f * s,
	-1.2684380046f * l + 2.6097574011f * m - 0.3413193965f * s,
	-0.0041960863f * l - 0.7034186147f * m + 1.7076147010f * s,
	*/
    float3 p = mul(m1, oklab);
    p = p * p * p;
    float3 p3 = mul(m2, p);
    return p3;
}

float minNormalize(float x, float min)
{
    return x * (1 - min) + min;
}

//get concentrated distribution 0~1 based on cos(x)
float concentration(float rough, float cosx)
{
    float c = (cosx * cosx * (rough - 1) + 1);
	//XXX: if rough = 0, result is NaN, ggx has same issue
	[flatten]
    if (rough <= 0)
    {
        return 0;
    }
    return saturate((rough / c) - rough);
}

float3 halfway(float3 a, float3 b)
{
    return normalize(a + b);

}

float3 AnisotropicBentNormal(
    in float3 normalWS,
    //in float3 lightDir,
    //in float3 viewDir,
    in float3 dirWS,
    in float3 anisotropicAxisWS,
    in float _Anisotropic
    //out float3 bentNormalOut, 
    //out float3 envSpecularBentNormalOut
)
{
    
    //float3 halfwayVL = normalize(lightDir + viewDir);
    //simple axis-based tangent reconstruct
    float3 tangentDir = normalize(cross(anisotropicAxisWS, normalWS));
    //normal-defined plane
    float3 tangentPlane = dot(tangentDir, dirWS) * tangentDir;
    float3 bitangentDir = normalize(cross(tangentDir, normalWS));
    float3 bitangentPlane = dot(bitangentDir, dirWS) * bitangentDir;
    
    float3 anisoPlane = _Anisotropic <= 0 ? bitangentPlane : tangentPlane;
    //surface normal vs. anisotropic planar projection vector
    float3 anNormal = lerp(normalWS, normalize(dirWS - anisoPlane), abs(_Anisotropic));
    anNormal = length(anNormal) <= 0 ? 0 : normalize(anNormal);
    
    return anNormal;
}

void ImageBasedLighting(  
    in float inverseAbsFresnalFactor, 
    in float3 _BaseColor,
    in float3 _EnvSpecularSample,
    in float _EnvSpecularRoughness,
    in float _EnvSpecularFactor,
    in float _Metallic, 
    in float _ClearCoatPerceptual,
    in float3 _SheenColor,
    in float _Sheen,
    out float3 envSpecularOut)
{
    
    //float clearcoat = _ClearCoatMin + _ClearCoatMaskSample * _ClearCoatMask;
    //float si = smoothstep(0, 1, dot(specularSample , specularSample) * clearcoat * clearcoat / 3);
    float envIntensity = pow(dot(_EnvSpecularSample, _EnvSpecularSample) / 3, 0.5);
    float albedoIntensity = pow(dot(_BaseColor, _BaseColor) / 3, 0.5);
    float clearcoatIntensity = envIntensity * _ClearCoatPerceptual;
				//float3 sum = lerp(toOklab(specularSample * rf * albedoOnce), toOklab(albedoOnce), (1 - _Metallic) * (1 - _Roughness) + (_Roughness));
    float3 envSpecular = lerp(
        toOklab(albedoIntensity * _BaseColor), 
        toOklab(_EnvSpecularSample * pow(_BaseColor, _Metallic * (1 - _ClearCoatPerceptual * _Metallic))), 
        minNormalize(saturate(inverseAbsFresnalFactor * (1 - _EnvSpecularRoughness)), saturate(_Metallic + clearcoatIntensity))
    );
    
    //assume sheen on top of clearcoat
    envSpecular = lerp(envSpecular, toOklab(_SheenColor * envIntensity), (_Sheen * inverseAbsFresnalFactor));
    
    envSpecularOut = toLsrgb(envSpecular) * _EnvSpecularFactor;
    return;
				
}


void DirectLighting(
    in float distanceAttenuation,
    in float shadow, 
    in float3 normal,
    in float3 lightDir,
    in float3 viewDir,
    //
    in float3 lightColor, 
    in float3 lightColorPerceptual,
    //
    in float _IsDoubleSide,
    in float3 _BaseColorPerceptual,
    in float3 _BaseColorA2Perceptual,
    //
    in float _RoughnessPerceptual,
    in float _Metallic,
    in float _ClearCoatMask,
    //in float _ClearCoatMin,
    in float _ClearCoatRoughnessPerceptual,
    in float _Transmission,
    in float _TransmissionChroma,
    in float _TransmissionScatter,
    //
    in float3 _SheenColorPerceptual,
    in float _Sheen,
    //
    in float _Scatter,
    //
    in float _Anisotropic, 
    in float3 _AnisotropicAxisWS,
    //output
    out float3 diffuseOut,
    out float3 specularOut,
    out float3 clearCoatSpecularOut,
    out float3 transmissionOut
)
{
    //const float _RoughnessPerceptual = _RoughnessLinear * _RoughnessLinear;
    
    //const float _ClearCoatRoughnessPerceptual = _ClearCoatRoughnessLinear * _ClearCoatRoughnessLinear;
    
    const float _Smoothness = 1 - _RoughnessPerceptual;
    const float _Dereflective = 1 - _Metallic;
    
       
    float lambert = dot(normal, lightDir);
    float lambertFactor = saturate(lambert);
    float inverseLambertFactor = 1 - lambertFactor;
    float fresnal = dot(normal, viewDir);
    float fresnalFactor = saturate(fresnal);
    //XXX: inverseAbsFresnalFactor is for double side single face (no cull)
    float inverseAbsFresnalFactor = 1 - abs(fresnal);
    float inverseFresnalFactor = saturate(1 - fresnal);
    float3 halfwayVL = normalize(viewDir + lightDir);
    
    
    ////simple axis-base tangent reconstruction
    //float3 tangentDir = normalize(cross(_AnisotropicAxis, normal));
    ////normal-defined plane
    //float3 tangentPlane = dot(tangentDir, halfwayVL) * tangentDir;
    //float3 bitangentDir = normalize(cross(tangentDir, normal));
    //float3 bitangentPlane = dot(bitangentDir, halfwayVL) * bitangentDir;
    //
    //float3 anisoPlane = _Anisotropic <= 0 ? bitangentPlane : tangentPlane;
    ////surface normal vs. anisotropic planar projection vector
    //float3 anNormal = lerp(normal, normalize(halfwayVL - anisoPlane), abs(_Anisotropic));
    float3 anNormal = AnisotropicBentNormal(normal, halfwayVL, _AnisotropicAxisWS, _Anisotropic);
    
    float specularNH = saturate(dot(anNormal, halfwayVL));
    
    float specularFactor = concentration(_RoughnessPerceptual, specularNH);
    float3 transmissionChroma = toLsrgb(lerp(float3(1, _BaseColorPerceptual.yz), float3(1, lightColorPerceptual.yz), _TransmissionChroma.xxx));
    float islmb = saturate(-lambert);
    float ts = minNormalize(fresnalFactor * islmb * islmb, islmb * islmb);
    float3 transmission = (transmissionChroma)
					* pow((transmissionChroma) * _Transmission, minNormalize(inverseFresnalFactor + 1 - islmb, (1 - _Transmission)) * 2)
					* lerp(ts, minNormalize(shadow * ts, _TransmissionScatter), islmb);
    //float shadowing = lerp(minNormalize(lambertFactor, _Scatter), shadow, lambertFactor);
    
    float clearcoat = _ClearCoatMask;
    
    float clearcoatSpecular = concentration(_ClearCoatRoughnessPerceptual * clearcoat, specularNH) * _ClearCoatMask;
    
    float3 diffuseColor = lerp(_BaseColorA2Perceptual, _BaseColorPerceptual, lambertFactor);
    diffuseColor = lerp(diffuseColor, _SheenColorPerceptual, inverseAbsFresnalFactor * _Sheen);
    
    
	float lsh = lerp(minNormalize(lambertFactor, _Scatter), shadow, lambertFactor);
    
    //float3 specularColor = ;
    float intensity = pow(dot(lightColor * distanceAttenuation, lightColor * distanceAttenuation) / 3, 0.5);
    diffuseOut = toLsrgb(diffuseColor) * saturate(_Dereflective + _RoughnessPerceptual + intensity * 0.3) * lightColor * lsh * distanceAttenuation;
    specularOut = specularFactor * lightColor * lerp(lambertFactor, 1, _IsDoubleSide) * shadow * distanceAttenuation;
    transmissionOut = transmission * distanceAttenuation;
    clearCoatSpecularOut = clearcoatSpecular * lerp(lambertFactor, 1, _IsDoubleSide) * shadow * distanceAttenuation;
    
    return;
    
}

//void DirectLighting(
//    LightingInput lightingInput,
//    MaterialInput materialInput,
//    out float3 diffuseOut,
//    out float3 specularOut,
//    out float3 clearCoatSpecularOut,
//    out float3 transmissionOut
//)
//{
//    DirectLighting(
//         lightingInput.distanceAttenuation,
//         lightingInput.shadow,
//         lightingInput.normal,
//         lightingInput.lightDir,
//         lightingInput.viewDir,
//         lightingInput.lightColor,
//         lightingInput.lightColorPerceptual,
//    
//         materialInput._IsDoubleSide,
//         materialInput._BaseColorPerceptual,
//         materialInput._BaseColorA2Perceptual,
//         materialInput._RoughnessPerceptual,
//         materialInput._Metallic,
//         materialInput._ClearCoat,
//         materialInput._ClearCoatMin,
//         materialInput._ClearCoatRoughnessPerceptual,
//         materialInput._Transmission,
//         materialInput._TransmissionChroma,
//         materialInput._TransmissionScatter,
//         materialInput._SheenColorPerceptual,
//         materialInput._Sheen,
//         materialInput._Scatter,
//         materialInput._Anisotropic,
//         materialInput._AnisotropicAxisWS,
//    
//         diffuseOut,
//         specularOut,
//         clearCoatSpecularOut,
//         transmissionOut
//    );
//    return;
//
//}


