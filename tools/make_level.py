#!/usr/bin/env python3
"""Converte uma imagem (.txt de arte ASCII ou .png) num nivel jogavel.

    python3 tools/make_level.py --input tools/samples/flower.txt \
        --out levels/level_001.json --id level_001 --name "Primeiro Broto"

O artista nunca pensa em solucionabilidade: a imagem e livre, e a pilha de
colmeias e derivada e verificada aqui.
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from beeflow.board import EMPTY, Board
from beeflow.difficulty import analyze
from beeflow.difficulty import report as report_difficulty
from beeflow.generator import apply_mobility, apply_territory, deal, derive_sequence
from beeflow.palette import PALETTE, nearest_key
from beeflow.solver import solve, solve_spatial


def load_board(path: Path) -> Board:
    if path.suffix.lower() == ".png":
        from PIL import Image  # so importa se realmente for PNG

        img = Image.open(path).convert("RGBA")
        lines = []
        for y in range(img.height):
            row = []
            for x in range(img.width):
                r, g, b, a = img.getpixel((x, y))
                row.append(EMPTY if a < 128 else nearest_key((r, g, b)))
            lines.append("".join(row))
        return Board.from_lines(lines)

    text = path.read_text(encoding="utf-8")
    lines = [ln for ln in text.splitlines() if ln and not ln.startswith("#")]
    return Board.from_lines(lines)


def build(board: Board, seed: int, columns: int, slots: int, slack: float,
          attempts: int, bury: float, limited_frac: float,
          limited_moves: int, territorial_frac: float) -> tuple[list[list[dict]], dict, int, int, int]:
    """Tenta varias sementes ate cair um deal verificadamente solucionavel."""
    last = None
    for attempt in range(attempts):
        rng = random.Random(seed + attempt)
        seq = derive_sequence(board, rng)
        if slack > 1.0:
            for hive in seq:
                hive["bees"] = max(1, round(hive["bees"] * slack))
        limited = apply_mobility(seq, rng, limited_frac, limited_moves)
        territorial = apply_territory(seq, rng, territorial_frac)
        dealt = deal(seq, columns, rng, bury)
        # Colmeia presa exige o verificador espacial: o combinatorio assume que
        # qualquer colmeia da cor alcanca qualquer bloco da cor, o que so vale
        # com reposicionamento livre.
        # O combinatorio confere ordem de pilha e pressao de slot; o espacial
        # confere que a estrategia de referencia sobrevive a essa ordem com as
        # colmeias presas nos ancoradouros. Sao perguntas diferentes, entao com
        # colmeia fixa o nivel tem de passar nas DUAS - trocar uma pela outra
        # deixava um buraco de cada lado.
        presa = any(h.get("moves", -1) == 0 for c in dealt for h in c)
        report = solve(board, dealt, slots=slots)
        if presa and report["solvable"]:
            esp = solve_spatial(board, dealt, slots=slots)
            if not esp["solvable"]:
                report["solvable"] = False
                report["nodes"] += esp["nodes"]
        report["spatial"] = presa
        last = (dealt, report, seed + attempt, limited, territorial)
        if report["solvable"]:
            return last
    return last


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--input", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--id", default=None)
    ap.add_argument("--name", default="Sem nome")
    ap.add_argument("--slots", type=int, default=5)
    ap.add_argument("--columns", type=int, default=5)
    ap.add_argument("--slack", type=float, default=1.0,
                    help="folga de abelhas: 1.0 e cirurgico, 1.2 perdoa desperdicio")
    ap.add_argument("--limited-frac", type=float, default=0.0,
                    help="fracao de colmeias com remanejamento limitado")
    ap.add_argument("--limited-moves", type=int, default=3,
                    help="quantos remanejamentos as colmeias limitadas ganham")
    ap.add_argument("--territorial-frac", type=float, default=0.0,
                    help="fracao de colmeias cuja area nao pode encostar em outra")
    ap.add_argument("--bury", type=float, default=0.0,
                    help="fracao de colmeias enterradas no fundo da pilha mais alta")
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--attempts", type=int, default=12)
    ap.add_argument("--no-difficulty", action="store_true",
                    help="pula a analise de dificuldade (mais rapido)")
    args = ap.parse_args()

    board = load_board(args.input)
    counts = board.counts_by_color()
    dealt, report, used_seed, limited, territorial = build(
        board, args.seed, args.columns, args.slots, args.slack, args.attempts,
        args.bury, args.limited_frac, args.limited_moves, args.territorial_frac
    )

    if not report["solvable"]:
        print(f"FALHOU: nenhuma das {args.attempts} tentativas gerou nivel solucionavel")
        print(f"  nos explorados: {report['nodes']}  cap atingido: {report['capped']}")
        return 1

    diff = None if args.no_difficulty else analyze(board, dealt, args.slots)

    # A atribuicao de blocos so serve ao verificador espacial, que ja rodou.
    # Publicar ela seria mandar a solucao junto com o enigma - e engordar o
    # arquivo em mil indices. O ancoradouro fica: e pequeno, e e o que permite
    # reverificar um nivel ja publicado.
    for col in dealt:
        for hive in col:
            hive.pop("cells", None)

    level = {
        "id": args.id or args.out.stem,
        "name": args.name,
        "rows": board.rows,
        "cols": board.cols,
        "slots": args.slots,
        "palette": {k: PALETTE[k] for k in sorted(counts)},
        "grid": board.to_lines(),
        "columns": dealt,
        "meta": {
            "seed": used_seed,
            "blocks": board.filled(),
            "hives": sum(len(c) for c in dealt),
            "greedy_ok": report["greedy_ok"],
            "solver_nodes": report["nodes"],
            "difficulty": diff,
            "limited_hives": limited,
            "limited_moves": args.limited_moves if limited else 0,
            "territorial_hives": territorial,
        },
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(level, ensure_ascii=False, indent=2) + "\n",
                        encoding="utf-8")

    print(f"OK  {args.out}")
    print(f"  {board.rows}x{board.cols}, {board.filled()} blocos")
    for key in sorted(counts):
        bees = sum(h["bees"] for c in dealt for h in c if h["color"] == key)
        print(f"  {key} {PALETTE[key]['name']:<9} blocos={counts[key]:<4} "
              f"abelhas={bees:<4} folga={bees / counts[key]:.2f}")
    print(f"  colmeias={level['meta']['hives']} em {args.columns} colunas")
    prova = "combinatorio+espacial" if report.get("spatial") else "combinatorio"
    print(f"  solucionavel=SIM  prova={prova}"
          f"  guloso={'SIM' if report['greedy_ok'] else 'NAO'}"
          f"  nos={report['nodes']}  seed={used_seed}")
    if limited:
        total = sum(len(c) for c in dealt)
        print(f"  mobilidade      {limited} de {total} colmeias "
              f"({limited / total:.0%}) com {args.limited_moves} remanejamentos")
    if territorial:
        total = sum(len(c) for c in dealt)
        print(f"  territorio      {territorial} de {total} colmeias "
              f"({territorial / total:.0%}) nao admitem area encostada")
    if diff:
        print(report_difficulty(diff))
        if limited:
            print("    ATENCAO: o score NAO mede pressao espacial. Com colmeias de"
                  "\n             mobilidade limitada, a dificuldade real e MAIOR"
                  "\n             que o numero acima.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
