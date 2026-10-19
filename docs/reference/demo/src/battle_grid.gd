extends RefCounted
## Grid rules shared by the playable demo and its checks.

var width: int
var height: int
var terrain: Array
var rules: Dictionary


## Loads one authored square-grid map. Returns false for malformed data.
func load_map(data: Dictionary) -> bool:
	width = int(data.get("width", 0))
	height = int(data.get("height", 0))
	terrain = data.get("terrain", [])
	rules = data.get("terrain_rules", {})
	if width <= 0 or height <= 0 or terrain.size() != height:
		return false
	for row in terrain:
		if not row is String or row.length() != width:
			return false
		for x in width:
			if not rules.has(row.substr(x, 1)):
				return false
	return true


## Returns whether a cell is inside the authored map and can be entered.
func is_passable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return false
	return bool(rules[terrain[cell.y].substr(cell.x, 1)]["passable"])


## Returns legal end tiles. Allied occupied cells allow traversal but not stopping.
func reachable(start: Vector2i, movement: int, occupied: Dictionary, allied_occupied: Dictionary = {}) -> Dictionary:
	var cost_so_far: Dictionary = {start: 0}
	var frontier: Array[Vector2i] = [start]
	var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for direction in directions:
			var next: Vector2i = current + direction
			if not is_passable(next) or (occupied.has(next) and not allied_occupied.has(next)):
				continue
			var symbol: String = terrain[next.y].substr(next.x, 1)
			var next_cost: int = int(cost_so_far[current]) + int(rules[symbol]["move_cost"])
			if next_cost > movement:
				continue
			if not cost_so_far.has(next) or next_cost < int(cost_so_far[next]):
				cost_so_far[next] = next_cost
				frontier.append(next)
	cost_so_far.erase(start)
	for ally_cell in allied_occupied.keys():
		cost_so_far.erase(ally_cell)
	return cost_so_far


## Shortest remaining movement cost from each tile to a goal. Allied units may
## be crossed but enemy-occupied tiles block the route. Reverse edge cost is
## the cost of entering the tile being expanded, matching reachable().
func costs_to_goal(goal: Vector2i, occupied: Dictionary, allied_occupied: Dictionary = {}) -> Dictionary:
	if not is_passable(goal) or (occupied.has(goal) and not allied_occupied.has(goal)):
		return {}
	var costs: Dictionary = {goal: 0}
	var frontier: Array[Vector2i] = [goal]
	var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var symbol: String = terrain[current.y].substr(current.x, 1)
		var step_cost: int = int(rules[symbol]["move_cost"])
		for direction in directions:
			var previous: Vector2i = current + direction
			if not is_passable(previous) or (occupied.has(previous) and not allied_occupied.has(previous)):
				continue
			var next_cost: int = int(costs[current]) + step_cost
			if not costs.has(previous) or next_cost < int(costs[previous]):
				costs[previous] = next_cost
				frontier.append(previous)
	return costs
