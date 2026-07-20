extends RefCounted
# Dados fixos do elenco: quem existe, atributos base, traits.
# Sem estado próprio — só dados e funções puras. Não sabe nada sobre
# "o jogo agora" (zona, placar, etc.) — só quem SÃO os jogadores.

const ROLES = ["ZAG", "VOL", "MEI", "CA"]

const ROSTER = [
	{"name": "Rocha", "role": "ZAG", "trait": "PAREDE", "PAS": 55, "DRI": 40, "SHO": 25, "DEF": 65},
	{"name": "Muralha", "role": "ZAG", "trait": "INTERCEPTADOR", "PAS": 42, "DRI": 30, "SHO": 18, "DEF": 78},
	{"name": "Diego", "role": "VOL", "trait": "LADRÃO_DE_BOLA", "PAS": 62, "DRI": 50, "SHO": 35, "DEF": 55},
	{"name": "Kauê", "role": "VOL", "trait": "INCANSÁVEL", "PAS": 52, "DRI": 45, "SHO": 28, "DEF": 68},
	{"name": "Armando", "role": "MEI", "trait": "DRIBLADOR", "PAS": 58, "DRI": 60, "SHO": 48, "DEF": 35},
	{"name": "Rafinha", "role": "MEI", "trait": "ARMADOR", "PAS": 70, "DRI": 52, "SHO": 38, "DEF": 25},
	{"name": "Nunes", "role": "CA", "trait": "FINALIZADOR", "PAS": 40, "DRI": 50, "SHO": 65, "DEF": 25},
	{"name": "Fominha", "role": "CA", "trait": "ATIRADOR", "PAS": 28, "DRI": 38, "SHO": 78, "DEF": 12},
]


static func candidates_for(role_idx: int) -> Array:
	# Retorna os índices do ROSTER que jogam na posição de ROLES[role_idx].
	var role = ROLES[role_idx]
	var result = []
	for i in range(ROSTER.size()):
		if ROSTER[i]["role"] == role:
			result.append(i)
	return result


static func trait_name(trait_id: String) -> String:
	match trait_id:
		"PAREDE":
			return "Parede (+Defesa)"
		"INTERCEPTADOR":
			return "Interceptador (+Recuperação)"
		"LADRÃO_DE_BOLA":
			return "Ladrão de Bola (+Recuperação)"
		"INCANSÁVEL":
			return "Incansável (Pressão pós-perda)"
		"ARMADOR":
			return "Armador (+Passe)"
		"DRIBLADOR":
			return "Driblador (+Drible/Finta)"
		"FINALIZADOR":
			return "Finalizador (+Chute)"
		"ATIRADOR":
			return "Atirador (+Chute de Longe)"
		_:
			return trait_id


static func trait_bonus(player: Dictionary, action: String) -> int:
	# Recebe o jogador como parâmetro (em vez de ler "o jogador ativo" de
	# algum lugar global) — assim essa função não depende de mais nada.
	match player["trait"]:
		"ARMADOR":
			if action == "PASS":
				return 8
		"DRIBLADOR":
			if action == "DRI" or action == "FEINT":
				return 8
		"FINALIZADOR":
			if action == "SHO":
				return 8
		"ATIRADOR":
			if action == "LONG_SHO":
				return 10
	return 0
