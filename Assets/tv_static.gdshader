shader_type canvas_item;
render_mode blend_mix;

uniform float intensity = 0.4;
uniform float time_scale = 25.0;
uniform float color_shift = 1.5;
uniform float wave_strength = 0.75; // Control the strength of the wave
uniform float alpha_intensity_speed = 1.0; // Speed of alpha intensification

float rand(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 uv) {
	return rand(uv * time_scale + TIME);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 uv = UV;

	// Add wavey distortion to UVs
	float wave = sin(uv.y * 10.0 + TIME * 5.0) * wave_strength;
	uv.x += wave;

	// Generate color noise
	float hue = noise(uv * 2.0 + TIME * 0.2) + uv.y * 0.6 + TIME * 0.05;
	hue = fract(hue);

	vec3 col = hsv2rgb(vec3(hue, 0.9, 0.85));

	// Scanlines (softer, lower frequency)
	float scan = 0.85 + 0.15 * sin(uv.y * 200.0 + TIME * 120.0);
	col *= scan;

	// Apply brightness
	col = pow(col, vec3(0.85));

	// Calculate alpha intensification over time
	float alpha = 0.35 * intensity * (1.0 - exp(-TIME * alpha_intensity_speed));

	COLOR = vec4(col, alpha);
}