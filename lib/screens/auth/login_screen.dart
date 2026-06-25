import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/auth_text_field.dart';
import '../../components/brand_logo_badge.dart';
import '../../components/pitch_pattern_background.dart';
import '../../core/validators.dart';
import '../../router/route_paths.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_localizations.dart';

/// Giriş / Kayıt ekranı.
///
/// "Giriş Yap" ve "Kayıt Ol" sekmeleri arasında animasyonlu yeşil underline
/// ([TabController] + [TabBar]) ile geçiş yapılır. Tüm renkler tema üzerinden
/// gelir.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginUsername = TextEditingController();
  final _loginPassword = TextEditingController();

  final _registerUsername = TextEditingController();
  final _registerEmail = TextEditingController();
  final _registerPassword = TextEditingController();
  final _registerConfirm = TextEditingController();

  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureRegisterConfirm = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginUsername.dispose();
    _loginPassword.dispose();
    _registerUsername.dispose();
    _registerEmail.dispose();
    _registerPassword.dispose();
    _registerConfirm.dispose();
    super.dispose();
  }

  /// Kullanıcı adı + şifre ile giriş.
  Future<void> _login() => _runAuth(
        _loginFormKey,
        () => ref.read(authServiceProvider).signIn(
              username: _loginUsername.text,
              password: _loginPassword.text,
            ),
      );

  /// Yeni hesap oluşturma (kayıt sonrası kullanıcı otomatik oturum açar).
  Future<void> _register() => _runAuth(
        _registerFormKey,
        () => ref.read(authServiceProvider).register(
              username: _registerUsername.text,
              email: _registerEmail.text,
              password: _registerPassword.text,
            ),
      );

  /// Google ile giriş. İptal edilirse sessizce geri döner.
  Future<void> _signInWithGoogle() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final signedIn = await ref.read(authServiceProvider).signInWithGoogle();
      if (!mounted) return;
      if (signedIn) context.goNamed(RoutePaths.homeName);
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        _showError(l10n.unknownError);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Form doğrulama, loading durumu ve hata yönetimini ortak yürüten yardımcı.
  Future<void> _runAuth(
    GlobalKey<FormState> formKey,
    Future<void> Function() action,
  ) async {
    if (_loading) return;
    final form = formKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      await action();
      if (!mounted) return;
      context.goNamed(RoutePaths.homeName);
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        _showError(l10n.unknownError);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: scheme.onError)),
          backgroundColor: scheme.error,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: PitchPatternBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      _Header()
                          .animate()
                          .fadeIn(duration: 600.ms)
                          .slideY(begin: 0.15, end: 0),
                      const SizedBox(height: 32),
                      _AuthCard(
                        tabController: _tabController,
                        loginForm: _buildLoginForm(theme, l10n),
                        registerForm: _buildRegisterForm(theme, l10n),
                        l10n: l10n,
                      )
                          .animate()
                          .fadeIn(delay: 150.ms, duration: 600.ms)
                          .slideY(begin: 0.15, end: 0),
                      const SizedBox(height: 20),
                      _OrDivider(l10n: l10n)
                          .animate()
                          .fadeIn(delay: 250.ms, duration: 500.ms),
                      const SizedBox(height: 16),
                      _GoogleButton(
                        loading: _loading,
                        onPressed: _signInWithGoogle,
                        l10n: l10n,
                      )
                          .animate()
                          .fadeIn(delay: 300.ms, duration: 500.ms)
                          .slideY(begin: 0.15, end: 0),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () =>
                                context.goNamed(RoutePaths.guestWarningName),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.guestContinue,
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 300.ms, duration: 600.ms),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(ThemeData theme, AppLocalizations l10n) {
    return Form(
      key: _loginFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthTextField(
            controller: _loginUsername,
            label: l10n.usernameLabel,
            hint: l10n.usernameHint,
            icon: Icons.person_outline,
            validator: Validators.username,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _loginPassword,
            label: l10n.passwordLabel,
            hint: l10n.passwordHint,
            icon: Icons.lock_outline,
            isPassword: true,
            obscure: _obscureLoginPassword,
            onToggleObscure: () => setState(
              () => _obscureLoginPassword = !_obscureLoginPassword,
            ),
            validator: Validators.password,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _login(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _loading ? null : _onForgotPassword,
              child: Text(l10n.forgotPassword),
            ),
          ),
          const SizedBox(height: 8),
          _SubmitButton(
            label: l10n.loginTitle,
            icon: Icons.arrow_forward,
            loading: _loading,
            filled: true,
            onPressed: _login,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(ThemeData theme, AppLocalizations l10n) {
    return Form(
      key: _registerFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthTextField(
            controller: _registerUsername,
            label: l10n.usernameLabel,
            hint: l10n.usernameRegisterHint,
            icon: Icons.person_outline,
            validator: Validators.username,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _registerEmail,
            label: l10n.emailLabel,
            hint: 'ornek@eposta.com',
            icon: Icons.email_outlined,
            validator: Validators.email,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _registerPassword,
            label: l10n.passwordLabel,
            hint: l10n.passwordRegisterHint,
            icon: Icons.lock_outline,
            isPassword: true,
            obscure: _obscureRegisterPassword,
            onToggleObscure: () => setState(
              () => _obscureRegisterPassword = !_obscureRegisterPassword,
            ),
            validator: Validators.password,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _registerConfirm,
            label: l10n.confirmPasswordLabel,
            hint: l10n.confirmPasswordHint,
            icon: Icons.lock_reset,
            isPassword: true,
            obscure: _obscureRegisterConfirm,
            onToggleObscure: () => setState(
              () => _obscureRegisterConfirm = !_obscureRegisterConfirm,
            ),
            validator: (value) =>
                Validators.confirmPassword(value, _registerPassword.text),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _register(),
          ),
          const SizedBox(height: 24),
          _SubmitButton(
            label: l10n.registerTitle,
            icon: Icons.person_add_alt,
            loading: _loading,
            filled: false,
            onPressed: _register,
          ),
        ],
      ),
    );
  }

  Future<void> _onForgotPassword() async {
    if (_loading) return;
    final username = _loginUsername.text.trim();
    final l10n = AppLocalizations.of(context)!;
    if (username.isEmpty) {
      _showError(l10n.enterUsernameFirst);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).sendPasswordReset(username);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.passwordResetSent),
        ),
      );
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) {
        _showError(l10n.unknownError);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

/// Logo rozeti + COMPETRA wordmark (splash ile tutarlı).
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        const BrandLogoBadge(size: 64, borderRadius: 18),
        const SizedBox(height: 16),
        Text(
          'COMPETRA',
          style: theme.textTheme.displaySmall?.copyWith(
            color: scheme.secondary,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
      ],
    );
  }
}

/// Sekmeleri ve form alanlarını barındıran yüzey kartı.
class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.tabController,
    required this.loginForm,
    required this.registerForm,
    required this.l10n,
  });

  final TabController tabController;
  final Widget loginForm;
  final Widget registerForm;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          TabBar(
            controller: tabController,
            labelColor: scheme.primary,
            unselectedLabelColor: scheme.onSurfaceVariant,
            labelStyle: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
            unselectedLabelStyle: theme.textTheme.labelLarge,
            indicatorColor: scheme.primary,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: scheme.outline.withValues(alpha: 0.2),
            tabs: [
              Tab(text: l10n.loginTitle),
              Tab(text: l10n.registerTitle),
            ],
          ),
          SizedBox(
            height: 420,
            child: TabBarView(
              controller: tabController,
              children: [
                _FormPane(child: loginForm),
                _FormPane(child: registerForm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Form içeriğini kaydırılabilir ve iç boşluklu sunan pane.
class _FormPane extends StatelessWidget {
  const _FormPane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: child,
    );
  }
}

/// Tam genişlikte, yükleniyor durumunu destekleyen gönder butonu.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Widget content = loading
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: filled ? scheme.onPrimary : scheme.primary,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label),
              const SizedBox(width: 8),
              Icon(icon, size: 20),
            ],
          );

    if (filled) {
      return ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: content,
      );
    }
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      child: content,
    );
  }
}

/// "veya" yazılı, iki yanında ince çizgi olan ayraç.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final line = Expanded(
      child: Divider(color: scheme.outline.withValues(alpha: 0.3)),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            l10n.orDivider,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
        line,
      ],
    );
  }
}

/// "Google ile Giriş Yap" butonu.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.loading, required this.onPressed, required this.l10n});

  final bool loading;
  final VoidCallback onPressed;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: Icon(Icons.g_mobiledata, size: 28, color: scheme.primary),
      label: Text(l10n.googleLogin),
    );
  }
}
