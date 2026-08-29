from pathlib import Path
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "project.godot"
PLUGIN = 'res://addons/openai_assistant/plugin.cfg'

if not PROJECT.exists():
    print("[ERRO] project.godot nao encontrado.")
    print("Extraia o ZIP diretamente na pasta raiz do seu projeto Godot.")
    sys.exit(2)

text = PROJECT.read_text(encoding="utf-8-sig")

if PLUGIN not in text:
    backup = ROOT / "project.godot.bak_openai_assistant"
    if not backup.exists():
        shutil.copy2(PROJECT, backup)

    section_re = re.compile(r'(?ms)^\[editor_plugins\]\s*\n(.*?)(?=^\[|\Z)')
    match = section_re.search(text)

    if match:
        section_body = match.group(1)
        enabled_re = re.compile(r'(?m)^enabled\s*=\s*PackedStringArray\((.*?)\)\s*$')
        enabled = enabled_re.search(section_body)
        if enabled:
            inside = enabled.group(1).strip()
            quoted = f'"{PLUGIN}"'
            new_inside = f"{inside}, {quoted}" if inside else quoted
            new_body = (
                section_body[:enabled.start()]
                + f"enabled=PackedStringArray({new_inside})"
                + section_body[enabled.end():]
            )
        else:
            new_body = section_body.rstrip() + f'\nenabled=PackedStringArray("{PLUGIN}")\n'

        text = text[:match.start(1)] + new_body + text[match.end(1):]
    else:
        text = text.rstrip() + f'\n\n[editor_plugins]\nenabled=PackedStringArray("{PLUGIN}")\n'

    PROJECT.write_text(text, encoding="utf-8")
    print("[OK] Plugin habilitado em project.godot.")
else:
    print("[OK] Plugin ja estava habilitado.")

gitignore = ROOT / ".gitignore"
existing = gitignore.read_text(encoding="utf-8") if gitignore.exists() else ""
entries = [".env", ".godot_ai_venv/", "__pycache__/", "*.bak_openai_assistant"]
to_add = [e for e in entries if e not in existing.splitlines()]
if to_add:
    with gitignore.open("a", encoding="utf-8") as f:
        if existing and not existing.endswith("\n"):
            f.write("\n")
        f.write("\n# Godot OpenAI Assistant\n")
        for e in to_add:
            f.write(e + "\n")
    print("[OK] .gitignore atualizado para proteger a chave da API.")

print("[OK] Configuracao do projeto concluida.")
