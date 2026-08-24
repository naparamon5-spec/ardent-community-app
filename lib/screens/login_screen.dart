import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/session.dart';
import '../theme/ardent_colors.dart';

/// Password sign-in against `POST /auth/login`. On success the JWT is stored
/// (securely) and the session profile is populated; the [AuthGate] then swaps in
/// the main app shell.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await Api.instance.auth.login(
        email: _email.text.trim(),
        password: _password.text,
      );
      // Populate the session from the login payload's `user` so we don't need a
      // second round-trip; the AuthStore change will trigger the AuthGate.
      AppSession.instance.setFromJson(result);
      Api.instance.realtime.connect();
    } on ApiException catch (e) {
      debugPrint('[Login] failed (status ${e.statusCode}): ${e.message}');
      if (!mounted) return;
      setState(() => _error = _messageFor(e));
    } catch (e, st) {
      // Anything not already turned into an ApiException by the client.
      debugPrint('[Login] unexpected error hitting ${ApiConfig.baseUrl}/auth/login: $e');
      debugPrintStack(stackTrace: st, maxFrames: 6);
      if (!mounted) return;
      setState(() => _error =
          "Couldn't reach the server. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _messageFor(ApiException e) {
    if (e.statusCode == 0) {
      // Transport error — no HTTP response. Show the host so it's obvious when
      // the app is pointed at the wrong/unreachable URL.
      return "Couldn't reach the server at ${ApiConfig.baseUrl}. "
          'Check your connection and the API URL.';
    }
    if (e.isUnauthorized) return 'Incorrect email or password.';
    if (e.isForbidden) return 'This account has been deactivated.';
    return e.message;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: ArdentColors.bgSurface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ArdentSpacing.s6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: Alignment(-0.3, -0.4),
                            radius: 1.0,
                            colors: [
                              ArdentColors.brandCoral,
                              ArdentColors.brandRed,
                              ArdentColors.red800
                            ],
                            stops: [0.0, 0.48, 1.0],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: ArdentSpacing.s4),
                    Text('Ardent Community',
                        textAlign: TextAlign.center,
                        style: text.headlineMedium?.copyWith(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text('Sign in to continue',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(color: ArdentColors.fg3)),
                    const SizedBox(height: ArdentSpacing.s6),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: ArdentColors.red50,
                          border: Border.all(color: ArdentColors.red100),
                          borderRadius: BorderRadius.circular(ArdentRadii.sm),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 18, color: ArdentColors.accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: text.bodyMedium
                                      ?.copyWith(color: ArdentColors.red800)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: ArdentSpacing.s4),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: 'Work email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.isEmpty) return 'Enter your email';
                        if (!s.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: ArdentSpacing.s3),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      enabled: !_submitting,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Enter your password' : null,
                    ),
                    const SizedBox(height: ArdentSpacing.s5),
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: ArdentSpacing.s4),
                    Text(
                      'Use your Ardent Networks account. Contact HR if you need access.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: ArdentColors.fg3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
