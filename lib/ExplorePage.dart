import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'nav_bar.dart';
import 'recipe_detail_page_user.dart';

class ExplorePage extends StatefulWidget {
  final String username;

  ExplorePage({required this.username});

  @override
  _ExplorePageState createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  List<Recipe> _allRecipes = [];

  @override
  void initState() {
    super.initState();
    _fetchRecipes();
  }

  Future<void> _fetchRecipes() async {
    // Fetch only the 10 most recent public recipes from Firestore
    final snapshot = await FirebaseFirestore.instance
        .collection('users_recipes')
        .where('source', isEqualTo: 'public')
        .orderBy('created_at', descending: true)
        .limit(10)
        .get();

    final recipes = snapshot.docs.map((doc) {
      return Recipe.fromFirestore(doc);
    }).toList();

    setState(() {
      _allRecipes = recipes;
    });
  }

  void _shareRecipe(String recipeName) {
    Share.share('Check out this recipe: $recipeName');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Explore Recipes"),
        backgroundColor: const Color.fromARGB(255, 137, 174, 124),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: _allRecipes.length,
          itemBuilder: (context, index) {
            final recipe = _allRecipes[index];

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecipeDetailPageUser(
                      recipeId: recipe.id,
                      username: widget.username,
                    ),
                  ),
                );
              },
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      recipe.image.isNotEmpty
                          ? Image.network(
                              recipe.image,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.error, size: 50);
                              },
                            )
                          : Icon(Icons.image, size: 100),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipe.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Created by: ${recipe.createdBy}",
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.share),
                        onPressed: () {
                          _shareRecipe(recipe.name);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: CustomNavBar(
        username: widget.username,
        currentIndex: 2,
      ),
    );
  }
}

// Recipe Model
class Recipe {
  final String id;
  final String name;
  final String image;
  final String createdBy;

  Recipe({
    required this.id,
    required this.name,
    required this.image,
    required this.createdBy,
  });

  factory Recipe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Recipe(
      id: doc.id,
      name: data['name'] ?? 'Unknown Recipe',
      image: data['image'] ?? '',
      createdBy: data['createdBy'] ?? 'Unknown',
    );
  }
}
