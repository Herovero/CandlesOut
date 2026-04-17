shader_type canvas_item;

uniform float radius : hint_range(0.0, 1.0) = 0.75;
uniform float softness : hint_range(0.0, 1.0) = 0.45;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv);

    float vignette = smoothstep(radius, radius - softness, dist);

    COLOR = mix(vec4(1.0), vignette_color, vignette);
}
