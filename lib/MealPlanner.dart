import 'package:flutter/material.dart';
import 'nav_bar.dart';

class MealPlannerPage extends StatelessWidget {
  final String username;

  const MealPlannerPage({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Planner'),
        backgroundColor: const Color.fromRGBO(88, 126, 75, 1),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Center(
            child: Container(
              color: const Color.fromARGB(255, 228, 237, 235).withOpacity(0.3),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'This page is empty for now.',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Stay tuned for something special!',
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Exciting updates are on the way. Keep an eye out!',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomNavBar(
        username: username,
        currentIndex: 3,
      ),
    );
  }
}
