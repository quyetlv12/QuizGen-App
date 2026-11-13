import contextlib
import importlib.util
import io
import json
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('flutter_local', Path(__file__).with_name('flutter-local.py'))
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class ProvisionTests(unittest.TestCase):
    def test_automatically_creates_reuses_and_cleans_private_configuration(self):
        with tempfile.TemporaryDirectory() as folder:
            auth = Path(folder) / 'token'
            configs = []
            tokens = []

            def run(command, cwd):
                self.assertEqual(command[:4], ['flutter', 'run', '-d', 'simulator'])
                self.assertEqual(cwd, launcher.ROOT)
                config = Path(command[-1].split('=', 1)[1])
                configs.append(config)
                self.assertEqual(stat.S_IMODE(config.stat().st_mode), 0o600)
                self.assertEqual(stat.S_IMODE(config.parent.stat().st_mode), 0o700)
                data = json.loads(config.read_text())
                self.assertEqual(data['QUIZMIND_RELAY_URL'], 'http://127.0.0.1:8787')
                tokens.append(data['QUIZMIND_RELAY_TOKEN'])
                self.assertNotIn(tokens[-1], ' '.join(command))
                return 0

            output = io.StringIO()
            with patch.dict(launcher.os.environ, {'QUIZMIND_AUTH_FILE': str(auth)}), \
                    patch.object(launcher.subprocess, 'call', side_effect=run), \
                    contextlib.redirect_stdout(output):
                for _ in range(2):
                    self.assertEqual(launcher.main(['run', '-d', 'simulator']), 0)
            self.assertEqual(tokens[0], tokens[1])
            self.assertNotIn(tokens[0], output.getvalue())
            self.assertTrue(all(not config.exists() for config in configs))

    def test_phone_build_embeds_saved_https(self):
        with tempfile.TemporaryDirectory() as folder:
            config_dir = Path(folder) / '.config/quizmind'
            config_dir.mkdir(parents=True)
            (config_dir / 'phone-url').write_text('https://quiz.example.com\n')
            def run(command, cwd):
                data = json.loads(Path(command[-1].split('=', 1)[1]).read_text())
                self.assertEqual(data['QUIZMIND_RELAY_URL'], 'https://quiz.example.com')
                self.assertEqual(data['QUIZMIND_RELAY_TOKEN'], 'synthetic-token')
                return 0
            with patch.object(launcher.Path, 'home', return_value=Path(folder)), \
                    patch.object(launcher, 'load_auth_token', return_value='synthetic-token'), \
                    patch.object(launcher.subprocess, 'call', side_effect=run):
                self.assertEqual(launcher.main(['--phone', 'build', 'ios']), 0)

    def test_unsafe_credentials_do_not_launch_flutter(self):
        with patch.object(launcher, 'load_auth_token', side_effect=launcher.AppError('private detail')), \
                patch.object(launcher.subprocess, 'call') as run, \
                contextlib.redirect_stderr(io.StringIO()) as output:
            self.assertEqual(launcher.main(['build', 'ios']), 1)
            run.assert_not_called()
            self.assertNotIn('private detail', output.getvalue())

    def test_cannot_override_managed_credentials(self):
        with patch.object(launcher, 'load_auth_token') as load, \
                contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(launcher.main(['run', '--dart-define=QUIZMIND_RELAY_TOKEN=other']), 2)
            load.assert_not_called()


if __name__ == '__main__':
    unittest.main()
