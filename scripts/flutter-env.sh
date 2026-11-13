# Source from project launchers: keep Flutter output away from the ./build command.
export XDG_CONFIG_HOME="$ROOT/.local/flutter-config"
mkdir -p "$XDG_CONFIG_HOME"
python3 - "$HOME/.config/flutter/settings" "$XDG_CONFIG_HOME/settings" <<'PY'
import json
from pathlib import Path
import sys
source, target = map(Path, sys.argv[1:])
settings = json.loads(source.read_text()) if source.is_file() else {}
settings['build-dir'] = '.flutter-build'
target.write_text(json.dumps(settings))
PY
