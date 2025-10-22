//login_page,dart
import 'package:flutter/material.dart';
import '../driver/driver_home.dart';
import '../manager/manager_home.dart';
import 'auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _pass  = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  final _auth = AuthService();

  @override
  void dispose() {
    _phone.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final typedPhone = _phone.text.trim();

      await _auth.login(phone: typedPhone, password: _pass.text);
      final me = await _auth.whois();

      if (!mounted) return;

      // حدّد الوجهة بناءً على الدور
      if (me.role.toLowerCase().contains('manager')) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ManagerHome(userName: me.name)),
        );
      } else {
        // مرر الاسم + رقم الجوال (من whois أو من الحقل كـ fallback)
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => DriverHome(userName: me.name, userPhone: me.phone)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تسجيل الدخول: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFF76D20);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Image.asset('assets/images/logo.png', width: 86, height: 86),
                ),
                const SizedBox(height: 12),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2C2C2C),
                    ),
                    children: const [
                      TextSpan(text: 'مرحباً بك في '),
                      TextSpan(text: 'Routex '),
                      TextSpan(text: '👋'),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'سجّل دخول لحسابك الآن',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: const Color(0xFF6E6E6E)),
                ),
                const SizedBox(height: 22),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'رقم الجوال',
                          hintText: '0566788999',
                          prefixIcon: Padding(
                            padding: EdgeInsetsDirectional.only(start: 12, end: 8),
                            child: Text('🇸🇦  +966',
                                style: TextStyle(fontSize: 14, color: Color(0xFF2C2C2C))),
                          ),
                          prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                        ),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'أدخل رقم الجوال';
                          if (t.length < 8) return 'رقم غير صحيح';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _pass,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) {
                          if ((v ?? '').length < 6) return 'كلمة المرور قصيرة';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            // TODO: ربط تدفّق OTP لاحقاً
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: primary,
                          ),
                          child: const Text('نسيت كلمة المرور؟'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('سجّل دخولك الآن'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
