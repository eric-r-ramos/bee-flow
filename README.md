# Bee Flow

Jogo mobile de puzzle em **Godot 4.3**. Abelhas desmontam uma imagem em pixel
art, bloco a bloco. Cada colmeia só coleta blocos da cor dela, e só alcança o
que está dentro do raio de voo dela.

Dois níveis jogáveis: limpar a imagem avança para o próximo.

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
  solucionavel=SIM  guloso=SIM (facil)  nos=39  seed=7
```

`guloso=SIM` significa que o nível cai com a heurística burra "pegue a coluna
mais à esquerda" — ou seja, é fácil. Knobs úteis:

- `--bury` — fração de colmeias enterradas no fundo de outra coluna. É o que
  separa o nível 2 (`--bury 0.45`, `guloso=NÃO`) do nível 1.
- `--slack` — folga de abelhas por cor. `1.0` é cirúrgico, `1.3` perdoa.
- `--columns`, `--slots`, `--seed`.

Nenhum desses knobs é monotônico por construção — sempre confira o `guloso=` na
saída em vez de presumir que aumentar o número aumentou a dificuldade.

Para PNG (`pip install Pillow`), cada pixel vira o bloco da cor mais próxima da
paleta em `tools/beeflow/palette.py`; pixel transparente vira vazio.

## Estrutura

```
scripts/
  Main.gd            loop principal, layout, entrada, vitória/derrota
  Autoplay.gd        jogador automático (teste headless)
  model/Board.gd     grid + cálculo de fronteira
  model/Hive.gd      colmeia: cor, raio, abelhas, mobilidade
  view/BoardView.gd  desenha os blocos
  view/TableView.gd  zona de voo, raios, slots, pilhas
  view/Bee.gd        abelha: voa, coleta, entrega
  view/Hud.gd        status, velocidade, cartaz de fim
tools/
  make_level.py      CLI: imagem -> nível verificado
  beeflow/board.py   modelo de tabuleiro (espelha model/Board.gd)
  beeflow/generator.py  deriva a pilha de colmeias jogando o nível
  beeflow/solver.py     verifica solucionabilidade e mede dificuldade
levels/
  level_001.json     Primeiro Broto — 20x20, 5 cores, fácil
  level_002.json     Voo do Entardecer — 24x24, 6 cores, exige planejamento
  test_deadlock.json nível impossível de propósito, para o teste de derrota
```

## Estado

Protótipo jogável. Já funciona: fronteira, 5 slots, pilhas com topo elegível,
raio de voo, reposicionamento livre, coleta, vitória e derrota, x2 velocidade,
progressão entre níveis.

Ainda não: mobilidade limitada de colmeia, nuvem, pedra, economia, progressão
entre níveis.
