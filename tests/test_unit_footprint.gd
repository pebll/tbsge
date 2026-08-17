extends RefCounted

const UnitFootprint = preload("res://scripts/ui/interact/unit_footprint.gd")
const MinigameRules = preload("res://scripts/minigame/minigame_rules.gd")
const UiTooltipPolicy = preload("res://scripts/ui/interact/ui_tooltip_policy.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_allowed_sizes_and_footprints():
		return false
	if not _test_packing():
		return false
	if not _test_rules_caps():
		return false
	if not _test_tooltip_policy():
		return false
	print("Success: Unit footprint / strip UI tests")
	return true

func _test_allowed_sizes_and_footprints() -> bool:
	# Vector2 = width × height. Height is always 1 (small) or 2 (large).
	var expected := {
		0.75: Vector2(0.75, 1.0),
		1.0: Vector2(1.0, 1.0),
		1.5: Vector2(1.5, 1.0),
		2.0: Vector2(1.0, 2.0),
		3.0: Vector2(1.5, 2.0),
		4.0: Vector2(2.0, 2.0),
		6.0: Vector2(3.0, 2.0),
		8.0: Vector2(4.0, 2.0),
		10.0: Vector2(5.0, 2.0),
		12.0: Vector2(6.0, 2.0),
	}
	for size in expected.keys():
		if not UnitFootprint.is_allowed(float(size)):
			push_error("Expected size %s allowed" % size)
			return false
		var fp: Vector2 = UnitFootprint.footprint(float(size))
		var want: Vector2 = expected[size]
		if fp != want:
			push_error("Footprint for %s: got %s want %s" % [size, fp, want])
			return false
	if UnitFootprint.is_allowed(1.25) or UnitFootprint.is_allowed(0.8):
		push_error("Disallowed legacy sizes should be rejected")
		return false
	if UnitFootprint.footprint(1.25) != Vector2.ZERO:
		push_error("Disallowed size should have zero footprint")
		return false
	return true

func _test_packing() -> bool:
	if not UnitFootprint.can_pack([]):
		push_error("Empty pack should succeed")
		return false
	# Twelve size-1 units fill the board.
	var ones: Array = []
	ones.resize(12)
	ones.fill(1.0)
	if not UnitFootprint.can_pack(ones):
		push_error("12× size 1 should pack")
		return false
	# Size 1.5 is 1.5×1 → 4 per row × 2 rows = 8 (matches fill).
	var mages: Array = []
	mages.resize(8)
	mages.fill(1.5)
	if not UnitFootprint.can_pack(mages):
		push_error("8× size 1.5 should pack")
		return false
	var too_many_mages: Array = []
	too_many_mages.resize(9)
	too_many_mages.fill(1.5)
	if UnitFootprint.can_pack(too_many_mages):
		push_error("9× size 1.5 should fail packing")
		return false
	# Two size-4 (2×2) + two size-2 (1×2).
	if not UnitFootprint.can_pack([4.0, 4.0, 2.0, 2.0]):
		push_error("two 4s + two 2s should pack")
		return false
	if UnitFootprint.max_packable_count(1.5) != 8:
		push_error("max_packable 1.5 expected 8, got %d" % UnitFootprint.max_packable_count(1.5))
		return false
	if UnitFootprint.max_packable_count(3.0) != 4:
		push_error("max_packable 3.0 expected 4, got %d" % UnitFootprint.max_packable_count(3.0))
		return false
	# Input order preserved.
	var placements := UnitFootprint.pack([1.0, 4.0, 1.0])
	if placements.size() != 3:
		push_error("Expected 3 placements")
		return false
	if absf(float(placements[1]["size"]) - 4.0) > 0.001:
		push_error("Placement order should match input (index 1 = size 4)")
		return false
	return true

func _test_rules_caps() -> bool:
	if MinigameRules.max_units_in_legion("GOBLIN") != 12:
		push_error("GOBLIN max units expected 12")
		return false
	if MinigameRules.max_units_in_legion("MAGE") != 8:
		push_error("MAGE max units expected 8, got %d" % MinigameRules.max_units_in_legion("MAGE"))
		return false
	if MinigameRules.max_units_in_legion("GOLEM") != 4:
		push_error("GOLEM max units expected 4, got %d" % MinigameRules.max_units_in_legion("GOLEM"))
		return false
	if MinigameRules.unit_size("SPIDER") != 0.75:
		push_error("SPIDER size should be remapped to 0.75")
		return false
	if MinigameRules.unit_size("ARCHER") != 1.5:
		push_error("ARCHER size should be remapped to 1.5")
		return false
	var bad := MinigameRules.validate_draft_placement(
		"GREEN", Vector2i(0, -3), "MAGE", 9, _FakeDraft.new(), [Vector2i(0, -3)], 12.0
	)
	if bad.is_empty():
		push_error("Draft should reject un-packable mage count")
		return false
	return true

func _test_tooltip_policy() -> bool:
	var policy := UiTooltipPolicy.new()
	var shown: Array = []
	var hidden: Array = []
	policy.configure(
		func(source: Object, _payload) -> void: shown.append(source),
		func(source: Object) -> void: hidden.append(source)
	)
	var a := RefCounted.new()
	var b := RefCounted.new()
	policy.set_hover_tooltip_provider(func(_s: Object) -> Dictionary: return {"title": "x"})
	policy.notify_hover_entered(a)
	if shown.size() != 1:
		push_error("Hover should show tooltip when nothing selected")
		return false
	policy.select(a, func(_s: Object) -> Dictionary: return {"title": "sel"})
	var shown_after_select := shown.size()
	policy.notify_hover_entered(b)
	if shown.size() != shown_after_select:
		push_error("Hover tooltip should be suppressed while selected")
		return false
	policy.deselect(a)
	policy.notify_hover_entered(b)
	if shown.size() <= shown_after_select:
		push_error("Hover tooltip should work again after deselect")
		return false
	return true

class _FakeDraft:
	var remaining_budget: int = 999
	func find_placement(_coords: Vector2i):
		return null
