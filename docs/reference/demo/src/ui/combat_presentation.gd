extends Control
## Placeholder combat cut-in that replays an already-resolved exchange.

signal presentation_state_changed(active: bool)
signal presentation_finished

const INK := Color("#081920")
const PANEL := Color("#122934")
const PALE := Color("#f3eddd")
const MUTED := Color("#a9b8b7")
const GOLD := Color("#dfbd80")
const ALLY := Color("#6287db")
const FOE := Color("#cb6b65")

var active: bool = false
var exchanges: Array[Dictionary] = []
var current: Dictionary = {}
var step_index: int = -1
var elapsed: float = 0.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Queues one committed exchange for display without changing battle state.
func enqueue(exchange: Dictionary) -> void:
	exchanges.append(exchange.duplicate(true))
	if not active:
		_start_next()


## Advances the currently displayed exchange by one visual beat.
func advance() -> void:
	if not active:
		return
	elapsed = 0.0
	step_index += 1
	if step_index > current["strikes"].size():
		_start_next()
	else:
		queue_redraw()


## Skips every queued visual beat, including later enemy exchanges.
func skip() -> void:
	if not active:
		return
	exchanges.clear()
	_close()


## Clears the view when a map is reloaded or rewound.
func reset() -> void:
	exchanges.clear()
	current.clear()
	step_index = -1
	elapsed = 0.0
	var was_active: bool = active
	active = false
	visible = false
	if was_active:
		presentation_state_changed.emit(false)


func _process(delta: float) -> void:
	if not active or not visible:
		return
	elapsed += delta
	var duration: float = 0.42 if step_index < 0 else (0.66 if step_index >= current["strikes"].size() else 0.98)
	if elapsed >= duration:
		advance()
	elif step_index >= 0 and step_index < current["strikes"].size() and elapsed < 0.32:
		queue_redraw()


func _start_next() -> void:
	if exchanges.is_empty():
		_close()
		return
	current = exchanges.pop_front()
	step_index = -1
	elapsed = 0.0
	var was_active: bool = active
	active = true
	visible = true
	if not was_active:
		presentation_state_changed.emit(true)
	queue_redraw()


func _close() -> void:
	current.clear()
	step_index = -1
	elapsed = 0.0
	active = false
	visible = false
	presentation_state_changed.emit(false)
	presentation_finished.emit()


func _draw() -> void:
	if not active or current.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, INK)
	draw_rect(Rect2(0, 0, size.x, 72), Color("#102b36"))
	draw_string(font, Vector2(48, 46), "GIAO CHIẾN", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, PALE)
	var left: Dictionary = current["left"]
	var right: Dictionary = current["right"]
	var hp_left: int = int(left["hp"])
	var hp_right: int = int(right["hp"])
	var strikes: Array = current["strikes"]
	for i in mini(step_index + 1, strikes.size()):
		var strike: Dictionary = strikes[i]
		if strike["target"] == "left":
			hp_left = int(strike["target_hp"])
		else:
			hp_right = int(strike["target_hp"])
	var current_strike: Dictionary = strikes[step_index] if step_index >= 0 and step_index < strikes.size() else {}
	_draw_fighter(font, left, hp_left, Rect2(55, 113, 550, 405), true, current_strike)
	_draw_fighter(font, right, hp_right, Rect2(size.x - 605, 113, 550, 405), false, current_strike)
	draw_rect(Rect2(size.x * 0.5 - 1, 130, 2, 365), Color(0.85, 0.74, 0.54, 0.28))
	draw_string(font, Vector2(size.x * 0.5 - 29, 330), "VS", HORIZONTAL_ALIGNMENT_LEFT, -1, 29, GOLD)
	var caption: String = "Sẵn sàng giao chiến"
	var subcaption: String = "Đòn đánh, phản công và đánh đôi sẽ hiện theo thứ tự."
	if not current_strike.is_empty():
		var actor: Dictionary = left if current_strike["actor"] == "left" else right
		caption = "%s — %s" % [current_strike["label"], actor["name"]]
		subcaption = "TRƯỢT" if not current_strike["hit"] else ("CHÍ MẠNG  −%d HP" % current_strike["damage"] if current_strike["critical"] else "TRÚNG  −%d HP" % current_strike["damage"])
	elif step_index >= strikes.size():
		caption = "Kết thúc giao chiến"
		subcaption = "%d/%d HP  •  %d/%d HP" % [hp_left, left["max_hp"], hp_right, right["max_hp"]]
	draw_string(font, Vector2(65, 578), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 130, 24, PALE)
	draw_string(font, Vector2(65, 612), subcaption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 130, 18, GOLD)
	draw_string(font, Vector2(65, size.y - 36), "Click / Enter / Space: tiếp     Esc: bỏ qua", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED)
	if not strikes.is_empty():
		draw_string(font, Vector2(size.x - 190, size.y - 36), "Đòn %d/%d" % [clampi(step_index + 1, 0, strikes.size()), strikes.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED)


func _draw_fighter(font: Font, fighter: Dictionary, hp: int, panel: Rect2, is_left: bool, strike: Dictionary) -> void:
	var side_color: Color = ALLY if fighter["side"] == "player" else FOE
	var tag: String = "QUÂN MÌNH" if fighter["side"] == "player" else "ĐỊCH"
	draw_rect(panel, PANEL)
	draw_rect(panel, side_color, false, 3.0)
	draw_string(font, panel.position + Vector2(25, 39), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, side_color.lightened(0.3))
	draw_string(font, panel.position + Vector2(25, 82), str(fighter["name"]), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 50, 30, PALE)
	draw_string(font, panel.position + Vector2(25, 111), str(fighter["class"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MUTED)
	var figure_center := panel.position + Vector2(panel.size.x * 0.5, 248)
	var actor_side: String = "left" if is_left else "right"
	if not strike.is_empty() and strike["actor"] == actor_side and elapsed < 0.32:
		figure_center.x += 17 if is_left else -17
	if not strike.is_empty() and strike["target"] == actor_side and strike["hit"] and elapsed < 0.25:
		draw_rect(Rect2(panel.position + Vector2(7, 122), Vector2(panel.size.x - 14, 195)), Color(1, 0.85, 0.66, 0.17))
	draw_circle(figure_center + Vector2(0, -73), 37, side_color.lightened(0.25))
	draw_rect(Rect2(figure_center + Vector2(-55, -33), Vector2(110, 130)), side_color)
	draw_rect(Rect2(figure_center + Vector2(-70, 80), Vector2(53, 36)), side_color.darkened(0.28))
	draw_rect(Rect2(figure_center + Vector2(17, 80), Vector2(53, 36)), side_color.darkened(0.28))
	var blade_start := figure_center + Vector2(67 if is_left else -67, -10)
	var blade_end := blade_start + Vector2(75 if is_left else -75, -53)
	draw_line(blade_start, blade_end, GOLD, 7.0)
	draw_circle(blade_start, 10, GOLD.darkened(0.3))
	var bar := Rect2(panel.position + Vector2(25, panel.size.y - 58), Vector2(panel.size.x - 50, 17))
	draw_rect(bar, Color("#334851"))
	var ratio: float = clampf(float(hp) / float(maxi(1, int(fighter["max_hp"]))), 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), Color("#75d294") if ratio > 0.3 else Color("#ed7468"))
	draw_string(font, bar.position + Vector2(0, -8), "HP  %d / %d" % [hp, fighter["max_hp"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PALE)
