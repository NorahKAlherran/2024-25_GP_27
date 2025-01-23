import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'nav_bar.dart';
import 'chat_service.dart';

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
  bool _isInCollection = false;
  bool _isEditingNote = false;
  TextEditingController _noteController = TextEditingController();


  Map<String, dynamic>? _recipeData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRecipeData();
    _checkIfFavorite(); // Check favorite status when the page loads
  }

  Future<void> _fetchRecipeData() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    setState(() => _isLoading = false);
    return;
  }

  try {
    DocumentSnapshot recipeDoc = await FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .get();

    if (!recipeDoc.exists) {
      setState(() {
        _isLoading = false;
        _recipeData = null; // Explicitly handle the case where the document does not exist.
      });
      return;
    }

    setState(() {
      _recipeData = recipeDoc.data() as Map<String, dynamic>?;
      _isLoading = false;
    });

    // Fetch collections to find the note associated with this recipe
    final collectionSnapshot = await FirebaseFirestore.instance
        .collection('collections')
        .where('createdBy', isEqualTo: user.uid)
        .get();

      for (var doc in collectionSnapshot.docs) {
      var recipes = List<Map<String, dynamic>>.from(doc.data()['recipes']);
      var foundRecipe = recipes.firstWhere(
          (recipe) => recipe['id'] == widget.recipeId,
          orElse: () => {});
      if (foundRecipe.isNotEmpty) {
        setState(() {
          _noteController.text = foundRecipe['note'] ?? ''; // Persist note on page load
        });
        break;
      }
    }
  } catch (e) {
    print("Error fetching recipe data: $e");
    setState(() {
      _isLoading = false;
      _recipeData = null;
    });
  }
}


 Future<void> _checkIfFavorite() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
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

    // Use setState to update the UI immediately
    setState(() {
      _isFavorite = isFavorite;
      _isInCollection = isInCollection;
    });
  } catch (e) {
    print("Error checking favorite status: $e");
  }
}

Future<void> _fetchIngredientSubstitution(String ingredient) async {
    String substitution = await getIngredientSubstitution(ingredient);
    _showSubstitutionDialog(ingredient, substitution);
  }

 void _showSubstitutionDialog(String ingredient, String substitution) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Substitution for $ingredient', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold)),
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
          child: Text('OK', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
          style: TextButton.styleFrom(
            backgroundColor: Colors.green[50], // Light green background for the button
          ),
        ),
      ],
      shape: RoundedRectangleBorder( // Rounded corners for the dialog box
        borderRadius: BorderRadius.circular(20.0),
      ),
      backgroundColor: Colors.white,
      elevation: 24.0, // Adds shadow to the dialog box
    ),
  );
}

void _showIngredientsForSubstitution() {
  final String ingredientsString = _recipeData!['ingredients'] ?? '[]';
  final List<String> ingredients = ingredientsString
      .replaceAll(RegExp(r"[\[\]']"), '')
      .split(',')
      .map((ingredient) => ingredient.trim())
      .toList();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // Allows the bottom sheet to be dragged full screen.
    builder: (BuildContext context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.5, // The initial size of the sheet when opened.
        minChildSize: 0.3,     // The minimum size to which the sheet can be collapsed.
        maxChildSize: 0.95,    // The maximum size to which the sheet can be expanded.
        expand: false,         // Prevents the sheet from expanding beyond the maxChildSize.
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,  // Aligns header text to the left
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), // Enhanced padding for the header
                  child: Text(
                    'Ingredient Substitution',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 88, 126, 75)
                    )
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController, // Connecting the list to the draggable sheet's controller.
                    itemCount: ingredients.length,
                    itemBuilder: (BuildContext context, int index) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), // Increased vertical margin
                        elevation: 1,
                        child: ListTile(
                          title: Text(
                            ingredients[index],
                            style: TextStyle(
                              color: Colors.black, // Changed to black
                              fontWeight: FontWeight.bold, // Make text bold
                            )
                          ),
                          onTap: () => _fetchIngredientSubstitution(ingredients[index]),
                          trailing: Icon(Icons.swap_horiz, color: Color.fromARGB(255, 88, 126, 75)),
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


Future<void> _saveNote() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    final collections = await FirebaseFirestore.instance
        .collection('collections')
        .where('createdBy', isEqualTo: user.uid)
        .get();

    bool noteUpdated = false;

    for (var collectionDoc in collections.docs) {
      var collectionData = collectionDoc.data();
      var recipes = List<Map<String, dynamic>>.from(collectionData['recipes']);
      
      int recipeIndex = recipes.indexWhere((recipe) => recipe['id'] == widget.recipeId);
      if (recipeIndex != -1) {
        // Update the local state immediately
        recipes[recipeIndex]['note'] = _noteController.text;

        await FirebaseFirestore.instance
            .collection('collections')
            .doc(collectionDoc.id)
            .update({'recipes': recipes});

        setState(() {
          _isEditingNote = false;
        });

        noteUpdated = true;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Note saved successfully!')));
        break;
      }
    }

    if (!noteUpdated) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Note not found in collection')));
    }
  } catch (e) {
    print("Error saving note: $e");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save note')));
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

    bool foundAndDeleted = false;

    for (var collectionDoc in collections.docs) {
      var collectionData = collectionDoc.data();
      var recipes = List<Map<String, dynamic>>.from(collectionData['recipes']);
      
      int recipeIndex = recipes.indexWhere((recipe) => recipe['id'] == widget.recipeId);
      if (recipeIndex != -1 && recipes[recipeIndex].containsKey('note')) {
        // Directly remove note from the local state and Firestore
        recipes[recipeIndex].remove('note');

        await FirebaseFirestore.instance
            .collection('collections')
            .doc(collectionDoc.id)
            .update({'recipes': recipes});

        setState(() {
          _noteController.clear(); // Clear the text field immediately
          _isEditingNote = false;  
        });

        foundAndDeleted = true;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Note deleted successfully!')));
        break;
      }
    }

    if (!foundAndDeleted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No note found to delete')));
    }
  } catch (e) {
    print("Error deleting note: $e");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete note')));
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
                      maxLines: null,  // Allows the text field to expand with content
                      keyboardType: TextInputType.multiline,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _saveNote,
                      child: const Text('Save Note', style: TextStyle(color: Colors.white)),
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
                      width: double.infinity,  // Expands to full width of the card
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

   Future<void> _addToCollection(String collectionId, String collectionName) async {
  final collectionRef = FirebaseFirestore.instance.collection('collections').doc(collectionId);

  try {
    await collectionRef.update({
      'recipes': FieldValue.arrayUnion([
        {
          'id': widget.recipeId,
          'name': _recipeData!['name'],
          'image': _recipeData!['image'],
          'note': _noteController.text,
        }
      ]),
    });

    setState(() {
      _isFavorite = true;
      _isInCollection = true;  // Immediately reflect the change
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added to $collectionName')),
    );
     Navigator.of(context).pop(); 
  } catch (e) {
    print("Error adding to collection: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to add to collection')),
    );
  }
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
             // Note field displayed conditionally
            
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

            _buildNoteSection(),
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
