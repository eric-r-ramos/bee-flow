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

**4. Raio de voo, e a colmeia fica de fora.** A colmeia só alcança o que está
dentro do círculo dela, e só pode ser plantada **fora da silhueta da imagem** —
nunca dentro. Não basta a célula estar vazia: ela precisa estar ligada ao lado
de fora, então um bolsão de vazio cercado de blocos continua sendo "dentro".
É a mesma máscara que define a fronteira, reaproveitada.

Na prática o arrasto **gruda na borda**: levar o dedo para dentro da imagem faz
a colmeia deslizar até o ponto válido mais próximo, em vez de seguir o dedo e
receber um "não" no fim. Soltar sempre funciona. O raio não trava a solução —
trava a **cobertura**. A pergunta que o raio faz não é
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

| # | Dificultador | Efeito | Estado |
|---|---|---|---|
| 1 | **Mobilidade da colmeia** (`moves`) | `-1` livre → `N` remanejamentos → `0` fixa onde plantou. | **em uso** (níveis 4–9) |
| 1b | **Território** (`territorial`) | Ninguém pousa dentro do círculo dela. | **em uso** (nível 9) |
| 2 | **Folga de abelhas** (`--slack`) | Total de abelhas ÷ blocos daquela cor. | **em uso** (nível 9) |
| 3 | **Profundidade do enterro** (`--bury`) | Fração empurrada para o fundo de outra coluna. | em uso |
| 4 | **Colmeias ocultas (`?`)** | O jogador aposta sem saber o que vem. | pendente |
| 5 | **Nuvem** | Esconde uma região até X abelhas serem despachadas. | pendente |
| 6 | **Pedra** | Trava o topo de uma pilha; dois martelos. | pendente |

Nuvem e pedra ficam pra depois — 1 a 4 já dão muita corda.

## Dois sistemas de coordenadas

Os blocos vivem numa **grade de inteiros**. As colmeias e as abelhas vivem em
**pixels contínuos**. Não é inconsistência: a colmeia precisa poder pousar no
anel de folga *fora* da grade, onde não existe célula nenhuma — `cell_at()`
devolve `-1` ali —, e o raio é um círculo medido em pixels, que arredondar para
células destruiria.

A ponte entre os dois é um par de funções: `cell_center(i)` leva grade →
pixels, `cell_at(p)` leva pixels → grade.

### O preço, que só apareceu quando foi medido

Guardar a colmeia em pixels do canvas amarra a posição ao **tamanho da tela**.
No Godot isso não morde: a resolução de projeto é fixa (1080×1920) e a engine
escala o quadro inteiro. Na versão web o canvas acompanha a janela de verdade,
então girar o aparelho recalcula `cell`, `ox` e `oy` — e a colmeia ficava parada
no mesmo pixel enquanto a imagem escorregava debaixo dela.

Medido: **3,26 células de deriva** ao girar o aparelho, com o raio mudando de
significado junto, já que ele é `radius * cell`.

A correção é reancorar no relayout, convertendo pixel → célula → pixel. A
posição *em células* é a que tem significado; a posição em pixels é uma
projeção dela para a tela atual.

**Lição:** quando dois sistemas de coordenadas convivem, decida qual é a
verdade. O outro é uma vista, e toda vista precisa ser recalculada quando a
projeção muda.


## O recorde tem de poder variar

A rota mostrava "recorde 676 de mel". Mas pela invariante **todo bloco vira
exatamente um mel**, esse número é sempre igual à contagem de blocos do nível —
idêntico para todo jogador, em toda partida. Era a contagem de blocos com outro
nome: informação morta vestida de conquista.

Medido em duas partidas do nível 1, uma bem jogada e outra remanejando colmeias
à toa:

| | jogando bem | remanejando à toa |
|---|---|---|
| mel | 400 | 400 |
| viagens perdidas | 0 | 5 |
| **tempo de jogo** | **40,7 s** | **185,9 s** |

O recorde passou a ser o **tempo**, e o registro guarda também as **viagens
perdidas** (abelha que sai e volta vazia porque o alvo saiu do alcance). Os dois
medem a mesma coisa por ângulos diferentes: colmeia bem plantada coleta sem
ficar ociosa e sem mandar abelha à toa.

O tempo é acumulado em **tempo de jogo**, não de relógio: o botão ×2 acelera a
exibição, não a simulação, então acelerar não falsifica recorde.

**Regra geral:** antes de exibir um número como recorde, pergunte se duas
partidas boas podem produzir valores diferentes. Se não podem, não é recorde.


## Mobilidade limitada

O reposicionamento livre da v0 tornava o raio quase decorativo: errar o pouso
custava tempo, nunca o nível. A partir do nível 4, uma fração das colmeias
nasce com um orçamento de remanejamentos (`moves: 3`); as demais seguem livres
(`moves: -1`). A fração cresce a cada nível — começa em **5%**.

### Por que a garantia de solucionabilidade sobrevive

O gerador esvazia **cada colmeia a partir de um único ancoradouro** — a solução
de referência nunca reposiciona coisa nenhuma, e sobreviveria até a `moves: 0`.
Limitar a mobilidade não pode tornar o nível insolúvel.

Isso obrigou a fechar um buraco que não importava antes: o ancoradouro da
solução de referência agora é **validado como pouso legal** (fora da silhueta).
Com movimento livre, um ancoradouro em cima da imagem era irrelevante — o
jogador achava outro lugar. Com movimento escasso, seria uma solução que o
jogador não consegue executar.

O que muda é do lado do jogador: agora ele **pode** tornar o nível insolúvel
plantando mal uma colmeia limitada. Essa é a dificuldade pretendida.

### As três regras que impedem que isso vire armadilha

1. **O jogador sabe antes de puxar.** O token na pilha traz um selo escuro
   `mov N`. Punir por informação escondida seria trapaça.
2. **Toque não custa movimento.** Só arrastos acima de 0,6 célula consomem o
   orçamento; abaixo disso nada acontece — nem move, nem gasta. E como arrastar
   para dentro da imagem gruda de volta na borda, tentar o proibido é grátis.
3. **A colmeia presa diz que está presa.** Ela mostra `presa` em vermelho, e
   tentar arrastá-la explica por quê.

### O que o score NÃO mede

O solver ignora posição de propósito, então o número de dificuldade mede apenas
o quebra-cabeça de cor e ordem. **Com colmeias limitadas, a dificuldade real é
maior que o score.** O gerador imprime esse aviso junto do número; tratar o
score como completo aqui seria mentir.

### O que a instrumentação mostrou: nem a fração nem o número são o botão

Quatro níveis, quatro configurações, e o mesmo resultado:

| nível | limitadas | colocadas | **esgotaram** | remanejamentos gastos |
|---|---|---|---|---|
| 4 | 5% × 3 mov | 4 | **0** | — |
| 5 | 10% × 3 mov | 9 | **0** | 2 (média **0,22**/colmeia) |
| 6 | 20% × 3 mov | 15 | **0** | 4 (média **0,27**/colmeia) |
| 7 | 20% × **2 mov** | 17 | **0** | 3 (média **0,18**/colmeia) |

A última coluna é a resposta que faltava. **A colmeia limitada usa cerca de
0,2 remanejamento em média** — a esmagadora maioria é plantada uma vez e nunca
mais tocada. Um orçamento de 2 ou 3 está uma ordem de grandeza acima do uso
real, e por isso quadruplicar a fração e depois cortar o orçamento não mudaram
nada.

**A mecânica só passa a existir em `moves: 0`** — colmeia que fica onde foi
plantada. O eixo interessante nunca foi "quantos movimentos", e sim *que fração
das colmeias é fixa*.

Ressalva honesta: 0,2 é o uso do **bot**, que economiza de propósito. Um jogador
humano experimentando move mais. Mas mesmo dez vezes esse número raramente
esgotaria um orçamento de 2.

Sem essa contagem, quatro níveis seguidos teriam passado no teste dando a
impressão de escalada. **Um teste verde não distingue "a mecânica funciona" de
"a mecânica nunca foi acionada".**


## Território

A colmeia territorial não divide espaço. **Nenhuma outra colmeia pousa dentro
do círculo dela, e ela não pousa com outra colmeia dentro do círculo dela.**
É o segundo eixo que faz o raio pesar: mobilidade limitada cobra *onde* plantar,
território cobra *quantas* podem trabalhar ao mesmo tempo.

O selo é uma faixa rosa no token e um anel duplo tracejado em campo; ao arrastar
qualquer colmeia, os territórios em vigor aparecem tracejados.

### A primeira versão travava o fim de nível

A regra escrita ao pé da letra — "as áreas não podem se cruzar" — vetava o
pouso quando a distância entre os centros era menor que **a soma dos dois
raios**. Parece a leitura óbvia, e é injogável. Medido na zona de voo de um
celular (370×480 px, célula de 12 px):

| territorial | candidata | zona de voo proibida — soma dos raios | — raio da territorial |
|---|---|---|---|
| operária 3,5 | operária 3,5 | 12,5% | 3,1% |
| zangão 5,5 | batedora 8,0 | **46,4%** | 16,3% |
| batedora 8,0 | batedora 8,0 | **65,1%** | 16,3% |

Uma única batedora territorial apagava **dois terços** dos pousos possíveis de
outra batedora. Com 5 slots, duas delas em campo fechavam o tabuleiro.

O bot perdeu o nível 9 com **4 blocos de 784 restando**, num impasse que nenhuma
ordem de jogo resolve: quatro colmeias com abelhas de sobra, cada uma com
exatamente o número de abelhas que faltava, e **nenhuma com alvo no alcance** —
duas já tinham gastado seu único remanejamento, e as duas livres não tinham para
onde ir porque o território alheio cobria o resto do tabuleiro. A territorial
também não podia sair: todo mundo estava dentro do círculo dela.

Trocando o veto pela versão limitada — **o raio da territorial, não a soma** — o
mesmo nível, mesma seed, mesmo bot:

| regra | resultado |
|---|---|
| soma dos raios (`círculos não se tocam`) | **derrota**, 3 blocos restando |
| raio da territorial (`ninguém dentro do meu círculo`) | **vitória**, 784 de mel |
| só entre territoriais | vitória, 784 de mel |

Ficou a do meio. A terceira também passa, mas quase nunca é acionada — duas
territoriais precisariam estar em campo ao mesmo tempo, e a 20% isso é raro
demais para a mecânica existir.

### O que isso ensinou sobre o gate de aceite

Nível 9 é **solucionável por construção** — o gerador o resolve jogando pra
frente, e a solução de referência é serial e de âncora única: nunca tem duas
colmeias em campo, então o território nunca é acionado nela. A garantia
sobreviveu intacta à regra que travava o jogo.

**Solucionável não é o mesmo que vencível.** Só o bot jogando o nível de
verdade, com cinco slots ocupados ao mesmo tempo, encontra esse impasse. Já
tinha aparecido no nível 8 — 4 de 5 seeds candidatas eram invencíveis pelo bot
— e ali a saída foi trocar a seed. Aqui a seed não era o problema: a regra era.

### E não era só a regra: a cadeia inteira do nível 9

Corrigida a regra, o bot continuou perdendo o nível 9 em quase toda seed — por
**1 a 6 blocos de 784**. O teste decisivo foi rodar com **0% de territoriais**:
perdeu do mesmo jeito. Três causas empilhadas, cada uma só visível depois de
remover a anterior:

1. **A imagem era densa demais.** O favo tinha **46% de céu** contra 59–71% de
   todos os outros níveis. Céu é espaço de manobra: com pouco, o fim de nível
   vira migalhas de 4 cores espalhadas pelos cantos, e colmeia limitada não
   alcança migalha. Uma moldura de +2 anéis de céu (46% → 59%) devolveu o
   nível à faixa saudável. Regra de artista atualizada: **céu entre 59% e
   71%** — medido, não estimado.

2. **Folga zero transforma qualquer erro em derrota.** Com `--slack 1.0`
   (o padrão), total de abelhas = total de blocos, exato. A 30% de colmeias
   travadas com 1 movimento, UMA colmeia encalhada com abelhas dentro já é
   derrota garantida — os blocos dela ficam órfãos. O nível 9 estreia o
   `--slack 1.15`: as colmeias continuam encalhando (2 a 9 por seed, a
   mecânica morde), mas o estrago é absorvível. A folga estava na tabela de
   dificultadores desde o começo como "disponível"; este é o nível que
   provou por que ela existe. O nível 7 caiu na mesma armadilha depois: passava
   sozinho e perdia por 1 bloco dentro da campanha (o relógio do bot entra em
   cada nível com outra fase, o que muda a trajetória). Regenerado com
   `--slack 1.10`, mesmo score (50,1 → 49,8). Regra que fica: **nível com
   colmeia limitada precisa de folga**.

3. **A folga criou carta morta — e um bug de bot.** Com abelhas sobrando, uma
   cor termina antes de as colmeias repetidas dela saírem da pilha. Essas
   cartas mortas entopem o topo das colunas, e o bot tinha um guard que
   recusava colocá-las (`count_of == 0 → não coloca`): ficou **340 segundos
   parado com 5 slots livres, 20 cartas na pilha e 24 blocos na tela**. O
   jogo estava certo — colocar carta morta custa um instante, ela é
   dispensada na hora e a coluna anda. O bot é que não sabia descartar.

Com as três correções: **7 de 7 seeds em vitória**, média de 0,07–0,30
remanejamento por colmeia limitada. A ordem importa: sem medir cada causa
isolada, a tentação era "afrouxar o território" — que nunca foi o culpado.

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
- **Céu (a cor que encosta na borda) entre 59% e 71%** da imagem. Faixa medida,
  não estimada: o favo do nível 9 nasceu com 46% e era invencível — sem céu não
  há espaço de manobra, e o fim de nível vira migalha fora de alcance.
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

| | 1 Broto | 2 Entardecer | 3 Colmeia | 4 Pote | 5 Girassol | 6 Rainha | 7 Pomar |
|---|---|---|---|---|---|---|---|
| Blocos | 400 | 576 | 784 | 676 | 784 | 784 | 784 |
| Letalidade | 0% | 23% | 29% | 12% | 20% | 21% | 19% |
| Pressão de slots | 15% | 35% | 46% | 21% | 56% | 42% | 54% |
| Limitadas | — | — | — | 5%×3 | 10%×3 | 20%×3 | **20%×2** |
| **Score (cor/ordem)** | **3,7** | **49,3** | **55,2** | **39,0** | **49,6** | **49,0** | **50,1** |

O score mede só o eixo cor/ordem, e nele a curva **não é monótona** de
propósito: o nível 4 alivia para ensinar a mobilidade limitada. O eixo novo —
fração de colmeias limitadas — esse sim só cresce.

### Só o que encosta na borda existe no começo

A primeira versão do nível 3 tinha o galho e o chão atravessando a grade de
ponta a ponta. Resultado: **quatro das sete cores já estavam expostas na
largada**, quase toda pilha puxada servia, e o nível maior e mais colorido
pontuou **35,6 — abaixo do nível 2**.

A intuição "mais cores = mais difícil" estava errada, e a medição pegou. O que
governa o perdão inicial não é o número de cores, é **quantas delas tocam a
borda da grade**. Recuando tudo para dentro do céu — só o azul encostando na
borda — o mesmo desenho subiu para 55,2.

Regra prática para o artista: se você quer tensão, enterre. **Uma cor que toca
a borda é uma cor de graça.**

### Quatro vezes minha intuição de arte errou

Um placar honesto das minhas hipóteses sobre o que deixa um nível difícil:

| hipótese | resultado medido |
|---|---|
| "mais cores = mais difícil" (nível 3, v1) | **35,6 — mais fácil que o nível 2** |
| "recuar tudo para dentro do céu" (nível 3, v2) | 55,2 — certa |
| "camadas concêntricas forçam ordem" (nível 5, v1) | **6–9, o guloso resolve** |
| "cores minúsculas e fundas" (nível 5, v2) | 48,1 — certa |

E um detalhe que fecha o argumento: aumentar uma única cor de **3 para 9
blocos** derrubou o score de 48,1 para 7,1. Depois, varrendo doze sementes na
mesma arte, os scores foram de 6 a 51.

**Uma semente não é uma medição.** O procedimento que sobrou é: filtrar rápido
pelo `guloso` (que é barato), medir os sobreviventes, escolher o melhor. Minha
opinião sobre o desenho serve para gerar candidatos, nunca para escolher.


### O teto desta versão

Varri sementes e intensidades de enterro; com 5 slots esta imagem satura por
volta de 55. Os termos disponíveis já estão perto do máximo — o guloso já falha
(20 pontos cheios) e a pressão de slots bate em ~48%.

Passar disso exige as mecânicas adiadas de propósito: **mobilidade limitada da
colmeia**, nuvem e pedra. A primeira é a mais forte, e é também a que cobra a
dívida técnica registrada no fim deste documento — o solver vai ter que
aprender posição.

## Anotações de UI vindas de referência do gênero

- **Caminho irregular na rota.** O zigue-zague estrito lado-a-lado lia como
  gerado. Agora o lado ainda alterna — é o que faz o conector em L se ler como
  trajeto — mas a posição dentro de cada lado e a altura variam. O sorteio é um
  **hash do índice**, não `Math.random`: a rota tem de ser idêntica em toda
  abertura do jogo, em qualquer aparelho.

Duas já aplicadas:

- **Favos menores na rota.** Nós grandes viravam uma coluna de balões e o
  caminho sumia. O que precisa se ler à distância é a trilha, não o nó.
- **A pilha mostra a fila de cores.** Antes as colmeias seguintes eram tocos
  escuros: dava para ver que havia mais, não de quais cores. A ordem das cores
  é justamente o que o jogador precisa para planejar, então esconder era
  esconder a decisão. O nome do tipo saiu junto — o hexágono já codifica o
  alcance, e a altura foi para a fila.

Uma anotada, não construída:

- **Fileira de facilitadores por anúncio.** Jogos do gênero põem uma linha de
  boosters abaixo da fila, obtidos assistindo propaganda. Encaixa no 6º slot já
  previsto como válvula de escape de deadlock. Precisa de SDK de anúncios, o
  que traz rede, privacidade e classificação etária — nada disso existe hoje.


## O medidor tem um teto de escala

O custo da análise é O(decisões × jogadas × sub-busca) e cresce mais que
linearmente com o tamanho do nível: a 784 blocos com muita ramificação, a
varredura completa passou de dez minutos e ficou inutilizável.

A saída foi **amostrar**: sondar no máximo 40 pontos de decisão, espaçados por
igual ao longo da solução. Validado contra a medição exaustiva do nível 5 —
**49,6 estimado contra 50,6 exato**, sondando 24 de 72 decisões.

O relatório sempre diz quando amostrou. Um número estimado apresentado como
exato seria pior que número nenhum.


## Em aberto

- Economia: mel offline (idle)? merge de colmeias? upgrade direto?
- Progressão de longo prazo e como as colmeias evoluem entre níveis.
- Pipeline de arte em volume: importar PNG já funciona, falta o banco de imagens.
