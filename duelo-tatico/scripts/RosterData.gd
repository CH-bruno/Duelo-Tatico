extends RefCounted
# Dados fixos do elenco: quem existe, atributos base, traits.
# Sem estado próprio — só dados e funções puras.

const ROLES = ["ZAG", "VOL", "MEI", "CA"]

# PAS/DRI/SHO = ataque. INT (Interceptação, contra Passe),
# TAC (Desarme, contra Drible) e BLQ (Bloqueio, contra Chute) = defesa,
# cada um contando pra um tipo de jogada específico do adversário.
const ROSTER = [
	{"name": "Rocha", "role": "ZAG", "trait": "PAREDE", "PAS": 55, "DRI": 40, "SHO": 25, "INT": 45, "TAC": 50, "BLQ": 75},
	{"name": "Muralha", "role": "ZAG", "trait": "INTERCEPTADOR", "PAS": 42, "DRI": 30, "SHO": 18, "INT": 80, "TAC": 55, "BLQ": 60},
	{"name": "Diego", "role": "VOL", "trait": "LADRÃO_DE_BOLA", "PAS": 62, "DRI": 50, "SHO": 35, "INT": 45, "TAC": 70, "BLQ": 35},
	{"name": "Kauê", "role": "VOL", "trait": "INCANSÁVEL", "PAS": 52, "DRI": 45, "SHO": 28, "INT": 50, "TAC": 60, "BLQ": 45},
	{"name": "Armando", "role": "MEI", "trait": "DRIBLADOR", "PAS": 58, "DRI": 60, "SHO": 48, "INT": 30, "TAC": 35, "BLQ": 25},
	{"name": "Rafinha", "role": "MEI", "trait": "ARMADOR", "PAS": 70, "DRI": 52, "SHO": 38, "INT": 25, "TAC": 30, "BLQ": 20},
	{"name": "Nunes", "role": "CA", "trait": "FINALIZADOR", "PAS": 40, "DRI": 50, "SHO": 65, "INT": 20, "TAC": 25, "BLQ": 25},
	{"name": "Fominha", "role": "CA", "trait": "ATIRADOR", "PAS": 28, "DRI": 38, "SHO": 78, "INT": 15, "TAC": 15, "BLQ": 15},
]


static func candidates_for(role_idx: int) -> Array:
	var role = ROLES[role_idx]
	var result = []
	for i in range(ROSTER.size()):
		if ROSTER[i]["role"] == role:
			result.append(i)
	return result


static func trait_name(trait_id: String) -> String:
	match trait_id:
		"PAREDE":
			return "Parede (+Bloqueio)"
		"INTERCEPTADOR":
			return "Interceptador (+Interceptação)"
		"LADRÃO_DE_BOLA":
			return "Ladrão de Bola (+Desarme)"
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
		"PAREDE":
			if action == "BLOCK":
				return 10
		"INTERCEPTADOR":
			if action == "INTERCEPT":
				return 14
		"LADRÃO_DE_BOLA":
			if action == "TACKLE":
				return 12
	return 0
