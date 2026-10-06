extends Control
var mode = "class"
var kind = "rock"
var data = {}
var tex: Texture2D = null
func _draw():
	var c = size * 0.5 if size.x > 0 and size.y > 0 else Vector2(55, 55)
	var sc = float(data.get("scale", 1.0))
	c.y -= float(data.get("yoff", 0.0)) * 20.0
	var drew = false
	if tex != null:
		var s = 84.0 * sc
		draw_texture_rect(tex, Rect2(c.x - s * 0.5, c.y - s * 0.5, s, s), false)
		drew = true
	if not drew:
		if mode == "class":
			draw_circle(c, 28, Color(0.3, 0.5, 0.9))
			draw_arc(c, 28, 0, TAU, 32, Color.WHITE, 2.0)
			var letter = str(data.get("name", "?")).substr(0, 1)
			var font = ThemeDB.fallback_font
			var ts = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 22)
			draw_string(font, Vector2(c.x - ts.x * 0.5, c.y + ts.y * 0.25), letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color.WHITE)
			draw_line(c + Vector2(14, 0), c + Vector2(34, 0), Color.WHITE, 3.0)
		else:
			if kind == "tree":
				draw_rect(Rect2(c.x - 3, c.y, 6, 14), Color(0.35, 0.25, 0.15))
				draw_circle(c + Vector2(0, -10), 14, Color(0.15, 0.4, 0.2))
			elif kind == "house":
				draw_rect(Rect2(c.x - 16, c.y - 10, 32, 22), Color(0.75, 0.6, 0.4))
				draw_colored_polygon(PackedVector2Array([Vector2(c.x - 18, c.y - 10), Vector2(c.x + 18, c.y - 10), Vector2(c.x, c.y - 26)]), Color(0.6, 0.2, 0.15))
			elif kind == "tent":
				draw_colored_polygon(PackedVector2Array([Vector2(c.x - 14, c.y + 12), Vector2(c.x + 14, c.y + 12), Vector2(c.x, c.y - 14)]), Color(0.7, 0.65, 0.55))
			elif kind == "crate":
				draw_rect(Rect2(c.x - 12, c.y - 12, 24, 24), Color(0.55, 0.4, 0.2))
			else:
				draw_colored_polygon(PackedVector2Array([Vector2(c.x - 20, c.y + 18), Vector2(c.x - 24, c.y - 4), Vector2(c.x - 8, c.y - 20), Vector2(c.x + 12, c.y - 16), Vector2(c.x + 22, c.y + 2), Vector2(c.x + 14, c.y + 18)]), Color(0.45, 0.45, 0.5))
	if mode == "class" and bool(data.get("col", false)):
		var h = 70.0 * sc
		var r = 18.0 * sc
		var col = Color(1, 1, 1, 0.25)
		draw_rect(Rect2(c.x - r, c.y - h * 0.5 + r, r * 2, h - r * 2), col)
		draw_circle(Vector2(c.x, c.y - h * 0.5 + r), r, col)
		draw_circle(Vector2(c.x, c.y + h * 0.5 - r), r, col)
