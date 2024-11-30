import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'nav_bar.dart';

import ' CollectionDetailsPage.dart';

class UserCollectionsPage extends StatefulWidget {
  final String username;

  UserCollectionsPage({required this.username});

  @override
  _UserCollectionsPageState createState() => _UserCollectionsPageState();
}

class _UserCollectionsPageState extends State<UserCollectionsPage> {
  final user = FirebaseAuth.instance.currentUser;

  // Function to create a new collection
  void _createNewCollection(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) {
        final _collectionNameController = TextEditingController();
        bool _isValid = false;
        String _errorMessage = ''; // Error message to display inside the dialog

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Row(
                children: [
                  SizedBox(width: 8),
                  Text(
                    'Create New Collection',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 12),
                  TextField(
                    controller: _collectionNameController,
                    decoration: InputDecoration(
                      hintText: 'Collection Name',
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (text) {
                      setState(() {
                        // Real-time validation to check if the name is not empty
                        _isValid = text.trim().isNotEmpty;
                        _errorMessage = '';
                      });
                    },
                  ),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isValid
                      ? () async {
                          final collectionName =
                              _collectionNameController.text.trim();

                          if (_isValid && collectionName.isNotEmpty) {
                            // Check if the collection name already exists for this user
                            final querySnapshot = await FirebaseFirestore
                                .instance
                                .collection('collections')
                                .where('name', isEqualTo: collectionName)
                                .where('createdBy', isEqualTo: user!.uid)
                                .get();

                            if (querySnapshot.docs.isEmpty) {
                              await FirebaseFirestore.instance
                                  .collection('collections')
                                  .add({
                                'name': collectionName,
                                'recipes': [],
                                'createdBy': user!.uid,
                              });
                              Navigator.of(context).pop();
                              // Show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Collection added successfully!'),
                                  backgroundColor:
                                      const Color.fromARGB(255, 118, 133, 118),
                                ),
                              );
                            } else {
                              // error message
                              setState(() {
                                _errorMessage =
                                    'Collection name already exists!';
                              });
                            }
                          }
                        }
                      : null, // Disable button if the name is empty
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 137, 174, 124),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Create',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

// Function to edit a collection name
  void _editCollection(
      BuildContext context, String collectionId, String currentName) {
    showDialog(
      context: context,
      builder: (context) {
        final _editCollectionController =
            TextEditingController(text: currentName);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              SizedBox(width: 8),
              Text(
                'Edit Collection',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 12),
              TextField(
                controller: _editCollectionController,
                decoration: InputDecoration(
                  hintText: 'Collection Name',
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedName = _editCollectionController.text.trim();
                if (updatedName.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('collections')
                      .doc(collectionId)
                      .update({'name': updatedName});
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 137, 174, 124),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Function to delete a collection
  void _deleteCollection(String collectionId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Row(
            children: [
              SizedBox(width: 8),
              Text(
                'Delete Collection',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete this collection? This action cannot be undone.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('collections')
                    .doc(collectionId)
                    .delete();
                Navigator.of(context).pop();
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Collection deleted successfully!'),
                    backgroundColor: const Color.fromARGB(255, 118, 133, 118),
                  ),
                );
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

  Widget _buildCollectionItem(DocumentSnapshot collection) {
    final data = collection.data() as Map<String, dynamic>;
    final recipes = data['recipes'] as List<dynamic>? ?? [];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CollectionDetailsPage(
              collectionId: collection.id,
              username: '',
            ),
          ),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
        child: Column(
          children: [
            // Collection Image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  image: recipes.isNotEmpty && recipes.last['image'] != null
                      ? DecorationImage(
                          image: NetworkImage(recipes.last['image']),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: Colors.grey[300],
                ),
                child: recipes.isEmpty
                    ? Icon(Icons.add_photo_alternate, color: Colors.grey)
                    : null,
              ),
            ),
            SizedBox(height: 10),
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Collection Name
                    Text(
                      data['name'] ?? 'Unnamed Collection',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    // Display number of recipes
                    SizedBox(height: 5),
                    Text(
                      '${recipes.length} ${recipes.length == 1 ? 'Recipe' : 'Recipes'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Edit and Delete Icons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () {
                    _editCollection(context, collection.id, data['name'] ?? '');
                  },
                  icon: Icon(Icons.edit, color: Colors.green),
                  constraints: BoxConstraints(maxHeight: 24),
                ),
                IconButton(
                  onPressed: () {
                    _deleteCollection(collection.id);
                  },
                  icon: Icon(Icons.delete, color: Colors.red),
                  constraints: BoxConstraints(maxHeight: 24),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Collections'),
        backgroundColor: const Color.fromARGB(255, 137, 174, 124),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('collections')
            .where('createdBy',
                isEqualTo: user!.uid) // Retrieve collections for logged-in user
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // Show empty state if no collections exist
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No collections yet!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the "+" button below to create your first collection.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }
          final collections = snapshot.data!.docs;

          return GridView.builder(
            padding: EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final collection = collections[index];
              return _buildCollectionItem(collection);
            },
          );
        },
      ),
      floatingActionButton: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FloatingActionButton(
            onPressed: () => _createNewCollection(context),
            backgroundColor: const Color.fromARGB(255, 137, 174, 124),
            child: Icon(Icons.add, color: Colors.white),
          ),
        ),
      ),
      bottomNavigationBar: CustomNavBar(
        username: widget.username,
        currentIndex: 3,
      ),
    );
  }
}
