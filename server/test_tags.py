import copy
import tempfile
import unittest
from unittest.mock import patch

import app


class TagTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.store = app.Store(self.directory.name)
        self.store.state['documents'] = [dict(id='doc')]
        self.store.state['quizzes'] = [dict(id='quiz', documentId='doc', questions=[])]
        self.store.save()

    def test_crud_assignment_and_reload(self):
        a = self.store.tags({'name': '  Ôn   thi  '}, 'create')
        b = self.store.tags({'name': 'Quan trọng'}, 'create')
        self.store.tags({'quizId': 'quiz', 'tagIds': [a['id'], b['id'], a['id']]}, 'assign')
        self.store.tags({'tagId': a['id'], 'name': 'Ôn cuối kỳ'}, 'rename')
        loaded = app.Store(self.directory.name)
        self.assertEqual(loaded.state['quizzes'][0]['tagIds'], [a['id'], b['id']])
        self.assertEqual(loaded.state['tags'][0]['name'], 'Ôn cuối kỳ')
        loaded.tags({'tagId': a['id']}, 'delete')
        self.assertEqual(loaded.state['quizzes'][0]['tagIds'], [b['id']])
        self.assertEqual(len(loaded.state['quizzes']), 1)

    def test_colors_persist_and_legacy_updates_preserve_color(self):
        tag = self.store.tags({'name': 'Màu xanh', 'color': 'blue'}, 'create')
        self.assertEqual(tag['color'], 'blue')
        self.store.tags({'tagId': tag['id'], 'name': 'Đổi tên'}, 'rename')
        self.assertEqual(self.store.state['tags'][0]['color'], 'blue')
        self.store.tags({'tagId': tag['id'], 'name': 'Đổi tên', 'color': 'red'}, 'rename')
        loaded = app.Store(self.directory.name)
        self.assertEqual(loaded.state['tags'][0]['color'], 'red')
        legacy = self.store.tags({'name': 'Tag cũ'}, 'create')
        self.store.state['tags'][-1].pop('color')
        self.store.save()
        self.store.tags({'tagId': legacy['id'], 'name': 'Tag cũ đổi tên'}, 'rename')
        self.assertEqual(self.store.state['tags'][-1]['color'], 'green')
        for color in ('#ffffff', '', None, [], 42):
            before = copy.deepcopy(self.store.state)
            with self.subTest(color=color), self.assertRaises(app.AppError):
                self.store.tags({'tagId': tag['id'], 'name': 'Đổi tên', 'color': color}, 'rename')
            self.assertEqual(self.store.state, before)
            with self.assertRaises(app.AppError):
                self.store.tags({'name': 'Invalid', 'color': color}, 'create')
            self.assertEqual(self.store.state, before)

    def test_invalid_names_and_assignment_leave_data_intact(self):
        self.store.tags({'name': 'Ôn thi'}, 'create')
        for body, action in [({'name': 'ôn THI'}, 'create'), ({'name': ' '}, 'create'),
                             ({'name': 12}, 'create'), ({'name': 'x' * 41}, 'create'),
                             ({'tagId': 'missing'}, 'delete'),
                             ({'quizId': 'quiz', 'tagIds': ['missing']}, 'assign'),
                             ({'quizId': 'quiz', 'tagIds': [True]}, 'assign'),
                             ({'quizId': 'missing', 'tagIds': []}, 'assign')]:
            before = copy.deepcopy(self.store.state)
            with self.subTest(body=body), self.assertRaises(app.AppError):
                self.store.tags(body, action)
            self.assertEqual(self.store.state, before)
        self.store.state['documents'][0]['deleted'] = True
        with self.assertRaises(app.AppError):
            self.store.tags({'quizId': 'quiz', 'tagIds': []}, 'assign')

    def test_save_failure_rolls_back(self):
        before = copy.deepcopy(self.store.state)
        with patch.object(app.os, 'replace', side_effect=OSError('disk full')):
            with self.assertRaises(OSError):
                self.store.tags({'name': 'Ôn thi'}, 'create')
        self.assertEqual(self.store.state, before)

    def test_old_state_migrates_without_quiz_loss(self):
        self.store.state.pop('tags')
        self.store.save()
        loaded = app.Store(self.directory.name)
        self.assertEqual(loaded.state['tags'], [])
        self.assertEqual(len(loaded.state['quizzes']), 1)
