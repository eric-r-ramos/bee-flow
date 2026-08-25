"""Gerador de niveis do Bee Flow.

A imagem e arte livre; a pilha de colmeias e derivada por algoritmo.
O gerador *joga o nivel sozinho* e anota cada colmeia que precisou usar,
entao a sequencia produzida e solucionavel por construcao. Depois ela e
distribuida em colunas (so o topo de cada coluna e elegivel pra um slot),
e essa etapa - a unica que pode criar deadlock - e verificada pelo solver.
"""

from __future__ import annotations

import math
import random

from .board import EMPTY, Board

# Raio em celulas. Colmeias diferentes cobrem areas diferentes: e o eixo
# de variedade que o Ant Flow nao tem.
HIVE_KINDS = [
    {"kind": "operaria", "radius": 3.5},
    {"kind": "zangao", "radius": 5.5},
    {"kind": "batedora", "radius": 8.0},
]


def _anchor_for(board: Board, seed: int, radius: float) -> tuple[float, float]:
    """Ponto de pouso plausivel pra colmeia: fora da silhueta, perto do bloco."""
    r, c = board.rc(seed)
    cx, cy = c + 0.5, r + 0.5
    dx, dy = 0.0, 0.0
    for nr, nc in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
        outside = not (0 <= nr < board.rows and 0 <= nc < board.cols)
        if outside or board.cells[board.idx(nr, nc)] == EMPTY:
            dx += nc + 0.5 - cx
            dy += nr + 0.5 - cy
    norm = math.hypot(dx, dy)
    if norm < 1e-6:
        return cx, cy
    push = radius * 0.45
    return cx + dx / norm * push, cy + dy / norm * push


def _peel(board: Board, color: str, anchor: tuple[float, float],
          radius: float, want: int) -> int:
    """Coleta ate `want` blocos de `color` no alcance, recalculando a fronteira.

    Descascar de fora pra dentro expoe blocos novos a cada remocao - e por isso
    que o raio nao precisa alcancar o miolo da imagem no inicio.
    """
    ax, ay = anchor
    taken = 0
    while taken < want:
        candidates = []
        for i in board.frontier():
            if board.cells[i] != color:
                continue
            r, c = board.rc(i)
            d = math.hypot(c + 0.5 - ax, r + 0.5 - ay)
            if d <= radius:
                candidates.append((d, i))
        if not candidates:
            break
        candidates.sort()
        board.remove(candidates[0][1])
        taken += 1
    return taken


def derive_sequence(board: Board, rng: random.Random, min_chunk: int = 5,
                    max_chunk: int = 24) -> list[dict]:
    """Joga o nivel do inicio ao fim e devolve as colmeias que foram precisas."""
    work = board.clone()
    seq: list[dict] = []
    guard = work.filled() * 2 + 64

    while not work.is_clear() and guard > 0:
        guard -= 1
        by_color = work.frontier_by_color()
        if not by_color:
            raise RuntimeError("fronteira vazia com blocos restantes - grid invalido")

        # Prefere a cor com mais blocos expostos, com um empurrao aleatorio,
        # pra alternar cores em vez de esvaziar uma antes de tocar na outra.
        colors = sorted(by_color, key=lambda k: -len(by_color[k]))
        color = rng.choice(colors[:2]) if len(colors) > 1 else colors[0]

        # Sorteia o tipo de colmeia; so cresce o raio se o sorteado nao alcancar
        # nada. Sem isso o gerador escolheria sempre a menor e os tipos maiores
        # nunca apareceriam no jogo.
        kinds = sorted(HIVE_KINDS, key=lambda k: k["radius"])
        first = rng.randrange(len(kinds))
        taken = 0
        for kind in kinds[first:] + kinds[:first]:
            seed = rng.choice(by_color[color])
            anchor = _anchor_for(work, seed, kind["radius"])
            want = rng.randint(min_chunk, max_chunk)
            taken = _peel(work, color, anchor, kind["radius"], want)
            if taken > 0:
                seq.append({
                    "color": color,
                    "bees": taken,
                    "radius": kind["radius"],
                    "kind": kind["kind"],
                    "moves": -1,  # v0: reposicionamento livre
                })
                break
        if taken == 0:
            raise RuntimeError(f"nao consegui coletar nenhum bloco '{color}'")

    if not work.is_clear():
        raise RuntimeError("nao consegui limpar o tabuleiro")
    return seq


def deal(seq: list[dict], n_columns: int, rng: random.Random | None = None,
         bury: float = 0.0) -> list[list[dict]]:
    """Distribui a sequencia em colunas. Indice 0 de cada coluna e o topo.

    Round-robin puro deixa a colmeia necessaria sempre no topo de *alguma*
    coluna: o jogador so precisa escolher qual, e a heuristica gulosa resolve.

    `bury` (0..1) e a fracao de colmeias empurradas pro fundo da coluna mais
    alta em vez da coluna da vez. Isso enterra o que o jogador precisa sob
    colmeias inuteis, obrigando ele a queimar slots pra desenterrar - que e a
    profundidade de enterro do DESIGN.md. E a unica etapa capaz de criar
    deadlock, entao o solver revalida tudo depois.
    """
    columns: list[list[dict]] = [[] for _ in range(n_columns)]
    for i, hive in enumerate(seq):
        target = i % n_columns
        if bury > 0.0 and rng is not None and n_columns > 1 and rng.random() < bury:
            # Qualquer coluna menos a da vez. Mandar pra "mais alta" seria pior
            # que inutil: concentraria a sequencia numa pilha so, em ordem, e o
            # nivel ficaria MAIS facil. Por isso o efeito e sempre medido pelo
            # solver depois, nunca presumido.
            options = [j for j in range(n_columns) if j != target]
            target = rng.choice(options)
        columns[target].append(hive)
    return columns
