# Continuar o Bee Flow noutra máquina

Escrito no fim de uma sessão do Claude Code na web. A conversa não migra — ela
vive na nuvem. O trabalho migra inteiro, e isto aqui é o que faltava para uma
sessão nova (ou uma pessoa) retomar sem arqueologia.

## Onde o projeto está

Nove níveis jogáveis e verificados. Protótipo em Godot 4.3 e um porte web
autocontido (`web/bee-flow-play.html`) que é o que roda no celular.

Últimas três coisas que aconteceram, em ordem:

1. **Bug do encalhe, corrigido e publicado.** Colmeia presa sem alcance agora é
   derrota anunciada na hora, não vinte jogadas depois. O nível tem uma abelha
   por bloco, cor a cor — folga zero —, então toda abelha que nunca mais voa é
   um bloco que ninguém coleta.
2. **Verificador espacial no gerador.** O solver combinatório é cego a
   geometria; com colmeia presa isso aprova nível invencível. Ver a seção abaixo
   sobre o que ele prova e o que não prova.
3. **Nível 10 com 100% das colmeias presas: não passou.** Ver
   `experimentos/nivel_010/LEIA.md`.

## Montar a máquina local

    git clone https://github.com/eric-r-ramos/bee-flow
    cd bee-flow

**Godot 4.3** (headless serve; não precisa do editor):
baixe de https://godotengine.org/download — o binário `linux.x86_64` ou o
equivalente do seu sistema. O projeto não usa addons, mas em clone novo rode
UMA vez a importação antes de qualquer gate:

    godot --headless --path . --import

Sem isso não existe o cache de classes globais, `Main.gd` falha no parse
(`BFBee não declarado` etc.), o engine sobe sem cena nenhuma e — como
`--fixed-fps` desliga a sincronização com o relógio — fica num loop vazio a
100% de CPU que nunca termina. Parece o gate rodando; não é.

**Python 3** para o gerador. Sem dependências, exceto Pillow, e só se você for
gerar nível a partir de `.png` (arte em `.txt` não precisa).

**Playwright** só para os testes do porte web:

    pip install playwright && playwright install chromium

## Os três gates

Nenhum nível é publicado sem passar nos três.

**1. Gerador** — prova que o nível tem solução:

    python3 tools/make_level.py --input tools/samples/flower.txt \
        --out levels/level_001.json --id level_001 --name "Primeiro Broto"

**2. Campanha no Godot** — o bot joga os nove níveis do começo ao fim:

    godot --headless --path . --fixed-fps 120 -- --autoplay

Espera-se `VITORIA mel=1024 abelhas=1024 blocos_restantes=0`. Um nível isolado:
acrescente `--level res://levels/level_009.json`.

**3. Campanha no navegador** — mesma coisa no porte web, que é o que o jogador
usa:

    python3 -m http.server 8731 &
    python3 tools/test_web_campanha.py

Testes menores: `tools/test_encalhe.py` (a regra do encalhe, com os dois lados
negativos) e `tools/test_solver_espacial.py` (o que o verificador prova).

## O verificador espacial: leia antes de confiar nele

`solve_spatial` respeita ancoradouro e raio, e o gerador o exige junto com o
combinatório sempre que existe colmeia com `moves == 0`.

**Ele é vácuo como porteiro.** Nunca reprova — nem com 90% das cartas
enterradas, nem com um slot só. Não é bug: a estratégia de referência é serial
(planta uma colmeia, espera esvaziar, planta a próxima) e estratégia serial cabe
em um slot.

Ou seja: prova que **existe** uma linha vencedora, o que a garantia do gerador
já dava. Não prova que um jogador **sem acesso à atribuição secreta de blocos**
consegue achar uma. `tools/test_solver_espacial.py` registra as duas coisas e
falha de propósito se alguém mexer numa sem mexer na documentação.

## O problema aberto

**Falta um jogador de referência competente.**

O porteiro de verdade é o bot (`scripts/Autoplay.gd`), e ele foi afinado para um
jogo onde a colmeia se reposiciona. Com 100% das colmeias presas ele perde em
segundos, e a tentativa de consertá-lo regrediu os níveis 1-9.

O que resolveria de fundo é um verificador que **busque entre os pousos que o
jogador poderia escolher** — não a atribuição que o gerador anotou. Isso é, em
essência, um bot bom com backtracking, e serviria aos dois lados: seria o gate
do gerador e a base do bot do Godot.

Enquanto isso não existir, movimento zero em 100% fica fora de alcance. A saída
barata para um nível difícil é 100% das colmeias com **1 remanejamento**.

## Coisas que custaram caro para descobrir

Estão no `DESIGN.md`, mas estas três decidem nível:

- **Céu entre 59% e 71%.** Céu é espaço de manobra. Abaixo disso o fim de nível
  vira migalha de quatro cores espalhadas e se perde por um bloco.
- **Cor tem de estar junta.** Colmeia presa planta num pedaço e nunca alcança o
  resto. `python3 tools/medir_arte.py saida.txt` mede fragmentação e céu.
- **Folga zero.** Abelhas == blocos, cor a cor. Já se tentou folga de 15%: cria
  carta morta que entope slot.

## O que ficou fora do git de propósito

Capturas de tela, GIFs, logs de execução e níveis candidatos descartados —
todos regeneráveis. O binário do Godot também: baixe do site oficial.

## Onde está o jogo publicado

https://claude.ai/code/artifact/b2878a1a-5c1d-4080-9eb9-2bf67877cf92

Artifact privado, atualizado republicando `web/bee-flow-play.html` no mesmo URL.
