import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';
import 'ui.dart';

const tagPalette = <String, ({String name, Color ink, Color fill})>{
  'green': (name: 'Xanh lá', ink: Color(0xFF006B16), fill: Color(0xFFDDFDE3)),
  'blue': (name: 'Xanh dương', ink: Color(0xFF1555A0), fill: Color(0xFFE3EFFF)),
  'amber': (name: 'Vàng', ink: Color(0xFF805000), fill: Color(0xFFFFF1C7)),
  'red': (name: 'Đỏ', ink: Color(0xFFA32435), fill: Color(0xFFFFE6E9)),
  'teal': (name: 'Xanh ngọc', ink: Color(0xFF00675E), fill: Color(0xFFDDF5F0)),
  'gray': (name: 'Xám', ink: Color(0xFF455560), fill: Color(0xFFEAF0F3)),
};

({String name, Color ink, Color fill}) tagColors(Json tag) =>
    tagPalette[tag['color']] ?? tagPalette['green']!;

List<Json> quizTags(AppController c, Json quiz) => c
    .items('tags')
    .where((tag) => ((quiz['tagIds'] as List?) ?? []).contains(tag['id']))
    .toList();

Future<void> showQuizTags(
  BuildContext context,
  AppController c, [
  Json? quiz,
]) => showAppSheet<void>(
  context: context,
  builder: (_) => QuizTagSheet(c: c, quiz: quiz),
);

class QuizTagSheet extends StatefulWidget {
  final AppController c;
  final Json? quiz;
  const QuizTagSheet({super.key, required this.c, this.quiz});
  @override
  State<QuizTagSheet> createState() => _QuizTagSheetState();
}

class _QuizTagSheetState extends State<QuizTagSheet> {
  late final tags = widget.c.items('tags').map((t) => Json.from(t)).toList();
  late final selected = ((widget.quiz?['tagIds'] as List?) ?? [])
      .cast<String>()
      .toSet();
  late final generation = widget.c.connectionGeneration;
  final input = TextEditingController();
  String? editing, error;
  String color = 'green';
  bool busy = false;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<Json> send(String action, Json body) =>
      widget.c.send('/api/tags/$action', body, expectedGeneration: generation);

  Future<void> saveName() => run(() async {
    final tag = await send(editing == null ? 'create' : 'rename', {
      'name': input.text,
      'color': color,
      if (editing != null) 'tagId': editing,
    });
    if (!mounted) return;
    setState(() {
      if (editing == null) {
        tags.add(tag);
        if (widget.quiz != null) selected.add(tag['id'] as String);
      } else {
        tags[tags.indexWhere((t) => t['id'] == editing)] = tag;
      }
      editing = null;
      color = 'green';
      input.clear();
    });
  });

  Future<void> remove(Json tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoá tag?'),
        content: Text(
          'Tag “${tag['name']}” sẽ được gỡ khỏi tất cả bộ đề. Các bộ đề vẫn được giữ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoá tag'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await run(() async {
      await send('delete', {'tagId': tag['id']});
      if (!mounted) return;
      setState(() {
        tags.removeWhere((t) => t['id'] == tag['id']);
        selected.remove(tag['id']);
        if (editing == tag['id']) {
          editing = null;
          color = 'green';
          input.clear();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AppSheetBody(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Quản lý thẻ Tag',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Đóng',
              onPressed: busy ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.quiz == null
              ? 'Tạo và sắp xếp tag cho các bộ đề.'
              : 'Gắn thẻ để dễ tìm kiếm và tổ chức bộ đề.',
        ),
        if (widget.quiz != null) ...[
          const SizedBox(height: 20),
          Text(
            'Thẻ đã chọn · ${selected.length}',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 8),
          if (selected.isEmpty) const Text('Chưa chọn tag nào.'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .where((t) => selected.contains(t['id']))
                .map(
                  (tag) => InputChip(
                    label: Text(tag['name']),
                    backgroundColor: tagColors(tag).fill,
                    labelStyle: TextStyle(color: tagColors(tag).ink),
                    deleteIconColor: tagColors(tag).ink,
                    onDeleted: busy
                        ? null
                        : () => setState(() => selected.remove(tag['id'])),
                    deleteButtonTooltipMessage: 'Gỡ tag khỏi bộ đề',
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        const Text('Danh sách Tag', style: TextStyle(color: muted)),
        if (tags.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Chưa có tag. Tạo tag đầu tiên bên dưới.'),
          ),
        ...tags.map(
          (tag) => Row(
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.sell_outlined,
                    color: tagColors(tag).ink,
                    size: 22,
                  ),
                  title: Text(tag['name']),
                  trailing: widget.quiz == null
                      ? null
                      : Icon(
                          selected.contains(tag['id'])
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: selected.contains(tag['id']) ? green : muted,
                        ),
                  onTap: busy || widget.quiz == null
                      ? null
                      : () => setState(() {
                          if (!selected.add(tag['id'] as String)) {
                            selected.remove(tag['id']);
                          }
                        }),
                ),
              ),
              PopupMenuButton<String>(
                enabled: !busy,
                tooltip: 'Sửa hoặc xoá ${tag['name']}',
                onSelected: (value) {
                  if (value == 'delete') {
                    remove(tag);
                  } else {
                    setState(() {
                      editing = tag['id'];
                      input.text = tag['name'];
                      color = tagPalette.containsKey(tag['color'])
                          ? tag['color'] as String
                          : 'green';
                    });
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Đổi tên')),
                  PopupMenuItem(value: 'color', child: Text('Đổi màu')),
                  PopupMenuItem(value: 'delete', child: Text('Xoá tag')),
                ],
              ),
            ],
          ),
        ),
        const Divider(),
        const SizedBox(height: 12),
        Text(
          editing == null ? 'Tạo Tag mới' : 'Sửa Tag',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: input,
                enabled: !busy,
                maxLength: 40,
                decoration: const InputDecoration(
                  hintText: 'Nhập tên Tag…',
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (!busy && input.text.trim().isNotEmpty) saveName();
                },
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: green,
                backgroundColor: tagPalette['green']!.fill,
                disabledBackgroundColor: tagPalette['green']!.fill.withValues(
                  alpha: 0.45,
                ),
                minimumSize: const Size(88, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: busy || input.text.trim().isEmpty ? null : saveName,
              child: Text(editing == null ? '+ Thêm' : 'Lưu tag'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Màu tag', style: TextStyle(color: muted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tagPalette.entries
              .map(
                (entry) => Semantics(
                  button: true,
                  selected: color == entry.key,
                  label: 'Màu ${entry.value.name}',
                  child: Tooltip(
                    message: 'Màu ${entry.value.name}',
                    child: InkWell(
                      onTap: busy
                          ? null
                          : () => setState(() => color = entry.key),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: entry.value.fill,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color == entry.key
                                ? entry.value.ink
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          color == entry.key ? Icons.check : Icons.circle,
                          color: entry.value.ink,
                          size: color == entry.key ? 22 : 14,
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        if (editing != null)
          TextButton(
            onPressed: busy
                ? null
                : () => setState(() {
                    editing = null;
                    color = 'green';
                    input.clear();
                  }),
            child: const Text('Huỷ chỉnh sửa'),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: busy
                ? null
                : () => run(() async {
                    if (widget.quiz != null) {
                      await send('assign', {
                        'quizId': widget.quiz!['id'],
                        'tagIds': selected.toList(),
                      });
                    }
                    if (context.mounted) Navigator.pop(context);
                  }),
            child: Text(busy ? 'Đang lưu…' : 'Hoàn tất'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}
