"""Local account registry. Passwords and bearer sessions are never stored raw."""
import hashlib
import hmac
import re
import secrets
import sqlite3
import threading
import time
from collections import deque
from contextlib import contextmanager
from pathlib import Path

ROLES = {'user', 'teacher', 'student'}
SESSION_SECONDS = 30 * 24 * 60 * 60


class AccountError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


class Accounts:
    def __init__(self, directory, store_factory):
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.file = self.directory / 'accounts.sqlite3'
        self.lock = threading.RLock()
        self.attempts = deque()
        self.stores = {}
        self.store_factory = store_factory
        with self.database() as db:
            db.execute('CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, email TEXT UNIQUE, name TEXT, role TEXT, salt TEXT, password TEXT)')
            db.execute('CREATE TABLE IF NOT EXISTS sessions (digest TEXT PRIMARY KEY, user_id TEXT, expires REAL)')
        self.file.chmod(0o600)

    @contextmanager
    def database(self):
        db = sqlite3.connect(self.file)
        try:
            with db:
                yield db
        finally:
            db.close()

    def throttle(self):
        now = time.monotonic()
        with self.lock:
            while self.attempts and self.attempts[0] <= now - 60:
                self.attempts.popleft()
            if len(self.attempts) >= 12:
                raise AccountError(429, 'Quá nhiều lần đăng nhập hoặc đăng ký. Thử lại sau một phút.')
            self.attempts.append(now)

    @staticmethod
    def digest(token):
        return hashlib.sha256(token.encode()).hexdigest()

    @staticmethod
    def hash_password(password, salt):
        return hashlib.pbkdf2_hmac('sha256', password.encode(), bytes.fromhex(salt), 600_000).hex()

    @staticmethod
    def profile(row):
        return dict(id=row[0], email=row[1], name=row[2], role=row[3])

    def authenticate(self, body, register=False):
        self.throttle()
        email, password = body.get('email'), body.get('password')
        if not isinstance(email, str) or not isinstance(password, str):
            raise AccountError(400, 'Nhập email và mật khẩu.')
        email = email.strip().casefold()
        if len(email) > 254 or not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', email):
            raise AccountError(400, 'Email không hợp lệ.')
        if not 8 <= len(password) <= 128:
            raise AccountError(400, 'Mật khẩu cần từ 8 đến 128 ký tự.')
        with self.lock, self.database() as db:
            if register:
                name, role = body.get('name'), body.get('role')
                if not isinstance(name, str) or not 1 <= len(name.strip()) <= 80:
                    raise AccountError(400, 'Họ và tên cần từ 1 đến 80 ký tự.')
                if not isinstance(role, str) or role not in ROLES:
                    raise AccountError(400, 'Chọn vai trò hợp lệ.')
                salt = secrets.token_hex(16)
                row = (secrets.token_hex(16), email, name.strip(), role, salt, self.hash_password(password, salt))
                try:
                    db.execute('INSERT INTO users VALUES (?, ?, ?, ?, ?, ?)', row)
                except sqlite3.IntegrityError:
                    raise AccountError(409, 'Email này đã được đăng ký. Hãy đăng nhập.') from None
            else:
                row = db.execute('SELECT * FROM users WHERE email = ?', (email,)).fetchone()
                # Same password work for unknown addresses to avoid timing disclosure.
                actual = self.hash_password(password, row[4] if row else '00' * 16)
                if row is None or not hmac.compare_digest(actual, row[5]):
                    raise AccountError(401, 'Email hoặc mật khẩu chưa đúng.')
            token = secrets.token_urlsafe(32)
            db.execute('DELETE FROM sessions WHERE expires <= ?', (time.time(),))
            db.execute('INSERT INTO sessions VALUES (?, ?, ?)', (self.digest(token), row[0], time.time() + SESSION_SECONDS))
            return dict(user=self.profile(row), session=token)

    def user(self, token):
        if not isinstance(token, str) or not re.fullmatch(r'[A-Za-z0-9_-]{43}', token):
            raise AccountError(403, 'Vui lòng đăng nhập để tiếp tục.')
        with self.database() as db:
            row = db.execute('SELECT users.* FROM users JOIN sessions ON users.id = sessions.user_id WHERE digest = ? AND expires > ?', (self.digest(token), time.time())).fetchone()
        if row is None:
            raise AccountError(403, 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.')
        return self.profile(row)

    def logout(self, token):
        self.user(token)
        with self.lock, self.database() as db:
            db.execute('DELETE FROM sessions WHERE digest = ?', (self.digest(token),))

    def store(self, user):
        with self.lock:
            if user['id'] not in self.stores:
                self.stores[user['id']] = self.store_factory(self.directory / 'users' / user['id'])
            return self.stores[user['id']]
