import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'nav_bar.dart';
import 'recipe_detail_page_user.dart';
import 'edit_recipe_page.dart';

class MyRecipesPage extends StatefulWidget {
  final String username;

  MyRecipesPage({required this.username});

  @override
  _MyRecipesPageState createState() => _MyRecipesPageState();
}

class _MyRecipesPageState extends State<MyRecipesPage> {
  int _currentIndex = 0;
  String _currentUsername = '';
  bool _isLoadingUsername = true;
  @override
  void initState() {
    super.initState();
    _fetchUsername();
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

  Future<void> _deleteRecipe(String recipeId) async {
    final recipeRef =
        FirebaseFirestore.instance.collection('users_recipes').doc(recipeId);

    try {
      final translationsSnap = await recipeRef.collection('translations').get();
      for (final doc in translationsSnap.docs) {
        await recipeRef.collection('translations').doc(doc.id).delete();
      }

      final substitutionsSnap =
          await recipeRef.collection('substitutions').get();
      for (final doc in substitutionsSnap.docs) {
        await recipeRef.collection('substitutions').doc(doc.id).delete();
      }

      await recipeRef.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting recipe: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isLoadingUsername
            ? const SizedBox(height: 20)
            : Text(
                "$_currentUsername's Recipes",
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                ),
              ),
        backgroundColor: const Color.fromARGB(255, 137, 174, 124),
      ),
      body: Builder(
        builder: (context) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser == null) {
            return const Center(child: Text('User not logged in.'));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users_recipes')
                .where('creatorId', isEqualTo: currentUser.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No recipes found.'));
              }

              final recipes = snapshot.data!.docs;

              return ListView.builder(
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  final recipe = recipes[index];
                  final recipeId = recipe.id;
                  final recipeName = recipe['name'] ?? 'Unnamed Recipe';
                  final recipeDescription =
                      recipe['description'] ?? 'No Description';

                  final recipeImage =
                      recipe['image'] is List && recipe['image'].isNotEmpty
                          ? recipe['image'][0]
                          : '';

                  final isPublic = recipe['source'] == 'public';

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: ListTile(
                      leading: recipeImage.isNotEmpty
                          ? Image.network(
                              recipeImage,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            )
                          : null,
                      title: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$recipeName ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            TextSpan(
                              text: '(${isPublic ? 'Public' : 'Private'})',
                              style: const TextStyle(
                                fontWeight: FontWeight.normal,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      subtitle: Text(recipeDescription),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.green),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditRecipePage(
                                    recipeId: recipeId,
                                    username: widget.username,
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Delete Recipe'),
                                    content: const Text(
                                        'Are you sure you want to delete this recipe?'),
                                    actions: [
                                      TextButton(
                                        child: const Text('Cancel'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      TextButton(
                                        child: const Text('Delete'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          _deleteRecipe(recipeId);
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecipeDetailPageUser(
                              recipeId: recipeId,
                              username: widget.username,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: CustomNavBar(
        username: widget.username,
        currentIndex: _currentIndex,
      ),
    );
  }
}
