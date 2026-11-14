import http.client
import json
import stat
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import app
from accounts import AccountError, Accounts


class AccountTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='quizmind-accounts-')
        self.accounts = Accounts(self.tmp.name, app.Store)

    def tearDown(self):
        self.tmp.cleanup()

    def register(self, **changes):
        body = dict(email='learner@example.test', password='Synthetic123!', name='Người học', role='student')
        body.update(changes)
        return self.accounts.authenticate(body, register=True)

    def test_roles_normalization_and_no_raw_credentials_on_disk(self):
        for role in ('user', 'teacher', 'student'):
            result = self.accounts.authenticate(dict(email=f' {role.upper()}@Example.Test ',
                password='Synthetic123!', name=' Người học ', role=role), register=True)
            self.assertEqual(result['user']['role'], role)
            self.assertEqual(result['user']['email'], f'{role}@example.test')
            self.assertEqual(result['user']['name'], 'Người học')
            self.assertEqual(set(result['user']), {'id', 'email', 'name', 'role'})
            self.assertEqual(self.accounts.user(result['session']), result['user'])
            raw = self.accounts.file.read_bytes()
            self.assertNotIn(b'Synthetic123!', raw)
            self.assertNotIn(result['session'].encode(), raw)
        self.assertEqual(stat.S_IMODE(self.accounts.file.stat().st_mode), 0o600)
        with self.accounts.database() as db:
            rows = db.execute('SELECT salt, password FROM users').fetchall()
        self.assertEqual(len({salt for salt, _ in rows}), 3)
        self.assertEqual(len({password for _, password in rows}), 3)

    def test_registration_validation_and_duplicate_leave_original_profile(self):
        original = self.register()
        invalid = [dict(email='bad'), dict(password='short'), dict(password='x' * 129),
                   dict(name=' '), dict(name='x' * 81), dict(role='admin'), dict(role=[])]
        for changes in invalid:
            body = dict(email='new@example.test', password='Synthetic123!', name='New', role='user')
            body.update(changes)
            with self.subTest(changes=changes), self.assertRaises(AccountError) as error:
                self.accounts.authenticate(body, register=True)
            self.assertEqual(error.exception.status, 400)
        with self.assertRaises(AccountError) as error:
            self.register()
        self.assertEqual(error.exception.status, 409)
        self.assertEqual(self.accounts.user(original['session']), original['user'])
        with self.accounts.database() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM users').fetchone()[0], 1)

    def test_login_session_persistence_logout_and_expiry(self):
        original = self.register()
        login = self.accounts.authenticate(dict(email='LEARNER@example.test', password='Synthetic123!'))
        self.assertNotEqual(login['session'], original['session'])
        reopened = Accounts(self.tmp.name, app.Store)
        self.assertEqual(reopened.user(login['session']), original['user'])
        reopened.logout(login['session'])
        with self.assertRaises(AccountError):
            self.accounts.user(login['session'])
        self.assertEqual(self.accounts.user(original['session']), original['user'])
        with self.accounts.database() as db:
            db.execute('UPDATE sessions SET expires = ?', (time.time() - 1,))
        with self.assertRaises(AccountError) as error:
            self.accounts.user(original['session'])
        self.assertEqual(error.exception.status, 403)

    def test_wrong_password_and_unknown_email_have_same_error(self):
        self.register()
        messages = []
        for email in ('learner@example.test', 'unknown@example.test'):
            with self.assertRaises(AccountError) as error:
                self.accounts.authenticate(dict(email=email, password='Incorrect123!'))
            self.assertEqual(error.exception.status, 401)
            messages.append(str(error.exception))
        self.assertEqual(messages[0], messages[1])
        for token in (None, '', 'invalid', 'A' * 43):
            with self.subTest(token=token), self.assertRaises(AccountError) as error:
                self.accounts.user(token)
            self.assertEqual(error.exception.status, 403)

    def test_throttle_bounds_password_work_and_recovers(self):
        with patch('accounts.time.monotonic', return_value=100):
            for _ in range(12):
                self.accounts.throttle()
            with self.assertRaises(AccountError) as error:
                self.accounts.authenticate(dict(email='new@example.test', password='Synthetic123!'))
            self.assertEqual(error.exception.status, 429)
        with patch('accounts.time.monotonic', return_value=161):
            self.accounts.throttle()


class AccountHTTPTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='quizmind-account-http-')
        self.legacy = app.Store(self.tmp.name)
        self.legacy.state['documents'] = [dict(id='legacy-doc', name='Legacy', pages=['Private old library'])]
        self.legacy.save()
        self.legacy_bytes = self.legacy.file.read_bytes()
        self.accounts = Accounts(self.tmp.name, app.Store)
        self.executor = Mock()
        self.relay = 'A' * 43
        self.server = app.LimitedServer(('127.0.0.1', 0),
            app.make_handler(self.legacy, self.executor, self.relay, accounts=self.accounts))
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.tmp.cleanup()

    def request(self, path, body=None, session=None, relay=True):
        headers = {'Host': '127.0.0.1:8787', 'Content-Type': 'application/json'}
        if relay:
            headers['Authorization'] = 'Bearer ' + self.relay
        if session:
            headers['X-QuizMind-Session'] = session
        connection = http.client.HTTPConnection(*self.server.server_address, timeout=5)
        connection.request('GET' if body is None else 'POST', path,
                           body=None if body is None else json.dumps(body), headers=headers)
        response = connection.getresponse()
        result = response.status, json.loads(response.read())
        connection.close()
        return result

    def register(self, email, role='user'):
        status, result = self.request('/api/auth/register', dict(email=email, name='Test User',
            password='Synthetic123!', role=role))
        self.assertEqual(status, 200)
        return result

    def test_account_endpoints_and_data_routes_require_both_credentials(self):
        self.assertEqual(self.request('/api/auth/register', {}, relay=False)[0], 401)
        self.assertEqual(self.request('/api/auth/register', [])[0], 400)
        result = self.register('user@example.test')
        token = result['session']
        self.assertEqual(self.request('/api/auth/me', session=token), (200, dict(user=result['user'])))
        for path in ('/api/auth/me', '/api/state'):
            self.assertEqual(self.request(path)[0], 403)
            self.assertEqual(self.request(path, session=token, relay=False)[0], 401)
        for path in ('import', 'generate', 'update', 'chat', 'research', 'attempts', 'rename',
                     'trash', 'tags/create', 'tags/rename', 'tags/delete', 'tags/assign'):
            self.assertEqual(self.request('/api/' + path, {})[0], 403, path)
        self.executor.submit.assert_not_called()
        self.assertEqual(self.request('/api/auth/logout', {}, session=token), (200, dict(ok=True)))
        self.assertEqual(self.request('/api/state', session=token)[0], 403)

    def test_data_and_mutations_isolated_even_with_guessed_object_ids(self):
        alice = self.register('alice@example.test', 'teacher')
        bob = self.register('bob@example.test', 'student')
        alice_store = self.accounts.store(alice['user'])
        alice_store.state['documents'] = [dict(id='alice-doc', name='Alice document', pages=['Alice source'])]
        alice_store.state['quizzes'] = [dict(id='alice-quiz', documentId='alice-doc',
            questions=[dict(question='Synthetic?', correct=0)])]
        alice_store.save()
        self.assertEqual(self.request('/api/state', session=bob['session'])[1]['documents'], [])
        self.assertEqual(self.request('/api/state', session=alice['session'])[1]['documents'][0]['id'], 'alice-doc')
        attempts = [('/api/rename', dict(documentId='alice-doc', name='Changed')),
                    ('/api/trash', dict(documentId='alice-doc')),
                    ('/api/generate', dict(requestId='cross-user-request', documentId='alice-doc', name='Changed', count=5)),
                    ('/api/update', dict(requestId='cross-user-update', documentId='alice-doc', name='Changed')),
                    ('/api/research', dict(quizId='alice-quiz', questionIndex=0)),
                    ('/api/attempts', dict(id='cross-user-attempt', quizId='alice-quiz', answers=[0])),
                    ('/api/tags/assign', dict(quizId='alice-quiz', tagIds=[]))]
        with patch.object(app, 'research_question') as research:
            for path, body in attempts:
                self.assertEqual(self.request(path, body, session=bob['session'])[0], 400, path)
            research.assert_not_called()
        self.executor.submit.assert_not_called()
        self.assertEqual(alice_store.state['documents'][0]['name'], 'Alice document')
        self.assertFalse(alice_store.state['documents'][0].get('deleted', False))
        self.assertEqual(self.legacy.file.read_bytes(), self.legacy_bytes)
        self.assertNotIn('legacy-doc', json.dumps(self.request('/api/state', session=alice['session'])[1]))
        self.assertEqual(self.request('/api/tags/create', dict(name='Only Alice'), session=alice['session'])[0], 200)
        self.assertEqual(self.request('/api/state', session=bob['session'])[1]['tags'], [])


if __name__ == '__main__':
    unittest.main()
