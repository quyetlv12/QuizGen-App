#!/usr/bin/env python3
"""Own the relay and its tunnel together; keep credentials and logs private."""
import argparse
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import re
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('public_tunnel', ROOT / 'scripts/start-public-tunnel.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
sys.path.insert(0, str(ROOT / 'server'))
from app import load_auth_token, AppError, normalized_host

CONFIG = Path.home() / '.config/quizmind'


def fixed_settings(path):
    if not path.exists():
        return None
    data = json.loads(path.read_text())
    host = data.get('hostname', '')
    if normalized_host(host) != (host, None) or host in ('localhost', '127.0.0.1'):
        raise RuntimeError('Hostname tunnel cố định không hợp lệ.')
    provider = data.get('provider', 'cloudflare')
    if provider == 'ngrok':
        return {'provider': 'ngrok', 'hostname': host}
    if provider != 'cloudflare':
        raise RuntimeError('Chỉ hỗ trợ provider cloudflare hoặc ngrok.')
    tunnel = data.get('tunnel', '')
    if not re.fullmatch(r'[a-fA-F0-9]{8}(?:-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}', tunnel):
        raise RuntimeError('Tunnel phải là UUID của Cloudflare Tunnel.')
    credentials = Path(data.get('credentials_file', '')).expanduser()
    if not credentials.is_file():
        raise RuntimeError('Chưa có tệp credentials của named tunnel.')
    return dict(tunnel=tunnel, **{'credentials-file': str(credentials.resolve())},
                ingress=[{'hostname': host, 'service': gate.ORIGIN}, {'service': 'http_status:404'}])


def stop(process):
    if process is not None and process.poll() is None:
        try:
            os.killpg(process.pid, signal.SIGINT)
        except ProcessLookupError:
            return
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()


def wait_for(check, children, seconds=60):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if any(child.poll() is not None for child in children):
            raise RuntimeError('Backend hoặc tunnel đã dừng. Xem log riêng trong ~/.config/quizmind/phone.log.')
        try:
            value = check()
            if value:
                return value
        except (OSError, urllib.error.URLError):
            pass
        time.sleep(0.5)
    raise RuntimeError('Chờ kết nối quá hạn. Kiểm tra mạng và log phone.log.')


def remote_ready(url, token):
    # Never forward Bearer credentials through redirects.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *args, **kwargs):
            return None
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect)
    def code(headers):
        try:
            with opener.open(urllib.request.Request(url + '/api/health', headers=headers), timeout=5) as response:
                return response.status
        except urllib.error.HTTPError as error:
            error.close()
            return error.code
    return code({}) == 401 and code({'Authorization': 'Bearer ' + token}) == 200


def supervise(url, token, children, interval=30, failure_limit=3):
    failures = 0
    next_check = time.monotonic() + interval
    while True:
        if any(child.poll() is not None for child in children):
            raise RuntimeError('Backend hoặc tunnel đã dừng; cần khởi động lại dịch vụ.')
        if time.monotonic() >= next_check:
            try:
                healthy = remote_ready(url, token)
            except (OSError, urllib.error.URLError):
                healthy = False
            failures = 0 if healthy else failures + 1
            if failures >= failure_limit:
                raise RuntimeError('HTTPS lỗi liên tiếp; khởi động lại backend/tunnel để khôi phục.')
            next_check = time.monotonic() + interval
        time.sleep(1)


def main(args=None):
    parser = argparse.ArgumentParser(description='Bật backend và tunnel với URL cố định.')
    parser.add_argument('--temporary', action='store_true', help='Cho phép tunnel tạm đổi URL khi chưa có tunnel.json.')
    options = parser.parse_args(args)
    backend = tunnel = None
    url_file = CONFIG / 'phone-url'
    published = False
    try:
        token = load_auth_token()
        fixed = fixed_settings(CONFIG / 'tunnel.json')
        if not fixed and not options.temporary:
            raise RuntimeError('Chưa có URL cố định. Cấu hình ~/.config/quizmind/tunnel.json theo README trước. Chỉ dùng --temporary nếu chấp nhận URL thay đổi.')
        ngrok = bool(fixed and fixed.get('provider') == 'ngrok')
        program = 'ngrok' if ngrok else 'cloudflared'
        binary = gate.shutil.which(program) or str(Path.home() / '.local/bin' / program)
        if not Path(binary).is_file():
            raise RuntimeError('Chưa cài ' + program + '.')
        lock = (CONFIG / 'phone.lock').open('w')
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('Lệnh bật backend/tunnel đang chạy ở terminal khác.') from None
        with socket.socket() as probe:
            if probe.connect_ex(('127.0.0.1', 8787)) == 0:
                raise RuntimeError('Cổng 8787 đang được dùng. Dừng backend cũ trước; không tự dừng tiến trình khác.')
        url_file.unlink(missing_ok=True)
        environment = {key: value for key, value in os.environ.items() if not key.startswith('TUNNEL_')}
        environment.pop('QUIZMIND_PUBLIC_HOSTS', None)
        log_fd = os.open(CONFIG / 'phone.log', os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
        os.fchmod(log_fd, 0o600)
        with os.fdopen(log_fd, 'w+') as log, tempfile.TemporaryDirectory(prefix='quizmind-tunnel-') as folder:
            def start_backend(host=None):
                env = dict(environment)
                if host:
                    env['QUIZMIND_PUBLIC_HOSTS'] = host
                process = subprocess.Popen([str(ROOT / 'scripts/start-server.sh')], cwd=ROOT,
                                           env=env, stdout=log, stderr=log, start_new_session=True)
                return process
            print('Đang bật backend và kiểm tra xác thực…', flush=True)
            host = (fixed['hostname'] if ngrok else fixed['ingress'][0]['hostname']) if fixed else None
            backend = start_backend(host)
            wait_for(lambda: gate.status('/api/health') == 401, [backend])
            gate.preflight()
            if ngrok:
                url = 'https://' + host
                command = [binary, 'http', gate.ORIGIN, '--url', url,
                           '--inspect=false', '--log=stdout', '--log-level=info']
            elif fixed:
                config = Path(folder) / 'config.yml'
                config.write_text(json.dumps(fixed))  # JSON is valid YAML; no credential contents copied.
                config.chmod(0o600)
                command = [binary, 'tunnel', '--config', str(config), '--no-autoupdate', 'run', fixed['tunnel']]
                url = 'https://' + host
            else:
                for directory in (Path.home() / '.cloudflared', Path.home() / '.cloudflare-warp', Path.home() / 'cloudflare-warp', Path('/etc/cloudflared'), Path('/usr/local/etc/cloudflared')):
                    if any((directory / name).exists() for name in ('config.yml', 'config.yaml')):
                        raise RuntimeError('Có cấu hình Cloudflare riêng. Cấu hình tunnel.json để dùng named tunnel.')
                command = [binary, 'tunnel', '--no-autoupdate', '--url', gate.ORIGIN, '--loglevel', 'info']
            tunnel = subprocess.Popen(command, env=environment, stdout=log, stderr=log, start_new_session=True)
            if not fixed:
                def discover():
                    log.flush()
                    content = (CONFIG / 'phone.log').read_text()
                    match = re.search(r'https://[a-z0-9]+(?:-[a-z0-9]+)*\.trycloudflare\.com\b', content)
                    return match.group() if match else None
                url = wait_for(discover, [backend, tunnel])
                stop(backend)
                backend = start_backend(url.removeprefix('https://'))
                wait_for(lambda: gate.status('/api/health') == 401, [backend, tunnel])
                gate.preflight()
            print('Đang kiểm tra HTTPS từ bên ngoài…', flush=True)
            wait_for(lambda: remote_ready(url, token), [backend, tunnel], seconds=90)
            fd = os.open(url_file, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
            with os.fdopen(fd, 'w') as stream:
                stream.write(url + '\n')
            published = True
            print('Backend + tunnel sẵn sàng. Địa chỉ lưu riêng tại ~/.config/quizmind/phone-url.', flush=True)
            if not fixed:
                print('Tunnel tạm: địa chỉ đổi sau mỗi lần chạy; cần cài lại cấu hình app khi đổi.', flush=True)
            print('Cài app: python3 scripts/flutter-local.py --phone run -d <device-id>', flush=True)
            print('Giữ terminal mở và Mac thức. Ctrl+C dừng cả backend lẫn tunnel.', flush=True)
            supervise(url, token, [backend, tunnel])
    except KeyboardInterrupt:
        return 0
    except (RuntimeError, AppError) as error:
        print(str(error), file=sys.stderr)
        return 1
    except (OSError, ValueError, KeyError, TypeError):
        print('Không bật được dịch vụ. Kiểm tra cấu hình và log riêng phone.log.', file=sys.stderr)
        return 1
    finally:
        stop(tunnel)
        stop(backend)
        if published:
            url_file.unlink(missing_ok=True)


def interrupted(*_):
    raise KeyboardInterrupt


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, interrupted)
    sys.exit(main())
