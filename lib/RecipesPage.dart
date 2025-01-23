import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'RecipeDetailPage.dart';
import 'nav_bar.dart';
import 'recipe_detail_page_user.dart';

class RecipesPage extends StatefulWidget {
  final String username;

  RecipesPage({required this.username});

  @override
  _RecipesPageState createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Recipe> _allRecipes = [];
  List<Recipe> _filteredRecipes = [];
  String _selectedDifficulty = '';
  List<String> _selectedFlags = [];
  bool _filterApplied = false;

  @override
  void initState() {
    super.initState();
    _fetchRecipes();
  }

  Future<void> _fetchRecipes() async {
    try {
      // Fetch all documents from the 'recipes' collection
      final recipesSnapshot =
          await FirebaseFirestore.instance.collection('recipes').get();

      // Fetch all public documents from the 'users_recipes' collection
      final usersRecipesSnapshot = await FirebaseFirestore.instance
          .collection('users_recipes')
          .where('source', isEqualTo: 'public')
          .get();

      final recipes = recipesSnapshot.docs
          .map((doc) => Recipe.fromFirestore(doc, 'recipes'))
          .toList();
      final usersRecipes = usersRecipesSnapshot.docs
          .map((doc) => Recipe.fromFirestore(doc, 'users_recipes'))
          .toList();

      // Combine all recipes into a single list
      final allRecipes = [...recipes, ...usersRecipes];

      setState(() {
        _allRecipes = allRecipes;
        _filteredRecipes = allRecipes;
      });
    } catch (e) {
      print("Error fetching recipes:$e");
    }
  }

  Future<void> _filterRecipes() async {
    List<Recipe> filtered = _allRecipes;

    if (_filterApplied) {
      filtered = filtered.where((recipe) {
        bool matchesDifficulty = (_selectedDifficulty.isEmpty) ||
            (_selectedDifficulty == 'Easy' && recipe.difficulty == 'Easy') ||
            (_selectedDifficulty == 'Difficult' &&
                (recipe.difficulty == 'Difficult' ||
                    recipe.difficulty == 'More effort' ||
                    recipe.difficulty == 'Challenge'));

        bool matchesFlag = _selectedFlags.isEmpty ||
            (_selectedFlags.contains("QOOT Recipe") &&
                recipe.flag == 'recipes') ||
            (_selectedFlags.contains("Other Recipe") &&
                recipe.flag == 'users_recipes');

        return matchesDifficulty && matchesFlag;
      }).toList();
    }

    String searchText = _searchController.text.toLowerCase();
    List<Recipe> startsWithSearchText = filtered
        .where((recipe) => recipe.name.toLowerCase().startsWith(searchText))
        .toList();
    List<Recipe> containsSearchText = filtered
        .where((recipe) =>
            recipe.name.toLowerCase().contains(searchText) &&
            !recipe.name.toLowerCase().startsWith(searchText))
        .toList();

    List<Recipe> prioritizedResults = [
      ...startsWithSearchText,
      ...containsSearchText
    ];

    setState(() {
      _filteredRecipes = prioritizedResults;
    });
  }

  void _applyFilters() {
    setState(() {
      _filterApplied = true;
    });
    _filterRecipes();
    Navigator.of(context).pop();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Center(
                child: Text(
                  "Filter Recipes",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 137, 174, 124),
                  ),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Divider(color: Colors.grey[300], thickness: 1),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        "Difficulty",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Center(
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text("Easy"),
                            value: "Easy",
                            groupValue: _selectedDifficulty,
                            activeColor:
                                const Color.fromARGB(255, 137, 174, 124),
                            onChanged: (value) {
                              setState(() {
                                _selectedDifficulty = value ?? "";
                              });
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text("Difficult"),
                            value: "Difficult",
                            groupValue: _selectedDifficulty,
                            activeColor:
                                const Color.fromARGB(255, 137, 174, 124),
                            onChanged: (value) {
                              setState(() {
                                _selectedDifficulty = value ?? "";
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Divider(color: Colors.grey[300], thickness: 1),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        "Recipe Source",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Center(
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        alignment: WrapAlignment.center,
                        children: [
                          ChoiceChip(
                            label: Text("QOOT Recipes"),
                            selected: _selectedFlags.contains("QOOT Recipe"),
                            selectedColor:
                                const Color.fromARGB(255, 137, 174, 124),
                            onSelected: (bool selected) {
                              setState(() {
                                if (selected) {
                                  _selectedFlags.add("QOOT Recipe");
                                } else {
                                  _selectedFlags.remove("QOOT Recipe");
                                }
                              });
                            },
                          ),
                          ChoiceChip(
                            label: Text("User Recipes"),
                            selected: _selectedFlags.contains("Other Recipe"),
                            selectedColor:
                                const Color.fromARGB(255, 137, 174, 124),
                            onSelected: (bool selected) {
                              setState(() {
                                if (selected) {
                                  _selectedFlags.add("Other Recipe");
                                } else {
                                  _selectedFlags.remove("Other Recipe");
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                  ),
                  child: Text("Reset"),
                  onPressed: () {
                    setState(() {
                      _selectedDifficulty = '';
                      _selectedFlags.clear();
                      _searchController.clear();
                    });
                    this.setState(() {
                      _filterApplied = false;
                      _filteredRecipes = _allRecipes;
                    });
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 137, 174, 124),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text("Apply"),
                  onPressed: () {
                    _applyFilters();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recipes"),
        backgroundColor: const Color.fromARGB(255, 137, 174, 124),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  _filterRecipes();
                },
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Search recipes...",
                  icon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color.fromARGB(255, 137, 174, 124),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.filter_list, color: Colors.white),
                  onPressed: _showFilterDialog,
                  iconSize: 30,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                itemCount: _filteredRecipes.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.8,
                ),
                itemBuilder: (context, index) {
                  final recipe = _filteredRecipes[index];
                  return RecipeCard(
                    recipe: recipe,
                    username: widget.username,
                    searchText: _searchController.text,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomNavBar(
        username: widget.username,
        currentIndex: 2,
      ),
    );
  }
}

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final String username;
  final String searchText;

  RecipeCard({
    required this.recipe,
    required this.username,
    required this.searchText,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (recipe.flag == 'recipes') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeDetailPage(
                recipeId: recipe.id,
                username: username,
              ),
            ),
          );
        } else if (recipe.flag == 'users_recipes') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeDetailPageUser(
                recipeId: recipe.id,
                username: username,
              ),
            ),
          );
        }
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Recipe image
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                image: recipe.image.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(recipe.image),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: Colors.grey[200],
              ),
              child: recipe.image.isEmpty
                  ? Icon(Icons.image, size: 50, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 8),
            // Recipe name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _buildRecipeName(),
            ),
            const Spacer(),

            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Share icon
                  IconButton(
                    icon: const Icon(Icons.share),
                    color: Colors.grey,
                    onPressed: () {
                      _shareRecipe(context);
                    },
                  ),

                  const SizedBox(width: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareRecipe(BuildContext context) {
    final String shareText =
        'Check out this recipe: ${recipe.name}!\n${recipe.image.isNotEmpty ? recipe.image : ''}';
    Share.share(shareText);
  }

  Widget _buildRecipeName() {
    String recipeName = recipe.name;
    String searchText = this.searchText;

    if (searchText.isEmpty) {
      return Text(
        recipeName,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'Times New Roman',
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      );
    }

    List<TextSpan> spans = [];
    int start = 0;
    int index = recipeName.toLowerCase().indexOf(searchText);

    while (index != -1) {
      if (index > start) {
        spans.add(TextSpan(
          text: recipeName.substring(start, index),
          style: const TextStyle(fontFamily: 'Times New Roman'),
        ));
      }
      spans.add(
        TextSpan(
          text: recipeName.substring(index, index + searchText.length),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Times New Roman',
          ),
        ),
      );
      start = index + searchText.length;
      index = recipeName.toLowerCase().indexOf(searchText, start);
    }

    if (start < recipeName.length) {
      spans.add(TextSpan(
        text: recipeName.substring(start),
        style: const TextStyle(fontFamily: 'Times New Roman'),
      ));
    }

    return RichText(
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black,
          fontFamily: 'Times New Roman',
        ),
        children: spans,
      ),
    );
  }
}

class Recipe {
  final String id;
  final String name;
  final String image;
  final String difficulty;
  final String flag;

  Recipe({
    required this.id,
    required this.name,
    required this.image,
    required this.difficulty,
    required this.flag,
  });

  factory Recipe.fromFirestore(QueryDocumentSnapshot doc, String collection) {
    final data = doc.data() as Map<String, dynamic>;

    // Safely handle the 'image' field
    String image = '';
    if (data['image'] is String) {
      image = data['image']; // Single image URL as a string
    } else if (data['image'] is List<dynamic> && data['image'].isNotEmpty) {
      image = data['image'][0]; // First image from the list
    }
    return Recipe(
      id: doc.id,
      name: data['name'] ?? '',
      image: image,
      difficulty: data['difficulty'] ?? data['difficult'] ?? '',
      flag: collection == 'recipes' ? 'recipes' : 'users_recipes',
    );
  }
}
