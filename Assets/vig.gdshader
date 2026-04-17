shader_type canvas_item;

uniform float strength = 0.8;   // how dark edges get
uniform float radius = 0.6;     // size of clear center

void fragment() {
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv);

    float vignette = smoothstep(radius, 1.0, dist);

    COLOR = vec4(0.0, 0.0, 0.0, vignette * strength);
}