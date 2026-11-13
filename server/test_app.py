import base64
import copy
import io
import json
import os
import http.client
import http.server
import socket
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import app  # noqa: E402


SOURCE = "QuizMind dùng tài liệu nguồn để tạo câu hỏi có căn cứ và giải thích rõ ràng cho người tự học."


def question(quote="tài liệu nguồn để tạo câu hỏi"):
    return {
        "question": "Điều gì được nêu trong tài liệu?",
        "options": ["Đáp án A", "Đáp án B", "Đáp án C", "Đáp án D"],
        "correct": 0,
        "page": 1,
        "quote": quote,
        "explanation": "Đáp án được giải thích dựa trên nội dung nguồn.",
    }


class FakeResponse(io.BytesIO):
    code = 200
    msg = "OK"

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()

    def getcode(self):
        return self.code

    def info(self):
        return {}


class ProbeHTTPHandler(app.urllib.request.HTTPHandler):
    hosts = []

    def http_open(self, request):
        self.hosts.append(request.host)
        return FakeResponse(b'{"data": []}')


class StoreTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="quizmind-test-")
        self.store = app.Store(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_validate_quiz_accepts_source_quote_and_cleans_fields(self):
        raw = {"questions": [question()]}
        clean = app.validate_quiz(raw, [SOURCE], 5)
        self.assertEqual(clean[0]["quote"], question()["quote"])
        self.assertEqual(clean[0]["question"], question()["question"])

    def test_validate_quiz_rejects_whitespace_quote(self):
        with self.assertRaises(app.AppError):
            app.validate_quiz({"questions": [question(" " * 15)]}, [SOURCE], 5)

    def test_ai_request_bypasses_environment_proxy(self):
        ProbeHTTPHandler.hosts = []

        class Config:
            def read_text(self):
                return json.dumps({"base_url": "http://127.0.0.1:57220/v1", "api_key": "synthetic"})

        with patch.object(app, "CONFIG", Config()), patch.dict(
            os.environ, {"http_proxy": "http://192.0.2.10:3128", "no_proxy": ""}, clear=True
        ), patch.object(app.urllib.request, "HTTPHandler", ProbeHTTPHandler):
            self.assertEqual(app.ai_request("/models"), {"data": []})
        self.assertEqual(ProbeHTTPHandler.hosts, ["127.0.0.1:57220"])

    def test_save_rollback_keeps_disk_and_memory_consistent_and_retry_is_fresh(self):
        before = copy.deepcopy(self.store.state)
        with patch.object(app.os, "replace", side_effect=OSError("synthetic disk failure")):
            with self.assertRaises(OSError):
                self.store.new_job({"requestId": "request-123", "name": "Fixture", "files": []}, "import")
        self.assertEqual(self.store.state, before)
        self.assertEqual(json.loads(self.store.file.read_text()), before)
        job, fresh = self.store.new_job({"requestId": "request-123", "name": "Fixture", "files": []}, "import")
        self.assertTrue(fresh)
        self.assertEqual(job["stage"], "queued")
        self.assertEqual(len(self.store.state["jobs"]), 1)

    def test_import_rejects_bad_extension_and_persists_valid_text_for_restart(self):
        bad, _ = self.store.new_job({"requestId": "bad-file-123", "name": "Bad file", "files": [{"name": "x.exe", "data": "eA=="}]}, "import")
        self.store.process(bad, {"files": [{"name": "x.exe", "data": "eA=="}]})
        self.assertEqual(self.store.state["jobs"][0]["stage"], "failed")
        self.assertEqual(self.store.state["documents"], [])

        text = base64.b64encode(SOURCE.encode()).decode()
        good, _ = self.store.new_job({"requestId": "good-file-123", "name": "  Source 😀  ", "files": [{"name": "source.txt", "data": text}]}, "import")
        self.store.process(good, {"name": "  Source 😀  ", "files": [{"name": "source.txt", "data": text}]})
        self.assertEqual(self.store.state["jobs"][0]["stage"], "ready")
        restarted = app.Store(self.tmp.name)
        self.assertEqual(restarted.state["documents"][0]["pages"], [SOURCE])
        self.assertEqual(restarted.state["documents"][0]["name"], "Source 😀")
        self.assertEqual(restarted.state["jobs"][0]["name"], "Source 😀")

    def seed_document(self):
        self.store.state['documents'] = [dict(id='doc-123', name='Original', pages=[SOURCE])]
        self.store.save()
        return dict(requestId='generate-123', documentId='doc-123', name='  Đề mới 😀  ', count=7)

    def test_names_are_required_strings_trimmed_and_limited_in_codepoints(self):
        body = self.seed_document()
        before = copy.deepcopy(self.store.state)
        for kind in ('import', 'generate'):
            for invalid in (None, '', ' \t\n', '\u2003', 'a' * 161, 123, True, [], {}):
                with self.subTest(kind=kind, name=invalid), self.assertRaises(app.AppError):
                    self.store.new_job({**body, 'name': invalid}, kind)
            missing = {k: v for k, v in body.items() if k != 'name'}
            with self.assertRaises(app.AppError):
                self.store.new_job(missing, kind)
        self.assertEqual(self.store.state, before)
        self.assertEqual(json.loads(self.store.file.read_text()), before)
        for kind in ('import', 'generate'):
            job, fresh = self.store.new_job({**body, 'requestId': 'unicode-' + kind,
                                             'name': '  ' + '😀' * 160 + '  '}, kind)
            self.assertTrue(fresh)
            self.assertEqual(job['name'], '😀' * 160)

    def test_generate_rejects_noninteger_or_out_of_range_counts_before_admission(self):
        body = self.seed_document()
        before = copy.deepcopy(self.store.state)
        for count in (None, 0, -1, 101, True, False, 7.0, 1.5, '7', [], {}):
            with self.subTest(count=count), self.assertRaises(app.AppError):
                self.store.new_job({**body, 'count': count}, 'generate')
        del body['count']
        with self.assertRaises(app.AppError):
            self.store.new_job(body, 'generate')
        self.assertEqual(self.store.state, before)
        self.assertEqual(json.loads(self.store.file.read_text()), before)

    def test_generate_boundaries_custom_count_and_persisted_names_match_quiz(self):
        body = self.seed_document()
        for count, budget in ((1, 7000), (7, 7000), (31, 15500), (100, 50000)):
            with self.subTest(count=count):
                name = f'Đề {count} 😀'
                body.update(requestId=f'generate-{count}', count=count, name='  ' + name + '  ')
                job, fresh = self.store.new_job(body, 'generate')
                self.assertTrue(fresh)
                self.assertEqual(job['name'], name)
                self.assertEqual(json.loads(self.store.file.read_text())['documents'][0]['name'], name)
                questions = [{**question(), 'question': f'Câu {i}: Điều gì được nêu trong tài liệu?'}
                             for i in range(count)]
                response = dict(choices=[dict(message=dict(content=json.dumps(dict(questions=questions))))])
                with patch.object(app, 'CONFIG') as config, patch.object(app, 'ai_request', return_value=response) as ai:
                    config.read_text.return_value = '{"model": "fixture-model"}'
                    self.store.process(job, body)
                self.assertEqual(self.store.current_job(job)['stage'], 'ready')
                payload = ai.call_args.args[1]
                self.assertIn(f'Tạo tối đa {count} câu', payload['messages'][0]['content'])
                self.assertEqual(payload['max_tokens'], budget)
                quiz = self.store.state['quizzes'][0]
                self.assertEqual(quiz['title'], name)
                self.assertEqual(quiz['requestedCount'], count)
                self.assertEqual(len(quiz['questions']), count)
        restarted = app.Store(self.tmp.name)
        self.assertEqual(restarted.state['documents'][0]['name'], 'Đề 100 😀')
        self.assertEqual([q['title'] for q in restarted.state['quizzes']], ['Đề 100 😀', 'Đề 31 😀', 'Đề 7 😀', 'Đề 1 😀'])

    def test_generate_optional_instructions_validation_and_ai_payload(self):
        for instructions in (None, 42, [], 'x' * 2001):
            body = self.seed_document()
            before = copy.deepcopy(self.store.state)
            with self.subTest(instructions=type(instructions).__name__), self.assertRaises(app.AppError):
                self.store.new_job({**body, 'instructions': instructions}, 'generate')
            self.assertEqual(self.store.state, before)
        for index, instructions in enumerate(('', '   ', '  Tập trung vào ngữ pháp.  ', 'x' * 2000)):
            body = {**self.seed_document(), 'requestId': f'instructions-{index}', 'instructions': instructions}
            job, _ = self.store.new_job(body, 'generate')
            response = dict(choices=[dict(message=dict(content=json.dumps(dict(questions=[question()]))))])
            with patch.object(app, 'CONFIG') as config, patch.object(app, 'ai_request', return_value=response) as ai:
                config.read_text.return_value = '{"model":"fixture"}'
                self.store.process(job, body)
            self.assertEqual(self.store.current_job(job)['stage'], 'ready')
            messages = ai.call_args.args[1]['messages']
            self.assertEqual(len(messages), 3 if instructions.strip() else 2)
            if instructions.strip():
                self.assertEqual(messages[1], dict(role='user', content='Yêu cầu bổ sung: ' + instructions.strip()))
            self.assertEqual(json.loads(messages[-1]['content']), [dict(page=1, text=SOURCE)])
            self.assertIn('Chỉ dùng dữ kiện trong nguồn', messages[0]['content'])

    def test_generate_retry_and_active_dedupe_do_not_rename_or_resubmit(self):
        body = self.seed_document()
        job, _ = self.store.new_job(body, 'generate')
        before = copy.deepcopy(self.store.state)
        for changes in ({'name': 'Retry name', 'count': 100},
                        {'requestId': 'another-123', 'name': 'Active duplicate', 'count': 1}):
            replay, fresh = self.store.new_job({**body, **changes}, 'generate')
            self.assertFalse(fresh)
            self.assertEqual(replay, job)
            self.assertEqual(self.store.state, before)
        with self.assertRaises(app.AppError):
            self.store.new_job(body, 'import')
        with patch.object(app, 'CONFIG') as config, patch.object(app, 'ai_request') as ai:
            config.read_text.return_value = '{}'
            ai.return_value = dict(choices=[dict(message=dict(content=json.dumps({'questions': [question()]})))])
            self.store.process(job, body)
            ai.assert_called_once()
        ready = copy.deepcopy(self.store.state)
        replay, fresh = self.store.new_job({**body, 'name': 'Completed retry'}, 'generate')
        self.assertFalse(fresh)
        self.assertEqual(replay['name'], 'Đề mới 😀')
        self.assertEqual(self.store.state, ready)
        self.assertEqual(self.store.state['quizzes'][0]['title'], 'Đề mới 😀')

    def test_concurrent_generate_admission_keeps_one_job_and_its_name(self):
        body = self.seed_document()
        barrier = threading.Barrier(2, timeout=3)

        def admit(number):
            barrier.wait()
            return self.store.new_job({**body, 'requestId': f'concurrent-{number}',
                                       'name': f'Concurrent {number}'}, 'generate')

        with app.concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(admit, (1, 2)))
        self.assertEqual(sum(fresh for _, fresh in results), 1)
        self.assertEqual(results[0][0]['id'], results[1][0]['id'])
        self.assertEqual(len(self.store.state['jobs']), 1)
        self.assertEqual(self.store.document('doc-123')['name'], results[0][0]['name'])
        self.assertEqual(json.loads(self.store.file.read_text()), self.store.state)

    def test_generate_admission_save_failure_rolls_back_rename_and_job(self):
        body = self.seed_document()
        before = copy.deepcopy(self.store.state)
        with patch.object(app.os, 'replace', side_effect=OSError('synthetic disk failure')):
            with self.assertRaises(OSError):
                self.store.new_job(body, 'generate')
        self.assertEqual(self.store.state, before)
        self.assertEqual(json.loads(self.store.file.read_text()), before)
        job, fresh = self.store.new_job(body, 'generate')
        self.assertTrue(fresh)
        self.assertEqual(job['name'], 'Đề mới 😀')
        self.assertEqual(self.store.document('doc-123')['name'], 'Đề mới 😀')

    def test_chat_admission_validates_prompt_and_replays_request(self):
        valid = dict(requestId='chat-request-123', name='  Đề từ chat  ',
                     prompt='Tạo đề Sinh học lớp 9 về hệ hô hấp.', count=5)
        for prompt in (None, '', 'ngắn', 'x' * 4001):
            with self.subTest(prompt=prompt), self.assertRaises(app.AppError):
                self.store.new_job({**valid, 'prompt': prompt}, 'chat')
        for count in (0, 101, True, 5.0, '5', None):
            with self.subTest(count=count), self.assertRaises(app.AppError):
                self.store.new_job({**valid, 'count': count}, 'chat')
        job, fresh = self.store.new_job(valid, 'chat')
        self.assertTrue(fresh)
        self.assertEqual(job['name'], 'Đề từ chat')
        replay, fresh = self.store.new_job({**valid, 'name': 'Tên khác', 'count': 15}, 'chat')
        self.assertFalse(fresh)
        self.assertEqual(replay, job)

    def test_chat_completion_persists_quiz_and_invalid_ai_output_fails(self):
        body = dict(requestId='chat-complete-123', name='Đề Sinh học',
                    prompt='Tạo câu hỏi Sinh học lớp 9 về hô hấp.', count=5)
        for valid in (True, False):
            with self.subTest(valid=valid):
                job, _ = self.store.new_job({**body, 'requestId': f'chat-complete-{valid}'}, 'chat')
                raw = dict(questions=[question()])
                if not valid:
                    raw['questions'][0]['options'] = ['A', 'A', 'B', 'C']
                response = dict(choices=[dict(message=dict(content=json.dumps(raw)))])
                with patch.object(app, 'CONFIG') as config, patch.object(app, 'ai_request', return_value=response):
                    config.read_text.return_value = '{"model":"fixture"}'
                    self.store.process(job, body)
                self.assertEqual(self.store.current_job(job)['stage'], 'ready' if valid else 'failed')
        restarted = app.Store(self.tmp.name)
        self.assertEqual(len(restarted.state['quizzes']), 1)
        quiz = restarted.state['quizzes'][0]
        self.assertEqual(quiz['title'], body['name'])
        self.assertEqual(quiz['questions'][0]['sourceType'], 'ai')
        self.assertEqual(restarted.document(quiz['documentId'])['pages'], [body['prompt']])

    def test_generate_completion_save_failure_does_not_leave_a_quiz(self):
        body = self.seed_document()
        job, _ = self.store.new_job(body, 'generate')
        replace = app.os.replace

        def fail_quiz_save(*args):
            if self.store.state['quizzes']:
                raise OSError('synthetic quiz save failure')
            return replace(*args)

        with patch.object(app, 'CONFIG') as config, patch.object(app, 'ai_request') as ai, patch.object(app.os, 'replace', side_effect=fail_quiz_save):
            config.read_text.return_value = '{}'
            ai.return_value = dict(choices=[dict(message=dict(content=json.dumps({'questions': [question()]})))])
            self.store.process(job, body)
        self.assertEqual(self.store.state['quizzes'], [])
        self.assertEqual(self.store.current_job(job)['stage'], 'failed')
        self.assertEqual(self.store.document('doc-123')['name'], 'Đề mới 😀')
        self.assertEqual(json.loads(self.store.file.read_text()), self.store.state)

    def test_submit_scores_and_is_idempotent(self):
        self.store.state["documents"] = [{"id": "doc-123", "pages": [SOURCE]}]
        self.store.state["quizzes"] = [{"id": "quiz-123", "documentId": "doc-123", "questions": [{"correct": 0}, {"correct": 2}]}]
        self.store.save()
        body = {"id": "attempt-123", "quizId": "quiz-123", "answers": [0, -1]}
        first = self.store.submit(body)
        second = self.store.submit(body)
        self.assertEqual(first, second)
        self.assertEqual(first["score"], 1)
        self.assertEqual(len(self.store.state["attempts"]), 1)


class AuthTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="quizmind-auth-")
        self.token = "A" * 43
        self.server = app.LimitedServer(
            ("127.0.0.1", 0),
            app.make_handler(app.Store(Path(self.tmp.name) / "data"), None, self.token, {('relay.example', None)}),
        )
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.tmp.cleanup()

    def request(self, headers=None, path="/api/connection"):
        conn = http.client.HTTPConnection(*self.server.server_address, timeout=2)
        conn.request("GET", path, headers={"Host": "127.0.0.1:8787", **(headers or {})})
        response = conn.getresponse()
        body = response.read()
        conn.close()
        return response.status, body

    def test_auth_connection_contract_and_origin_protection(self):
        self.assertEqual(self.request()[0], 401)
        self.assertEqual(self.request({"Authorization": "Bearer " + self.token})[0], 200)
        status, body = self.request({"Authorization": "Bearer " + self.token, "Origin": "null"})
        self.assertEqual(status, 403)
        self.assertEqual(json.loads(body), {"error": "Dịch vụ không nhận yêu cầu từ website."})

    def test_wrong_token_is_unauthorized_and_connection_does_not_expose_config(self):
        status, body = self.request({"Authorization": "Bearer " + "B" * 43})
        self.assertEqual(status, 401)
        status, body = self.request({"Authorization": "Bearer " + self.token})
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body), {"ok": True})

    def test_token_file_is_atomic_and_fails_closed(self):
        path = Path(self.tmp.name) / "token"
        first = app.load_auth_token(path)
        self.assertTrue(app.TOKEN_RE.fullmatch(first))
        self.assertEqual(app.load_auth_token(path), first)
        os.chmod(path, 0o644)
        with self.assertRaises(app.AppError):
            app.load_auth_token(path)

    def test_token_file_rejects_symlink_invalid_content_and_hardlink(self):
        path = Path(self.tmp.name) / 'token'
        path.write_text('invalid')
        path.chmod(0o600)
        with self.assertRaises(app.AppError):
            app.load_auth_token(path)
        path.write_text(self.token + '\n')
        link = Path(self.tmp.name) / 'link'
        link.symlink_to(path)
        with self.assertRaises(app.AppError):
            app.load_auth_token(link)
        link.unlink()
        os.link(path, link)
        with self.assertRaises(app.AppError):
            app.load_auth_token(link)

    def test_every_route_requires_auth_before_state_ai_or_mutation(self):
        for route in ('state', 'health', 'connection', 'import', 'generate', 'chat', 'attempts', 'trash'):
            conn = http.client.HTTPConnection(*self.server.server_address, timeout=2)
            method = 'POST' if route in ('import', 'generate', 'chat', 'attempts', 'trash') else 'GET'
            conn.request(method, '/api/' + route, body='{}' if method == 'POST' else None,
                         headers={'Host': '127.0.0.1:8787', 'Content-Type': 'application/json'})
            response = conn.getresponse()
            self.assertEqual(response.status, 401, route)
            response.read()
            conn.close()

    def test_public_host_is_exact_and_requires_trusted_https_marker_and_token(self):
        good = {'Authorization': 'Bearer ' + self.token}
        for host in ('evil.example', 'relay.example.evil', 'relay.example.', 'relay.example:80', 'localhost:9999', '[::1]:8787', '@relay.example', 'relay.example?', 'relay.example#'):
            self.assertEqual(self.request({**good, 'Host': host, 'X-Forwarded-Proto': 'https'})[0], 403, host)
        self.assertEqual(self.request({**good, 'Host': 'relay.example'})[0], 403)
        self.assertEqual(self.request({**good, 'X-Forwarded-Proto': 'https'})[0], 403)
        self.assertEqual(self.request({**good, 'Host': 'relay.example', 'X-Forwarded-Proto': 'https'})[0], 200)
        self.assertEqual(self.request({**good, 'Host': 'RELAY.EXAMPLE:443', 'X-Forwarded-Proto': 'https'})[0], 200)
        self.assertEqual(self.request({**good, 'Origin': ''})[0], 403)

    def raw_request(self, extra, method='POST'):
        with socket.create_connection(self.server.server_address, timeout=2) as connection:
            connection.sendall((f'{method} /api/import HTTP/1.1\r\nHost: 127.0.0.1:8787\r\nAuthorization: Bearer {self.token}\r\n' + extra + '\r\n').encode())
            return int(connection.recv(4096).split(b' ')[1])

    def test_rejects_duplicate_headers_and_ambiguous_framing_before_body_read(self):
        for header in ('Host: 127.0.0.1:8787\r\n', 'Authorization: Bearer ' + self.token + '\r\n',
                       'Content-Length: 1\r\nContent-Length: 1\r\n',
                       'Transfer-Encoding: chunked\r\nContent-Length: 1\r\n',
                       'Transfer-Encoding: \r\n', 'Content-Length: +1\r\n',
                       'Content-Length: ' + str(app.MAX_BODY + 1) + '\r\n'):
            self.assertEqual(self.raw_request(header), 400, header.split(':')[0])

    def test_rate_limit_includes_unauthenticated_requests(self):
        with patch.object(app, 'RATE_LIMIT', 2):
            self.assertEqual(self.request()[0], 401)
            self.assertEqual(self.request()[0], 401)
            self.assertEqual(self.request({'Authorization': 'Bearer ' + self.token})[0], 429)

    def test_document_options_http_validation_and_duplicate_submission(self):
        store = app.Store(Path(self.tmp.name) / 'options')
        store.state['documents'] = [dict(id='doc-123', name='Original', pages=[SOURCE])]
        store.save()
        executor = Mock()
        self.server.RequestHandlerClass = app.make_handler(store, executor, self.token)

        def post(kind, body, token=None):
            conn = http.client.HTTPConnection(*self.server.server_address, timeout=2)
            conn.request('POST', '/api/' + kind, body=json.dumps(body), headers={
                'Host': '127.0.0.1:8787', 'Content-Type': 'application/json',
                'Authorization': 'Bearer ' + (token or self.token)})
            response = conn.getresponse()
            result = response.status, json.loads(response.read())
            conn.close()
            return result

        body = dict(requestId='http-request', documentId='doc-123', count=7, name='  Tên mới  ')
        for kind in ('import', 'generate'):
            for invalid in (None, '', '  ', 123, 'a' * 161):
                status, result = post(kind, {**body, 'name': invalid})
                self.assertEqual(status, 400)
                self.assertIn('error', result)
            self.assertEqual(post(kind, {k: v for k, v in body.items() if k != 'name'})[0], 400)
        for count in (0, 101, True, 7.0, '7', None):
            self.assertEqual(post('generate', {**body, 'count': count})[0], 400)
        self.assertEqual(post('generate', body, 'B' * 43)[0], 401)
        self.assertEqual(store.state['jobs'], [])
        self.assertEqual(store.document('doc-123')['name'], 'Original')
        executor.submit.assert_not_called()
        status, job = post('generate', body)
        self.assertEqual(status, 202)
        self.assertEqual(job['name'], 'Tên mới')
        self.assertEqual(store.document('doc-123')['name'], 'Tên mới')
        for changes in ({'name': 'Retry'}, {'requestId': 'http-active-duplicate', 'name': 'Duplicate'}):
            status, replay = post('generate', {**body, **changes})
            self.assertEqual(status, 202)
            self.assertEqual(replay, job)
        executor.submit.assert_called_once()
        status, imported = post('import', {**body, 'requestId': 'http-import'})
        self.assertEqual(status, 202)
        self.assertEqual(imported['name'], 'Tên mới')
        self.assertEqual(executor.submit.call_count, 2)
        store.job_update(job, stage='ready')
        for count in (31, 100):
            status, generated = post('generate', {**body, 'requestId': f'http-count-{count}', 'count': count})
            self.assertEqual(status, 202)
            self.assertEqual(executor.submit.call_args.args[2]['count'], count)
            store.job_update(generated, stage='ready')
        self.assertEqual(executor.submit.call_count, 4)

    def test_chat_endpoint_accepts_valid_request_and_deduplicates(self):
        store = app.Store(Path(self.tmp.name) / 'chat-options')
        executor = Mock()
        self.server.RequestHandlerClass = app.make_handler(store, executor, self.token)

        def post(body):
            conn = http.client.HTTPConnection(*self.server.server_address, timeout=2)
            conn.request('POST', '/api/chat', body=json.dumps(body), headers={
                'Host': '127.0.0.1:8787', 'Content-Type': 'application/json',
                'Authorization': 'Bearer ' + self.token})
            response = conn.getresponse()
            result = response.status, json.loads(response.read())
            conn.close()
            return result

        valid = dict(requestId='http-chat-123', name='  Đề chat  ',
                     prompt='Tạo 5 câu Vật lý lớp 8 về lực đẩy.', count=5)
        for prompt in ('', 'ngắn', 'x' * 4001):
            status, result = post({**valid, 'prompt': prompt})
            self.assertEqual(status, 400)
            self.assertIn('error', result)
        status, job = post(valid)
        self.assertEqual(status, 202)
        self.assertEqual(job['name'], 'Đề chat')
        status, replay = post({**valid, 'name': 'Tên khác', 'count': 15})
        self.assertEqual(status, 202)
        self.assertEqual(replay, job)
        executor.submit.assert_called_once()
        self.assertEqual(executor.submit.call_args.args[2]['prompt'], valid['prompt'])

    def test_rotated_token_rejects_previous_token_after_handler_reload(self):
        path = Path(self.tmp.name) / 'rotated-token'
        previous = app.load_auth_token(path)
        self.server.RequestHandlerClass = app.make_handler(app.Store(Path(self.tmp.name) / 'data'), None, previous)
        self.assertEqual(self.request({'Authorization': 'Bearer ' + previous})[0], 200)
        path.write_text('B' * 43 + '\n')
        current = app.load_auth_token(path)
        self.server.RequestHandlerClass = app.make_handler(app.Store(Path(self.tmp.name) / 'data'), None, current)
        self.assertEqual(self.request({'Authorization': 'Bearer ' + previous})[0], 401)
        self.assertEqual(self.request({'Authorization': 'Bearer ' + current})[0], 200)


class LimitTests(unittest.TestCase):
    def test_seventeenth_connection_is_rejected_before_starting_worker(self):
        ready = threading.Barrier(17, timeout=5)

        class HeldServer(app.LimitedServer):
            def process_request_thread(self, request, client_address):
                ready.wait()
                super().process_request_thread(request, client_address)

        server = HeldServer(('127.0.0.1', 0), http.server.BaseHTTPRequestHandler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        connections = []
        try:
            for _ in range(16):
                connections.append(socket.create_connection(server.server_address, timeout=2))
            ready.wait()
            with socket.create_connection(server.server_address, timeout=2) as rejected:
                self.assertIn(b'429 Too Many Requests', rejected.recv(4096))
        finally:
            for connection in connections:
                connection.close()
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

    def test_three_active_jobs_are_bounded_and_duplicates_do_not_add_jobs(self):
        with tempfile.TemporaryDirectory() as directory:
            store = app.Store(directory)
            for number in range(3):
                store.new_job({'requestId': f'request-{number}', 'name': 'Fixture'}, 'import')
            _, fresh = store.new_job({'requestId': 'request-0', 'name': 'Fixture'}, 'import')
            self.assertFalse(fresh)
            with self.assertRaises(app.AppError):
                store.new_job({'requestId': 'request-3', 'name': 'Fixture'}, 'import')
            self.assertEqual(len(store.state['jobs']), 3)


if __name__ == "__main__":
    unittest.main()
