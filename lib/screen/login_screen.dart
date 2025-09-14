import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/login_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        await Provider.of<LoginProvider>(context, listen: false)
            .signInWithEmailAndPassword(
                _emailController.text, _passwordController.text);

        final user = Provider.of<LoginProvider>(context, listen: false).user;
        if (user != null) {
          if (user.emailVerified) {
            Navigator.pushNamed(context, '/success', arguments: user);
          } else {
            await FirebaseAuth.instance.signOut();
            _showErrorMessage('이메일 인증을 완료해주세요.');
          }
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        if (e.code == 'user-not-found') {
          errorMessage = '사용자를 찾을 수 없습니다.';
        } else if (e.code == 'wrong-password') {
          errorMessage = '잘못된 비밀번호입니다.';
        } else {
          errorMessage = '로그인 실패: ${e.message}';
        }
        _showErrorMessage(errorMessage);
      }
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('로그인'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start, // 변경: 중앙 정렬을 상단으로 변경
          children: [
            // 로고 이미지 추가
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0), // 아래 여백 추가
              child: Image.asset(
                'assets/logo.png',
                height: 150,
              ),
            ),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '이메일을 입력해주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: '비밀번호',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 입력해주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _login,
                    child: const Text('로그인'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/password');
                    },
                    child: const Text('비밀번호를 잊으셨나요?'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                    child: const Text('계정이 없으신가요? 회원가입'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
