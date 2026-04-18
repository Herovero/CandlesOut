shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.45, 0.0, 1.0);
uniform float glow_size = 4.0;
uniform float glow_strength = 2.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	vec2 px = TEXTURE_PIXEL_SIZE * glow_size;

	// sample 4 directions (cheap + stable)
	float a =
		texture(TEXTURE, UV + vec2(px.x, 0.0)).a +
		texture(TEXTURE, UV + vec2(-px.x, 0.0)).a +
		texture(TEXTURE, UV + vec2(0.0, px.y)).a +
		texture(TEXTURE, UV + vec2(0.0, -px.y)).a;

	a *= 0.25;

	// remove inside sprite so glow only appears outside edges
	float glow = max(a - tex.a, 0.0);

	vec3 glow_rgb = glow_color.rgb * glow * glow_strength;

	COLOR = vec4(tex.rgb + glow_rgb, tex.a);
}