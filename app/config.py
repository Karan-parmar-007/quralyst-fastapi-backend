# app/config.py
from pydantic_settings import BaseSettings, SettingsConfigDict

_base_config = SettingsConfigDict(
    env_file=".env",
    env_file_encoding="utf-8",
    env_ignore_empty=True,
    extra="ignore"

)

class DatabaseSettings(BaseSettings):
    """Database settings."""

    
    MONGO_URI: str 
    MONGO_DB_NAME: str


    model_config = _base_config


class AuthSettings(BaseSettings):
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    RESET_PASSWORD_TOKEN_EXPIRE_MINUTES: int = 15
    FORGET_PASSWORD_TOKEN_EXPIRE_MINUTES: int = 15
    EMAIL_VERIFICATION_TOKEN_EXPIRE_MINUTES: int = 15
    CSRF_SECRET_KEY: str = ""

    model_config = _base_config

    @property
    def _csrf_secret(self) -> str:
        return self.CSRF_SECRET_KEY or self.SECRET_KEY





auth_settings = AuthSettings() # type: ignore
db_settings = DatabaseSettings() # type: ignore
