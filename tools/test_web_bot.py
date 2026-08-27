import asyncio, json, os, pathlib
from playwright.async_api import async_playwright

# No contêiner da sessão web o Chromium fica fora do cache padrão do
# Playwright; em máquina local o Playwright acha o dele sozinho.
_EXE = "/opt/pw-browsers/chromium"
CHROMIUM = {"executable_path": _EXE} if os.path.exists(_EXE) else {}

BOT = """() => {
  if (phase !== 'play') return;

  const cellsOf = (key) => {
    const out = [];
    for (let i = 0; i < N; i++) if (cells[i] && KEYS[cells[i]-1] === key) out.push(i);
    return out;
  };
  const covered = (h, x, y) => {
    const reach = h.radius * cell; let n = 0;
    for (const i of frontierOf(h.key)) {
      const p = centerOf(i); if (Math.hypot(p.x-x, p.y-y) <= reach) n++;
    }
    return n;
  };
  // `durable` pontua pelo que AINDA EXISTE daquela cor, não pelo que está
  // exposto agora: colmeia que não pode se mexer precisa de um ponto que
  // continue valendo quando a fronteira andar.
  const spot = (key, radius, territorial, ignora, durable) => {
    const f = frontierOf(key); if (!f.length) return null;
    const alvo = durable ? cellsOf(key) : f;
    if (!alvo.length) return null;
    const reach = radius * cell; let best = null, bs = -1;
    const step = Math.max(1, Math.floor(f.length / 24));
    for (let k = 0; k < f.length; k += step) {
      const c = centerOf(f[k]);
      const cands = [[c.x, c.y]];
      for (const ring of [0.45, 0.8]) for (let i = 0; i < 8; i++) {
        const a = i * Math.PI / 4;
        cands.push([c.x + Math.cos(a) * reach * ring, c.y + Math.sin(a) * reach * ring]);
      }
      for (const [x, y] of cands) {
        if (!canPlace(x, y, reach, territorial, ignora)) continue;
        let sc = 0;
        for (const i of alvo) { const p = centerOf(i); if (Math.hypot(p.x-x, p.y-y) <= reach) sc++; }
        if (sc > bs) { bs = sc; best = [x, y]; }
        break;
      }
    }
    return best;
  };

  // Guardar o último remanejamento é boa estratégia — até o jogo parar.
  let travado = true;
  for (const h of hives) if (h.flight > 0 || pickTarget(h) >= 0) { travado = false; break; }

  for (const h of hives) {
    if (h.bees <= 0 || h.flight > 0 || pickTarget(h) >= 0 || !canMove(h)) continue;
    const t = spot(h.key, h.radius, h.territorial, h, h.moves >= 0);
    if (!t) continue;
    if (h.moves >= 0) {
      const restante = h.moves - h.used;
      const minimo = travado ? 1 : (restante >= 3 ? 2 : (restante === 2 ? 5 : 10));
      if (covered(h, t[0], t[1]) - covered(h, h.x, h.y) < minimo) continue;
    }
    h.x = t[0]; h.y = t[1]; h.used++;
  }

  const s = slots.indexOf(null); if (s < 0) return;
  let bj = -1, bn = -1;
  columns.forEach((d, j) => { if (!d.length) return;
    const n = frontierOf(d[0].color).length; if (n > bn) { bn = n; bj = j; } });
  if (bj < 0) return;
  const spec = columns[bj][0];
  let t = spot(spec.color, spec.radius, !!spec.territorial, null, (spec.moves ?? -1) >= 0);
  if (!t) {
    // Sem ponto útil: estaciona pra desenterrar — inclusive carta de cor já
    // limpa, que é dispensada na hora e faz a coluna andar.
    const a = boardRect, reach = spec.radius * cell;
    for (const fy of [0.06, 0.5, 0.94]) for (const fx of [0.06, 0.5, 0.94]) {
      const px = a.x + a.w * fx, py = a.y + a.h * fy;
      if (!t && canPlace(px, py, reach, !!spec.territorial)) t = [px, py];
    }
    if (!t) return;
  }
  columns[bj].shift();
  slots[s] = { key: spec.color, color: COLOR[spec.color], kind: spec.kind,
               radius: spec.radius, bees: spec.bees, moves: spec.moves ?? -1,
               territorial: !!spec.territorial, used: 0,
               x: t[0], y: t[1], slot: s, flight: 0, clock: SPAWN };
  hives.push(slots[s]);
}"""


async def play(pg, tag):
    await pg.evaluate("() => { speed = 8; }")
    for _ in range(140):
        await pg.evaluate(BOT)
        await pg.wait_for_timeout(150)
        if await pg.evaluate("() => phase !== 'play'"):
            break
    st = await pg.evaluate("() => ({phase, li, filled, honey, dispatched, blocks: N})")
    print(f"{tag}: {json.dumps(st)}")
    return st

async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(**CHROMIUM)
        pg = await b.new_page(viewport={"width": 390, "height": 780}, device_scale_factor=2)
        errs = []
        pg.on("pageerror", lambda e: errs.append(f"pageerror: {e}"))
        await pg.goto(pathlib.Path("web/bee-flow-play.html").resolve().as_uri())
        await pg.wait_for_timeout(1200)
        print("cabecalho inicial:", (await pg.inner_text("#brand")).replace("\n", " / "))

        await play(pg, "fim do nivel 1")
        await pg.wait_for_timeout(400)
        print("cartao:", (await pg.inner_text("#card")).replace("\n", " | "))
        await pg.screenshot(path="lv_transition.png")

        await pg.click("#oAgain")
        await pg.wait_for_timeout(900)
        print("cabecalho apos avancar:", (await pg.inner_text("#brand")).replace("\n", " / "))
        await pg.screenshot(path="lv2_start.png")

        st = await play(pg, "fim do nivel 2")
        await pg.wait_for_timeout(400)
        print("cartao final:", (await pg.inner_text("#card")).replace("\n", " | "))
        await pg.screenshot(path="lv2_end.png")
        print("erros:", errs if errs else "nenhum")
        assert st["phase"] == "win" and st["li"] == 1 and st["filled"] == 0, "campanha nao fechou"
        print("OK: campanha completa no navegador")
        await b.close()

asyncio.run(main())
