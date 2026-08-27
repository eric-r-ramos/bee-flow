import asyncio, json
from playwright.async_api import async_playwright

BOT = open("tools/test_web_bot.py").read().split('BOT = """')[1].split('"""')[0]

# O jogador humano tem "tentar de novo"; o bot tambem tem. Cada tentativa usa
# uma cadencia diferente (determinismo por tentativa), porque nivel de fio de
# navalha - colmeia limitada, folga zero - pode perder por 1 numa trajetoria e
# vencer na outra. O que o gate exige e que o nivel seja VENCIVEL no navegador,
# nao que uma unica trajetoria fixa vença. O Godot segue sem retry.
async def play(pg):
    for tent, cadencia in enumerate((9, 7, 8, 13)):
        await pg.evaluate("() => { speed = 8; fixedDt = 1 / 60; }")
        for _ in range(500):
            await pg.evaluate(BOT)
            await pg.evaluate(f"() => tick({cadencia})")
            if await pg.evaluate("() => phase !== 'play'"):
                break
        else:
            raise AssertionError("nao terminou")
        if await pg.evaluate("() => phase === 'win'"):
            if tent:
                print(f"   (venceu na tentativa {tent + 1}, cadencia {cadencia})")
            return
        await pg.click("#oAgain")   # "tentar de novo"
        await pg.wait_for_timeout(300)
    raise AssertionError("perdeu todas as tentativas")

async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path="/opt/pw-browsers/chromium")
        ctx = await b.new_context(viewport={"width": 390, "height": 780}, device_scale_factor=2)
        pg = await ctx.new_page()
        errs = []
        pg.on("pageerror", lambda e: errs.append(str(e)))
        await pg.goto("http://127.0.0.1:8731/web/bee-flow-play.html")
        await pg.wait_for_timeout(1200)

        st = await pg.evaluate("() => ({n: mapNodes.length, abertos: LEVELS.map((_,i)=>isUnlocked(i))})")
        print("rota inicial:", json.dumps(st))
        assert st["n"] == 9 and st["abertos"] == [True] + [False] * 8
        await pg.screenshot(path="wmap3_start.png")

        box = await pg.locator("#game").bounding_box()
        for i in range(9):
            n = await pg.evaluate(f"() => mapNodes[{i}]")
            await pg.mouse.click(box["x"] + n["x"], box["y"] + n["y"])
            await pg.wait_for_timeout(500)
            assert await pg.evaluate("() => li") == i, f"nao abriu o nivel {i+1}"
            await play(pg)
            await pg.wait_for_timeout(400)
            r = await pg.evaluate("""() => {
              const total = LEVEL.grid.join('').split('').filter(c => c !== '.').length;
              return { nivel: li + 1, phase, honey, blocos: total, bate: honey === total,
                       tempo: Math.round(playTime * 10) / 10,
                       perdidas: dispatched - total };
            }""")
            print("  ", json.dumps(r))
            assert r["bate"], f"mel nao bate no nivel {i+1}"
            await pg.click("#oMap")
            await pg.wait_for_timeout(500)

        st = await pg.evaluate("() => ({abertos: LEVELS.map((_,i)=>isUnlocked(i)), limpos: LEVELS.map((_,i)=>isCleared(i))})")
        print("rota final:", json.dumps(st))
        assert st["limpos"] == [True] * 9
        await pg.screenshot(path="wmap3_done.png")
        print("erros:", errs or "nenhum")
        assert not errs
        print("TUDO OK")
        await b.close()

asyncio.run(main())
