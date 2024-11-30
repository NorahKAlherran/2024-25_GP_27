import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'RecipeDetailPage.dart';
import 'nav_bar.dart';
import 'package:http/http.dart' as http;
import 'recipe_detail_page_user.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SelectIngredientsPage extends StatefulWidget {
  final String username;

  const SelectIngredientsPage({super.key, required this.username});

  @override
  _SelectIngredientsPageState createState() => _SelectIngredientsPageState();
}

class _SelectIngredientsPageState extends State<SelectIngredientsPage> {
  final List<String> fruits = [
    'Apple',
    'Banana',
    'Orange',
    'Mango',
    'Strawberry',
    'Pineapple',
    'Blueberry',
    'Kiwi',
    'Plum',
    'Apricot',
    'Blackberry',
    'Raspberry',
    'Lemon',
    'Lime',
    'Figs',
    'Pomegranate'
  ];

  final List<String> vegetables = [
    'Carrot',
    'Tomato',
    'Lettuce',
    'Cucumber',
    'Spinach',
    'Broccoli',
    'Cauliflower',
    'Onion',
    'Garlic',
    'Asparagus',
    'Potato',
    'Beetroot',
    'Mushroom',
    'Cabbage',
    'Kale',
    'Leek',
    'Squash'
  ];

  final List<String> meats = [
    'Chicken',
    'Beef',
    'Lamb',
    'Fish',
    'Turkey',
    'Sausage',
    'Salmon',
    'Tuna',
    'Trout',
    'Cod',
  ];

  final List<String> dairies = [
    'Milk',
    'Cheese',
    'Butter',
    'Yogurt',
    'Cream',
    'Ricotta',
    'Mozzarella',
    'Parmesan',
    'Cheddar',
    'Brie',
    'Buttermilk',
    'Mascarpone',
  ];
  final List<String> condimentsAndSauces = [
    'Ketchup',
    'Mustard',
    'Mayonnaise',
    'Vinegar',
    'Buffalo',
    'Worcestershire',
    'Pesto',
    'Honey',
    'Tahini',
    'Mayo',
  ];

  final List<String> nutsAndSeeds = [
    'Almonds',
    'Cashews',
    'Walnuts',
    'Pistachios',
    'Peanuts',
    'Hazelnuts',
    'Coconut',
    'Nutmeg',
  ];

  final List<String> grainsAndLegumes = [
    'Rice',
    'Barley',
    'Lentils',
    'Chickpeas',
    'Oats',
    'Peas',
  ];

  final List<String> herbsAndSpices = [
    'Basil',
    'Oregano',
    'Thyme',
    'Rosemary',
    'Parsley',
    'Mint',
    'Cumin',
    'Paprika',
    'Turmeric',
    'Ginger',
    'Cinnamon',
    'Cloves',
    'Nutmeg',
    'Saffron'
  ];

  final List<String> bakingIngredients = [
    'Flour',
    'Sugar',
    'Molasses',
    'Vanilla',
    'Salt',
    'Eggs',
    'Margarine',
  ];

  List<String> allIngredients = [];
  List<String> filteredIngredients =
      []; // List for filtered results based on search
  List<String> selectedIngredients = []; // List of selected ingredients
  List<Map<String, dynamic>> matchingRecipes = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchRandomIngredients();
  }

  Future<bool> isImageAccessible(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> _fetchRandomIngredients() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('recipes').get();

      Set<String> ingredientsSet = {};

      for (var doc in snapshot.docs) {
        List<dynamic> cleanedIngredients = doc['cleaned_ingredients'] ?? [];

        ingredientsSet
            .addAll(cleanedIngredients.map((e) => e.toString().toLowerCase()));
      }

      // Fetch public user recipes from 'user_recipes' collection
      final userRecipesSnapshot = await FirebaseFirestore.instance
          .collection('users_recipes')
          .where('source', isEqualTo: 'public')
          .get();

      for (var doc in userRecipesSnapshot.docs) {
        List<dynamic> cleanedIngredients = doc['cleaned_ingredients'] ?? [];

        ingredientsSet
            .addAll(cleanedIngredients.map((e) => e.toString().toLowerCase()));
      }

      setState(() {
        allIngredients = ingredientsSet.toList();
        filteredIngredients = [];
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching ingredients: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  String getValidImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return 'https://via.placeholder.com/150'; // Placeholder image URL
    }
    return url;
  }

  Future<void> _fetchMatchingRecipes() async {
    setState(() {
      isLoading = true;
    });

    try {
      // List to hold all matching recipes
      List<Map<String, dynamic>> allMatchingRecipes = [];

      // Normalize selected ingredients for comparison
      List<String> normalizedSelectedIngredients = selectedIngredients
          .map((ingredient) => ingredient.toLowerCase().trim())
          .toList();

      print('Selected Ingredients on search: $selectedIngredients');
      print('Normalized Selected Ingredients: $normalizedSelectedIngredients');

      // Fetch all recipes from the 'recipes' collection
      final recipesSnapshot =
          await FirebaseFirestore.instance.collection('recipes').get();

      // Fetch all user recipes from the 'users_recipes' collection
      final userRecipesSnapshot = await FirebaseFirestore.instance
          .collection('users_recipes')
          .where('source', isEqualTo: 'public')
          .get();

      // Match ingredients for recipes in the 'recipes' collection
      for (var doc in recipesSnapshot.docs) {
        var docData = doc.data() as Map<String, dynamic>;

        // Check if the "cleaned_ingredients" field exists and is a List
        if (docData.containsKey('cleaned_ingredients') &&
            docData['cleaned_ingredients'] is List) {
          List<dynamic> cleanedIngredients = docData['cleaned_ingredients'];

          bool containsAllIngredients = normalizedSelectedIngredients.every(
            (ingredient) => cleanedIngredients
                .map((e) => e.toString().toLowerCase().trim())
                .contains(ingredient),
          );

          if (containsAllIngredients) {
            allMatchingRecipes.add({
              ...docData,
              'id': doc.id,
              'source': 'recipes',
              'image': getValidImageUrl(
                  docData['image']), // Make sure getValidImageUrl exists
            });
          }
        } else {
          print(
              'Document ${doc.id} is missing or has an invalid type for the "cleaned_ingredients" field.');
        }
      }

      // Match ingredients for recipes in the 'user_recipes' collection
      for (var doc in userRecipesSnapshot.docs) {
        var docData = doc.data() as Map<String, dynamic>;

        // Check if the "cleaned_ingredients" field exists and is a List
        if (docData.containsKey('cleaned_ingredients') &&
            docData['cleaned_ingredients'] is List) {
          List<dynamic> cleanedIngredients = docData['cleaned_ingredients'];

          bool containsAllIngredients = normalizedSelectedIngredients.every(
            (ingredient) => cleanedIngredients
                .map((e) => e.toString().toLowerCase())
                .contains(ingredient),
          );

          if (containsAllIngredients) {
            allMatchingRecipes.add({
              ...docData,
              'id': doc.id,
              'source': 'users_recipes',
              'image': getValidImageUrl(
                  docData['image']), // Make sure getValidImageUrl exists
            });
          }
        } else {
          print(
              'Document ${doc.id} is missing or has an invalid type for the "cleaned_ingredients" field.');
        }
      }

      // Update state with matching recipes
      setState(() {
        matchingRecipes = allMatchingRecipes;
        isLoading = false;
      });

      // Debug: Total matching recipes found
      print('Total Matching Recipes: ${allMatchingRecipes.length}');
    } catch (e) {
      print('Error fetching recipes: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _toggleIngredientSelection(String ingredient) {
    setState(() {
      if (selectedIngredients.contains(ingredient)) {
        selectedIngredients.remove(ingredient);
      } else {
        selectedIngredients.add(ingredient);
      }
    });
  }

  void _resetSelection() {
    setState(() {
      selectedIngredients.clear();
      matchingRecipes.clear();
      searchController.clear();
      filteredIngredients = [];
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isNotEmpty) {
        // Filter the ingredients, excluding selected ones
        filteredIngredients = allIngredients
            .where((ingredient) =>
                ingredient.toLowerCase().contains(query.toLowerCase()) &&
                !selectedIngredients.contains(ingredient))
            .toList();
      } else {
        // Clear search results if the query is empty
        filteredIngredients = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Recipes By Ingredients'),
        backgroundColor: const Color.fromARGB(255, 137, 174, 124),
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Container(
              child: Column(
                children: [
                  // Search bar and selected ingredients
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            labelText: 'Search for an Ingredient',
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        if (selectedIngredients.isNotEmpty)
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: selectedIngredients.map((ingredient) {
                              return Chip(
                                label: Text(ingredient),
                                deleteIcon: Icon(Icons.close),
                                onDeleted: () {
                                  _toggleIngredientSelection(ingredient);
                                },
                                backgroundColor:
                                    const Color.fromARGB(255, 137, 174, 124),
                                labelStyle: TextStyle(color: Colors.white),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                  // Expanded ListView for categories and ingredients
                  Expanded(
                    child: ListView(
                      children: [
                        if (filteredIngredients.isNotEmpty)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Search Results:',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Wrap(
                                  spacing: 8.0,
                                  children:
                                      filteredIngredients.map((ingredient) {
                                    return FilterChip(
                                      label: Text(ingredient),
                                      selected: selectedIngredients
                                          .contains(ingredient),
                                      selectedColor: const Color.fromARGB(
                                          255, 137, 174, 124),
                                      onSelected: (_) =>
                                          _toggleIngredientSelection(
                                              ingredient),
                                    );
                                  }).toList(),
                                ),
                                Divider(),
                              ],
                            ),
                          ),
                        // Ingredient categories
                        ExpansionTile(
                          title: Text(
                            'Fruits',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          children: [
                            Wrap(
                              spacing: 8.0,
                              children: fruits.map((ingredient) {
                                return FilterChip(
                                  label: Text(ingredient),
                                  selected:
                                      selectedIngredients.contains(ingredient),
                                  selectedColor:
                                      const Color.fromARGB(255, 137, 174, 124),
                                  onSelected: (_) =>
                                      _toggleIngredientSelection(ingredient),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        Divider(),
                        ExpansionTile(
                          title: Text(
                            'Vegetables',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          children: [
                            Wrap(
                              spacing: 8.0,
                              children: vegetables.map((ingredient) {
                                return FilterChip(
                                  label: Text(ingredient),
                                  selected:
                                      selectedIngredients.contains(ingredient),
                                  selectedColor:
                                      const Color.fromARGB(255, 137, 174, 124),
                                  onSelected: (_) =>
                                      _toggleIngredientSelection(ingredient),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        Divider(),
                        ExpansionTile(
                          title: Text(
                            'Meats',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          children: [
                            Wrap(
                              spacing: 8.0,
                              children: meats.map((ingredient) {
                                return FilterChip(
                                  label: Text(ingredient),
                                  selected:
                                      selectedIngredients.contains(ingredient),
                                  selectedColor:
                                      const Color.fromARGB(255, 137, 174, 124),
                                  onSelected: (_) =>
                                      _toggleIngredientSelection(ingredient),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        Divider(),
                        // Dairies Category
                        ExpansionTile(
                          title: Text(
                            'Dairies',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          children: [
                            Wrap(
                              spacing: 8.0,
                              children: dairies.map((ingredient) {
                                return FilterChip(
                                  label: Text(ingredient),
                                  selected:
                                      selectedIngredients.contains(ingredient),
                                  selectedColor:
                                      const Color.fromARGB(255, 137, 174, 124),
                                  onSelected: (_) =>
                                      _toggleIngredientSelection(ingredient),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        Divider(),
                        // Condiments and Sauces Category
                        ExpansionTile(
                          title: Text(
                            'Condiments And Sauces',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          children: [
                            Wrap(
                              spacing: 8.0,
                              children: condimentsAndSauces.map((ingredient) {
                                return FilterChip(
                                  label: Text(ingredient),
                                  selected:
                                      selectedIngredients.contains(ingredient),
                                  selectedColor:
                                      const Color.fromARGB(255, 137, 174, 124),
                                  onSelected: (_) =>
                                      _toggleIngredientSelection(ingredient),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        Divider(),
                        // Baking Ingredients Category
                        ExpansionTile(
                          title: Text(
                            'Baking Ingredients',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          children: [
                            Wrap(
                              spacing: 8.0,
                              children: bakingIngredients.map((ingredient) {
                                return FilterChip(
                                  label: Text(ingredient),
                                  selected:
                                      selectedIngredients.contains(ingredient),
                                  selectedColor:
                                      const Color.fromARGB(255, 137, 174, 124),
                                  onSelected: (_) =>
                                      _toggleIngredientSelection(ingredient),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        Divider(),
                        // Nuts and Seeds Category
                        ExpansionTile(
                          title: Text(
                            'Nuts And Seeds',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          children: [
                            Wrap(
                              spacing: 8.0,
                              children: nutsAndSeeds.map((ingredient) {
                                return FilterChip(
                                  label: Text(ingredient),
                                  selected:
                                      selectedIngredients.contains(ingredient),
                                  selectedColor:
                                      const Color.fromARGB(255, 137, 174, 124),
                                  onSelected: (_) =>
                                      _toggleIngredientSelection(ingredient),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        Divider(),
                        // Grains and Legumes Category
                        ExpansionTile(
                          title: Text(
                            'Grains And Legumes',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          children: [
                            Wrap(
                              spacing: 8.0,
                              children: grainsAndLegumes.map((ingredient) {
                                return FilterChip(
                                  label: Text(ingredient),
                                  selected:
                                      selectedIngredients.contains(ingredient),
                                  selectedColor:
                                      const Color.fromARGB(255, 137, 174, 124),
                                  onSelected: (_) =>
                                      _toggleIngredientSelection(ingredient),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        Divider(),
                        // Herbs and Spices Category
                        ExpansionTile(
                          title: Text(
                            'Herbs And Spices',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          children: [
                            Wrap(
                              spacing: 8.0,
                              children: herbsAndSpices.map((ingredient) {
                                return FilterChip(
                                  label: Text(ingredient),
                                  selected:
                                      selectedIngredients.contains(ingredient),
                                  selectedColor:
                                      const Color.fromARGB(255, 137, 174, 124),
                                  onSelected: (_) =>
                                      _toggleIngredientSelection(ingredient),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        Divider(),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: selectedIngredients.isEmpty
                            ? null
                            : () async {
                                await _fetchMatchingRecipes();
                                if (matchingRecipes.isNotEmpty) {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(16)),
                                    ),
                                    builder: (context) {
                                      return DraggableScrollableSheet(
                                        expand: false,
                                        initialChildSize: 0.5,
                                        minChildSize: 0.3,
                                        maxChildSize: 0.8,
                                        builder: (context, scrollController) {
                                          return Stack(
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // Dialog handle for better UX
                                                  Container(
                                                    height: 5,
                                                    width: 50,
                                                    margin:
                                                        EdgeInsets.symmetric(
                                                            vertical: 10),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[400],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            16.0),
                                                    child: Text(
                                                      'Matching Recipes',
                                                      style: TextStyle(
                                                        fontSize: 22,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color
                                                            .fromARGB(
                                                            255, 137, 174, 124),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: ListView.builder(
                                                      controller:
                                                          scrollController,
                                                      itemCount: matchingRecipes
                                                          .length,
                                                      itemBuilder:
                                                          (context, index) {
                                                        final recipe =
                                                            matchingRecipes[
                                                                index];
                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      16.0,
                                                                  vertical:
                                                                      8.0),
                                                          child: Card(
                                                            elevation: 4,
                                                            shape:
                                                                RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                            ),
                                                            child: ListTile(
                                                              contentPadding:
                                                                  EdgeInsets
                                                                      .all(12),
                                                              leading:
                                                                  ClipRRect(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                                child:
                                                                    CachedNetworkImage(
                                                                  imageUrl:
                                                                      getValidImageUrl(
                                                                          recipe[
                                                                              'image']),
                                                                  width: 60,
                                                                  height: 60,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                  placeholder: (context,
                                                                          url) =>
                                                                      Container(
                                                                    width: 60,
                                                                    height: 60,
                                                                    color: Colors
                                                                            .grey[
                                                                        300],
                                                                    child: Icon(
                                                                        Icons
                                                                            .image,
                                                                        color: Colors
                                                                            .grey),
                                                                  ),
                                                                  errorWidget: (context,
                                                                          url,
                                                                          error) =>
                                                                      Container(
                                                                    width: 60,
                                                                    height: 60,
                                                                    color: Colors
                                                                            .grey[
                                                                        300],
                                                                    child: Icon(
                                                                        Icons
                                                                            .broken_image,
                                                                        color: Colors
                                                                            .grey),
                                                                  ),
                                                                ),
                                                              ),
                                                              title: Text(
                                                                recipe['name'] ??
                                                                    'Unknown',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 18,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                              subtitle: Text(
                                                                recipe['description'] ??
                                                                    'No description available',
                                                                maxLines: 2,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                              trailing: Icon(
                                                                Icons
                                                                    .arrow_forward_ios,
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                              onTap: () {
                                                                Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder:
                                                                        (context) {
                                                                      if (recipe[
                                                                              'source'] ==
                                                                          'recipes') {
                                                                        return RecipeDetailPage(
                                                                          recipeId:
                                                                              recipe['id'],
                                                                          username:
                                                                              widget.username,
                                                                        );
                                                                      } else {
                                                                        return RecipeDetailPageUser(
                                                                          recipeId:
                                                                              recipe['id'],
                                                                          username:
                                                                              widget.username,
                                                                        );
                                                                      }
                                                                    },
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              // Enhanced Scroll Indicator
                                              Align(
                                                alignment:
                                                    Alignment.bottomCenter,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 16.0),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        'Scroll for more',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              Colors.grey[700],
                                                        ),
                                                      ),
                                                      SizedBox(height: 4),
                                                      Icon(
                                                        Icons
                                                            .keyboard_arrow_down,
                                                        size: 36,
                                                        color: const Color
                                                            .fromARGB(
                                                            255, 137, 174, 124),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  );
                                } else {
                                  showModalBottomSheet(
                                    context: context,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(16)),
                                    ),
                                    builder: (context) {
                                      return Container(
                                        padding: EdgeInsets.all(16),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.search_off,
                                              size: 60,
                                              color: Colors.grey[
                                                  600], // Subtle grey color for the icon
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              'No Recipes Found',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[
                                                    800], // Darker text color for visibility
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Unfortunately, we couldn\'t find any recipes matching your selection.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey[
                                                    700], // Medium grey for the description
                                              ),
                                            ),
                                            SizedBox(height: 16),
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color.fromRGBO(
                                                        88, 126, 75, 1),
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 24,
                                                    vertical: 12),
                                              ),
                                              icon: Icon(Icons.check_circle,
                                                  color: Colors.white),
                                              label: Text(
                                                'OK',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(88, 126, 75, 1),
                          padding:
                              EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                        ),
                        child: Text(
                          "Find Recipes",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _resetSelection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 239, 73, 73),
                          padding:
                              EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                        ),
                        child: Text(
                          "Reset",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
      bottomNavigationBar: CustomNavBar(
        username: widget.username,
        currentIndex: 1,
      ),
    );
  }

  Widget _buildRecipeList() {
    return ListView.builder(
      itemCount: matchingRecipes.length,
      itemBuilder: (context, index) {
        final recipe = matchingRecipes[index];

        return ListTile(
          leading: CachedNetworkImage(
            imageUrl: getValidImageUrl(recipe['image']),
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 50,
              height: 50,
              color: Colors.grey[300], // Grey background
              child: Icon(Icons.image, color: Colors.grey), // Placeholder icon
            ),
            errorWidget: (context, url, error) => Container(
              width: 50,
              height: 50,
              color: Colors.grey[300], // Grey background
              child: Icon(Icons.broken_image, color: Colors.grey), // Error icon
            ),
          ),
          title: Text(recipe['name'] ?? 'Unknown'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) {
                  if (recipe['source'] == 'recipes') {
                    return RecipeDetailPage(
                      recipeId: recipe['id'],
                      username: widget.username,
                    );
                  } else {
                    return RecipeDetailPageUser(
                      recipeId: recipe['id'],
                      username: widget.username,
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
