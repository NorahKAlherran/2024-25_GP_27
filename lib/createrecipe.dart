import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'homepage.dart';
import 'recipe_detail_page_user.dart';
import 'nav_bar.dart';
import 'chat_service.dart';

class CreateRecipePage extends StatefulWidget {
  final String username;

  const CreateRecipePage({super.key, required this.username});

  @override
  _CreateRecipePageState createState() => _CreateRecipePageState();
}

class _CreateRecipePageState extends State<CreateRecipePage> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey<FormFieldState> _recipeNameKey = GlobalKey<FormFieldState>();
  final GlobalKey<FormFieldState> _ingredientsKey = GlobalKey<FormFieldState>();
  final GlobalKey<FormFieldState> _instructionsKey =
      GlobalKey<FormFieldState>();
  final List<File> _selectedImages = []; // List to store multiple images
  String _recipeName = '';
  String _description = '';
  String _ingredients = '';
  String _difficulty = 'Easy';
  String _instructions = '';
  int _hours = 0;
  int _minutes = 0;
  int _seconds = 0;
  bool _isPrivate = true;
  File? _imageFile;
  bool _isLoading = false;

  final FocusNode _recipeNameFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();
  final FocusNode _ingredientsFocusNode = FocusNode();
  final FocusNode _instructionsFocusNode = FocusNode();
  final FocusNode _difficultyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
// Validate when the recipe name field gains focus
    _recipeNameFocusNode.addListener(() {
      if (!_recipeNameFocusNode.hasFocus) {
        _recipeNameKey.currentState!.validate();
      }
    });
// Validate when the Ingredients field gains focus
    _ingredientsFocusNode.addListener(() {
      if (!_ingredientsFocusNode.hasFocus) {
        _ingredientsKey.currentState!.validate();
      }
    });

    // Validate when the instructions field gains focus
    _instructionsFocusNode.addListener(() {
      if (!_instructionsFocusNode.hasFocus) {
        _instructionsKey.currentState!.validate(); // Validate Ingredients
      }
    });
  }

// Function to pick image from gallery
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImages.add(File(pickedFile.path)); // Add image to the list
      });
    }
  }

  // Method to remove an image
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // Function to upload a single image to Firebase Storage
  Future<String?> _uploadImage(File image) async {
    try {
      String fileExtension = image.path.split('.').last;
      final storageRef = FirebaseStorage.instance.ref().child(
          'recipes/${DateTime.now().millisecondsSinceEpoch}.$fileExtension');
      await storageRef.putFile(image);
      String downloadURL = await storageRef.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print('Image upload failed: $e');
      return null;
    }
  }

  // Function to upload all selected images to Firebase Storage
  Future<List<String>> _uploadImages() async {
    List<String> downloadUrls = []; // List to store URLs of the uploaded images
    for (var image in _selectedImages) {
      String? downloadUrl = await _uploadImage(image);
      if (downloadUrl != null) {
        downloadUrls.add(downloadUrl); // Add the URL to the list
      }
    }
    return downloadUrls;
  }

  // Function to show preview dialog before submission
  void _showPreviewDialog() {
    String cookingTime = "${_hours}h ${_minutes}m ${_seconds}s";
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Preview Your Recipe',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(88, 126, 75, 1),
                    ),
                  ),
                ),
                const Divider(color: Colors.grey),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name
                          Row(
                            children: [
                              const Text(
                                'Name: ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _recipeName,
                                  style: const TextStyle(
                                      fontSize: 16, color: Colors.black54),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Description
                          if (_description.isNotEmpty)
                            Text(
                              'Description: $_description',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[700]),
                            ),
                          const Divider(color: Colors.grey),

                          // Cooking Time
                          Row(
                            children: [
                              const Text(
                                'Cooking Time: ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                cookingTime,
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.black54),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.grey),

                          // Ingredients
                          const Text(
                            'Ingredients:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ..._ingredients
                              .replaceAll('[', '')
                              .replaceAll(']', '')
                              .split(',')
                              .map((ingredient) => ingredient.trim())
                              .where((ingredient) => ingredient.isNotEmpty)
                              .map((ingredient) => Text(
                                    '- ${ingredient.trim()}',
                                    style: const TextStyle(
                                        fontSize: 16, color: Colors.black54),
                                  )),
                          const Divider(color: Colors.grey),

                          // Steps
                          const Text(
                            'Steps:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ..._instructions
                              .replaceAll('[', '')
                              .replaceAll(']', '')
                              .replaceAll('"', '')
                              .split(',')
                              .map((step) => step.trim())
                              .where((step) => step.isNotEmpty)
                              .toList()
                              .asMap()
                              .entries
                              .map((entry) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    child: Text(
                                      'Step ${entry.key + 1}: ${entry.value}',
                                      style: const TextStyle(
                                          fontSize: 16, color: Colors.black54),
                                    ),
                                  )),
                          const Divider(color: Colors.grey),

                          // Difficulty
                          Row(
                            children: [
                              const Text(
                                'Difficulty: ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                _difficulty,
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.black54),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.grey),

                          // Privacy
                          Row(
                            children: [
                              const Text(
                                'Privacy: ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                _isPrivate ? 'Private' : 'Public',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.black54),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.grey),

                          // Photos
                          if (_selectedImages.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Photos:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 120,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _selectedImages.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5.0),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                          child: Image.file(
                                            _selectedImages[index],
                                            height: 120,
                                            width: 120,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Actions
                const Divider(color: Colors.grey),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close to edit
                        },
                        child: const Text(
                          'Edit',
                          style:
                              TextStyle(color: Color.fromRGBO(88, 126, 75, 1)),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          FocusScope.of(context).unfocus();
                          await _createRecipe();
                        },
                        child: const Text(
                          'Confirm',
                          style:
                              TextStyle(color: Color.fromRGBO(88, 126, 75, 1)),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createRecipe() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() {
        _isLoading = true; // Start loading
      });

      List<String> imageUrls = await _uploadImages();

      Map<String, dynamic> recipeData = {
        'name': _recipeName,
        'description': _description,
        'ingredients': _ingredients,
        'steps': _instructions,
        'difficulty': _difficulty,
        'cookingTime': "${_hours}h ${_minutes}m ${_seconds}s",
        'image': imageUrls,
        'source': _isPrivate ? 'private' : 'public',
        'created_at': Timestamp.now(),
        'createdBy': widget.username,
        'flag': 'users_recipes',
        'creatorId': FirebaseAuth.instance.currentUser!.uid,
      };

      try {
        DocumentReference docRef = await FirebaseFirestore.instance
            .collection('users_recipes')
            .add(recipeData);
        String recipeId = docRef.id; // Get the ID of the newly created recipe

        print('Recipe created successfully!');

        // Generate tags using ChatService
        List<String> tags = await generateRecipeTags(
          _recipeName,
          _description,
          _ingredients.split(',').map((e) => e.trim()).toList(),
        );

        //  Store tags in Firestore
        await FirebaseFirestore.instance
            .collection('users_recipes')
            .doc(recipeId)
            .update({'Tags': tags});
//  Translate entire recipe (including tags)
        final translated = await translateWholeRecipe(
          title: _recipeName,
          difficulty: _difficulty,
          description: _description,
          ingredients: _ingredients.split(',').map((e) => e.trim()).toList(),
          steps: _instructions.split(',').map((e) => e.trim()).toList(),
          cookingTime: "${_hours}h ${_minutes}m ${_seconds}s",
          tags: tags,
        );

//  If successful, store under translations/ar and merge Arabic tags
        if (translated.isNotEmpty) {
          final List<String> arabicTags =
              (translated['tags'] as List).map((e) => e.toString()).toList();

          // Combine both English and Arabic tags
          final combinedTags = {
            ...tags,
            ...arabicTags,
          }.toList(); // ensure no duplicates

          //  Save Arabic translation
          await FirebaseFirestore.instance
              .collection('users_recipes')
              .doc(recipeId)
              .collection('translations')
              .doc('ar')
              .set({
            'name': translated['title'] ?? '',
            'description': translated['description'] ?? '',
            'ingredients': translated['ingredients'] ?? [],
            'steps': translated['steps'] ?? [],
            'difficulty': translated['difficulty'] ?? '',
            'cookingTime': translated['cookingTime'] ?? '',
            'Tags': arabicTags,
            'sourceLang': 'en',
            'sourceLastUpdated': Timestamp.now(),
          });

          //  update the main Tags field to include Arabic too
          await FirebaseFirestore.instance
              .collection('users_recipes')
              .doc(recipeId)
              .update({'Tags': combinedTags});
        }

        setState(() {
          _isLoading = false; // Stop loading
        });

        // Show success dialog with preview
        _showRecipeDetailsDialog(recipeId, tags);
      } catch (e) {
        print('Failed to create recipe: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to create recipe. Please try again.')),
        );
        setState(() {
          _isLoading = false; // Stop loading if there's an error
        });
      }
    }
  }

  // Function to show recipe details in a dialog after submission
  void _showRecipeDetailsDialog(String recipeId, List<String> tags) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Recipe Created Successfully',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(88, 126, 75, 1),
                    ),
                  ),
                ),
                const Divider(color: Colors.grey),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name
                          Text(
                            'Recipe Name: $_recipeName',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),

                          // Description
                          if (_description.isNotEmpty) ...[
                            Text(
                              'Description:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              _description,
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[700]),
                            ),
                            const Divider(color: Colors.grey),
                          ],

                          // Tags Section with Pastel Colors (Now After Description)
                          if (tags.isNotEmpty) ...[
                            const Text(
                              'Tags:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8.0,
                              children: tags.asMap().entries.map((entry) {
                                int index = entry.key;
                                String tag = entry.value;

                                List<Color> pastelColors = [
                                  Color(0xFFE3B7D0), // Pastel Pink
                                  Color(0xFFC1C8E4), // Pastel Blue
                                  Color(0xFFC1E1DC), // Pastel Mint
                                  Color(0xFFF7D1BA), // Pastel Peach
                                  Color(0xFFF2D7E0), // Pastel Lavender
                                  Color(0xFFF7F1B5), // Pastel Yellow
                                  Color(0xFFD3F8E2), // Pastel Green
                                  Color(0xFFF9E2C0), // Pastel Orange
                                ];

                                // Assign colors in rotation
                                Color tagColor =
                                    pastelColors[index % pastelColors.length];

                                return Chip(
                                  label: Text(
                                    "#$tag",
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.black),
                                  ),
                                  backgroundColor: tagColor,
                                  padding: EdgeInsets.symmetric(horizontal: 1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(color: Colors.transparent),
                                  ),
                                  elevation: 0,
                                );
                              }).toList(),
                            ),
                            const Divider(color: Colors.grey),
                          ],

                          // Cooking Time
                          Text(
                            'Cooking Time: ${_hours}h ${_minutes}m ${_seconds}s',
                            style: TextStyle(fontSize: 16),
                          ),
                          const Divider(color: Colors.grey),

                          // Ingredients
                          const Text(
                            'Ingredients:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ..._ingredients
                              .replaceAll('[', '')
                              .replaceAll(']', '')
                              .split(',')
                              .map((ingredient) => ingredient.trim())
                              .where((ingredient) => ingredient.isNotEmpty)
                              .map((ingredient) => Text(
                                    '- ${ingredient.trim()}',
                                    style: const TextStyle(
                                        fontSize: 16, color: Colors.black54),
                                  )),
                          const Divider(color: Colors.grey),

                          // Steps
                          const Text(
                            'Steps:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ..._instructions
                              .replaceAll('[', '')
                              .replaceAll(']', '')
                              .replaceAll('"', '')
                              .split(',')
                              .map((step) => step.trim())
                              .where((step) => step.isNotEmpty)
                              .toList()
                              .asMap()
                              .entries
                              .map((entry) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    child: Text(
                                      'Step ${entry.key + 1}: ${entry.value}',
                                      style: const TextStyle(
                                          fontSize: 16, color: Colors.black54),
                                    ),
                                  )),
                          const Divider(color: Colors.grey),

                          // Difficulty
                          Row(
                            children: [
                              const Text(
                                'Difficulty: ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                _difficulty,
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.black54),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.grey),

                          // Privacy Settings
                          Row(
                            children: [
                              const Text(
                                'Privacy: ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                _isPrivate ? 'Private' : 'Public',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.black54),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.grey),

                          // Photos
                          if (_selectedImages.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Photos:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 120,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _selectedImages.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5.0),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                          child: Image.file(
                                            _selectedImages[index],
                                            height: 120,
                                            width: 120,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Actions
                const Divider(color: Colors.grey),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close the dialog
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecipeDetailPageUser(
                                recipeId: recipeId,
                                username: widget.username,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'OK',
                          style:
                              TextStyle(color: Color.fromRGBO(88, 126, 75, 1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Create Recipe"),
        backgroundColor: const Color.fromARGB(255, 137, 174, 124),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: AbsorbPointer(
          absorbing: _isLoading,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Recipe Name Input
                TextFormField(
                  key: _recipeNameKey,
                  // Attach the key to the TextFormField
                  focusNode: _recipeNameFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'Recipe Name *',
                    labelStyle: TextStyle(fontFamily: 'Times New Roman'),
                    border: OutlineInputBorder(),
                    fillColor: Color.fromARGB(255, 246, 243, 236),
                    filled: true,
                  ),
                  autovalidateMode: AutovalidateMode
                      .onUserInteraction, // Auto-validate on interaction
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the recipe name';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    _recipeName = value;
                  },
                  onSaved: (value) {
                    _recipeName = value!;
                  },
                ),

                const SizedBox(height: 15),

                // Description Input (optional)
                TextFormField(
                  focusNode: _descriptionFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    labelStyle: TextStyle(fontFamily: 'Times New Roman'),
                    border: OutlineInputBorder(),
                    fillColor: Color.fromARGB(255, 246, 243, 236),
                    filled: true,
                  ),
                  onSaved: (value) {
                    _description = value ?? '';
                  },
                ),
                const SizedBox(height: 1),

// Cooking Time Dropdowns

                const SizedBox(height: 15),
                const Text(
                  'Cooking Time:',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color.fromARGB(255, 52, 49, 49), // Set color
                  ),
                ),

                const SizedBox(height: 10), // Ad
                Container(
                  color: const Color.fromARGB(255, 246, 243, 236),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Hours Dropdown
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Hours',
                            border: OutlineInputBorder(),
                          ),
                          value: _hours,
                          items: List.generate(24, (index) => index)
                              .map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(value.toString()),
                            );
                          }).toList(),
                          onChanged: (int? newValue) {
                            setState(() {
                              _hours = newValue!;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select hours';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Minutes Dropdown
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Minutes',
                            border: OutlineInputBorder(),
                          ),
                          value: _minutes,
                          items: List.generate(60, (index) => index)
                              .map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(value.toString()),
                            );
                          }).toList(),
                          onChanged: (int? newValue) {
                            setState(() {
                              _minutes = newValue!;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select minutes';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Seconds Dropdown
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Seconds',
                            border: OutlineInputBorder(),
                          ),
                          value: _seconds,
                          items: List.generate(60, (index) => index)
                              .map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(value.toString()),
                            );
                          }).toList(),
                          onChanged: (int? newValue) {
                            setState(() {
                              _seconds = newValue!;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select seconds';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                // Ingredients Input
                TextFormField(
                  key: _ingredientsKey,
                  focusNode: _ingredientsFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'Ingredients * (Separate by commas)',
                    labelStyle: TextStyle(fontFamily: 'Times New Roman'),
                    border: OutlineInputBorder(),
                    fillColor: Color.fromARGB(255, 246, 243, 236),
                    filled: true,
                  ),
                  autovalidateMode: AutovalidateMode
                      .onUserInteraction, // Auto-validate on interaction
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the ingredients';
                    }
                    if (!value.contains(',')) {
                      return 'Please separate ingredients with commas';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    _ingredients = value;
                  },
                  onSaved: (value) {
                    _ingredients = value!
                        .split(',')
                        .map((ingredient) => ingredient.trim())
                        .toList()
                        .toString(); // Convert list to a string format
                  },
                ),

                const SizedBox(height: 15),

                // Instructions Input
                TextFormField(
                  key: _instructionsKey,
                  focusNode: _instructionsFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'Instructions * (Separate by commas)',
                    hintText: 'Format: Step 1, Step 2, Step 3, ...',
                    labelStyle: TextStyle(fontFamily: 'Times New Roman'),
                    hintStyle: TextStyle(
                        fontFamily: 'Times New Roman', color: Colors.grey),
                    border: OutlineInputBorder(),
                    fillColor: Color.fromARGB(255, 246, 243, 236),
                    filled: true,
                  ),
                  maxLines: 5,
                  autovalidateMode: AutovalidateMode
                      .onUserInteraction, // Auto-validate on interaction
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the instructions';
                    }
                    if (!value.contains(',')) {
                      return 'Please separate each step with a comma';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    _instructions = value;
                  },
                  onSaved: (value) {
                    _instructions = value!
                        .split(',')
                        .map((step) => step.trim())
                        .toList()
                        .toString(); // Convert list to a string format
                  },
                ),

                // Difficulty Selection
                const SizedBox(height: 20),
                const Text(
                  'Select Difficulty',
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6C8D5B),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Easy'),
                        value: 'Easy',
                        groupValue: _difficulty,
                        onChanged: (value) {
                          setState(() {
                            _difficulty = value!;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Difficult'),
                        value: 'Difficult',
                        groupValue: _difficulty,
                        onChanged: (value) {
                          setState(() {
                            _difficulty = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                // Privacy Selection
                const SizedBox(height: 20),
                const Text(
                  'Privacy Settings',
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6C8D5B),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Private'),
                        value: true,
                        groupValue: _isPrivate,
                        onChanged: (value) {
                          setState(() {
                            _isPrivate = value!;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Public'),
                        value: false,
                        groupValue: _isPrivate,
                        onChanged: (value) {
                          setState(() {
                            _isPrivate = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Image Upload
                Row(
                  children: [
                    const Text(
                      'Upload image: *',
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Times New Roman',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6C8D5B),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.upload_file),
                      iconSize: 40,
                      color: const Color(0xFF6C8D5B),
                      onPressed: _pickImage,
                    ),
                    const SizedBox(width: 10),

                    // Display selected images
                    if (_selectedImages.isNotEmpty)
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _selectedImages.map((imageFile) {
                              int index = _selectedImages
                                  .indexOf(imageFile); // Get index of image

                              return Stack(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 5),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: const Color(0xFF6C8D5B)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        imageFile,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: IconButton(
                                      icon: const Icon(Icons.remove_circle,
                                          color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          _selectedImages.removeAt(
                                              index); // Remove the image at the given index
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // Create Recipe Button
                Center(
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              if (_selectedImages.isEmpty) {
                                // Show a pop-up dialog if no image is selected
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      title: const Row(
                                        children: [
                                          Icon(Icons.warning_amber_rounded,
                                              color: Colors.orange, size: 30),
                                          SizedBox(width: 10),
                                          Text(
                                            'Image Required',
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      content: const Text(
                                        'Please upload at least one image for your recipe.',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      actions: <Widget>[
                                        Center(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF6C8D5B),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 10),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                              ),
                                            ),
                                            onPressed: () {
                                              Navigator.of(context)
                                                  .pop(); // Close the dialog
                                            },
                                            child: const Text(
                                              'OK',
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              } else {
                                _formKey.currentState!.save();
                                FocusScope.of(context)
                                    .unfocus(); // Unfocus text fields

                                _showPreviewDialog(); // Show the preview dialog
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C8D5B),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : const Text(
                            'Create Recipe',
                            style: TextStyle(
                              fontSize: 20,
                              fontFamily: 'Times New Roman',
                              color: Colors.white,
                            ),
                          ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomNavBar(
        username: widget.username,
        currentIndex: 4,
      ),
    );
  }

  @override
  void dispose() {
    _recipeNameFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _ingredientsFocusNode.dispose();
    _instructionsFocusNode.dispose();
    _difficultyFocusNode.dispose();
    super.dispose();
  }
}
