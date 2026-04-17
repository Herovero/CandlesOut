shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float curvature : hint_range(0.0, 1.0) = 0.15;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.05;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.25;
uniform float chromatic_aberration : hint_range(0.0, 3.0) = 0.15;

vec2 curve_uv(vec2 uv) {
    uv = uv * 2.0 - 1.0;

    uv.x *= 1.0 + pow(abs(uv.y), 2.0) * curvature;
    uv.y *= 1.0 + pow(abs(uv.x), 2.0) * curvature;

    return uv * 0.5 + 0.5;
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 cuv = curve_uv(uv);

    float offset = chromatic_aberration / 2000.0;

    vec3 col;
    col.r = texture(SCREEN_TEXTURE, cuv + vec2(offset, 0.0)).r;
    col.g = texture(SCREEN_TEXTURE, cuv).g;
    col.b = texture(SCREEN_TEXTURE, cuv - vec2(offset, 0.0)).b;

    float scan = sin(cuv.y * 600.0) * 0.5 + 0.5;
    col *= 1.0 - scanline_strength * scan;

    float dist = distance(uv, vec2(0.5));
    col *= 1.0 - vignette_strength * dist * dist;

    COLOR = vec4(col, 1.0);
}