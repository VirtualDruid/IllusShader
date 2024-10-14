![img](https://github.com/VirtualDruid/IllusShader/blob/master/matstext.png)

> Textures from AMD MaterialX https://matlib.gpuopen.com/main/materials/all

![img](https://github.com/VirtualDruid/IllusShader/blob/79276f0143d346e6a499925381fbe1641786cf5f/mats.png)

![img](https://github.com/VirtualDruid/IllusShader/blob/6f8faa4cf368eae3d9fa36d60068f74ccadbc97e/dragon.png)

![img](https://github.com/VirtualDruid/IllusShader/blob/13758e6f25dea05e0b51cefa7583d2890dcf8ae6/helmet.png)

![img](https://raw.githubusercontent.com/VirtualDruid/IllusShader/refs/heads/master/orchid.png)

![img](https://raw.githubusercontent.com/VirtualDruid/IllusShader/refs/heads/master/wing.png)

> Model from https://www.cgtrader.com/free-3d-models/character/fantasy-character/high-poly-transcended

This shader is an approximated surface PBR that attempt to imitate realistic visuals rather than strict physic-ruled calculation, 
with advanced features such as Transmission, Clearcoat, Anisotropic.
The shader is mostly built from ground up.

# Key Features

> __Basic PBR (Normal, Metallic, Roughness, EnvSpecular)__
>> Metallic use a color-perceptual approach for better visual on colored metal(copper, gold) or half-metallic surface (half-oxydized metal).

>> Environment Specular can be set at runtime to fit artistic need, rather than fixed skybox reflection.

> __Clearcoat__
>> Clearcoat value simulate transparent coating/layer such as wet surface(low value), car paint(mid value), varnish(high value).

> __Anisotropic__
>> Anisotropic simulate surface like brushed metal, hair.
>> http://www.neilblevins.com/art_lessons/aniso_ref_real_world/aniso_ref_real_world.htm

> __Tranmission__
>> Simulate thin surface tranmission (object with no volumn) like leaf, paper, feather, pinpong ball.

> __Sheen__
>> Simulate cloth, fabric, or slightly tinted coating.


# Design choice/ implementation detail

- Use an altered version of GGX specular.

- Use Oklab perceptual color space for everything that does color blending, for better hue preservation than sRGB blending.

- Transmission takes view angle and light angle into account.

- Lighting of tranparent material affects alpha blending, based on intensity of lighting. 

- PBR Energy conservation is concerned, except energy preservation, which seems unrealistic because entropy (lighting most likely turns into heat).

- Anisotropic use simple axis reconstruction for tangent instead of using flow map/ tangent map texture.

- Use Interleaved Gradient Noise for shadow map temporal dithered sampling.
> ![img](https://raw.githubusercontent.com/VirtualDruid/IllusShader/refs/heads/master/dither.png)

