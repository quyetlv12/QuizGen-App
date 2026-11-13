"""Check launcher routing without building or touching connected devices."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class LauncherTests(unittest.TestCase):
    def run_launcher(self, name):
        with tempfile.TemporaryDirectory() as folder:
            temp = Path(folder)
            (temp / 'scripts').mkdir()
            (temp / '.config/quizmind').mkdir(parents=True)
            (temp / '.config/quizmind/phone-url').write_text('https://example.invalid\n')
            (temp / name).write_text((ROOT / name).read_text())
            (temp / name).chmod(0o755)
            (temp / 'scripts/flutter-env.sh').write_text((ROOT / 'scripts/flutter-env.sh').read_text())
            binary = temp / 'bin'
            binary.mkdir()
            mocks = {
                'curl': '#!/bin/sh\nprintf 401',
                'open': '#!/bin/sh\nexit 0',
                'xcode-select': '#!/bin/sh\necho /Applications/Xcode.app/Contents/Developer',
                'xcrun': '''#!/bin/sh
if [ "$1" = devicectl ]; then echo "DEVICE $*"; fi
if [ "$3" = devices ]; then
 if [ "$4" = booted ]; then echo 'sim-1'; else
 echo '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-27-0":[{"udid":"sim-1","name":"iPhone 17","isAvailable":true,"state":"Booted"}]}}'
 fi
fi
''',
                'flutter': '''#!/bin/sh
echo '[{"id":"sim-1","emulator":true,"targetPlatform":"ios","isSupported":true},{"id":"phone-1","emulator":false,"targetPlatform":"ios","isSupported":true}]'
''',
                'python3': f'''#!{sys.executable}
import os, sys
if sys.argv[1].endswith('flutter-local.py'):
 print('LAUNCH ' + ' '.join(sys.argv[2:]))
elif sys.argv[1] == '-' and sys.argv[2].endswith('phone-url'):
 sys.exit(0)
else:
 os.execv({sys.executable!r}, [{sys.executable!r}, *sys.argv[1:]])
''',
            }
            for command, content in mocks.items():
                path = binary / command
                path.write_text(content)
                path.chmod(0o755)
            env = dict(os.environ, PATH=str(binary) + ':' + os.environ['PATH'], HOME=str(temp))
            result = subprocess.run([str(temp / name)], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((temp / name).is_file())
            self.assertIn('"build-dir": ".flutter-build"', (temp / '.local/flutter-config/settings').read_text())
            return result.stdout

    def test_dev_selects_simulator(self):
        self.assertIn('LAUNCH run -d sim-1', self.run_launcher('dev'))

    def test_build_selects_physical_phone_and_release(self):
        output = self.run_launcher('build')
        self.assertIn('LAUNCH --phone build ios --release', output)
        self.assertIn('DEVICE devicectl device install app --device phone-1', output)
        self.assertIn('DEVICE devicectl device process launch --device phone-1 dev.quyet.quizmind', output)


if __name__ == '__main__':
    unittest.main()
