from __future__ import annotations

import os
import subprocess
import sys
import time
import webbrowser
from pathlib import Path
from urllib.request import urlopen


BASE_DIR = Path(__file__).resolve().parent


def main() -> int:
    app = BASE_DIR / "app.py"
    host = os.environ.get("ARCHIVE_HOST", "127.0.0.1")
    port = int(os.environ.get("ARCHIVE_PORT", "8787"))
    browser_host = "127.0.0.1" if host == "0.0.0.0" else host
    url = f"http://{browser_host}:{port}"

    process = subprocess.Popen([sys.executable, str(app)], cwd=BASE_DIR)
    for _ in range(30):
        if process.poll() is not None:
            return process.returncode or 1
        try:
            with urlopen(f"{url}/health", timeout=1):
                webbrowser.open(url)
                break
        except Exception:
            time.sleep(0.3)
    try:
        return process.wait()
    except KeyboardInterrupt:
        process.terminate()
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
