#!/usr/bin/env python3
"""O que o verificador espacial prova - e o que ele NAO prova.

Existe para nao deixar ninguem (inclusive eu, daqui a um mes) confundir as duas
coisas. O teste 2 falha de proposito se alguem "consertar" a vacuidade sem
trocar o que esta sendo verificado.

    python3 tools/test_solver_espacial.py
"""
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from beeflow.board import Board
from beeflow.generator import apply_mobility, deal, derive_sequence
from beeflow.solver import solve_spatial


def monta(caminho, seed, bury=0.0, frac=1.0, moves=0):
    lines = [l for l in open(caminho, encoding="utf-8")
             if l.strip() and not l.startswith("#")]
    board = Board.from_lines(lines)
    rng = random.Random(seed)
    seq = derive_sequence(board, rng)
    apply_mobility(seq, rng, frac, moves)
    return board, deal(seq, 5, rng, bury)


def main() -> int:
    arte = str(Path(__file__).resolve().parent / "samples" / "flower.txt")
    falhas = []

    # 1. Aprova o que deve aprovar, e sem backtracking: a atribuicao de blocos
    #    feita ao descascar torna a linha de referencia executavel direto.
    for seed in range(4):
        board, dealt = monta(arte, seed)
        r = solve_spatial(board, dealt, slots=5, node_cap=8000)
        n = sum(len(c) for c in dealt)
        if not r["solvable"]:
            falhas.append(f"seed {seed}: deveria aprovar, reprovou")
        elif r["nodes"] > n:
            falhas.append(f"seed {seed}: {r['nodes']} nos para {n} colmeias "
                          "- a atribuicao deveria dispensar backtracking")
    print(f"1. aprova a linha de referencia sem backtracking: "
          f"{'OK' if not falhas else 'FALHOU'}")

    # 2. E VACUO como porteiro: nunca reprova, nem com baralho hostil nem com
    #    um slot so. A razao e estrutural, nao um bug - a estrategia de
    #    referencia e serial (planta uma colmeia, espera esvaziar, planta a
    #    proxima), e estrategia serial cabe em um slot. Ou seja: ele prova que
    #    EXISTE uma linha vencedora, o que ja se sabia. NAO prova que um jogador
    #    que ignora a atribuicao secreta consegue achar uma.
    #
    #    Por isso o gerador exige tambem o solver combinatorio, e por isso o
    #    porteiro de verdade continua sendo o bot. Trocar isto por um verificador
    #    que busque entre os pousos que o JOGADOR poderia escolher e o trabalho
    #    que falta.
    reprovou = False
    for bury, slots in ((0.9, 5), (0.0, 1)):
        for seed in range(4):
            board, dealt = monta(arte, seed, bury=bury)
            if not solve_spatial(board, dealt, slots=slots, node_cap=4000)["solvable"]:
                reprovou = True
    print(f"2. vacuo como porteiro (nunca reprova): "
          f"{'OK, como documentado' if not reprovou else 'MUDOU - reveja o texto acima'}")
    if reprovou:
        falhas.append("o verificador passou a reprovar: a documentacao acima "
                      "ficou desatualizada e precisa ser reescrita")

    for f in falhas:
        print("  !", f)
    return 1 if falhas else 0


if __name__ == "__main__":
    raise SystemExit(main())
