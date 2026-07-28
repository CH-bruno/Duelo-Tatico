class_name Rules
extends RefCounted

const BASE_BY_ZONE = [25, 35, 45, 55]

static func opponent_difficulty_for(zone: int, level: int, stage: int) -> int:
	var value = BASE_BY_ZONE[zone] + level + (stage - 1) * 4
	return clampi(value, 0, 92)


static func success_chance(
		player_stat: float,
		difficulty: int,
		momentum: float,
		trait_bonus: int,
		min_pct: int = 8,
		max_pct: int = 92
	) -> int:

	var diff = player_stat - difficulty + momentum + trait_bonus
	var pct = 50.0 + diff * 0.6

	return clampi(roundi(pct), min_pct, max_pct)
