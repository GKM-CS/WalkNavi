import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
        );
        return;
      }

      try {
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        // 유저의 displayName을 설정합니다.
        await userCredential.user?.updateDisplayName(_nameController.text);

        // Firestore에 사용자 정보 저장
        var db = FirebaseFirestore.instance;
        final user = <String, String>{
          "name": _nameController.text,
          "email": _emailController.text,
        };
        await db.collection('users').doc(userCredential.user?.uid).set(user);

        // 이메일 인증 보내기
        await userCredential.user!.sendEmailVerification();

        // 회원가입 후 LoginScreen으로 이동
        Navigator.pushReplacementNamed(context, '/login');
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('회원가입 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: '이메일'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return '이메일을 입력해주세요.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return '비밀번호를 입력해주세요.';
                  }
                  return null;
                },
                obscureText: true,
              ),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: '비밀번호 확인',
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return '비밀번호 확인을 입력해주세요.';
                  }
                  return null;
                },
                obscureText: true,
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '이름'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return '이름을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signUp,
                child: const Text('회원가입'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
