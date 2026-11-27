#!/bin/sh
# src/ parçalarını tek dosyalık game/index.html'e birleştirir
cd "$(dirname "$0")/.."
cat src/00_shell.html src/01_core.js src/02_data.js src/03_cache.js src/04_render.js src/05_world.js src/06_figure.js src/07_input.js src/08_actors.js src/09_vehicles.js src/10_ui.js src/11_missions.js src/115_updater.js src/12_main.js src/99_end.html | sed "s/__NG_VERSION__/$(cat VERSION)/g" > game/index.html
echo "game/index.html: $(wc -c < game/index.html) bayt"
