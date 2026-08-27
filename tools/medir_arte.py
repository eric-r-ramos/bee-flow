#!/usr/bin/env python3
"""Mede uma arte antes de virar nível: céu de manobra e fragmentação de cor.

    python3 tools/medir_arte.py tools/samples/apiary.txt

Duas medidas, ambas aprendidas perdendo nível:

**Céu.** Céu é espaço de manobra — é onde a colmeia pousa. A faixa saudável
medida nos níveis 1 a 8 é 59% a 71%. O favo do nível 9 saiu com 46% e o fim de
nível virava migalha de quatro cores espalhadas: o bot perdia por um bloco em
quase toda seed. Foi preciso emoldurar a imagem com dois anéis de céu.

**Fragmentação.** Colmeia sem remanejamento planta num pedaço da cor e nunca
alcança o resto — e desde a regra do encalhe isso é derrota imediata. Cor
partida em pedaços pequenos e distantes é armadilha. Quanto mais colmeia presa
o nível tiver, mais isso pesa.

O raio de voo vai de 3,5 a 8 células, então um pedaço menor que ~10 células
raramente justifica uma colmeia própria: ou está perto de outro pedaço da mesma
cor, ou vai encalhar alguém.
"""
import sys
from collections import Counter, deque


def carrega(caminho):
    linhas = [l.rstrip("\n") for l in open(caminho, encoding="utf-8")
              if l.strip() and not l.startswith("#")]
    largura = max(len(l) for l in linhas)
    return [l.ljust(largura, ".") for l in linhas]


def componentes(linhas, ch):
    """Pedaços separados daquela cor, do maior para o menor."""
    rows, cols = len(linhas), len(linhas[0])
    visto = [[False] * cols for _ in range(rows)]
    out = []
    for y in range(rows):
        for x in range(cols):
            if linhas[y][x] != ch or visto[y][x]:
                continue
            fila, n = deque([(y, x)]), 0
            visto[y][x] = True
            while fila:
                cy, cx = fila.popleft()
                n += 1
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = cy + dy, cx + dx
                    if (0 <= ny < rows and 0 <= nx < cols
                            and not visto[ny][nx] and linhas[ny][nx] == ch):
                        visto[ny][nx] = True
                        fila.append((ny, nx))
            out.append(n)
    return sorted(out, reverse=True)


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    linhas = carrega(sys.argv[1])
    rows, cols = len(linhas), len(linhas[0])
    cnt = Counter(ch for l in linhas for ch in l)
    total = rows * cols
    vazio = cnt.pop(".", 0)
    ceu = cnt.get("b", 0)

    print(f"{rows}x{cols} = {total} células, {total - vazio} blocos")
    # Compara no valor exibido, senão 58,98% aparece como "59%" e é reprovado
    # como fora da faixa 59-71% - contradição na mesma linha.
    pct = round(100 * ceu / total)
    faixa = "ok" if 59 <= pct <= 71 else "FORA da faixa 59-71%"
    print(f"céu (b): {ceu} = {pct}%   {faixa}")
    if vazio:
        print(f"vazio (.): {vazio} — corredor, não é bloco e não precisa de abelha")

    print(f"\n{'cor':<5}{'blocos':>8}   pedaços separados")
    alerta = 0
    for ch in sorted(cnt):
        comp = componentes(linhas, ch)
        aviso = ""
        if len(comp) > 1 and comp[-1] < 10:
            aviso = "  <-- PEDAÇO ÓRFÃO: risco de encalhe"
            alerta += 1
        print(f"{ch:<5}{cnt[ch]:>8}   {comp}{aviso}")

    print("\nnenhuma cor órfã" if not alerta
          else f"\n{alerta} cor(es) com pedaço órfão — evite colmeia presa nesta arte")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
