#ifndef _CUSTOM_STANDARD_SUPPORT_INCLUDED_
#define _CUSTOM_STANDARD_SUPPORT_INCLUDED_

#include "UnityStandardCore.cginc"
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"		

#ifdef UNITY_COLORSPACE_GAMMAclip
#define DIELECTRIC_CONSTANT 0.3
#else
#define DIELECTRIC_CONSTANT 0.08
#endif

struct v2f
{
	float4 pos					: SV_POSITION;
	half4 uv_MainTex			: TEXCOORD0;
	half3 vWorldNormal			: TEXCOORD1;
	half3 vViewDir				: TEXCOORD2;
	half4 ambientOrLightmapUV	: TEXCOORD3;
	half4 vWorldPos				: TEXCOORD4;
	half3 vWorldTangent			: TEXCOORD5;
	half3 vWorldBinormal		: TEXCOORD6;
	UNITY_FOG_COORDS(7)
	UNITY_SHADOW_COORDS(8)
	half2 uv2					: COLOR0;
};

sampler2D _DetailBumpMap;
sampler2D _SecondaryTex;

half _DetailBumpScale;
half4 _SecondaryTex_ST;


v2f vert(appdata_full v)
{
	v2f o;
	UNITY_INITIALIZE_OUTPUT(v2f, o);

	o.uv_MainTex.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
	o.uv_MainTex.zw = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
	o.uv2 = TRANSFORM_TEX(v.texcoord, _SecondaryTex);

	o.pos = UnityObjectToClipPos(v.vertex);
	o.vWorldPos = mul(unity_ObjectToWorld, v.vertex);

	o.vWorldNormal = UnityObjectToWorldNormal(v.normal);

#if _BUMP_ON || _SPECULARTYPE_ANISOTROPIC
	o.vWorldTangent = normalize((mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0))).xyz);
	o.vWorldBinormal = normalize(cross(o.vWorldNormal, o.vWorldTangent) * v.tangent.w);
#endif

	float4 vWorldPos = o.vWorldPos;
	o.vViewDir = (vWorldPos - _WorldSpaceCameraPos.xyz);
	
	UNITY_TRANSFER_FOG(o, o.pos);
	UNITY_TRANSFER_SHADOW(o, v.texcoord1);

	return o;
}	


sampler2D _BrdfLUT;
sampler2D _RetroreflectivityMask;

half _RoughnessLow, _RoughnessHigh;
half _Specular;
half _ReflGamma;
half4 _SpecularColor;
half _ReflMult;

half _AmbientInfluence;
half _Retroreflectivity;
half _Translucency;

half _RoughnessX;
half _RoughnessY;

struct MaterialParams
{
	half3 albedo;
	half metallic;
	half roughness;
	half specular;
	half retroReflectivity;
	half translucency;
};

float GGXSpecCustom(half NoH, half roughness)
{
	float a = roughness * roughness;
	float a2 = a * a;
	float d = NoH * NoH * (a2 - 1.f) + 1.f;
	return a2 / (UNITY_PI * d * d);
}

float D_GGXCustom(half Roughness, half NoH)
{
	float ggx = min(40, max(0, GGXSpecCustom(NoH, Roughness)));
	return ggx;
}

inline half3 EnvBRDFApproxCustom(half3 SpecularColor, half Roughness, half NoV)
{
	// [ Lazarov 2013, "Getting More Physical in Call of Duty: Black Ops II" ]
	// Adaptation to fit our G term.
	const half4 c0 = { -1, -0.0275, -0.572, 0.022 };
	const half4 c1 = { 1, 0.0425, 1.04, -0.04 };
	half4 r = Roughness * c0 + c1;
	half a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
	half2 AB = half2(-1.04, 1.04) * a004 + r.zw;

	return SpecularColor * AB.x + AB.y;
}

float SpecularDistRetro(float NoH, float a2)
{
	a2 = max(a2, 0.01);
	float ct2 = NoH * NoH;
	float st2 = 1.0001 - ct2;
	float st4 = st2*st2;
	float cot2 = ct2 / st2;

	return (1 + 4 * exp(-cot2 / a2) / st4) / (4 * a2 + 1);
}

float3 SpecularFresnel(float3 RF0, float vDotH)
{
	return RF0 + (1 - RF0) * pow(1 - vDotH, 5);
}

float D_GGXAnisotropic(float ToH, float BoH, float NoH, float roughnessT, float roughnessB)
{
	float ToH2 = ToH * ToH;
	float BoH2 = BoH * BoH;
	float NoH2 = NoH * NoH;
	float roughnessT2 = roughnessT * roughnessT;
	float roughnessB2 = roughnessB * roughnessB;

	float f = (ToH2 / roughnessT2) + (BoH2 / roughnessB2) + NoH2;
	return 1.0 / (roughnessT * roughnessB * f * f);
}

half3 FresnelSchlickRoughness(float cosTheta, half3 F0, float roughness)
{
	half smoothness = 1 - roughness;
	return F0 + (max(smoothness.xxx, F0) - F0) * pow(1.0 - cosTheta, 5.0);
}

half3 GetSpecularRetroReflectiveBRDF(half3 specularColor, half VoH, half NoH, half retroReflectivity)
{
	return SpecularFresnel(specularColor, VoH) * SpecularDistRetro(NoH, retroReflectivity);
}

half3 GetEnvRetroReflectiveBRDF(half3 specularColor, half NoV, half retroReflectivity, half roughness)
{
	half3 F = FresnelSchlickRoughness(max(NoV, 0.0), specularColor, roughness);
	half2 envBRDF = tex2D(_BrdfLUT, half2(max(NoV, 0.0), roughness)).rg;
	return saturate(F * envBRDF.x + envBRDF.y) * SpecularDistRetro(NoV, retroReflectivity);	
}

inline half3 CalcLighting(half3 vWorldNormal, half3 vNormal, half3 vViewDir, half3 vWorldPos, half atten, MaterialParams params, half3 ambientLight, half3 tangentDir, half3 bitangentDir, half3 lightDir)
{
	half3 albedo = params.albedo;
	half metallic = params.metallic;
	half roughness = params.roughness;

	half nonMetal = 1 - metallic;
	half3 diffuse = albedo * nonMetal;
	half dielectricSpecular = DIELECTRIC_CONSTANT * params.specular;
	half3 specularColor = (dielectricSpecular * nonMetal) + albedo * metallic;		
	half3 origSpecColor = specularColor;

	half3 negViewDir = normalize(-vViewDir);
	half NoV = max(dot(vNormal, negViewDir), 0);
	half NoV1 = max(dot(vNormal, normalize(vViewDir)), 0);

	half NoL = max(0, dot(vNormal, lightDir.xyz));
	half NoL1 = max(0, dot(-vWorldNormal, lightDir.xyz)) * params.translucency;	

	half3 H = normalize(lightDir.xyz + negViewDir);
	half NoH = max(0, dot(vNormal, H));

#if _SPECULARTYPE_ANISOTROPIC
	half ToH = dot(tangentDir, H);
	half BoH = dot(bitangentDir, H);
	half spec = D_GGXAnisotropic(ToH, BoH, NoH, _RoughnessX, _RoughnessY);
#else
	half spec = D_GGXCustom(roughness + 0.05, NoH) * UNITY_PI;
#endif

#ifdef UNITY_COLORSPACE_GAMMA
	spec = sqrt(max(1e-4h, spec));
#endif

	spec = max(0, spec * NoL);	

	half VoH = saturate(dot(negViewDir, H));	

	half3 H1 = normalize(lightDir.xyz + vNormal);
	half NoH1 = max(0, dot(vNormal, H1));

	params.retroReflectivity = max(params.retroReflectivity, 0.01);

	#if _BRDF_COOKTORRANCE
		specularColor = (EnvBRDFApproxCustom(specularColor, roughness, NoV));
	#endif

	#if _BRDF_ASHIKHMIN
		specularColor = GetSpecularRetroReflectiveBRDF(specularColor, VoH, NoH, params.retroReflectivity);
	#endif

	half3 dirSpec = spec * _LightColor0.rgb * atten * specularColor;

	half3 vRefl = (reflect(vViewDir, vNormal));

	half3 env = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, vRefl, roughness);
	env = lerp(env, env * env, _ReflGamma) * _ReflMult;	
	
	half3 ambient = 0;

#if UNITY_SHOULD_SAMPLE_SH
	ambient += ShadeSHPerPixel(vNormal, ambientLight, vWorldPos);
#endif

	half3 ambientLighting = ambient;

	ambient = ambient * diffuse;
	diffuse = diffuse * (NoL + NoL1 ) * atten * _LightColor0.rgb;

	half3 brdfSpecColor = specularColor;

	#if _BRDF_ASHIKHMIN
		brdfSpecColor = GetEnvRetroReflectiveBRDF(origSpecColor, NoV, params.retroReflectivity, roughness);
	#endif

	return ambient + diffuse + (dirSpec * _SpecularColor) + (env * lerp(1, atten, NoL) * brdfSpecColor * lerp(1, ambientLighting, _AmbientInfluence));
}

half4 frag(v2f IN) : SV_Target
{
	half4 finalColor = half4(0, 0, 0, 1);

	half4 albedo = tex2D(_MainTex, IN.uv_MainTex.xy) * _Color * tex2D(_SecondaryTex, IN.uv2);

	half4 mask = tex2D(_MetallicGlossMap, IN.uv_MainTex.xy);
	half metallic = mask.r * _Metallic;

	half roughness = mask.a;
	roughness = saturate(lerp(_RoughnessLow, _RoughnessHigh, roughness));


#if _BUMP_ON
	half3 vNormal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));
	vNormal = lerp(half3(0, 0, 1), vNormal, _BumpScale);

	half3 vNormalDetail = UnpackNormal(tex2D(_DetailBumpMap, IN.uv2));
	vNormalDetail = lerp(half3(0, 0, 1), vNormalDetail, _DetailBumpScale);

	vNormal = normalize(half3(vNormal.xy + vNormalDetail.xy, vNormal.z));

	half3x3 local2WorldTranspose = half3x3((IN.vWorldTangent), (IN.vWorldBinormal), (IN.vWorldNormal));
	vNormal = normalize(mul(vNormal, local2WorldTranspose));
#else
	half3 vNormal = normalize(IN.vWorldNormal);
#endif

	MaterialParams params;
	UNITY_INITIALIZE_OUTPUT(MaterialParams, params);
	params.albedo = albedo;
	params.metallic = metallic;
	params.roughness = roughness;
	params.specular = _Specular;

	half4 retroReflectivityMask = tex2D(_RetroreflectivityMask, IN.uv_MainTex);	
	params.retroReflectivity = retroReflectivityMask.r * _Retroreflectivity;
	params.translucency = retroReflectivityMask.a * _Translucency;

	IN.vWorldBinormal = normalize(cross(vNormal, IN.vWorldTangent));

	UNITY_LIGHT_ATTENUATION(atten, IN, IN.vWorldPos.xyz);	
	finalColor.rgb = CalcLighting(IN.vWorldNormal, vNormal, IN.vViewDir, IN.vWorldPos, atten, params, IN.ambientOrLightmapUV, IN.vWorldTangent, IN.vWorldBinormal, _WorldSpaceLightPos0.xyz);

	finalColor.rgb = finalColor.rgb * 1.5;
	finalColor.rgb = lerp(finalColor.rgb, finalColor.rgb * finalColor.rgb, 0.5);
	
	finalColor.a = albedo.a;	

	UNITY_APPLY_FOG(IN.fogCoord, finalColor.rgb);

	return finalColor;	
}

#endif