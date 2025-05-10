import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'RecipeDetailPage.dart';
import 'RecipesPage.dart';
import 'ExplorePage.dart';
import 'nav_bar.dart';
import 'login.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  final String username;

  HomePage({required this.username});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> randomTags = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isVerified = false;
  bool hasFetchedRecipes = false;
  List<Map<String, dynamic>> randomRecipes = [];
  String _currentUsername = '';
  bool _isLoadingUsername = true;

  // Store recipes persistently

  @override
  void initState() {
    super.initState();
    _fetchTags();
    _fetchUsername();
    if (!hasFetchedRecipes) {
      _fetchRandomRecipes();
    }

    FirebaseAuth.instance.authStateChanges().first.then((User? user) {
      if (user != null) {
        _checkEmailVerification();
      } else {
        print("No user signed in.");
      }
    });
  }

  Future<void> _fetchUsername() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      setState(() {
        _currentUsername = doc['username'] ?? 'My';
        _isLoadingUsername = false;
      });
    }
  }

  Future<void> _checkEmailVerification() async {
    User? user = _auth.currentUser;

    if (user == null) {
      print("No user is currently signed in.");
      return;
    }

    // Reload user to get updated verification status
    await user.reload();
    setState(() {
      _isVerified = user.emailVerified;
    });

    if (!_isVerified) {
      // Show warning and set a timer for auto logout
      _showWarningDialog();
      Future.delayed(const Duration(minutes: 1), () async {
        User? refreshedUser = _auth.currentUser; // Get the latest user instance
        if (refreshedUser != null) {
          await refreshedUser.reload();
          if (!refreshedUser.emailVerified) {
            _logout();
          }
        }
      });
    }
  }

  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs
        .clear(); //  Clears all stored data, ensuring new recipes on next login

    await _auth.signOut();

    Future.delayed(Duration(seconds: 2), () {
      if (!context.mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  void _showWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Email Verification Needed"),
        content: const Text(
          "Your email is not verified. Please verify it within 1 minute to avoid being logged out.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

//////////////////////////////////////////////////////////////////
  List<String> allTags = []; // List to store all the tags
  bool tagsFetched = false; // Flag to check if tags have already been fetched

  Future<void> _fetchTags() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;

    try {
      // Check if user has existing tag click counts
      DocumentSnapshot userTagSnapshot = await FirebaseFirestore.instance
          .collection('user_tag_counts')
          .doc(userId)
          .get();

      Map<String, int> userTagUsage = {};
      bool isNewUser = !userTagSnapshot.exists; // If no tag data, user is new

      if (!isNewUser) {
        //  Load user-specific tag usage
        userTagUsage = Map<String, int>.from(
            userTagSnapshot.data() as Map<String, dynamic>);
      }

      //  Fetch all recipes
      QuerySnapshot recipeSnapshot =
          await FirebaseFirestore.instance.collection('recipes').get();

      Map<String, int> tagFrequency =
          {}; // Store tag occurrence across all recipes

      for (var doc in recipeSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('Tags') && data['Tags'] is List) {
          List<String> tags = List<String>.from(data['Tags'])
              .where((tag) =>
                  !RegExp(r'^[\u0600-\u06FF]').hasMatch(tag)) //  exclude Arabic
              .toList();

          for (String tag in tags) {
            tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
          }
        }
      }

      // Determine sorting method
      List<String> sortedTags;

      if (!isNewUser) {
        // Returning user: Sort based on personal tag click counts
        sortedTags = tagFrequency.keys.toList()
          ..sort(
              (a, b) => (userTagUsage[b] ?? 0).compareTo(userTagUsage[a] ?? 0));
        print(
            "Returning user: Displaying tags sorted by personal click counts: $sortedTags");
      } else {
        // New user: Sort based on how often tags appear in recipes
        sortedTags = tagFrequency.keys.toList()
          ..sort(
              (a, b) => (tagFrequency[b] ?? 0).compareTo(tagFrequency[a] ?? 0));
        print(
            "New user: Displaying tags sorted by occurrence in recipes: ${sortedTags.map((tag) => '$tag (${tagFrequency[tag]})').toList()}");
      }

      // Store the top 20 tags
      allTags = sortedTags.take(20).toList();
      tagsFetched = true;

      setState(() {});
    } catch (e) {
      print("Error fetching tags: $e");
    }
  }

/////////////////////////////////////////////

  final List<Color> pastelColors = [
    Color(0xFFE3B7D0), // Pastel Pink
    Color(0xFFC1C8E4), // Pastel Blue
    Color(0xFFC1E1DC), // Pastel Mint
    Color(0xFFF7D1BA), // Pastel Peach
    Color(0xFFF2D7E0), // Pastel Lavender
    Color(0xFFF7F1B5), // Pastel Yellow
    Color(0xFFD3F8E2), // Pastel Green
    Color(0xFFF9E2C0), // Pastel Orange
  ];

  Widget _buildTagList() {
    if (!tagsFetched) {
      return const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(allTags.length, (index) {
          Color tagColor = pastelColors[index % pastelColors.length];

          return GestureDetector(
            onTap: () {
              _recordTagSelection(allTags[index]);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecipesPage(
                    username: widget.username,
                    selectedTag: allTags[index],
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: tagColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  "#${allTags[index]}",
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _recordTagSelection(String tag) async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    DocumentReference userTagDoc =
        FirebaseFirestore.instance.collection('user_tag_counts').doc(userId);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userTagDoc);

      if (snapshot.exists) {
        Map<String, dynamic> tagCounts =
            snapshot.data() as Map<String, dynamic>;
        int currentCount = tagCounts[tag] ?? 0;
        tagCounts[tag] = currentCount + 1;
        transaction.update(userTagDoc, tagCounts);
      } else {
        transaction.set(userTagDoc, {tag: 1});
      }
    });
  }

  Future<void> _fetchRandomRecipes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    //  Detect if user is logging in and force new recipes
    bool isNewLogin = prefs.getBool('isNewLogin') ?? true;

    if (!isNewLogin && hasFetchedRecipes && randomRecipes.isNotEmpty) {
      print("Using stored recipes instead of fetching new ones.");
      return; //  Use cached recipes if NOT a new login
    }

    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      DocumentSnapshot userTagSnapshot = await FirebaseFirestore.instance
          .collection('user_tag_counts')
          .doc(userId)
          .get();

      List<String> topTags = [];

      if (userTagSnapshot.exists) {
        Map<String, dynamic> tagCounts =
            userTagSnapshot.data() as Map<String, dynamic>;

        topTags = tagCounts.keys.toList()
          ..sort((a, b) => (tagCounts[b] ?? 0).compareTo(tagCounts[a] ?? 0));
        topTags = topTags.take(3).toList();
      }

      QuerySnapshot recipesSnapshot;

      if (topTags.isEmpty) {
        print("No top tags found. Fetching random recipes.");
        recipesSnapshot = await FirebaseFirestore.instance
            .collection('recipes')
            .limit(4)
            .get();
      } else {
        recipesSnapshot = await FirebaseFirestore.instance
            .collection('recipes')
            .where('Tags', arrayContainsAny: topTags)
            .get();
      }

      List<Map<String, dynamic>> matchingRecipes = recipesSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                'name': doc['name'],
                'image': doc['image'],
              })
          .toList();

      randomRecipes = matchingRecipes.take(4).toList();
      hasFetchedRecipes = true;

      //  Store new recipes in SharedPreferences
      await prefs.setString('cachedRecipes', jsonEncode(randomRecipes));
      await prefs.setBool(
          'isNewLogin', false); //  Prevent fetching on every home entry

      print("Stored new recipes in SharedPreferences.");
      setState(() {});
    } catch (e) {
      print("Error fetching random recipes: $e");
    }
  }

//////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromARGB(255, 137, 174, 124),
        elevation: 0,
        title: _isLoadingUsername
            ? const SizedBox(height: 20)
            : Text(
                "Welcome Back, $_currentUsername!",
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                ),
              ),
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          "Explore, find more, enjoy!",
                          style: TextStyle(
                            fontFamily: 'Gabriola',
                            fontSize: 23,
                            color: const Color.fromARGB(255, 0, 0, 0),
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 137, 174, 124),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ExplorePage(username: widget.username),
                            ),
                          );
                        },
                        child: const Text(
                          "Explore Recent Recipes",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color.fromARGB(255, 250, 249, 249),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Image.asset(
                  'assets/images/chiefphoto.png',
                  height: 150,
                  width: 150,
                ),
              ],
            ),
            const SizedBox(height: 20),
            ////////////////////////////////////////////////////////-----------
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0), // Adjust as needed
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 137, 174, 124),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecipesPage(
                            username: widget.username,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      "All",
                      style: TextStyle(
                        fontSize: 16,
                        color: Color.fromARGB(255, 250, 249, 249),
                      ),
                    ),
                  ),
                  Expanded(child: _buildTagList()),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: randomRecipes.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio:
                            0.68, // 🔧 Adjusted to prevent overflow
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: randomRecipes.length,
                      itemBuilder: (context, index) {
                        final recipe = randomRecipes[index];

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecipeDetailPage(
                                  recipeId: recipe['id'],
                                  username: widget.username,
                                ),
                              ),
                            );
                          },
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  height: 150,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      topRight: Radius.circular(12),
                                    ),
                                    image: DecorationImage(
                                      image: NetworkImage(recipe['image']),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0, vertical: 4.0),
                                  child: Center(
                                    child: Text(
                                      recipe['name'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.share,
                                            color: Colors.grey),
                                        onPressed: () {
                                          Share.share(
                                            'Check out this recipe: ${recipe['name']}! Here is the image: ${recipe['image']}',
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomNavBar(
        username: widget.username,
        currentIndex: 2,
      ),
    );
  }
}
