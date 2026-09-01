class_name Viewport3D
extends RefCounted

# Shared plumbing for the 3D content this game shows inside otherwise-2D
# scenes: the match board, the army creator's board, and the main menu's
# hanging signs. All of them live in their own SubViewport for the same
# reason - 2D CanvasItems always draw on top of ANY 3D content in a shared
# viewport, with no way to sort one behind the other - and all of them hit the
# same resolution trap, so that fix lives here once instead of being copied
# and left to drift.

# The plates and the menu signs are hard-edged and permanently, slowly moving,
# so aliasing on them crawls. Everything else in these viewports is unshaded
# billboards and quads, which do not care.
static func setup(viewport: SubViewport) -> void:
	viewport.msaa_3d = Viewport.MSAA_4X

# The 2D world is authored against a fixed 512-unit base and scaled up to the
# window (window/stretch/mode = canvas_items). Text and controls come through
# that sharp because they are re-rasterized at the real resolution. A
# SubViewport does not: it is a texture, so sizing it in base units renders
# the 3D at a fraction of the window's real resolution and leaves the
# container to blow the result back up - which is why the board's plates once
# looked like you could count their pixels. The container is therefore sized
# in REAL pixels and scaled back down by the same factor: same area of screen,
# one rendered pixel per screen pixel.
#
# `canvas_rect` is where the content should sit, in the 2D units the rest of
# the scene is laid out in. Anything mapping between the mouse and this
# viewport has to divide by the container's scale to get back into the
# viewport's own pixels - see to_canvas() and the board's _mouse_ground_point().
static func fit_to_pixels(container: SubViewportContainer, canvas_rect: Rect2) -> void:
	var canvas := container.get_viewport_rect().size
	var pixels := Vector2(container.get_window().size)
	var factor := 1.0
	# aspect = expand keeps the scale uniform, so one axis is enough.
	if canvas.x > 0.0 and pixels.x > 0.0:
		factor = pixels.x / canvas.x
	container.position = canvas_rect.position
	container.scale = Vector2.ONE / factor
	container.size = canvas_rect.size * factor

# Turns a position inside the SubViewport (what Camera3D.unproject_position
# hands back) into the 2D coordinates the mouse is reported in.
static func to_canvas(container: SubViewportContainer, viewport_point: Vector2) -> Vector2:
	return viewport_point * container.scale + container.position
