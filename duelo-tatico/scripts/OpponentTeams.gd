extends RefCounted
# OpponentTeams.gd — Banco de dados de times adversários para Campanha e Desafio.

const TEAMS = [
	{
		"name": "Time de Bairro",
		"goalkeeper": {"name": "Zezinho", "role": "GOL", "trait": "", "REF": 45, "POS": 42, "DEF": 44},
		"squad": [
			{"name":"Marquinho","role":"ZAG","PAS":48,"DRI":42,"SHO":36,"INT":60,"TAC":62,"BLQ":64},
			{"name":"Bino","role":"VOL","PAS":56,"DRI":52,"SHO":40,"INT":60,"TAC":60,"BLQ":52},
			{"name":"Juca","role":"MEI","PAS":60,"DRI":58,"SHO":54,"INT":45,"TAC":42,"BLQ":40},
			{"name":"Pipoca","role":"CA","PAS":48,"DRI":56,"SHO":62,"INT":38,"TAC":36,"BLQ":35},
		]
	},
	{
		"name":"Time Regional",
		"goalkeeper": {"name": "PC", "role": "GOL", "trait": "", "REF": 52, "POS": 50, "DEF": 54},
		"squad":[
			{"name":"Cardoso","role":"ZAG","PAS":56,"DRI":48,"SHO":42,"INT":68,"TAC":70,"BLQ":72},
			{"name":"Renatinho","role":"VOL","PAS":62,"DRI":58,"SHO":48,"INT":66,"TAC":68,"BLQ":60},
			{"name":"Válber","role":"MEI","PAS":68,"DRI":66,"SHO":60,"INT":52,"TAC":48,"BLQ":46},
			{"name":"Índio","role":"CA","PAS":56,"DRI":66,"SHO":70,"INT":45,"TAC":42,"BLQ":40},
		]
	},
	{
		"name":"Time Estadual",
		"goalkeeper": {"name": "Marcelinho", "role": "GOL", "trait": "MURALHA", "REF": 60, "POS": 58, "DEF": 66},
		"squad":[
			{"name":"Bruno Reis","role":"ZAG","PAS":62,"DRI":56,"SHO":48,"INT":76,"TAC":78,"BLQ":80},
			{"name":"Kadu","role":"VOL","PAS":70,"DRI":66,"SHO":56,"INT":74,"TAC":74,"BLQ":66},
			{"name":"Everson","role":"MEI","PAS":76,"DRI":74,"SHO":68,"INT":58,"TAC":56,"BLQ":52},
			{"name":"Fabinho","role":"CA","PAS":62,"DRI":74,"SHO":78,"INT":48,"TAC":46,"BLQ":44},
		]
	},
	{
		"name":"Time Nacional",
		"goalkeeper": {"name": "Weverton", "role": "GOL", "trait": "REFLEXO_FELINO", "REF": 76, "POS": 70, "DEF": 74},
		"squad":[
			{"name":"Wanderley","role":"ZAG","PAS":70,"DRI":62,"SHO":54,"INT":84,"TAC":86,"BLQ":88},
			{"name":"Cassiano","role":"VOL","PAS":76,"DRI":72,"SHO":62,"INT":82,"TAC":82,"BLQ":74},
			{"name":"Denner","role":"MEI","PAS":82,"DRI":80,"SHO":74,"INT":66,"TAC":62,"BLQ":58},
			{"name":"Bala","role":"CA","PAS":70,"DRI":80,"SHO":84,"INT":56,"TAC":52,"BLQ":50},
		]
	},
	{
		"name":"Grande Final",
		"goalkeeper": {"name": "Muralha", "role": "GOL", "trait": "MURALHA", "REF": 84, "POS": 82, "DEF": 90},
		"squad":[
			{"name":"Aço","role":"ZAG","PAS":76,"DRI":68,"SHO":60,"INT":92,"TAC":92,"BLQ":92},
			{"name":"Furacão","role":"VOL","PAS":84,"DRI":80,"SHO":72,"INT":88,"TAC":88,"BLQ":82},
			{"name":"Maestro","role":"MEI","PAS":90,"DRI":90,"SHO":84,"INT":74,"TAC":70,"BLQ":66},
			{"name":"Foguete","role":"CA","PAS":78,"DRI":88,"SHO":92,"INT":60,"TAC":56,"BLQ":54},
		]
	},
]


static func team_for_stage(stage: int) -> Dictionary:
	var idx = clampi(stage - 1, 0, TEAMS.size() - 1)
	# 🔒 Cópia profunda: TEAMS é const e compartilhado por toda a sessão do
	# jogo. Sem isso, cartões/expulsões da IA gravados aqui vazariam pra
	# qualquer partida futura contra o mesmo time, pra sempre.
	return TEAMS[idx].duplicate(true)


static func team_for_challenge(wins: int) -> Dictionary:
	var idx = wins % TEAMS.size()
	var loops: int = int(float(wins) / TEAMS.size())
	
	# Faz uma cópia profunda para não alterar os dados originais
	var base_team = TEAMS[idx].duplicate(true)
	
	# Se já completou uma volta, adiciona +3 em todos os atributos por ciclo
	if loops > 0:
		base_team["name"] = "%s (Nível +%d)" % [base_team["name"], loops]
		for player in base_team["squad"]:
			for stat in ["PAS", "DRI", "SHO", "INT", "TAC", "BLQ"]:
				player[stat] = min(99, player[stat] + (loops * 3))

		# 🧤 O goleiro escala junto com o resto do time nas voltas do Desafio
		var gk = base_team.get("goalkeeper", {})
		for stat in ["REF", "POS", "DEF"]:
			if gk.has(stat):
				gk[stat] = min(99, gk[stat] + (loops * 3))

	return base_team


# 🔄 Constrói (uma vez por partida) o squad ativo do adversário: parte
# sempre dos dados originais (via current_opponent_team(), já duplicados)
# e aplica cartão/expulsão a partir de ai_players_out / ai_yellow_cards no
# GameState — nunca escreve de volta em TEAMS.
static func build_active_squad(gs: Node) -> Array:
	var raw_squad: Array = gs.current_opponent_team().get("squad", [])
	var final_squad: Array = []
	for i in range(raw_squad.size()):
		var p = raw_squad[i]
		p["is_ejected"] = i in gs.ai_players_out
		p["has_yellow"] = gs.ai_yellow_cards.get(i, false)
		final_squad.append(p)
	return final_squad
