// File: res://dissolve.gdshader (Updated Version)
shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_texture;
uniform float progress : hint_range(0.0, 1.0);
uniform float pixel_size : hint_range(1.0, 50.0) = 4.0;

void fragment() {
    vec2 pixel_uv = floor(SCREEN_UV * (1.0 / pixel_size)) * pixel_size;
    float noise_value = texture(noise_texture, SCREEN_UV).r;

    // --- This is the updated logic ---
    if (noise_value < progress) {
        // If the pixel is dissolved, color it solid black.
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        // Otherwise, show the color from the screen behind.
        COLOR = texture(SCREEN_TEXTURE, pixel_uv);
    }
}