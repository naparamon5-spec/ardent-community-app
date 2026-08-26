import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/session.dart';
import '../theme/ardent_colors.dart';

/// Ardent Hub Login & Welcome Screen.
/// Pixel-matched with the brand design reference:
/// - 3D Ardent Hub Emblem & "ArdentHub." branding
/// - "Your Community, In One Place" tagline
/// - "Connect • Share • Grow" sub-tagline
/// - Transparent 3D wave ribbon background
/// - Pill-shaped "Get Started" and "Sign In" action buttons
/// - Vertically balanced, uncompressed sign-in form
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
  bool _showSignInForm = false;
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
      return "Couldn't reach the server at ${ApiConfig.baseUrl}. "
          'Check your connection and the API URL.';
    }
    if (e.isUnauthorized) return 'Incorrect email or password.';
    if (e.isForbidden) return 'This account has been deactivated.';
    return e.message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Soft top-left ambient pink/red glow
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x35E88B92),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x35E88B92),
                    blurRadius: 45,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // 2. Soft middle-right ambient pink/red glow
          Positioned(
            bottom: 240,
            right: 30,
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x28A31B1F),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x28A31B1F),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),

          // 3. 3D Wave ribbon graphic positioned in lower third
          Positioned(
            left: 0,
            right: 0,
            bottom: _showSignInForm ? 0 : 85,
            height: 240,
            child: IgnorePointer(
              child: Opacity(
                opacity: _showSignInForm ? 0.35 : 1.0,
                child: Image.asset(
                  'assets/images/ardent_hub_wave_transparent.png',
                  fit: BoxFit.fill,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          // 4. Main content (Welcome Hero or Sign In Form)
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 16,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: _showSignInForm
                                ? _buildSignInForm(context, constraints.maxHeight)
                                : _buildWelcomeHero(context, constraints.maxHeight),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// The Welcome Hero state matching the reference mobile screen.
  Widget _buildWelcomeHero(BuildContext context, double totalHeight) {
    return SizedBox(
      key: const ValueKey('welcome_hero'),
      height: totalHeight - 32, // Subtract vertical padding
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),

          // Brand Hero
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 3D Ardent Hub Emblem
              Hero(
                tag: 'ardent_hub_emblem',
                child: Image.asset(
                  'assets/images/ardent_hub_symbol.png',
                  width: 140,
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: ArdentColors.brandCrimson,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ArdentHub. Typography
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                  children: [
                    TextSpan(
                      text: 'Ardent',
                      style: TextStyle(color: Color(0xFF1B1B1B)),
                    ),
                    TextSpan(
                      text: 'Hub',
                      style: TextStyle(color: ArdentColors.brandCrimson),
                    ),
                    TextSpan(
                      text: '.',
                      style: TextStyle(color: ArdentColors.brandCrimson),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Tagline: "Your Community, In One Place"
              const Text(
                'Your Community, In One Place',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A4C52),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 10),

              // Sub-tagline: "Connect • Share • Grow"
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Connect',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF686A70),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 9),
                    child: Text(
                      '•',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ArdentColors.brandBrightRed,
                      ),
                    ),
                  ),
                  Text(
                    'Share',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF686A70),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 9),
                    child: Text(
                      '•',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ArdentColors.brandBrightRed,
                      ),
                    ),
                  ),
                  Text(
                    'Grow',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF686A70),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Bottom Action Buttons
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // "Get Started" Solid Crimson Pill Button
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ArdentRadii.pill),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFA31B1F),
                        Color(0xFF760F12),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33A31B1F),
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showSignInForm = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ArdentRadii.pill),
                      ),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // "Sign In" Outlined Pill Button
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _showSignInForm = true),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(
                        color: ArdentColors.brandCrimson,
                        width: 1.8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ArdentRadii.pill),
                      ),
                    ),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ArdentColors.brandCrimson,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The Sign In Form state - vertically centered and balanced.
  Widget _buildSignInForm(BuildContext context, double totalHeight) {
    final text = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: Container(
        key: const ValueKey('sign_in_form'),
        constraints: BoxConstraints(
          minHeight: totalHeight - 32,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // Header Emblem & Title
            Center(
              child: Hero(
                tag: 'ardent_hub_emblem',
                child: Image.asset(
                  'assets/images/ardent_hub_symbol.png',
                  width: 85,
                  height: 74,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 14),

            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
                children: [
                  TextSpan(
                    text: 'Ardent',
                    style: TextStyle(color: Color(0xFF1B1B1B)),
                  ),
                  TextSpan(
                    text: 'Hub',
                    style: TextStyle(color: ArdentColors.brandCrimson),
                  ),
                  TextSpan(
                    text: '.',
                    style: TextStyle(color: ArdentColors.brandCrimson),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to your account',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(
                color: ArdentColors.fg3,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),

            // Error Banner
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: ArdentColors.red50,
                  border: Border.all(color: ArdentColors.red200),
                  borderRadius: BorderRadius.circular(ArdentRadii.md),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 20, color: ArdentColors.brandCrimson),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: text.bodyMedium?.copyWith(
                          color: ArdentColors.red800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Work Email Field
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: 'Work email',
                prefixIcon: const Icon(Icons.mail_outline_rounded,
                    color: ArdentColors.brandCrimson),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ArdentRadii.pill),
                  borderSide: const BorderSide(color: Color(0xFFD7D7D7)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ArdentRadii.pill),
                  borderSide: const BorderSide(color: Color(0xFFD7D7D7)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ArdentRadii.pill),
                  borderSide: const BorderSide(
                      color: ArdentColors.brandCrimson, width: 1.8),
                ),
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'Enter your email';
                if (!s.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password Field
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              enabled: !_submitting,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded,
                    color: ArdentColors.brandCrimson),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ArdentRadii.pill),
                  borderSide: const BorderSide(color: Color(0xFFD7D7D7)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ArdentRadii.pill),
                  borderSide: const BorderSide(color: Color(0xFFD7D7D7)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ArdentRadii.pill),
                  borderSide: const BorderSide(
                      color: ArdentColors.brandCrimson, width: 1.8),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: ArdentColors.fg3,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your password' : null,
            ),
            const SizedBox(height: 24),

            // Submit Button
            Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ArdentRadii.pill),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFA31B1F),
                    Color(0xFF760F12),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33A31B1F),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ArdentRadii.pill),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Back to Welcome Text Link
            Center(
              child: TextButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                          _showSignInForm = false;
                          _error = null;
                        }),
                child: const Text(
                  'Back to Welcome',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A4C52),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Footer note
            Text(
              'Use your Ardent Networks account. Contact HR if you need access.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: ArdentColors.fg3),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
