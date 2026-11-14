"""Accept actual AI question counts with synthetic replies and isolated storage."""
import json
import unittest
from unittest.mock import patch

import app
import test_app
from test_app import question


def reply(start, size, **overrides):
    questions = [
        {**question(), 'question': f'Câu {i}: QuizMind dùng nguồn nào để tạo câu hỏi có căn cứ?',
         **overrides}
        for i in range(start, start + size)
    ]
    return dict(model='fixture', choices=[dict(message=dict(
        content=json.dumps(dict(analysis=test_app.DOCUMENT_ANALYSIS, questions=questions))))])


class QuestionCountTests(unittest.TestCase):
    setUp = test_app.StoreTests.setUp
    tearDown = test_app.StoreTests.tearDown
    seed_document = test_app.StoreTests.seed_document

    def run_job(self, kind, count, responses, **body_fields):
        body = dict(self.seed_document(), requestId=f'count-{kind}-{count}-{len(self.store.state["jobs"])}', count=count,
                    prompt='Tạo câu hỏi về tài liệu nguồn.', **body_fields)
        job, _ = self.store.new_job(body, kind)
        with patch.object(app, 'CONFIG') as config, patch.object(
                app, 'ai_request', side_effect=responses) as ai:
            config.read_text.return_value = '{"model":"fixture"}'
            self.store.process(job, body)
        return self.store.current_job(job), ai

    def test_validators_accept_nonempty_counts_independent_of_request(self):
        for size in (1, 3, 6, 100):
            raw = json.loads(reply(0, size)['choices'][0]['message']['content'])
            for validate in (app.validate_chat_quiz,
                             lambda raw, count: app.validate_quiz(raw, [question()['quote']], count)):
                with self.subTest(size=size):
                    self.assertEqual(len(validate(raw, 5)), size)

    def test_validators_reject_empty_or_oversized_results(self):
        for size in (0, 101):
            raw = json.loads(reply(0, size)['choices'][0]['message']['content'])
            for validate in (app.validate_chat_quiz,
                             lambda raw, count: app.validate_quiz(raw, [question()['quote']], count)):
                with self.subTest(size=size), self.assertRaises(app.AppError):
                    validate(raw, 5)

    def test_exact_counts_save_without_extra_calls(self):
        for kind in ('generate', 'chat'):
            for count in (1, 5, 7, 31, 100):
                with self.subTest(kind=kind, count=count):
                    job, ai = self.run_job(kind, count, [reply(0, count)])
                    self.assertEqual(job['stage'], 'ready')
                    ai.assert_called_once()
                    quiz = self.store.state['quizzes'][0]
                    self.assertEqual(len(quiz['questions']), count)
                    self.assertEqual(quiz['requestedCount'], count)
                    self.assertIn(f'đúng {count} câu', ai.call_args.args[1]['messages'][0]['content'])

    def test_mismatched_count_saves_actual_questions_without_retry(self):
        for kind in ('generate', 'chat'):
            for count, actual in ((7, 2), (31, 3), (100, 5), (5, 7)):
                with self.subTest(kind=kind, count=count, actual=actual):
                    job, ai = self.run_job(kind, count, [reply(0, actual)])
                    self.assertEqual(job['stage'], 'ready')
                    self.assertNotIn('error', job)
                    ai.assert_called_once()
                    quiz = self.store.state['quizzes'][0]
                    self.assertEqual(len(quiz['questions']), actual)
                    self.assertEqual(quiz['requestedCount'], count)
                    self.assertEqual(json.loads(self.store.file.read_text()), self.store.state)
                    if kind == 'chat':
                        self.assertEqual(self.store.state['documents'][0]['id'], quiz['documentId'])

    def test_invalid_results_still_fail_without_retry_or_partial_save(self):
        for kind in ('generate', 'chat'):
            for response in (
                reply(0, 0),
                reply(0, 101),
                reply(0, 2, options=['Trùng'] * 4),
                app.AppError('Upstream unavailable'),
                dict(choices=[dict(message=dict(content='{"questions":['))]),
            ):
                with self.subTest(kind=kind, response=response):
                    job, ai = self.run_job(kind, 7, [response])
                    self.assertEqual(job['stage'], 'failed')
                    ai.assert_called_once()
                    self.assertEqual(self.store.state['quizzes'], [])

    def test_document_source_validation_is_preserved(self):
        job, ai = self.run_job('generate', 7, [reply(0, 2, quote='Trích dẫn không có trong nguồn.')])
        self.assertEqual(job['stage'], 'failed')
        ai.assert_called_once()
        self.assertEqual(self.store.state['quizzes'], [])


if __name__ == '__main__':
    unittest.main()
