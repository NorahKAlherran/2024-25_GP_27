import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'RecipeDetailPage.dart';
import 'recipe_detail_page_user.dart';
import 'nav_bar.dart';

class CollectionDetailsPage extends StatefulWidget {
  final String collectionId;
  final String username;

  CollectionDetailsPage({
    required this.collectionId,
    required this.username,
  }) {
    print('CollectionDetailsPage initialized with username: $username');
  }

  @override
  _CollectionDetailsPageState createState() => _CollectionDetailsPageState();
}

class _CollectionDetailsPageState extends State<CollectionDetailsPage> {
  Future<void> _removeRecipeFromCollectionAndFavorites(String recipeId) async {
    try {
      final collectionRef = FirebaseFirestore.instance
          .collection('collections')
          .doc(widget.collectionId);

      final snapshot = await collectionRef.get();
      final data = snapshot.data() as Map<String, dynamic>;

      if (data.containsKey('recipes')) {
        final recipes = List<Map<String, dynamic>>.from(data['recipes']);
        final updatedRecipes =
            recipes.where((recipe) => recipe['id'] != recipeId).toList();

        await collectionRef.update({'recipes': updatedRecipes});

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recipe deleted successfully!'),
            backgroundColor: const Color.fromARGB(255, 118, 133, 118),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove recipe: $error')),
        );
      }
    }
  }

  void _showDeleteConfirmationDialog(String recipeId, String recipeName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Delete Recipe',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "$recipeName" from this collection?',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel', style: TextStyle(color: Colors.green)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeRecipeFromCollectionAndFavorites(recipeId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<DocumentSnapshot> _fetchRecipeDetails(String recipeId) async {
    final recipeDoc = await FirebaseFirestore.instance
        .collection('users_recipes')
        .doc(recipeId)
        .get();

    if (recipeDoc.exists) {
      return recipeDoc;
    }

    return FirebaseFirestore.instance.collection('recipes').doc(recipeId).get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 137, 174, 124),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('collections')
              .doc(widget.collectionId)
              .snapshots(),
          builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Text('Loading...');
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Text('Collection Details');
            }

            final data = snapshot.data!.data() as Map<String, dynamic>?;
            final collectionName = data?['name'] ?? 'Unnamed Collection';

            return Text(collectionName);
          },
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('collections')
            .doc(widget.collectionId)
            .snapshots(),
        builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text("Collection not found."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final recipes = data?['recipes'] as List<dynamic>? ?? [];

          if (recipes.isEmpty) {
            return Center(
              child: Text('No recipes added to this collection yet.'),
            );
          }

          return ListView.builder(
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipeData = recipes[index] as Map<String, dynamic>;
              final recipeId = recipeData['id'];
              final recipeName = recipeData['name'];
              final recipeImage = recipeData['image'];

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: recipeImage != null && recipeImage.isNotEmpty
                          ? Image.network(
                              recipeImage,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            )
                          : Icon(Icons.image, size: 60, color: Colors.grey),
                    ),
                    title: Text(
                      recipeName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        _showDeleteConfirmationDialog(recipeId, recipeName);
                      },
                    ),
                    onTap: () async {
                      final doc = await _fetchRecipeDetails(recipeId);
                      if (!doc.exists) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Recipe not found')),
                        );
                        return;
                      }

                      final recipeData = doc.data() as Map<String, dynamic>;
                      final flag = recipeData['flag'] ?? 'unknown';

                      if (flag == 'recipes') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecipeDetailPage(
                              recipeId: recipeId,
                              username: widget.username,
                            ),
                          ),
                        );
                      } else if (flag == 'users_recipes') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecipeDetailPageUser(
                              recipeId: recipeId,
                              username: widget.username,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Unknown recipe type')),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: CustomNavBar(
        username: widget.username,
        currentIndex: 2,
      ),
    );
  }
}
