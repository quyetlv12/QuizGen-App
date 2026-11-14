import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';
import 'ui.dart';

const accountRoles = {
  'user': 'Người dùng',
  'teacher': 'Giáo viên',
  'student': 'Học sinh, sinh viên',
};

class AuthScreen extends StatefulWidget {
  final AppController controller;
  const AuthScreen({super.key, required this.controller});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late final _address = TextEditingController(text: widget.controller.api.base);
  final _relayToken = TextEditingController();
  bool _register = false, _busy = false, _hidden = true;
  bool _connection = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _password,
      _confirm,
      _address,
      _relayToken,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.authenticate(
        email: _email.text,
        password: _password.text,
        name: _register ? _name.text : null,
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool password = false,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !_busy,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      obscureText: password && _hidden,
      autocorrect: !password && keyboardType != TextInputType.emailAddress,
      enableSuggestions: !password,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        hintText: label,
        filled: true,
        fillColor: Colors.white.withValues(alpha: .88),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCCDAD9)),
        ),
        prefixIcon: Icon(icon),
        suffixIcon: password
            ? IconButton(
                tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                onPressed: () => setState(() => _hidden = !_hidden),
                icon: Icon(
                  _hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              )
            : null,
      ),
      validator:
          validator ??
          (value) => value == null || value.trim().isEmpty
              ? 'Vui lòng nhập ${label.toLowerCase()}.'
              : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _AuthBackdrop())),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: AutofillGroup(
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: 'Kết nối dịch vụ',
                              onPressed: _busy
                                  ? null
                                  : () => setState(
                                      () => _connection = !_connection,
                                    ),
                              icon: const Icon(
                                Icons.settings_outlined,
                                size: 20,
                                color: muted,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.menu_book_rounded,
                                size: 42,
                                color: green,
                              ),
                              const SizedBox(width: 10),
                              Text.rich(
                                const TextSpan(
                                  text: 'QuizGen ',
                                  children: [
                                    TextSpan(
                                      text: 'AI',
                                      style: TextStyle(color: green),
                                    ),
                                  ],
                                ),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                          ),
                          if (!_register) ...[
                            const SizedBox(height: 20),
                            Image.asset(
                              'assets/robot.png',
                              height: 180,
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                            ),
                            const SizedBox(height: 16),
                          ] else
                            const SizedBox(height: 32),
                          Text(
                            _register ? 'Tạo tài khoản' : 'Chào mừng trở lại',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF073A23),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _register
                                ? 'Bắt đầu hành trình học tập của bạn'
                                : 'Đăng nhập để tiếp tục ôn tập',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: muted),
                          ),
                          const SizedBox(height: 28),
                          if (c.restoringAccount) ...[
                            const Center(child: CircularProgressIndicator()),
                            const SizedBox(height: 12),
                            const Text(
                              'Đang kiểm tra phiên đăng nhập…',
                              textAlign: TextAlign.center,
                            ),
                          ] else ...[
                            if (_register)
                              _field(
                                'Họ và tên',
                                _name,
                                Icons.person_outline,
                                autofillHints: const [AutofillHints.name],
                              ),
                            _field(
                              'Email',
                              _email,
                              Icons.mail_outline,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              validator: (v) =>
                                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(v?.trim() ?? '')
                                  ? null
                                  : 'Vui lòng nhập email hợp lệ.',
                            ),
                            _field(
                              'Mật khẩu',
                              _password,
                              Icons.lock_outline,
                              password: true,
                              autofillHints: [
                                _register
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              validator: (v) => (v ?? '').isEmpty
                                  ? 'Vui lòng nhập mật khẩu.'
                                  : _register && v!.length < 8
                                  ? 'Mật khẩu cần ít nhất 8 ký tự.'
                                  : null,
                            ),
                            if (_register) ...[
                              _field(
                                'Xác nhận mật khẩu',
                                _confirm,
                                Icons.lock_outline,
                                password: true,
                                validator: (v) =>
                                    v == _password.text && (v ?? '').isNotEmpty
                                    ? null
                                    : 'Mật khẩu xác nhận chưa khớp.',
                              ),
                            ],
                            if (_error ?? c.accountError
                                case final String message) ...[
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  message,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            GradientAction(
                              _busy
                                  ? 'Đang xử lý…'
                                  : _register
                                  ? 'Tạo tài khoản'
                                  : 'Đăng nhập',
                              onPressed: _busy ? null : _submit,
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  _register
                                      ? 'Đã có tài khoản?'
                                      : 'Chưa có tài khoản?',
                                ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() {
                                          _register = !_register;
                                          _error = null;
                                          c.accountError = null;
                                          _password.clear();
                                          _confirm.clear();
                                          _form.currentState?.reset();
                                        }),
                                  child: Text(
                                    _register ? 'Đăng nhập' : 'Đăng ký',
                                  ),
                                ),
                              ],
                            ),
                            if (c.accountError != null)
                              TextButton(
                                onPressed: _busy ? null : c.restoreAccount,
                                child: const Text('Kiểm tra lại phiên đã lưu'),
                              ),
                          ],
                          const SizedBox(height: 16),
                          if (_connection)
                            ExpansionTile(
                              initiallyExpanded: true,
                              tilePadding: EdgeInsets.zero,
                              title: const Text(
                                'Kết nối dịch vụ',
                                style: TextStyle(fontSize: 14),
                              ),
                              children: [
                                TextField(
                                  controller: _address,
                                  enabled: !_busy && !c.restoringAccount,
                                  decoration: const InputDecoration(
                                    labelText: 'Địa chỉ dịch vụ',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _relayToken,
                                  enabled: !_busy && !c.restoringAccount,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Mã truy cập dịch vụ (nếu cần)',
                                  ),
                                ),
                                TextButton(
                                  onPressed: _busy || c.restoringAccount
                                      ? null
                                      : () async {
                                          setState(() {
                                            _busy = true;
                                            _error = null;
                                          });
                                          try {
                                            await c.setAddress(
                                              _address.text.trim(),
                                              token: _relayToken.text.isEmpty
                                                  ? null
                                                  : _relayToken.text.trim(),
                                            );
                                          } catch (e) {
                                            if (mounted) {
                                              setState(
                                                () => _error = e.toString(),
                                              );
                                            }
                                          } finally {
                                            if (mounted) {
                                              setState(() => _busy = false);
                                            }
                                          }
                                        },
                                  child: const Text('Lưu kết nối'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthBackdrop extends CustomPainter {
  const _AuthBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE8FAED);
    canvas.drawOval(Rect.fromLTWH(-100, -105, 225, 255), paint);
    canvas.drawOval(Rect.fromLTWH(size.width - 130, -125, 245, 230), paint);
    canvas.drawOval(Rect.fromLTWH(-130, size.height - 65, 310, 200), paint);
    canvas.drawOval(
      Rect.fromLTWH(size.width - 175, size.height - 70, 340, 210),
      paint,
    );
  }

  @override
  bool shouldRepaint(_AuthBackdrop oldDelegate) => false;
}
