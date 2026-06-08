shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0);

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	col.rgb = mix(col.rgb, flash_color, flash_amount);
	COLOR = col;
}
