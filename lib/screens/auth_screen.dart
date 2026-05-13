import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSignUp = false;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fadeAnim =
        CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final supabase = Supabase.instance.client;
      if (_isSignUp) {
        await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {'display_name': _nameController.text.trim()},
        );
      } else {
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleMode() {
    _slideCtrl.reset();
    setState(() { _isSignUp = !_isSignUp; _error = null; });
    _slideCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Vibrant gradient background ──────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF4F46E5), // indigo
                  Color(0xFF0EA5E9), // sky blue
                  Color(0xFF06B6D4), // cyan/teal
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Decorative circles ───────────────────────────────
          Positioned(
            top: -40,
            right: -40,
            child: _Circle(size: 180,
                color: Colors.white.withOpacity(0.08)),
          ),
          Positioned(
            top: 60,
            right: 40,
            child: _Circle(size: 80,
                color: Colors.white.withOpacity(0.1)),
          ),
          Positioned(
            bottom: 180,
            left: -50,
            child: _Circle(size: 160,
                color: Colors.white.withOpacity(0.07)),
          ),
          Positioned(
            bottom: -30,
            right: -30,
            child: _Circle(size: 140,
                color: Colors.white.withOpacity(0.08)),
          ),

          // ── Top hero text ────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 48),
                // Icon badge
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.35), width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.people_rounded,
                        color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'TogetherIRL',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isSignUp
                      ? 'Join the hangout 🎉'
                      : 'Welcome back 👋',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const Spacer(),

                // ── White card ───────────────────────────────────
                SlideTransition(
                  position: _slideAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.2),
                            blurRadius: 40,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isSignUp ? 'Create Account' : 'Sign In',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isSignUp
                                  ? 'Fill in the details below'
                                  : 'Enter your credentials to continue',
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 22),

                            if (_isSignUp) ...[
                              _Field(
                                controller: _nameController,
                                label: 'Your name',
                                icon: Icons.person_outline_rounded,
                                textCapitalization: TextCapitalization.words,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Enter your name'
                                        : null,
                              ),
                              const SizedBox(height: 14),
                            ],

                            _Field(
                              controller: _emailController,
                              label: 'Email address',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              validator: (v) =>
                                  (v == null || !v.contains('@'))
                                      ? 'Enter a valid email'
                                      : null,
                            ),
                            const SizedBox(height: 14),

                            _Field(
                              controller: _passwordController,
                              label: 'Password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              validator: (v) =>
                                  (v == null || v.length < 6)
                                      ? 'At least 6 characters'
                                      : null,
                              suffix: GestureDetector(
                                onTap: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                                child: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                              ),
                            ),

                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEDED),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Color(0xFFEF4444), size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(_error!,
                                          style: const TextStyle(
                                              color: Color(0xFFEF4444),
                                              fontSize: 13)),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 22),

                            // Submit button
                            GestureDetector(
                              onTap: _loading ? null : _submit,
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  gradient: _loading
                                      ? null
                                      : const LinearGradient(
                                          colors: [
                                            Color(0xFF4F46E5),
                                            Color(0xFF0EA5E9),
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                  color: _loading
                                      ? const Color(0xFFE2E8F0)
                                      : null,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: _loading
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: const Color(0xFF0EA5E9)
                                                .withOpacity(0.4),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                ),
                                child: Center(
                                  child: _loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Color(0xFF6366F1)),
                                        )
                                      : Text(
                                          _isSignUp
                                              ? 'Create Account'
                                              : 'Sign In',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Toggle
                            GestureDetector(
                              onTap: _toggleMode,
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF94A3B8)),
                                  children: [
                                    TextSpan(
                                      text: _isSignUp
                                          ? 'Already have an account?  '
                                          : "Don't have an account?  ",
                                    ),
                                    TextSpan(
                                      text: _isSignUp ? 'Sign in' : 'Sign up',
                                      style: const TextStyle(
                                        color: Color(0xFF0EA5E9),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  final double size;
  final Color color;
  const _Circle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool autocorrect;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final Widget? suffix;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.autocorrect = true,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autocorrect: autocorrect,
      textCapitalization: textCapitalization,
      validator: validator,
      style: const TextStyle(
          color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        prefixIcon:
            Icon(icon, color: const Color(0xFF94A3B8), size: 20),
        suffixIcon: suffix != null
            ? Padding(
                padding: const EdgeInsets.only(right: 12), child: suffix)
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFEF4444)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
