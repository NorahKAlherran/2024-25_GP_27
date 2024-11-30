import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'homepage.dart';
import 'nav_bar.dart';

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
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // Function to upload image to Firebase Storage
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

  // Function to show preview dialog before submission
  void _showPreviewDialog() {
    String cookingTime = "${_hours}h ${_minutes}m ${_seconds}s";
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Preview Your Recipe',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color.fromRGBO(88, 126, 75, 1),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Name
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      const Text(
                        'Name: ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        _recipeName,
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                // Description
                if (_description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Description: $_description',
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                  ),
                const Divider(color: Colors.grey),
                // Cooking Time
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
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
                ),
                const Divider(color: Colors.grey),
                // Ingredients
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Ingredients:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _ingredients
                        .replaceAll('[', '')
                        .replaceAll(']', '')
                        .split(',')
                        .map((ingredient) => Text(
                              '- ${ingredient.trim()}',
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.black54),
                            ))
                        .toList(),
                  ),
                ),
                const Divider(color: Colors.grey),
                // Instructions
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Steps:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _instructions
                        .replaceAll('[', '')
                        .replaceAll(']', '')
                        .replaceAll('"', '')
                        .split(',')
                        .asMap()
                        .entries
                        .map((entry) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(
                                'Step ${entry.key + 1}: ${entry.value.trim()}',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.black54),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const Divider(color: Colors.grey),
                // Difficulty
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
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
                ),
                const Divider(color: Colors.grey),
                // Privacy Settings
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
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
                ),
                // Photo
                if (_imageFile != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10.0),
                        child: Text(
                          'Photo:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Image.file(
                          _imageFile!,
                          height: 150,
                          width: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Edit',
                style: TextStyle(
                  color: Color.fromRGBO(88, 126, 75, 1),
                  fontSize: 16,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog to edit
              },
            ),
            TextButton(
              child: const Text(
                'Confirm',
                style: TextStyle(
                  color: Color.fromRGBO(88, 126, 75, 1),
                  fontSize: 16,
                ),
              ),
              onPressed: () async {
                Navigator.of(context).pop(); // Close the preview dialog
                // Unfocus all text fields to dismiss the keyboard
                FocusScope.of(context).unfocus();
                await _createRecipe(); // Call the function to create the recipe
              },
            ),
          ],
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

      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await _uploadImage(_imageFile!);
        if (imageUrl == null) {
          print('Image URL is null. Recipe will not be created.');
          setState(() {
            _isLoading = false; // Stop loading if upload fails
          });
          return;
        }
      }

      Map<String, dynamic> recipeData = {
        'name': _recipeName,
        'description': _description,
        'ingredients': _ingredients,
        'steps': _instructions,
        'difficulty': _difficulty,
        'cookingTime': "${_hours}h ${_minutes}m ${_seconds}s",
        'image': imageUrl,
        'source': _isPrivate ? 'private' : 'public',
        'created_at': Timestamp.now(),
        'createdBy': widget.username,
        'flag': 'users_recipes',
      };

      try {
        await FirebaseFirestore.instance
            .collection('users_recipes')
            .add(recipeData);
        print('Recipe created successfully!');

        // Stop the loading state before showing the dialog
        setState(() {
          _isLoading = false;
        });

        _showRecipeDetailsDialog(); // Call the details dialog to show success
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
  void _showRecipeDetailsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Recipe Created Successfully',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color.fromRGBO(88, 126, 75, 1),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Name
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      const Text(
                        'Name: ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        _recipeName,
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                // Description
                if (_description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Description: $_description',
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                  ),
                const Divider(color: Colors.grey),
                // Cooking Time
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
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
                        "${_hours}h ${_minutes}m ${_seconds}s",
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.grey),
                // Ingredients
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Ingredients:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _ingredients
                        .replaceAll('[', '')
                        .replaceAll(']', '')
                        .split(',')
                        .map((ingredient) => Text(
                              '- ${ingredient.trim()}',
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.black54),
                            ))
                        .toList(),
                  ),
                ),
                const Divider(color: Colors.grey),
                // Instructions
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Steps:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _instructions
                        .replaceAll('[', '')
                        .replaceAll(']', '')
                        .replaceAll('"', '')
                        .split(',')
                        .asMap()
                        .entries
                        .map((entry) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(
                                'Step ${entry.key + 1}: ${entry.value.trim()}',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.black54),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const Divider(color: Colors.grey),
                // Difficulty
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
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
                ),
                const Divider(color: Colors.grey),
                // Privacy Settings
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
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
                ),
                // Photo
                if (_imageFile != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10.0),
                        child: Text(
                          'Photo:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Image.file(
                          _imageFile!,
                          height: 150,
                          width: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Color.fromRGBO(88, 126, 75, 1),
                  fontSize: 16,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                // Navigate to homepage after confirmation
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomePage(username: widget.username),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Create Recipe"),
        backgroundColor: const Color.fromARGB(255, 137, 174, 124),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
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
                    _recipeName = value; // No need for validate() here
                  },
                  onSaved: (value) {
                    _recipeName = value!;
                  },
                ),

                const SizedBox(height: 15),

                // Description Input (optional)
                TextFormField(
                  focusNode: _descriptionFocusNode, // Attach the new FocusNode
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

                    // Check if _imageFile is not null, then display the image
                    if (_imageFile != null)
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(
                                  0xFF6C8D5B)), // border for better visibility
                          borderRadius:
                              BorderRadius.circular(8), //rounded corners
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _imageFile!,
                            fit: BoxFit
                                .cover, // Adjust how the image fits within the container
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
                              if (_imageFile == null) {
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
                                        'Please upload an image for your recipe.',
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
    _descriptionFocusNode.dispose(); // Dispose the new FocusNode
    _ingredientsFocusNode.dispose();
    _instructionsFocusNode.dispose();
    _difficultyFocusNode.dispose(); // Dispose the new FocusNode
    super.dispose();
  }
}
