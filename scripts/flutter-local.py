#!/usr/bin/env python3
"""Provision this Mac's local or --phone tunnel relay into a personal Flutter build."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'server'))
from app import AppError, load_auth_token


def main(args=None):
    args = sys.argv[1:] if args is None else args
    phone = bool(args and args[0] == '--phone')
    if phone:
        args = args[1:]
    if not args or args[0] not in ('run', 'build'):
        print('Dùng: python3 scripts/flutter-local.py [--phone] run -d <device-id> hoặc build <platform>.', file=sys.stderr)
        return 2
    if any(arg.startswith(('--dart-define', '--flavor')) for arg in args):
        print('Lệnh local tự quản lý cấu hình relay; không truyền thêm defines/flavor.', file=sys.stderr)
        return 2
    try:
        token = load_auth_token()
        relay = 'http://127.0.0.1:8787'
        if phone:
            relay = (Path.home() / '.config/quizmind/phone-url').read_text().strip()
            parsed = urlsplit(relay)
            if (parsed.scheme != 'https' or not parsed.hostname or parsed.username
                    or parsed.password or parsed.port not in (None, 443)
                    or parsed.path or parsed.query or parsed.fragment):
                raise AppError('Địa chỉ tunnel không hợp lệ.')
        with tempfile.TemporaryDirectory(prefix='quizmind-build-') as folder:
            config = Path(folder) / 'relay.json'
            fd = os.open(config, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, 'w') as stream:
                json.dump({'QUIZMIND_RELAY_URL': relay,
                           'QUIZMIND_RELAY_TOKEN': token}, stream)
            print('Đã tự cấu hình địa chỉ và token relay cho app.', flush=True)
            lock_path = ROOT / '.local/flutter.lock'
            lock_path.parent.mkdir(exist_ok=True)
            with lock_path.open('a') as lock:
                try:
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError:
                    print('Một lệnh Flutter khác đang chạy. Dừng ./dev trước nếu muốn build máy thật.', flush=True)
                    fcntl.flock(lock, fcntl.LOCK_EX)
                return subprocess.call(['flutter', *args, f'--dart-define-from-file={config}'], cwd=ROOT)
    except (AppError, OSError, ValueError):
        print('Không cấu hình được relay local. Kiểm tra Flutter, token (0600); với --phone cần chạy scripts/start-phone.py trước.', file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130


if __name__ == '__main__':
    sys.exit(main())
