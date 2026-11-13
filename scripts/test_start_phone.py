import importlib.util
import json
import io
import contextlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch, Mock

spec = importlib.util.spec_from_file_location('phone', Path(__file__).with_name('start-phone.py'))
phone = importlib.util.module_from_spec(spec)
spec.loader.exec_module(phone)


class PhoneTests(unittest.TestCase):
    def test_named_tunnel_only_routes_exact_host_and_loopback(self):
        with tempfile.TemporaryDirectory() as folder:
            config = Path(folder) / 'tunnel.json'
            credentials = Path(folder) / 'credentials.json'
            credentials.touch()
            data = dict(hostname='quiz.example.com', tunnel='12345678-1234-1234-1234-123456789abc', credentials_file=str(credentials))
            config.write_text(json.dumps(data))
            result = phone.fixed_settings(config)
            self.assertEqual(result['ingress'], [{'hostname': 'quiz.example.com', 'service': 'http://127.0.0.1:8787'}, {'service': 'http_status:404'}])
            for hostname in ('https://quiz.example.com', 'quiz.example.com/path', 'localhost', 'quiz.example.com:443'):
                data['hostname'] = hostname
                config.write_text(json.dumps(data))
                with self.assertRaises(RuntimeError):
                    phone.fixed_settings(config)

    def test_ngrok_requires_fixed_hostname_without_cloudflare_credentials(self):
        with tempfile.TemporaryDirectory() as folder:
            config = Path(folder) / 'tunnel.json'
            config.write_text(json.dumps({'provider': 'ngrok', 'hostname': 'assigned.ngrok-free.dev'}))
            self.assertEqual(phone.fixed_settings(config), {'provider': 'ngrok', 'hostname': 'assigned.ngrok-free.dev'})
            config.write_text(json.dumps({'provider': 'unknown', 'hostname': 'example.com'}))
            with self.assertRaises(RuntimeError):
                phone.fixed_settings(config)

    def test_missing_fixed_url_does_not_start_random_tunnel(self):
        with patch.object(phone, 'load_auth_token', return_value='synthetic'), \
                patch.object(phone, 'fixed_settings', return_value=None), \
                patch.object(phone.subprocess, 'Popen') as launch, \
                contextlib.redirect_stderr(io.StringIO()) as output:
            self.assertEqual(phone.main([]), 1)
            launch.assert_not_called()
            self.assertIn('Chưa có URL cố định', output.getvalue())

    def test_health_requires_both_auth_rejection_and_acceptance(self):
        opener = Mock()
        rejected = phone.urllib.error.HTTPError('https://example.invalid', 401, '', {}, io.BytesIO())
        response = Mock()
        response.__enter__ = Mock(return_value=Mock(status=200))
        response.__exit__ = Mock(return_value=False)
        opener.open.side_effect = [rejected, response]
        with patch.object(phone.urllib.request, 'build_opener', return_value=opener):
            self.assertTrue(phone.remote_ready('https://example.invalid', 'synthetic'))
        self.assertNotIn('Authorization', opener.open.call_args_list[0].args[0].headers)
        self.assertEqual(opener.open.call_args_list[1].args[0].headers['Authorization'], 'Bearer synthetic')

    def test_dead_child_fails_without_waiting(self):
        with self.assertRaises(RuntimeError):
            phone.wait_for(lambda: True, [Mock(poll=Mock(return_value=1))])

    def test_redirect_never_forwards_credentials(self):
        response = Mock(status=302)
        response.__enter__ = Mock(return_value=response)
        response.__exit__ = Mock(return_value=False)
        with patch.object(phone.urllib.request, 'build_opener') as build:
            build.return_value.open.return_value = response
            self.assertFalse(phone.remote_ready('https://example.invalid', 'synthetic'))
            handler = build.call_args.args[1]
            self.assertIsNone(handler.redirect_request(None, None, None, None, None))


if __name__ == '__main__':
    unittest.main()
