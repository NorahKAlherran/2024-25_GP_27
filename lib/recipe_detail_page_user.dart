import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'RecipesPage.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'nav_bar.dart';
import 'chat_service.dart';

// Helper function to format cooking time
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
  bool _showNoteSection = false;
  TextEditingController _noteController = TextEditingController();
  final PageController _pageController = PageController(initialPage: 1000);
  DateTime _displayedWeekStart =
      DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  bool _isTranslating = false;

  ////////////////////============================
  bool _showTranslated = false;
  bool _isFetchingSubstitution = false;
  String translatedTitle = '';
  String translatedDescription = '';
  String translatedDifficulty = '';
  List<String> translatedIngredients = [];
  List<String> translatedSteps = [];
  String translatedCookingTime = '';
  List<String> translatedTags = [];

  Future<void> translateRecipe() async {
    if (_recipeData == null) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users_recipes')
          .doc(widget.recipeId)
          .collection('translations')
          .doc('ar');

      final recipeRef = FirebaseFirestore.instance
          .collection('users_recipes')
          .doc(widget.recipeId);

      final recipeSnap = await recipeRef.get();
      final translationSnap = await docRef.get();

      final recipeLastUpdated = recipeSnap.data()?['lastUpdated'];
      final translationSourceLastUpdated =
          translationSnap.data()?['sourceLastUpdated'];

      Map<String, dynamic> translatedRecipe;

      final bool isTranslationUpToDate = translationSnap.exists &&
          translationSourceLastUpdated != null &&
          (recipeLastUpdated ==
                  null || // ✅ no recipe updates → translation is valid
              recipeLastUpdated
                  .toDate()
                  .isBefore(translationSourceLastUpdated.toDate()));

      if (isTranslationUpToDate) {
        print('✅ Using existing up-to-date translation.');
        translatedRecipe = translationSnap.data()!;
      } else {
        print('🚧 Generating new translation...');

        final tagsRaw = _recipeData?['Tags'] ?? [];
        List<String> tags =
            tagsRaw is List ? List<String>.from(tagsRaw) : [tagsRaw.toString()];

        final translated = await translateWholeRecipe(
          title: _recipeData!['name'] ?? '',
          difficulty: _recipeData!['difficulty'] ?? '',
          description: _recipeData!['description'] ?? '',
          ingredients: _parseIngredients(_recipeData!['ingredients']),
          steps: _parseSteps(_recipeData!['steps']),
          cookingTime: _recipeData!['cookingTime'] ?? '',
          tags: tags,
        );


        translated['name'] = translated['title'];
        translated.remove('title');

//  Save to Firestore
        await docRef.set({
          ...translated,
          'sourceLastUpdated': FieldValue.serverTimestamp(),
        });

        // Merge tags
        final englishTags = List<String>.from(_recipeData!['Tags'] ?? []);
        final arabicTags = List<String>.from(translated['tags'] ?? []);
        final combinedTags = {...englishTags, ...arabicTags}.toList();
        await recipeRef.update({'Tags': combinedTags});
        _recipeData!['Tags'] = combinedTags;

        // Retrieve the saved translation again (with resolved timestamp)
        final updatedTranslation = await docRef.get();
        translatedRecipe = updatedTranslation.data()!;
      }
      String cleanArabicCookingTime(String raw) {
        // Normalize input by removing dots or bullet separators
        String cleaned = raw
            .replaceAll(RegExp(r'[•\.]'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        // Check if it's all zeros (any order or spacing)
        if (RegExp(r'^٠ ?ساعة ?٠ ?دقيقة ?٠ ?ثانية$').hasMatch(cleaned) ||
            cleaned.replaceAll(' ', '') == '٠ساعة٠دقيقة٠ثانية') {
          return 'المدة غير محددة';
        }

        // Remove zero parts
        return cleaned
            .replaceAll(RegExp(r'٠ ?ساعة'), '')
            .replaceAll(RegExp(r'٠ ?دقيقة'), '')
            .replaceAll(RegExp(r'٠ ?ثانية'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }

      if (!mounted) return;

      setState(() {
        translatedTitle = translatedRecipe['name'] ?? '';
        translatedDescription = translatedRecipe['description'] ?? '';
        translatedDifficulty = translatedRecipe['difficulty'] ?? '';
        translatedIngredients =
            List<String>.from(translatedRecipe['ingredients'] ?? []);
        translatedSteps = List<String>.from(translatedRecipe['steps'] ?? []);
        translatedCookingTime =
            cleanArabicCookingTime(translatedRecipe['cookingTime'] ?? '');

        translatedTags = List<String>.from(translatedRecipe['tags'] ?? []);
        _showTranslated = true;
      });
    } catch (e) {
      print("❌ Error in translateRecipe: $e");
    }
  }

  List<String> _parseIngredients(dynamic ingredientsRaw) {
    return ingredientsRaw
        .toString()
        .replaceAll(RegExp(r"[\[\]']"), '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> _parseSteps(String stepsRaw) {
    return stepsRaw
        .replaceAll(RegExp(r"[\[\]']"), '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

////////////////////=====================================

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

        if (!_recipeData!.containsKey('Tags') || _recipeData!['Tags'] == null) {
          print("No tags found");
        }
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

  void _showIngredientSubstitutionBottomSheet() {
    if (_recipeData == null || !_recipeData!.containsKey('ingredients')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No ingredients found for this recipe.")),
      );
      return;
    }

    final List<String> ingredients = _showTranslated
        ? translatedIngredients
        : (_recipeData!['ingredients'] as String)
            .replaceAll(RegExp(r"[\[\]']"), '')
            .split(',')
            .map((ingredient) => ingredient.trim())
            .where((ingredient) => ingredient.isNotEmpty)
            .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: _showTranslated
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: _showTranslated
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Text(
                      _showTranslated
                          ? ":اختر مكونًا لاستبداله"
                          : "Select an Ingredient to Replace:",
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign:
                          _showTranslated ? TextAlign.right : TextAlign.left,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: ingredients.length,
                      itemBuilder: (context, index) {
                        return Align(
                          alignment: _showTranslated
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ListTile(
                            contentPadding: EdgeInsets.only(
                              left: _showTranslated ? 0 : 16,
                              right: _showTranslated ? 16 : 0,
                            ),
                            title: Align(
                              alignment: _showTranslated
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Text(
                                ingredients[index],
                                textAlign: _showTranslated
                                    ? TextAlign.right
                                    : TextAlign.left,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.swap_horiz,
                              color: Colors.green,
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              _fetchIngredientSubstitution(ingredients[index]);
                            },
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

  String cleanArabicSubstitution(String raw) {
    final arabicNumbers = {
      '0': '٠',
      '1': '١',
      '2': '٢',
      '3': '٣',
      '4': '٤',
      '5': '٥',
      '6': '٦',
      '7': '٧',
      '8': '٨',
      '9': '٩'
    };
    final unitMap = {
      'g': 'غرام',
      'kg': 'كيلو',
      'ml': 'مل',
      'l': 'لتر',
      'tsp': 'ملعقة صغيرة',
      'tbsp': 'ملعقة كبيرة'
    };

    String cleaned = raw;

    // Convert English digits to Arabic digits
    arabicNumbers.forEach((eng, ar) {
      cleaned = cleaned.replaceAll(eng, ar);
    });

    // Convert common measurement units
    unitMap.forEach((eng, ar) {
      cleaned = cleaned.replaceAll(
          RegExp(r'\b' + eng + r'\b', caseSensitive: false), ar);
    });

    // Replace dash bullets with •
    cleaned = cleaned.replaceAllMapped(
        RegExp(r'(?<!\n|^)-\s*(.+)'), (match) => '• ${match.group(1)}');

    return cleaned.trim();
  }

  void _fetchIngredientSubstitution(String ingredient) async {
    if (_recipeData == null) return;
    setState(() => _isFetchingSubstitution = true);

    final String recipeName = _recipeData!['name'] ?? 'Unknown Recipe';
    final List<String> englishIngredients =
        (_recipeData!['ingredients'] as String)
            .replaceAll(RegExp(r"[\[\]']"), '')
            .split(',')
            .map((i) => i.trim())
            .where((i) => i.isNotEmpty)
            .toList();

    int index = -1;

    if (_showTranslated && translatedIngredients.isNotEmpty) {
      index = translatedIngredients.indexOf(ingredient.trim());
    } else {
      index = englishIngredients.indexOf(ingredient.trim());
    }

    if (index == -1 || index >= englishIngredients.length) {
      print(" Ingredient index not found.");
      setState(() => _isFetchingSubstitution = false);
      return;
    }

    final String englishIngredient = englishIngredients[index];
    final String key = index.toString();

    final substitutionDocRef = FirebaseFirestore.instance
        .collection('users_recipes')
        .doc(widget.recipeId)
        .collection('substitutions')
        .doc(key);

    try {
      final snapshot = await substitutionDocRef.get();
      String englishAnswer = '';
      String finalAnswer = '';

      if (snapshot.exists) {
        final data = snapshot.data()!;
        englishAnswer = data['answer'] ?? 'No substitution found.';
        final arAnswer = data['ar'];

        if (_showTranslated) {
          if (arAnswer != null && arAnswer.toString().trim().isNotEmpty) {
            finalAnswer = arAnswer;
          } else {
            final translated = await translateToArabic(englishAnswer);
            final cleaned = cleanArabicSubstitution(translated);
            await substitutionDocRef.update({'ar': cleaned});
            finalAnswer = cleaned;
          }
        } else {
          finalAnswer = englishAnswer;
        }
      } else {
        englishAnswer = await getIngredientSubstitution(
          englishIngredient,
          recipeName,
          englishIngredients,
        );

        final rawArabic = await translateToArabic(englishAnswer);
        final arabicAnswer = cleanArabicSubstitution(rawArabic);

        await substitutionDocRef.set({
          'ingredient': englishIngredient,
          'answer': englishAnswer,
          'ar': arabicAnswer,
          'timestamp': FieldValue.serverTimestamp(),
        });

        finalAnswer = _showTranslated ? arabicAnswer : englishAnswer;
      }

      // Warning split
      String warningText = '';
      String restText = finalAnswer;
      if (finalAnswer.startsWith("⚠️")) {
        final splitIndex = finalAnswer.indexOf('\n\n');
        if (splitIndex != -1) {
          warningText = finalAnswer.substring(0, splitIndex).trim();
          restText = finalAnswer.substring(splitIndex + 2).trim();
        } else {
          warningText = finalAnswer.trim();
          restText = '';
        }
      }

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Align(
              alignment: _showTranslated
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Text(
                _showTranslated
                    ? "بديل لـ $ingredient"
                    : "Substitution for $ingredient",
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: _showTranslated ? TextAlign.right : TextAlign.left,
              ),
            ),
            content: RichText(
              textAlign: _showTranslated ? TextAlign.right : TextAlign.left,
              text: TextSpan(
                children: [
                  if (warningText.isNotEmpty)
                    TextSpan(
                      text: warningText + '\n\n',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                  TextSpan(
                    text: restText,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(_showTranslated ? "تم" : "OK"),
                style: TextButton.styleFrom(foregroundColor: Colors.green),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print("❌ Error fetching substitution: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to fetch substitution.")),
      );
    } finally {
      setState(() => _isFetchingSubstitution = false);
    }
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

    setState(() {}); // Refresh UI to reflect note fetching
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

    return Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 1,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Note',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
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
                          width: double.infinity,
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
                              onPressed: _showDeleteConfirmationDialog,
                            ),
                          ],
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Delete Note",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red[800],
            ),
          ),
          content: Text(
            "Are you sure you want to delete this note?",
            style: TextStyle(
              fontSize: 16,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(); // Dismiss the dialog without deleting
              },
              child: Text("Cancel"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black87,
                backgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteNote();
              },
              child: Text("Delete"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 24.0,
        );
      },
    );
  }

  void _showRemoveFromCollectionConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Remove Recipe",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red[800],
            ),
          ),
          content: Text(
            "Are you sure you want to remove this recipe from collection?",
            style: TextStyle(
              fontSize: 16,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black87,
                backgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeFromCollection();
              },
              child: Text("Remove"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 24.0,
        );
      },
    );
  }

  Future<void> _removeFromCollection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final collectionSnapshot = await FirebaseFirestore.instance
        .collection('collections')
        .where('createdBy', isEqualTo: user.uid)
        .get();

    bool removed = false; // Flag to check if removal was successful

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

        removed =
            true; // Set removed to true as the recipe was found and removed
      }
    }

    if (removed) {
      setState(() {
        _isFavorite = false;
        _isInCollection = false; // Immediately reflect the change
        _noteController.text = "";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recipe removed from collection')),
      );
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

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  void _showWeeklyPlannerDialog() {
    final List<String> daysOfWeek = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final DateTime now = DateTime.now();
        final DateTime currentWeekStart =
            now.subtract(Duration(days: now.weekday - 1));
        DateTime endOfDisplayedWeek =
            _displayedWeekStart.add(Duration(days: 6));

        return StatefulBuilder(
          builder: (context, setState) {
            bool showLeftArrow = _displayedWeekStart.isAfter(currentWeekStart);

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ Dialog Header
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            Color.fromARGB(255, 137, 174, 124), // Green header
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(15)),
                      ),
                      child: Center(
                        child: Text(
                          "Add Meal to Planner",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 10),

                    // ✅ Week Navigation
                    Container(
                      padding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left Arrow (Only show if not the current week)
                          if (showLeftArrow)
                            IconButton(
                              icon: Icon(Icons.arrow_back, color: Colors.black),
                              onPressed: () {
                                setState(() {
                                  _displayedWeekStart = _displayedWeekStart
                                      .subtract(Duration(days: 7));
                                  endOfDisplayedWeek = _displayedWeekStart
                                      .add(Duration(days: 6));
                                });
                              },
                            ),

                          // Date Range (Always centered)
                          Expanded(
                            child: Center(
                              child: Text(
                                "${DateFormat('dd MMM').format(_displayedWeekStart)} - ${DateFormat('dd MMM yyyy').format(endOfDisplayedWeek)}",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),

                          // Right Arrow (Always visible)
                          IconButton(
                            icon:
                                Icon(Icons.arrow_forward, color: Colors.black),
                            onPressed: () {
                              setState(() {
                                _displayedWeekStart =
                                    _displayedWeekStart.add(Duration(days: 7));
                                endOfDisplayedWeek =
                                    _displayedWeekStart.add(Duration(days: 6));
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 10),

                    // ✅ Days List (Styled like the screenshot)
                    Column(
                      children: daysOfWeek.asMap().entries.map((entry) {
                        final int index = entry.key;
                        final String day = entry.value;
                        final DateTime dayDate =
                            _displayedWeekStart.add(Duration(days: index));
                        final bool isToday = _isSameDay(dayDate, now);
                        final bool isPastDay = dayDate.isBefore(now) &&
                            !isToday; // Past days except today

                        return GestureDetector(
                          onTap: isPastDay
                              ? null // Disable tap on past days
                              : () {
                                  Navigator.of(context).pop();
                                  _showMealTypeDialog(day);
                                },
                          child: Container(
                            margin: EdgeInsets.symmetric(
                                vertical: 5, horizontal: 12),
                            padding: EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? Color.fromARGB(255, 137, 174,
                                      124) // ✅ Highlight today in green
                                  : isPastDay
                                      ? Colors.grey[300] // ✅ Grey out past days
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  day,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isToday
                                        ? Colors.white
                                        : isPastDay
                                            ? Colors.grey[
                                                600] // ✅ Darker grey for past days text
                                            : Colors.black,
                                  ),
                                ),
                                Icon(
                                  Icons.add_circle_outline,
                                  color: isToday
                                      ? Colors.white
                                      : isPastDay
                                          ? Colors.grey[
                                              500] // ✅ Grey out add icon for past days
                                          : Colors.green,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMealTypeDialog(String day) {
    final List<Map<String, dynamic>> mealTypes = [
      {
        'type': 'Breakfast',
        'icon': Icons.wb_sunny_outlined,
        'color': Colors.blue
      },
      {'type': 'Lunch', 'icon': Icons.wb_sunny, 'color': Colors.orange},
      {'type': 'Dinner', 'icon': Icons.nightlight_round, 'color': Colors.red},
      {'type': 'Snacks', 'icon': Icons.card_giftcard, 'color': Colors.green},
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          elevation: 10,
          backgroundColor: Colors.white,
          title: Center(
            child: Text(
              "Select Meal Type",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: mealTypes.map((meal) {
              return ListTile(
                leading: Icon(
                  meal['icon'],
                  color: meal['color'],
                  size: 24,
                ),
                title: Text(
                  meal['type'],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop(); // Close dialog
                  _addRecipeToPlanner(day, meal['type']); // Add the meal
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _addRecipeToPlanner(String day, String mealType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _recipeData == null) return;

    try {
      // ✅ Get the correct dateKey for the selected day
      final DateTime dayDate =
          _displayedWeekStart.add(Duration(days: _getDayIndex(day)));
      final String dateKey = DateFormat('yyyy-MM-dd').format(dayDate);

      // ✅ Reference to the Firestore document
      final plannerRef = FirebaseFirestore.instance
          .collection('planner')
          .doc(widget.username) // ✅ Save under username, not random UID
          .collection('weeks')
          .doc(dateKey);

      // ✅ Fetch existing data to avoid overwriting
      final docSnapshot = await plannerRef.get();
      Map<String, dynamic> existingData =
          docSnapshot.exists ? docSnapshot.data() ?? {} : {};

      // ✅ Ensure 'meals' is always treated as a List<dynamic>
      List<dynamic> meals = [];
      if (existingData.containsKey('meals') &&
          existingData['meals'] is List<dynamic>) {
        meals = List<dynamic>.from(existingData['meals']);
      }

      // ✅ Create new meal entry
      Map<String, dynamic> newMeal = {
        'recipeId': widget.recipeId,
        'image':
            (_recipeData!['image'] is List && _recipeData!['image'].isNotEmpty)
                ? _recipeData!['image'][0] // ✅ Use first image
                : _recipeData!['image'] ?? 'https://via.placeholder.com/50',
        'name': _recipeData!['name'],
        'type': mealType,
        'source': "users_recipes",
      };

      // ✅ Add the new meal to the list
      meals.add(newMeal);

      // ✅ Update Firestore: Merge the new meal with existing data
      await plannerRef.set({'meals': meals}, SetOptions(merge: true));

      // ✅ Show confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added to $day ($mealType)')),
      );
    } catch (e) {
      print("❌ Error adding recipe to planner: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to planner')),
      );
    }
  }

  /// Helper function to get the index of the selected day
  int _getDayIndex(String day) {
    final List<String> daysOfWeek = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return daysOfWeek.indexOf(day);
  }

  String _getWeekId(DateTime startOfWeek) {
    return DateFormat('yyyy-MM-dd').format(startOfWeek);
  }

  String _convertStepNumberToArabic(int number) {
    const arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number
        .toString()
        .split('')
        .map((e) => arabicNumbers[int.parse(e)])
        .join();
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
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Container(
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

                  final String description =
                      data['description'] ?? 'No description';
                  final String difficulty =
                      data['difficulty'] ?? 'Unknown Difficulty';
                  final String cookingTime =
                      data['cookingTime'] ?? 'Not specified';

                  final String ingredientsString = data['ingredients'] ?? '[]';
                  final List<String> ingredients = _showTranslated
                      ? translatedIngredients
                      : ingredientsString
                          .replaceAll(RegExp(r"[\[\]']"), '')
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();

                  final String stepsString = data['steps'] ?? '';
                  final List<String> steps = _showTranslated
                      ? translatedSteps
                      : stepsString
                          .replaceAll(RegExp(r"[\[\]']"), '')
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();

//Extract and clean tags
                  final List<String> tags = (_recipeData?['Tags'] is List)
                      ? List<String>.from(_recipeData!['Tags'])
                          .where((tag) => _showTranslated
                              ? RegExp(r'^[\u0600-\u06FF]')
                                  .hasMatch(tag) // Arabic
                              : !RegExp(r'^[\u0600-\u06FF]')
                                  .hasMatch(tag)) // English
                          .toList()
                      : [];

                  final List<Color> tagColors = [
                    Color(0xFFE3B7D0), // Pastel Pink
                    Color(0xFFC1C8E4), // Pastel Blue
                    Color(0xFFC1E1DC), // Pastel Mint
                    Color(0xFFF7D1BA), // Pastel Peach
                    Color(0xFFF2D7E0), // Pastel Lavender
                    Color(0xFFF7F1B5), // Pastel Yellow
                    Color(0xFFD3F8E2), // Pastel Green
                    Color(0xFFF9E2C0), // Pastel Orange
                  ];
                  final String labelCookingTime =
                      _showTranslated ? "مدة الطهي:\u200F" : "Cooking Time:";
                  final String labelIngredients =
                      _showTranslated ? "المكونات:\u200F" : "Ingredients:";
                  final String labelSteps =
                      _showTranslated ? "الخطوات:\u200F" : "Steps:";
                  final String labelTags =
                      _showTranslated ? "علامات:\u200F" : "Tags:";

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 250,
                          child: Stack(
                            children: [
                              PageView.builder(
                                controller: _pageController,
                                itemCount: null, // Infinite scrolling
                                itemBuilder: (context, index) {
                                  final actualIndex = index %
                                      images.length; // Loop through images
                                  return Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(
                                        image:
                                            NetworkImage(images[actualIndex]),
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
                                        color: Colors.black.withOpacity(0.8),
                                      ),
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        Icons.arrow_back_ios,
                                        size: 24.0,
                                        color: Colors.white,
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
                                        color: Colors.black.withOpacity(0.8),
                                      ),
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        Icons.arrow_forward_ios,
                                        size: 24.0,
                                        color: Colors.white,
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
                              _showTranslated ? translatedTitle : name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _showTranslated
                                  ? translatedDifficulty
                                  : difficulty, // Display difficulty
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
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _isFetchingSubstitution
                                          ? const SizedBox(
                                              height: 36,
                                              width: 36,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            )
                                          : const Icon(
                                              Icons.compare_arrows,
                                              size: 36.0,
                                              color: Color.fromRGBO(
                                                  88, 126, 75, 1),
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
                                  onPressed: _isFetchingSubstitution
                                      ? null
                                      : _showIngredientSubstitutionBottomSheet,
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _isTranslating
                                      ? const SizedBox(
                                          height: 36,
                                          width: 36,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.translate,
                                          size: 36.0,
                                          color:
                                              Color.fromRGBO(88, 126, 75, 1)),
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
                              onPressed: _isTranslating
                                  ? null
                                  : () async {
                                      if (!_showTranslated) {
                                        setState(() => _isTranslating = true);
                                        await translateRecipe();
                                        setState(() {
                                          _showTranslated = true;
                                          _isTranslating = false;
                                        });
                                      } else {
                                        setState(() => _showTranslated = false);
                                      }
                                    },
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
                                  _showRemoveFromCollectionConfirmationDialog();
                                }
                              },
                            ),
                            if (_isInCollection) // Add Note button only if in collection
                              Flexible(
                                child: IconButton(
                                  icon: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        'assets/images/write.png',
                                        height: 36.0,
                                        width: 36.0,
                                        fit: BoxFit.contain,
                                      ),
                                      Text(
                                        'My Note',
                                        style: TextStyle(
                                          fontSize: 12.0,
                                          fontWeight: FontWeight.bold,
                                          color: Color.fromRGBO(88, 126, 75, 1),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showNoteSection =
                                          !_showNoteSection; // Toggle the note section visibility
                                    });
                                  },
                                ),
                              ),
                          ],
                        ),
                        if (_showNoteSection) _buildNoteSection(),
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

                        const SizedBox(height: 10),

                        // Recipe description
                        Align(
                          alignment: _showTranslated
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Text(
                            _showTranslated
                                ? translatedDescription
                                : description,
                            style: TextStyle(fontSize: _fontSize),
                            textAlign: _showTranslated
                                ? TextAlign.right
                                : TextAlign.left,
                          ),
                        ),

                        const SizedBox(height: 20),
                        if (tags.isNotEmpty) ...[
                          Align(
                            alignment: _showTranslated
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Text(
                              labelTags,
                              style: TextStyle(
                                fontSize: _fontSize + 2,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: _showTranslated
                                  ? TextAlign.right
                                  : TextAlign.left,
                            ),
                          ),
                          Wrap(
                            alignment: _showTranslated
                                ? WrapAlignment.end
                                : WrapAlignment.start,
                            spacing: 5.0,
                            children: tags.asMap().entries.map((entry) {
                              int index = entry.key;
                              String tag = entry.value;

                              Color tagColor =
                                  tagColors[index % tagColors.length];

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RecipesPage(
                                        username: widget.username,
                                        selectedTag: tag,
                                      ),
                                    ),
                                  );
                                },
                                child: Chip(
                                  label: Text(
                                    tag.contains(RegExp(r'^[\u0600-\u06FF]'))
                                        ? "$tag#"
                                        : "#$tag",
                                    style: TextStyle(
                                      fontSize: _fontSize,
                                      color: Colors.black,
                                    ),
                                  ),
                                  backgroundColor: tagColor,
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(color: Colors.transparent),
                                  ),
                                  elevation: 0,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                        ],

                        Align(
                          alignment: _showTranslated
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: labelCookingTime,
                                  style: TextStyle(
                                    fontSize: _fontSize + 4,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: _showTranslated
                                      ? translatedCookingTime
                                      : formatCookingTime(cookingTime),
                                  style: TextStyle(
                                    fontSize: _fontSize + 4,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: _showTranslated
                                ? TextAlign.right
                                : TextAlign.left,
                          ),
                        ),

                        const SizedBox(height: 20),
                        // Ingredients section
                        Align(
                          alignment: _showTranslated
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Text(
                            labelIngredients,
                            style: TextStyle(
                              fontSize: _fontSize + 4,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: _showTranslated
                                ? TextAlign.right
                                : TextAlign.left,
                          ),
                        ),

                        const SizedBox(height: 10),
                        ...ingredients.map((ingredient) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 2),
                              child: Align(
                                alignment: _showTranslated
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: _showTranslated
                                      ? [
                                          Text(
                                            ingredient,
                                            textAlign: TextAlign.right,
                                            style:
                                                TextStyle(fontSize: _fontSize),
                                            softWrap: true,
                                          ),
                                          const SizedBox(width: 6),
                                          const Text('•',
                                              style: TextStyle(fontSize: 18)),
                                        ]
                                      : [
                                          const Text('•',
                                              style: TextStyle(fontSize: 18)),
                                          const SizedBox(width: 6),
                                          Text(
                                            ingredient,
                                            textAlign: TextAlign.right,
                                            style:
                                                TextStyle(fontSize: _fontSize),
                                            softWrap: true,
                                          ),
                                        ],
                                ),
                              ),
                            )),
                        const SizedBox(height: 10),
                        // Steps section
                        Align(
                          alignment: _showTranslated
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Text(
                            labelSteps,
                            style: TextStyle(
                              fontSize: _fontSize + 4,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: _showTranslated
                                ? TextAlign.right
                                : TextAlign.left,
                          ),
                        ),

                        const SizedBox(height: 10),
                        for (int i = 0; i < steps.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Align(
                              alignment: _showTranslated
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Text(
                                _showTranslated
                                    ? "${_convertStepNumberToArabic(i + 1)}: ${steps[i]}"
                                    : "Step ${i + 1}: ${steps[i]}",
                                style: TextStyle(fontSize: _fontSize),
                                textAlign: _showTranslated
                                    ? TextAlign.right
                                    : TextAlign.left,
                                softWrap: true,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _showWeeklyPlannerDialog,
              backgroundColor: const Color.fromARGB(255, 137, 174, 124),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/schedule.png', // Ensure the path to the image is correct
                    width: 24, // Adjust the size of the image as needed
                    height: 24, // Adjust the size of the image as needed
                  ),
                  Icon(Icons.add, size: 20, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomNavBar(
        username: widget.username,
        currentIndex: 2,
      ),
    );
  }
}
