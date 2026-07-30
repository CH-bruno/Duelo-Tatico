class_name Narration
extends RefCounted
# Narration.gd — Banco central de narração dinâmica e reativa.

# ==============================================================================
# 1. ATAQUE (Sucessos)
# ==============================================================================

const PASS_SUCCESS = [
	"%s (%s) encontrou %s (%s) com um passe preciso.",
	"%s (%s) acionou %s (%s) entre as linhas.",
	"Boa troca de passes entre %s (%s) e %s (%s).",
	"%s (%s) inverteu o jogo com categoria para %s (%s)."
]

const DRIBBLE_SUCCESS = [
	"%s (%s) deixou o marcador para trás!",
	"%s (%s) ganhou espaço com um belo drible!",
	"%s (%s) tirou o corpo da jogada e passou com facilidade!"
]

const FEINT_SUCCESS = [
	"%s (%s) aplicou uma linda finta!",
	"%s (%s) enganou completamente a marcação!",
	"%s (%s) fez a zaga balançar com o jogo de corpo!"
]

const GOAL_CALL = [
	"GOOOOOOOOOOOL!!!!",
	"É GOOOOOOL!!!",
	"BALANÇOU A REDE! GOOOOL!!!"
]

const GOAL = [
	"%s (%s) bateu colocado no canto!",
	"%s (%s) finalizou com categoria!",
	"%s (%s) não desperdiçou a oportunidade!"
]

const LONG_GOAL = [
	"%s (%s) acertou um foguete de longe!",
	"%s (%s) colocou lá no ângulo! Que golaço!",
	"%s (%s) marcou uma pintura de fora da área!"
]


# ==============================================================================
# 2. DEFESA (Usada tanto para a defesa do jogador quanto para desarmes da IA)
# ==============================================================================

const INTERCEPT_SUCCESS = [
	"🛡 %s (%s) leu a jogada perfeitamente e fez a interceptação!",
	"🛡 Passe cortado por %s (%s) na hora certa!",
	"🛡 %s (%s) se antecipou e retomou a posse de bola!"
]

const TACKLE_SUCCESS = [
	"🛡 %s (%s) veio firme por baixo e tomou a bola de forma limpa!",
	"🛡 Desarme perfeito de %s (%s) no tempo certo!",
	"🛡 %s (%s) tomou a frente do lance e ficou com a bola!"
]

const BLOCK_SUCCESS = [
	"🛡 BLOQUEIO SENSACIONAL! %s (%s) se colocou à frente do chute!",
	"🛡 %s (%s) travou a finalização no momento exato!",
	"🛡 Que parede! %s (%s) evitou o perigo com um grande bloqueio!"
]

const SLIDE_SUCCESS = [
	"🦵 CARRINHO PERFEITO! %s (%s) foi de encontro à bola e limpou o lance!",
	"🦵 NA BOLA! %s (%s) deu um carrinho espetacular e tomou a posse!",
	"🦵 Entrada cirúrgica! %s (%s) foi de carrinho e desarmou com categoria!"
]

# Quando a defesa tenta abordar, mas o atacante passa
const DEFENSE_BYPASSED = [
	"❌ %s (%s) tentou a intervenção, mas foi superado no lance.",
	"❌ O ataque levou a melhor sobre a marcação de %s (%s)!",
	"❌ %s (%s) foi batido na jogada."
]


# ==============================================================================
# 3. RECUPERAÇÃO DE POSSE (Transições)
# ==============================================================================

const ZAG_RECOVERY = [
	"%s (%s) roubou a bola do atacante na zaga.",
	"%s (%s) desarmou o centroavante com autoridade."
]

const VOL_RECOVERY = [
	"%s (%s) roubou a bola na marcação do meio-campo.",
	"%s (%s) interceptou o passe e iniciou o contra-ataque."
]

const MEI_RECOVERY = [
	"%s (%s) pressionou alto e recuperou a bola.",
	"%s (%s) retomou a posse perto da área rival."
]

const CA_RECOVERY = [
	"%s (%s) pressionou a saída de bola e roubou a posse!",
	"%s (%s) forçou o erro da defesa adversária!"
]


# ==============================================================================
# 4. FALTAS, CARTÕES E PÊNALTIS
# ==============================================================================

const FOUL_COMMITTED = [
	"⚠️ Falta dura de %s (%s) em %s (%s)!",
	"⚠️ O árbitro apita falta de %s (%s) no lance!"
]

const YELLOW_CARD = [
	"🟨 Cartão Amarelo para %s (%s) pela falta!",
	"🟨 O árbitro mostra o Amarelo para %s (%s)!"
]

const SECOND_YELLOW_CARD = [
	"🟨➡️🟥 SEGUNDO AMARELO! %s (%s) comete outra falta e é EXPULSO!"
]

const RED_CARD = [
	"🟥 CARTÃO VERMELHO DIRETO! %s (%s) comete uma falta violentíssima e está EXPULSO!"
]

const PENALTY_CALL = [
	"🚨 PÊNALTI MARCADO! Falta cometida dentro da Grande Área!"
]

const PENALTY_GOAL = [
	"⚽ GOL DE PÊNALTI! Cobrança perfeita no canto!"
]
