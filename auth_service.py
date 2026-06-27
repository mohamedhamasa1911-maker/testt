from __future__ import annotations

import hashlib
import hmac
import secrets
import sqlite3
from datetime import datetime, timedelta


PASSWORD_ITERATIONS = 310_000
SESSION_HOURS = 12


def normalize_username(value: object) -> str:
    username = str(value or "").strip().lower()
    if not username or len(username) > 50:
        raise ValueError("اسم المستخدم مطلوب وبحد أقصى 50 حرفًا.")
    if not all(char.isalnum() or char in "._-" for char in username):
        raise ValueError("اسم المستخدم يقبل الحروف والأرقام والنقطة والشرطة فقط.")
    return username


def validate_password(password: object) -> str:
    value = str(password or "")
    if len(value) < 8:
        raise ValueError("كلمة المرور يجب ألا تقل عن 8 أحرف.")
    return value


def password_hash(password: str, salt: bytes | None = None) -> tuple[str, str]:
    salt = salt or secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt,
        PASSWORD_ITERATIONS,
    )
    return salt.hex(), digest.hex()


def verify_password(password: str, salt_hex: str, digest_hex: str) -> bool:
    try:
        salt = bytes.fromhex(salt_hex)
    except ValueError:
        return False
    _, candidate = password_hash(password, salt)
    return hmac.compare_digest(candidate, digest_hex)


def create_user(
    conn: sqlite3.Connection,
    username: object,
    display_name: object,
    password: object,
    role: str = "user",
) -> dict:
    login = normalize_username(username)
    name = str(display_name or "").strip()
    if not name or len(name) > 100:
        raise ValueError("الاسم مطلوب وبحد أقصى 100 حرف.")
    password_value = validate_password(password)
    normalized_role = "admin" if role == "admin" else "user"
    salt, digest = password_hash(password_value)
    current = datetime.now().replace(microsecond=0).isoformat(sep=" ")
    try:
        cursor = conn.execute(
            """
            INSERT INTO users (
                username, display_name, password_salt, password_hash,
                role, is_active, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, 1, ?, ?)
            """,
            (login, name, salt, digest, normalized_role, current, current),
        )
    except sqlite3.IntegrityError as exc:
        raise ValueError("اسم المستخدم مستخدم بالفعل.") from exc
    return {
        "id": int(cursor.lastrowid),
        "username": login,
        "display_name": name,
        "role": normalized_role,
        "is_active": True,
    }


def authenticate(conn: sqlite3.Connection, username: object, password: object) -> dict | None:
    try:
        login = normalize_username(username)
    except ValueError:
        return None
    row = conn.execute(
        "SELECT * FROM users WHERE username = ? AND is_active = 1",
        (login,),
    ).fetchone()
    if not row or not verify_password(str(password or ""), row["password_salt"], row["password_hash"]):
        return None
    return public_user(row)


def public_user(row: sqlite3.Row | dict) -> dict:
    return {
        "id": int(row["id"]),
        "username": row["username"],
        "display_name": row["display_name"],
        "role": row["role"],
        "is_active": bool(row["is_active"]),
    }


def create_session(conn: sqlite3.Connection, user_id: int, ip_address: str) -> str:
    token = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
    created = datetime.now().replace(microsecond=0)
    expires = created + timedelta(hours=SESSION_HOURS)
    conn.execute(
        """
        INSERT INTO sessions (token_hash, user_id, ip_address, created_at, expires_at)
        VALUES (?, ?, ?, ?, ?)
        """,
        (
            token_hash,
            user_id,
            ip_address,
            created.isoformat(sep=" "),
            expires.isoformat(sep=" "),
        ),
    )
    return token


def session_user(conn: sqlite3.Connection, token: str) -> dict | None:
    if not token:
        return None
    token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
    row = conn.execute(
        """
        SELECT u.*
        FROM sessions s
        JOIN users u ON u.id = s.user_id
        WHERE s.token_hash = ?
          AND s.expires_at > ?
          AND u.is_active = 1
        """,
        (token_hash, datetime.now().replace(microsecond=0).isoformat(sep=" ")),
    ).fetchone()
    return public_user(row) if row else None


def revoke_session(conn: sqlite3.Connection, token: str) -> None:
    if token:
        token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
        conn.execute("DELETE FROM sessions WHERE token_hash = ?", (token_hash,))


def cleanup_sessions(conn: sqlite3.Connection) -> None:
    conn.execute(
        "DELETE FROM sessions WHERE expires_at <= ?",
        (datetime.now().replace(microsecond=0).isoformat(sep=" "),),
    )
