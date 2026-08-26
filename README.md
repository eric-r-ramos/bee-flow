# Bee Flow

Jogo mobile de puzzle em **Godot 4.3**. Abelhas desmontam uma imagem em pixel
art, bloco a bloco. Cada colmeia só coleta blocos da cor dela, e só alcança o
que está dentro do raio de voo dela.

Sete níveis numa rota de favos: o seguinte abre quando você vence o atual, e
nível vencido pode ser rejogado sem perder o desbloqueio.

O design completo está em [DESIGN.md](DESIGN.md).

## Rodar

```bash
godot --path .                     # abre o jogo
godot --path . -- --level res://levels/level_001.json
```

## Testes

O jogo tem um jogador automático que roda headless e serve de teste de fumaça do
loop inteiro — colocar colmeia, coletar, liberar slot, vencer:

```bash
GODOT=/caminho/para/godot tools/smoke.sh
```

Ele verifica três caminhos:

- os dois geradores precisam produzir níveis solucionáveis;
- a **campanha inteira** precisa terminar em vitória — o bot joga o nível 1,
  atravessa a transição e limpa o nível 2, então a passagem de nível está
  coberta por teste, não só pelo olho;
- `test_deadlock` — deck cortado de propósito — precisa terminar em **derrota**
  (saída 1). Se esse passar, a detecção de "sem movimentos" quebrou.

O bot também guarda uma invariante: **todo bloco coletado vira exatamente um
mel**. Ela já foi violada uma vez — a vitória era declarada na última *coleta*,
e as abelhas que ainda voltavam com bloco nunca entregavam, então 400 blocos
viravam 398 de mel. Note que a conta não é com abelhas *despachadas*: quem volta
de mão vazia é despachada de novo depois, e aí os números legitimamente diferem.

## Criar um nível

A imagem é arte livre: arte ASCII (`.txt`) ou PNG. A pilha de colmeias é
derivada e verificada pelo gerador, então **é impossível publicar um nível
insolúvel**.

```bash
python3 tools/make_level.py \
    --input tools/samples/flower.txt \
    --out levels/level_002.json \
    --id level_002 --name "Segundo Broto"
```

Saída:

```
OK  levels/level_002.json
  20x20, 400 blocos
  b ceu       blocos=270  abelhas=270  folga=1.00
  ...
  colmeias=39 em 5 colunas
  solucionavel=SIM  nos=39  seed=7
  score 3.7/100  ->  TUTORIAL
    letalidade      0.0% em media, 0% na pior decisao
                    (0 de 112 jogadas legais matam)
    risco comeca    a 100% do nivel
    pressao slots   14.9%
    ramificacao     3.05 escolhas por vez, 32 decisoes reais em 39 jogadas
    guloso resolve  SIM
```

O **score** vem de `difficulty.analyze()`, que percorre a solução e testa todas
as jogadas legais em cada decisão para descobrir quantas matam o nível. Custa
alguns segundos por nível; `--no-difficulty` pula. Os pesos são hipótese até
haver telemetria de jogadores reais — servem para ordenar níveis entre si.

Knobs úteis:

- `--bury` — fração de colmeias enterradas no fundo de outra coluna. É o que
  separa o nível 2 (`--bury 0.45`, `guloso=NÃO`) do nível 1.
- `--limited-frac` / `--limited-moves` — fração de colmeias com remanejamento
  limitado e quantos movimentos elas ganham. O nível 4 usa `0.05` e `3`; o 8 e o
  9 usam `0.30` e `1`, que é onde a mecânica passa a morder de verdade.
- `--territorial-frac` — fração de colmeias territoriais: ninguém pousa dentro
  do círculo delas. O nível 9 usa `0.20`. Ver `DESIGN.md`, "Território" — a
  primeira versão da regra tornava o fim de nível impossível.
- `--slack` — folga de abelhas por cor. `1.0` é cirúrgico, `1.3` perdoa. Com
  colmeias limitadas, `1.0` transforma qualquer colmeia encalhada em derrota
  certa — os níveis 7 e 9 usam `1.10`/`1.15` por isso (ver `DESIGN.md`).
- `--columns`, `--slots`, `--seed`.

Nenhum desses knobs é monotônico por construção — sempre confira o `guloso=` na
saída em vez de presumir que aumentar o número aumentou a dificuldade.

Para PNG (`pip install Pillow`), cada pixel vira o bloco da cor mais próxima da
paleta em `tools/beeflow/palette.py`; pixel transparente vira vazio.

## Estrutura

```
scripts/
  Main.gd            loop principal, layout, entrada, vitória/derrota, rota
  Autoplay.gd        jogador automático (teste headless)
  model/Board.gd     grid + cálculo de fronteira
  model/Hive.gd      colmeia: cor, raio, abelhas, mobilidade
  model/Progress.gd  níveis vencidos e recordes de tempo (user://progress.json)
  view/MapView.gd    a rota: favos, trilha, cadeados
  view/BoardView.gd  desenha os blocos
  view/TableView.gd  zona de voo, raios, slots, pilhas
  view/Bee.gd        abelha: voa, coleta, entrega
  view/Hud.gd        status, velocidade, cartaz de fim
tools/
  make_level.py      CLI: imagem -> nível verificado
  beeflow/board.py   modelo de tabuleiro (espelha model/Board.gd)
  beeflow/generator.py  deriva a pilha de colmeias jogando o nível
  beeflow/solver.py     verifica se o nível tem solução
  beeflow/difficulty.py mede quanto o nível cobra do jogador
levels/
  level_001.json     Primeiro Broto — 20x20, 5 cores, fácil
  level_002.json     Voo do Entardecer — 24x24, 6 cores, exige planejamento
  level_003.json     A Colmeia no Galho — 28x28, 7 cores, 29% das jogadas matam
  level_004.json     O Pote de Mel — 26x26, apresenta mobilidade limitada (5%)
  level_005.json     O Girassol — 28x28, 9 cores, 10% de colmeias limitadas
  level_006.json     A Rainha — 28x28, 20% de colmeias limitadas (3 movimentos)
  level_007.json     O Pomar — 28x28, 20% limitadas (2 mov), folga 1.10
  level_008.json     O Enxame — 28x28, 30% de colmeias limitadas (1 movimento)
  level_009.json     O Favo — 32x32, 30% limitadas (1 mov) + 20% territoriais
                     + folga 1.15 — a folga é o que absorve colmeia encalhada
  test_deadlock.json nível impossível de propósito, para o teste de derrota
```

## Estado

Protótipo jogável. Já funciona: fronteira, 5 slots, pilhas com topo elegível,
raio de voo, pouso restrito ao lado de fora da imagem com arrasto grudado,
reposicionamento livre, coleta, vitória e derrota, x2 velocidade, rota de níveis
com desbloqueio e progresso em disco.

Ainda não: mobilidade limitada de colmeia, nuvem, pedra, economia, progressão
entre níveis.
