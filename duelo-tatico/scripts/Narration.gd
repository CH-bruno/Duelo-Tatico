class_name Narration
extends RefCounted

const PASS_SUCCESS = [
	"%s (%s) encontrou %s (%s) com um passe preciso.",
	"%s (%s) acionou %s (%s) entre as linhas.",
	"Boa troca de passes entre %s (%s) e %s (%s).",
	"%s (%s) inverteu a jogada para %s (%s)."
]

const PASS_FAIL = [
	"O passe de %s (%s) para %s (%s) foi interceptado.",
	"%s (%s) errou o passe para %s (%s).",
	"%s (%s) tentou achar %s (%s), mas a defesa cortou."
]

const DRIBBLE = [
	"%s (%s) deixou o marcador para trás.",
	"%s (%s) ganhou espaço com um belo drible.",
	"%s (%s) passou com facilidade pelo adversário."
]

const DRIBBLE_FAIL = [
	"%s (%s) tentou o drible, mas perdeu a bola.",
	"%s (%s) foi desarmado.",
	"O marcador levou a melhor sobre %s (%s).",
	"%s (%s) exagerou no drible e perdeu a posse."
]

const FEINT = [
	"%s (%s) aplicou uma linda finta.",
	"%s (%s) enganou completamente a marcação.",
	"%s (%s) fez o defensor ficar na saudade."
]

const FEINT_FAIL = [
	"%s (%s) tentou a finta, mas o defensor não caiu.",
	"A finta de %s (%s) não funcionou.",
	"%s (%s) perdeu a bola na tentativa.",
	"%s (%s) tentou um lance de efeito e foi desarmado."
]

const GOAL_CALL = [
	"GOOOOOOOOOOOL!!!!",
	"GOOOOOOOOOL!!!",
	"É GOOOOOOL!!!",
	"GOOOOOOOOOOOOOOL!!!"
]

const GOAL = [
	"%s (%s) bateu colocado no canto!",
	"%s (%s) finalizou com categoria!",
	"%s (%s) não desperdiçou a oportunidade!",
	"%s (%s) acertou um lindo chute!",
	"%s (%s) venceu o goleiro!"
]

const GOAL_FAIL = [
	"%s (%s) finalizou para fora.",
	"O goleiro defendeu a finalização de %s (%s).",
	"%s (%s) chutou, mas a defesa bloqueou.",
	"%s (%s) desperdiçou uma boa oportunidade.",
	"%s (%s) bateu firme, mas a bola passou ao lado."
]

const LONG_GOAL = [
	"%s (%s) acertou um foguete de longe!",
	"%s (%s) colocou no ângulo!",
	"%s (%s) marcou um golaço de fora da área!",
	"%s (%s) soltou uma bomba indefensável!"
]

const LONG_GOAL_FAIL = [
	"%s (%s) arriscou de longe, mas mandou para fora.",
	"O goleiro defendeu o chute de longa distância de %s (%s).",
	"%s (%s) tentou surpreender de longe, mas a bola passou por cima.",
	"A defesa bloqueou o chute de longa distância de %s (%s).",
	"%s (%s) soltou a bomba, mas faltou direção."
]

const ZAG_RECOVERY = [
	"%s (%s) roubou a bola do atacante.",
	"%s (%s) desarmou o centroavante.",
	"%s (%s) antecipou a jogada e recuperou a posse."
]

const VOL_RECOVERY = [
	"%s (%s) roubou a bola no meio.",
	"%s (%s) desarmou o meia adversário.",
	"%s (%s) interceptou o passe e recuperou a posse."
]

const MEI_RECOVERY = [
	"%s (%s) pressionou e recuperou a bola.",
	"%s (%s) ganhou a dividida.",
	"%s (%s) retomou a posse no ataque."
]

const CA_RECOVERY = [
	"%s (%s) pressionou a saída e roubou a bola!",
	"%s (%s) recuperou a posse ainda no ataque!",
	"%s (%s) forçou o erro da defesa adversária!"
]
