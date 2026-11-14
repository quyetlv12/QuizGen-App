import 'package:flutter/material.dart';

import 'theme.dart';
import 'ui.dart';

/// The account page shares the app's real navigation and account actions.
class ProfileView extends StatelessWidget {
  const ProfileView({
    super.key,
    required this.name,
    required this.email,
    required this.role,
    required this.documents,
    required this.quizzes,
    required this.attempts,
    required this.onStatistics,
    required this.onPersonalization,
    required this.onDocuments,
    required this.onQuizzes,
    required this.onLogout,
  });

  final String name, email, role;
  final int documents, quizzes, attempts;
  final VoidCallback onDocuments, onQuizzes, onStatistics, onPersonalization;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: 104,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 180,
                height: 70,
                decoration: BoxDecoration(
                  color: mint,
                  borderRadius: BorderRadius.circular(60),
                ),
              ),
            ),
            const Positioned(
              right: 12,
              bottom: -12,
              child: RobotArt(size: 125),
            ),
            Positioned(
              left: 6,
              top: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cá nhân',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, mint],
          ),
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: forest.withValues(alpha: .08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: line, width: 2),
                  ),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: greenGradient,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontSize: 24),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        style: const TextStyle(color: muted, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: mint,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: EdgeInsets.only(right: 5),
                                  child: Icon(
                                    Icons.person_outline_rounded,
                                    size: 17,
                                    color: green,
                                  ),
                                ),
                              ),
                              TextSpan(text: role),
                            ],
                          ),
                          style: const TextStyle(
                            color: forest,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      StudyRow(
        leading: const MintIcon(Icons.insights_outlined),
        title: 'Thống kê học tập',
        subtitle: 'Tiến độ, điểm số, điểm mạnh và điểm yếu',
        onTap: onStatistics,
      ),
      StudyRow(
        leading: const MintIcon(Icons.tune_rounded),
        title: 'Cá nhân hóa học tập',
        subtitle: 'Môn học, lớp, độ khó và mục tiêu',
        onTap: onPersonalization,
      ),
      StudyRow(
        leading: const MintIcon(Icons.description_outlined),
        title: 'Tài liệu của bạn',
        subtitle: '$documents tài liệu',
        onTap: onDocuments,
      ),
      StudyRow(
        leading: const MintIcon(Icons.quiz_outlined),
        title: 'Bộ đề và kết quả',
        subtitle: '$quizzes bộ đề · $attempts lượt làm bài',
        onTap: onQuizzes,
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 74, 12),
        decoration: BoxDecoration(
          color: mint,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: muted, size: 21),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Bài đang làm được lưu nháp trên thiết bị.',
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ),
          ],
        ),
      ),
      if (onLogout != null) ...[
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB42318),
              backgroundColor: const Color(0xFFFFEEEE),
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, size: 23),
            label: const Text('Đăng xuất'),
          ),
        ),
      ],
    ],
  );
}
