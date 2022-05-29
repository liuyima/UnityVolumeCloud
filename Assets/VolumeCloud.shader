Shader "Liuyima/VolumeCloud"
{
    Properties
    {
		_MainTex("Main Texture",2D) = "white"{}
		_Noise3D("Noise 3",3D) = "white"{}
		_Noise3D2("Noise 3D 2",3D) = "white"{}
		_PerlinNoise("Perlin Noise",2D) = "white"{}
		_Weather("Weather",2D) = "white"{}
		_Weather2("Weather2",2D) = "white"{}

		_Absorption("Absorption",Range(0,1)) = 1//吸光率
		_LightAbsorption("Light Absorption",Range(0,1)) = 1
		_G("g",Range(0,1)) = 0.65
		_BP("BeerPowder",Range(0,1)) = 0.65

		_BoundsMin("Bounds Min",VECTOR) = (1,1,1,1)
		_BoundsMax("Bounds Max",VECTOR) = (0,0,0,1)
		_UVScale("UV Scale",FLOAT) = 0.025
    }
    SubShader
    {
		CGINCLUDE

		//边界框最小值       边界框最大值         
		float2 rayBoxDst(float3 boundsMin, float3 boundsMax,
			//射线起点         射线方向倒数
			float3 rayOrigin, float3 invRaydir)
		{
			float3 t0 = (boundsMin - rayOrigin) * invRaydir;
			float3 t1 = (boundsMax - rayOrigin) * invRaydir;
			float3 tmin = min(t0, t1);
			float3 tmax = max(t0, t1);

			float dstA = max(max(tmin.x, tmin.y), tmin.z); //进入点
			float dstB = min(tmax.x, min(tmax.y, tmax.z)); //出去点

			float dstToBox = max(0, dstA);
			float dstInsideBox = max(0, dstB - dstToBox);
			return float2(dstToBox, dstInsideBox);
		}

		float4x4 _InvVP;
		float4 GetWorldPositionFromDepth(float2 uv,float depth)
		{
			float4 wpos = mul(_InvVP, float4(uv * 2 - 1, depth, 1));
			wpos /= wpos.w;
			return wpos;
		}
		float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
		{
			return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
		}
		float random(float2 st) {
			return frac(sin(dot(st.xy,
				float2(12.9898, 78.233)))*
				43758.5453123);
		}
		float2 computeCurl(float2 st)
		{
			float x = st.x; float y = st.y;
			float h = 0.0001;
			float n, n1, n2, a, b;

			n = random(float2(x, y));
			n1 = random(float2(x, y - h));
			n2 = random(float2(x - h, y));
			a = (n - n1) / h;
			b = (n - n2) / h;

			return float2(a, -b);
		}
		ENDCG

		Pass
		{
			Blend SrcAlpha OneMinusSrcAlpha
			ZWrite Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			#include "Lighting.cginc"


			struct appdata
			{
				float4 vertex:POSITION;
				float2 uv:TEXCOORD;
			};
			struct v2f
			{
				float4 pos:POSITION;
				float2 uv:TEXCOORD;
				float4 worldPos:TEXCOORD1;
				float3 uv3:TEXCOORD2;
			};

			sampler2D _CameraDepthTexture;

			sampler2D _MainTex;
			sampler2D _Weather;
			float4 _Weather_ST;
			sampler2D _PerlinNoise;
			sampler3D _Noise3D;
			sampler3D _Noise3D2;

			float _Absorption;
			float _LightAbsorption;
			float _G;
			float _BP;

			float4 _BoundsMax;
			float4 _BoundsMin;
			float _UVScale;
			v2f vert(appdata i)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(i.vertex);
				o.uv = i.uv;
				o.worldPos = mul(unity_ObjectToWorld, i.vertex);
				o.uv3 = i.vertex.xyz;
				return o;
			}
			float GetDensityHeightGradientForPoint1(float h, float w)
			{
				float d = remap(h, 0, w, 1, 0);
				return saturate(d)*2;
			}
			float cloudShape(float3 pos)
			{
				float2 uv = pos.xz / float2(_BoundsMax.x - _BoundsMin.x, _BoundsMax.z - _BoundsMin.z);
				uv.x += _Time.y*0.004;
				float heightPercent = (pos.y - _BoundsMin.y) / (_BoundsMax.y - _BoundsMin.y);
				float weather = tex2Dlod(_Weather, float4( uv*_Weather_ST.xy+_Weather_ST.zw,0,0));
				float heightFra = GetDensityHeightGradientForPoint1(heightPercent, weather);

				float3 detailUVW = pos * _UVScale;
				detailUVW.xy += float2( _Time.y*0.04,_Time.w*0.01);
				float4 low_frequency_noises = tex3Dlod(_Noise3D, float4(detailUVW, 0));
				// 从低频Worley噪声中构建FBM，可用于为低频Perlin-Worley噪声添加细节。 
				float low_freq_FBM = (low_frequency_noises.g * 0.625) + (low_frequency_noises.b*0.25) + (low_frequency_noises.r * 0.125);
				// 通过使用由Worley噪声制成的低频FBM对其进行膨胀来定义基本云形状。
				float base_cloud = remap(low_frequency_noises.r, -(1.0 - low_freq_FBM), 1.0, 0.0, 1.0);
				base_cloud *= heightFra;
				//return base_cloud;

				float cloud_coverage = weather.x*0.9;
				// 使用重新映射来应用云覆盖属性。 
				float base_cloud_with_coverage = saturate(remap(base_cloud, cloud_coverage, 1.0, 0.0, 1.0));
				// 将结果乘以云覆盖属性，使较小的云更轻且更美观。 
				base_cloud_with_coverage *= cloud_coverage;

				//base_cloud_with_coverage = base_cloud;

				float2 curl_noise = normalize(computeCurl(uv));
				//在云底添加一些湍流。
				pos.xy += curl_noise.xy *(1.0 - heightPercent);
				//采样高频噪声。 
				float3 high_frequency_noises = tex3Dlod(_Noise3D2, float4(detailUVW, 0)).rgb;
				//构建高频Worley噪声FBM。 
				float high_freq_FBM = (high_frequency_noises.r * 0.625) + (high_frequency_noises.g *0.25) + (high_frequency_noises.b * 0.125);
				//return high_freq_FBM;

				//从纤细的形状过渡到高度的波浪形状。
				float high_freq_noise_modifier = lerp(high_freq_FBM, 1.0 - high_freq_FBM, saturate(heightPercent * 10.0));
				//用扭曲的高频Worley噪声侵蚀基础云形状。 
				float final_cloud = saturate(remap(base_cloud_with_coverage, high_freq_noise_modifier * 0.2, 1.0, 0.0, 1.0));
				return final_cloud;
			}

			float sampleCloud(float3 pos)
			{
				float noise = 0;
				if (pos.x < _BoundsMax.x && pos.x > _BoundsMin.x &&
					pos.z < _BoundsMax.z && pos.z > _BoundsMin.z &&
					pos.y < _BoundsMax.y && pos.y > _BoundsMin.z)
				{
					return cloudShape(pos);
				}
				return noise;
			}
			//光线向前散射的概率
			float HenyeyGreenstein(float cosine)
			{
				float coeff = _G;
				float g2 = coeff * coeff;
				return (1 - g2) / (4 * 3.1415*pow(1 + g2 - 2 * coeff * cosine, 1.5));
			}
			//光穿过云的衰减
			float Beer(float depth)
			{
				return exp(depth);
			}
			//光在云中的折射，糖粉效应
			float BeerPowder(float depth)
			{
				float e = _BP;
				return exp(-e * depth) * (1 - exp(-e * 2 * depth))*2;
			}
			float SampleCloudDensityAlongCone(float3 p)
			{
				float3 lightDir = -normalize(_WorldSpaceLightPos0.xyz);
				float dis = rayBoxDst(_BoundsMin, _BoundsMax, p, 1 / lightDir).y;
				float stepSize = dis / 6;
				float cone_spread_multiplier = stepSize;
				float3 light_step = normalize(lightDir)* stepSize;
				float density_along_cone = 0.0;
				//光照的ray-march循环。 
				for (fixed i = 0; i <= 6; i++)
				{
					float3 noise = tex2D(_PerlinNoise, p.xz).rgb;
					//将采样位置加上当前步距。 
					p += light_step + (cone_spread_multiplier * noise * i);
					density_along_cone += sampleCloud(p)*stepSize;
				}
				return Beer(density_along_cone);
			}
			float sampleLight(float3 p)
			{
				float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
				float dis = rayBoxDst(_BoundsMin, _BoundsMax, p, 1 / lightDir).y;
				float stepSize = 2;//dis / 8;
				//p = p - lightDir * dis;
				float3 light_step = lightDir * stepSize;
				float density = 0;
				//光照的ray-march循环。 
				for (fixed i = 0; i <= 8; i++)
				{
					//将采样位置加上当前步距。 
					p += light_step;
					density += sampleCloud(p)*stepSize;
				}
				return Beer(density* -_LightAbsorption);

			}

			float4 renderCloud(float3 start,float3 end)
			{
				float sum = 1;
				fixed stepCount = 128;
				float3 dir = normalize(end - start);
				float dis = length(end - start);
				float stepSize = dis / stepCount;

				float3 samplePos = start;
				float d = dot(normalize(_WorldSpaceLightPos0.xyz), normalize(dir));
				float hg = HenyeyGreenstein(d);
				float light = 0;
				for (fixed i = 0; i < stepCount; i++)
				{
					float density = sampleCloud(samplePos);
					if (density > 0.0)
					{
						light += sampleLight(samplePos)* density*BeerPowder(sum)*stepSize;//*(exp(-i/stepCount) / 4.75)
						sum *= Beer(density*stepSize* -_Absorption);
					}
					if (sum <= 0.01)
						break;
					//samplePos = start + dir * stepSize * (i + random(samplePos.xz));
					samplePos += dir * stepSize;
				}
				light =saturate(light * (hg + 0.45));
				return float4(lerp(float3(0.2, 0.2, 0.2), _LightColor0.xyz, light), 1 - sum);
			}

			float4 frag(v2f i) :SV_TARGET
			{
				float4 col = tex2D(_MainTex,i.uv);

				float depth = UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, i.uv));
				float linearDepth = Linear01Depth(depth);
				float3 rayEnd = GetWorldPositionFromDepth(i.uv, depth).xyz;
				float3 camPos = _WorldSpaceCameraPos.xyz;
				float3 dir = normalize(rayEnd - camPos);
				float2 cast = rayBoxDst(_BoundsMin, _BoundsMax, camPos, 1 / dir);
				float3 start = camPos + dir * cast.x;

				rayEnd = camPos + dir * min(length(rayEnd - camPos), cast.x + cast.y);

				float4 cloud = renderCloud(start, rayEnd);
				col.rgb *=1- cloud.a;
				col.rgb += cloud.rgb;
				return col;
			}
			ENDCG
		}
    }
    FallBack "Diffuse"
}
