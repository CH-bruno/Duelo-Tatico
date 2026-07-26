extends RefCounted
# OpponentTeams.gd — Banco de dados de times adversários para Campanha e Desafio.

const TEAMS = [
	{
		"name": "Time de Bairro",
		"squad": [
			{"name":"Marquinho","role":"ZAG","PAS":48,"DRI":42,"SHO":36,"INT":60,"TAC":62,"BLQ":64},
			{"name":"Bino","role":"VOL","PAS":56,"DRI":52,"SHO":40,"INT":60,"TAC":60,"BLQ":52},
			{"name":"Juca","role":"MEI","PAS":60,"DRI":58,"SHO":54,"INT":45,"TAC":42,"BLQ":40},
			{"name":"Pipoca","role":"CA","PAS":48,"DRI":56,"SHO":62,"INT":38,"TAC":36,"BLQ":35},
		]
	},
	{
		"name":"Time Regional",
		"squad":[
			{"name":"Cardoso","role":"ZAG","PAS":56,"DRI":48,"SHO":42,"INT":68,"TAC":70,"BLQ":72},
			{"name":"Renatinho","role":"VOL","PAS":62,"DRI":58,"SHO":48,"INT":66,"TAC":68,"BLQ":60},
			{"name":"Válber","role":"MEI","PAS":68,"DRI":66,"SHO":60,"INT":52,"TAC":48,"BLQ":46},
			{"name":"Índio","role":"CA","PAS":56,"DRI":66,"SHO":70,"INT":45,"TAC":42,"BLQ":40},
		]
	},
	{
		"name":"Time Estadual",
		"squad":[
			{"name":"Bruno Reis","role":"ZAG","PAS":62,"DRI":56,"SHO":48,"INT":76,"TAC":78,"BLQ":80},
			{"name":"Kadu","role":"VOL","PAS":70,"DRI":66,"SHO":56,"INT":74,"TAC":74,"BLQ":66},
			{"name":"Everson","role":"MEI","PAS":76,"DRI":74,"SHO":68,"INT":58,"TAC":56,"BLQ":52},
			{"name":"Fabinho","role":"CA","PAS":62,"DRI":74,"SHO":78,"INT":48,"TAC":46,"BLQ":44},
		]
	},
	{
		"name":"Time Nacional",
		"squad":[
			{"name":"Wanderley","role":"ZAG","PAS":70,"DRI":62,"SHO":54,"INT":84,"TAC":86,"BLQ":88},
			{"name":"Cassiano","role":"VOL","PAS":76,"DRI":72,"SHO":62,"INT":82,"TAC":82,"BLQ":74},
			{"name":"Denner","role":"MEI","PAS":82,"DRI":80,"SHO":74,"INT":66,"TAC":62,"BLQ":58},
			{"name":"Bala","role":"CA","PAS":70,"DRI":80,"SHO":84,"INT":56,"TAC":52,"BLQ":50},
		]
	},
	{
		"name":"Grande Final",
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
	return TEAMS[idx]


static func team_for_challenge(wins: int) -> Dictionary:
	var idx = wins % TEAMS.size()
	var loops = wins / TEAMS.size()
	
	# Faz uma cópia profunda para não alterar os dados originais
	var base_team = TEAMS[idx].duplicate(true)
	
	# Se já completou uma volta, adiciona +3 em todos os atributos por ciclo
	if loops > 0:
		base_team["name"] = "%s (Nível +%d)" % [base_team["name"], loops]
		for player in base_team["squad"]:
			for stat in ["PAS", "DRI", "SHO", "INT", "TAC", "BLQ"]:
				player[stat] = min(99, player[stat] + (loops * 3))
				
	return base_team
