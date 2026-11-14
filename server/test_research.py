import copy
import io
import json
import tempfile
import unittest
from unittest.mock import Mock, patch

import app


QUESTION = dict(question='Ở áp suất 1 atm, nước sôi ở nhiệt độ bao nhiêu?',
                options=['100 °C', '50 °C', '20 °C', '0 °C'], correct=0,
                explanation='Nước sôi ở 100 °C dưới áp suất 1 atm.')
SOURCE = dict(title='Nước', text='Nước sôi ở 100 °C dưới áp suất 1 atm.',
              url='https://vi.wikipedia.org/?curid=42')


def ai_response(data):
    return {'choices': [{'message': {'content': json.dumps(data)}}]}


class ResearchTests(unittest.TestCase):
    def test_research_uses_retrieved_sources_and_filters_unused(self):
        with patch.object(app, 'CONFIG', Mock(read_text=Mock(return_value='{}'))), \
             patch.object(app, 'wikipedia_search', return_value=[SOURCE]) as search, \
             patch.object(app, 'ai_request', side_effect=[
                 ai_response({'query': 'Nhiệt độ sôi'}),
                 ai_response({'answer': 'Nước sôi khi áp suất hơi bằng áp suất bên ngoài.', 'usedSources': [1, 1]})]) as ai:
            result = app.research_question(QUESTION)
        search.assert_called_once_with('Nhiệt độ sôi')
        self.assertEqual(result['sources'], [dict(title=SOURCE['title'], url=SOURCE['url'])])
        payload = ai.call_args.args[1]
        self.assertIn(SOURCE['text'], payload['messages'][1]['content'])
        self.assertNotIn('text', result['sources'][0])

    def test_missing_sources_is_explicit_not_fabricated(self):
        with patch.object(app, 'CONFIG', Mock(read_text=Mock(return_value='{}'))), \
             patch.object(app, 'wikipedia_search', return_value=[]), \
             patch.object(app, 'ai_request', side_effect=[ai_response({'query': 'Nước'}),
                 ai_response({'answer': 'Kiến thức do AI giải thích, chưa có nguồn kiểm chứng.', 'usedSources': []})]):
            self.assertEqual(app.research_question(QUESTION)['sources'], [])

    def test_invalid_ai_and_citations_are_rejected(self):
        for response in ({}, ai_response({'answer': 'x' * 30, 'usedSources': [99]})):
            with self.subTest(response=response), \
                 patch.object(app, 'CONFIG', Mock(read_text=Mock(return_value='{}'))), \
                 patch.object(app, 'wikipedia_search', return_value=[SOURCE]), \
                 patch.object(app, 'ai_request', side_effect=[ai_response({'query': 'Nước'}), response]):
                with self.assertRaises(app.AppError):
                    app.research_question(QUESTION)

    def test_store_validates_question_and_keeps_state_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            store = app.Store(directory)
            store.state['documents'] = [dict(id='doc')]
            store.state['quizzes'] = [dict(id='quiz', documentId='doc', questions=[QUESTION])]
            before = copy.deepcopy(store.state)
            with patch.object(app, 'research_question', return_value={'answer': 'result'}) as research:
                for body in ({'quizId': 'missing', 'questionIndex': 0},
                             {'quizId': 'quiz', 'questionIndex': True},
                             {'quizId': 'quiz', 'questionIndex': -1},
                             {'quizId': 'quiz', 'questionIndex': 1}):
                    with self.assertRaises(app.AppError):
                        store.research(body)
                research.assert_not_called()
                store.research(dict(quizId='quiz', questionIndex=0))
                research.assert_called_once_with(QUESTION)
            self.assertEqual(store.state, before)
            with patch.object(app, 'research_question', side_effect=app.AppError('offline')):
                with self.assertRaises(app.AppError):
                    store.research(dict(quizId='quiz', questionIndex=0))
            self.assertTrue(store.research_slots.acquire(blocking=False))
            self.assertTrue(store.research_slots.acquire(blocking=False))
            with self.assertRaises(app.AppError):
                store.research(dict(quizId='quiz', questionIndex=0))

    def test_wikipedia_fixed_origin_bounded_extracts(self):
        payload = {'query': {'pages': {'42': dict(pageid=42, title='Nước', extract='a' * 4000)}}}
        response = io.BytesIO(json.dumps(payload).encode())
        opener = Mock()
        opener.open.return_value = response
        with patch.object(app.urllib.request, 'build_opener', return_value=opener):
            sources = app.wikipedia_search('Nước & áp suất')
        self.assertEqual(len(sources[0]['text']), 2500)
        request = opener.open.call_args.args[0]
        self.assertTrue(request.full_url.startswith('https://vi.wikipedia.org/w/api.php?'))
        self.assertFalse(request.has_header('Authorization'))
        with patch.object(app.urllib.request, 'build_opener', side_effect=OSError):
            self.assertEqual(app.wikipedia_search('Nước'), [])
