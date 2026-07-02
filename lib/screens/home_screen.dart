import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'coloring_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _signInWithGoogle() async {
    // TODO: Implement Google Sign-In
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.palette, size: 100, color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                'Kids Coloring',
                style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              if (user == null)
                ElevatedButton(
                  onPressed: _signInWithGoogle,
                  style: ElevatedButton(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF667eea),
                  ),
                  child: const Text('Sign In with Google', style: TextStyle(fontSize: 18)),
                )
              else
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ColoringScreen()),
                  ),
                  style: ElevatedButton(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF667eea),
                  ),
                  child: const Text('Start Coloring', style: TextStyle(fontSize: 18)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
