import 'package:bar_app/auth_gate.dart';
import 'package:bar_app/screens/pay_invoice_screen.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.appAttest,
  );
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    // App lancée depuis un lien (était fermée)
    _appLinks.getInitialLink().then(_handleDeepLink);

    // Lien reçu pendant que l'app tourne
    _appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  Future<void> _handleDeepLink(Uri? uri) async {
    if (uri == null) return;

    // https://votredomaine.com/pay?invoiceId=abc123
    // cve://pay?invoiceId=abc123
    final invoiceId = uri.queryParameters['invoiceId'];
    if (invoiceId == null) return;

    if (uri.path == '/pay' || uri.host == 'pay') {
      navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => PayInvoiceScreen(invoiceId: invoiceId),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CVE Bar',
      navigatorKey: navigatorKey, // ← indispensable pour le deep link
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(192, 227, 241, 1),
        ),
      ),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}