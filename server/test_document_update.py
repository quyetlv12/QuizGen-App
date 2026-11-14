import base64
import copy
import json
import tempfile
import unittest
from unittest.mock import patch

import app
from test_app import SOURCE, question
import test_document_actions


class DocumentUpdateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.store = app.Store(self.tmp.name)
        self.original = dict(id='one', name='Original', pages=['Original source'], createdAt=1)
        self.store.state['documents'] = [copy.deepcopy(self.original)]
        self.store.state['quizzes'] = [dict(id='old-quiz', documentId='one', title='Old quiz')]
        self.store.state['attempts'] = [dict(id='old-attempt', quizId='old-quiz')]
        self.store.save()
        self.body = dict(requestId='update-001', documentId='one', name='Updated', files=[dict(name='new.txt', data=base64.b64encode(SOURCE.encode()).decode())])

    def update(self):
        job, fresh = self.store.new_job(self.body, 'update')
        self.assertTrue(fresh)
        self.store.process(job, self.body)
        return self.store.current_job(job)

    def test_update_preserves_identity_history_and_persists_new_source(self):
        self.assertEqual(self.update()['stage'], 'ready')
        restored = app.Store(self.tmp.name)
        self.assertEqual(len(restored.state['documents']), 1)
        doc = restored.document('one')
        self.assertEqual((doc['pages'], doc['name'], doc['createdAt']), ([SOURCE], 'Updated', 1))
        self.assertIn('updatedAt', doc)
        self.assertEqual(restored.state['quizzes'][0]['title'], 'Old quiz')
        self.assertEqual(restored.state['attempts'][0]['id'], 'old-attempt')
        self.assertFalse(self.store.new_job(self.body, 'update')[1])
        with self.assertRaises(app.AppError):
            self.store.new_job(dict(self.body, documentId='other'), 'update')

    def test_invalid_files_keep_original(self):
        for files in ([], [dict(name='bad.txt', data='!!!')], [dict(name='short.txt', data='YQ==')], [dict(name='bad.exe', data='YQ==')]):
            with self.subTest(files=files):
                self.body.update(requestId=app.uuid.uuid4().hex, files=files)
                self.assertEqual(self.update()['stage'], 'failed')
                self.assertEqual(self.store.document('one'), self.original)
                self.assertEqual(app.Store(self.tmp.name).document('one'), self.original)

    def test_disk_failure_at_replacement_rolls_back_source(self):
        original_replace = app.os.replace
        def replace(src, dest):
            if self.store.document('one')['pages'] == [SOURCE]:
                raise OSError('disk full')
            return original_replace(src, dest)
        with patch.object(app.os, 'replace', side_effect=replace):
            self.assertEqual(self.update()['stage'], 'failed')
        self.assertEqual(self.store.document('one'), self.original)
        self.assertEqual(app.Store(self.tmp.name).document('one'), self.original)

    def test_document_jobs_are_mutually_exclusive(self):
        job, _ = self.store.new_job(self.body, 'update')
        self.assertFalse(self.store.new_job(self.body, 'update')[1])
        generate = dict(requestId='generate-001', documentId='one', name='Quiz', count=1)
        with self.assertRaises(app.AppError):
            self.store.new_job(generate, 'generate')
        with self.assertRaises(app.AppError):
            self.store.new_job(dict(self.body, requestId='update-002'), 'update')
        self.store.process(job, self.body)
        self.store.new_job(generate, 'generate')
        with self.assertRaises(app.AppError):
            self.store.new_job(dict(self.body, requestId='update-003'), 'update')

    def test_unknown_or_deleted_document_rejected(self):
        for doc_id in (None, 'missing'):
            with self.assertRaises(app.AppError):
                self.store.new_job(dict(self.body, documentId=doc_id), 'update')
        self.store.document('one')['deleted'] = True
        with self.assertRaises(app.AppError):
            self.store.new_job(self.body, 'update')

    def test_generation_uses_replaced_pages(self):
        self.update()
        body = dict(requestId='generate-001', documentId='one', name='New quiz', count=1)
        job, _ = self.store.new_job(body, 'generate')
        response = dict(choices=[dict(message=dict(content=json.dumps(dict(analysis=dict(subject='QuizMind', sourceLanguage='vi', questionLanguage='vi', topics=['Tài liệu nguồn']), questions=[question()]))))])
        with patch.object(app, 'CONFIG') as config, patch.object(app, 'ai_request', return_value=response) as ai:
            config.read_text.return_value = '{}'
            self.store.process(job, body)
        self.assertEqual(self.store.current_job(job)['stage'], 'ready')
        self.assertEqual(json.loads(ai.call_args.args[1]['messages'][-1]['content'])[0]['text'], SOURCE)


class UpdateRouteTests(unittest.TestCase):
    setUp = test_document_actions.DocumentActionsTests.setUp
    tearDown = test_document_actions.DocumentActionsTests.tearDown
    post = test_document_actions.DocumentActionsTests.post

    def test_update_route_auth_and_dispatch(self):
        from unittest.mock import Mock
        executor = Mock()
        self.server.RequestHandlerClass = app.make_handler(self.store, executor, 'A' * 43)
        body = dict(requestId='update-001', documentId='one', name='New', files=[])
        self.assertEqual(self.post('update', body, token='B' * 43)[0], 401)
        executor.submit.assert_not_called()
        status, job = self.post('update', body)
        self.assertEqual((status, job['type'], job['documentId']), (202, 'update', 'one'))
        self.assertEqual(self.post('update', body)[0], 202)
        executor.submit.assert_called_once()
