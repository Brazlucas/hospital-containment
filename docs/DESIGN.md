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
5. Onda concluída: o jogador escolhe **2 habilidades** (1 de 3 cartas, duas vezes), sempre, independente do nível.
6. Loja: gasta as moedas em armas e itens (ver "Loja"), depois segue.
7. Próxima onda, mais difícil. Sobreviver à última = vitória; morrer = fim da run (ENTER reinicia).

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
| Upgrade | novo `.tres` (UpgradeData) em `resources/data/upgrades/`. A tela de upgrade varre a pasta, não precisa registrar; a raridade é sorteada na hora, então um arquivo serve para as 5 |
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
A pistola (`pistola.tres`) e as armas da folha abaixo só se obtêm na loja. (O pack `Guns/` e o pack `Melee/` foram testados e removidos: a arte não combinou.)

### Armas da folha "Pack de armas" (arte própria do HOSPITAL)

18 armas recortadas da imagem `1b92d6ad-...png` (fundo removido por cor, reduzidas pro tamanho do jogo em `assets/sprites/weapons/hospital/`, usadas em escala 0,5
como o taco). ids com prefixo `h_`. As cores originais da folha eram roxo e rosa; foram remapeadas pra paleta do jogo (aço cinza-esverdeado da arena, vermelho de sangue fosco do gore, marrom do cabelo da personagem; o clarão do lança-chamas virou laranja). As brancas (faca, marreta, machado, bastão, tesoura médica, serrote) giram pra apontar pra frente; a tesoura e o serrote
vinham com a parte que corta pro lado oposto, então o giro é diferente. As de fogo: pistola, revólver, escopeta, SMG, fuzil, fuzil de precisão.
Especiais, com os campos novos de `WeaponData`:
- `explosion_radius`: o tiro explode onde termina (primeiro inimigo ou fim do alcance) e machuca todos num raio (`Projectile._explode`, efeito em `burst.gd`). Granada, bomba tóxica (raio maior, dano menor) e mina.
- `projectile_color` / `projectile_size`: cor e tamanho do projétil (as de fogo usam o traçante amarelo padrão, a bomba tóxica verde, o lança-chamas laranja).
- `firearm = false`: sem clarão, luz nem cartucho (lança-chamas, granada, bomba, seringa, raio, mina).
- Aproximações: o **lança-chamas** é uma rajada curta de projéteis que perfuram (não é um cone contínuo); a **mina** é lançada aos pés e explode no fim do alcance curto
  (não fica no chão esperando); a **seringa** só atira agulhas que atravessam (sem cura).

Sons por categoria: `gunshot` (pistola e revólver), `smg_shot`, `ak47_shot` (fuzil), `shotgun_shot`, `sniper_shot`. As brancas e os especiais são silenciosos (a explosão usa `mob_explode`).
`WeaponData.muzzle_offset` diz de onde saem o tiro e o flash (a boca da arma, relativa à mão); nas armas da folha ele é calculado pela ponta do cano do sprite.

## Loja

Depois das 2 habilidades de cada onda (menos a última), abre a `ShopScreen`: 4 itens sorteados de `resources/data/shop/`,
pagos com as moedas coletadas (`RunState.materials`). Botão "TROCAR" sorteia de novo por um preço que sobe a cada troca.
Preço final = `price` x (1 + 0,1 por onda depois da primeira) (`RunState.PRICE_WAVE_STEP`).

- `ShopItemData` com `kind` = `WEAPON` (aponta pra um `WeaponData`; vai pra um slot novo, máx. 6, `RunState.MAX_WEAPONS`)
  ou `ITEM` (soma `modifiers` nos stats e/ou cura `heal`). Itens com `max_stacks` esgotam.
- Novo item = novo `.tres` na pasta; a loja varre a pasta. Magias e pets ainda não existem como sistema: quando existirem,
  viram um `Kind` novo (ou um campo próprio) em `ShopItemData`.
- Comprar passa por `RunState.buy()`, que cobra, aplica e emite `Events.weapon_added` / `stats_changed` / `player_healed`.

O nível/XP continua na HUD mas não dá mais escolhas (as escolhas são as 2 por onda).

## Trainer (testes)

`F1` abre o painel `scripts/debug/trainer.gd` (só existe em build de debug, ou seja, rodando pelo editor). Ele não pausa o jogo.
Tem: +moedas, curar, invencibilidade, dar/tirar qualquer arma (ignora preço e o limite de 6 só na hora de dar, não passa dele),
+/- de cada atributo, pausar a onda (congela o relógio e os spawns; os inimigos que já saíram continuam), terminar a onda (abre habilidades e loja como no fluxo normal), ir pra onda anterior/próxima,
spawnar/matar inimigos, velocidade do jogo (0.5x a 4x) e reiniciar a run.

## Médico arremessador e médico fantasma

O médico infectado ganhou duas variações (`resources/data/enemies/`): o **arremessador** (`zumbi_medico`, agora sempre joga seringas) e o **fantasma**
(`fantasma_medico`): `EnemyData.ghost` + `hover_height`. Levita (com um balanço), é translúcido e azulado (`ghost.gdshader`, que também dissolve o corpo em
direção aos pés), deixa um rastro de cópias brilhantes que somem (`Enemy._leave_trail`), atravessa paredes e móveis (`collision_mask = 0`), não sangra
(morre virando uma névoa azul), corre 100 (o rastejante, 78), dá 3,5 de dano (o médico, 2) e tem pouca vida (8). Entra nas ondas 2 a 5.

## Cartuchos, números de dano e zumbis que arremessam

- **Cartuchos** (`scripts/effects/shell.gd`): cada tiro ejeta uma cápsula (a animação "shell" do jogo original) que gira, cai no chão e some
  depois de 6 a 10 s (com um quique ao cair). Escopeta = vermelha e mais gorda, sniper = mais comprida. No máximo 120 no chão ao mesmo tempo.
- **Números de dano** (`scripts/effects/damage_number.gd`): subem do zumbi a cada acerto; crítico = maior e amarelo; máx. 80 na tela.
- **Zumbis que arremessam** (`EnemyData.throw_*`, `scripts/enemies/enemy_projectile.gd`): cada zumbi sorteia `throw_chance` ao nascer. Quem
  sorteou para a `throw_hold` px do player e joga um projétil (médico = seringa, rastejante = bile) depois de uma preparação visível (ele
  fica amarelado por `throw_windup` s). O projétil voa reto até onde o player estava, então andar de lado desvia; para em parede.

## Variação dos zumbis

Só a cor: cada zumbi sorteia ao nascer matiz (±0,9 rad), saturação e brilho (`Enemy._vary_look`, uniforms em `hurt_flash.gdshader`). Tamanho, andar
e sangue não variam. Os fantasmas não variam. Moedas: `EnemyData.drop_chance` (médico 1 moeda 80%, rastejante 50%, fantasma 2 moedas 80%).

## Controle (gamepad)

Movimento: analógico esquerdo e direcional (`move_*` no `project.godot`, `Input.get_vector` lê o analógico de verdade, então andar devagar ou rápido segue o quanto você inclina).
Menus (habilidades e loja): direcional ou analógico navega entre os cards, **A** compra/escolhe e também recomeça a run (são as ações `ui_*` padrão do Godot). A arma mira e atira sozinha.
Quando o player apanha o controle vibra (`Input.start_joy_vibration`, mais forte quanto maior o dano). O trainer (F1) continua só de teclado e mouse.

## Dor do player

Quando o player apanha (`Events.player_hurt`): a HUD treme e inclina por ~0,4 s e a barra de vida pisca (`hud.gd`), e a tela ganha artefatos
(`scripts/ui/pain_overlay.gd` + `pain.gdshader`): vinheta vermelha, franjas de cor, faixas rasgadas pro lado, granulado e linhas de varredura. A força
cresce com o dano e decai sozinha; o overlay só existe na tela enquanto dura (ele copia a tela, que não é de graça).

## Limpeza do sangue

No fim de cada onda (`Arena._on_wave_time_up`), `Gore.clear()` faz as manchas e os pedaços no chão sumirem em ~1 s, e o chão volta a refletir como antes
(`ReflectionMap.reset_wet`, que desfaz só o sangue da partida). O sangue pintado no fundo da arena e as poças d'água ficam. Os cartuchos somem sozinhos.

## Câmera

Teste atual: `Arena.full_view = true`. A câmera usa zoom `Player.OVERVIEW_ZOOM` (0,7) e mostra quase toda a arena (`Player.set_full_view`): segue o player
mas nunca passa dos limites, e num eixo em que a arena cabe inteira fica centrada (na horizontal cabe; na vertical rola um pouco). O cenário não "abre" mais. O trainer (F1, "Câmera") alterna com a câmera que segue o player em 1x. Tudo fica menor; os
números de dano e as fontes do mundo diminuem junto (a HUD e a loja não).

## Regeneração

Todo personagem começa com regeneração base de 0,4 vida/s (`Stats.INFO.hp_regen.base`); "Cicatrização" e a Bolsa de soro somam em cima.

## Arena

A sala é **uma única imagem pintada** (`assets/arenas/enfermaria_melhorada.png`, 1374x1145: a versão com o meio livre e os móveis nas bordas, com a cor corrigida (histograma casado por canal com o da original) pra manter o tom escuro e esverdeado; a imagem bruta está em `cenario-1-melhorado.png`; a original, `enfermaria.png` + `enfermaria_antiga.tres`, continua no projeto pra voltar).
O `ArenaLayout` (`resources/data/arenas/enfermaria.tres`) guarda:

- `art_scale` (0.5): pixels do jogo por pixel da imagem. Mexer nesse número redimensiona a sala inteira.
- `blockers`: retângulos de paredes e móveis, em **pixels da imagem**. Viram colisão para o player e os zumbis.
  Para ajustar, edite o array no inspetor; o spawn já evita essas áreas (`Arena.is_free`).
- `view_rect` (limites da câmera) e `player_start`.

Zumbis andam em linha reta até o player; se ficam presos num móvel, desviam de lado por instantes (`Enemy._check_blocked`).
Limitação: os móveis são parte da pintura, então o player sempre aparece por cima deles (sem y-sort contra a mobília).

## Sinergias

Cada arma e cada item da loja tem **tags** (famílias): `bala`, `branca`, `pistola`, `smg`, `fuzil`, `escopeta`, `sniper`, `explosivo`, `quimico`, `medico`, `energia`, `chama`
(`WeaponData.tags`, `ShopItemData.tags`; uma arma comprada também conta como `arma`). Uma **sinergia** (`SynergyData`, um `.tres` em `resources/data/synergies/`, sem registrar) liga um
bônus enquanto o jogador tem tags suficientes (`requires`, ex.: `{"pistola": 2}`). `RunState.refresh_synergies()` recalcula a cada arma ou item novo, dá e retira os bônus
(`modifiers`, os mesmos stats dos upgrades) e avisa as que acabaram de ligar.

| Sinergia | Precisa | Dá |
|---|---|---|
| Dupla Letal | 2 pistolas | +30% vel. de ataque |
| Açougueiro | 2 armas brancas | +20% dano, +10% crítico |
| Chuva de Chumbo | 2 escopetas | +20% dano, +60% empurrão |
| Rajada | 2 SMGs | +25% vel. de ataque, +10% dano |
| Franco-atirador | fuzil de precisão + fuzil | +1 perfuração, +25% alcance |
| Pirotécnico | 2 explosivos | +40% área de explosão, +15% dano |
| Plantão Médico | 2 médicos (armas ou itens) | +0,5 vida por abate, +0,5 regen |
| Laboratório | 2 químicos | +1 perfuração, +8% crítico |
| Versátil | 1 arma branca + 1 de fogo | +15% vel. de movimento, +10 sorte |
| Arsenal | 4 armas | +10% dano, +10% vel. de ataque |

Stats novos pra isso: `pierce` (perfuração extra de todo projétil), `explosion_pct`, `knockback_pct` (também no golpe corpo a corpo) e `heal_on_kill`.
Na tela: a **loja** mostra, sob o nome de cada item, a sinergia que ele inicia (☆ nome 1/2) ou liga (★ ativa nome), e uma faixa com as sinergias ligadas (com o que dão) e as em andamento;
a **HUD** lista as ligadas no canto inferior esquerdo e solta uma faixa "SINERGIA: NOME" quando uma liga.

## Heliporto e clima

`resources/data/arenas/heliporto.tres` (`assets/arenas/heliporto.png`, 1374x1145, sem correção de cor: a noite azulada de chuva é parte do cenário): caixa d'água, ar-condicionados,
heliponto (andável), antena e a escada de saída. 8 retângulos de parede e 19 de mobília, 13 luzes (hall, escada, 2 postes, 4 do heliponto, 4 balizas vermelhas e centro).
É a **onda 6**, a última (`wave_06.tres`, 50 s, vida x1,9, dano x1,4), com a atmosfera **Tempestade**.

O clima vem do `AmbiencePreset` (`rain` 0 a 1, `lightning`) via `Events.weather_changed` e é desenhado por `scripts/effects/weather.gd` (camada acima do mundo, abaixo da HUD):
- **Chuva** (3 camadas que entram e saem juntas em ~2 s, camada `weather.gd` acima do mundo e abaixo da HUD): riscos rápidos e densos (`rain.gdshader`: 3 profundidades, inclinados pelo vento, cabeça brilhante e rabo que some);
  **lente molhada** (`rain_lens.gdshader`: a tela inteira fica levemente embaçada e se formam gotas que escorrem e somem; cada gota é uma lentezinha que mostra a cena nítida, deslocada e invertida, com brilho);
  **respingos no chão** (`RainSplashes`: ~110 anéis achatados por segundo, espalhados em volta da câmera, no chão e sob os personagens). O som é o loop `chuva.wav` (`loop_sfx`);
  o chão todo fica molhado (`ReflectionMap.soak`, até 0,7 de umidade; o fim de onda não seca), há 4 poças com goteira no heliporto e a névoa da atmosfera é mais carregada (0,32).
- **Tempestade:** raios a cada 5 a 11 s: um risco irregular, um flash duplo e o trovão (`trovao.wav`) com atraso de 0,25 a 1,4 s (quanto mais longe, mais baixo; se for perto, a câmera treme).
Ordem das salas: enfermaria (1), jardim (2), estacionamento (3), posto de enfermagem (4), psiquiatria (5), heliporto (6).

## Texto animado

As faixas da HUD (onda, sinergia, marcos de abates) usam `banner_text.gdshader`: as letras ondulam, uma faixa de cor (`accent`) varre a palavra e o conjunto pulsa; o contorno escuro fica intacto.

## Sensação de jogo (juice)

HUD (`hud.gd`): faixa grande "ONDA N" ao começar (estoura e some) e "ONDA CONCLUÍDA" ao acabar; contador de **abates em sequência** (aparece a partir de 3, esquenta de branco a vermelho,
pulsa a cada abate, some depois de 2,5 s sem matar; marcos em 10/25/50/100 gritam CHACINA!/MASSACRE!/IMPARÁVEL!/LENDÁRIO!); o contador de moedas pulsa quando chega moeda; a barra de vida
pulsa em vermelho abaixo de 30%. Áudio: o som de coletar moeda sobe de tom a cada moeda seguida (cadeia de 0,5 s, até +60%), como uma escala (`MaterialPickup`, `AudioManager.play_sfx(..., pitch)`).

## Vida no fim da onda

Quando a onda acaba (`Arena._on_wave_time_up`), a vida do player volta ao máximo, então cada onda começa com vida cheia. A regeneração e o Kit médico da loja
passam a valer só *durante* a onda.

## Saída da onda

Quando a onda acaba e as moedas chegam ao player, ele caminha sozinho até a porta/escada da sala (`ArenaLayout.exit_point`, o chão na frente dela), entra
(`exit_into`) esvaecendo e encolhendo um pouco, e só então abrem as habilidades e a loja (`Player.walk_out`, `Arena._player_exits`). Durante isso ele não obedece
ao teclado, não colide e não toma dano. Na onda seguinte ele reaparece com fade no `player_start` (`Player.appear_at`), com 1 s de proteção. Vale também na última
onda, antes da vitória. Ele anda em linha reta até a porta, atravessando o que estiver no caminho (não há pathfinding).

## Segundo cenário: o jardim

`resources/data/arenas/jardim.tres` usa `assets/arenas/jardim_2.png` (1374x1145, `art_scale` 0,5, como a enfermaria): estufa quebrada, elevador, poste, gaiola, cama e canteiros nas bordas,
centro livre. A cor foi corrigida pro tom do jardim antigo (histograma casado por canal); a imagem bruta está em `jardim-2.png`. 11 retângulos de parede e 7 de mobília, 6 luzes
(janela, elevador, poste, nicho, escada e centro), saída pela escada de baixo. O jardim antigo (`jardim.jpg`) continua em `jardim_antigo.tres`.
Cada onda pode trocar de sala com `WaveData.arena`; a sala vale também pras ondas seguintes. A onda 2 já entra no jardim: depois da loja a tela escurece (0,5 s),
`Arena._switch_room` reconstrói tudo (fundo, paredes, reflexo, luzes, névoa e poeira; limpa sangue, cartuchos e moedas) e posiciona o player em `player_start`,
e a tela volta (0,8 s). Pra mudar a sala de outra onda, aponte `arena` no `.tres` dela.

## Terceiro cenário: o estacionamento

`resources/data/arenas/estacionamento.tres` usa `assets/arenas/estacionamento_2.png` (1475x1066, imagem bruta em `estac-2.png`, com só um empurrão leve de cor pro verde: a correção
completa clareava demais e apagava as lâmpadas quentes). `art_scale` 0,58, pra os carros terem o tamanho de antes. É uma sala mais larga que as outras: 4 carros nas laterais,
corredor e centro livres, entrada da escada embaixo. 12 retângulos de parede e 7 de mobília (os 4 carros, 2 montes de entulho e a estante), 6 luzes (fluorescente, 2 postes amarelos,
nicho, escada e centro), saída pela escada. O antigo continua em `estacionamento_antigo.tres`.
Entra na **onda 3** (`wave_03.tres`, alarme vermelho) e vale só pra ela (a onda 4 troca pro posto de enfermagem).

## Quarto cenário: o posto de enfermagem

`resources/data/arenas/enfermaria_2.tres` usa `assets/arenas/enfermaria_2.png` (1374x1145, bruta em `enferm-2.png`, com o mesmo empurrão leve de cor pro verde do estacionamento; `art_scale` 0,5).
Balcão do posto em L à direita, mesa com computador no topo, camas e cortinas nas laterais, hall de vidro e escada embaixo. 12 retângulos de parede e 23 de mobília, 8 luzes (hall, porta,
balcão, 2 postes laterais, 2 nichos, escada e centro). Entra na **onda 4** (apagão), e só nela (a onda 5 é a psiquiatria).
Ordem das salas: enfermaria (onda 1), jardim (2), estacionamento (3), posto de enfermagem (4).

## Quinto cenário: a ala de psiquiatria

`resources/data/arenas/psiquiatria.tres` usa `assets/arenas/psiquiatria.png` (1374x1145, sem correção de cor; `art_scale` 0,62). Oito celas gradeadas nas laterais e duas salas de observação em cima
são tratadas como parede: a parte jogável é um corredor central, mais fechado que nas outras salas (a escala maior compensa a área). 9 retângulos de parede e 12 de mobília (macas, cadeira de rodas,
carrinhos, pilhas de roupa), 13 luzes (hall, escada, as 8 lâmpadas das celas e as janelas das salas de observação). É a **onda 5** (surto) e **substitui o posto de enfermagem repetido**.
Ordem das salas: enfermaria (1), jardim (2), estacionamento (3), posto de enfermagem (4), psiquiatria (5), heliporto (6).

## Cartas de upgrade e raridade

Depois de cada onda, cada nível ganho vira uma escolha de 3 cartas (`UpgradeScreen` + `UpgradeCard`). Cada carta é um
upgrade **numa raridade**, e a raridade multiplica os números do upgrade, como no Brotato:

| Raridade | Bônus | Efeito visual (shader `scripts/ui/card.gdshader`) |
|---|---|---|
| Comum | x1 | aço escovado: listras finas, brilho que desliza com a inclinação, borda clara |
| Incomum | x1,5 | foil: faixa prateada que desliza, com brilhos |
| Rara | x2,2 | holográfica: arco-íris que muda com a inclinação, borda iridescente |
| Épica | x3,2 | polychrome: cores girando, reflexo que viaja, brilhos |
| Lendária | x4,5 | ouro: chamas que sobem, faíscas, borda pulsando |

Penalidades (valores negativos) crescem só pela metade, então os upgrades com desvantagem ficam mais atraentes nas raridades altas.

- **Sorteio** (`Rarity.roll`): depende da onda que acabou de terminar (`Rarity.WEIGHTS`: na 1ª, 85% comum e 15% incomum; da 4ª em
  diante já aparecem lendárias) e do atributo **Sorte** (`luck`), que aumenta a chance de tudo acima de comum.
- **A carta** é um `Button` (mouse, teclado e controle funcionam). O rosto é desenhado num `SubViewport` e o shader o inclina em
  perspectiva na direção do ponteiro, então o texto e a borda inclinam juntos. Com o teclado, a carta selecionada balança sozinha.
  Os efeitos de cor só tingem o fundo escuro e deixam o texto claro intacto, pra manter a leitura.
- **Ajustes:** multiplicadores e chances em `scripts/core/rarity.gd`; cores e intensidade de cada efeito em `card.gdshader`.
  `UpgradeData.icon` (opcional) já está pronto para quando houver arte por upgrade.

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
| 3 armas | 20 (taco inicial; pistola e 18 da folha "Pack de armas" na loja) |
| 4 inimigos | 2 (médico infectado, rastejante) |
| 10 melhorias | 10 |
| partida de ~10 min | 5 ondas, ~3 min |
| chefe final | falta |

## Próximos passos sugeridos

1. Magias e pets na loja (os sistemas ainda não existem).
2. Mais 2 armas (ex.: bisturi corpo a corpo, seringa que perfura) e 2 inimigos (um à distância, um tanque).
3. Chefe na última onda; estender para ~10 ondas.
4. Arte: mais arenas (outras alas), sprite de arma própria por arma, números de dano flutuantes.
5. Tela inicial, escolha de personagem, pausa, volume.
6. Balanceamento: `RunState.XP_BASE/XP_STEP`, `WaveData`, `EnemyData`.
