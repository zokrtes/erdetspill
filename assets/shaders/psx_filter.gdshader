shader_type canvas_item;

uniform float dither_strength : hint_range(0.0, 1.0) = 0.02;
uniform float color_depth : hint_range(2.0, 32.0) = 24.0;
uniform vec2 resolution = vec2(640.0, 360.0);
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec2 pixel_uv = floor(SCREEN_UV * resolution) / resolution;
	vec4 color = texture(screen_texture, pixel_uv);

	color.rgb = floor(color.rgb * color_depth) / color_depth;

	float dither = fract(sin(dot(floor(SCREEN_UV * resolution), vec2(12.9898, 78.233))) * 43758.5453);
	color.rgb += (dither - 0.5) * dither_strength;
	color.rgb = clamp(color.rgb, 0.0, 1.0);

	COLOR = color;
}
