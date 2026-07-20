extends RefCounted
# Fórmulas de balanceamento. Todas as funções são puras: recebem números
# e devolvem números, sem ler nem guardar nenhum estado do jogo. Isso
# facilita ajustar dificuldade sem precisar entender o resto do projeto,
# e facilita testar essas contas isoladamente se um dia você quiser.

const BASE_BY_ZONE = [25, 35, 45, 55]


static func opponent_difficulty_for(zone: int, level: int, stage: int) -> int:
	var value = BASE_BY_ZONE[zone] + int(level * 1.0) + (stage - 1) * 4
	return min(92, value)


static func ai_attack_strength(level: int, stage: int) -> int:
	return min(88, 25 + int(level * 0.8) + (stage - 1) * 3)


static func success_chance(player_stat: float, difficulty: int, momentum: float, trait_bonus: int, min_pct: int = 8, max_pct: int = 92) -> int:
	var diff = player_stat - difficulty + momentum + trait_bonus
	var pct = 50 + diff * 0.6
	return clampi(round(pct), min_pct, max_pct)
