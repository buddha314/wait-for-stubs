shader_type canvas_item;
// The world behind the rack screen, blurred and dimmed (rack_frame screen.backdrop).
// One mipmapped read of the screen texture: the mip level approximates the blur
// radius (lod = log2(blur_px)), so the cost is one texture fetch per pixel.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float lod = 3.8;
uniform vec4 dim_color : source_color = vec4(0.043, 0.047, 0.063, 1.0);
uniform float dim = 0.55;

void fragment() {
	vec3 world = textureLod(screen_texture, SCREEN_UV, lod).rgb;
	COLOR = vec4(mix(world, dim_color.rgb, dim), 1.0);
}
