"""Document generation contracts, using synthetic AI replies and temporary data."""
import copy
import json
import unittest
from unittest.mock import patch

import app
import test_app


class DocumentFocusTests(unittest.TestCase):
    setUp = test_app.StoreTests.setUp
    tearDown = test_app.StoreTests.tearDown
    seed_document = test_app.StoreTests.seed_document

    def generate(self, source, analysis, question, **fields):
        body = dict(self.seed_document(), count=1, **fields)
        self.store.document('doc-123')['pages'] = [source]
        self.store.save()
        job, _ = self.store.new_job(body, 'generate')
        raw = dict(questions=[question])
        if analysis is not None:
            raw['analysis'] = analysis
        response = dict(model='fixture', choices=[dict(message=dict(content=json.dumps(raw)))])
        with patch.object(app, 'CONFIG') as config, patch.object(app, 'ai_request', return_value=response) as ai:
            config.read_text.return_value = '{"model":"fixture"}'
            self.store.process(job, body)
        return self.store.current_job(job), ai

    def test_subject_language_and_questions_survive_generation_and_restart(self):
        cases = [
            ('The present simple describes habits. Use the base verb with I, you, we and they.',
             'English grammar', 'en', 'en', 'Present simple',
             'Which sentence describes a habit using the present simple?',
             ['They walk to school every day.', 'They walked yesterday.', 'They are walking now.', 'They will walk tomorrow.'],
             'Use the base verb with they to describe a habit.'),
            ('Thì hiện tại đơn diễn tả thói quen. Example: She walks to school every day.',
             'English grammar', 'vi/en', 'en', 'Present simple',
             'Which verb completes the habit: She ___ to school every day?',
             ['walks', 'walk', 'walking', 'walked'],
             'The example uses walks with she to describe a daily habit.'),
            ('Photosynthesis uses light energy to convert carbon dioxide and water into glucose and oxygen.',
             'Biology', 'en', 'en', 'Photosynthesis',
             'Which energy source is used in photosynthesis?',
             ['Light energy', 'Sound energy', 'Nuclear energy', 'Geothermal energy'],
             'Photosynthesis uses light energy to produce glucose and oxygen.'),
            ('Chiến thắng Điện Biên Phủ năm 1954 là một sự kiện quan trọng trong lịch sử Việt Nam.',
             'Lịch sử Việt Nam', 'vi', 'vi', 'Điện Biên Phủ',
             'Chiến thắng Điện Biên Phủ diễn ra vào năm nào?',
             ['1954', '1945', '1975', '1930'],
             'Nguồn xác định chiến thắng Điện Biên Phủ diễn ra năm 1954.'),
        ]
        for index, (source, subject, language, output_language, topic, text, options, explanation) in enumerate(cases):
            with self.subTest(subject=subject, language=language):
                analysis = dict(subject=subject, sourceLanguage=language,
                                questionLanguage=output_language, topics=[topic])
                question = dict(question=text, options=options, correct=0, page=1,
                                quote=source, explanation=explanation)
                job, ai = self.generate(source, analysis, question, requestId=f'document-focus-{index}')
                self.assertEqual(job['stage'], 'ready')
                ai.assert_called_once()
                messages = ai.call_args.args[1]['messages']
                self.assertIn(app.DOCUMENT_QUIZ_RULES, messages[0]['content'])
                self.assertNotIn('TIẾNG VIỆT', messages[0]['content'])
                self.assertNotIn('dùng tiếng Việt tự nhiên', messages[0]['content'])
                self.assertEqual(json.loads(messages[-1]['content']), [dict(page=1, text=source)])
                saved = app.Store(self.tmp.name).state['quizzes'][0]
                self.assertEqual(saved['analysis'], analysis)
                self.assertEqual(saved['questions'], [question])

    def test_missing_or_invalid_analysis_fails_without_partial_quiz_or_retry(self):
        invalid = [None, [], {}, {**test_app.DOCUMENT_ANALYSIS, 'subject': ' '},
                   {**test_app.DOCUMENT_ANALYSIS, 'sourceLanguage': 12},
                   {**test_app.DOCUMENT_ANALYSIS, 'questionLanguage': 'x' * 201},
                   {**test_app.DOCUMENT_ANALYSIS, 'topics': []},
                   {**test_app.DOCUMENT_ANALYSIS, 'topics': [' ']},
                   {**test_app.DOCUMENT_ANALYSIS, 'topics': ['x'] * 31}]
        for index, analysis in enumerate(invalid):
            with self.subTest(analysis=analysis):
                job, ai = self.generate(test_app.SOURCE, analysis, test_app.question(), requestId=f'invalid-{index}')
                self.assertEqual(job['stage'], 'failed')
                ai.assert_called_once()
                self.assertEqual(self.store.state['quizzes'], [])
                self.assertEqual(app.Store(self.tmp.name).state['quizzes'], [])

    def test_analysis_cannot_bypass_citation_validation(self):
        question = {**test_app.question(), 'quote': 'A citation which is absent from the actual document.'}
        job, ai = self.generate(test_app.SOURCE, copy.deepcopy(test_app.DOCUMENT_ANALYSIS), question)
        self.assertEqual(job['stage'], 'failed')
        self.assertIn('Trích dẫn', job['error'])
        self.assertEqual(self.store.state['quizzes'], [])
        ai.assert_called_once()


if __name__ == '__main__':
    unittest.main()
