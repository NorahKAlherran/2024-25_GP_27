import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'nav_bar.dart';
import 'chat_service.dart';

// Helper function to format cooking time.
String formatCookingTime(String cookingTime) {
  int hours = 0;
  int minutes = 0;
  int seconds = 0;

  // cookingTime is in the format "0h 15m 0s"
  RegExp exp = RegExp(r"(\d+)h|(\d+)m|(\d+)s");
  Iterable<Match> matches = exp.allMatches(cookingTime);

  for (var match in matches) {
    if (match.group(0)!.contains('h')) {
      hours = int.parse(match.group(0)!.replaceAll('h', ''));
    }
    if (match.group(0)!.contains('m')) {
      minutes = int.parse(match.group(0)!.replaceAll('m', ''));
    }
    if (match.group(0)!.contains('s')) {
      seconds = int.parse(match.group(0)!.replaceAll('s', ''));
    }
  }

  // If hours, minutes, and seconds are all zero, return the "not specified" message
  if (hours == 0 && minutes == 0 && seconds == 0) {
    return 'Time is flexible :)';
  }

  // Otherwise, format the time as needed
  String formattedTime = "";
  if (hours > 0) formattedTime += "${hours}h ";
  if (minutes > 0) formattedTime += "${minutes}m ";
  if (seconds > 0) formattedTime += "${seconds}s";

  return formattedTime.trim();
}

class RecipeDetailPageUser extends StatefulWidget {
  final String recipeId;
  final String username;

  const RecipeDetailPageUser(
      {super.key, required this.recipeId, required this.username});

  @override
  _RecipeDetailPageUserState createState() => _RecipeDetailPageUserState();
}

Map<String, dynamic>? _recipeData;

class _RecipeDetailPageUserState extends State<RecipeDetailPageUser> {
  bool _isFavorite = false;
  double _fontSize = 16.0;
  Future<DocumentSnapshot>? _recipeFuture;
  bool _isInCollection = false;
  bool _isEditingNote = false;
  TextEditingController _noteController = TextEditingController();
// Define a PageController for controlling the PageView
  final PageController _pageController = PageController(initialPage: 1000);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    _initializeRecipeData();
    super.initState();
    _recipeFuture = FirebaseFirestore.instance
        .collection('users_recipes')
        .doc(widget.recipeId)
        .get();

    _checkIfFavorite();
    _fetchNote();
  }

  Future<void> _initializeRecipeData() async {
    try {
      final recipeDoc = await FirebaseFirestore.instance
          .collection('users_recipes')
          .doc(widget.recipeId)
          .get();

      if (recipeDoc.exists) {
        setState(() {
          _recipeData = recipeDoc.data() as Map<String, dynamic>;
        });
      } else {
        setState(() {
          _recipeData = null; // Handle missing data
        });
        print("Error: Recipe document does not exist!");
      }
    } catch (e) {
      setState(() {
        _recipeData = null;
      });
      print("Error fetching recipe data: $e");
    }
  }

//////////////////////////////////////////////////////////////

  Future<void> _fetchIngredientSubstitution(String ingredient) async {
    final String ingredientsString = _recipeData?['ingredients'] ?? '[]';
    print('Ingredients string: $ingredientsString');
    final List<String> ingredients = ingredientsString
        .replaceAll(RegExp(r"[\[\]']"), '')
        .split(',')
        .map((ingredient) => ingredient.trim())
        .toList();

    print('Parsed ingredients: $ingredients');
    String substitution = await getIngredientSubstitution(ingredient);
    _showSubstitutionDialog(ingredient, substitution);
  }

  void _showSubstitutionDialog(String ingredient, String substitution) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Substitution for $ingredient',
            style: TextStyle(
                color: Colors.green[800], fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text(substitution, style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK',
                style: TextStyle(
                    color: Colors.green[700], fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              backgroundColor:
                  Colors.green[50], // Light green background for the button
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          // Rounded corners for the dialog box
          borderRadius: BorderRadius.circular(20.0),
        ),
        backgroundColor: Colors.white,
        elevation: 24.0, // Adds shadow to the dialog box
      ),
    );
  }

  void _showIngredientsForSubstitution() {
    if (_recipeData == null || !_recipeData!.containsKey('ingredients')) {
      print("Error: Recipe data or ingredients are null!");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No ingredients found for substitution.")),
      );
      return;
    }
    print("Recipe data: $_recipeData");

    final String ingredientsString = _recipeData!['ingredients'] ?? '[]';
    final List<String> ingredients = ingredientsString
        .replaceAll(RegExp(r"[\[\]']"), '')
        .split(',')
        .map((ingredient) => ingredient.trim())
        .toList();

    if (ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No ingredients available for substitution.")),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled:
          true, // Allows the bottom sheet to be dragged full screen.
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5, // The initial size of the sheet when opened.
          minChildSize:
              0.3, // The minimum size to which the sheet can be collapsed.
          maxChildSize:
              0.95, // The maximum size to which the sheet can be expanded.
          expand:
              false, // Prevents the sheet from expanding beyond the maxChildSize.
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start, // Aligns header text to the left
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20), // Enhanced padding for the header
                    child: Text('Ingredient Substitution',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 88, 126, 75))),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller:
                          scrollController, // Connecting the list to the draggable sheet's controller.
                      itemCount: ingredients.length,
                      itemBuilder: (BuildContext context, int index) {
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8), // Increased vertical margin
                          elevation: 1,
                          child: ListTile(
                            title: Text(ingredients[index],
                                style: TextStyle(
                                  color: Colors.black, // Changed to black
                                  fontWeight: FontWeight.bold, // Make text bold
                                )),
                            onTap: () => _fetchIngredientSubstitution(
                                ingredients[index]),
                            trailing: Icon(Icons.swap_horiz,
                                color: Color.fromARGB(255, 88, 126, 75)),
                          ),
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
////////////////////////////////////////////////////////////////////////////////////

  Future<void> _fetchNote() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('collections')
        .where('createdBy', isEqualTo: user.uid)
        .get();

    bool foundNote = false;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final recipes = List<Map<String, dynamic>>.from(data['recipes']);

      // Find the recipe or provide a default empty map
      var recipe = recipes.firstWhere(
          (recipe) => recipe['id'] == widget.recipeId,
          orElse: () => {} // Returning an empty map if no match is found
          );

      // Check if the recipe is not empty before attempting to access 'note'
      if (recipe.isNotEmpty) {
        _noteController.text = recipe['note'] ?? '';
        foundNote = true;
        break;
      }
    }

    if (!foundNote) {
      _noteController.text = ''; // Initialize with empty if no note found
    }

    setState(() {}); // Refresh UI to reflect note fetching or initialization
  }

  void _checkIfFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('collections')
        .where('createdBy', isEqualTo: user.uid)
        .get();

    bool isFavorite = false;
    bool isInCollection = false;

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final recipes = data['recipes'] as List<dynamic>;
      if (recipes.any((recipe) => recipe['id'] == widget.recipeId)) {
        isFavorite = true;
        isInCollection = true;
        break;
      }
    }

    setState(() {
      _isFavorite = isFavorite;
      _isInCollection = isInCollection;
    });
  }

  Future<void> _saveNote() async {
    _checkIfFavorite();
    if (!_isInCollection) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final collections = await FirebaseFirestore.instance
          .collection('collections')
          .where('createdBy', isEqualTo: user.uid)
          .get();

      for (var collectionDoc in collections.docs) {
        var collectionData = collectionDoc.data();
        var recipes =
            List<Map<String, dynamic>>.from(collectionData['recipes']);

        int recipeIndex =
            recipes.indexWhere((recipe) => recipe['id'] == widget.recipeId);
        if (recipeIndex != -1) {
          // Found the recipe, update the note
          recipes[recipeIndex]['note'] = _noteController.text;
          await FirebaseFirestore.instance
              .collection('collections')
              .doc(collectionDoc.id)
              .update({'recipes': recipes});

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Note saved successfully!')),
          );
          setState(() {
            _isEditingNote = false; // Exit edit mode
          });
          break;
        }
      }
    } catch (e) {
      print("Error saving note: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save note')),
      );
    }
  }

  Future<void> _deleteNote() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final collections = await FirebaseFirestore.instance
          .collection('collections')
          .where('createdBy', isEqualTo: user.uid)
          .get();

      for (var collectionDoc in collections.docs) {
        var collectionData = collectionDoc.data();
        var recipes =
            List<Map<String, dynamic>>.from(collectionData['recipes']);

        int recipeIndex =
            recipes.indexWhere((recipe) => recipe['id'] == widget.recipeId);
        if (recipeIndex != -1) {
          recipes[recipeIndex].remove('note');
          await FirebaseFirestore.instance
              .collection('collections')
              .doc(collectionDoc.id)
              .update({'recipes': recipes});

          setState(() {
            _noteController.clear();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Note deleted successfully!')),
          );
          break;
        }
      }
    } catch (e) {
      print("Error deleting note: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete note')),
      );
    }
  }

  Widget _buildNoteSection() {
    if (!_isInCollection) {
      return SizedBox(); // Return an empty widget if the recipe is not in a collection
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Note',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(), // Adds a visual separation below the title
            _isEditingNote
                ? Column(
                    children: [
                      TextField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          labelText: 'Type Note',
                          border: OutlineInputBorder(),
                        ),
                        maxLines:
                            null, // Allows the text field to expand with content
                        keyboardType: TextInputType.multiline,
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _saveNote,
                        child: const Text('Save Note',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 137, 174, 124),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Expanding note content based on its length
                      Container(
                        width: double
                            .infinity, // Expands to full width of the card
                        child: Text(
                          _noteController.text.isNotEmpty
                              ? _noteController.text
                              : 'No note available',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.green),
                            onPressed: () {
                              setState(() {
                                _isEditingNote = true;
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: _deleteNote,
                          ),
                        ],
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  // Remove the recipe from the collection
  void _removeFromCollection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final collectionSnapshot = await FirebaseFirestore.instance
        .collection('collections')
        .where('createdBy', isEqualTo: user.uid)
        .get();

    for (var collectionDoc in collectionSnapshot.docs) {
      final collectionData = collectionDoc.data() as Map<String, dynamic>;
      final recipes =
          List<Map<String, dynamic>>.from(collectionData['recipes']);

      // Remove the recipe from the collection's recipes
      final updatedRecipes =
          recipes.where((recipe) => recipe['id'] != widget.recipeId).toList();

      if (updatedRecipes.length != recipes.length) {
        await FirebaseFirestore.instance
            .collection('collections')
            .doc(collectionDoc.id)
            .update({'recipes': updatedRecipes});

        setState(() {
          _isFavorite = false; // Update the state
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recipe removed from collection')),
        );
      }
    }
  }

  // Add to collection (handle the addition process)
  void _addToCollection(
      String recipeId, String recipeName, String recipeImage) {
    final TextEditingController _collectionNameController =
        TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    Future<void> _createCollection(String name) async {
      final collectionRef =
          FirebaseFirestore.instance.collection('collections');
      await collectionRef.add({
        'name': name,
        'recipes': [],
        'createdBy': user!.uid,
      });
    }

    Future<void> _addRecipeToCollection(
        String collectionId, String collectionName) async {
      final collectionRef = FirebaseFirestore.instance
          .collection('collections')
          .doc(collectionId);
      // Fetch the recipe from users_recipes to get the image URL
      final recipeDoc = await FirebaseFirestore.instance
          .collection('users_recipes')
          .doc(recipeId)
          .get();
      if (!recipeDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recipe not found!')),
        );
        return;
      }

      final recipeData = recipeDoc.data() as Map<String, dynamic>;

      // Extract image URL (use the first image if there are multiple)
      final List<dynamic>? imageList = recipeData['image'];
      final String recipeImageUrl =
          (imageList != null && imageList.isNotEmpty) ? imageList[0] : '';

      await collectionRef.update({
        'recipes': FieldValue.arrayUnion([
          {
            'id': recipeId,
            'name': recipeName,
            'image': recipeImageUrl,
          }
        ]),
      });
      await _fetchNote();
      setState(() {
        _isFavorite = true;
        _isInCollection = true;
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
                                _addRecipeToCollection(
                                    collection.id, data['name']);
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

  void _increaseFontSize() {
    setState(() {
      _fontSize += 2; // Increase font size by 2
    });
  }

  void _decreaseFontSize() {
    setState(() {
      if (_fontSize > 10) _fontSize -= 2; // Decrease font size by 2
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recipe Details"),
        backgroundColor: const Color.fromARGB(255, 137, 174, 124),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              DocumentSnapshot recipeSnapshot = await FirebaseFirestore.instance
                  .collection('users_recipes')
                  .doc(widget.recipeId)
                  .get();

              if (recipeSnapshot.exists) {
                final data = recipeSnapshot.data() as Map<String, dynamic>;
                final String name = data['name'] ?? 'Unnamed Recipe';
                final String description =
                    data['description'] ?? 'No description';
                final String shareContent = "$name\n\n$description";

                // Share the recipe
                await Share.share(shareContent);
              }
            },
          ),
        ],
      ),
      body: Container(
        color: const Color.fromARGB(255, 255, 255, 255),
        child: FutureBuilder<DocumentSnapshot>(
          future: _recipeFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              print("Error fetching recipe: ${snapshot.error}");
              return const Center(child: Text("Failed to load recipe."));
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text("Recipe not found."));
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final String name = data['name'] ?? 'Unnamed Recipe';
            final List<String> images =
                data['image'] != null && data['image'] is List
                    ? List<String>.from(data['image'])
                    : [];

            final String description = data['description'] ?? 'No description';
            final String difficulty =
                data['difficulty'] ?? 'Unknown Difficulty';
            final String cookingTime = data['cookingTime'] ?? 'Not specified';

            final String ingredientsString = data['ingredients'] ?? '[]';
            final List<String> ingredients = ingredientsString
                .substring(1, ingredientsString.length - 1)
                .split(',')
                .map((ingredient) =>
                    ingredient.trim().replaceAll(RegExp(r"(^')|('$)"), ''))
                .toList();

            final String stepsString = data['steps'] ?? '';
            final List<String> steps = stepsString
                .replaceAll(RegExp(r"[\[\]']"),
                    '') // Remove square brackets and single quotes
                .split(',')
                .map((step) =>
                    step.trim()) // Remove any extra spaces around steps
                .where((step) => step.isNotEmpty) // Filter out any empty steps
                .toList();

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Recipe image carousel using PageView
                    // Recipe image carousel using PageView
                    Container(
                      height: 250,
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: _pageController,
                            itemCount: null, // Infinite scrolling
                            itemBuilder: (context, index) {
                              final actualIndex =
                                  index % images.length; // Loop through images
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: NetworkImage(images[actualIndex]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                          if (images.length >
                              1) // Only show arrows if there is more than 1 image
                            Positioned(
                              left: 8.0,
                              top: 0.0,
                              bottom: 0.0,
                              child: GestureDetector(
                                onTap: () {
                                  _pageController.previousPage(
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withOpacity(
                                        0.8), // Dark background for bold effect
                                  ),
                                  padding: const EdgeInsets.all(
                                      8.0), // Padding to emphasize the arrow
                                  child: Icon(
                                    Icons.arrow_back_ios,
                                    size: 24.0, // Larger size for boldness
                                    color:
                                        Colors.white, // White for high contrast
                                  ),
                                ),
                              ),
                            ),
                          if (images.length >
                              1) // Only show arrows if there is more than 1 image
                            Positioned(
                              right: 8.0,
                              top: 0.0,
                              bottom: 0.0,
                              child: GestureDetector(
                                onTap: () {
                                  _pageController.nextPage(
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withOpacity(
                                        0.8), // Background for bold effect
                                  ),
                                  padding: const EdgeInsets.all(
                                      8.0), // Padding to enlarge the icon
                                  child: Icon(
                                    Icons.arrow_forward_ios,
                                    size: 24.0, // Larger size for boldness
                                    color: Colors
                                        .white, // Contrasting color for visibility
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          difficulty, // Display difficulty
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
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
                              icon: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.compare_arrows,
                                    size: 36.0,
                                    color: Color.fromRGBO(88, 126, 75, 1),
                                  ),
                                  Text(
                                    'Ingredient',
                                    style: TextStyle(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.bold,
                                      color: Color.fromRGBO(88, 126, 75, 1),
                                    ),
                                  ),
                                  Text(
                                    'substitution',
                                    style: TextStyle(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.bold,
                                      color: Color.fromRGBO(88, 126, 75, 1),
                                    ),
                                  ),
                                ],
                              ),
                              onPressed: _showIngredientsForSubstitution,
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
                                _isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
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
                            // Use the first image from the images list (if it exists)
                            String firstImage =
                                images.isNotEmpty ? images[0] : '';

                            if (!_isFavorite) {
                              // Add to collection with the first image
                              _addToCollection(
                                  widget.recipeId, name, firstImage);
                            } else {
                              // Remove from collection
                              _removeFromCollection();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: _decreaseFontSize,
                        ),
                        Text(
                          "${_fontSize.toInt()}",
                          style: const TextStyle(fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _increaseFontSize,
                        ),
                      ],
                    ),
                    _buildNoteSection(),
                    const SizedBox(height: 10),

                    // Recipe description
                    Text(
                      description,
                      style: TextStyle(fontSize: _fontSize),
                      textAlign: TextAlign.justify,
                    ),
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
                            text: formatCookingTime(
                                cookingTime), // Use the helper function here
                            style: TextStyle(
                              fontSize: _fontSize + 4,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    // Ingredients section
                    Text(
                      "Ingredients:",
                      style: TextStyle(
                        fontSize: _fontSize + 4,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...ingredients.map((ingredient) => Text("• $ingredient",
                        style: TextStyle(fontSize: _fontSize))),
                    const SizedBox(height: 20),

                    // Steps section
                    Text(
                      "Steps:",
                      style: TextStyle(
                        fontSize: _fontSize + 4,
                        fontWeight: FontWeight.bold,
                      ),
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
