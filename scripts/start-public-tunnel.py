#!/usr/bin/env python3
"""Temporary native-app tunnel; refuse startup until local Bearer auth works."""
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import urllib.error
import urllib.request

ORIGIN = 'http://127.0.0.1:8787'


def status(path, headers=None):
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *args, **kwargs):
            return None

    request = urllib.request.Request(ORIGIN + path, headers=headers or {})
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect)
    try:
        with opener.open(request, timeout=5) as response:
            return response.status
    except urllib.error.HTTPError as error:
        error.close()
        return error.code


def preflight():
    # Do not read or print document data, even if the old relay is still running.
    for path in ('/api/health', '/api/state'):
        if status(path) != 401:
            raise RuntimeError('Backend chưa bắt buộc Bearer token (cần HTTP 401). Không mở tunnel.')
        if status(path, {'Authorization': 'Bearer invalid-tunnel-preflight'}) != 401:
            raise RuntimeError('Backend chưa từ chối token sai. Không mở tunnel.')
    auth_file = Path(os.environ.get('QUIZMIND_AUTH_FILE', str(Path.home() / '.config/quizmind/relay-token')))
    metadata = auth_file.lstat()
    if not stat.S_ISREG(metadata.st_mode) or stat.S_IMODE(metadata.st_mode) != 0o600:
        raise RuntimeError('Tệp token phải là regular file quyền 0600. Không mở tunnel.')
    token = auth_file.read_text().strip()
    if len(token) < 32 or any(character.isspace() for character in token):
        raise RuntimeError('Tệp token không hợp lệ. Không mở tunnel.')
    headers = {'Authorization': 'Bearer ' + token}
    if status('/api/health', headers) != 200:
        raise RuntimeError('Token hiện tại không được backend chấp nhận. Không mở tunnel.')
    if status('/api/health', dict(headers, Origin='https://example.invalid')) < 400:
        raise RuntimeError('Backend chưa từ chối browser Origin. Không mở tunnel.')


def main():
    try:
        preflight()
        binary = shutil.which('cloudflared')
        if not binary:
            candidate = Path.home() / '.local/bin/cloudflared'
            binary = str(candidate) if candidate.is_file() else None
        if not binary:
            raise RuntimeError('Chưa có cloudflared trên máy.')
        # Quick Tunnel must not inherit a named tunnel or Host rewrite config.
        for directory in (Path.home() / '.cloudflared', Path.home() / '.cloudflare-warp',
                          Path.home() / 'cloudflare-warp', Path('/etc/cloudflared'),
                          Path('/usr/local/etc/cloudflared')):
            if any((directory / name).exists() for name in ('config.yml', 'config.yaml')):
                raise RuntimeError('Có cấu hình Cloudflare riêng; cần đối chiếu trước khi mở Quick Tunnel.')
        environment = {key: value for key, value in os.environ.items()
                       if key in ('HOME', 'PATH', 'TMPDIR', 'LANG', 'LC_ALL', 'SSL_CERT_FILE', 'SSL_CERT_DIR')}
        print('Auth local đạt. Tunnel giữ nguyên Host; không dùng --http-host-header.', flush=True)
        print('Sau khi có URL, cấu hình exact hostname trong QUIZMIND_PUBLIC_HOSTS và khởi động lại backend.', flush=True)
        print('Giữ terminal mở; Ctrl+C dừng tunnel. URL đổi sau mỗi lần mở lại.', flush=True)
        return subprocess.call([binary, 'tunnel', '--no-autoupdate', '--url', ORIGIN,
                                '--loglevel', 'info'], env=environment)
    except RuntimeError as error:
        print(str(error), file=sys.stderr)
        return 1
    except (OSError, ValueError):
        # Do not include HTTP headers, response bodies, or credential file contents.
        print('Không mở tunnel: backend/auth hoặc cấu hình chưa đạt. Xem runbook và kiểm tra health local.', file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130


if __name__ == '__main__':
    sys.exit(main())
