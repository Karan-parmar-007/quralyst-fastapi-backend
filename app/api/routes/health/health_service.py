import asyncio
import logging
from typing import Any

from pymongo.asynchronous.database import AsyncDatabase

logger = logging.getLogger(__name__)

HEALTH_CHECK_TIMEOUT_SECONDS = 5.0


class HealthService:
    def __init__(
        self,
        mongo_db: AsyncDatabase,
    ) -> None:
        self.mongo_db = mongo_db


    async def check_mongodb(self) -> bool:
        return await self._run_check("mongodb", self._check_mongodb)

    async def _run_check(self, name: str, check) -> bool:
        try:
            return await asyncio.wait_for(
                check(),
                timeout=HEALTH_CHECK_TIMEOUT_SECONDS,
            )
        except TimeoutError:
            logger.warning("%s health check timed out after %ss", name, HEALTH_CHECK_TIMEOUT_SECONDS)
            return False
        except Exception:
            logger.exception("%s health check failed", name)
            return False



    async def _check_mongodb(self) -> bool:
        await self.mongo_db.command("ping")
        return True

