# main.py
import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Load .env into os.environ before any config reads
load_dotenv()

from app.api.main_router import main_router  # noqa: E402  # after load_dotenv()
from app.db.mongo_session import MongoSession  # noqa: E402  # after load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI):
    mongo_session = MongoSession()

    await mongo_session.connect()
    app.state.mongo_session = mongo_session

    yield

    await mongo_session.close()


# ── CORS (read from .env — never hardcode production origins) ──────────────────
# Comma-separated origins, e.g.
#   http://localhost,http://127.0.0.1,https://dev.fe.quralyst.ai,https://*.quralyst.ai
_raw_origins = os.environ.get("CORS_ORIGINS", "")
_cors_origins: list[str] = [o.strip() for o in _raw_origins.split(",") if o.strip()]
def _glob_to_regex(glob: str) -> str:
    """Convert a CORS glob origin like 'https://*.quralyst.ai' to a regex string."""
    # Escape literal dots first, then apply wildcard substitutions
    escaped = glob.replace(".", "\\.")
    # Handle '*.' (subdomain wildcard) before bare '*' to avoid double-matching
    return escaped.replace("*.", "[^.]+.").replace("*", ".*")


_cors_regexes = [_glob_to_regex(o) for o in _cors_origins if "*" in o]
_cors_non_regex = [o for o in _cors_origins if "*" not in o]
_cors_regex_str = "|".join(_cors_regexes) if _cors_regexes else None

app = FastAPI(title="Quralust", lifespan=lifespan)

if _cors_non_regex or _cors_regex_str:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_cors_non_regex,
        allow_origin_regex=_cors_regex_str,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
app.include_router(main_router)
