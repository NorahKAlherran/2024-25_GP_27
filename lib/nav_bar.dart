import 'package:flutter/material.dart';
import 'createrecipe.dart';
import 'profile.dart';
import 'homepage.dart';
import 'SelectIngredients.dart';
import 'MealPlanner.dart';

class CustomNavBar extends StatefulWidget {
  final String username;
  final int currentIndex;

  const CustomNavBar({
    Key? key,
    required this.username,
    required this.currentIndex,
  }) : super(key: key);

  @override
  _CustomNavBarState createState() => _CustomNavBarState();
}

class _CustomNavBarState extends State<CustomNavBar> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: const Color.fromARGB(255, 137, 174, 124),
      selectedItemColor: const Color.fromRGBO(61, 64, 91, 1),
      unselectedItemColor: Colors.white70,
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });

        if (index == 4) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ProfilePage(
                  username: widget.username), // Navigate to ProfilePage
            ),
          );
        } else if (index == 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  HomePage(username: widget.username), // Navigate to HomePage
            ),
          );
        } else if (index == 2) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CreateRecipePage(
                  username: widget.username), // Navigate to CreateRecipePage
            ),
          );
        } else if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SelectIngredientsPage(
                  username:
                      widget.username), // Navigate to SelectIngredientsPage
            ),
          );
        } else if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MealPlannerPage(
                  username: widget.username), // Navigate to MealPlannerPage
            ),
          );
        }
      },
      items: [
        BottomNavigationBarItem(
          icon: Image.asset("assets/images/home-button.png",
              width: 50, height: 50),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Image.asset("assets/images/ingrediants.png",
              width: 50, height: 50),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            "assets/images/plus.png",
            width: 80,
            height: 80,
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon:
              Image.asset("assets/images/calendar.png", width: 50, height: 50),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Image.asset("assets/images/profile.png", width: 50, height: 50),
          label: '',
        ),
      ],
    );
  }
}
