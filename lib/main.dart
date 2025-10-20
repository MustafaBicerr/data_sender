import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'state/invoice_state.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InvoiceState()),
        Provider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'Invoice Scanner',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const RootDecider(),
      ),
    );
  }
}

class RootDecider extends StatefulWidget {
  const RootDecider({super.key});
  @override
  State<RootDecider> createState() => _RootDeciderState();
}

class _RootDeciderState extends State<RootDecider> {
  bool _checking = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final auth = AuthService();
    final user = await auth.getCurrentUser();
    setState(() {
      _loggedIn = user != null;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _loggedIn ? const HomeScreen() : const AuthScreen();
  }
}
