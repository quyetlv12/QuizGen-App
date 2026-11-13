import copy
import http.client
import json
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch
import app


class DocumentActionsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.store = app.Store(self.tmp.name)
        self.store.state['documents'] = [dict(id='one', name='Tên cũ', pages=['source']), dict(id='two', name='Giữ lại', pages=['source'])]
        self.store.state['quizzes'] = [dict(id='quiz', documentId='one', title='Lịch sử')]
        self.store.state['attempts'] = [dict(id='attempt', quizId='quiz')]
        self.store.save()
        self.server = app.LimitedServer(('127.0.0.1', 0), app.make_handler(self.store, None, 'A' * 43))
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.tmp.cleanup()

    def post(self, route, body, token='A' * 43):
        c = http.client.HTTPConnection(*self.server.server_address, timeout=2)
        c.request('POST', '/api/' + route, json.dumps(body), {'Host': '127.0.0.1:8787', 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token})
        r = c.getresponse()
        result = r.status, json.loads(r.read())
        c.close()
        return result

    def test_rename_trim_persistence_and_historical_titles(self):
        self.assertEqual(self.post('rename', dict(documentId='one', name='  Tên mới 😀  '))[0], 200)
        restored = app.Store(self.tmp.name)
        self.assertEqual(restored.document('one')['name'], 'Tên mới 😀')
        self.assertEqual(restored.document('two')['name'], 'Giữ lại')
        self.assertEqual(restored.state['quizzes'][0]['title'], 'Lịch sử')

    def test_invalid_auth_name_id_and_active_job_preserve_data(self):
        before = copy.deepcopy(self.store.state)
        disk = self.store.file.read_bytes()
        for name in ('', '  ', None, 42, '😀' * 161):
            self.assertEqual(self.post('rename', dict(documentId='one', name=name))[0], 400)
        self.assertEqual(self.post('rename', dict(documentId='missing', name='New'))[0], 400)
        self.assertEqual(self.post('rename', dict(documentId='one', name='New'), token='B' * 43)[0], 401)
        self.assertEqual(self.store.state, before)
        self.assertEqual(self.store.file.read_bytes(), disk)
        self.store.state['jobs'] = [dict(id='busy', documentId='one', stage='generating')]
        self.store.save()
        for route in ('rename', 'trash'):
            self.assertEqual(self.post(route, dict(documentId='one', name='New'))[0], 400)
        self.assertEqual(self.store.document('one')['name'], 'Tên cũ')

    def test_rename_and_delete_disk_failure_roll_back(self):
        before = copy.deepcopy(self.store.state)
        disk = self.store.file.read_bytes()
        with patch.object(app.os, 'replace', side_effect=OSError('disk full')):
            for route in ('rename', 'trash'):
                self.assertEqual(self.post(route, dict(documentId='one', name='New'))[0], 500)
                self.assertEqual(self.store.state, before)
                self.assertEqual(self.store.file.read_bytes(), disk)

    def test_delete_persists_soft_hide_and_rejects_rename_deleted(self):
        self.assertEqual(self.post('trash', dict(documentId='one'))[0], 200)
        restored = app.Store(self.tmp.name)
        self.assertEqual([d['id'] for d in restored.snapshot()['documents']], ['two'])
        self.assertEqual(restored.snapshot()['quizzes'], [])
        self.assertEqual(restored.snapshot()['attempts'], [])
        self.assertEqual(len(restored.state['documents']), 2)
        self.assertEqual(self.post('rename', dict(documentId='one', name='New'))[0], 400)


if __name__ == '__main__':
    unittest.main()
