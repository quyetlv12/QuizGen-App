import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'auth_screen.dart';
import 'question_research_sheet.dart';
import 'quiz_tags.dart';
import 'profile_view.dart';
import 'learning_profile.dart';
import 'scan_screen.dart';
export 'scan_screen.dart';
import 'theme.dart';
import 'ui.dart';
import 'swipe_document_row.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(
    await SharedPreferences.getInstance(),
    requireAccount: true,
  );
  runApp(QuizMindApp(controller: controller));
  controller.start();
}

class QuizMindApp extends StatelessWidget {
  final AppController controller;
  const QuizMindApp({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (_, _) => MaterialApp(
      // A changed connection discards routes, selected files and quiz objects.
      key: ValueKey(controller.connectionGeneration),
      debugShowCheckedModeBanner: false,
      title: 'QuizGen AI',
      theme: appTheme(),
      home: controller.requireAccount && controller.user == null
          ? AuthScreen(controller: controller)
          : HomeScreen(
              c: controller,
              initialTab:
                  controller.requireAccount ||
                      controller.connectionGeneration == 0
                  ? 0
                  : 3,
            ),
    ),
  );
}

void errorMessage(BuildContext context, Object error) =>
    showAppToast(context, error.toString());
void openScreen(BuildContext context, Widget screen) =>
    Navigator.of(context).push(AppPageRoute<void>(builder: (_) => screen));
String dateLabel(dynamic value) {
  final d = DateTime.fromMillisecondsSinceEpoch(((value as num) * 1000).round())
      .toLocal();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

Widget panel(Widget child, {Color color = Colors.white}) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: color,
    border: Border.all(color: line),
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: forest.withValues(alpha: .05),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: child,
);
Widget heading(BuildContext context, String text) =>
    Text(text, style: Theme.of(context).textTheme.titleLarge);
Widget gap([double size = 20]) => SizedBox(height: size);

class PageBody extends StatelessWidget {
  final List<Widget> children;
  final ScrollController? controller;
  final bool behindNavigation;
  const PageBody({
    super.key,
    required this.children,
    this.controller,
    this.behindNavigation = false,
  });
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: !behindNavigation,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          controller: controller,
          primary: false,
          padding: EdgeInsets.fromLTRB(
            18,
            16,
            18,
            28 + (behindNavigation ? MediaQuery.paddingOf(context).bottom : 0),
          ),
          children: children,
        ),
      ),
    ),
  );
}

class EmptyView extends StatelessWidget {
  final String title, detail;
  final IconData icon;
  const EmptyView(
    this.title,
    this.detail, {
    super.key,
    this.icon = Icons.description_outlined,
  });
  @override
  Widget build(BuildContext context) => panel(
    Column(
      children: [
        Icon(icon, size: 36, color: green),
        gap(12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        gap(4),
        Text(detail, textAlign: TextAlign.center),
      ],
    ),
  );
}

class HomeScreen extends StatefulWidget {
  final AppController c;
  final int initialTab;
  const HomeScreen({super.key, required this.c, this.initialTab = 0});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int tab = widget.initialTab;
  String search = "";
  String? selectedTag;
  final searchText = TextEditingController();
  AppController get c => widget.c;

  @override
  void dispose() {
    searchText.dispose();
    super.dispose();
  }

  Widget documentRow(Json d) {
    final hasQuiz = c.items('quizzes').any((q) => q['documentId'] == d['id']);
    return SwipeDocumentRow(
      key: ValueKey('document-${d['id']}'),
      onRename: () async {
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _DocumentActionDialog(c: c, document: d),
        );
      },
      onDelete: () async {
        await deleteDocument(context, c, d);
      },
      child: StudyRow(
        leading: FileBadge(d['name']),
        title: d['name'],
        subtitle:
            '${(d['pages'] as List).length} trang · ${dateLabel(d['createdAt'])}',
        badge: hasQuiz && MediaQuery.sizeOf(context).width > 380
            ? const StatusPill('Đã tạo đề')
            : null,
        onTap: () => openScreen(context, DocumentScreen(c: c, document: d)),
      ),
    );
  }

  Widget quizRow(Json q) {
    final attempts = c.items('attempts').where((a) => a['quizId'] == q['id']);
    final last = attempts.isEmpty ? null : attempts.last;
    return StudyRow(
      leading: const MintIcon(Icons.eco_rounded),
      title: q['title'],
      subtitle:
          '${(q['questions'] as List).length} câu hỏi · ${dateLabel(q['createdAt'])}',
      badge: last == null
          ? null
          : StatusPill(
              '${((last['score'] as num) / (last['total'] as num) * 100).round()}%',
            ),
      footer: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...quizTags(c, q).map(
            (tag) => StatusPill(
              tag['name'],
              backgroundColor: tagColors(tag).fill,
              textColor: tagColors(tag).ink,
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => showQuizTags(context, c, q),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sell_outlined, size: 16, color: green),
                  SizedBox(width: 4),
                  Text('Gắn tag', style: TextStyle(color: green, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
      onTap: () => openScreen(context, QuizScreen(c: c, quiz: q)),
    );
  }

  Widget jobRow(Json j) {
    final stage = j['stage'];
    const labels = {
      'queued': 'Đang chờ',
      'extracting': 'Đang đọc tài liệu',
      'generating': 'AI đang tạo câu hỏi',
      'validating': 'Đang đối chiếu nguồn',
      'ready': 'Hoàn tất',
      'failed': 'Chưa hoàn tất',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: panel(
        Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: stage == 'ready'
                ? const Icon(Icons.check_circle_outline, color: green)
                : stage == 'failed'
                ? const Icon(Icons.error_outline, color: Colors.deepOrange)
                : const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
            title: Text(
              j['name'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(j['error'] ?? labels[stage] ?? stage),
            trailing: stage == 'ready'
                ? const Icon(Icons.open_in_new, size: 20)
                : null,
            onTap: stage != 'ready'
                ? null
                : () {
                    if (j['quizId'] != null) {
                      final found = c
                          .items('quizzes')
                          .where((q) => q['id'] == j['quizId']);
                      if (found.isNotEmpty) {
                        openScreen(
                          context,
                          QuizScreen(c: c, quiz: found.first),
                        );
                      }
                    } else {
                      final found = c
                          .items('documents')
                          .where((d) => d['id'] == j['documentId']);
                      if (found.isNotEmpty) {
                        openScreen(
                          context,
                          DocumentScreen(c: c, document: found.first),
                        );
                      }
                    }
                  },
          ),
        ),
      ),
    );
  }

  List<Widget> home() {
    final docs = c.items('documents'),
        quizzes = c.items('quizzes'),
        attempts = c.items('attempts');
    final average = attempts.isEmpty
        ? 0
        : (attempts.fold<double>(
                    0,
                    (sum, a) => sum + (a['score'] as num) / (a['total'] as num),
                  ) /
                  attempts.length *
                  100)
              .round();
    final activeJobs = c
        .items('jobs')
        .where((j) => j['stage'] != 'ready')
        .toList();
    return [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chào bạn',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                gap(5),
                const Text(
                  'Hôm nay bạn muốn ôn gì?',
                  style: TextStyle(fontSize: 16, color: muted),
                ),
              ],
            ),
          ),
          const RobotArt(size: 112),
        ],
      ),
      Container(
        decoration: BoxDecoration(
          gradient: greenGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => openScreen(context, ImportScreen(c: c)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                children: [
                  Container(
                    width: 49,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEFFE9),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.file_upload_outlined,
                      color: forest,
                      size: 31,
                    ),
                  ),
                  Container(
                    height: 51,
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: Colors.white.withValues(alpha: .55),
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tạo bài trắc nghiệm',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tải tài liệu lên và để AI tạo câu hỏi cho bạn',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 25,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      gap(16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: mint,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 65,
              height: 65,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: average / 100,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      backgroundColor: const Color(0xFFCDEFD3),
                      color: green,
                    ),
                  ),
                  Text(
                    '$average%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Color(0xFFB9E4C8)),
                    right: BorderSide(color: Color(0xFFB9E4C8)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.layers_outlined, color: green, size: 22),
                    const Text('Đã làm', style: TextStyle(fontSize: 12)),
                    Text(
                      '${attempts.map((a) => a['quizId']).toSet().length} bộ đề',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.track_changes_rounded,
                      color: green,
                      size: 22,
                    ),
                    const Text(
                      'Điểm trung bình',
                      style: TextStyle(fontSize: 11),
                    ),
                    Text(
                      attempts.isEmpty ? '—' : '$average%',
                      style: const TextStyle(
                        fontSize: 20,
                        color: green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      gap(17),
      SectionTitle(
        'Tài liệu gần đây',
        icon: Icons.description_outlined,
        onAll: () => setState(() => tab = 1),
      ),
      gap(8),
      if (docs.isEmpty)
        const EmptyView(
          'Thư viện đang chờ bạn',
          'Thêm tài liệu đầu tiên để bắt đầu ôn tập.',
        )
      else
        ...docs.take(2).map(documentRow),
      gap(12),
      SectionTitle(
        'Bộ đề gần đây',
        icon: Icons.assignment_outlined,
        onAll: () => setState(() => tab = 2),
      ),
      gap(8),
      if (quizzes.isEmpty)
        const EmptyView(
          'Chưa có bộ đề',
          'Chọn tài liệu để tạo bộ câu hỏi đầu tiên.',
          icon: Icons.assignment_outlined,
        )
      else
        ...quizzes.take(2).map(quizRow),
      if (activeJobs.isNotEmpty) ...[
        gap(16),
        heading(context, 'Tác vụ gần đây'),
        gap(12),
        ...activeJobs.take(3).map(jobRow),
      ],
    ];
  }

  List<Widget> library() => [
    Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 8, 16),
      decoration: BoxDecoration(
        gradient: greenGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Tạo trắc nghiệm AI',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Tải tài liệu lên, AI sẽ đọc và tạo câu hỏi trắc nghiệm.',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          const RobotArt(size: 120),
        ],
      ),
    ),
    gap(16),
    TextField(
      controller: searchText,
      onChanged: (v) => setState(() => search = v),
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search, color: forest),
        hintText: 'Tìm tài liệu của bạn…',
      ),
    ),
    gap(18),
    UploadZone(onTap: () => openScreen(context, ImportScreen(c: c))),
    gap(14),
    const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FileTypeChip('PDF', Icons.picture_as_pdf_outlined),
        FileTypeChip('TXT / MD', Icons.description_outlined),
        FileTypeChip('JPG / PNG', Icons.image_outlined),
      ],
    ),
    gap(8),
    const Text(
      'PDF tối đa 20 trang · Tổng tệp tối đa 12 MB',
      style: TextStyle(fontSize: 12, color: muted),
    ),
    gap(20),
    const SectionTitle('Tài liệu gần đây', icon: Icons.description_outlined),
    gap(12),
    if (c.items('documents').isEmpty)
      const EmptyView(
        'Chưa có tài liệu',
        'Hỗ trợ PDF, văn bản và ảnh chụp rõ chữ.',
      )
    else if (c
        .items('documents')
        .where(
          (d) => (d['name'] as String).toLowerCase().contains(
            search.toLowerCase(),
          ),
        )
        .isEmpty)
      const EmptyView(
        'Không tìm thấy tài liệu',
        'Thử tìm bằng tên khác.',
        icon: Icons.search,
      )
    else
      ...c
          .items('documents')
          .where(
            (d) => (d['name'] as String).toLowerCase().contains(
              search.toLowerCase(),
            ),
          )
          .map(documentRow),
  ];
  List<Widget> quizzes() {
    final activeTag = c.items('tags').any((t) => t['id'] == selectedTag)
        ? selectedTag
        : null;
    final filtered = c
        .items('quizzes')
        .where(
          (q) =>
              activeTag == null ||
              ((q['tagIds'] as List?) ?? []).contains(activeTag),
        )
        .toList();
    return [
      Row(
        children: [
          Expanded(child: heading(context, 'Bộ đề của tôi')),
          IconButton(
            tooltip: 'Quản lý thẻ Tag',
            onPressed: () => showQuizTags(context, c),
            icon: const Icon(Icons.sell_outlined, color: green),
          ),
        ],
      ),
      gap(8),
      const Text('Mỗi câu hỏi đều có giải thích và trích dẫn nguồn.'),
      gap(24),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tag in <Json>[
              {'id': null, 'name': 'Tất cả'},
              ...c.items('tags'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(tag['name']),
                  selected: tag['id'] == activeTag,
                  selectedColor: tagColors(tag).ink,
                  showCheckmark: false,
                  backgroundColor: tag['id'] == null
                      ? null
                      : tagColors(tag).fill,
                  labelStyle: TextStyle(
                    color: tag['id'] == activeTag
                        ? Colors.white
                        : tagColors(tag).ink,
                  ),
                  shape: const StadiumBorder(),
                  onSelected: (_) =>
                      setState(() => selectedTag = tag['id'] as String?),
                ),
              ),
          ],
        ),
      ),
      gap(16),
      if (c.items('quizzes').isEmpty)
        const EmptyView(
          'Bộ đề đầu tiên đang chờ',
          'Mở một tài liệu và chọn Tạo câu hỏi với AI.',
          icon: Icons.quiz_outlined,
        )
      else
        ...filtered.map(quizRow),
      if (activeTag != null && filtered.isEmpty)
        const EmptyView(
          'Chưa có bộ đề với tag này',
          'Chọn Tất cả để gắn tag cho bộ đề.',
          icon: Icons.sell_outlined,
        ),
      if (c.items('attempts').isNotEmpty) ...[
        gap(20),
        heading(context, 'Kết quả đã lưu'),
        gap(12),
        ...c.items('attempts').map((a) {
          final q = c
              .items('quizzes')
              .firstWhere((q) => q['id'] == a['quizId']);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: panel(
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(q['title']),
                subtitle: Text(dateLabel(a['createdAt'])),
                trailing: Text(
                  '${a['score']}/${a['total']}',
                  style: const TextStyle(
                    color: green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => openScreen(
                  context,
                  ResultScreen(c: c, quiz: q, attempt: a),
                ),
              ),
            ),
          );
        }),
      ],
    ];
  }

  List<Widget> profile() => [
    ProfileView(
      name: c.user?['name'] as String? ?? 'Không gian của bạn',
      email: c.user?['email'] as String? ?? 'Sẵn sàng cho buổi ôn tập mới',
      role: accountRoles[c.user?['role']] ?? 'Người dùng',
      documents: c.items('documents').length,
      quizzes: c.items('quizzes').length,
      attempts: c.items('attempts').length,
      onStatistics: () => openScreen(context, LearningStatsScreen(c: c)),
      onPersonalization: () =>
          openScreen(context, LearningPreferencesScreen(c: c)),
      onDocuments: () => setState(() => tab = 1),
      onQuizzes: () => setState(() => tab = 2),
      onLogout: c.user == null ? null : c.logout,
    ),
  ];

  void showNotifications() => openScreen(
    context,
    ListenableBuilder(
      listenable: c,
      builder: (context, _) => Scaffold(
        body: PageBody(
          children: [
            const PageTitle('Thông báo hệ thống'),
            gap(20),
            if (!c.connected) ...[
              Text(c.error ?? 'Đang kết nối dịch vụ…'),
              TextButton(onPressed: c.refresh, child: const Text('Thử lại')),
              gap(12),
            ],
            if (c.items('jobs').isEmpty)
              const EmptyView(
                'Chưa có thông báo',
                'Trạng thái đọc tài liệu và tạo câu hỏi sẽ xuất hiện ở đây.',
                icon: Icons.notifications_none_rounded,
              )
            else
              ...c.items('jobs').reversed.map(jobRow),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final notice = c.takeJobNotice();
      if (notice != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showAppToast(
            context,
            notice.success
                ? 'Đã tạo xong bộ câu hỏi: ${notice.name}'
                : 'Tạo câu hỏi chưa hoàn tất: ${notice.error ?? notice.name}',
            success: notice.success,
          );
        });
      }
      return Scaffold(
        extendBody: true,
        appBar: BrandBar(onNotifications: showNotifications),
        body: Column(
          children: [
            if (!c.connected)
              MaterialBanner(
                content: Text(c.error ?? 'Đang kết nối dịch vụ trên Mac…'),
                actions: [
                  TextButton(
                    onPressed: c.refresh,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            Expanded(
              child: SmoothTabBody(
                index: tab,
                children: [
                  PageBody(
                    behindNavigation: true,
                    children: [...home(), gap(72)],
                  ),
                  PageBody(
                    behindNavigation: true,
                    children: [...library(), gap(72)],
                  ),
                  PageBody(
                    behindNavigation: true,
                    children: [...quizzes(), gap(72)],
                  ),
                  PageBody(
                    behindNavigation: true,
                    children: [...profile(), gap(72)],
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: AiChatLauncher(
          onPressed: () => openScreen(context, ChatScreen(c: c)),
        ),
        bottomNavigationBar: StudyNavigation(
          selected: tab,
          onScan: () =>
              openScreen(context, ImportScreen(c: c, startWithScanner: true)),
          onChanged: (v) => setState(() => tab = v),
        ),
      );
    },
  );
}

class ImportFile {
  final String name;
  final Uint8List bytes;
  ImportFile(this.name, this.bytes);
  bool get isImage =>
      RegExp(r'\.(png|jpe?g)$', caseSensitive: false).hasMatch(name);
}

class ChatScreen extends StatefulWidget {
  final AppController c;
  const ChatScreen({super.key, required this.c});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  final messages = <({bool user, String text})>[];
  int count = 10;
  String? requestId;
  bool sending = false;
  late final int generation = widget.c.connectionGeneration;
  bool get busy =>
      sending || (job != null && !['ready', 'failed'].contains(job!['stage']));

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Json? get job {
    final id = requestId;
    if (id == null) return null;
    for (final item in widget.c.items('jobs')) {
      if (item['requestId'] == id) return item;
    }
    return null;
  }

  Future<void> send() async {
    final prompt = input.text.trim();
    if (busy || prompt.length < 10) {
      if (prompt.isNotEmpty && prompt.length < 10) {
        errorMessage(context, 'Hãy mô tả yêu cầu ít nhất 10 ký tự.');
      }
      return;
    }
    final id = newId();
    setState(() {
      messages.add((user: true, text: prompt));
      messages.add((
        user: false,
        text: 'Mình đang tạo bộ đề từ yêu cầu của bạn…',
      ));
      input.clear();
      requestId = id;
      sending = true;
    });
    try {
      await widget.c.send('/api/chat', {
        'requestId': id,
        'name': 'Bộ đề từ chat',
        'prompt': prompt,
        'count': count,
      }, expectedGeneration: generation);
    } catch (e) {
      if (mounted) {
        setState(() {
          sending = false;
          messages.add((user: false, text: 'Mình chưa thể gửi yêu cầu: $e'));
        });
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void openQuiz(Json j) {
    final quizId = j['quizId'];
    if (quizId == null) return;
    final found = widget.c.items('quizzes').where((q) => q['id'] == quizId);
    if (found.isNotEmpty) {
      openScreen(context, QuizScreen(c: widget.c, quiz: found.first));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.c,
    builder: (context, _) {
      final current = job;
      final isBusy = busy;
      return Scaffold(
        body: PageBody(
          children: [
            const PageTitle(
              'Chat với AI',
              trailing: MintIcon(Icons.school_rounded, size: 48),
            ),
            gap(8),
            const Text(
              'Mô tả chủ đề, lớp học và số câu. AI sẽ tạo bộ đề để bạn làm ngay.',
              style: TextStyle(color: muted),
            ),
            if (messages.isEmpty) ...[gap(20), const _ChatWelcome()],
            gap(22),
            const _ChatHeading('Số câu hỏi', Icons.layers_outlined),
            gap(10),
            Row(
              children: [
                for (final n in [5, 10, 15]) ...[
                  if (n != 5) const SizedBox(width: 8),
                  Expanded(
                    child: ChoicePill(
                      '$n câu',
                      icon: count == n ? Icons.check_circle_rounded : null,
                      selected: count == n,
                      onTap: isBusy ? null : () => setState(() => count = n),
                    ),
                  ),
                ],
              ],
            ),
            if (messages.isEmpty) ...[
              gap(24),
              const _ChatHeading('Gợi ý câu lệnh', Icons.auto_awesome_rounded),
              gap(6),
              const Text(
                'Chọn một gợi ý hoặc nhập câu lệnh của riêng bạn.',
                style: TextStyle(color: muted),
              ),
              gap(14),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final suggestion in const [
                      (
                        label: 'Toán lớp 6',
                        icon: Icons.calculate_rounded,
                        topic: 'Toán lớp 6 về phân số',
                      ),
                      (
                        label: 'Sinh học lớp 9',
                        icon: Icons.eco_rounded,
                        topic: 'Sinh học lớp 9 về hệ hô hấp',
                      ),
                      (
                        label: 'Lịch sử lớp 8',
                        icon: Icons.account_balance_rounded,
                        topic: 'Lịch sử lớp 8 về cách mạng công nghiệp',
                      ),
                    ])
                      SizedBox(
                        width:
                            constraints.maxWidth < 350 ||
                                MediaQuery.textScalerOf(context).scale(14) > 17
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 16) / 3,
                        child: _ChatSuggestion(
                          label: suggestion.label,
                          icon: suggestion.icon,
                          onTap: isBusy
                              ? null
                              : () {
                                  final text =
                                      'Tạo $count câu ${suggestion.topic}';
                                  input.value = TextEditingValue(
                                    text: text,
                                    selection: TextSelection.collapsed(
                                      offset: text.length,
                                    ),
                                  );
                                },
                        ),
                      ),
                  ],
                ),
              ),
              gap(22),
              const _ChatTips(),
            ],
            gap(18),
            ...messages.map(
              (message) => Align(
                alignment: message.user
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 560),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: message.user ? forest : mint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.user ? Colors.white : ink,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
            if (current != null && current['stage'] == 'ready') ...[
              gap(4),
              panel(
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: green),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Bộ đề đã sẵn sàng. Bạn có thể mở và làm ngay.',
                      ),
                    ),
                    TextButton(
                      onPressed: () => openQuiz(current),
                      child: const Text('Mở bộ đề'),
                    ),
                  ],
                ),
              ),
            ] else if (current != null && current['stage'] == 'failed')
              panel(
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.deepOrange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        current['error'] ?? 'Tạo bộ đề chưa hoàn tất.',
                      ),
                    ),
                  ],
                ),
              ),
            if (isBusy) ...[gap(12), const AiThinkingIndicator()],
          ],
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: Center(
              heightFactor: 1,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 720),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  color: mint,
                  border: Border.all(color: line),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: input,
                        enabled: !isBusy,
                        maxLength: 4000,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => send(),
                        buildCounter: (
                          context, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => null,
                        decoration: InputDecoration(
                          hintText: 'Ví dụ: Tạo đề Toán lớp 6…',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: muted,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: const BorderSide(color: green),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: const BorderSide(
                              color: green,
                              width: 1.5,
                            ),
                          ),
                          suffixIcon: ValueListenableBuilder(
                            valueListenable: input,
                            builder: (context, value, _) => Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Text(
                                '${value.text.characters.length}/4000',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 46,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: isBusy ? null : send,
                      style: IconButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.send_rounded),
                      tooltip: 'Gửi yêu cầu',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ChatHeading extends StatelessWidget {
  final String title;
  final IconData icon;
  const _ChatHeading(this.title, this.icon);
  @override
  Widget build(BuildContext context) => Row(
    children: [
      MintIcon(icon, size: 32),
      const SizedBox(width: 10),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
    ],
  );
}

class _ChatWelcome extends StatelessWidget {
  const _ChatWelcome();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [mint, Color(0xFFDDF8E4)]),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        const RobotArt(size: 96),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chào bạn! 👋',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                gap(6),
                const Text(
                  'Hãy mô tả chủ đề và số câu muốn tạo, ví dụ: “Tạo 10 câu Sinh học lớp 9 về hệ hô hấp”.',
                  style: TextStyle(height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ChatSuggestion extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _ChatSuggestion({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: mint,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: line),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: green, size: 22),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label.replaceAll('lớp ', 'lớp\u00a0'),
                key: ValueKey(label),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
            if (MediaQuery.sizeOf(context).width >= 600)
              const Icon(Icons.chevron_right_rounded, size: 18, color: green),
          ],
        ),
      ),
    ),
  );
}

class _ChatTips extends StatelessWidget {
  const _ChatTips();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: mint,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ChatHeading('Mẹo nhập đề bài', Icons.lightbulb_outline_rounded),
        gap(12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final tip in const [
                    'Nêu rõ môn học, lớp học và chủ đề.',
                    'Chỉ định số câu hỏi bạn mong muốn.',
                    'Ví dụ: “Tạo 10 câu Vật lý lớp 8 về áp suất”, “Tạo 15 câu Tiếng Anh lớp 7 về thì hiện tại đơn”.',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '•  ',
                            style: TextStyle(
                              color: green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              tip,
                              style: const TextStyle(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (MediaQuery.sizeOf(context).width >= 380) ...[
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Icon(Icons.fact_check_rounded, size: 56, color: green),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

class _MintAction extends StatelessWidget {
  final String label;
  final IconData icon, trailing;
  final VoidCallback? onPressed;
  const _MintAction({
    required this.label,
    required this.icon,
    required this.trailing,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: mint,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              Icon(icon, color: forest, size: 25),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: forest,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(trailing, color: forest, size: 24),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ImportEmptyCard extends StatelessWidget {
  const _ImportEmptyCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: line, width: 1.5),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: const BoxDecoration(color: mint, shape: BoxShape.circle),
          child: const Icon(Icons.description_outlined, color: green, size: 34),
        ),
        const SizedBox(height: 13),
        Text(
          'Chọn tài liệu để bắt đầu',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        const Text(
          'Với nhiều ảnh, bạn có thể đổi thứ tự trang trước khi đọc.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 14, height: 1.35),
        ),
      ],
    ),
  );
}

class ImportScreen extends StatefulWidget {
  final AppController c;
  final bool startWithScanner;
  final bool startWithPicker;
  final Json? document;
  const ImportScreen({
    super.key,
    required this.c,
    this.startWithScanner = false,
    this.startWithPicker = false,
    this.document,
  });
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final formKey = GlobalKey<FormState>();
  late final int generation;
  @override
  void initState() {
    super.initState();
    generation = widget.c.connectionGeneration;
    widget.c.addListener(checkImport);
    title.text = widget.document?['name'] as String? ?? '';
    if (widget.startWithPicker) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) await pick();
      });
    }
    if (widget.startWithScanner) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          AppPageRoute<void>(
            builder: (_) => ScanScreen(onPhoto: photo, onCapture: addPhoto),
          ),
        );
        if (mounted && files.isEmpty) Navigator.pop(context);
      });
    }
  }

  final title = TextEditingController();
  final scroll = ScrollController();
  final files = <ImportFile>[];
  bool busy = false;
  String? importJobId;
  bool openingGenerator = false;

  void checkImport() {
    if (!mounted || importJobId == null || openingGenerator) return;
    if (generation != widget.c.connectionGeneration) {
      setState(() {
        importJobId = null;
        busy = false;
      });
      return;
    }
    final job = widget.c.items('jobs').where((j) => j['id'] == importJobId);
    if (job.isEmpty) return;
    final current = job.first;
    if (current['stage'] == 'failed') {
      setState(() {
        importJobId = null;
        requestId = newId();
        busy = false;
      });
      errorMessage(context, current['error'] ?? 'Không đọc được tài liệu.');
    } else if (current['stage'] == 'ready') {
      final documents = widget.c
          .items('documents')
          .where((d) => d['id'] == current['documentId']);
      if (documents.isEmpty) return;
      final document = documents.first;
      setState(() => openingGenerator = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != widget.c.connectionGeneration) return;
        Navigator.of(context).pushReplacement(
          AppPageRoute<void>(
            builder: (_) => DocumentScreen(c: widget.c, document: document),
          ),
        );
      });
    }
  }

  String requestId = newId();
  void addFiles(List<ImportFile> additions) {
    final all = [...files, ...additions];
    if (all.length > 10 || (all.length > 1 && all.any((f) => !f.isImage))) {
      throw ApiException('Chọn một tài liệu hoặc tối đa 10 ảnh.');
    }
    if (all.any((f) => f.bytes.isEmpty) ||
        all.fold<int>(0, (n, f) => n + f.bytes.length) > 12 * 1024 * 1024) {
      throw ApiException('Tổng tệp phải từ 1 byte đến 12 MB.');
    }
    setState(() {
      files.addAll(additions);
      requestId = newId();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) scroll.jumpTo(0);
    });
  }

  Future<void> pick() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'md', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
        withData: true,
      );
      if (result == null || !mounted) return;
      addFiles(
        result.files
            .map((f) => ImportFile(f.name, f.bytes ?? Uint8List(0)))
            .toList(),
      );
    } catch (e) {
      if (mounted) {
        errorMessage(
          context,
          e is ApiException ? e : 'Không mở được tệp. Hãy thử chọn lại.',
        );
      }
    }
  }

  Future<bool> addPhoto(XFile image) async {
    final bytes = await image.readAsBytes();
    if (!mounted) return false;
    addFiles([ImportFile(image.name, bytes)]);
    return true;
  }

  Future<bool> photo(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2400,
      );
      if (image == null) return false;
      return await addPhoto(image);
    } catch (_) {
      if (mounted) {
        errorMessage(
          context,
          'Không mở được ảnh/camera. Kiểm tra quyền truy cập hoặc chọn tệp.',
        );
      }
      return false;
    }
  }

  Future<void> submit() async {
    if (documentNameError(title.text) != null) {
      scroll.jumpTo(0);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) formKey.currentState!.validate();
      return;
    }
    setState(() => busy = true);
    try {
      final result = await widget.c.send(
        widget.document == null ? '/api/import' : '/api/update',
        {
          if (widget.document != null) 'documentId': widget.document!['id'],
          'requestId': requestId,
          'name': title.text.trim(),
          'files': files
              .map((f) => {'name': f.name, 'data': base64Encode(f.bytes)})
              .toList(),
        },
        expectedGeneration: generation,
      );
      if (mounted) {
        if (widget.document != null) {
          Navigator.pop(context, true);
        } else {
          setState(() => importJobId = result['id'] as String);
          checkImport();
        }
      }
    } catch (e) {
      if (mounted) errorMessage(context, e);
    } finally {
      if (mounted && importJobId == null) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    widget.c.removeListener(checkImport);
    title.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Form(
      key: formKey,
      child: PageBody(
        controller: scroll,
        children: [
          PageTitle(
            widget.document == null ? 'Thêm tài liệu' : 'Cập nhật tài liệu',
          ),
          if (widget.document != null) ...[
            gap(12),
            const Text(
              'Chọn file hoặc quét lại để thay nội dung. Bản cũ được giữ nếu đọc thất bại. Các bộ đề và kết quả đã có vẫn được giữ.',
              style: TextStyle(fontSize: 14, color: muted),
            ),
          ],
          gap(16),
          if (files.isNotEmpty) ...[
            TextFormField(
              key: const ValueKey('import-document-name'),
              controller: title,
              maxLength: 160,
              enabled: !busy,
              onChanged: (_) => requestId = newId(),
              validator: documentNameError,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(
                labelText: 'Tên tài liệu *',
                hintText: 'Ví dụ: Sinh học — Chương 1',
              ),
            ),
            gap(12),
          ],
          Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 12, 18),
            decoration: BoxDecoration(
              gradient: greenGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.document == null
                                ? 'Tạo trắc nghiệm AI'
                                : 'Cập nhật nguồn tài liệu',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 9),
                      Text(
                        widget.document == null
                            ? 'Tải tài liệu lên, AI sẽ đọc và tạo câu hỏi cho bạn.'
                            : 'Đọc bản mới để tạo bộ đề tiếp theo từ nội dung đã cập nhật.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.35,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                RobotArt(size: 100),
              ],
            ),
          ),
          gap(20),
          UploadZone(onTap: busy ? null : pick, showFileHints: true),
          gap(12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FileTypeChip('PDF', Icons.picture_as_pdf_outlined),
              FileTypeChip('TXT / MD', Icons.description_outlined),
              FileTypeChip('JPG / PNG', Icons.image_outlined),
              FileTypeChip('DOC', Icons.article_outlined),
            ],
          ),
          gap(10),
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: muted),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'PDF tối đa 20 trang · Tổng tệp tối đa 12 MB',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
            ],
          ),
          gap(16),
          GradientAction(
            'Chụp hoặc quét tài liệu',
            onPressed: busy
                ? null
                : () => openScreen(
                    context,
                    ScanScreen(onPhoto: photo, onCapture: addPhoto),
                  ),
            icon: Icons.document_scanner_outlined,
            trailing: Icons.chevron_right_rounded,
          ),
          gap(10),
          if (files.isEmpty) ...[
            _MintAction(
              label: 'Thư viện tài liệu mẫu',
              onPressed: busy
                  ? null
                  : () async {
                      final text = await rootBundle.load('assets/sample.txt');
                      if (mounted) {
                        addFiles([
                          ImportFile(
                            'Thư viện Mây — tài liệu mẫu.txt',
                            text.buffer.asUint8List(
                              text.offsetInBytes,
                              text.lengthInBytes,
                            ),
                          ),
                        ]);
                      }
                    },
              icon: Icons.menu_book_outlined,
              trailing: Icons.chevron_right_rounded,
            ),
            gap(24),
          ],
          if (files.isNotEmpty) ...[
            heading(context, 'Xem lại ${files.length} tệp'),
            gap(12),
            for (int i = 0; i < files.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (files[i].isImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            files[i].bytes,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox(
                              height: 80,
                              child: Center(
                                child: Text('Không xem trước được ảnh'),
                              ),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${i + 1}. ${files[i].name}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (i > 0)
                            IconButton(
                              tooltip: 'Đưa trang lên trên',
                              onPressed: busy
                                  ? null
                                  : () => setState(() {
                                      final f = files.removeAt(i);
                                      files.insert(i - 1, f);
                                      requestId = newId();
                                    }),
                              icon: const Icon(Icons.arrow_upward),
                            ),
                          IconButton(
                            tooltip: 'Bỏ tệp',
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                    files.removeAt(i);
                                    requestId = newId();
                                  }),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            gap(12),
            FilledButton.icon(
              onPressed: busy ? null : submit,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.text_snippet_outlined),
              label: Text(
                busy
                    ? importJobId == null
                          ? 'Đang gửi…'
                          : 'Đang đọc tài liệu…'
                    : widget.document == null
                    ? 'Đọc nội dung tài liệu'
                    : 'Đọc và cập nhật tài liệu',
              ),
            ),
          ] else
            const _ImportEmptyCard(),
          gap(20),
          const Text(
            'Chữ được trích xuất trên Mac. Bạn sẽ xem lại nội dung trước khi gửi tới API AI để tạo câu hỏi. Tệp gốc tạm thời được xóa sau khi đọc.',
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ],
      ),
    ),
  );
}

String? documentNameError(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Vui lòng nhập tên tài liệu.';
  if (name.runes.length > 160) return 'Tên tài liệu tối đa 160 ký tự.';
  return null;
}

String? questionCountError(String? value) {
  final n = int.tryParse(value?.trim() ?? '');
  return n == null || n < 1 || n > 100
      ? 'Vui lòng nhập số nguyên từ 1 đến 100.'
      : null;
}

class DocumentScreen extends StatefulWidget {
  final AppController c;
  final Json document;
  const DocumentScreen({super.key, required this.c, required this.document});
  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

const _difficultyOptions = {
  'auto': ('Tự động', 'AI điều chỉnh theo nội dung tài liệu'),
  'easy': ('Dễ', 'Câu hỏi cơ bản, nhận biết và ghi nhớ'),
  'medium': ('Trung bình', 'Câu hỏi thông hiểu và vận dụng'),
  'hard': ('Khó', 'Câu hỏi phân tích và vận dụng nâng cao'),
};
const _modeOptions = {
  'practice': ('Luyện tập', 'Xem đáp án và giải thích sau mỗi câu'),
  'exam': ('Kiểm tra', 'Xem đáp án và giải thích sau khi nộp bài'),
};

class _DocumentScreenState extends State<DocumentScreen> {
  String difficulty = 'auto';
  String mode = 'practice';

  Future<void> selectOption({required bool isDifficulty}) async {
    if (busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final options = isDifficulty ? _difficultyOptions : _modeOptions;
    final current = isDifficulty ? difficulty : mode;
    var pending = current;
    final selected = await showAppSheet<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => AppSheetBody(
          children: [
            Text(
              isDifficulty ? 'Chọn độ khó' : 'Chọn chế độ',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            gap(20),
            for (final entry in options.entries)
              SheetOptionCard(
                title: entry.value.$1,
                subtitle: entry.value.$2,
                icon: switch (entry.key) {
                  'auto' => Icons.auto_awesome_rounded,
                  'easy' => Icons.menu_book_rounded,
                  'medium' => Icons.layers_outlined,
                  'hard' => Icons.bar_chart_rounded,
                  'practice' => Icons.school_outlined,
                  _ => Icons.assignment_outlined,
                },
                selected: entry.key == pending,
                isChoice: true,
                onTap: () => setSheetState(() => pending = entry.key),
              ),
            gap(24),
            GradientAction(
              'Áp dụng',
              icon: Icons.auto_awesome_rounded,
              onPressed: () => Navigator.pop(ctx, pending),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null || selected == current) return;
    setState(() {
      if (isDifficulty) {
        difficulty = selected;
      } else {
        mode = selected;
      }
      requestId = newId();
    });
  }

  final formKey = GlobalKey<FormState>();
  late final TextEditingController title;
  final questionCount = TextEditingController(text: '5');
  final instructions = TextEditingController();
  late final int generation;
  @override
  void initState() {
    super.initState();
    generation = widget.c.connectionGeneration;
    title = TextEditingController(text: widget.document['name'] as String);
    final preferences = LearningPreferences.load(widget.c);
    difficulty = preferences.difficulty;
    instructions.text = preferences.instructions;
  }

  @override
  void dispose() {
    title.dispose();
    questionCount.dispose();
    instructions.dispose();
    super.dispose();
  }

  int? get count => int.tryParse(questionCount.text.trim());
  bool busy = false;
  String requestId = newId();
  Future<void> generate() async {
    final error =
        documentNameError(title.text) ?? questionCountError(questionCount.text);
    final valid = formKey.currentState!.validate();
    if (error != null) {
      if (valid) errorMessage(context, ApiException(error));
      return;
    }
    setState(() => busy = true);
    try {
      await widget.c.send('/api/generate', {
        'requestId': requestId,
        'documentId': widget.document['id'],
        'name': title.text.trim(),
        'count': count,
        'instructions': instructions.text.trim(),
        'difficulty': difficulty,
        'mode': mode,
      }, expectedGeneration: generation);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) errorMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> updateDocument({bool scan = false, bool upload = false}) async {
    final accepted = await Navigator.of(context).push<bool>(
      AppPageRoute<bool>(
        builder: (_) => ImportScreen(
          c: widget.c,
          document: widget.document,
          startWithScanner: scan,
          startWithPicker: upload,
        ),
      ),
    );
    // Return to the task list while extraction runs, avoiding a stale source.
    if (accepted == true && mounted) Navigator.pop(context);
  }

  Future<void> hide() async {
    if (await deleteDocument(context, widget.c, widget.document) && mounted) {
      Navigator.pop(context);
    }
  }

  Widget optionRow({required bool isDifficulty}) {
    final options = isDifficulty ? _difficultyOptions : _modeOptions;
    final value = options[isDifficulty ? difficulty : mode]!;
    return ListTile(
      key: ValueKey(isDifficulty ? 'difficulty-picker' : 'mode-picker'),
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 24,
      leading: Icon(
        isDifficulty
            ? Icons.signal_cellular_alt_rounded
            : Icons.school_outlined,
        color: green,
      ),
      title: Text(
        isDifficulty ? 'Độ khó' : 'Chế độ',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(value.$1, style: const TextStyle(color: forest)),
      trailing: const Icon(Icons.expand_more_rounded, color: muted),
      onTap: busy ? null : () => selectOption(isDifficulty: isDifficulty),
    );
  }

  Future<void> showDocumentActions() async {
    if (busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final action = await showAppSheet<String>(
      context: context,
      builder: (ctx) => AppSheetBody(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tài liệu',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Đóng',
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: muted),
              ),
            ],
          ),
          gap(12),
          Row(
            children: [
              FileBadge(widget.document['name']),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.document['name'],
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    Text(
                      '${(widget.document['pages'] as List).length} trang nội dung đã đọc',
                      style: const TextStyle(fontSize: 13, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          gap(24),
          Text('Thay thế tài liệu', style: Theme.of(ctx).textTheme.titleMedium),
          gap(6),
          const Text(
            'Chọn nguồn mới để đọc lại nội dung. Các bộ đề đã tạo vẫn được giữ.',
            style: TextStyle(fontSize: 13, color: muted),
          ),
          gap(16),
          for (final item in [
            (
              'scan',
              Icons.document_scanner_outlined,
              'Quét tài liệu mới',
              'Chụp từng trang bằng camera',
            ),
            (
              'upload',
              Icons.upload_file_outlined,
              'Tải tài liệu mới',
              'PDF, văn bản hoặc ảnh từ thiết bị',
            ),
          ])
            SheetOptionCard(
              title: item.$3,
              subtitle: item.$4,
              icon: item.$2,
              onTap: () => Navigator.pop(ctx, item.$1),
            ),
          gap(4),
          const Text(
            'Bản cũ được giữ nếu bạn hủy hoặc không đọc được tài liệu mới.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          gap(20),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.archive_outlined, color: muted),
            title: const Text('Ẩn tài liệu'),
            subtitle: const Text('Đưa tài liệu ra khỏi danh sách'),
            onTap: () => Navigator.pop(ctx, 'hide'),
          ),
        ],
      ),
    );
    if (!mounted || busy) return;
    if (action == 'scan') await updateDocument(scan: true);
    if (action == 'upload') await updateDocument(upload: true);
    if (action == 'hide') await hide();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.document,
        pages = (widget.document['pages'] as List).cast<String>();
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final narrow = MediaQuery.sizeOf(context).width < 360;
    return Scaffold(
      extendBody: false,
      body: Form(
        key: formKey,
        child: Column(
          children: [
            Expanded(
              child: PageBody(
                behindNavigation: true,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Stack(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(right: narrow ? 68 : 96),
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: mint,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: IconButton(
                                    tooltip: 'Quay lại',
                                    onPressed: () =>
                                        Navigator.maybePop(context),
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      color: green,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Tạo bộ đề',
                                    style: TextStyle(
                                      fontSize: narrow ? 24 : 28,
                                      height: 1.2,
                                      color: ink,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: RobotArt(size: narrow ? 68 : 96),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(
                              top: 62,
                              right: 76,
                              bottom: 16,
                            ),
                            child: Text(
                              'Tạo bài trắc nghiệm từ tài liệu của bạn',
                              style: TextStyle(fontSize: 14, color: muted),
                            ),
                          ),
                        ],
                      ),
                      gap(8),
                      panel(
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 300;
                            final selected = Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: mint,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_rounded,
                                    color: green,
                                    size: 18,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Đã chọn',
                                    style: TextStyle(
                                      color: green,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                            return InkWell(
                              key: const ValueKey('document-details'),
                              borderRadius: BorderRadius.circular(12),
                              onTap: busy ? null : showDocumentActions,
                              child: Row(
                                children: [
                                  FileBadge(d['name']),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d['name'],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: ink,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        gap(3),
                                        Text(
                                          '${pages.length} trang · ${dateLabel(d['createdAt'])}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: muted,
                                          ),
                                        ),
                                        if (compact) ...[gap(6), selected],
                                      ],
                                    ),
                                  ),
                                  if (!compact) ...[
                                    const SizedBox(width: 8),
                                    selected,
                                  ],
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: muted,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      gap(20),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: busy ? null : () => updateDocument(),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: SectionTitle(
                            'Cập nhật tài liệu',
                            icon: Icons.upload_file_outlined,
                          ),
                        ),
                      ),
                      gap(16),
                      TextFormField(
                        key: const ValueKey('generate-document-name'),
                        controller: title,
                        enabled: !busy,
                        maxLength: 160,
                        validator: documentNameError,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        onChanged: (_) => requestId = newId(),
                        decoration: InputDecoration(
                          labelText: 'Tên tài liệu *',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          labelStyle: const TextStyle(
                            color: green,
                            fontWeight: FontWeight.w600,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: green,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                      gap(16),
                      const SectionTitle(
                        'Cấu hình bộ đề',
                        icon: Icons.layers_outlined,
                      ),
                      gap(12),
                      panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: mint,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.help_outline_rounded,
                                    color: green,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Số lượng câu hỏi',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: ink,
                                        ),
                                      ),
                                      Text(
                                        'Chọn số câu hỏi cho bộ đề',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            gap(14),
                            Row(
                              children: [
                                for (final n in [5, 10, 15]) ...[
                                  if (n != 5) const SizedBox(width: 8),
                                  Expanded(
                                    child: Semantics(
                                      selected: count == n,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: count == n
                                              ? greenGradient
                                              : null,
                                          color: count == n ? null : mint,
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            minimumSize: const Size(48, 44),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            foregroundColor: count == n
                                                ? Colors.white
                                                : ink,
                                          ),
                                          onPressed: busy
                                              ? null
                                              : () => setState(() {
                                                  questionCount.text = '$n';
                                                  requestId = newId();
                                                }),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                if (count == n) ...[
                                                  const Icon(
                                                    Icons.check_rounded,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 5),
                                                ],
                                                Text(
                                                  '$n câu',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            gap(18),
                            TextFormField(
                              key: const ValueKey('question-count'),
                              controller: questionCount,
                              enabled: !busy,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              decoration: const InputDecoration(
                                labelText: 'Số câu hỏi tùy chọn',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                                helperText: 'Nhập số nguyên từ 1 đến 100',
                                helperMaxLines: 2,
                              ),
                              validator: questionCountError,
                              onChanged: (_) =>
                                  setState(() => requestId = newId()),
                            ),
                          ],
                        ),
                      ),
                      gap(14),
                      panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: mint,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.auto_fix_high_rounded,
                                    color: green,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Yêu cầu thêm cho AI (tùy chọn)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            gap(10),
                            TextFormField(
                              key: const ValueKey('generate-instructions'),
                              controller: instructions,
                              enabled: !busy,
                              minLines: 2,
                              maxLines: 4,
                              maxLength: 2000,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: (_) => requestId = newId(),
                              decoration: const InputDecoration(
                                counterText: '',
                                hintText: 'Ví dụ: Tạo câu hỏi dễ hơn, tập trung vào khái niệm chính...',
                                hintMaxLines: 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      gap(18),
                      optionRow(isDifficulty: true),
                      const Divider(height: 1),
                      optionRow(isDifficulty: false),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.subject_rounded,
                          color: green,
                        ),
                        title: const Text(
                          'Xem lại nội dung tài liệu',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text(
                          'Kiểm tra chữ trước khi gửi tới AI',
                          style: TextStyle(fontSize: 12),
                        ),
                        children: [
                          if ((d['warnings'] as List).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Chưa đọc được chữ ở trang: ${(d['warnings'] as List).join(', ')}. Bạn có thể nhập lại ảnh rõ hơn.',
                                style: const TextStyle(
                                  color: Colors.deepOrange,
                                ),
                              ),
                            ),
                          for (int i = 0; i < pages.length; i++) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: heading(context, 'Trang ${i + 1}'),
                            ),
                            gap(10),
                            panel(
                              SelectableText(
                                pages[i].isEmpty
                                    ? 'Không nhận diện được chữ.'
                                    : pages[i],
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                            gap(20),
                          ],
                        ],
                      ),
                      gap(12),
                      const Text(
                        'Nội dung chữ sẽ đi qua API AI đã cấu hình trên Mac. API local có thể dùng nhà cung cấp bên ngoài.',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GradientAction(
                          busy ? 'Đang gửi…' : 'Tạo câu hỏi với AI',
                          onPressed: busy ? null : generate,
                          icon: Icons.auto_awesome,
                        ),
                        if (busy)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(
                              semanticsLabel: 'Đang gửi yêu cầu tạo bộ đề',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: keyboardOpen
          ? null
          : StudyNavigation(
              selected: 2,
              onScan: () {
                if (!busy) updateDocument(scan: true);
              },
              onChanged: (tab) {
                if (busy) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  AppPageRoute<void>(
                    builder: (_) => HomeScreen(c: widget.c, initialTab: tab),
                  ),
                  (_) => false,
                );
              },
            ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final AppController c;
  final Json quiz;
  const QuizScreen({super.key, required this.c, required this.quiz});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  AudioPlayer? answerPlayer;
  Future<void> audioTask = Future.value();
  int audioRevision = 0;

  void playAnswerSound(bool correct) {
    final revision = ++audioRevision;
    audioTask = audioTask
        .then((_) async {
          if (!mounted || revision != audioRevision) return;
          final player = answerPlayer ??= (AudioPlayer()
            ..positionUpdater = null);
          await player.stop();
          if (!mounted || revision != audioRevision) return;
          await player.play(
            AssetSource(correct ? 'audio/correct.mp3' : 'audio/incorrect.mp3'),
          );
        })
        .catchError((Object error) {
          debugPrint('Không phát được âm thanh đáp án: $error');
        });
  }

  late final int generation;
  late List<int> answers;
  final marked = <int>{};
  String attemptId = newId();
  int index = 0;
  bool busy = false;
  DateTime startedAt = DateTime.now();
  Timer? timer;
  List<Json> get questions => (widget.quiz['questions'] as List).cast<Json>();
  late final String draftKey;
  int get elapsed =>
      DateTime.now().difference(startedAt).inSeconds.clamp(0, 86400 * 365);
  String get timeLabel =>
      '${(elapsed ~/ 60).toString().padLeft(2, '0')}:${(elapsed % 60).toString().padLeft(2, '0')}';
  @override
  void initState() {
    super.initState();
    generation = widget.c.connectionGeneration;
    draftKey = widget.c.localKey('draft-${widget.quiz['id']}');
    answers = List.filled(questions.length, -1);
    try {
      final raw = widget.c.prefs.getString(draftKey);
      if (raw != null) {
        final d = jsonDecode(raw);
        final a = (d['answers'] as List).cast<int>();
        if (d['id'] is String &&
            a.length == answers.length &&
            a.every((n) => n >= -1 && n < 4)) {
          answers = a;
          attemptId = d['id'];
          if (d['index'] is int &&
              d['index'] >= 0 &&
              d['index'] < questions.length) {
            index = d['index'];
          }
          if (d['marked'] is List) {
            marked.addAll(
              (d['marked'] as List).whereType<int>().where(
                (i) => i >= 0 && i < questions.length,
              ),
            );
          }
          if (d['startedAt'] is int) {
            startedAt = DateTime.fromMillisecondsSinceEpoch(d['startedAt']);
          }
        }
      }
    } catch (_) {
      /* An invalid draft does not affect saved results. */
    }
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    audioRevision++;
    unawaited(
      audioTask
          .then((_) async {
            await answerPlayer?.dispose();
          })
          .catchError((Object error) {
            debugPrint('Không giải phóng được âm thanh đáp án: $error');
          }),
    );
    super.dispose();
  }

  Future<void> save() async {
    if (generation != widget.c.connectionGeneration) return;
    await widget.c.prefs.setString(
      draftKey,
      jsonEncode({
        'id': attemptId,
        'answers': answers,
        'index': index,
        'marked': marked.toList(),
        'startedAt': startedAt.millisecondsSinceEpoch,
      }),
    );
  }

  Future<void> saveDraft() async {
    try {
      await save();
    } catch (_) {
      if (mounted) {
        errorMessage(
          context,
          'Không lưu được bài nháp. Giữ app mở cho đến khi nộp.',
        );
      }
    }
  }

  void move(int next) {
    setState(() => index = next);
    saveDraft();
  }

  Future<void> submit() async {
    if (busy) return;
    if (answers.contains(-1)) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Vẫn còn câu chưa trả lời'),
          content: Text(
            '${answers.where((a) => a == -1).length} câu bỏ trống sẽ tính là sai. Bạn muốn nộp bài?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Làm tiếp'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Nộp bài'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() => busy = true);
    try {
      await save();
      final result = await widget.c.send('/api/attempts', {
        'id': attemptId,
        'quizId': widget.quiz['id'],
        'answers': answers,
      }, expectedGeneration: generation);
      await widget.c.prefs.setInt(
        widget.c.localKey('duration-$attemptId'),
        elapsed,
      );
      await widget.c.prefs.remove(draftKey);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          AppPageRoute<void>(
            builder: (_) =>
                ResultScreen(c: widget.c, quiz: widget.quiz, attempt: result),
          ),
        );
      }
    } catch (e) {
      if (mounted) errorMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = questions[index];
    final showFeedback = widget.quiz['mode'] != 'exam' && answers[index] >= 0;
    final right = answers[index] == q['correct'];
    final feedbackColor = right ? green : Colors.deepOrange;
    return Scaffold(
      body: PageBody(
        children: [
          PageTitle(
            'Làm bài',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: mint,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, size: 22, color: green),
                  const SizedBox(width: 5),
                  Text(
                    timeLabel,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          gap(18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Câu ${index + 1} / ${questions.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${answers.where((a) => a >= 0).length} đã trả lời',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, color: muted),
                ),
              ),
            ],
          ),
          gap(10),
          LinearProgressIndicator(
            value: (index + 1) / questions.length,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: const Color(0xFFD7F4DE),
            color: green,
          ),
          gap(20),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF3FFF6), Color(0xFFDDF9E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: greenGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.eco_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      gap(12),
                      Text(
                        q['question'],
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.35,
                          color: ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const RobotArt(size: 88),
              ],
            ),
          ),
          gap(16),
          if (showFeedback) ...[
            Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: feedbackColor.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: feedbackColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          right
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: feedbackColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          right ? 'Chính xác!' : 'Chưa chính xác',
                          style: TextStyle(
                            color: feedbackColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    gap(8),
                    Text(
                      'Đáp án đúng: ${String.fromCharCode(65 + (q['correct'] as int))}. ${q['options'][q['correct']]}',
                      style: const TextStyle(
                        color: green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    gap(8),
                    Text(q['explanation']),
                    gap(8),
                    TextButton.icon(
                      onPressed: () => showQuestionResearch(
                        context,
                        widget.c,
                        widget.quiz['id'],
                        index,
                        q,
                      ),
                      icon: const Icon(Icons.travel_explore_rounded),
                      label: const Text('Tìm hiểu thêm'),
                    ),
                  ],
                ),
              ),
            ),
            gap(12),
          ],
          for (int i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Semantics(
                selected: answers[index] == i,
                button: true,
                child: Container(
                  decoration: BoxDecoration(
                    color: showFeedback && i == q['correct']
                        ? mint
                        : answers[index] == i
                        ? (widget.quiz['mode'] == 'exam'
                              ? mint
                              : Colors.deepOrange.withValues(alpha: .08))
                        : Colors.white,
                    border: Border.all(
                      color: showFeedback && i == q['correct']
                          ? green
                          : answers[index] == i
                          ? (widget.quiz['mode'] == 'exam'
                                ? green
                                : Colors.deepOrange)
                          : line,
                      width: answers[index] == i ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: forest.withValues(alpha: .05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: busy
                          ? null
                          : () {
                              setState(() => answers[index] = i);
                              saveDraft();
                              if (widget.quiz['mode'] != 'exam') {
                                playAnswerSound(i == q['correct']);
                              }
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 35,
                              height: 35,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD9FCDD),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                String.fromCharCode(65 + i),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: green,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                q['options'][i],
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              showFeedback && i == q['correct']
                                  ? Icons.check_circle_rounded
                                  : answers[index] == i
                                  ? (widget.quiz['mode'] == 'exam'
                                        ? Icons.check_circle_rounded
                                        : Icons.cancel_rounded)
                                  : Icons.radio_button_unchecked_rounded,
                              color: showFeedback && i == q['correct']
                                  ? green
                                  : answers[index] == i
                                  ? (widget.quiz['mode'] == 'exam'
                                        ? green
                                        : Colors.deepOrange)
                                  : const Color(0xFF91A89C),
                              size: 25,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          gap(8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: mint,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: busy
                      ? null
                      : () {
                          setState(() {
                            if (!marked.add(index)) marked.remove(index);
                          });
                          saveDraft();
                        },
                  icon: Icon(
                    marked.contains(index)
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                  ),
                  label: Text(
                    marked.contains(index) ? 'Đã đánh dấu' : 'Đánh dấu',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: mint,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: busy
                      ? null
                      : () => move((index + 1) % questions.length),
                  icon: const Icon(Icons.fast_forward_outlined),
                  label: const Text('Bỏ qua'),
                ),
              ),
            ],
          ),
          if (marked.isNotEmpty) ...[
            gap(12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final i in marked.toList()..sort())
                  ActionChip(
                    avatar: const Icon(
                      Icons.bookmark_rounded,
                      size: 16,
                      color: green,
                    ),
                    label: Text('Câu ${i + 1}'),
                    onPressed: busy ? null : () => move(i),
                  ),
              ],
            ),
          ],
          gap(16),
          Text(
            widget.quiz['title'],
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          gap(4),
          const Text(
            'Lựa chọn được lưu nháp trên thiết bị để tiếp tục sau.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
      bottomNavigationBar: BottomActions(
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: mint,
                  minimumSize: const Size(48, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: busy || index == 0 ? null : () => move(index - 1),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Câu trước'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: GradientAction(
                busy
                    ? 'Đang lưu…'
                    : index < questions.length - 1
                    ? 'Câu tiếp theo'
                    : 'Nộp bài',
                onPressed: busy
                    ? null
                    : index < questions.length - 1
                    ? () => move(index + 1)
                    : submit,
                trailing: Icons.arrow_forward_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResultScreen extends StatefulWidget {
  final AppController c;
  final Json quiz, attempt;
  const ResultScreen({
    super.key,
    required this.c,
    required this.quiz,
    required this.attempt,
  });
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool showAllWrong = false;
  Json get quiz => widget.quiz;
  Json get attempt => widget.attempt;
  List<Json> get questions => (quiz['questions'] as List).cast<Json>();
  List<int> get wrong => [
    for (int i = 0; i < questions.length; i++)
      if (attempt['answers'][i] != questions[i]['correct']) i,
  ];
  void openAnswers({bool onlyWrong = false}) => openScreen(
    context,
    Scaffold(
      body: PageBody(
        children: [
          PageTitle(onlyWrong ? 'Ôn lại câu sai' : 'Đáp án & giải thích'),
          gap(16),
          const Text(
            'Đối chiếu nguồn khi cần. Nội dung AI có thể còn sai dù trích dẫn đã được kiểm tra.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          gap(16),
          for (int i = 0; i < questions.length; i++)
            if (!onlyWrong || wrong.contains(i)) ...[
              _answer(context, questions[i], attempt['answers'][i], i),
              gap(16),
            ],
        ],
      ),
    ),
  );

  Widget stat(
    IconData icon,
    String label,
    String value, {
    Color color = green,
  }) => Expanded(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 25),
        const SizedBox(width: 7),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: muted)),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final score = attempt['score'] as int, total = attempt['total'] as int;
    final percent = (score / total * 100).round();
    final duration = widget.c.prefs.getInt(
      widget.c.localKey('duration-${attempt['id']}'),
    );
    return Scaffold(
      extendBody: true,
      body: PageBody(
        behindNavigation: true,
        children: [
          const PageTitle('Kết quả'),
          gap(18),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 20, 4, 20),
            decoration: BoxDecoration(
              gradient: greenGradient,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        margin: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1FFF2),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: score / total,
                          strokeWidth: 9,
                          strokeCap: StrokeCap.round,
                          color: const Color(0xFF00A51D),
                          backgroundColor: const Color(0xFFCAEDCA),
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 64,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: Colors.white.withValues(alpha: .5),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$score/$total',
                        style: const TextStyle(
                          fontSize: 25,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'câu đúng',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      gap(5),
                      Text(
                        percent >= 80 ? 'Kết quả tốt!' : 'Cùng ôn lại nhé!',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const RobotArt(size: 90),
              ],
            ),
          ),
          gap(14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
            decoration: BoxDecoration(
              color: mint,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                stat(Icons.check_rounded, 'Đúng', '$score'),
                Container(height: 42, width: 1, color: line),
                stat(
                  Icons.close_rounded,
                  'Sai',
                  '${total - score}',
                  color: const Color(0xFFE63E25),
                ),
                Container(height: 42, width: 1, color: line),
                stat(
                  Icons.timer_outlined,
                  'Thời gian',
                  duration == null
                      ? '—'
                      : duration < 60
                      ? '${duration}s'
                      : '${duration ~/ 60} phút',
                ),
              ],
            ),
          ),
          gap(18),
          SectionTitle(
            'Câu cần ôn lại',
            icon: Icons.assignment_outlined,
            onAll: wrong.length <= 2
                ? null
                : () => setState(() => showAllWrong = !showAllWrong),
          ),
          gap(10),
          if (wrong.isEmpty)
            const EmptyView(
              'Bạn đã trả lời đúng tất cả!',
              'Tiếp tục giữ nhịp học tập nhé.',
              icon: Icons.task_alt_rounded,
            )
          else
            for (final i in wrong.take(showAllWrong ? wrong.length : 2))
              StudyRow(
                leading: const MintIcon(Icons.eco_rounded),
                title: 'Câu ${i + 1} · ${quiz['title']}',
                subtitle: questions[i]['question'],
                badge: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE7E1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Sai',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFCB2313),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                onTap: () => openScreen(
                  context,
                  Scaffold(
                    body: PageBody(
                      children: [
                        const PageTitle('Xem lại câu hỏi'),
                        gap(20),
                        _answer(
                          context,
                          questions[i],
                          attempt['answers'][i],
                          i,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          gap(12),
          GradientAction(
            'Xem đáp án & giải thích',
            onPressed: () => openAnswers(),
            icon: Icons.description_outlined,
            trailing: Icons.chevron_right,
          ),
          gap(10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushReplacement(
              context,
              AppPageRoute<void>(
                builder: (_) => QuizScreen(c: widget.c, quiz: quiz),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Làm lại bộ đề'),
          ),
          gap(10),
          if (wrong.isNotEmpty)
            Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: mint,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: () => openAnswers(onlyWrong: true),
                icon: const Icon(Icons.track_changes_rounded),
                label: const Text('Ôn lại câu sai'),
              ),
            ),
          gap(16),
          Text(
            quiz['title'],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          Text(
            dateLabel(attempt['createdAt']),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
      bottomNavigationBar: StudyNavigation(
        selected: 0,
        onScan: () => openScreen(
          context,
          ImportScreen(c: widget.c, startWithScanner: true),
        ),
        onChanged: (tab) => Navigator.pushAndRemoveUntil(
          context,
          AppPageRoute<void>(
            builder: (_) => HomeScreen(c: widget.c, initialTab: tab),
          ),
          (_) => false,
        ),
      ),
    );
  }

  Widget _answer(BuildContext context, Json q, int selected, int index) {
    final right = selected == q['correct'];
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                right ? Icons.check_circle_outline : Icons.cancel_outlined,
                color: right ? green : Colors.deepOrange,
              ),
              const SizedBox(width: 8),
              Text(
                'Câu ${index + 1} · ${right ? 'Chính xác' : 'Cần ôn lại'}',
                style: TextStyle(
                  color: right ? green : Colors.deepOrange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          gap(12),
          Text(q['question'], style: Theme.of(context).textTheme.titleMedium),
          gap(12),
          Text(
            'Bạn chọn: ${selected < 0 ? 'Bỏ trống' : q['options'][selected]}',
          ),
          gap(4),
          Text(
            'Đáp án: ${q['options'][q['correct']]}',
            style: const TextStyle(color: green, fontWeight: FontWeight.w600),
          ),
          gap(16),
          Text(q['explanation'], style: Theme.of(context).textTheme.bodyLarge),
          TextButton.icon(
            onPressed: () =>
                showQuestionResearch(context, widget.c, quiz['id'], index, q),
            icon: const Icon(Icons.travel_explore_rounded),
            label: const Text('Tìm hiểu thêm'),
          ),
          gap(16),
          Container(
            padding: const EdgeInsets.only(left: 14),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: green, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q['sourceType'] == 'ai'
                      ? 'NỘI DUNG DO AI TẠO'
                      : 'NGUỒN · TRANG ${q['page']}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                gap(6),
                SelectableText(
                  q['sourceType'] == 'ai' ? q['quote'] : '“${q['quote']}”',
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> deleteDocument(
  BuildContext context,
  AppController c,
  Json document,
) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _DocumentActionDialog(c: c, document: document, deleting: true),
    ) ??
    false;

class _DocumentActionDialog extends StatefulWidget {
  final AppController c;
  final Json document;
  final bool deleting;
  const _DocumentActionDialog({
    required this.c,
    required this.document,
    this.deleting = false,
  });
  @override
  State<_DocumentActionDialog> createState() => _DocumentActionDialogState();
}

class _DocumentActionDialogState extends State<_DocumentActionDialog> {
  late final title = TextEditingController(
    text: widget.document['name'] as String,
  );
  late final int generation;
  @override
  void initState() {
    super.initState();
    generation = widget.c.connectionGeneration;
  }

  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || (!widget.deleting && !form.currentState!.validate())) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.c.send(widget.deleting ? '/api/trash' : '/api/rename', {
        'documentId': widget.document['id'],
        if (!widget.deleting) 'name': title.text.trim(),
      }, expectedGeneration: generation);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(widget.deleting ? 'Xóa tài liệu?' : 'Đổi tên tài liệu'),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.deleting)
                Text(
                  'Xóa “${widget.document['name']}” khỏi thư viện? Bộ đề và kết quả liên quan cũng sẽ được ẩn. Dữ liệu vẫn còn trong bản lưu trên Mac.',
                )
              else
                TextFormField(
                  key: const ValueKey('rename-document-name'),
                  controller: title,
                  enabled: !busy,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Tên tài liệu'),
                  validator: documentNameError,
                  onFieldSubmitted: (_) => save(),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(
            busy
                ? 'Đang lưu…'
                : widget.deleting
                ? 'Xóa'
                : 'Lưu',
          ),
        ),
      ],
    ),
  );
}
