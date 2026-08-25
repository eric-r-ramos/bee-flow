#!/usr/bin/env bash
# Teste de fumaca do Bee Flow. Uso: GODOT=/caminho/para/godot tools/smoke.sh
set -euo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

echo "== gerador: a imagem de exemplo tem que produzir nivel solucionavel"
python3 tools/make_level.py --input tools/samples/flower.txt \
    --out /tmp/beeflow_check.json --id check --name check

echo
echo "== jogo: level_001 tem que terminar em VITORIA"
"$GODOT" --headless --path . --fixed-fps 120 -- \
    --autoplay --level res://levels/level_001.json

echo
echo "== jogo: test_deadlock tem que terminar em DERROTA"
if "$GODOT" --headless --path . --fixed-fps 120 -- \
        --autoplay --level res://levels/test_deadlock.json; then
    echo "FALHOU: nivel impossivel deveria ter sido detectado como derrota"
    exit 1
fi

echo
echo "tudo ok"
