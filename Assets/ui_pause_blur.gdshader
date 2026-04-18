shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_strength = 2.2;
uniform float dim = 0.55;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 texel = blur_strength / vec2(textureSize(screen_texture, 0));

	vec3 c = vec3(0.0);
	c += textureLod(screen_texture, uv + texel * vec2(-2.0, -2.0), 1.2).rgb * 0.06;
	c += textureLod(screen_texture, uv + texel * vec2( 0.0, -2.0), 1.2).rgb * 0.10;
	c += textureLod(screen_texture, uv + texel * vec2( 2.0, -2.0), 1.2).rgb * 0.06;
	c += textureLod(screen_texture, uv + texel * vec2(-2.0,  0.0), 1.2).rgb * 0.10;
	c += textureLod(screen_texture, uv, 1.2).rgb * 0.36;
	c += textureLod(screen_texture, uv + texel * vec2( 2.0,  0.0), 1.2).rgb * 0.10;
	c += textureLod(screen_texture, uv + texel * vec2(-2.0,  2.0), 1.2).rgb * 0.06;
	c += textureLod(screen_texture, uv + texel * vec2( 0.0,  2.0), 1.2).rgb * 0.10;
	c += textureLod(screen_texture, uv + texel * vec2( 2.0,  2.0), 1.2).rgb * 0.06;

	c *= (1.0 - dim);
	COLOR = vec4(c, 0.92);
}
