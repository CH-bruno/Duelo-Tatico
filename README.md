# Duelo Tático

Jogo tático que combina futebol e RPG, desenvolvido sozinho em **Godot (GDScript)**.

Cada jogador do time ocupa uma posição fixa em campo, com atributos próprios (passe, drible, chute, defesa) e traços especiais individuais. O controle passa de jogador em jogador conforme a bola circula entre as zonas do campo, e cada duelo de posição (atacante x defensor) é resolvido com base nesses atributos.

## Modos de jogo

- **Campanha** — 5 estágios com dificuldade progressiva, com uma tela de escalação entre as partidas para escolher os titulares do elenco.
- **Desafio** — modo de sobrevivência sem fim, com dificuldade crescente a cada vitória e um recorde pessoal de sequência de vitórias.

## Principais funcionalidades

- Sistema de elenco com 2 jogadores candidatos por posição e tela de seleção de titulares
- Traços de jogador com bônus especiais individuais
- Narração de eventos da partida gerada de forma dinâmica
- Campo bidirecional com gol em cada extremidade e duelos de coluna (atacante x defensor)
- Atributos de defesa divididos em três frentes: interceptação, desarme e bloqueio
- Sistema de energia/stamina por jogador
- Sistema de expulsão (cartão vermelho) integrado ao fluxo da partida
- Progresso salvo localmente (JSON), com opção de continuar de onde parou

## Arquitetura

O projeto é organizado em módulos separados para manter o código sustentável conforme cresceu:

- `RosterData` — dados estáticos do elenco e dos traços dos jogadores
- `Rules` — fórmulas de balanceamento e regras de partida
- Persistência de progresso (nível, XP, estágio, escalação, recorde do modo Desafio) em `user://`

## Tecnologias

- Godot Engine
- GDScript

## Status

Projeto em desenvolvimento ativo — melhorias recentes incluem o refinamento da interação entre o sistema de expulsão e o sistema de energia dos jogadores.
