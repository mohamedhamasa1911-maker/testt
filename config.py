from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

try:
    from dotenv import load_dotenv
except ImportError:
    load_dotenv = None


BASE_DIR = Path(__file__).resolve().parent
if load_dotenv:
    load_dotenv(BASE_DIR / ".env")


def _path_from_env(name: str, default: Path) -> Path:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return default.resolve()
    path = Path(raw)
    if not path.is_absolute():
        path = BASE_DIR / path
    return path.resolve()


def _sqlite_path(database_url: str, fallback: Path) -> Path:
    prefix = "sqlite:///"
    if not database_url.startswith(prefix):
        return fallback
    raw = database_url[len(prefix) :]
    path = Path(raw)
    if not path.is_absolute():
        path = BASE_DIR / path
    return path.resolve()


@dataclass(frozen=True)
class Settings:
    base_dir: Path
    static_dir: Path
    data_dir: Path
    db_path: Path
    uploads_dir: Path
    originals_dir: Path
    scans_dir: Path
    excel_dir: Path
    processed_dir: Path
    reports_dir: Path
    logs_dir: Path
    host: str
    port: int
    log_level: str
    max_upload_bytes: int
    ocr_provider: str
    ocr_languages: str
    tesseract_cmd: str
    tessdata_dir: Path
    openrouter_api_key: str
    openrouter_model: str


def load_settings() -> Settings:
    data_dir = _path_from_env("ARCHIVE_DATA_DIR", BASE_DIR / "data")
    database_url = os.environ.get("DATABASE_URL", "").strip()
    db_path = _sqlite_path(database_url, data_dir / "archive.db")
    uploads_dir = data_dir / "uploads"
    return Settings(
        base_dir=BASE_DIR,
        static_dir=BASE_DIR / "static",
        data_dir=data_dir,
        db_path=db_path,
        uploads_dir=uploads_dir,
        originals_dir=uploads_dir / "originals",
        scans_dir=uploads_dir / "scans",
        excel_dir=uploads_dir / "excel",
        processed_dir=uploads_dir / "processed",
        reports_dir=data_dir / "exports" / "reports",
        logs_dir=data_dir / "logs",
        host=os.environ.get("ARCHIVE_HOST", "127.0.0.1"),
        port=int(os.environ.get("ARCHIVE_PORT", "8787")),
        log_level=os.environ.get("LOG_LEVEL", "INFO").upper(),
        max_upload_bytes=max(0, int(os.environ.get("MAX_UPLOAD_MB", "0"))) * 1024 * 1024,
        ocr_provider=os.environ.get("OCR_PROVIDER", "local").strip().lower() or "local",
        ocr_languages=os.environ.get("OCR_LANGUAGES", "ara+eng").strip() or "ara+eng",
        tesseract_cmd=os.environ.get("TESSERACT_CMD", "").strip(),
        tessdata_dir=_path_from_env("TESSDATA_DIR", BASE_DIR / "tessdata"),
        openrouter_api_key=os.environ.get("OPENROUTER_API_KEY", "").strip(),
        openrouter_model=os.environ.get("OPENROUTER_MODEL", "openrouter/auto").strip(),
    )


SETTINGS = load_settings()
