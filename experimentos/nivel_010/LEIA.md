# Nível 10 — tentativa com 100% das colmeias presas (moves = 0)

Não foi publicado. Está aqui para quem retomar não repetir o caminho.

## O que se tentou

Nível com **todas** as colmeias sem remanejamento. Arte "O Apiário"
(`tools/samples/apiary.txt`), duas pilhas de caixas, cada cor num bloco único e
contínuo — cor picada em pedaços distantes é armadilha quando a colmeia não pode
se mexer.

Gerar candidatos:

    python3 tools/make_level.py --input tools/samples/apiary.txt \
        --out /tmp/n10.json --id level_010 --name "O Apiario" \
        --limited-frac 1.0 --limited-moves 0 --seed 5 --attempts 8 --no-difficulty

Sai aprovado pelos dois verificadores. E o bot perde em segundos.

## O que se descobriu

**O nível não é injusto.** Medido: na abertura, todas as cinco cartas do topo
têm ponto de pouso legal cobrindo todas as abelhas delas. A estrutura está sã.

**O bot é que não sabe jogar isso.** Ele empilha colmeias no mesmo ponto, elas
dividem os mesmos blocos, a primeira come tudo e as outras encalham — o que
desde a regra do encalhe é derrota imediata.

## `Autoplay_tentativa.gd`

Bot com quatro mudanças, nesta ordem de importância:

1. **Descontar o que já foi reivindicado.** Ao pontuar um ponto de pouso,
   ignora os blocos que as colmeias em campo já vão consumir (os `bees_left`
   mais próximos de cada uma). Sem isso ele empilha.
2. **Recusar pouso que não cabe todas as abelhas** (só para `moves == 0`).
3. **`_score_at`**: varre a caixa do raio em vez de todas as células da cor.
   Sem isso o bot fica lento demais para rodar — céu tem centenas de células e
   são ~2000 candidatos por decisão.
4. Anéis de candidatos mais densos: no começo o tabuleiro está 100% cheio e a
   única faixa que aceita colmeia é o anel de folga em volta da imagem.

Resultado: de perder em 2 segundos para 785 de 1024 blocos. **Não vencer.**

**E regride os níveis 1-9** (campanha trava no 5 com 9 blocos restantes). A
causa não foi totalmente isolada; a última hipótese testada — separar colmeia
fixa (`moves == 0`) de colmeia com 1-3 remanejamentos — não resolveu.

Não use este arquivo como está. Use como registro do que já foi tentado.

## O problema de fundo

Movimento zero em 100% exige um **jogador de referência competente**, e é
exatamente isso que falta — no bot do Godot e no gerador. Ver `CONTINUAR.md`.

## Alternativa mais barata

100% das colmeias com **1 remanejamento** em vez de zero. O bot já lida com
mobilidade limitada (é o que os níveis 7-9 fazem) e o único movimento é o que
tira a roleta da ordem das pilhas.
