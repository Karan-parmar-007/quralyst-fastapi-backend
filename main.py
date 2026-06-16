# main.py
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.main_router import main_router
from app.api.middlewares.csrf import CSRFMiddleware
from app.db.mongo_session import MongoSession


@asynccontextmanager
async def lifespan(app: FastAPI):
    mongo_session = MongoSession()

    await mongo_session.connect()
    app.state.mongo_session = mongo_session

    yield

    await mongo_session.close()


app = FastAPI(title="Quralust", lifespan=lifespan)
# app.add_middleware(CSRFMiddleware)
app.include_router(main_router)
