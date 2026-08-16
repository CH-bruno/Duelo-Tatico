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
	"%s (%s) inverteu o jogo com categoria para %s (%s).",
	"%s (%s) serviu %s (%s) na medida certa!",
	"%s (%s) achou um belo passe enfiado para %s (%s).",
	"Passe limpo de %s (%s) nos pés de %s (%s)."
]

const DRIBBLE_SUCCESS = [
	"%s (%s) deixou o marcador para trás!",
	"%s (%s) ganhou espaço com um belo drible!",
	"%s (%s) tirou o corpo da jogada e passou com facilidade!",
	"%s (%s) entortou a marcação e avançou!",
	"Que drible desconcertante de %s (%s)!",
	"%s (%s) rabiscou pra cima do defensor e deixou ele na saudade!"
]

const FEINT_SUCCESS = [
	"%s (%s) aplicou uma linda finta!",
	"%s (%s) enganou completamente a marcação!",
	"%s (%s) fez a zaga balançar com o jogo de corpo!",
	"Finta desconcertante! %s (%s) tirou o defensor do lance!",
	"%s (%s) fingiu que ia para um lado e cortou pro outro com maestria!"
]

const GOAL_CALL = [
	"GOOOOOOOOOOOL!!!!",
	"É GOOOOOOL!!!",
	"BALANÇOU A REDE! GOOOOL!!!",
	"GOOOOOOOOOOOOOOOOLAZO!!!"
]

const GOAL = [
	"%s (%s) bateu colocado no canto!",
	"%s (%s) finalizou com categoria!",
	"%s (%s) não desperdiçou a oportunidade!",
	"%s (%s) soltou o pé e estufou as redes!",
	"%s (%s) tirou totalmente do alcance do goleiro!"
]

const LONG_GOAL = [
	"%s (%s) acertou um foguete de longe!",
	"%s (%s) colocou lá no ângulo! Que golaço!",
	"%s (%s) marcou uma pintura de fora da área!",
	"%s (%s) mandou um míssil defensável direto pro fundo da rede!"
]

const GOAL_FAIL = [
	"O chute de %s (%s) foi bloqueado pela zaga!",
	"Isso foi longe! %s (%s) pegou muito mal na bola.",
	"%s (%s) tentou o chute, mas a bola saiu pela linha de fundo!",
	"Travado! A marcação impediu a finalização de %s (%s)."
]

# ==============================================================================
# 1B. GOLEIRO (Camada 2 — depois que o chute supera a marcação)
# ==============================================================================

const GK_SAVE = [
	"🧤 Defesa segura do goleiro %s!",
	"🧤 %s espalma para escanteio!",
	"🧤 Na trave! %s evita o gol certo!",
	"🧤 %s se estica todo e faz a defesa!",
	"🧤 %s desvia com a ponta dos dedos!",
	"🧤 Grande intervenção de %s!"
]

const GK_MIRACLE_SAVE = [
	"🧤🔥 DEFESA IMPOSSÍVEL! %s faz um milagre!",
	"🧤🔥 QUE DEFESA! %s tira uma bola incrível de cima da linha!",
	"🧤🔥 Ninguém acreditava, mas %s salvou o time sozinho!",
	"🧤🔥 ABSURDO! %s voou no ângulo e tirou o gol certo!"
]

# 🛡️ O marcador (zagueiro) NÃO consegue bloquear — o chute passa pra
# camada do goleiro. Usa nome/role do marcador, igual BLOCK_SUCCESS.
const BLOCK_FAIL = [
	"⚠️ %s (%s) não chega a tempo no bloqueio!",
	"⚠️ %s (%s) fica no caminho errado e o chute passa!",
	"⚠️ %s (%s) tenta se jogar na frente, mas não alcança!",
	"⚠️ Marcação furada! %s (%s) não consegue impedir a finalização.",
	"⚠️ %s (%s) é driblado no lance e vê o chute seguir para o gol!"
]

# 🥅 O goleiro é vazado — usado logo antes do "GOOOOL!" pra creditar a
# falha dele especificamente, e não só anunciar o gol do atacante.
const GK_BEATEN = [
	"🥅 %s não alcança dessa vez!",
	"🥅 %s fica no chão e vê a bola morrer no fundo da rede!",
	"🥅 Sem chances para %s!",
	"🥅 %s se estica mas não chega!",
	"🥅 %s é batido no lance!"
]

# ==============================================================================
# 2. DEFESA (Usada para desarmes do jogador e da IA)
# ==============================================================================

const INTERCEPT_SUCCESS = [
	"🛡 %s (%s) leu a jogada perfeitamente e fez a interceptação!",
	"🛡 Passe cortado por %s (%s) na hora certa!",
	"🛡 %s (%s) se antecipou e retomou a posse de bola!",
	"🛡 %s (%s) esticou a perna e travou a linha de passe!",
	"🛡 Atento no lance, %s (%s) tomou a frente e ficou com a bola."
]

const TACKLE_SUCCESS = [
	"🛡 %s (%s) veio firme por baixo e tomou a bola de forma limpa!",
	"🛡 Desarme perfeito de %s (%s) no tempo certo!",
	"🛡 %s (%s) tomou a frente do lance e ficou com a bola!",
	"🛡 %s (%s) chegou na bola com precisão cirúrgica!",
	"🛡 Sem dar espaço, %s (%s) tomou a posse no corpo a corpo."
]

const BLOCK_SUCCESS = [
	"🛡 BLOQUEIO SENSACIONAL! %s (%s) se colocou à frente do chute!",
	"🛡 %s (%s) travou a finalização no momento exato!",
	"🛡 Que parede! %s (%s) evitou o perigo com um grande bloqueio!",
	"🛡 %s (%s) se atirou na bola e abafou o chute!",
	"🛡 Chute amortecido e bloqueado com firmeza por %s (%s)!"
]

const SLIDE_SUCCESS = [
	"🦵 CARRINHO PERFEITO! %s (%s) foi de encontro à bola e limpou o lance!",
	"🦵 NA BOLA! %s (%s) deu um carrinho espetacular e tomou a posse!",
	"🦵 Entrada cirúrgica! %s (%s) foi de carrinho e desarmou com categoria!",
	"🦵 %s (%s) desceu de carrinho, levou só a bola e levantou a torcida!"
]

# Quando o atacante supera o defensor
const DEFENSE_BYPASSED = [
	"❌ %s (%s) tentou a intervenção, mas foi superado no lance.",
	"❌ O ataque levou a melhor sobre a marcação de %s (%s)!",
	"❌ %s (%s) foi batido na jogada.",
	"❌ %s (%s) chegou atrasado na marcação e viu a jogada passar."
]


# ==============================================================================
# 3. RECUPERAÇÃO DE POSSE (Transições)
# ==============================================================================

const ZAG_RECOVERY = [
	"%s (%s) roubou a bola do atacante na zaga.",
	"%s (%s) desarmou o centroavante com autoridade.",
	"%s (%s) impôs respeito no setor defensivo e ficou com a bola."
]

const VOL_RECOVERY = [
	"%s (%s) roubou a bola na marcação do meio-campo.",
	"%s (%s) interceptou o passe e iniciou o contra-ataque.",
	"%s (%s) morde na marcação e recupera a posse no meio!"
]

const MEI_RECOVERY = [
	"%s (%s) pressionou alto e recuperou a bola.",
	"%s (%s) retomou a posse perto da área rival.",
	"%s (%s) roubou a bola no campo de ataque!"
]

const CA_RECOVERY = [
	"%s (%s) pressionou a saída de bola e roubou a posse!",
	"%s (%s) forçou o erro da defesa adversária!",
	"%s (%s) brigou pela bola e ganhou a dividida no ataque!"
]


# ==============================================================================
# 4. FALTAS, CARTÕES E PÊNALTIS (EXPANDIDO)
# ==============================================================================

# Faltas Simples / Drible travado com falta
const FOUL_COMMITTED = [
	"⚠️ Falta dura de %s (%s) em %s (%s)!",
	"⚠️ O árbitro apita falta de %s (%s) no lance!",
	"⚠️ %s (%s) chega atrasado e comete a falta em %s (%s).",
	"⚠️ Entrada faltosa de %s (%s) para parar a jogada!",
	"⚠️ O juiz paralisa o jogo! Falta cometida por %s (%s)."
]

# Faltas resultantes de Carrinho Furado
const FOUL_SLIDE = [
	"⚠️ Falta.CARRINHO PERIGOSO! %s (%s) errou a bola e atingiu %s (%s)!",
	"⚠️ Falta.Entrou com muita sede! %s (%s) atropelou o adversário de carrinho!",
	"⚠️ Falta clara de carrinho de %s (%s)!"
]

# Recomeço após falta comum (sem cobrança direta)
const FOUL_RESTART = [
	"O jogo recomeça com a posse mantida no mesmo setor.",
	"Apito do juiz. A posse de bola continua com a equipe que sofreu a falta.",
	"Falta cobrada rapidamente. O ataque retoma a posse."
]

# Cartão Amarelo
const YELLOW_CARD = [
	"🟨 Cartão Amarelo para %s (%s) pela falta!",
	"🟨 O árbitro não tolera a entrada e mostra o Amarelo para %s (%s)!",
	"🟨 Cartão Amarelo mostrado para %s (%s) após a infração!",
	"🟨 Chegou forte demais! %s (%s) entra para o caderno de amarelados."
]

# Segundo Amarelo -> Expulsão
const SECOND_YELLOW_CARD = [
	"🟨➡️🟥 SEGUNDO AMARELO! %s (%s) comete outra falta e é EXPULSO!",
	"🟨➡️🟥 É o segundo amarelo de %s (%s)! O árbitro puxa o vermelho e manda pro vestiário!",
	"🟨➡️🟥 Reincidência de %s (%s)! Recebe o segundo amarelo e deixa o time com um a menos!"
]

# Vermelho Direto
const RED_CARD = [
	"🟥 CARTÃO VERMELHO DIRETO! %s (%s) comete uma falta violentíssima e está EXPULSO!",
	"🟥 É RUA! Entrada desleal de %s (%s) e expulsão direta decretada!",
	"🟥 VERMELHO DIRETO! %s (%s) vai mais cedo pro chuveiro após entrada perigosíssima!"
]

# Anúncio de Pênalti
const PENALTY_CALL = [
	"🚨 PÊNALTI MARCADO! Falta cometida dentro da Grande Área!",
	"🚨 APONTOU PARA A MARCA DA CAL! É PÊNALTI!",
	"🚨 Falta dentro da área! O árbitro não hesita e marca o PÊNALTI!"
]

# 🎯 Cobrador anuncia o lado escolhido
const PENALTY_KICK_ANNOUNCE = [
	"🎯 %s (%s) escolhe o canto e mira pro lado %s.",
	"🎯 %s (%s) já decidiu: vai de %s.",
	"🎯 %s (%s) se prepara, mirando o lado %s.",
	"🎯 %s (%s) aponta a bola pro lado %s."
]

# 🧤 Goleiro foi pro lado certo — vira duelo de verdade
const PENALTY_GK_GUESSED_RIGHT = [
	"🧤 %s vai pro lado certo!",
	"🧤 %s leu a cobrança e pulou no canto certo!",
	"🧤 %s não caiu no truque — foi pro lado certo!",
	"🧤 %s adivinhou o canto!"
]

# ↔️ Goleiro foi pro lado errado — cobrador muito favorito
const PENALTY_GK_GUESSED_WRONG = [
	"↔️ %s foi pro lado errado!",
	"↔️ %s caiu no outro canto — caminho livre!",
	"↔️ %s escorregou pro lado errado!",
	"↔️ %s se atirou no canto errado!"
]

# Gol de Pênalti
const PENALTY_GOAL = [
	"⚽ GOL DE PÊNALTI! Cobrança perfeita no canto!",
	"⚽ DESLOCOU O GOLEIRO! Cobrança impecável de pênalti!",
	"⚽ Bateu firme na bochecha da rede! Gol de pênalti!"
]

# Pênalti Perdido/Defendido
const PENALTY_FAIL = [
	"❌ PERDEU O PÊNALTI! O chute explodiu na trave!",
	"❌ DEFESSAÇA NO PÊNALTI! O goleiro buscou no canto!",
	"❌ PRA FORA! A cobrança de pênalti subiu demais e foi por cima!"
]
