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
| 1 | **Mobilidade da colmeia** (`moves`) | `-1` livre → `N` remanejamentos → `0` fixa onde plantou. | **em uso** (nível 4) |
| 2 | **Folga de abelhas** (`--slack`) | Total de abelhas ÷ blocos daquela cor. | disponível |
| 3 | **Profundidade do enterro** (`--bury`) | Fração empurrada para o fundo de outra coluna. | em uso |
| 4 | **Colmeias ocultas (`?`)** | O jogador aposta sem saber o que vem. | pendente |
| 5 | **Nuvem** | Esconde uma região até X abelhas serem despachadas. | pendente |
| 6 | **Pedra** | Trava o topo de uma pilha; dois martelos. | pendente |

Nuvem e pedra ficam pra depois — 1 a 4 já dão muita corda.

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

### O que a instrumentação mostrou

Uma campanha completa do bot no nível 4 colocou **4 colmeias limitadas e
nenhuma esgotou os três movimentos**. A 5% e 3 remanejamentos a mecânica é
apresentada, não cobrada — que é o certo para o nível que a ensina, e é o
primeiro degrau de uma escada. Sem essa contagem, um teste verde não
distinguiria "a mecânica funciona" de "a mecânica nunca foi acionada".


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

### O termo que não entrou, e a conclusão que teve de ser corrigida

A primeira versão do score pesava o *atraso da armadilha*: quantas jogadas o
jogador faz antes de descobrir que já perdeu. Errar e travar na jogada seguinte
ensina; travar oito jogadas depois é punição.

Medindo os níveis 1 e 2, todos os 44 estados fatais tinham a mesma forma: o
jogador enchia o quinto slot e travava na hora, com zero jogadas seguintes. Eu
escrevi aqui que **"não existe morte lenta neste jogo"** e deixei o termo fora
do score, mas mantive a medição como canário.

**O nível 3 falsificou isso.** Com sete cores e a imagem inteira enterrada sob
o céu, aparecem estados em que ainda há jogada legal e o nível já está perdido —
o atraso medido ficou entre 0,5 e 2,0 jogadas. O canário fez exatamente o que
existia para fazer: avisar que uma suposição minha tinha morrido.

O termo segue fora do score, agora por outro motivo: os valores são rasos (0 a 2
jogadas), e re-pesar tudo com base em três níveis seria a mesma falsa precisão
contra a qual este documento avisa. Virou métrica normal no relatório, com aviso
alto só acima de 3 jogadas — onde a armadilha deixaria de ser rasa e passaria a
ser injusta de verdade.

**Lição de instrumentação:** um canário que sempre dispara é um canário que se
aprende a ignorar. Quando ele passou a tocar em toda rodada, virou métrica com
limiar, não alarme.

## Progressão: a rota

Os níveis são um caminho de favos, do primeiro embaixo ao último em cima. Um
nível abre quando o anterior é vencido, e **nível vencido pode ser rejogado
quantas vezes o jogador quiser** — sem perder o desbloqueio do seguinte. O
recorde de mel de cada um fica no favo.

O Ant Flow não tem isso: lá a campanha é uma fila de mão única. A rota custa
pouco e dá duas coisas que a fila não dá — a sensação de território percorrido,
e permissão para voltar num nível só porque foi gostoso.

Isso obrigou a introduzir o primeiro estado persistente do projeto: quais
níveis foram limpos e o melhor resultado de cada um. Em Godot vai para
`user://progress.json`; na versão web, para `localStorage`, com toda leitura e
escrita em `try/catch` — janela anônima devolve erro, e nesse caso o jogo roda
sem memória em vez de quebrar.

Limpar a imagem também continua avançando direto para o próximo nível; o cartão
de transição mostra o que vem a seguir — nome, tamanho e número de cores — e
oferece a volta à rota.

| | Primeiro Broto | Voo do Entardecer | A Colmeia no Galho |
|---|---|---|---|
| Grid | 20×20, 400 blocos | 24×24, 576 blocos | 28×28, 784 blocos |
| Cores | 5 | 6 | 7 |
| Colmeias | 39 | 56 | 81 |
| Enterro | nenhum | 0.45 | 0.60 |
| Letalidade média | 0% | 23% | **29%** |
| Nós do solver | 39 | 80 | **677** |
| **Score** | **3,7** tutorial | **49,3** médio | **55,2** médio |

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

### O teto desta versão

Varri sementes e intensidades de enterro; com 5 slots esta imagem satura por
volta de 55. Os termos disponíveis já estão perto do máximo — o guloso já falha
(20 pontos cheios) e a pressão de slots bate em ~48%.

Passar disso exige as mecânicas adiadas de propósito: **mobilidade limitada da
colmeia**, nuvem e pedra. A primeira é a mais forte, e é também a que cobra a
dívida técnica registrada no fim deste documento — o solver vai ter que
aprender posição.

## Em aberto

- Economia: mel offline (idle)? merge de colmeias? upgrade direto?
- Progressão de longo prazo e como as colmeias evoluem entre níveis.
- Pipeline de arte em volume: importar PNG já funciona, falta o banco de imagens.
