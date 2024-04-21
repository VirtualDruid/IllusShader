Shader "Celluloid/LitOpaque"
{
	Properties
	{

		_IsDoubleSide("_IsDoubleSide", Range(0, 1)) = 0
		[MainTexture] _BaseColorTexture("Base Color Texture", 2D) = "white" {}
		[MainColor] _BaseColor("Base Color", Color) = (1,1,1,1)

		_RoughnessMetallicEnvRoughnessTexture("_RoughnessMetallicEnvRoughnessTexture", 2D) = "white" {}

		_Roughness("_Roughness", Range(0, 1)) = 0
		_Metallic("_Metallic", Range(0.04, 1)) = 1

		[Normal] _NormalTexture("Normal Texture", 2D) = "bump" {}
		_EnvSpecularTexture("_EnvSpecularTexture", Cube) = "white" {}
		_EnvSpecularColor("_EnvSpecularColor", Color) = (1,1,1,1)
		_EnvSpecularRoughness("_EnvSpecularRoughness", Range(0,1)) = 1
		_EnvSpecularFactor("_EnvSpecularFactor", Range(0,1)) = 1
		_EnvSpecularExposure("_EnvSpecularExposure", Range(-10,10)) = 0

		_EmissiveTexture("_EmissiveTexture", 2D) = "white" {}
		_Emissive("_Emissive", Color) = (0,0,0,0)

		//_ClearCoatMin("_ClearCoatMin", Range(0,1)) = 0
		_ClearCoatTexture("_ClearCoatTexture", 2D) = "white" {}
		_ClearCoatMask("_ClearCoatMask", Range(0,1)) = 0
		_ClearCoatRoughness("_ClearCoatRoughness", Range(0,1)) = 0

		_TransmissionTexture("_TransmissionTexture", 2D) = "white" {}
	   	_Transmission("_Transmission", Range(0,1)) = 0
	        _TransmissionChroma("_TransmissionChroma", Range(0,1)) = 0
	        _TransmissionScatter("_TransmissionScatter", Range(0,1)) = 0

		_Scatter("_Scatter", Range(0,1)) = 0

		_Anisotropic("_Anisotropic", Range(-1,1)) = 0
		_AnisotropicAxis("_AnisotropicAxis", Vector) = (0,1,0,0)

		_SheenTexture("SheenTexture", 2D) = "white" {}
		_SheenColor("_SheenColor", Color) = (0,0,0,0)
		_Sheen("_Sheen", Range(0, 1)) = 0
		
		_Cull("__cull", Float) = 2.0

	}

		SubShader
		{
			Tags {
			      "RenderType" = "Opaque"
			      "RenderPipeline" = "UniversalPipeline"
			      "UniversalMaterialType" = "Lit"
			      "IgnoreProjector" = "True"
			}
			LOD 300

			//@ShadowCaster
			Pass
			{
				Name "ShadowCaster"
			    Tags
			    {
				    "LightMode" = "ShadowCaster"
			    }

			    ZWrite On
			    ZTest LEqual
			    Cull [_Cull]

			    HLSLPROGRAM
			    
				#pragma vertex VertexShaderEntry
				#pragma fragment PixelShaderEntry

				#pragma shader_feature_local_fragment _AlphaClip


				
				
				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
				//#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"


				#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"

				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
				cbuffer c {
					float3 _LightDirection;
					float3 _LightPosition;
				};
				
				struct VertexAttribute
				{
					float3 vertex : POSITION;
					float2 uv : TEXCOORD0;
					float3 normal : NORMAL;
					float4 tangent : TANGENT;
					float2 texcoord : TEXCOORD0;

				};
				struct VertexShaderOutput
				{
					float3 vertex: TEXCOORD0;
					float2 uv : TEXCOORD1;
					float4 positionCS : SV_Position;
					float3 normal : TEXCOORD2;
				};
				VertexShaderOutput VertexShaderEntry(VertexAttribute v) {
					VertexShaderOutput o;
					VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
					VertexNormalInputs normalInput = GetVertexNormalInputs(v.normal, v.tangent);
					o.vertex = vertexInput.positionWS;
					o.normal = normalInput.normalWS;
					o.uv = v.uv;

					#if _CASTING_PUNCTUAL_LIGHT_SHADOW
					float3 lightDirectionWS = normalize(_LightPosition - positionWS);
					#else
					float3 lightDirectionWS = _LightDirection;
					#endif
					o.positionCS = TransformWorldToHClip(ApplyShadowBias(o.vertex, o.normal, lightDirectionWS));
					//o.positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
					return o;
				}

				float4 PixelShaderEntry(VertexShaderOutput vo) : SV_Target{
					
					#ifdef _AlphaClip
					clip(colorSample.a - _Cutoff);
					#endif
					return 0;
				}
			    ENDHLSL

		    }//@ShadowCaster


			//@ForwardLit
			Pass
			{
				Name "ForwardLit"
				Tags
				{
					"LightMode" = "UniversalForward"
				}
				//Blend One Zero
				Cull[_Cull]
				ZTest LEqual
				ZWrite On
			    HLSLPROGRAM
			    
			    #pragma target 5.0
			    #pragma shader_feature_local_fragment _AlphaClip
			    
			    //#pragma shader_feature_local_fragment _ALPHATEST_ON
			    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			    #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
			    #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
			    #pragma multi_compile_fragment _ _SHADOWS_SOFT
			    #pragma vertex VertexShaderEntry
			    #pragma fragment PixelShaderEntry
			    
			    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			    
			    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
			    
			    #include "MaterialConstantBuffer.hlsl"
			    #include "VertexAttribute.hlsl" 
			    #include "RenderPipeline/ForwardPlus.hlsl"
			    
			    
			    VertexShaderOutput VertexShaderEntry(VertexAttribute v)
			    {
			    	VertexShaderOutput o;
			    	VertexPositionInputs vertexInput = GetVertexPositionInputs(v.positionOS.xyz);
			    	VertexNormalInputs normalInput = GetVertexNormalInputs(v.normalOS, v.tangentOS);
			    	o.positionWS = vertexInput.positionWS;
			    	o.uv = v.uv;
			    	o.tangentWS = float4(normalInput.tangentWS.xyz, GetOddNegativeScale() * v.tangentOS.w);
			    	o.normalWS = normalInput.normalWS;
			    	o.positionCS = vertexInput.positionCS;
			    	return o;
			    }
			    void PixelShaderEntry(VertexShaderOutput i, in bool isFrontFace: SV_IsFrontFace, out float4 forwardOutput : SV_Target0) {
			    
			    	//const float4 colorSample = SAMPLE_TEXTURE2D(_BaseColorTexture, sampler_BaseColorTexture, i.uv);
			    	//float3 _Color = colorSample.rgb * _BaseColor;
			    	//
			    	//#ifdef _AlphaClip
			    	//clip(colorSample.a - _Cutoff);
			    	//#endif
			    
			    	i.normalWS = normalize(i.normalWS);
			    	//const float3 _Color = colorSample.rgb;
			    	//i.normalTS = normalize(i.normalTS);
			    	//i.tangentWS.xyz = normalize(i.tangentWS.xyz);
			    	float3 tangentWS = normalize(i.tangentWS.xyz);
			    	float3 bitangentWS = (cross(i.normalWS, tangentWS)) * i.tangentWS.w;
			    	matrix<float, 3, 3> tangentToWorld = matrix<float, 3, 3>(tangentWS, bitangentWS, i.normalWS);
			    	float4 nst = SAMPLE_TEXTURE2D(_NormalTexture, sampler_NormalTexture, i.uv);
			    	float3 normalSampleTS = UnpackNormal(nst);
			    
			    	//XXX: only need TS and ttw
			    	i.normalWS = SafeNormalize(mul(normalSampleTS, tangentToWorld));
			    	//i.normalTS = normalize(i.normalTS);
			    
			    	const float3 anisotropicAxisWS = TransformObjectToWorldDir(_AnisotropicAxis);
			    
			    	//SampleMaterial();
			    	LightingInput linput = (LightingInput) 0;
			    	linput.positionCS = i.positionCS;
			    	linput.positionWS = i.positionWS;
			    	linput.normalWS = i.normalWS;
			    	linput.isFrontFace = isFrontFace;
			    	MaterialInput minput = SampleMaterial(i.uv, anisotropicAxisWS, GetWorldSpaceNormalizeViewDir(i.positionWS), i.normalWS);
			    	ShadowSamplingInput sinput;
			    	sinput._ShadowSampleOffset = (4.0 / 4096.0);
			    	sinput._ShadowSurfaceBiasFactor = 0.01;
			    	sinput._ShadowProjectionDistanceFalloff = 4;
			    	sinput._Time = _Time.xx;
			    	//sinput.shadowDepthMap = _MainLightShadowmapTexture;
			    	sinput.shadowSamplerState = _linear_clamp_sampler;
			    	float3 diffuse, specular, clearcoat, transmission, envSpecular;
			    	//float4 _dbg;
			    	Forward(linput, minput, sinput, diffuse, specular, clearcoat, transmission, envSpecular);
			    	forwardOutput = float4(diffuse + specular + clearcoat + transmission + envSpecular + minput._Emissive , 1);
			    	//forwardOutput = minput._Alpha;
			    	//forwardOutput = _dbg;
			    	//forwardOutput = i.normalWS.xyzx;
			    }
			    ENDHLSL
		}//@ForwardLit

		}
		FallBack "Hidden/Universal Render Pipeline/FallbackError"
		//CustomEditor "UnityEditor.Rendering.Universal.ShaderGUI.LitShader"
}
