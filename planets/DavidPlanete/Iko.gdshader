shader_type spatial;

render_mode world_vertex_coords;

uniform vec3 center_pos;
uniform float max_height;
uniform float min_height;
uniform sampler2D height_color;

varying float height;

void vertex() {
	height = length(VERTEX - center_pos);
}

void fragment() {
	float t = (height - min_height) / (max_height - min_height);
	vec3 color = texture(height_color, vec2(t, 0)).rgb;
	ALBEDO = color;
}
