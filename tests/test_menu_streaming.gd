extends RefCounted

const MenuStreamUtils = preload("res://scripts/core/menu_stream_utils.gd")

func run(_tree: SceneTree) -> bool:
	var tile_size := 135.3
	var ratio := 0.75
	var margin := 2

	var rect := Rect2(-200.0, -150.0, 400.0, 300.0)
	var bounds := MenuStreamUtils.coord_bounds_for_rect(rect, tile_size, ratio, margin)

	if bounds.q_min > bounds.q_max or bounds.r_min > bounds.r_max:
		push_error("Invalid coord bounds: %s" % str(bounds))
		return false

	var center := MenuStreamUtils.axial_to_world(0, 0, tile_size, ratio)
	if not rect.has_point(center):
		push_error("Origin tile should lie inside test rect")
		return false

	if not MenuStreamUtils.coord_in_bounds(Vector2i(0, 0), bounds):
		push_error("Origin coord should be inside bounds")
		return false

	var coords := MenuStreamUtils.iter_coords_in_bounds(bounds)
	if coords.is_empty():
		push_error("Expected at least one coord in bounds")
		return false

	var far := MenuStreamUtils.axial_to_world(50, 50, tile_size, ratio)
	var far_bounds := MenuStreamUtils.coord_bounds_for_rect(
		Rect2(far - Vector2(10.0, 10.0), Vector2(20.0, 20.0)), tile_size, ratio, margin
	)
	if not MenuStreamUtils.coord_in_bounds(Vector2i(50, 50), far_bounds):
		push_error("Far coord should be inside its local bounds")
		return false

	print("Success: menu streaming coord bounds are consistent")
	return true
