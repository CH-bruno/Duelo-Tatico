class_name RosterData
extends RefCounted
# Dados fixos do elenco: quem existe, atributos base, traits.
# Sem estado próprio — só dados e funções puras com tipagem forte.

const ROLES: Array[String] = ["ZAG", "VOL", "MEI", "CA"]

# PAS/DRI/SHO = ataque. INT (Interceptação, contra Passe),
# TAC (Desarme, contra Drible) e BLQ (Bloqueio, contra Chute) = defesa,
# cada um contando pra um tipo de jogada específico do adversário.
const ROSTER: Array[Dictionary] = [
	# ==========================================
	# 🛡️ ZAGUEIROS (ZAG) - 3 Atletas
	# ==========================================
	{"name": "Rocha", "role": "ZAG", "trait": "PAREDE", "PAS": 55, "DRI": 40, "SHO": 25, "INT": 45, "TAC": 50, "BLQ": 75},
	{"name": "Juan", "role": "ZAG", "trait": "INTERCEPTADOR", "PAS": 42, "DRI": 30, "SHO": 18, "INT": 80, "TAC": 55, "BLQ": 60},
	{"name": "Xandão", "role": "ZAG", "trait": "PAREDE", "PAS": 48, "DRI": 32, "SHO": 20, "INT": 50, "TAC": 58, "BLQ": 82},
	# ==========================================
	# ⚙️ VOLANTES (VOL) - 3 Atletas
	# ==========================================
	{"name": "Diego", "role": "VOL", "trait": "LADRÃO_DE_BOLA", "PAS": 62, "DRI": 50, "SHO": 35, "INT": 45, "TAC": 70, "BLQ": 35},
	{"name": "Kauê", "role": "VOL", "trait": "INCANSÁVEL", "PAS": 52, "DRI": 45, "SHO": 28, "INT": 50, "TAC": 60, "BLQ": 45},
	{"name": "Breno", "role": "VOL", "trait": "LADRÃO_DE_BOLA", "PAS": 58, "DRI": 48, "SHO": 32, "INT": 48, "TAC": 74, "BLQ": 40},
	# ==========================================
	# 🎩 MEIAS (MEI) - 3 Atletas
	# ==========================================
	{"name": "Armando", "role": "MEI", "trait": "ARMADOR", "PAS": 70, "DRI": 52, "SHO": 38, "INT": 25, "TAC": 30, "BLQ": 20},
	{"name": "Rafinha", "role": "MEI", "trait": "ATIRADOR", "PAS": 28, "DRI": 38, "SHO": 78, "INT": 15, "TAC": 15, "BLQ": 15},
	{"name": "Caio", "role": "MEI", "trait": "ARMADOR", "PAS": 76, "DRI": 58, "SHO": 42, "INT": 20, "TAC": 28, "BLQ": 18},
	# ==========================================
	# ⚽ CENTROAVANTES (CA) - 3 Atletas
	# ==========================================
	{"name": "Fominha", "role": "CA", "trait": "FINALIZADOR", "PAS": 40, "DRI": 50, "SHO": 65, "INT": 20, "TAC": 25, "BLQ": 25},
	{"name": "Nunes", "role": "CA", "trait": "PRESSÃO_ALTA", "PAS": 58, "DRI": 60, "SHO": 58, "INT": 30, "TAC": 55, "BLQ": 25},
	{"name": "Bruno", "role": "CA", "trait": "FINALIZADOR", "PAS": 38, "DRI": 52, "SHO": 72, "INT": 18, "TAC": 20, "BLQ": 20}
]

# ==========================================
# 🧤 GOLEIROS (GOL) - Fora da linha de 4, escalação própria
# ==========================================
# REF (Reflexos) pesa mais em chutes de dentro da área;
# POS (Posicionamento) pesa mais em chutes de longe;
# DEF (Defesa Geral) é o "piso" que sempre entra um pouco na conta.
const GOALKEEPERS: Array[Dictionary] = [
	{"name": "Batista", "role": "GOL", "trait": "REFLEXO_FELINO", "REF": 70, "POS": 52, "DEF": 48},
	{"name": "Wescley", "role": "GOL", "trait": "MURALHA", "REF": 48, "POS": 50, "DEF": 72},
	{"name": "Igor", "role": "GOL", "trait": "ANTECIPADOR", "REF": 54, "POS": 74, "DEF": 46}
]

static func candidates_for(role_idx: int) -> Array[int]:
	var role: String = ROLES[role_idx]
	var result: Array[int] = []
	for i in range(ROSTER.size()):
		if ROSTER[i]["role"] == role:
			result.append(i)
	return result


static func candidates_for_gk() -> Array[int]:
	var result: Array[int] = []
	for i in range(GOALKEEPERS.size()):
		result.append(i)
	return result


static func trait_name(trait_id: String) -> String:
	match trait_id:
		"PAREDE": return "Parede (+Bloqueio)"
		"INTERCEPTADOR": return "Interceptador (+Interceptação)"
		"LADRÃO_DE_BOLA": return "Ladrão de Bola (+Desarme)"
		"INCANSÁVEL": return "Incansável (Pressão pós-perda)"
		"ARMADOR": return "Armador (+Passe)"
		"ATIRADOR": return "Atirador (+Chute de Longe)"
		"FINALIZADOR": return "Finalizador (+Chute)"
		"PRESSÃO_ALTA": return "Pressão Alta (+Desarme no Ataque)"
		"REFLEXO_FELINO": return "Reflexo Felino (+Defesa em chutes de dentro da área)"
		"MURALHA": return "Muralha (+Defesa Geral)"
		"ANTECIPADOR": return "Antecipador (+Defesa em chutes de longe)"
		_: return trait_id


static func trait_bonus(player: Dictionary, action: String) -> int:
	var p_trait: String = player.get("trait", "")
	if p_trait == "":
		return 0
	match p_trait:
		"ARMADOR":
			if action == "PASS": return 8
		"ATIRADOR":
			if action == "LONG_SHO": return 10
		"FINALIZADOR":
			if action == "SHO": return 8
		"PRESSÃO_ALTA":
			if action == "TACKLE": return 10
		"PAREDE":
			if action == "BLOCK": return 10
		"INTERCEPTADOR":
			if action == "INTERCEPT": return 14
		"LADRÃO_DE_BOLA":
			if action == "TACKLE": return 12
		"INCANSÁVEL":
			if action == "TACKLE" or action == "INTERCEPT":
				return 8
		"REFLEXO_FELINO":
			if action == "SAVE": return 10
		"MURALHA":
			if action == "SAVE" or action == "SAVE_LONG": return 8
		"ANTECIPADOR":
			if action == "SAVE_LONG": return 12
	return 0
