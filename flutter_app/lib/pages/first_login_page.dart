import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../components/app_colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;

  Future<void> _fakeLogin() async {
    setState(() => _loading = true);

    try {
      // ยิง API เปล่า ๆ ไปก่อน (mock)
      final res = await http.get(
        Uri.parse("https://jsonplaceholder.typicode.com/todos/1"),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        debugPrint("✅ Mock API response: $data");
      } else {
        debugPrint("❌ Mock API failed: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("⚠️ Error: $e");
    }

    await Future.delayed(const Duration(seconds: 1)); // จำลอง delay

    setState(() => _loading = false);

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white, // พื้นหลังด้านบนเป็นขาว
      body: SafeArea(
        child: Stack(
          children: [
            // ===== พื้นหลังครึ่งล่างสีเขียว =====
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: size.height * 0.58, 
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF84A98C), 
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(180),
                    topRight: Radius.circular(180),
                  ),
                ),
              ),
            ),

            // ===== เนื้อหาซ้อนบนพื้นหลัง =====
             Positioned(
              top: 120, // ปรับค่านี้เพื่อลงมาใกล้ส่วนเขียว
              left: 0,
              right: 0,
              child: const Center(
                child: Text(
                  'KUCOM',
                  style: TextStyle(
                    fontSize: 76,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF116466),
                  ),
                ),
              ),
            ),

            // ===== เนื้อหาภายในพื้นหลังเขียว =====
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center, 

                  children: [
                    const SizedBox(height: 180),
                    // รูป
                    SizedBox(
                      height: 320,
                      width: 320, 
                      child: Image.asset(
                        'assets/images/login_image.png',
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 60),

                    // ปุ่ม
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _fakeLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF116466),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                       child: _loading
                    ? const SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('KU ALL-Login', style: TextStyle(fontSize: 18, color: Colors.white)),
                            ),
                           ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF116466),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Login with Email',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}