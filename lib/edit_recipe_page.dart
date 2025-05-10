import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditRecipePage extends StatefulWidget {
  final String username;
  final String recipeId;

  const EditRecipePage({required this.username, required this.recipeId});

  @override
  _EditRecipePageState createState() => _EditRecipePageState();
}

final ImagePicker _imagePicker = ImagePicker();

class _EditRecipePageState extends State<EditRecipePage> {
  final _formKey = GlobalKey<FormState>();
  String _recipeName = '';
  String _description = '';
  String _ingredients = '';
  String _instructions = '';
  String _difficulty = 'Easy'; // Default difficulty
  int _hours = 0;
  int _minutes = 0;
  int _seconds = 0;
  bool _isPrivate = true;
  List<String> _imageUrls = []; // List to hold image URLs
  bool _isLoading = true;
  final List<File> _selectedImages = []; // List to store multiple images
  final List<String> _removedImageUrls = []; // To track removed images

  final TextEditingController _recipeNameController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchRecipeData();

    _recipeNameController.addListener(_validateRecipeName);
    _ingredientsController.addListener(_validateIngredients);
    _instructionsController.addListener(_validateInstructions);
  }

  @override
  void dispose() {
    _recipeNameController.removeListener(_validateRecipeName);
    _ingredientsController.removeListener(_validateIngredients);
    _instructionsController.removeListener(_validateInstructions);
    _recipeNameController.dispose();
    _ingredientsController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  // Validation functions
  void _validateRecipeName() {
    setState(() {
      _recipeName = _recipeNameController.text;
    });
  }

  void _validateIngredients() {
    setState(() {
      _ingredients = _ingredientsController.text;
    });
  }

  void _validateInstructions() {
    setState(() {
      _instructions = _instructionsController.text;
    });
  }

  Future<void> _fetchRecipeData() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users_recipes')
          .doc(widget.recipeId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        print('Document data from Firestore: $data'); // Log the entire document

        setState(() {
          _recipeName = data['name'] ?? '';
          _description = data['description'] ?? '';
          _ingredients = data['ingredients'] ?? '';
          _instructions = data['steps'] ?? '';
          _difficulty = data['difficulty'] ?? 'Easy';

          // Handling images
          _imageUrls = List<String>.from(data['image'] ?? []);

          // Debugging: Log the raw cooking time from Firestore
          final cookingTime = data['cookingTime'] ?? '';
          print('Raw cooking time from Firestore: $cookingTime');

          // Parse cooking time
          final match =
              RegExp(r'(\d+)h\s*(\d+)m\s*(\d+)s').firstMatch(cookingTime);

          if (match != null) {
            _hours = int.tryParse(match.group(1) ?? '0') ?? 0;
            _minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
            _seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
          } else {
            // If no match, set default values
            _hours = 0;
            _minutes = 0;
            _seconds = 0;
          }

          print(
              'Parsed cooking time: $_hours hours, $_minutes minutes, $_seconds seconds');
          _isPrivate = data['source'] == 'private';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching recipe data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

// Function to pick image from gallery
  Future<void> _pickImage() async {
    final pickedFiles =
        await _imagePicker.pickMultiImage(); // Allow multiple image selection
    setState(() {
      _selectedImages.addAll(pickedFiles.map((file) => File(file.path)));
    });
  }

  Future<String?> _uploadImage(File image) async {
    try {
      String fileExtension = image.path.split('.').last;
      final storageRef = FirebaseStorage.instance.ref().child(
          'recipes/${DateTime.now().millisecondsSinceEpoch}.$fileExtension');
      await storageRef.putFile(image);
      return await storageRef.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: $e')),
      );
      return null;
    }
  }

  // Function to upload all selected images to Firebase Storage
  Future<List<String>> _uploadImages() async {
    List<String> downloadUrls = [];
    for (var image in _selectedImages) {
      String? downloadUrl = await _uploadImage(image);
      if (downloadUrl != null) {
        downloadUrls.add(downloadUrl);
      }
    }
    return downloadUrls;
  }

// Update recipe function
  Future<void> _updateRecipe() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() {
        _isLoading = true;
      });

      try {
        // Upload new images if any
        List<String> newImageUrls = [];
        if (_selectedImages.isNotEmpty) {
          newImageUrls = await _uploadImages();
          print('Uploaded image URLs: $newImageUrls');
        }

        // Fetch existing image URLs from Firestore
        List<String> existingImageUrls = [];
        final recipeDoc = await FirebaseFirestore.instance
            .collection('users_recipes')
            .doc(widget.recipeId)
            .get();

        if (recipeDoc.exists) {
          var data = recipeDoc.data();
          if (data != null && data['image'] != null) {
            existingImageUrls = List<String>.from(data['image']);
            print('Existing image URLs from Firestore: $existingImageUrls');
          }
        }

        // Remove deleted images from existing list
        for (String removedImageUrl in _removedImageUrls) {
          existingImageUrls.remove(removedImageUrl);

          // Optionally delete the image from storage
          await FirebaseStorage.instance.refFromURL(removedImageUrl).delete();
          print('Deleted image URL from storage: $removedImageUrl');
        }

        // Merge existing and new image URLs (avoid duplicates)
        List<String> updatedImageUrls = List.from(existingImageUrls)
          ..addAll(newImageUrls);

        // Ensure no duplicate URLs
        updatedImageUrls = updatedImageUrls.toSet().toList();

        // Prepare cooking time
        final cookingTime = '${_hours}h ${_minutes}m ${_seconds}s';

        // Prepare update data
        Map<String, dynamic> updateData = {
          'name': _recipeName,
          'description': _description,
          'ingredients': _ingredients,
          'steps': _instructions,
          'difficulty': _difficulty,
          'cookingTime': cookingTime,
          'source': _isPrivate ? 'private' : 'public',
          'image': updatedImageUrls,
          'lastUpdated':
              FieldValue.serverTimestamp(), // Store the updated image URLs
        };
        print('Data sent to Firestore: $updateData');

        // Update Firestore
        await FirebaseFirestore.instance
            .collection('users_recipes')
            .doc(widget.recipeId)
            .update(updateData);

        // Success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe updated successfully')),
        );
        Navigator.pop(context);
      } catch (e) {
        print("Error updating recipe: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating recipe: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showPreviewDialog() async {
    // Save the form values before showing the preview dialog
    if (_formKey.currentState?.validate() == true) {
      _formKey.currentState?.save(); // This ensures the form values are saved

      // Print updated data to verify it's being passed
      print('Recipe Name: $_recipeName');
      print('Description: $_description');
      print('Ingredients: $_ingredients');
      print('Instructions: $_instructions');
      print('Difficulty: $_difficulty');
      print('Is Private: $_isPrivate');
      print('Image URLs: $_imageUrls');

      // Show the dialog
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
                      'Preview Recipe Changes',
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
                          children: <Widget>[
                            // Recipe Name
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
                                'Description: $_description', // Updated value here
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
                                  "${_hours}h ${_minutes}m ${_seconds}s",
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
                            ..._ingredients.split(',').map((ingredient) => Text(
                                  '- ${ingredient.trim()}',
                                  style: const TextStyle(
                                      fontSize: 16, color: Colors.black54),
                                )),
                            const Divider(color: Colors.grey),

                            // Instructions
                            const Text(
                              'Instructions:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ..._instructions.split(',').map((step) => Text(
                                  '- ${step.trim()}',
                                  style: const TextStyle(
                                      fontSize: 16, color: Colors.black54),
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

                            // Images
                            if (_imageUrls.isNotEmpty ||
                                _selectedImages.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Images:',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 120,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: [
                                        // Display existing images
                                        ..._imageUrls.map((imageUrl) => Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5.0),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                                child: Image.network(
                                                  imageUrl,
                                                  height: 120,
                                                  width: 120,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            )),

                                        // Display newly selected images
                                        ..._selectedImages.map((imageFile) =>
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5.0),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                                child: Image.file(
                                                  imageFile,
                                                  height: 120,
                                                  width: 120,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            )),
                                      ],
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
                          },
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.red, fontSize: 16),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Close the dialog

                            setState(() {
                              _isLoading = true;
                            });

                            // Call the update recipe function
                            _updateRecipe();
                          },
                          child: const Text(
                            'Confirm',
                            style: TextStyle(
                                color: Color.fromRGBO(88, 126, 75, 1),
                                fontSize: 16),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 254, 254, 253),
      appBar: AppBar(
        title: const Text('Edit Recipe'),
        backgroundColor: const Color(0xFF6C8D5B),
        toolbarHeight: 70,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 600,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        // Recipe Name Input (Mandatory)
                        TextFormField(
                          initialValue: _recipeName,
                          decoration: const InputDecoration(
                            labelText: 'Recipe Name *',
                            border: OutlineInputBorder(),
                            fillColor: Color.fromARGB(255, 246, 243, 236),
                            filled: true,
                          ),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter the recipe name';
                            }
                            return null;
                          },
                          onSaved: (value) {
                            _recipeName = value!;
                          },
                          onChanged: (value) {
                            setState(() {
                              _recipeName = value;
                            });
                            _validateRecipeName(); // Call real-time validation
                          },
                        ),
                        const SizedBox(height: 15),

                        // Description Input (Optional)
                        TextFormField(
                          initialValue: _description,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                            fillColor: Color.fromARGB(255, 246, 243, 236),
                            filled: true,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _description = value;
                            });
                          },
                        ),
                        const SizedBox(height: 15),

                        // Cooking Time Input
                        const Text('Cooking Time (e.g., 1h 0m 0s):'),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: _hours.toString(),
                                decoration: const InputDecoration(
                                  labelText: 'Hours',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setState(() {
                                    _hours = int.tryParse(value) ?? 0;
                                  });
                                },
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    final intValue = int.tryParse(value);
                                    if (intValue == null || intValue < 0) {
                                      return 'Invalid hours';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                initialValue: _minutes.toString(),
                                decoration: const InputDecoration(
                                  labelText: 'Minutes',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setState(() {
                                    _minutes = int.tryParse(value) ?? 0;
                                  });
                                },
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    final intValue = int.tryParse(value);
                                    if (intValue == null || intValue < 0) {
                                      return 'Invalid minutes';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                initialValue: _seconds.toString(),
                                decoration: const InputDecoration(
                                  labelText: 'Seconds',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setState(() {
                                    _seconds = int.tryParse(value) ?? 0;
                                  });
                                },
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    final intValue = int.tryParse(value);
                                    if (intValue == null || intValue < 0) {
                                      return 'Invalid seconds';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),

                        // Ingredients (Mandatory)
                        TextFormField(
                          initialValue: _ingredients,
                          decoration: const InputDecoration(
                            labelText: 'Ingredients (Separate by commas) *',
                            border: OutlineInputBorder(),
                            fillColor: Color.fromARGB(255, 246, 243, 236),
                            filled: true,
                          ),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter ingredients';
                            }
                            return null;
                          },
                          onSaved: (value) {
                            _ingredients = value!;
                          },
                          onChanged: (value) {
                            setState(() {
                              _ingredients = value;
                            });
                            _validateIngredients();
                          },
                        ),
                        const SizedBox(height: 15),

                        // Instructions (Mandatory)
                        TextFormField(
                          initialValue: _instructions,
                          decoration: const InputDecoration(
                            labelText: 'Instructions *',
                            border: OutlineInputBorder(),
                            fillColor: Color.fromARGB(255, 246, 243, 236),
                            filled: true,
                          ),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter the instructions';
                            }
                            return null;
                          },
                          onSaved: (value) {
                            _instructions = value!;
                          },
                          onChanged: (value) {
                            setState(() {
                              _instructions = value;
                            });
                            _validateInstructions(); // Call real-time validation
                          },
                        ),

                        // Difficulty Selection (Mandatory)
                        const SizedBox(height: 20),
                        const Text(
                          'Select Difficulty *',
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

                        // Privacy Selection (Mandatory)
                        const SizedBox(height: 20),
                        const Text(
                          'Privacy Settings *',
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

                        // Image Upload Section (Mandatory)
                        const SizedBox(height: 15),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                              onPressed: _pickImage, // Function to pick images
                            ),
                            const SizedBox(width: 10),

                            // Display fetched and newly selected images in a horizontal scrollable view
                            if (_imageUrls.isNotEmpty ||
                                _selectedImages.isNotEmpty)
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      // Display fetched images from Firestore
                                      ..._imageUrls.map((imageUrl) {
                                        final index =
                                            _imageUrls.indexOf(imageUrl);

                                        return Stack(
                                          children: [
                                            Container(
                                              width: 50,
                                              height: 50,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: const Color(
                                                        0xFF6C8D5B)),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  imageUrl,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 0,
                                              right: 0,
                                              child: IconButton(
                                                icon: const Icon(Icons.cancel,
                                                    color: Colors.red),
                                                onPressed: () {
                                                  setState(() {
                                                    _removedImageUrls
                                                        .add(_imageUrls[index]);
                                                    _imageUrls.removeAt(
                                                        index); // Remove from displayed list
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),

                                      // Display newly selected images
                                      ..._selectedImages.map((imageFile) {
                                        final index =
                                            _selectedImages.indexOf(imageFile);

                                        return Stack(
                                          children: [
                                            Container(
                                              width: 50,
                                              height: 50,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: const Color(
                                                        0xFF6C8D5B)),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
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
                                                icon: const Icon(Icons.cancel,
                                                    color: Colors.red),
                                                onPressed: () {
                                                  setState(() {
                                                    _selectedImages
                                                        .removeAt(index);
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Submit Button
                        Center(
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    if (_formKey.currentState!.validate()) {
                                      if (_imageUrls.isEmpty &&
                                          _selectedImages.isEmpty) {
                                        // Show a pop-up dialog if no image is selected
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              title: const Row(
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .warning_amber_rounded,
                                                      color: Colors.orange,
                                                      size: 30),
                                                  SizedBox(width: 10),
                                                  Text(
                                                    'Image Required',
                                                    style: TextStyle(
                                                      fontSize: 22,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          const Color(
                                                              0xFF6C8D5B),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 20,
                                                          vertical: 10),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(15),
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  )
                                : const Text(
                                    'Update Recipe',
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
            ),
    );
  }
}
