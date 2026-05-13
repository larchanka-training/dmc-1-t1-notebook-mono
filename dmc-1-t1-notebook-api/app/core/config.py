from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "MSD FastAPI Template"
    app_env: str = "dev"
    api_prefix: str = "/api/v1"

    # Logging settings
    log_level: str = "DEBUG"
    log_level_console: str = "DEBUG"
    log_level_file: str = "INFO"
    log_file: Path = Path("logs/app.log")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
    )


settings = Settings()
