# app/api/db_dependencies.py

from typing import Annotated, AsyncGenerator
from fastapi import Depends, Request
from pymongo.asynchronous.database import AsyncDatabase


async def _get_mongo_db(request: Request) -> AsyncGenerator[AsyncDatabase, None]:
    mongo_manager = request.app.state.mongo_session
    async for db in mongo_manager.get_db():
        yield db



MongoDBDep = Annotated[AsyncDatabase, Depends(_get_mongo_db)]
