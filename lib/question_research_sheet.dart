import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'theme.dart';
import 'ui.dart';

Future<void> showQuestionResearch(
  BuildContext context,
  AppController controller,
  String quizId,
  int questionIndex,
  Json question,
) => showAppSheet<void>(
  context: context,
  builder: (_) => QuestionResearchSheet(
    controller: controller,
    quizId: quizId,
    questionIndex: questionIndex,
    question: question,
  ),
);

class QuestionResearchSheet extends StatefulWidget {
  const QuestionResearchSheet({
    super.key,
    required this.controller,
    required this.quizId,
    required this.questionIndex,
    required this.question,
  });
  final AppController controller;
  final String quizId;
  final int questionIndex;
  final Json question;

  @override
  State<QuestionResearchSheet> createState() => _QuestionResearchSheetState();
}

class _QuestionResearchSheetState extends State<QuestionResearchSheet> {
  late final int generation;
  Json? result;
  String? error;
  bool loading = true;

  bool get connectionChanged =>
      widget.controller.closed ||
      widget.controller.connectionGeneration != generation;

  @override
  void initState() {
    super.initState();
    generation = widget.controller.connectionGeneration;
    widget.controller.addListener(checkConnection);
    load();
  }

  void checkConnection() {
    if (connectionChanged && mounted) {
      setState(() {
        loading = false;
        result = null;
        error = 'Kết nối đã thay đổi. Đóng cửa sổ và mở lại câu hỏi.';
      });
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await widget.controller.api.request('/api/research', {
        'quizId': widget.quizId,
        'questionIndex': widget.questionIndex,
      });
      if (!mounted || connectionChanged) return;
      if (response['answer'] is! String || response['sources'] is! List) {
        throw ApiException('Phản hồi tra cứu không hợp lệ.');
      }
      for (final source in response['sources']) {
        if (source is! Json ||
            source['title'] is! String ||
            source['url'] is! String ||
            !RegExp(r'^https://vi\.wikipedia\.org/\?curid=\d+$')
                .hasMatch(source['url'])) {
          throw ApiException('Nguồn tra cứu không hợp lệ.');
        }
      }
      setState(() {
        result = response;
        loading = false;
      });
    } catch (e) {
      if (!mounted || connectionChanged) return;
      setState(() {
        loading = false;
        error = e is ApiException
            ? e.message
            : 'Chưa tra cứu được câu hỏi. Hãy thử lại.';
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(checkConnection);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .86,
    ),
    child: AppSheetBody(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tìm hiểu thêm',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Đóng',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'AI giải thích và tra cứu thêm trên Wikipedia.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: mint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Câu ${widget.questionIndex + 1}',
                style: const TextStyle(
                  color: green,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.question['question'],
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Đáp án bộ đề: ${widget.question['options'][widget.question['correct']]}',
                style: const TextStyle(color: forest),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (loading) ...[
          const AiThinkingIndicator(),
          const SizedBox(height: 12),
          const Text(
            'AI đang tìm hiểu câu hỏi…',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Đang chọn từ khóa, tìm nguồn và tổng hợp nội dung. Bạn có thể đóng cửa sổ này.',
            style: TextStyle(color: muted, height: 1.5),
          ),
        ] else if (error != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              error!,
              style: const TextStyle(color: Colors.deepOrange, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          if (!connectionChanged)
            OutlinedButton.icon(
              onPressed: load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
        ] else if (result != null) ...[
          Semantics(
            liveRegion: true,
            child: const Text(
              'Kiến thức mở rộng',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            result!['answer'],
            style: const TextStyle(fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: 20),
          if ((result!['sources'] as List).isEmpty)
            const Text(
              'Chưa tìm được nguồn Wikipedia phù hợp. Nội dung trên do AI giải thích và chưa được kiểm chứng.',
              style: TextStyle(color: muted, height: 1.5),
            )
          else ...[
            const Text(
              'Nguồn tham khảo',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final source in result!['sources'])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.public_rounded, color: green),
                title: Text(source['title']),
                subtitle: SelectableText(source['url']),
                trailing: IconButton(
                  tooltip: 'Sao chép liên kết',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: source['url']));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép liên kết nguồn'),
                        ),
                      );
                    }
                  },
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'AI có thể sai. Hãy đối chiếu nguồn và ngữ cảnh trước khi sử dụng.',
              style: TextStyle(color: muted, height: 1.5),
            ),
          ],
        ],
      ],
    ),
  );
}
