from pathlib import Path

Import("env")
root = Path(env.subst("$PROJECT_DIR"))
html = (root.parent / "web" / "index.html").read_text(encoding="utf-8")
assert ')SENSOWEB"' not in html
(root / "include" / "webapp.generated.h").write_text(
    '#pragma once\nstatic const char WEBAPP[] PROGMEM = R"SENSOWEB('
    + html + ')SENSOWEB";\n', encoding="utf-8")
