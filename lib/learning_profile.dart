import 'dart:convert';

import 'package:flutter/material.dart';

import 'api.dart';
import 'main.dart' show PageBody, EmptyView;
import 'theme.dart';
import 'ui.dart';

const learningDifficulties = {
  'auto': 'Tự động',
  'easy': 'Dễ',
  'medium': 'Trung bình',
  'hard': 'Khó',
};

class LearningPreferences {
  const LearningPreferences({
    this.subject = '',
    this.grade = '',
    this.difficulty = 'auto',
    this.dailyGoal = 20,
  });
  final String subject, grade, difficulty;
  final int dailyGoal;

  static LearningPreferences load(AppController c) {
    try {
      final data = jsonDecode(
        c.prefs.getString(c.localKey('learning-profile')) ?? '{}',
      ) as Map<String, dynamic>;
      return LearningPreferences(
        subject: data['subject'] as String? ?? '',
        grade: data['grade'] as String? ?? '',
        difficulty: learningDifficulties.containsKey(data['difficulty'])
            ? data['difficulty'] as String
            : 'auto',
        dailyGoal: ((data['dailyGoal'] as num?)?.toInt() ?? 20).clamp(1, 100),
      );
    } catch (_) {
      return const LearningPreferences();
    }
  }

  Future<bool> save(AppController c) => c.prefs.setString(
    c.localKey('learning-profile'),
    jsonEncode({
      'subject': subject,
      'grade': grade,
      'difficulty': difficulty,
      'dailyGoal': dailyGoal,
    }),
  );

  String get instructions => [
    if (subject.isNotEmpty) 'Môn học ưu tiên: $subject.',
    if (grade.isNotEmpty) 'Trình độ/lớp: $grade.',
  ].join('\n');
}

class LearningStats {
  LearningStats(List<Json> attempts, {DateTime? now}) {
    final today = now ?? DateTime.now();
    for (final a in attempts) {
      final total = (a['total'] as num?)?.toInt() ?? 0;
      final score = (a['score'] as num?)?.toInt() ?? 0;
      if (total <= 0 || score < 0 || score > total) continue;
      valid.add(a);
      answered += total;
      correct += score;
      final timestamp = a['createdAt'];
      if (timestamp is num) {
        final date = DateTime.fromMillisecondsSinceEpoch(
          (timestamp * 1000).round(),
        );
        if (date.year == today.year &&
            date.month == today.month &&
            date.day == today.day) {
          todayAnswered += total;
        }
      }
      final id = a['quizId'] as String? ?? '';
      final previous = byQuiz[id] ?? (0, 0);
      byQuiz[id] = (previous.$1 + score, previous.$2 + total);
    }
    valid.sort(
      (a, b) => ((b['createdAt'] as num?) ?? 0).compareTo(
        (a['createdAt'] as num?) ?? 0,
      ),
    );
  }
  final valid = <Json>[];
  final byQuiz = <String, (int, int)>{};
  int answered = 0, correct = 0, todayAnswered = 0;
  int get accuracy => answered == 0 ? 0 : (correct / answered * 100).round();
}

class LearningStatsScreen extends StatelessWidget {
  const LearningStatsScreen({super.key, required this.c});
  final AppController c;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final stats = LearningStats(c.items('attempts'));
      final goal = LearningPreferences.load(c).dailyGoal;
      final quizzes = {for (final q in c.items('quizzes')) q['id']: q['title']};
      Widget metric(String label, String value) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: mint,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: forest,
              ),
            ),
            Text(label, style: const TextStyle(color: muted)),
          ],
        ),
      );
      return Scaffold(
        body: PageBody(
          children: [
            const PageTitle('Thống kê học tập'),
            const SizedBox(height: 20),
            const Text(
              'Mỗi lần luyện tập là một bước tiến.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                metric('Lượt làm bài', '${stats.valid.length}'),
                metric('Câu đã làm', '${stats.answered}'),
                metric(
                  'Tỉ lệ đúng',
                  stats.valid.isEmpty ? '—' : '${stats.accuracy}%',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Mục tiêu hôm nay',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text('${stats.todayAnswered}/$goal câu hỏi'),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: (stats.todayAnswered / goal).clamp(0, 1),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 24),
            if (stats.valid.isEmpty)
              const EmptyView(
                'Chưa có kết quả học tập',
                'Hoàn thành một bộ đề để xem tiến độ, điểm số và nội dung cần ôn.',
                icon: Icons.insights_outlined,
              )
            else ...[
              Text(
                'Điểm mạnh & nội dung cần ôn',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Dựa trên tỉ lệ trả lời đúng theo từng bộ đề, gồm cả các lần làm lại.',
                style: TextStyle(color: muted),
              ),
              for (final entry
                  in (stats.byQuiz.entries.toList()..sort(
                    (a, b) => (a.value.$1 / a.value.$2).compareTo(
                      b.value.$1 / b.value.$2,
                    ),
                  )))
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  leading: MintIcon(
                    entry.value.$1 / entry.value.$2 >= .8
                        ? Icons.check_circle_outline
                        : Icons.menu_book_outlined,
                  ),
                  title: Text(quizzes[entry.key] as String? ?? 'Bộ đề đã xóa'),
                  subtitle: Text(
                    '${(entry.value.$1 / entry.value.$2 * 100).round()}% đúng · ${entry.value.$1 / entry.value.$2 >= .8 ? 'Đang làm tốt' : 'Nên ôn thêm'}',
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                'Kết quả gần đây',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final attempt in stats.valid.take(10))
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  leading: const MintIcon(Icons.assignment_turned_in_outlined),
                  title: Text(
                    quizzes[attempt['quizId']] as String? ?? 'Bộ đề đã xóa',
                  ),
                  subtitle: Text(
                    '${attempt['score']}/${attempt['total']} câu đúng',
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

class LearningPreferencesScreen extends StatefulWidget {
  const LearningPreferencesScreen({super.key, required this.c});
  final AppController c;
  @override
  State<LearningPreferencesScreen> createState() =>
      _LearningPreferencesScreenState();
}

class _LearningPreferencesScreenState extends State<LearningPreferencesScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController subject, grade, goal;
  late String difficulty;
  late final String storageKey;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final preferences = LearningPreferences.load(widget.c);
    storageKey = widget.c.localKey('learning-profile');
    subject = TextEditingController(text: preferences.subject);
    grade = TextEditingController(text: preferences.grade);
    goal = TextEditingController(text: '${preferences.dailyGoal}');
    difficulty = preferences.difficulty;
  }

  @override
  void dispose() {
    subject.dispose();
    grade.dispose();
    goal.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || saving) return;
    setState(() => saving = true);
    try {
      if (storageKey != widget.c.localKey('learning-profile')) {
        throw StateError('Tài khoản đã thay đổi. Vui lòng mở lại màn hình.');
      }
      final ok = await LearningPreferences(
        subject: subject.text.trim(),
        grade: grade.text.trim(),
        difficulty: difficulty,
        dailyGoal: int.parse(goal.text.trim()),
      ).save(widget.c);
      if (!ok) throw StateError('Không thể lưu tùy chọn. Vui lòng thử lại.');
      if (mounted) {
        showAppToast(context, 'Đã lưu tùy chọn học tập', success: true);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        showAppToast(context, 'Không thể lưu tùy chọn. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageBody(
      children: [
        const PageTitle('Cá nhân hóa học tập'),
        const SizedBox(height: 20),
        const Text(
          'Thiết lập cách học phù hợp với bạn. Tùy chọn được lưu trên thiết bị này.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 24),
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: subject,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Môn học ưu tiên',
                  hintText: 'Ví dụ: Toán, Tiếng Anh',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: grade,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Lớp / trình độ',
                  hintText: 'Ví dụ: Lớp 12, Đại học',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: difficulty,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Độ khó mặc định'),
                items: [
                  for (final entry in learningDifficulties.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: saving
                    ? null
                    : (value) => setState(() => difficulty = value ?? 'auto'),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: goal,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Mục tiêu câu hỏi mỗi ngày',
                  helperText: 'Từ 1 đến 100 câu',
                ),
                validator: (value) {
                  final n = int.tryParse(value?.trim() ?? '');
                  return n == null || n < 1 || n > 100
                      ? 'Nhập số nguyên từ 1 đến 100.'
                      : null;
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Độ khó, môn học và trình độ sẽ điền sẵn khi tạo bộ đề từ tài liệu. Bạn có thể chỉnh lại trước khi tạo; nội dung vẫn bám theo tài liệu.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 24),
              GradientAction(
                saving ? 'Đang lưu…' : 'Lưu tùy chọn',
                icon: Icons.check_rounded,
                onPressed: saving ? null : save,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
