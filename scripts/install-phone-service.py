#!/usr/bin/env python3
"""Install the fixed phone relay as a per-user macOS launch agent."""
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
LABEL = 'dev.quyet.quizmind.phone'


def main():
    config = Path.home() / '.config/quizmind'
    if not (config / 'tunnel.json').is_file():
        raise SystemExit('Cần cấu hình tunnel.json cố định trước khi cài dịch vụ.')
    agent = Path.home() / 'Library/LaunchAgents' / (LABEL + '.plist')
    agent.parent.mkdir(parents=True, exist_ok=True)
    domain = 'gui/' + str(os.getuid())
    subprocess.run(['launchctl', 'bootout', domain + '/' + LABEL],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # launchd cannot read Documents without extra macOS privacy permissions.
    # Copy only runtime code; account data and credentials keep their existing paths.
    runtime = config / 'phone-runtime'
    for relative in ('scripts/start-phone.py', 'scripts/start-public-tunnel.py',
                     'scripts/start-server.sh', 'server/app.py', 'server/accounts.py',
                     'server/extract.swift', 'server/bin/extract'):
        source = ROOT / relative
        target = runtime / relative
        target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        shutil.copy2(source, target)
    for name in ('phone-service.out.log', 'phone-service.err.log'):
        fd = os.open(config / name, os.O_WRONLY | os.O_CREAT | os.O_APPEND | os.O_NOFOLLOW, 0o600)
        os.fchmod(fd, 0o600)
        os.close(fd)
    settings = {
        'Label': LABEL,
        'ProgramArguments': ['/usr/bin/caffeinate', '-i', sys.executable,
                             str(runtime / 'scripts/start-phone.py')],
        'WorkingDirectory': str(runtime),
        'EnvironmentVariables': {
            'HOME': str(Path.home()),
            'PATH': '/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin',
            'PYTHONUNBUFFERED': '1',
        },
        'RunAtLoad': True,
        'KeepAlive': True,
        'ThrottleInterval': 15,
        'ExitTimeOut': 30,
        'StandardOutPath': str(config / 'phone-service.out.log'),
        'StandardErrorPath': str(config / 'phone-service.err.log'),
    }
    agent.write_bytes(plistlib.dumps(settings))
    agent.chmod(0o600)
    subprocess.run(['launchctl', 'bootstrap', domain, str(agent)], check=True)
    print('Đã cài dịch vụ backend/tunnel tự khởi động và tự phục hồi khi lỗi.')


if __name__ == '__main__':
    main()
