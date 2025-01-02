import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'nav_bar.dart';

// qoot recipes details

class RecipeDetailPage extends StatefulWidget {
  final String recipeId;
  final String username;

  RecipeDetailPage({required this.recipeId, required this.username});

  @override
  _RecipeDetailPageState createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  bool _isFavorite = false;
  double _fontSize = 16.0;

  Map<String, dynamic>? _recipeData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRecipeData();
    _checkIfFavorite(); // Check favorite status when the page loads
  }

  Future<void> _fetchRecipeData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('recipes')
          .doc(widget.recipeId)
          .get();

      if (doc.exists) {
        setState(() {
          _recipeData = doc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching recipe data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkIfFavorite() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('collections')
          .where('createdBy', isEqualTo: user.uid)
          .get();

      bool isFavorite = false;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final recipes = data['recipes'] as List<dynamic>;

        if (recipes.any((recipe) => recipe['id'] == widget.recipeId)) {
          isFavorite = true;
          break;
        }
      }

      setState(() {
        _isFavorite = isFavorite;
      });
    } catch (e) {
      print("Error checking favorite status: $e");
    }
  }

  Future<void> _showCollectionSelector() async {
    final TextEditingController _collectionNameController =
        TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    Future<void> _createCollection(String name) async {
      final collectionRef =
          FirebaseFirestore.instance.collection('collections');
      await collectionRef.add({
        'name': name,
        'createdBy': user!.uid,
        'recipes': [],
      });
    }

    Future<void> _addToCollection(
        String collectionId, String collectionName) async {
      final collectionRef = FirebaseFirestore.instance
          .collection('collections')
          .doc(collectionId);

      await collectionRef.update({
        'recipes': FieldValue.arrayUnion([
          {
            'id': widget.recipeId,
            'name': _recipeData!['name'],
            'image': _recipeData!['image'],
          }
        ]),
      });

      setState(() {
        _isFavorite = true;
      });

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added to $collectionName')),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.4,
          maxChildSize: 0.7,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add to collection',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[300],
                      child: const Icon(Icons.add, color: Colors.black),
                    ),
                    title: const Text('Create new collection'),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          String? errorMessage; // To store the error message

                          return StatefulBuilder(
                            builder: (context, setState) {
                              return AlertDialog(
                                title: const Text('Create New Collection'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: _collectionNameController,
                                      decoration: InputDecoration(
                                        hintText: 'Collection Name',
                                        errorText:
                                            errorMessage, // Display the error message here
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      final name =
                                          _collectionNameController.text.trim();
                                      if (name.isNotEmpty) {
                                        // Check if the collection name already exists
                                        final existingCollection =
                                            await FirebaseFirestore.instance
                                                .collection('collections')
                                                .where('createdBy',
                                                    isEqualTo: user!.uid)
                                                .where('name', isEqualTo: name)
                                                .get();

                                        if (existingCollection
                                            .docs.isNotEmpty) {
                                          // Update the error message if the name already exists
                                          setState(() {
                                            errorMessage =
                                                'Collection name already exists.';
                                          });
                                        } else {
                                          // Clear the error message and create the collection
                                          setState(() {
                                            errorMessage = null;
                                          });
                                          await _createCollection(name);
                                          Navigator.of(context).pop();
                                        }
                                      } else {
                                        // Update the error message for empty input
                                        setState(() {
                                          errorMessage =
                                              'Collection name cannot be empty.';
                                        });
                                      }
                                    },
                                    child: const Text('Create'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  const Divider(),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('collections')
                          .where('createdBy', isEqualTo: user!.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final collections = snapshot.data!.docs;

                        if (collections.isEmpty) {
                          return const Center(
                              child: Text('No collections found.'));
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: collections.length,
                          itemBuilder: (context, index) {
                            final collection = collections[index];
                            final data =
                                collection.data() as Map<String, dynamic>;
                            final recipes = data['recipes'] as List<dynamic>;
                            final lastRecipeImage = recipes.isNotEmpty
                                ? recipes.last['image']
                                : null;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: lastRecipeImage != null
                                    ? NetworkImage(lastRecipeImage)
                                    : null,
                                backgroundColor: Colors.grey[300],
                                child: lastRecipeImage == null
                                    ? const Icon(Icons.image,
                                        color: Colors.grey)
                                    : null,
                              ),
                              title: Text(data['name']),
                              subtitle: Text('${recipes.length} recipes'),
                              onTap: () {
                                _addToCollection(collection.id, data['name']);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _removeFromAllCollections() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Query collections created by the user
      final snapshot = await FirebaseFirestore.instance
          .collection('collections')
          .where('createdBy', isEqualTo: user.uid)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final recipes = data['recipes'] as List<dynamic>;

        // Check if the recipe exists in the collection
        final recipeToRemove = recipes.firstWhere(
          (recipe) => recipe['id'] == widget.recipeId,
          orElse: () => null,
        );

        if (recipeToRemove != null) {
          // Remove the recipe from the collection
          await FirebaseFirestore.instance
              .collection('collections')
              .doc(doc.id)
              .update({
            'recipes': FieldValue.arrayRemove([recipeToRemove]),
          });
        }
      }

      // Update UI
      setState(() {
        _isFavorite = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe removed from all collections.')),
      );
    } catch (e) {
      print("Error removing recipe from collections: $e");
    }
  }

  void _increaseFontSize() {
    setState(() {
      _fontSize += 2;
    });
  }

  void _decreaseFontSize() {
    setState(() {
      if (_fontSize > 10) _fontSize -= 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Recipe Details"),
        backgroundColor: const Color.fromARGB(255, 137, 174, 124),
      ),
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _recipeData == null
              ? Center(child: Text("Recipe not found."))
              : _buildRecipeContent(),
      bottomNavigationBar: CustomNavBar(
        username: widget.username,
        currentIndex: 2,
      ),
    );
  }

  Widget _buildRecipeContent() {
    final String name = _recipeData!['name'] ?? 'Unnamed Recipe';
    final String image = _recipeData!['image'] ?? '';
    final String description = _recipeData!['description'] ?? 'No description';

    final String difficulty = _recipeData!['difficult'] ?? '';
    String difficultyLabel =
        difficulty == 'More effort' || difficulty == 'Challenge'
            ? 'Difficult'
            : difficulty;

    // Clean up ingredients by removing brackets, quotes, and extra characters
    final String ingredientsString = _recipeData!['ingredients'] ?? '[]';
    final List<String> ingredients = ingredientsString
        .replaceAll(
            RegExp(r"[\[\]']"), '') // Remove square brackets and single quotes
        .split(',')
        .map((ingredient) => ingredient.trim()) // Clean up extra spaces
        .toList();

    // Clean up steps by removing extra brackets, quotes, and characters
    final String stepsString = _recipeData!['steps'] ?? '';
    final List<String> steps = stepsString
        .replaceAll(
            RegExp(r"[\[\]']"), '') // Remove square brackets and single quotes
        .split('.')
        .map((step) => step.trim()) // Clean up spaces around steps
        .where((step) => step.isNotEmpty) // Filter out empty steps
        .toList();

    // Extract cooking time from the 'times' field
    final String timesString =
        _recipeData!['times'] ?? '{}'; // Ensure it's a string
    String cookingTime = '';

    // Use RegExp to find 'Cooking' time within the string
    final RegExp cookingRegExp = RegExp(r"Cooking':\s*'([^']*)");
    final Match? match = cookingRegExp.firstMatch(timesString);

    if (match != null) {
      cookingTime = match.group(1) ?? 'Unknown';
    } else {
      cookingTime = 'Unknown';
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: image.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(image),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: Colors.grey[300],
              ),
              child: image.isEmpty
                  ? Icon(Icons.image, size: 100, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              name,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            if (difficultyLabel.isNotEmpty)
              Text(
                difficultyLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: difficultyLabel == 'Difficult'
                      ? const Color.fromARGB(255, 19, 18, 18)
                      : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment
                      .center, // Optional: Centers the content vertically
                  children: [
                    IconButton(
                      icon: Icon(Icons.compare_arrows),
                      color: const Color.fromRGBO(88, 126, 75, 1),
                      iconSize: 36.0,
                      onPressed: () {},
                    ),
                    const Column(
                      children: [
                        Text(
                          'Ingredient',
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.bold,
                            color: Color.fromRGBO(
                                88, 126, 75, 1), // Match the icon's color
                          ),
                        ),
                        Text(
                          'substitution',
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.bold,
                            color: Color.fromRGBO(
                                88, 126, 75, 1), // Same color for consistency
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Column(
                    mainAxisSize: MainAxisSize
                        .min, // This ensures the column takes up minimal space
                    children: [
                      Icon(
                        Icons.translate,
                        size: 36.0,
                        color: Color.fromRGBO(88, 126, 75, 1),
                      ),
                      Text(
                        'Translation',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                          color: Color.fromRGBO(88, 126, 75, 1),
                        ),
                      ),
                    ],
                  ),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 40,
                        color: Colors.red,
                      ),
                      Text(
                        _isFavorite ? 'Favorite' : 'Collection',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () {
                    if (_isFavorite) {
                      // Remove the recipe from collections
                      _removeFromAllCollections();
                    } else {
                      // Show collection selector to add the recipe
                      _showCollectionSelector();
                    }
                  },
                )
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.remove),
                  onPressed: _decreaseFontSize,
                ),
                Text(
                  "${_fontSize.toInt()}",
                  style: TextStyle(fontSize: 16),
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: _increaseFontSize,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(description, style: TextStyle(fontSize: _fontSize)),
            const SizedBox(height: 20),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "Cooking Time: ",
                    style: TextStyle(
                      fontSize: _fontSize + 4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: "$cookingTime",
                    style: TextStyle(
                      fontSize: _fontSize + 4,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Ingredients:",
              style: TextStyle(
                  fontSize: _fontSize + 4, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            for (var ingredient in ingredients)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text("• $ingredient",
                    style: TextStyle(fontSize: _fontSize)),
              ),
            const SizedBox(height: 20),
            Text(
              "Steps:",
              style: TextStyle(
                  fontSize: _fontSize + 4, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  "Step ${i + 1}: ${steps[i]}.",
                  style: TextStyle(fontSize: _fontSize),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
