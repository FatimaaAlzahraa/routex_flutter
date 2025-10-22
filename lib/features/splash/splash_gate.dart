import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../../core/session.dart';
import '../driver/driver_home.dart';
import '../manager/manager_home.dart';
import '../auth/login_page.dart';

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await Session.token;
    if (!mounted) return;

    if (token == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    try {
      final me = await _auth.whois();
      if (!mounted) return;
      if (me.role.toLowerCase().contains('manager')) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ManagerHome(userName: me.name)),
        );
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => DriverHome(userName: me.name, userPhone: me.phone)));

      }
    } catch (_) {
      if (!mounted) return;
      await Session.clear();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
