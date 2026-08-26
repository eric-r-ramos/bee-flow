"""Regra nova: abelha encalhada = derrota na hora.

Monta o cenario do playtest - colmeia sem remanejamento plantada fora do
alcance da cor dela - e exige que o jogo declare a derrota no mesmo quadro, em
vez de deixar o jogador seguir meia partida ate travar de vez.

Testa tambem os dois lados negativos, que sao onde um falso positivo doeria:
colmeia presa mas COM alvo no raio, e colmeia livre no mesmo ponto ruim.
"""
import asyncio, json
from playwright.async_api import async_playwright

URL = "http://127.0.0.1:8731/bee-flow-play.html"

# Tira a carta do topo da coluna e planta a colmeia num ponto dado, do mesmo
# jeito que o bot faz. Tirar a carta da pilha e essencial: sao as abelhas DELA
# que encalham, e se a carta continuasse na pilha a conta nao fecharia.
PLANT = """([j, x, y, moves]) => {
  const spec = columns[j][0];
  columns[j].shift();
  const s = slots.indexOf(null);
  slots[s] = { key: spec.color, color: COLOR[spec.color], kind: spec.kind,
               radius: spec.radius, bees: spec.bees, moves,
               territorial: !!spec.territorial, used: 0,
               x, y, slot: s, flight: 0, clock: SPAWN };
  hives.push(slots[s]);
  return { key: spec.color, bees: spec.bees, radius: spec.radius };
}"""

# Ponto da zona de voo sem NENHUM bloco daquela cor no raio (enterrado conta).
FAR = """([key, radius]) => {
  const reach = radius * cell;
  const alvo = [];
  for (let i = 0; i < N; i++) if (cells[i] && KEYS[cells[i]-1] === key) alvo.push(centerOf(i));
  for (let fy = 0; fy <= 40; fy++) for (let fx = 0; fx <= 40; fx++) {
    const x = boardRect.x + boardRect.w * fx / 40, y = boardRect.y + boardRect.h * fy / 40;
    if (!canPlace(x, y, reach, false)) continue;
    if (alvo.every(p => Math.hypot(p.x - x, p.y - y) > reach)) return { x, y };
  }
  return null;
}"""

# Ponto colado no primeiro bloco daquela cor - o oposto do FAR.
NEAR = """([key, radius]) => {
  const reach = radius * cell;
  for (let i = 0; i < N; i++) {
    if (!cells[i] || KEYS[cells[i]-1] !== key) continue;
    const c = centerOf(i);
    for (let r = 0; r <= 12; r++) for (let a = 0; a < 12; a++) {
      const ang = a * Math.PI / 6, d = reach * r / 12;
      const x = c.x + Math.cos(ang) * d, y = c.y + Math.sin(ang) * d;
      if (canPlace(x, y, reach, false)) return { x, y };
    }
  }
  return null;
}"""


async def cenario(pg, nivel, moves, onde):
    """Abre o nivel limpo e planta uma colmeia com `moves` no ponto `onde`."""
    await pg.evaluate(f"() => openLevel({nivel})")
    await pg.wait_for_timeout(250)
    # Coluna cujo topo tem cor que nao cobre o tabuleiro inteiro: qualquer uma
    # serve para o FAR existir. Pega a primeira que tenha ponto valido.
    for j in range(await pg.evaluate("() => columns.length")):
        spec = await pg.evaluate(f"() => columns[{j}][0]")
        if not spec:
            continue
        busca = FAR if onde == "longe" else NEAR
        p = await pg.evaluate(busca, [spec["color"], spec["radius"]])
        if p:
            h = await pg.evaluate(PLANT, [j, p["x"], p["y"], moves])
            return h
    raise AssertionError(f"nenhuma coluna serviu para o cenario {onde}")


async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path="/opt/pw-browsers/chromium")
        ctx = await b.new_context(viewport={"width": 390, "height": 780}, device_scale_factor=2)
        pg = await ctx.new_page()
        errs = []
        pg.on("pageerror", lambda e: errs.append(str(e)))
        await pg.goto(URL)
        await pg.wait_for_timeout(1000)
        await pg.evaluate("() => { fixedDt = 1 / 60; speed = 1; }")

        # 1. PRESA E LONGE: derrota no mesmo quadro.
        h = await cenario(pg, 8, 0, "longe")
        falta = await pg.evaluate("() => beeShortage()")
        assert falta == h["key"], f"esperava falta de {h['key']}, veio {falta}"
        await pg.evaluate("() => tick(1)")
        r = await pg.evaluate("""() => ({ phase, titulo: document.getElementById('oTitle').textContent,
                                          visivel: over.classList.contains('show') })""")
        print("presa+longe:", json.dumps(r, ensure_ascii=False))
        assert r["phase"] == "lose" and r["visivel"], "nao declarou derrota"
        assert r["titulo"] == "Colmeia presa", f"banner errado: {r['titulo']}"
        await pg.screenshot(path="t12_presa.png")

        # 2. PRESA MAS COM ALVO: segue jogando.
        await cenario(pg, 8, 0, "perto")
        falta = await pg.evaluate("() => beeShortage()")
        await pg.evaluate("() => tick(30)")
        ph = await pg.evaluate("() => phase")
        print("presa+perto:", json.dumps({"falta": falta, "phase": ph}))
        assert falta is None and ph == "play", "falso positivo com alvo no raio"

        # 3. LIVRE E LONGE: segue jogando, porque ela ainda pode ser levada.
        await cenario(pg, 8, -1, "longe")
        falta = await pg.evaluate("() => beeShortage()")
        await pg.evaluate("() => tick(30)")
        ph = await pg.evaluate("() => phase")
        print("livre+longe:", json.dumps({"falta": falta, "phase": ph}))
        assert falta is None and ph == "play", "falso positivo com colmeia livre"

        assert not errs, errs
        print("OK")
        await b.close()

asyncio.run(main())
