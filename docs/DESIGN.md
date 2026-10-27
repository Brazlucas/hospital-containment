# HOSPITAL: Protocolo de Contenção

Roguelite de arena (estilo Brotato) no universo do HOSPITAL: um paciente preso numa ala que sofre surtos de
criaturas. Sobrevive a ondas, coleta materiais, escolhe melhorias entre as rodadas. Visual top-down 2D, 480x270.

**Princípio de produção:** arte simples (1 lado desenhado + `flip_h`, 2 a 3 animações por entidade) e variedade
vinda de *sistemas*, não de conteúdo novo. Toda arma, inimigo, upgrade e onda é um arquivo de dados.

## Loop

1. A onda começa; zumbis surgem em pontos marcados com um X vermelho (telegraph de 0,8 s).
2. A arma mira e atira sozinha no inimigo mais próximo. O jogador só se move (WASD / setas).
3. Inimigos mortos soltam materiais. Materiais valem moeda **e** XP.
4. Fim da onda: os zumbis restantes caem, os materiais voam até o jogador.
5. Cada nível ganho na onda vira uma escolha de 1 entre 3 upgrades.
6. Próxima onda, mais difícil. Sobreviver à última = vitória; morrer = fim da run (ENTER reinicia).

## Estrutura

```
scenes/arena/arena.tscn    cena principal: piso, paredes, Entities (y-sort), WaveDirector, HUD, UpgradeScreen
scripts/autoload/          Events (sinais), RunState (stats/XP/materiais da run), AudioManager
scripts/core/              Stats (sistema de atributos), Targeting, DataLibrary
scripts/data/              Resources: WeaponData, EnemyData, UpgradeData, WaveData, CharacterData
scripts/player|weapons|enemies|pickups|arena|ui|effects/
resources/data/            os .tres de conteúdo (ver abaixo)
```

Camadas de física: `world`(1), `player`(2), `enemy`(3), `enemy_hurtbox`(4). Projéteis só enxergam a hurtbox.

## Como adicionar conteúdo

| Quer | Faça |
|---|---|
| Upgrade | novo `.tres` (UpgradeData) em `resources/data/upgrades/`. A tela de upgrade varre a pasta, não precisa registrar |
| Atributo novo | uma linha em `Stats.INFO` e leia o valor onde importa (`RunState.stats.mult("x_pct")`) |
| Inimigo | novo `.tres` (EnemyData) + SpriteFrames com `walk` (e `idle`/`attack`) virados pra direita; coloque no `enemies` de uma onda |
| Arma | novo `.tres` (WeaponData); o `Weapon` já cuida de mira, tiro, recuo e flash |
| Onda | novo `.tres` (WaveData) e adicione em `waves` no `arena.tscn` |
| Personagem | novo `.tres` (CharacterData) com stats iniciais e arma inicial |

## O que veio do projeto antigo (`hospital-adventure-test`)

Reaproveitado: sprites do player e dos 2 zumbis (só os frames virados pra direita, em `idle`/`walk`/`attack`),
ícone da pistola, flash de tiro, moeda, gibs e decais de sangue, sons de tiro/zumbi/UI, fonte e tema de UI,
shaders de dano (`hurt_flash`, `character_motion`), e a lógica de gore/knockback/ímã de moeda (reescrita sem iso).

Deixado de fora: isometria (`Iso`), salas/portas/NPCs/diálogo/save/sanidade/chaves, animações em 8 direções,
tiles de chão e props (são losangos isométricos, não servem em top-down), arte de intro, jardim e estacionamento.
O repositório antigo continua intacto.

## Estado atual vs. meta do primeiro protótipo

| Meta | Agora |
|---|---|
| 1 arena | ok (640x360, chão **placeholder** desenhado em código) |
| 1 personagem | ok (Paciente) |
| 3 armas | 1 (pistola) |
| 4 inimigos | 2 (médico infectado, rastejante) |
| 10 melhorias | 10 |
| partida de ~10 min | 5 ondas, ~3 min |
| chefe final | falta |

## Próximos passos sugeridos

1. Loja entre ondas (gastar materiais em armas/itens) e mais de um slot de arma.
2. Mais 2 armas (ex.: bisturi corpo a corpo, seringa que perfura) e 2 inimigos (um à distância, um tanque).
3. Chefe na última onda; estender para ~10 ondas.
4. Arte: piso top-down da arena, sprite de arma própria por arma, números de dano flutuantes.
5. Tela inicial, escolha de personagem, pausa, volume.
6. Balanceamento: `RunState.XP_BASE/XP_STEP`, `WaveData`, `EnemyData`.
