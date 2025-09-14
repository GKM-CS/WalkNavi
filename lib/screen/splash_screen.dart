import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    // 위치 권한을 요청합니다.
    var status = await Permission.location.request();
    if (status.isGranted) {
      // 권한이 허용된 경우 다음 화면으로 이동합니다.
      _navigateToNextScreen();
    } else if (status.isDenied) {
      // 권한이 거부된 경우 사용자에게 알립니다.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 권한이 거부되었습니다.')),
      );
    } else if (status.isPermanentlyDenied) {
      // 권한이 영구적으로 거부된 경우 사용자에게 알립니다.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('위치 권한이 영구적으로 거부되었습니다. 앱 설정에서 권한을 허용해주세요.')),
      );
      await openAppSettings();
    }
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 3));
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 로고 이미지 추가
            Image.asset(
              'assets/logo.png',
              height: 150,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
