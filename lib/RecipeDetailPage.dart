import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'chat_service.dart';
import 'nav_bar.dart';
import 'MealPlanner.dart';
import 'dart:ui';
import 'RecipesPage.dart';
import 'dart:convert';
import 'package:intl/intl.dart' as intl;

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
  bool _showNoteSection = false;
  TextEditingController _noteController = TextEditingController();
  List<String> _tags = [];
  Map<String, dynamic>? _recipeData;
  bool _isLoading = true;
  DateTime _displayedWeekStart =
      DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  bool _showTranslated = false;
  bool _isTranslating = false;
  bool _isFetchingSubstitution = false;

  ///////////////////////////////////////
  String translatedTitle = '';
  String translatedDifficulty = '';
  String translatedDescription = '';
  List<String> translatedIngredients = [];
  List<String> translatedSteps = [];
  String translatedCookingTime = '';
  List<String> translatedTags = [];

  // Store translated cooking time

  // Function to call translateWholeRecipe

  Future<void> translateRecipe() async {
    try {
      final langCode = 'ar';
      final docRef = FirebaseFirestore.instance
          .collection('recipes')
          .doc(widget.recipeId)
          .collection('translations')
          .doc(langCode);

      final snapshot = await docRef.get();
      Map<String, dynamic> translatedRecipe;

      if (snapshot.exists) {
        print('✅ Translation already exists');
        translatedRecipe = snapshot.data()!;
      } else {
        print('🚧 No translation found, generating...');

        final timesRaw = _recipeData!['times'];
        Map<String, dynamic> times = {};
        if (timesRaw is String) {
          try {
            final cleanedJson = timesRaw.replaceAll(RegExp(r"(?<!\\)'"), '"');
            times = Map<String, dynamic>.from(jsonDecode(cleanedJson));
          } catch (_) {
            times = {};
          }
        } else if (timesRaw is Map) {
          times = Map<String, dynamic>.from(timesRaw);
        }

        final cookingTime = times['Cooking'] ?? 'Unknown';

        final tagsRaw = _recipeData?['Tags'] ?? [];
        List<String> tags =
            tagsRaw is List ? List<String>.from(tagsRaw) : [tagsRaw.toString()];

        translatedRecipe = await translateWholeRecipe(
          title: _recipeData!['name'] ?? '',
          difficulty: _recipeData!['difficult'] ?? '',
          description: _recipeData!['description'] ?? '',
          ingredients: _parseIngredients(_recipeData!['ingredients'] ?? '[]'),
          steps: _parseSteps(_recipeData!['steps'] ?? ''),
          cookingTime: cookingTime,
          tags: tags,
        );

        print('📦 Translated Recipe Output: $translatedRecipe');

        if (translatedRecipe.isNotEmpty) {
          await docRef.set(translatedRecipe);
          print('✅ Translation saved to Firestore');
        } else {
          print('⚠️ Empty translation result');
        }
      }

      if (!mounted) return;

      // Prepare combined tags for Firestore update
      final englishTagsRaw = _recipeData?['Tags'] ?? [];
      final englishTags = englishTagsRaw is List
          ? List<String>.from(englishTagsRaw)
          : [englishTagsRaw.toString()];
      final arabicTags = List<String>.from(translatedRecipe['tags'] ?? []);
      final combinedTags = {...englishTags, ...arabicTags}.toList();

      // ✅ Update Firestore tags separately
      await FirebaseFirestore.instance
          .collection('recipes')
          .doc(widget.recipeId)
          .update({'Tags': combinedTags});
      _recipeData!['Tags'] = combinedTags;
      // ✅ Now safely update state
      setState(() {
        translatedTitle = translatedRecipe['title'] ?? '';
        translatedDifficulty = translatedRecipe['difficulty'] ?? '';
        translatedDescription = translatedRecipe['description'] ?? '';
        translatedIngredients =
            List<String>.from(translatedRecipe['ingredients'] ?? []);
        translatedSteps = List<String>.from(translatedRecipe['steps'] ?? []);
        translatedCookingTime = translatedRecipe['cookingTime'] ?? '';
        translatedTags = combinedTags;
        _showTranslated = true;
      });
    } catch (e) {
      print('❌ Error translating recipe: $e');
    }
  }

// Helper function to handle string-to-list conversion
  List<String> _parseList(dynamic value) {
    if (value is String) {
      // Split by newline or comma to get each item as a separate list element
      return value.split(RegExp(r'\n|,')).map((e) => e.trim()).toList();
    }
    return [];
  }

  // Helper functions to parse ingredients and steps
  List<String> _parseIngredients(String ingredientsString) {
    return ingredientsString
        .replaceAll(
            RegExp(r"[\[\]']"), '') // Remove square brackets and single quotes
        .split(';')
        .map((ingredient) => ingredient.trim())
        .toList();
  }

  List<String> _parseSteps(String stepsString) {
    return stepsString
        .replaceAll(
            RegExp(r"[\[\]']"), '') // Remove square brackets and single quotes
        .split('.')
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .toList();
  }

/////////////////////////////////////////////////////////

  @override
  void initState() {
    super.initState();
    _fetchRecipeData();
    _checkIfFavorite();
  }

  Future<void> _generateAndSaveTags() async {
    if (_recipeData == null) return;

    String recipeName = _recipeData!['name'] ?? 'Unnamed Recipe';
    String description = _recipeData!['description'] ?? 'No description';
    List<String> ingredients = (_recipeData!['ingredients'] as String)
        .replaceAll(RegExp(r"[\[\]']"), '')
        .split(';')
        .map((ingredient) => ingredient.trim())
        .where((ingredient) => ingredient.isNotEmpty)
        .toList();

    try {
      List<String> tags =
          await generateRecipeTags(recipeName, description, ingredients);

      // Update Firestore with the new tags
      await FirebaseFirestore.instance
          .collection('recipes')
          .doc(widget.recipeId)
          .update({'Tags': tags});

      // Update local state
      setState(() {
        _recipeData!['Tags'] = tags;
      });

      print("Tags saved successfully: $tags");
    } catch (e) {
      print("Error generating tags: $e");
    }
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
          _recipeData = null;
        });
        return;
      }

      setState(() {
        _recipeData =
            recipeDoc.data() as Map<String, dynamic>?; // Fetch recipe data
        _isLoading = false;
      });

      // Check if Tags exist If not, generate and save them
      if (_recipeData != null && !_recipeData!.containsKey('Tags')) {
        await _generateAndSaveTags();
      }

      if (_recipeData != null) {
        final tagsData = _recipeData?['Tags'];
        List<String> tags = [];

        if (tagsData is List) {
          tags = List<String>.from(tagsData);
        } else if (tagsData is String) {
          tags = [tagsData];
        }

        setState(() {
          _tags = tags;
        });
      }

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
            _noteController.text =
                foundRecipe['note'] ?? ''; // Persist note on page load
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

///////////////////////////////////////////////////////////////
  void _showIngredientSubstitutionBottomSheet() {
    if (_recipeData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No ingredients found for this recipe.")),
      );
      return;
    }

    final List<String> ingredients = _showTranslated
        ? translatedIngredients
        : (_recipeData!['ingredients'] as String)
            .replaceAll(RegExp(r"[\[\]']"), '') // Clean brackets/quotes
            .split(';')
            .map((ingredient) => ingredient.trim())
            .where((ingredient) => ingredient.isNotEmpty)
            .toList();

    if (ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No ingredients found for this recipe.")),
      );
      return;
    }

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

  String convertToArabicNumbersAndUnits(String input) {
    const digitMap = {
      '0': '٠',
      '1': '١',
      '2': '٢',
      '3': '٣',
      '4': '٤',
      '5': '٥',
      '6': '٦',
      '7': '٧',
      '8': '٨',
      '9': '٩',
    };

    const unitMap = {
      'kg': 'كيلوغرام',
      'g': 'غرام',
      'ml': 'مل',
      'l': 'لتر',
      'tbsp': 'ملعقة كبيرة',
      'tsp': 'ملعقة صغيرة',
      'cup': 'كوب',
      'cups': 'أكواب',
    };

    // Convert digits
    String converted = input.replaceAllMapped(RegExp(r'\d'), (match) {
      return digitMap[match.group(0)]!;
    });

    // Convert units (longest first)
    unitMap.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length))
      ..forEach((entry) {
        converted = converted.replaceAllMapped(
          RegExp(r'\b' + entry.key + r'\b', caseSensitive: false),
          (match) => entry.value,
        );
      });

    return converted;
  }

List<String> formatArabicSubstitution(String raw) {
  String cleaned = raw.replaceAll('•', '');

  List<String> lines = cleaned
      .split(RegExp(r'[\.\n]')) // split by period or newline
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  List<String> result = [];

  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];

    if (line.startsWith('⚠️')) {
      result.add("⚠️ ${line.replaceFirst('⚠️', '').trim()}");
    } else {
      result.add("${line.trim()} \u2022"); // add bullet at the end
    }
  }

  return result;
}

  void _fetchIngredientSubstitution(String ingredient) async {
    if (_recipeData == null) return;
    setState(() => _isFetchingSubstitution = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isFetchingSubstitution = false);
      return;
    }

    final String recipeName = _recipeData!['name'] ?? 'Unknown Recipe';

    final List<String> englishIngredients =
        (_recipeData!['ingredients'] as String)
            .replaceAll(RegExp(r"[\[\]']"), '')
            .split(';')
            .map((i) => i.trim())
            .where((i) => i.isNotEmpty)
            .toList();

    int ingredientIndex = -1;

    if (_showTranslated && translatedIngredients.isNotEmpty) {
      ingredientIndex = translatedIngredients.indexWhere(
        (item) => item.trim() == ingredient.trim(),
      );
    } else {
      ingredientIndex = englishIngredients.indexWhere(
        (item) => item.trim() == ingredient.trim(),
      );
    }

    if (ingredientIndex == -1 || ingredientIndex >= englishIngredients.length) {
      print("❌ Ingredient index not found.");
      setState(() => _isFetchingSubstitution = false);
      return;
    }

    final String englishIngredient = englishIngredients[ingredientIndex];
    final String key = ingredientIndex.toString();

    final substitutionDocRef = FirebaseFirestore.instance
        .collection('recipes')
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

        if (_showTranslated) {
          final arAnswer = data['ar'];
          if (arAnswer != null && arAnswer.toString().trim().isNotEmpty) {
            finalAnswer = arAnswer;
          } else {
            final arabicTranslation = await translateToArabic(englishAnswer);
            await substitutionDocRef.update({'ar': arabicTranslation});
            finalAnswer = arabicTranslation;
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

        final arabicAnswer = await translateToArabic(englishAnswer);

        await substitutionDocRef.set({
          'ingredient': englishIngredient,
          'answer': englishAnswer,
          'ar': arabicAnswer,
          'createdBy': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });

        finalAnswer = _showTranslated ? arabicAnswer : englishAnswer;
      }

      final List<String> lines = _showTranslated
          ? formatArabicSubstitution(finalAnswer)
          : finalAnswer.split('\n');

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Align(
              alignment: _showTranslated
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Text(
                _showTranslated
                    ? "بديل لـ ${convertToArabicNumbersAndUnits(ingredient)}"
                    : "Substitution for $ingredient",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: _showTranslated ? TextAlign.right : TextAlign.left,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: _showTranslated
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: lines.map((line) {
                // Clean leading dashes/bullets
                final cleaned =
                    line.replaceAll(RegExp(r'^[•\-–—]+\s*'), '').trim();

                if (cleaned.startsWith('⚠️')) {
                  return Text(
                    cleaned,
                    textAlign:
                        _showTranslated ? TextAlign.right : TextAlign.left,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  );
                }

                // Format Arabic: move unit/number to end
                final formatted = _showTranslated
                    ? convertToArabicNumbersAndUnits(cleaned)
                        .replaceFirstMapped(
                        RegExp(
                          r'^(.*?)([٠-٩½¼¾⅓⅔⅛⅜⅝⅞ ]+(غرام|مل|كوب|كيلوغرام|لتر|ملعقة صغيرة|ملعقة كبيرة)?)',
                        ),
                        (match) =>
                            '${match.group(1)?.trim()} ${match.group(2)?.trim()}',
                      )
                    : cleaned;
                return Row(
                  mainAxisAlignment: _showTranslated
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    if (!_showTranslated)
                      const Text(
                        '- ',
                        style: TextStyle(fontSize: 18, color: Colors.black),
                      ),
                    Flexible(
                      child: Text(
                        formatted,
                        textAlign:
                            _showTranslated ? TextAlign.right : TextAlign.left,
                        style:
                            const TextStyle(fontSize: 18, color: Colors.black),
                      ),
                    ),
                    if (_showTranslated)
                      const Text(
                        ' -',
                        style: TextStyle(fontSize: 18, color: Colors.black),
                      ),
                  ],
                );
              }).toList(),
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
      print("❌ Error during substitution process: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to fetch substitution.")),
      );
    } finally {
      setState(() => _isFetchingSubstitution = false);
    }
  }

  ////////////////////////////////////////////////////
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
                Navigator.of(context).pop(); // Dismiss dialog first
                _removeFromAllCollections(); // Then proceed with the removal
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
        var recipes =
            List<Map<String, dynamic>>.from(collectionData['recipes']);

        int recipeIndex =
            recipes.indexWhere((recipe) => recipe['id'] == widget.recipeId);
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
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Note saved successfully!')));
          break;
        }
      }

      if (!noteUpdated) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Note not found in collection')));
      }
    } catch (e) {
      print("Error saving note: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save note')));
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
        var recipes =
            List<Map<String, dynamic>>.from(collectionData['recipes']);

        int recipeIndex =
            recipes.indexWhere((recipe) => recipe['id'] == widget.recipeId);
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
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Note deleted successfully!')));
          break;
        }
      }

      if (!foundAndDeleted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No note found to delete')));
      }
    } catch (e) {
      print("Error deleting note: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to delete note')));
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
                Navigator.of(context).pop();
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
          _isInCollection = true; // Immediately reflect the change
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
                          String? errorMessage;

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
                                        errorText: errorMessage,
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
      final snapshot = await FirebaseFirestore.instance
          .collection('collections')
          .where('createdBy', isEqualTo: user.uid)
          .get();

      bool removed = false;

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
          removed = true;
        }
      }

      if (removed) {
        // Update UI to reflect removal and clear the note
        setState(() {
          _isFavorite = false;
          _isInCollection = false;
          _noteController.clear(); // Clear the note controller
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe removed from all collections.')),
        );
      }
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
      final DateTime dayDate =
          _displayedWeekStart.add(Duration(days: _getDayIndex(day)));
      final String dateKey = DateFormat('yyyy-MM-dd').format(dayDate);

      final plannerRef = FirebaseFirestore.instance
          .collection('planner')
          .doc(widget.username)
          .collection('weeks')
          .doc(dateKey);

      final docSnapshot = await plannerRef.get();
      Map<String, dynamic> existingData =
          docSnapshot.exists ? docSnapshot.data() ?? {} : {};

      // ✅ Ensure 'meals' is always a list
      List<dynamic> meals = [];
      if (existingData.containsKey('meals')) {
        final storedMeals = existingData['meals'];
        if (storedMeals is List) {
          meals = List.from(storedMeals);
        } else {
          meals = []; // Reset if it's not a list
        }
      }

      // ✅ Create new meal entry
      Map<String, dynamic> newMeal = {
        'image': _recipeData!['image'] ?? '',
        'name': _recipeData!['name'],
        'type': mealType,
        'recipeId': widget.recipeId, // ✅ Add this!
        'source': 'recipes', // ✅ Include this to help navigation logic
      };

      meals.add(newMeal);

      // ✅ Update Firestore: Merge the new meal with existing data
      await plannerRef.set({'meals': meals}, SetOptions(merge: true));

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
              : Stack(
                  children: [
                    SingleChildScrollView(
                      child: _buildRecipeContent(),
                    ),
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton(
                        onPressed: _showWeeklyPlannerDialog,
                        backgroundColor:
                            const Color.fromARGB(255, 137, 174, 124),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/schedule.png',
                              width: 24,
                              height: 24,
                            ),
                            const Icon(Icons.add,
                                size: 20, color: Colors.white),
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

  String _extractCookingTime(String timesString) {
    final RegExp cookingRegExp = RegExp(r"Cooking':\s*'([^']*)");
    final Match? match = cookingRegExp.firstMatch(timesString);
    return match != null ? (match.group(1) ?? 'Unknown') : 'Unknown';
  }

  String _convertStepNumberToArabic(int number) {
    final arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String english = number.toString();
    return "الخطوة ${english.split('').map((e) => arabicNumbers[int.parse(e)]).join()}";
  }

  Widget _buildRecipeContent() {
    final String name = _showTranslated
        ? translatedTitle
        : (_recipeData!['name'] ?? 'Unnamed Recipe');
    final String description = _showTranslated
        ? translatedDescription
        : (_recipeData!['description'] ?? 'No description');
    final String difficultyRaw = _showTranslated
        ? translatedDifficulty
        : (_recipeData!['difficult'] ?? '');
    final String difficultyLabel =
        (difficultyRaw == 'More effort' || difficultyRaw == 'Challenge')
            ? 'Difficult'
            : difficultyRaw;
    final List<String> ingredients = _showTranslated
        ? translatedIngredients
        : _parseIngredients(_recipeData!['ingredients'] ?? '[]');
    final List<String> steps = _showTranslated
        ? translatedSteps
        : _parseSteps(_recipeData!['steps'] ?? '');
    final String cookingTime = _showTranslated
        ? translatedCookingTime
        : _extractCookingTime(_recipeData!['times'] ?? '{}');

    final List<String> tags = (_recipeData?['Tags'] is List)
        ? List<String>.from(_recipeData!['Tags'])
            .where((tag) => _showTranslated
                ? RegExp(r'^[\u0600-\u06FF]').hasMatch(tag) // only Arabic
                : !RegExp(r'^[\u0600-\u06FF]').hasMatch(tag)) // only English
            .toList()
        : [];

    final List<Color> tagColors = [
      Color(0xFFE3B7D0),
      Color(0xFFC1C8E4),
      Color(0xFFC1E1DC),
      Color(0xFFF7D1BA),
      Color(0xFFF2D7E0),
      Color(0xFFF7F1B5),
      Color(0xFFD3F8E2),
      Color(0xFFF9E2C0),
    ];

    // UI labels
    final String labelCookingTime =
        _showTranslated ? "مدة الطهي:\u200F" : "Cooking Time:";
    final String labelIngredients =
        _showTranslated ? "المكونات:\u200F" : "Ingredients:";
    final String labelSteps = _showTranslated ? "الخطوات:\u200F" : "Steps:";
    final String labelTags = _showTranslated ? "علامات:\u200F" : "Tags:";

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
                image:
                    _recipeData!['image'] != null && _recipeData!['image'] != ''
                        ? DecorationImage(
                            image: NetworkImage(_recipeData!['image']),
                            fit: BoxFit.cover,
                          )
                        : null,
                color: Colors.grey[300],
              ),
              child:
                  _recipeData!['image'] == null || _recipeData!['image'] == ''
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: _isFetchingSubstitution
                          ? const SizedBox(
                              height: 36,
                              width: 36,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Column(
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.translate,
                              size: 36.0,
                              color: Color.fromRGBO(88, 126, 75, 1)),
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
                      _showRemoveFromCollectionConfirmationDialog();
                    } else {
                      _showCollectionSelector();
                    }
                  },
                ),
                if (_isInCollection)
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
                          _showNoteSection = !_showNoteSection;
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
            Text(
              description,
              style: TextStyle(fontSize: _fontSize),
              textAlign: _showTranslated ? TextAlign.right : TextAlign.left,
            ),
            const SizedBox(height: 20),

            // Tags
            // Tags
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
                ),
              ),
              Wrap(
                alignment:
                    _showTranslated ? WrapAlignment.end : WrapAlignment.start,
                spacing: 10.0,
                children: tags.asMap().entries.map((entry) {
                  int index = entry.key;
                  String tag = entry.value;

                  Color tagColor = tagColors[index % tagColors.length];

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
            // Cooking Time
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
                      text: "$cookingTime",
                      style: TextStyle(
                        fontSize: _fontSize + 4,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                textAlign: _showTranslated ? TextAlign.right : TextAlign.left,
              ),
            ),
            const SizedBox(height: 20),

            // Ingredients
            Align(
              alignment: _showTranslated
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Text(
                labelIngredients,
                style: TextStyle(
                    fontSize: _fontSize + 4, fontWeight: FontWeight.bold),
                textAlign: _showTranslated ? TextAlign.right : TextAlign.left,
              ),
            ),
            const SizedBox(height: 10),
            for (var ingredient in ingredients)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: _showTranslated
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _showTranslated
                      ? [
                          // Arabic bullet after text
                          Flexible(
                            child: Text(
                              ingredient,
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: _fontSize),
                              softWrap: true,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(fontSize: 18)),
                        ]
                      : [
                          // English bullet before text
                          const Text('•', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              ingredient,
                              textAlign: TextAlign.left,
                              style: TextStyle(fontSize: _fontSize),
                              softWrap: true,
                            ),
                          ),
                        ],
                ),
              ),

            const SizedBox(height: 20),

            // Steps
            Align(
              alignment: _showTranslated
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Text(
                labelSteps,
                style: TextStyle(
                    fontSize: _fontSize + 4, fontWeight: FontWeight.bold),
                textAlign: _showTranslated ? TextAlign.right : TextAlign.left,
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
                    textAlign:
                        _showTranslated ? TextAlign.right : TextAlign.left,
                    softWrap: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
