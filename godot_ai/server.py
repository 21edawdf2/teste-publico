from __future__ import annotations

import os
from collections import defaultdict, deque
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from openai import OpenAI
from pydantic import BaseModel, Field

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")

app = FastAPI(title="Godot OpenAI Assistant", version="1.0.0")

# Mantém um contexto curto apenas enquanto o servidor estiver aberto.
history: dict[str, deque[dict[str, str]]] = defaultdict(lambda: deque(maxlen=12))


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=30000)
    session_id: str = "godot-editor"
    project_name: str = "Projeto Godot"
    scene: str = "(nenhuma cena aberta)"
    godot_version: str = "Godot 4"


class ResetRequest(BaseModel):
    session_id: str = "godot-editor"


def get_client() -> OpenAI:
    key = os.getenv("OPENAI_API_KEY", "").strip()
    if not key:
        raise HTTPException(
            status_code=500,
            detail="OPENAI_API_KEY não configurada. Rode INSTALAR_E_LIGAR.bat novamente."
        )
    return OpenAI(api_key=key)


@app.get("/health")
def health():
    return {
        "status": "ok",
        "model": os.getenv("OPENAI_MODEL", "gpt-5.6-luna")
    }


@app.post("/reset")
def reset(req: ResetRequest):
    history.pop(req.session_id, None)
    return {"status": "ok"}


@app.post("/chat")
def chat(req: ChatRequest):
    client = get_client()
    model = os.getenv("OPENAI_MODEL", "gpt-5.6-luna").strip() or "gpt-5.6-luna"

    context_note = (
        f"Contexto do editor: projeto={req.project_name!r}; "
        f"cena={req.scene!r}; versão={req.godot_version!r}."
    )

    h = history[req.session_id]
    h.append({"role": "user", "content": context_note + "\n\n" + req.message})

    instructions = """Você é um assistente de desenvolvimento integrado ao editor Godot.
Responda em português do Brasil.
Priorize Godot 4.x e GDScript 2.0.
Quando fornecer código, deixe claro em qual arquivo ele deve ser colocado.
Não diga que alterou/criou arquivos ou nós se você apenas forneceu instruções.
Se uma operação puder apagar ou sobrescrever trabalho, avise antes.
Se o usuário trouxer um erro, explique a causa provável e entregue passos concretos para corrigir.
Seja prático e direto."""

    try:
        response = client.responses.create(
            model=model,
            instructions=instructions,
            input=list(h),
        )
        reply = (response.output_text or "").strip()
        if not reply:
            reply = "A API retornou uma resposta sem texto."
        h.append({"role": "assistant", "content": reply})
        return {"reply": reply, "model": model}
    except Exception as exc:
        # Não expõe a chave; mostra apenas a mensagem da biblioteca/API.
        raise HTTPException(status_code=500, detail=f"Erro da OpenAI: {exc}") from exc


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8765)
