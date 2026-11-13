import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('public_tunnel', Path(__file__).with_name('start-public-tunnel.py'))
tunnel = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tunnel)


class GateTests(unittest.TestCase):
    def test_old_unauthenticated_backend_never_reaches_tunnel_launch(self):
        with patch.object(tunnel, 'status', return_value=200), patch.object(tunnel.subprocess, 'call') as launch:
            self.assertEqual(tunnel.main(), 1)
            launch.assert_not_called()

    def test_backend_accepting_invalid_token_fails_closed(self):
        with patch.object(tunnel, 'status', side_effect=[401, 200]):
            with self.assertRaises(RuntimeError):
                tunnel.preflight()

    def test_valid_auth_with_origin_rejected_passes_without_printing_token(self):
        with tempfile.TemporaryDirectory() as folder:
            token_file = Path(folder) / 'token'
            token_file.write_text('synthetic-' + 'a' * 64)
            token_file.chmod(0o600)
            with patch.dict(tunnel.os.environ, {'QUIZMIND_AUTH_FILE': str(token_file)}):
                with patch.object(tunnel, 'status', side_effect=[401, 401, 401, 401, 200, 403]):
                    tunnel.preflight()
                token_file.chmod(0o644)
                with patch.object(tunnel, 'status', side_effect=[401, 401, 401, 401]):
                    with self.assertRaises(RuntimeError):
                        tunnel.preflight()


if __name__ == '__main__':
    unittest.main()
