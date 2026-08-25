# Bee Flow — documento de design

Jogo mobile de puzzle. Uma imagem em pixel art é desmontada bloco a bloco por
abelhas. Inspirado no *Ant Flow*, mas com uma diferença mecânica que muda o
jogo: abelha voa, e voo tem alcance.

## Loop

1. O nível é uma imagem. Cada pixel é um bloco colorido.
2. O jogador arrasta a colmeia do topo de uma pilha até um ponto livre da zona
   de voo, ao redor (ou dentro) da imagem.
3. A colmeia ocupa um dos **5 slots** e manda abelhas buscarem blocos **da cor
   dela** que estejam **dentro do raio**.
4. Cada abelha carrega 1 bloco e volta. A colmeia sai de campo quando esvazia,
   liberando o slot.
5. Acabou a imagem: vitória. Ficou sem movimento possível: derrota.

## As quatro regras que criam a dificuldade

**1. Só blocos de fronteira são coletáveis.** Um bloco só existe pro jogo se
estiver ligado ao lado de fora por um caminho de células vazias. Bloco amarelo
ilhado no meio dos rosas só aparece depois que os rosas saem — é isso que
obriga o jogador a planejar a ordem das cores.

**2. Só o topo de cada pilha é elegível.** As colmeias ficam em pilhas; o
jogador escolhe de qual pilha puxar, mas não qual colmeia. Puxar a errada
queima um slot.

**3. Cinco slots.** Slot ocupado por colmeia sem alvo é slot morto. Ficar com
os cinco travados e nenhum bloco coletável é a derrota.

**4. Raio de voo.** A colmeia só alcança o que está dentro do círculo dela. Não
trava a solução — trava a **cobertura**. A pergunta que o raio faz não é
"consigo pegar esse bloco?", é "plantando aqui, gasto as 39 abelhas ou
desperdiço metade porque o resto do amarelo está do outro lado?"

### Por que o raio não trava o jogador

Regras 1 e 4 restringem a mesma coisa: a fronteira. Como os blocos saem sempre
de fora pra dentro, a silhueta encolhe e o miolo vira fronteira sozinho. O raio
nunca precisa alcançar o centro no início — só o perímetro atual, que está
sempre virado pra fora.

Na v0 o **reposicionamento é livre**: um raio mal aproveitado custa tempo, nunca
o nível. A solucionabilidade continua sendo um problema puro de cor + ordem.

## Como a dificuldade vai crescer

Cada item entra sozinho, medindo o impacto antes do próximo:

| # | Dificultador | Efeito |
|---|---|---|
| 1 | **Mobilidade da colmeia** (`moves`) | `-1` livre → `N` remanejamentos → `0` fixa onde plantou. É o eixo principal: a partir daí o raio passa a valer de verdade e o solver precisa considerar posição. |
| 2 | **Folga de abelhas** | Total de abelhas ÷ total de blocos daquela cor. `1.0` é cirúrgico, `1.3` perdoa desperdício. Knob mais forte de todos. |
| 3 | **Profundidade do enterro** (`--bury`) | Fração de colmeias empurradas para o fundo de outra coluna, em vez da coluna da vez. |
| 4 | **Colmeias ocultas (`?`)** | O jogador aposta sem saber o que vem. |
| 5 | **Nuvem** | Esconde uma região; some depois de X abelhas despachadas (contador global). |
| 6 | **Pedra** | Trava o topo de uma pilha; 1º martelo trinca, 2º estilhaça. |

Nuvem e pedra ficam pra depois — 1 a 4 já dão muita corda.

## Tipos de colmeia

O raio é o eixo de variedade que o Ant Flow não tem:

| Tipo | Raio | Perfil |
|---|---|---|
| operária | 3.5 células | curto alcance, boa pra bolsão denso |
| zangão | 5.5 células | meio termo |
| batedora | 8.0 células | cobre muito, ideal pra cor espalhada |

## Geração de nível

**O artista nunca pensa em solucionabilidade.** A imagem é arte livre; a pilha
de colmeias é derivada por algoritmo e verificada antes de publicar.

1. **Derivar** — o gerador *joga o nível sozinho*: olha a fronteira, escolhe uma
   cor exposta, planta uma colmeia num ponto plausível, descasca o que ela
   alcança, e anota. A sequência resultante é solucionável **por construção**.
2. **Distribuir** — a sequência é dealada em colunas. É a única etapa que pode
   criar deadlock, porque a colmeia certa pode ficar enterrada.
3. **Verificar** — um solver (DFS com memo sobre `tabuleiro + slots + topos`)
   confirma que o deal continua solucionável. Falhou, re-deala.
4. **Medir** — `difficulty.analyze()` percorre a solução e, em **cada decisão**,
   testa todas as jogadas legais, não só a que o solver escolheu. Cada
   alternativa vira uma nova busca. A pergunta central: *quantas das escolhas
   legais matam o nível?*

### O enterro só vale medido

A primeira versão do `--bury` mandava a colmeia para a **coluna mais alta**. O
efeito foi o oposto do pretendido: concentrar a sequência numa pilha só preserva
a ordem original dentro dela, e o nível ficava *mais* fácil — `guloso=SIM` em
todas as intensidades. Mandar para uma coluna qualquer que não seja a da vez
inverteu isso, e aí o knob passou a responder.

A lição vale para todos os dificultadores: nenhum deles é confiável por
raciocínio. O solver mede, e o número manda.

Aproximação consciente do solver: com colmeias de reposicionamento livre o
jogador sempre leva a colmeia até qualquer bloco da cor dela, então o raio não
restringe a solução e a dimensão espacial é ignorada. **Quando entrarem colmeias
de mobilidade limitada, o solver precisa passar a considerar posição e alcance.**

### Regras pro artista

Nada disso afeta correção — só diversão:

- 4 a 8 cores por imagem.
- Massas contíguas de pelo menos ~6 blocos por cor; pixel isolado gera colmeia
  de 3 abelhas, que é chata.
- Uma ou duas cores parcialmente enterradas (o "amarelo cercado de rosa"), que é
  onde mora a tensão.

## Válvulas de escape (e monetização)

São a mesma coisa, o que é conveniente:

- **6º slot** por anúncio — a saída clássica de deadlock.
- **Desfazer** a última colocação.
- **Embaralhar** as pilhas.
- **x2 velocidade**.

Com o 6º slot existindo, deadlock deixa de ser game over e vira decisão
econômica — o que permite ser mais agressivo na geração.

## Medida de dificuldade

| componente | peso | o que captura |
|---|---|---|
| letalidade média | 0.40 | quão arriscada é a decisão típica |
| letalidade de pico | 0.15 | quão arriscada é a **pior** decisão |
| não cai no guloso | 0.20 | exige planejamento |
| pressão de slots | 0.25 | o jogador joga sufocado |

Medido nos níveis reais:

| | Primeiro Broto | Voo do Entardecer |
|---|---|---|
| **score** | **3,7 — tutorial** | **49,3 — médio** |
| letalidade média | 0% | 23% |
| letalidade de pico | 0% | 75% |
| risco começa a | — | 10% do nível |
| pressão de slots | 14,9% | 35,4% |

O nível 1 tem **zero** jogadas fatais em 112 testadas: é literalmente impossível
perder. Como tutorial, é o comportamento certo — mas foi o medidor que provou
isso, não a intuição.

**Os pesos são hipótese, não verdade.** Só telemetria de jogadores reais pode
calibrá-los. Até lá o score serve para ordenar níveis entre si, nunca para
prometer quanto tempo alguém vai levar.

### O termo que não entrou, e por quê

A primeira versão pesava o *atraso da armadilha*: quantas jogadas o jogador faz
antes de descobrir que já perdeu. Errar e travar na jogada seguinte ensina;
travar oito jogadas depois é punição.

Medindo, todos os 44 estados fatais do nível 2 tinham a mesma forma: **o jogador
enche o quinto e último slot e trava na hora, com zero jogadas seguintes.** Não
existe morte lenta neste jogo. O termo seria sempre zero e só comeria escala,
então saiu do score.

Continua sendo medido, como **canário**: se um dia der diferente de zero, a
forma de perder mudou — 6º slot por anúncio, colmeias de mobilidade limitada —
e os pesos precisam ser repensados.

## Progressão

A campanha é uma lista ordenada de níveis (`LEVELS` em `Main.gd`). Limpar a
imagem avança para o próximo; o cartão de transição mostra o que vem a seguir —
nome, tamanho e número de cores — antes do jogador entrar.

| | Primeiro Broto | Voo do Entardecer |
|---|---|---|
| Grid | 20×20, 400 blocos | 24×24, 576 blocos |
| Cores | 5 | 6 |
| Colmeias | 39 | 56 |
| Enterro | nenhum | 0.45 |
| Cai na heurística gulosa? | sim | **não** |

## Em aberto

- Economia: mel offline (idle)? merge de colmeias? upgrade direto?
- Progressão de longo prazo e como as colmeias evoluem entre níveis.
- Pipeline de arte em volume: importar PNG já funciona, falta o banco de imagens.
