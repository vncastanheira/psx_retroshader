// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "psx/vertexlit (cull off)" {
	Properties{
		_MainTex("Base (RGB)", 2D) = "white" {}
	}
		SubShader{
			Tags { "RenderType" = "Opaque" }
			LOD 200

			Pass {
			Lighting On
			Cull Off
				CGPROGRAM

					#pragma vertex vert
					#pragma fragment frag
					#include "UnityCG.cginc"

					struct v2f
					{
						fixed4 pos : SV_POSITION;
						half4 color : COLOR0;
						half4 colorFog : COLOR1;
						float2 uv_MainTex : TEXCOORD0;
						half3 normal : TEXCOORD1;
					};

					float4 _MainTex_ST;
					uniform half4 unity_FogStart;
					uniform half4 unity_FogEnd;

					float3 CustomVertexLights(float4 vertex, float3 normal, int lightCount, bool spotLight)
					{
						float3 viewpos = mul (UNITY_MATRIX_MV, vertex).xyz;
						float3 viewN = normalize (mul ((float3x3)UNITY_MATRIX_IT_MV, normal));
 
						float3 lightColor = UNITY_LIGHTMODEL_AMBIENT.xyz;
						for (int i = 0; i < lightCount; i++) {
							float3 toLight = unity_LightPosition[i].xyz - viewpos.xyz * unity_LightPosition[i].w;
							float lengthSq = dot(toLight, toLight);
							toLight *= rsqrt(lengthSq);
 
							float atten = 1.0 / (1.0 + lengthSq * unity_LightAtten[i].z);
							if (spotLight)
							{
								float rho = max (0, dot(toLight, unity_SpotDirection[i].xyz));
								float spotAtt = (rho - unity_LightAtten[i].x) * unity_LightAtten[i].y;
								atten *= saturate(spotAtt);
							}
 
							float diff = max (0, dot (viewN, toLight));
							lightColor += unity_LightColor[i].rgb * (diff * atten);
						}
						return lightColor;
					}

					v2f vert(appdata_full v)
					{
						v2f o;

						//Vertex snapping
						float4 snapToPixel = UnityObjectToClipPos(v.vertex);
						float4 vertex = snapToPixel;
						vertex.xyz = snapToPixel.xyz / snapToPixel.w;
						vertex.x = floor(160 * vertex.x) / 160;
						vertex.y = floor(120 * vertex.y) / 120;
						vertex.xyz *= snapToPixel.w;
						o.pos = vertex;

						//Vertex lighting 
					//	o.color =  float4(ShadeVertexLights(v.vertex, v.normal), 1.0);
						o.color = float4(CustomVertexLights(v.vertex, v.normal, 8, true), 1.0);
						o.color *= v.color;

						float distance = length(UnityObjectToViewPos(v.vertex));

						//Affine Texture Mapping
						float4 affinePos = vertex; //vertex;				
						o.uv_MainTex = TRANSFORM_TEX(v.texcoord, _MainTex);
						o.uv_MainTex *= distance + (vertex.w*(UNITY_LIGHTMODEL_AMBIENT.a * 8)) / distance / 2;
						o.normal = distance + (vertex.w*(UNITY_LIGHTMODEL_AMBIENT.a * 8)) / distance / 2;

						//Fog
						float4 fogColor = unity_FogColor;

						float fogDensity = (unity_FogEnd - distance) / (unity_FogEnd - unity_FogStart);
						o.normal.g = fogDensity;
						o.normal.b = 1;

						o.colorFog = fogColor;
						o.colorFog.a = clamp(fogDensity,0,1);

						//Cut out polygons
						if (distance > unity_FogStart.z + unity_FogColor.a * 255)
						{
							o.pos.w = 0;
						}

						return o;
					}

					sampler2D _MainTex;

					float4 frag(v2f IN) : COLOR
					{
						half4 c = tex2D(_MainTex, IN.uv_MainTex / IN.normal.r)*IN.color;
						half4 color = c*(IN.colorFog.a);
						color.rgb += IN.colorFog.rgb*(1 - IN.colorFog.a);
						return color;
					}

					
				ENDCG
			}
	}
}