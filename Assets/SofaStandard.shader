Shader "SofaShader/Standard"
{
	Properties
	{
		[Space(20)][KeywordEnum(CookTorrance, Ashikhmin)] _Brdf("Brdf", Float) = 1

		[Header((RGB) Diffuse Texture)]		
		[HDR]_Color("Color", Color) = (1,1,1,1)
		_MainTex("Albedo", 2D) = "white"{}

		[Header((RGB)Secondary Diffuse Texture)]		
		_SecondaryTex("Secondary Texture", 2D) = "white"{}

		[Space(20)][Header(Normal Map)]
		[Toggle]_Bump("Use Normal Map", Float) = 0
		_BumpScale("Scale", Range(-10, 10)) = 1.0
		_BumpMap("Normal Map", 2D) = "bump" {}

		_DetailBumpScale("Detal Normal Scale", Range(-10, 10)) = 1.0

		[Space(20)][Header(Metallic(RGB) Roughness(A))]
		_Metallic("Metallic", Range(0, 1)) = 0		

		[Space(20)][Header(Roughness Extrapolation Control)]
		_RoughnessLow("Roughness Low", Float) = 0
		_RoughnessHigh("Roughness High", Float) = 1

		[Space(20)][Header(Retroreflectivity(RGB) Translucency(A))]
		_Retroreflectivity("Retro reflectivity", Range(0, 1)) = 0.5		
		_Translucency("Translucency", Range(0, 1)) = 0

		[Space(20)][KeywordEnum(Standard, Anisotropic)] _SpecularType("Specular Type", Float) = 0
		_RoughnessX("RoughnessX", Range(0.01, 1)) = 0.3
		_RoughnessY("RoughnessY", Range(0.01, 1)) = 0.01
		_Anisotropy("Anisotropic", Range(0, 1)) = 0
		
		_Specular("Surface Specular", Float) = 2	

		[Space(20)][Header(Directional Specular Color)]		
		[HDR]_SpecularColor("Directional light Specular Color", Color) = (1, 1, 1, 1)

		
		[Space(20)][Header(Emission)] 
		[Toggle]_Emission("Emission", Float) = 0
		[HDR]_EmissionColor("Color", Color) = (0,0,0)
		_EmissionMap("Emission", 2D) = "white" {}		
		
		_ReflMult("Reflection Mutliplier", Float) = 1
		_AmbientInfluence("Ambient Influence on Reflection", Range(0, 1)) = 0.1
		_ReflGamma("Reflection Gamma", Float) = 0
		
		[Space(20)][KeywordEnum(Off, Front, Back)] _BackFaceCull("Culling", Float) = 2

		_BrdfLUT("BRDF LUT", 2D) = "grey"{}
		
		[HideInInspector] _Mode("__mode", Float) = 0.0
		[HideInInspector] _SrcBlend("__src", Float) = 1.0
		[HideInInspector] _DstBlend("__dst", Float) = 0.0
		[HideInInspector] _ZWrite("__zw", Float) = 1.0  


	}
		 
	SubShader 
	{
		
		Tags
		{ 
			"RenderType" = "Opaque" 
			"PerformanceChecks" = "False"     
			"Queue" = "Geometry"
		}
 
		LOD 400
		Cull [_BackFaceCull]
		Blend[_SrcBlend][_DstBlend]
		ZWrite On
		Pass
		{
			Name "FORWARD"
			Tags{ "LightMode" = "ForwardBase" }

			CGPROGRAM
				
			#pragma target 3.0

			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog
					
			#pragma shader_feature _ _BUMP_ON
			#pragma multi_compile _BRDF_COOKTORRANCE _BRDF_ASHIKHMIN
			#pragma multi_compile _SPECULARTYPE_STANDARD _SPECULARTYPE_ANISOTROPIC

			#pragma vertex vert 
			#pragma fragment frag

			#include "StandardSupport.cginc"      

			ENDCG

		}
	}	

	Fallback "Diffuse"

	// CustomEditor "CustomStandardShaderEditor" 
}
