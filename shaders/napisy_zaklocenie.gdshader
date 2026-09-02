shader_type canvas_item;

// Roughs up the menu signs so they stop looking injection-moulded.
//
// This runs on the SubViewportContainer that displays the signs, not on the
// signs themselves, so it works on the finished image - which is the only
// place a pixel grid and a horizontal tear can exist at all - and leaves the
// background and the 2D title completely alone.
//
// Sizes are in TEXELS of that viewport, which is rendered at real screen
// pixels (Viewport3D.fit_to_pixels), so menu_glowne.gd scales `block_size`
// with the display factor to keep the blocks the same apparent size whatever
// the window resolution.

uniform float block_size = 4.0; // pixelation: side of one block, in texels
uniform float rgb_split = 1.5; // channel offset, in texels
uniform float scanline = 0.15; // 0 = none, 1 = every other row black
uniform float grain = 0.10; // static per block
uniform float tear = 0.5; // 0 = none; how often and how far rows slip
uniform float tear_hz = 6.0; // how many times a second the tearing reshuffles

// Every sample below is textureLod at level 0, never plain texture(). Snapping
// the UV with floor() makes it jump from block to block, and the GPU reads the
// mip level off exactly those jumps - so it decides the texture is being
// minified enormously and fetches a coarse, blurred mip. That is invisible as
// blur but shows up as brightness: measured on the letters, plain texture()
// gave 124 where no shader at all gives 175, and forcing level 0 gives 171.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE;
	vec2 block = texel * max(block_size, 1.0);
	// Snap to the block grid, sampling its centre: this is the pixelation, and
	// everything below works in blocks rather than pixels so the disruption
	// lands on the same grid instead of fighting it.
	vec2 uv = (floor(UV / block) + 0.5) * block;

	// A few rows slip sideways at a time, reshuffled `tear_hz` times a second.
	float row = floor(uv.y / block.y);
	float step_time = floor(TIME * tear_hz);
	float pick = hash(vec2(row, step_time));
	if (pick > 1.0 - 0.06 * tear) {
		uv.x += (hash(vec2(row, step_time + 1.0)) - 0.5) * block.x * 6.0 * tear;
	}

	// Splitting the channels leaves coloured fringes on the letter edges,
	// which is most of what stops them reading as clean.
	vec2 split = vec2(texel.x * rgb_split, 0.0);
	vec4 c;
	c.r = textureLod(TEXTURE, uv + split, 0.0).r;
	vec4 mid = textureLod(TEXTURE, uv, 0.0);
	c.g = mid.g;
	c.b = textureLod(TEXTURE, uv - split, 0.0).b;
	c.a = mid.a;

	float line = 1.0 - scanline * step(0.5, fract(uv.y / (block.y * 2.0)));
	float n = (hash(floor(uv / block) + vec2(step_time, 0.0)) - 0.5) * grain;
	// Both are folded into the colour only - scaling alpha as well would eat
	// holes in the letters rather than dirty them.
	c.rgb = c.rgb * line + n * c.a;
	// Deliberately NOT `c * COLOR`. The usual way to end a canvas shader is to
	// fold in the incoming COLOR, but on a SubViewportContainer that value is
	// not white: multiplying by it cost about a third of the brightness
	// (letters at 118 against 175 with no shader at all, with every effect
	// switched off). Nothing sets modulate on this container, so there is
	// nothing to fold in anyway.
	COLOR = c;
}
