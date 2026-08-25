"""Medidor de dificuldade do Bee Flow.

`solvable` diz se o nivel e possivel. `greedy_ok` diz se ele e trivial. Nenhum
dos dois e um numero, e entre "possivel" e "trivial" cabe o jogo inteiro.

A pergunta que este modulo responde e uma so:

    em cada decisao, quantas das escolhas legais matam o nivel?

Um nivel onde toda escolha serve nao e quebra-cabeca, e animacao. Um nivel onde
quase toda escolha mata e injusto. A dificuldade mora no meio, e e isso que a
letalidade mede.

O metodo: percorrer a solucao encontrada pelo solver e, em cada passo, testar
*todas* as jogadas legais - nao so a que o solver escolheu. Cada alternativa
vira uma nova busca a partir daquele estado. Caro, mas roda uma vez por nivel,
no build, e nunca no celular.
"""

from __future__ import annotations

from statistics import mean

from .board import Board
from .solver import apply_move, legal_moves, solve, solve_from

SUB_CAP = 20_000     # nos por sub-busca ("essa jogada ainda deixa vencer?")
TRAP_CAP = 4_000     # nos por medicao de atraso da armadilha

# Pesos do score final. IMPORTANTE: sao uma hipotese, nao uma verdade medida.
# So dados de jogadores reais podem calibra-los - ate la o score serve pra
# ordenar niveis entre si, nao pra prometer quanto tempo alguem vai levar.
W_LETHALITY = 0.40   # quao arriscada e a decisao media
W_PEAK = 0.15        # quao arriscada e a PIOR decisao
W_GREEDY = 0.20      # exige planejamento?
W_PRESSURE = 0.25    # o jogador joga sufocado de slots?

# O atraso da armadilha - quantas jogadas o jogador ainda faz antes de
# descobrir que ja perdeu - e medido mas NAO entra no score.
#
# Historico, porque a conclusao mudou: nos niveis 1 e 2 ele deu zero em todos
# os estados fatais, e eu escrevi que "nao existe morte lenta neste jogo". O
# nivel 3 falsificou isso - com sete cores e a imagem toda enterrada sob o ceu,
# aparecem estados em que ainda ha jogada legal e o nivel ja esta perdido.
#
# Continua fora do score por outro motivo: os valores observados sao rasos
# (0 a 2 jogadas), e re-pesar o score inteiro com base em tres niveis seria
# exatamente a falsa precisao contra a qual o resto deste arquivo avisa. O
# aviso alto so dispara acima de DEEP_TRAP, onde a armadilha deixaria de ser
# rasa e passaria a ser injusta de verdade.
DEEP_TRAP = 3.0

BANDS = [(20, "tutorial"), (40, "facil"), (60, "medio"), (80, "dificil"),
         (101, "brutal")]


def _key(board: Board, depths: tuple, hives: list[list]) -> tuple:
    return (board.state_key(), depths,
            tuple(sorted((c, n) for c, n in hives)))


def _survival(board: Board, columns: list[list[dict]], depths: tuple,
              hives: list[list], slots: int) -> int:
    """Quantas jogadas o jogador ainda faz antes de descobrir que ja perdeu.

    Errar e perceber na jogada seguinte ensina. Errar e so travar oito jogadas
    depois e punicao - o jogador nao consegue ligar a causa ao efeito.
    """
    best = 0
    seen: set[tuple] = set()
    stack = [(board, depths, [list(h) for h in hives], 0)]
    visited = 0

    while stack and visited < TRAP_CAP:
        b, d, h, depth = stack.pop()
        visited += 1
        best = max(best, depth)
        for j in legal_moves(columns, d, h, slots):
            nb, nd, nh = apply_move(b, columns, d, h, j)
            k = _key(nb, nd, nh)
            if k in seen:
                continue
            seen.add(k)
            stack.append((nb, nd, nh, depth + 1))
    return best


def analyze(board: Board, columns: list[list[dict]], slots: int = 5) -> dict:
    base = solve(board, columns, slots)
    if not base["solvable"]:
        return {"solvable": False}

    b = board.clone()
    depths: tuple = tuple(0 for _ in columns)
    hives: list[list] = []

    tested = fatal = unknown = 0
    trap_delays: list[int] = []
    branching: list[int] = []
    free_slots: list[int] = []
    per_decision: list[float] = []   # letalidade de cada decisao, em ordem
    real_decisions = 0

    for chosen in base["solution"]:
        moves = legal_moves(columns, depths, hives, slots)
        branching.append(len(moves))
        free_slots.append(slots - len(hives))

        if len(moves) > 1:
            real_decisions += 1
            here_tested = here_fatal = 0
            for j in moves:
                nb, nd, nh = apply_move(b, columns, depths, hives, j)
                if nb.is_clear():
                    tested += 1          # jogada que ganha na hora: segura
                    here_tested += 1
                    continue
                probe = solve_from(nb, columns, nd, nh, slots, SUB_CAP)
                if probe["capped"]:
                    # Estourou o orcamento: nao sabemos. Contar como fatal
                    # inflaria a letalidade, entao fica de fora e aparece
                    # no relatorio - truncar em silencio seria mentir.
                    unknown += 1
                    continue
                tested += 1
                here_tested += 1
                if not probe["solvable"]:
                    fatal += 1
                    here_fatal += 1
                    trap_delays.append(_survival(nb, columns, nd, nh, slots))
            if here_tested:
                per_decision.append(here_fatal / here_tested)

        b, depths, hives = apply_move(b, columns, depths, hives, chosen)

    lethality = fatal / tested if tested else 0.0
    peak = max(per_decision) if per_decision else 0.0
    pressure = 1.0 - (mean(free_slots) / slots if free_slots else 1.0)
    trap = mean(trap_delays) if trap_delays else 0.0
    greedy_penalty = 0.0 if base["greedy_ok"] else 1.0

    # A que altura do nivel a primeira jogada fatal aparece. Perto de 1.0
    # significa que o jogador pode brincar a vontade e so precisa acertar
    # no fim; perto de 0.0 significa que da pra perder na largada.
    onset = 1.0
    for i, lt in enumerate(per_decision):
        if lt > 0.0:
            onset = i / len(per_decision)
            break

    score = 100.0 * (W_LETHALITY * lethality + W_PEAK * peak
                     + W_GREEDY * greedy_penalty + W_PRESSURE * pressure)
    band = next(name for limit, name in BANDS if score < limit)

    return {
        "solvable": True,
        "score": round(score, 1),
        "band": band,
        "lethality": round(lethality, 3),
        "peak_lethality": round(peak, 3),
        "risk_onset": round(onset, 3),
        "fatal_moves": fatal,
        "tested_moves": tested,
        "unknown_moves": unknown,
        "trap_delay": round(trap, 2),
        "slot_pressure": round(pressure, 3),
        "branching": round(mean(branching), 2) if branching else 0.0,
        "decisions": real_decisions,
        "moves": base["moves"],
        "greedy_ok": base["greedy_ok"],
    }


def report(d: dict) -> str:
    if not d["solvable"]:
        return "  INSOLUVEL"
    lines = [
        f"  score {d['score']:.1f}/100  ->  {d['band'].upper()}",
        f"    letalidade      {d['lethality']:.1%} em media, "
        f"{d['peak_lethality']:.0%} na pior decisao",
        f"                    ({d['fatal_moves']} de {d['tested_moves']} "
        f"jogadas legais matam)",
        f"    risco comeca    a {d['risk_onset']:.0%} do nivel",
        f"    atraso da trap  {d['trap_delay']:.1f} jogadas ate o jogador perceber",
        f"    pressao slots   {d['slot_pressure']:.1%}",
        f"    ramificacao     {d['branching']:.2f} escolhas por vez, "
        f"{d['decisions']} decisoes reais em {d['moves']} jogadas",
        f"    guloso resolve  {'SIM' if d['greedy_ok'] else 'NAO'}",
    ]
    if d["trap_delay"] > DEEP_TRAP:
        lines.append(f"    AVISO: atraso da armadilha {d['trap_delay']:.1f} - o jogador "
                     f"perde longe do erro e nao consegue ligar causa e efeito")
    if d["unknown_moves"]:
        lines.append(f"    ATENCAO: {d['unknown_moves']} jogadas nao verificadas "
                     f"(orcamento de busca estourado)")
    return "\n".join(lines)
