# HOSPITAL: Protocolo de Contenção

Roguelite de arena (estilo Brotato) no universo do HOSPITAL: um paciente preso numa ala que sofre surtos de
criaturas. Sobrevive a ondas, coleta materiais, escolhe melhorias entre as rodadas. Visual top-down 2D, 480x270.

**Princípio de produção:** arte simples (1 pose 3/4 desenhada + `flip_h`, 2 a 3 animações por entidade) e variedade
vinda de *sistemas*, não de conteúdo novo. Toda arma, inimigo, upgrade e onda é um arquivo de dados.

## Loop

1. A onda começa; zumbis surgem em pontos marcados com um X vermelho (telegraph de 0,8 s).
2. A arma ataca sozinha o inimigo mais próximo: o taco golpeia em arco, a pistola atira. O jogador só se move (WASD / setas).
3. Inimigos mortos soltam materiais. Materiais valem moeda **e** XP.
4. Fim da onda: os zumbis restantes caem, os materiais voam até o jogador.
5. Cada nível ganho na onda vira uma escolha de 1 entre 3 upgrades.
6. Próxima onda, mais difícil. Sobreviver à última = vitória; morrer = fim da run (ENTER reinicia).

## Estrutura

```
scenes/arena/arena.tscn    cena principal: fundo, paredes, Entities (y-sort), WaveDirector, HUD, UpgradeScreen
scripts/autoload/          Events (sinais), RunState (stats/XP/materiais da run), AudioManager
scripts/core/              Stats (sistema de atributos), Targeting, DataLibrary
scripts/data/              Resources: WeaponData, EnemyData, UpgradeData, WaveData, CharacterData, ArenaLayout
scripts/player|weapons|enemies|pickups|arena|ui/
scripts/effects/           gore, reflexo (Reflector, ReflectionMap), Lamp, Fog, Puddle, Dripper, AmbienceDirector
resources/data/            os .tres de conteúdo (ver abaixo)
```

Camadas de física: `world`(1), `player`(2), `enemy`(3), `enemy_hurtbox`(4). Projéteis só enxergam a hurtbox.

## Como adicionar conteúdo

| Quer | Faça |
|---|---|
| Upgrade | novo `.tres` (UpgradeData) em `resources/data/upgrades/`. A tela de upgrade varre a pasta, não precisa registrar |
| Atributo novo | uma linha em `Stats.INFO` e leia o valor onde importa (`RunState.stats.mult("x_pct")`) |
| Inimigo | novo `.tres` (EnemyData) + SpriteFrames com `walk` (e `idle`/`attack`) virados pra baixo-direita (3/4); coloque no `enemies` de uma onda |
| Arma | novo `.tres` (WeaponData). `kind` = `RANGED` (tiro) ou `MELEE` (golpe em arco); o `Weapon` cuida de mira, tiro/golpe, recuo, flash e rastro |
| Onda | novo `.tres` (WaveData) e adicione em `waves` no `arena.tscn` |
| Personagem | novo `.tres` (CharacterData) com stats iniciais e arma inicial |
| Arena | nova imagem em `assets/arenas/` + `.tres` (ArenaLayout) com colisores, lâmpadas e poças; troque `layout` no `arena.tscn` |
| Atmosfera | novo `.tres` (AmbiencePreset) em `resources/data/ambience/` e escolha em `WaveData.ambience` |

## Armas

O personagem começa com o **taco de baseball** (`resources/data/weapons/taco.tres`, corpo a corpo): fica armado atrás do
ombro, golpeia em arco quando um zumbi chega perto, acerta **todos** no arco ao mesmo tempo e empurra bastante.
O sprite é o recorte da arte original em pixel real (52x46, girado 40,6° pra apontar pra frente, ver `icon_rotation_deg`).
Alcance e arco: `melee_reach` e `melee_arc_deg`; os upgrades de dano, velocidade de ataque, alcance e crítico valem pros dois tipos.
A pistola (`pistola.tres`) continua nos dados, pronta pra virar um item de loja.

## Arena

A sala é **uma única imagem pintada** (`assets/arenas/enfermaria.png`, 1374x1145, com a personagem do meio apagada).
O `ArenaLayout` (`resources/data/arenas/enfermaria.tres`) guarda:

- `art_scale` (0.5): pixels do jogo por pixel da imagem. Mexer nesse número redimensiona a sala inteira.
- `blockers`: retângulos de paredes e móveis, em **pixels da imagem**. Viram colisão para o player e os zumbis.
  Para ajustar, edite o array no inspetor; o spawn já evita essas áreas (`Arena.is_free`).
- `view_rect` (limites da câmera) e `player_start`.

Zumbis andam em linha reta até o player; se ficam presos num móvel, desviam de lado por instantes (`Enemy._check_blocked`).
Limitação: os móveis são parte da pintura, então o player sempre aparece por cima deles (sem y-sort contra a mobília).

## Atmosfera e efeitos

Cada onda tem a sua atmosfera (`AmbiencePreset`, escolhida em `WaveData.ambience`), e o `AmbienceDirector` faz a
transição entre elas. O nome aparece no HUD por alguns segundos.

| Onda | Atmosfera | O que muda |
|---|---|---|
| 1 | Hospital | luz normal, lâmpadas piscando em rajadas |
| 2 | Névoa na ala | névoa em movimento, luz mais fraca |
| 3 | Alarme de emergência | ambiente vermelho, lâmpadas vermelhas pulsando como sirene |
| 4 | Apagão | quase escuro, lâmpadas morrendo; só a lanterna do player e o flash dos tiros iluminam |
| 5 | Surto | vermelho, névoa avermelhada, lâmpadas em piscar frenético |

Como cada parte funciona:

- **Luz:** `CanvasModulate` (cor ambiente) + `PointLight2D`. As lâmpadas (`Lamp`) ficam na lista `ArenaLayout.lights`.
  O player tem uma lanterna (`Torch`) e cada tiro acende uma luz curta na boca da arma.
- **Reflexo no piso:** `Reflector` (nos prefabs do player e do zumbi) desenha uma cópia espelhada embaixo dos pés,
  com o shader `reflection.gdshader`. Onde ela aparece vem do `ReflectionMap`: R = tem piso (os `blockers` ficam de
  fora, então não vaza na parede nem no móvel), G = umidade. A umidade vem do **sangue pintado na imagem de fundo**,
  das poças de água e do **sangue novo** que cai durante a partida, e nessas áreas o reflexo é forte e ondula.
  Força e alcance: `resources/materials/reflection.tres` (`alpha_dry`, `alpha_wet`, `fade_dry`, `fade_wet`).
- **Poças e goteiras:** `ArenaLayout.puddles` (x, y, raio em pixels da imagem). Cada poça (`Puddle`) tem uma goteira
  (`Dripper`) com som (`drip.wav`, mais baixo quanto mais longe do player) e ondas na água.
- **Névoa e poeira:** `Fog` (shader em espaço de mundo) e partículas de poeira. A densidade vem do preset.
- **Itens que brilham no escuro:** tiros, flash da arma e o X de spawn usam `resources/materials/unshaded.tres`,
  que ignora a escuridão e as luzes.

## O que veio do projeto antigo (`hospital-adventure-test`)

Reaproveitado: sprites do player e dos 2 zumbis (só a pose 3/4 "baixo-direita", que mostra o rosto, em `idle`/`walk`/`attack`),
ícone da pistola, flash de tiro, moeda, gibs e decais de sangue, sons de tiro/zumbi/UI, fonte e tema de UI,
shaders de dano (`hurt_flash`, `character_motion`), a lógica de gore/knockback/ímã de moeda (reescrita sem iso), e os
efeitos de atmosfera: reflexo no piso, névoa, lâmpadas que piscam, goteira com poça, sala vermelha e sala escura
(estes dois viraram atmosferas de onda).

Deixado de fora: isometria (`Iso`), salas/portas/NPCs/diálogo/save/sanidade/chaves, animações em 8 direções,
tiles de chão e props (são losangos isométricos, não servem em top-down), arte de intro, jardim e estacionamento.
O repositório antigo continua intacto.

## Estado atual vs. meta do primeiro protótipo

| Meta | Agora |
|---|---|
| 1 arena | ok ("Enfermaria", pintura única + colisores manuais) |
| 1 personagem | ok (Paciente) |
| 3 armas | 2 (taco, que o player usa desde o início, e a pistola, que ainda não é obtível) |
| 4 inimigos | 2 (médico infectado, rastejante) |
| 10 melhorias | 10 |
| partida de ~10 min | 5 ondas, ~3 min |
| chefe final | falta |

## Próximos passos sugeridos

1. Loja entre ondas (gastar materiais em armas/itens) e mais de um slot de arma.
2. Mais 2 armas (ex.: bisturi corpo a corpo, seringa que perfura) e 2 inimigos (um à distância, um tanque).
3. Chefe na última onda; estender para ~10 ondas.
4. Arte: mais arenas (outras alas), sprite de arma própria por arma, números de dano flutuantes.
5. Tela inicial, escolha de personagem, pausa, volume.
6. Balanceamento: `RunState.XP_BASE/XP_STEP`, `WaveData`, `EnemyData`.
