from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "sqlite:///./madini-backend.db"
    jwt_secret: str = ""
    jwt_issuer: str = "madini-api"
    access_token_minutes: int = 30
    environment: str = "development"

    model_config = SettingsConfigDict(env_file=".env", env_prefix="MADINI_", extra="ignore")


settings = Settings()
