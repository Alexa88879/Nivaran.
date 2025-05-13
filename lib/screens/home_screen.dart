import 'package:flutter/material.dart';
import '../widgets/custom_button_all_screen.dart';
import '../utils/update_checker.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

 @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Builder( // NEW: wrap with Builder to get a fresh context
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            UpdateChecker.checkForUpdate(context);
          });

          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/icon/icon.jpg',
                      height: 80,
                      width: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Choose your option',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color.fromARGB(255, 7, 7, 7),
                    ),
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                    text: 'Login',
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    buttonColor: Colors.black,
                    height: 48,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('or'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: 'Sign up',
                    onPressed: () => Navigator.pushNamed(context, '/signup'),
                    buttonColor: Colors.black,
                    height: 48,
                    width: double.infinity,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

}
