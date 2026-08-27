"""Verificador e medidor de dificuldade do Bee Flow.

O gerador garante que *a sequencia* e solucionavel. Distribuir essa sequencia
em colunas pode quebrar a garantia (a colmeia certa fica enterrada), entao todo
nivel passa por aqui antes de ser publicado.

Sao DOIS verificadores, e a escolha depende da mobilidade:

`solve` e combinatorio e cego a geometria. Com reposicionamento livre
(moves == -1) isso e correto: o jogador leva a colmeia ate qualquer bloco da cor
dela, entao o raio afeta eficiencia, nao possibilidade.

`solve_spatial` respeita ancoradouro e raio. E o unico valido quando existe
colmeia presa (moves == 0), porque ai a colmeia fica onde pousou. Usar o cego
nesse caso aprova nivel invencivel - foi o que aconteceu no nivel 10.
"""

from __future__ import annotations

import math

from .board import EMPTY, Board

NODE_CAP = 200_000


def _drain(board: Board, hives: list[list], ) -> None:
    """Deixa todas as colmeias ativas coletarem ate travar. Muta board/hives.

    hives: lista de [color, bees_left]. Colmeia sem abelhas, ou cuja cor acabou
    no tabuleiro, e removida (o slot dela libera).
    """
    progressed = True
    while progressed:
        progressed = False
        for hive in hives:
            color, bees = hive
            if bees <= 0:
                continue
            frontier = [i for i in board.frontier() if board.cells[i] == color]
            for i in frontier:
                if bees <= 0:
                    break
                board.remove(i)
                bees -= 1
                progressed = True
            hive[1] = bees

    counts = board.counts_by_color()
    hives[:] = [h for h in hives if h[1] > 0 and counts.get(h[0], 0) > 0]


def _key(board: Board, depths: tuple[int, ...], hives: list[list]) -> str:
    active = ",".join(sorted(f"{c}:{n}" for c, n in hives))
    return f"{board.state_key()}|{depths}|{active}"


def legal_moves(columns: list[list[dict]], depths: tuple[int, ...],
                hives: list[list], slots: int) -> list[int]:
    """Pilhas que o jogador pode puxar agora."""
    if len(hives) >= slots:
        return []
    return [j for j in range(len(columns)) if depths[j] < len(columns[j])]


def apply_move(board: Board, columns: list[list[dict]], depths: tuple[int, ...],
               hives: list[list], j: int) -> tuple[Board, tuple[int, ...], list[list]]:
    """Puxa o topo da pilha j, poe em campo e deixa tudo coletar ate travar."""
    spec = columns[j][depths[j]]
    nb = board.clone()
    nh = [list(h) for h in hives] + [[spec["color"], spec["bees"]]]
    _drain(nb, nh)
    nd = depths[:j] + (depths[j] + 1,) + depths[j + 1:]
    return nb, nd, nh


def solve(board: Board, columns: list[list[dict]], slots: int = 5,
          node_cap: int = NODE_CAP) -> dict:
    """Busca em profundidade com memo, do inicio. Devolve solucao e metricas."""
    out = solve_from(board, columns, tuple(0 for _ in columns), [], slots, node_cap)
    out["greedy_ok"] = _greedy(board, columns, slots)
    return out


def solve_from(board: Board, columns: list[list[dict]], depths: tuple[int, ...],
               hives: list[list], slots: int = 5, node_cap: int = NODE_CAP) -> dict:
    """Mesma busca, mas partindo de um estado qualquer no meio da partida."""
    seen: set[str] = set()
    stats = {"nodes": 0, "capped": False, "melhor": None, "motivo": ""}

    def dfs(b: Board, depths: tuple[int, ...], hives: list[list],
            path: list[int]) -> list[int] | None:
        if b.is_clear():
            return path
        restante = b.filled()
        if stats["melhor"] is None or restante < stats["melhor"]:
            stats["melhor"] = restante
            stats["motivo"] = "profundidade %d, %d colmeias em campo" % (
                len(path), len(hives))
        stats["nodes"] += 1
        if stats["nodes"] > node_cap:
            stats["capped"] = True
            return None

        k = _key(b, depths, hives)
        if k in seen:
            return None
        seen.add(k)

        if len(hives) >= slots:
            return None  # slots cheios e nada drena: sem movimento

        for j in legal_moves(columns, depths, hives, slots):
            nb, nd, nh = apply_move(b, columns, depths, hives, j)
            got = dfs(nb, nd, nh, path + [j])
            if got is not None:
                return got
        return None

    solution = dfs(board.clone(), depths, [list(h) for h in hives], [])

    return {
        "solvable": solution is not None,
        "solution": solution,
        "moves": len(solution) if solution else 0,
        "nodes": stats["nodes"],
        "capped": stats["capped"],
    }


def _greedy(board: Board, columns: list[list[dict]], slots: int) -> bool:
    """O nivel cai sozinho com a heuristica burra 'pegue a coluna mais a esquerda'?

    Se sim, o nivel e facil: nao exige planejamento nenhum.
    """
    b = board.clone()
    depths = [0] * len(columns)
    hives: list[list] = []
    for _ in range(sum(len(c) for c in columns) + 1):
        if b.is_clear():
            return True
        if len(hives) >= slots:
            return False
        picked = next((j for j, c in enumerate(columns) if depths[j] < len(c)), None)
        if picked is None:
            return False
        spec = columns[picked][depths[picked]]
        depths[picked] += 1
        hives.append([spec["color"], spec["bees"]])
        _drain(b, hives)
    return b.is_clear()


# --------------------------------------------------------- verificador espacial
#
# O solver acima e cego a geometria: ele assume que qualquer colmeia da cor X
# drena qualquer bloco de X. Com reposicionamento livre isso e verdade - o
# jogador leva a colmeia ate o bloco -, entao o raio so afetava eficiencia.
#
# Com colmeia PRESA (moves = 0) a suposicao desaba: a colmeia fica onde pousou
# e so alcanca o que cabe no circulo dela. "Solucionavel=SIM" do solver cego
# passou a nao significar nada, e foi assim que o nivel 10 saiu do gerador
# aprovado e invencivel.
#
# Aqui a prova volta a existir, e por exibicao: o gerador ja descobre, para cada
# colmeia, um ancoradouro de onde ela esvazia exatamente as abelhas dela. O que
# faltava era carregar esses pontos e conferir que a ORDEM EMBARALHADA das
# pilhas ainda os honra. Nao e busca sobre posicoes (o espaco e continuo e
# inviavel) - e replay da estrategia de referencia sob a restricao de slots.


def _reaches_any(board: Board, hive: list) -> bool:
    """Os blocos atribuidos a ela ainda estao no tabuleiro?

    Se um deles sumiu sem ela ter tirado, alguem roubou e a atribuicao quebrou:
    o ramo esta perdido. Enterrado nao e problema - o miolo abre quando os
    vizinhos sairem, e ela espera.
    """
    return all(board.cells[i] != EMPTY for i in hive[1])


def _drain_spatial(board: Board, hives: list[list]) -> None:
    """Coleta ate travar. Muta board/hives.

    hives: [color, pendentes, ax, ay, radius], onde `pendentes` sao os blocos
    que ESTA colmeia tem de tirar - a atribuicao que o gerador anotou ao
    descascar. Cada colmeia so toca no que e dela, entao duas da mesma cor com
    raios sobrepostos nao disputam bloco e nenhuma encalha por roubo.

    A fronteira e recalculada entre as passadas: tirar um bloco expoe os
    vizinhos dele, e e assim que o miolo abre.
    """
    progressed = True
    while progressed:
        progressed = False
        frontier = set(board.frontier())
        for hive in hives:
            pendentes = hive[1]
            if not pendentes:
                continue
            saiu = [i for i in pendentes if i in frontier]
            if not saiu:
                continue
            for i in saiu:
                board.remove(i)
                pendentes.remove(i)
            progressed = True

    # Mesma regra do jogo: o slot so volta quando a ultima abelha sai. Colmeia
    # com abelha dentro e sem alcance fica ocupando lugar - e o entupimento que
    # o jogador ve na mesa.
    hives[:] = [h for h in hives if h[1]]


def _spatial_key(board: Board, depths: tuple[int, ...], hives: list[list]) -> str:
    active = ",".join(sorted(f"{h[0]}:{len(h[1])}:{h[2]:.1f}:{h[3]:.1f}" for h in hives))
    return f"{board.state_key()}|{depths}|{active}"


def _spatial_moves(board: Board, columns: list[list[dict]], depths: tuple[int, ...],
                   hives: list[list], slots: int) -> list[int]:
    """Pilhas puxaveis, com as uteis primeiro.

    Puxar uma carta que ja tem o que colher destrava o tabuleiro; puxar uma que
    vai ficar parada ocupa slot a toa. A ordem nao muda o que e alcancavel, so
    a rapidez com que a busca encontra a linha boa.
    """
    if len(hives) >= slots:
        return []
    livres = [j for j in range(len(columns)) if depths[j] < len(columns[j])]
    frontier = board.frontier_by_color()

    def util(j: int) -> int:
        spec = columns[j][depths[j]]
        ax, ay = spec["anchor"]
        radius = spec["radius"]
        pend = set(spec["cells"])
        return sum(1 for i in frontier.get(spec["color"], ()) if i in pend)

    return sorted(livres, key=lambda j: -util(j))


def solve_spatial(board: Board, columns: list[list[dict]], slots: int = 5,
                  node_cap: int = 20_000) -> dict:
    """Confere que o nivel se limpa com as colmeias PRESAS nos ancoradouros.

    Devolve a mesma forma do `solve`, para o chamador nao precisar saber qual
    dos dois rodou.
    """
    seen: set[str] = set()
    stats = {"nodes": 0, "capped": False, "melhor": None, "motivo": ""}

    def dfs(b: Board, depths: tuple[int, ...], hives: list[list],
            path: list[int]) -> list[int] | None:
        if b.is_clear():
            return path
        restante = b.filled()
        if stats["melhor"] is None or restante < stats["melhor"]:
            stats["melhor"] = restante
            stats["motivo"] = "profundidade %d, %d colmeias em campo" % (
                len(path), len(hives))
        stats["nodes"] += 1
        if stats["nodes"] > node_cap:
            stats["capped"] = True
            return None

        # Abelha encalhada e derrota: o nivel tem uma abelha por bloco, entao
        # abelha que nunca mais voa e bloco que ninguem coleta. Podar aqui evita
        # a busca gastar folego num ramo ja perdido.
        for h in hives:
            if h[1] and not _reaches_any(b, h):
                return None

        k = _spatial_key(b, depths, hives)
        if k in seen:
            return None
        seen.add(k)

        for j in _spatial_moves(b, columns, depths, hives, slots):
            spec = columns[j][depths[j]]
            nb = b.clone()
            ax, ay = spec["anchor"]
            nh = [list(h) for h in hives] + [
                [spec["color"], list(spec["cells"]), ax, ay, spec["radius"]]
            ]
            _drain_spatial(nb, nh)
            nd = depths[:j] + (depths[j] + 1,) + depths[j + 1:]
            got = dfs(nb, nd, nh, path + [j])
            if got is not None:
                return got
        return None

    solution = dfs(board.clone(), tuple(0 for _ in columns), [], [])
    return {
        "solvable": solution is not None,
        "solution": solution,
        "moves": len(solution) if solution else 0,
        "nodes": stats["nodes"],
        "capped": stats["capped"],
        "greedy_ok": False,
        "melhor_restante": stats["melhor"],
        "onde": stats["motivo"],
    }
