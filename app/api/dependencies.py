# app/api/dependencies.py

from typing import Annotated

from fastapi import Depends

from app.api.db_dependencies import MongoDBDep
from app.api.routes.health.health_service import HealthService


async def get_health_service(
    mongo: MongoDBDep,
) -> HealthService:
    return HealthService(
        mongo_db=mongo,
    )


HealthServiceDep = Annotated[HealthService, Depends(get_health_service)]
