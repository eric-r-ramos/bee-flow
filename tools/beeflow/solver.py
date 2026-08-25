"""Verificador e medidor de dificuldade do Bee Flow.

O gerador garante que *a sequencia* e solucionavel. Distribuir essa sequencia
em colunas pode quebrar a garantia (a colmeia certa fica enterrada), entao todo
nivel passa por aqui antes de ser publicado.

Aproximacao consciente: com colmeias de reposicionamento livre (moves == -1) o
jogador sempre consegue levar a colmeia ate qualquer bloco da cor dela, entao o
raio nao restringe a solucao - so a eficiencia. Por isso o solver ignora a
dimensao espacial nesse caso. Quando entrarem colmeias fixas (moves == 0) o
solver precisa passar a considerar posicao e alcance.
"""

from __future__ import annotations

from .board import Board

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


def solve(board: Board, columns: list[list[dict]], slots: int = 5,
          node_cap: int = NODE_CAP) -> dict:
    """Busca em profundidade com memo. Devolve solucao e metricas."""
    seen: set[str] = set()
    stats = {"nodes": 0, "capped": False}

    def dfs(b: Board, depths: tuple[int, ...], hives: list[list],
            path: list[int]) -> list[int] | None:
        if b.is_clear():
            return path
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

        for j, col in enumerate(columns):
            if depths[j] >= len(col):
                continue
            spec = col[depths[j]]
            nb = b.clone()
            nh = [list(h) for h in hives] + [[spec["color"], spec["bees"]]]
            _drain(nb, nh)
            nd = depths[:j] + (depths[j] + 1,) + depths[j + 1:]
            got = dfs(nb, nd, nh, path + [j])
            if got is not None:
                return got
        return None

    start_depths = tuple(0 for _ in columns)
    solution = dfs(board.clone(), start_depths, [], [])

    return {
        "solvable": solution is not None,
        "solution": solution,
        "moves": len(solution) if solution else 0,
        "nodes": stats["nodes"],
        "capped": stats["capped"],
        "greedy_ok": _greedy(board, columns, slots),
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
