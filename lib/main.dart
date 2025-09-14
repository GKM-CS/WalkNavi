import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'providers/login_provider.dart';
import 'screen/login_screen.dart';
import 'screen/sign_screen.dart';
import 'screen/success_screen.dart';
import 'screen/splash_screen.dart';
import 'screen/navi_main.dart';
import 'screen/star_screen.dart';
import 'screen/password_screen.dart';
import 'screen/liveissue_screen.dart';
import 'screen/routestar_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 위치 권한 요청
  await _requestLocationPermission();

  runApp(ChangeNotifierProvider(
    create: (_) => LoginProvider(),
    child: const MyApp(),
  ));
}

Future<void> _requestLocationPermission() async {
  // 위치 권한을 요청합니다.
  var status = await Permission.location.request();
  if (status.isDenied) {
    // 권한이 거부된 경우 사용자에게 알립니다.
    print('Location permissions are denied');
  } else if (status.isPermanentlyDenied) {
    // 권한이 영구적으로 거부된 경우 사용자에게 알립니다.
    print('Location permissions are permanently denied');
    await openAppSettings();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/splash',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/success': (context) => const SuccessScreen(),
        '/splash': (context) => const SplashScreen(),
        '/navi': (context) => const RouteScreen(),
        '/star': (context) => const PlaceRatingScreen(),
        '/password': (context) => const PasswordResetScreen(),
        '/liveissue': (context) => const LiveIssueScreen(),
        '/routestar': (context) => const RouteStarScreen(),
      },
    );
  }
}
