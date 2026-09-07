class_name ExploreTools
extends RefCounted

static func snap_to_cells(points: Array, is_free: Callable) -> Array:
	var res = []
	var occ = {}
	for p in points:
		var bx = int(p[0])
		var by = int(p[1])
		var best = null
		for r in range(0, 5):
			var done = false
			for dx in range(-r, r + 1):
				for dy in range(-r, r + 1):
					if maxi(abs(dx), abs(dy)) != r:
						continue
					var k = str(bx + dx) + "," + str(by + dy)
					if occ.has(k):
						continue
					if is_free.call(bx + dx, by + dy):
						best = [bx + dx, by + dy]
						done = true
						break
				if done:
					break
			if done:
				break
		if best == null:
			best = [bx, by]
		occ[str(best[0]) + "," + str(best[1])] = true
		res.append(best)
	return res
