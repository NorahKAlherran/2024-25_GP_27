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

  Future<void> _deleteRecipe(String recipeId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users_recipes')
          .doc(recipeId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recipe deleted successfully')),
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
        title: Text('${widget.username}\'s Recipes'),
        backgroundColor: const Color.fromARGB(255, 137, 174, 124),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users_recipes')
            .where('createdBy', isEqualTo: widget.username)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No recipes found.'));
          }

          final recipes = snapshot.data!.docs;

          return ListView.builder(
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              final recipeId = recipe.id;
              final recipeName = recipe['name'] ?? 'Unnamed Recipe';
              final recipeDescription = recipe['description'] ?? 'No Description';

              // Safely retrieve the first image URL from the image array, if it exists
              final recipeImage = recipe['image'] is List && recipe['image'].isNotEmpty
                  ? recipe['image'][0] // Get the first image URL
                  : '';  // If no images, set to empty string

              final isPublic = recipe['source'] == 'public';

              return Card(
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  leading: recipeImage.isNotEmpty
                      ? Image.network(
                          recipeImage,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                      : null,  // If no image, show nothing
                  title: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$recipeName ', // Recipe name
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
                      // Edit button
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.green),
                        onPressed: () {
                          // Navigate to the EditRecipePage
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
                      // Delete button
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          // Confirm deletion before deleting
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Delete Recipe'),
                                content: Text(
                                    'Are you sure you want to delete this recipe?'),
                                actions: [
                                  TextButton(
                                    child: Text('Cancel'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  TextButton(
                                    child: Text('Delete'),
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
      ),
      bottomNavigationBar: CustomNavBar(
        username: widget.username,
        currentIndex: _currentIndex,
      ),
    );
  }
}
