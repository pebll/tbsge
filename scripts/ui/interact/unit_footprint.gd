class_name UnitFootprint
extends RefCounted

## Legion capacity size → visual footprint on the 6×2 strip board.
## All allowed sizes divide evenly by STEP (0.25).

const ALLOWED: Array[float] = [0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0, 10.0, 12.0]
const BOARD := Vector2(6.0, 2.0)
const STEP := 0.25
const EPS := 0.001

static func is_allowed(size: float) -> bool:
	for allowed in ALLOWED:
		if absf(size - allowed) < EPS:
			return true
	return false

static func normalize(size: float) -> float:
	for allowed in ALLOWED:
		if absf(size - allowed) < EPS:
			return allowed
	return size

## Width × height in board units.
## Height is always 1 (small: size ≤ 1.5) or 2 (larger). Width carries the rest of size.
static func footprint(size: float) -> Vector2:
	var s := normalize(size)
	if not is_allowed(s):
		return Vector2.ZERO
	if s <= 1.5 + EPS:
		return Vector2(s, 1.0)
	return Vector2(s * 0.5, 2.0)

static func area(size: float) -> float:
	var fp := footprint(size)
	return fp.x * fp.y

static func can_pack(sizes: Array) -> bool:
	if sizes.is_empty():
		return true
	return not pack(sizes).is_empty()

## Returns placement dicts `{size, pos, footprint}` in **input order**, or [] on failure.
static func pack(sizes: Array) -> Array:
	if sizes.is_empty():
		return []
	var indexed: Array = []
	for i in range(sizes.size()):
		var s := normalize(float(sizes[i]))
		if not is_allowed(s):
			return []
		indexed.append({"i": i, "size": s})
	indexed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var aa := area(float(a["size"]))
		var ab := area(float(b["size"]))
		if aa != ab:
			return aa > ab
		return int(a["i"]) < int(b["i"])
	)

	var cols := _to_cells(BOARD.x)
	var rows := _to_cells(BOARD.y)
	var occ := PackedByteArray()
	occ.resize(cols * rows)
	occ.fill(0)

	var by_index: Dictionary = {}
	for item in indexed:
		var s: float = float(item["size"])
		var fp := footprint(s)
		var fw := _to_cells(fp.x)
		var fh := _to_cells(fp.y)
		if fw < 1 or fh < 1 or fw > cols or fh > rows:
			return []
		var placed := false
		var y := 0
		while y <= rows - fh:
			var x := 0
			while x <= cols - fw:
				if _fits(occ, cols, x, y, fw, fh):
					_mark(occ, cols, x, y, fw, fh, 1)
					by_index[int(item["i"])] = {
						"size": s,
						"pos": Vector2(float(x) * STEP, float(y) * STEP),
						"footprint": fp,
					}
					placed = true
					break
				x += 1
			if placed:
				break
			y += 1
		if not placed:
			return []

	var placements: Array = []
	placements.resize(sizes.size())
	for i in range(sizes.size()):
		if not by_index.has(i):
			return []
		placements[i] = by_index[i]
	return placements

## Max identical units of `size` that fit fill and packing.
static func max_packable_count(size: float, max_fill: float = 12.0) -> int:
	var s := normalize(size)
	if not is_allowed(s) or s <= 0.0:
		return 0
	var by_fill := int(floor((max_fill + EPS) / s))
	var count := by_fill
	while count > 0:
		var batch: Array = []
		batch.resize(count)
		batch.fill(s)
		if can_pack(batch):
			return count
		count -= 1
	return 0

static func _to_cells(v: float) -> int:
	return int(round(v / STEP))

static func _fits(occ: PackedByteArray, cols: int, x: int, y: int, w: int, h: int) -> bool:
	for dy in range(h):
		for dx in range(w):
			if occ[(y + dy) * cols + (x + dx)] != 0:
				return false
	return true

static func _mark(occ: PackedByteArray, cols: int, x: int, y: int, w: int, h: int, value: int) -> void:
	for dy in range(h):
		for dx in range(w):
			occ[(y + dy) * cols + (x + dx)] = value
