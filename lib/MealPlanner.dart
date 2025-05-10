import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'nav_bar.dart';
import 'Recipe_Detail_Page_User.dart';
import 'RecipeDetailPage.dart';

class MealPlannerPage extends StatefulWidget {
  final String username;
  const MealPlannerPage({Key? key, required this.username}) : super(key: key);

  @override
  _MealPlannerPageState createState() => _MealPlannerPageState();
}

class _MealPlannerPageState extends State<MealPlannerPage> {
  DateTime startOfWeek = DateTime.now();
  Map<String, dynamic> plannerData = {};
  bool _isDailyView = false; // Track View Mode (Default: Weekly View)
  bool _isMinimalView = false;

  @override
  void initState() {
    super.initState();
    startOfWeek = _getStartOfWeek(DateTime.now());
    _fetchPlannerData();
  }

  DateTime _getStartOfWeek(DateTime date) {
    int dayOfWeek = date.weekday;
    return date.subtract(Duration(days: dayOfWeek - 1));
  }

  void _changeWeek(int offset) {
    DateTime twoWeeksAgo =
        DateTime.now().subtract(Duration(days: 14)); // Two weeks back
    DateTime newStartOfWeek = startOfWeek.add(Duration(days: offset * 7));

    if (newStartOfWeek.isBefore(_getStartOfWeek(twoWeeksAgo))) {
      // Prevent user from going beyond two weeks back
      return;
    }

    setState(() {
      startOfWeek = newStartOfWeek;
    });

    _fetchPlannerData();
  }

  void _toggleViewMode() {
    setState(() {
      _isDailyView = !_isDailyView;
    });
  }

  Future<void> _fetchPlannerData() async {
    Map<String, dynamic> data = {};
    DateTime today = DateTime.now();
    String todayKey = DateFormat('yyyy-MM-dd').format(today);
    DateTime twoWeeksAgo = today.subtract(Duration(days: 14));

    for (int i = 0; i < 7; i++) {
      DateTime day = startOfWeek.add(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(day);

      if (day.isBefore(twoWeeksAgo)) continue;

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('planner')
          .doc(widget.username)
          .collection('weeks')
          .doc(dateKey)
          .get();

      if (doc.exists) {
        var docData = doc.data() as Map<String, dynamic>;
        List<dynamic> meals = docData['meals'] ?? [];
        String occasion = docData['occasion'] ?? "";

        List<dynamic> validMeals = [];

        for (var meal in meals) {
          if (!meal.containsKey('recipeId') || !meal.containsKey('source'))
            continue;

          String source = meal['source'];
          String recipeId = meal['recipeId'];

          try {
            DocumentSnapshot recipeDoc = await FirebaseFirestore.instance
                .collection(source)
                .doc(recipeId)
                .get();

            if (recipeDoc.exists) {
              validMeals.add(meal);
            } else {
              print("Recipe no longer exists: $source/$recipeId");
            }
          } catch (e) {
            print("⚠️ Error checking recipe existence: $e");
          }
        }

        data[dateKey] = {
          'meals': validMeals,
          'occasion': occasion,
        };

        // Clean Firestore if invalid meals were removed
        if (validMeals.length != meals.length) {
          await FirebaseFirestore.instance
              .collection('planner')
              .doc(widget.username)
              .collection('weeks')
              .doc(dateKey)
              .update({'meals': validMeals});
        }
      } else {
        // Add today even if it's empty
        if (dateKey == todayKey) {
          data[dateKey] = {'meals': [], 'occasion': ''};
        }
      }
    }

    // Ensure today is always present
    if (!data.containsKey(todayKey)) {
      data[todayKey] = {'meals': [], 'occasion': ''};
    }

    setState(() {
      plannerData = data;
    });
  }

  void _showOccasionDialog(DateTime date) {
    String dateKey = DateFormat('yyyy-MM-dd').format(date);

    FirebaseFirestore.instance
        .collection('planner')
        .doc(widget.username)
        .collection('weeks')
        .doc(dateKey)
        .get()
        .then((doc) {
      if (doc.exists && doc.data()?['occasion'] != null) {
        // ✅ Occasion Exists: Show "Remove Occasion" Confirmation Dialog
        _showRemoveOccasionDialog(dateKey);
      } else {
        // ✅ Occasion Does NOT Exist: Show "Add Occasion" Dialog
        _showAddOccasionDialog(date);
      }
    });
  }

  /// *Shows the Remove Occasion Confirmation Dialog*
  void _showRemoveOccasionDialog(String dateKey) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Remove Occasion"),
          content: Text("Do you want to remove this occasion?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // ❌ Cancel
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                // ✅ Remove the occasion from Firebase
                FirebaseFirestore.instance
                    .collection('planner')
                    .doc(widget.username)
                    .collection('weeks')
                    .doc(dateKey)
                    .update({'occasion': FieldValue.delete()}).then((_) {
                  _fetchPlannerData();
                  Navigator.pop(context);
                });
              },
              child: Text("Yes", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  /// *Shows the Add Occasion Dialog*
  void _showAddOccasionDialog(DateTime date) {
    TextEditingController occasionController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Enter Occasion Name"),
          content: TextField(
            controller: occasionController,
            decoration: InputDecoration(hintText: ""),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                String occasion = occasionController.text.trim();
                if (occasion.isNotEmpty) {
                  FirebaseFirestore.instance
                      .collection('planner')
                      .doc(widget.username)
                      .collection('weeks')
                      .doc(DateFormat('yyyy-MM-dd').format(date))
                      .set({
                    'occasion': occasion
                  }, SetOptions(merge: true)).then((_) => _fetchPlannerData());
                }
                Navigator.pop(context);
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _showMealTypeDialog(DateTime date, Map<String, dynamic> meal) {
    List<Map<String, dynamic>> mealTypes = [
      {
        'name': 'Breakfast',
        'icon': Icons.wb_sunny_outlined,
        'color': Colors.blue
      },
      {'name': 'Lunch', 'icon': Icons.wb_sunny, 'color': Colors.orange},
      {'name': 'Dinner', 'icon': Icons.nightlight_round, 'color': Colors.red},
      {'name': 'Snacks', 'icon': Icons.card_giftcard, 'color': Colors.green},
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Select Meal Type"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: mealTypes.map((type) {
              return ListTile(
                leading: Icon(type['icon'], color: type['color']),
                title: Text(type['name']),
                onTap: () {
                  if (!meal.containsKey('recipeId')) {
                    print("❌ Error: Missing recipeId before saving meal.");
                    return;
                  }
                  _saveMeal(date, meal, type['name']);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  /// *Saves the selected meal with its type in Firebase*
  void _saveMeal(DateTime date, Map<String, dynamic> meal, String mealType) {
    String dateKey = DateFormat('yyyy-MM-dd').format(date);

    if (!meal.containsKey('recipeId') ||
        meal['recipeId'] == null ||
        meal['recipeId'].isEmpty) {
      print("❌ Error: meal is missing recipeId when saving to planner.");
      return;
    }

    // Ensure correct source based on 'flag' field
    String source = 'recipes'; // Default to public recipes
    if (meal.containsKey('flag') && meal['flag'] == 'users_recipes') {
      source = 'users_recipes'; // Set to user recipe if flagged correctly
    }

    FirebaseFirestore.instance
        .collection('planner')
        .doc(widget.username)
        .collection('weeks')
        .doc(dateKey)
        .set({
      'meals': FieldValue.arrayUnion([
        {
          'name': meal['name'],
          'image': meal['image'] ?? '',
          'type': mealType,
          'recipeId': meal['recipeId'],
          'source': source, // Now it correctly sets based on Firebase flag
        }
      ])
    }, SetOptions(merge: true)).then((_) => _fetchPlannerData());
  }

  void _showMealSelectionDialog(DateTime date) async {
    List<Map<String, dynamic>> recipes = [];
    TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> filteredRecipes = [];

    String dateKey = DateFormat('yyyy-MM-dd').format(date);

    //  Fetch already selected meals for this date
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('planner')
        .doc(widget.username)
        .collection('weeks')
        .doc(dateKey)
        .get();

    List<dynamic> selectedMeals = [];
    if (doc.exists) {
      var docData = doc.data() as Map<String, dynamic>;
      selectedMeals = docData['meals'] ?? [];
    }

    //  Fetch recipes from Firestore (Public & User Recipes)
    var recipesSnapshot =
        await FirebaseFirestore.instance.collection('recipes').get();
    var userRecipesSnapshot = await FirebaseFirestore.instance
        .collection('users_recipes')
        .where('source', isEqualTo: 'public')
        .get();

    //  Convert Firestore documents to a usable list
    recipes.addAll(recipesSnapshot.docs
        .map((doc) => {...doc.data(), 'recipeId': doc.id, 'source': 'public'}));

    recipes.addAll(userRecipesSnapshot.docs.map((doc) =>
        {...doc.data(), 'recipeId': doc.id, 'source': 'users_recipes'}));

    filteredRecipes = List.from(recipes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return Container(
            padding: EdgeInsets.all(10),
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: searchController,
                    onChanged: (query) {
                      setState(() {
                        filteredRecipes = recipes
                            .where((recipe) => recipe['name']
                                .toLowerCase()
                                .contains(query.toLowerCase()))
                            .toList();
                      });
                    },
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      hintText: "Search recipes...",
                      hintStyle: TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredRecipes.length,
                    itemBuilder: (context, index) {
                      var recipe = filteredRecipes[index];
                      bool isSelected = selectedMeals.any(
                          (meal) => meal['recipeId'] == recipe['recipeId']);

                      String imageUrl = (recipe['image'] is List &&
                              recipe['image'].isNotEmpty)
                          ? recipe['image'][0]
                          : (recipe['image'] is String
                              ? recipe['image']
                              : 'https://via.placeholder.com/50');

                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.broken_image, size: 50),
                          ),
                        ),
                        title: Text(
                          recipe['name'] ?? "Unnamed Recipe",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.grey : Colors.black,
                          ),
                        ),
                        subtitle: isSelected
                            ? Text(
                                "Already Selected",
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 12),
                              )
                            : Text(
                                "Tap to add",
                                style: TextStyle(
                                    color: Colors.green, fontSize: 12),
                              ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        onTap: isSelected
                            ? null
                            : () {
                                if (!recipe.containsKey('recipeId') ||
                                    recipe['recipeId'] == null ||
                                    recipe['recipeId'].isEmpty) {
                                  print(
                                      "❌ Error: recipeId is missing in Firestore data.");
                                  return;
                                }

                                Navigator.pop(context);
                                Future.delayed(Duration(milliseconds: 200), () {
                                  _showMealTypeDialog(date, recipe);
                                });
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  /// *Returns the appropriate color based on the meal type*
  Color _getMealTypeColor(String? mealType) {
    switch (mealType) {
      case "Breakfast":
        return Colors.blue;
      case "Lunch":
        return Colors.orange;
      case "Dinner":
        return Colors.red;
      case "Snacks":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _editMealType(String dateKey, Map<String, dynamic> meal) {
    List<Map<String, dynamic>> mealTypes = [
      {
        'name': 'Breakfast',
        'icon': Icons.wb_sunny_outlined,
        'color': Colors.blue
      },
      {'name': 'Lunch', 'icon': Icons.wb_sunny, 'color': Colors.orange},
      {'name': 'Dinner', 'icon': Icons.nightlight_round, 'color': Colors.red},
      {'name': 'Snacks', 'icon': Icons.card_giftcard, 'color': Colors.green},
    ];

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // *Title*
                Text(
                  "Select Meal Type",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 15),

                // *Meal Type List*
                Column(
                  children: mealTypes.map((type) {
                    return ListTile(
                      leading:
                          Icon(type['icon'], color: type['color'], size: 28),
                      title: Text(type['name'], style: TextStyle(fontSize: 16)),
                      onTap: () {
                        // Update Meal Type in Firebase
                        FirebaseFirestore.instance
                            .collection('planner')
                            .doc(widget.username)
                            .collection('weeks')
                            .doc(dateKey)
                            .update({
                          'meals':
                              FieldValue.arrayRemove([meal]) // Remove old meal
                        }).then((_) {
                          //  Add updated meal
                          meal['type'] = type['name'];
                          FirebaseFirestore.instance
                              .collection('planner')
                              .doc(widget.username)
                              .collection('weeks')
                              .doc(dateKey)
                              .update({
                            'meals': FieldValue.arrayUnion(
                                [meal]) // Add updated meal
                          }).then((_) => _fetchPlannerData());
                        });

                        Navigator.pop(context); // Close the modal
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deleteMeal(String dateKey, Map<String, dynamic> meal) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Delete Meal"),
          content: Text("Are you sure you want to remove this meal?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                // Remove meal from Firebase
                FirebaseFirestore.instance
                    .collection('planner')
                    .doc(widget.username)
                    .collection('weeks')
                    .doc(dateKey)
                    .update({
                  'meals': FieldValue.arrayRemove([meal])
                }).then((_) => _fetchPlannerData());

                Navigator.pop(context); //  Close the dialog
              },
              child: Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  /// *Shows a Date Picker & Updates the Week View*
  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: startOfWeek, // Default to current week
      firstDate: DateTime(2020, 1), // Earliest selectable date
      lastDate: DateTime(2030, 12), // Latest selectable date
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.green, // Calendar header color
            hintColor: Colors.green, // Calendar selection color
            colorScheme: ColorScheme.light(primary: Colors.green),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != startOfWeek) {
      setState(() {
        startOfWeek = _getStartOfWeek(picked); // Navigate to selected week
      });
      _fetchPlannerData(); // Refresh the data
    }
  }

  void _onMealTap(Map<String, dynamic> meal) {
    if (!meal.containsKey('recipeId') || meal['recipeId'] == null) {
      print("❌ Error: Missing recipeId when navigating to RecipeDetailPage!");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Missing recipe details!')),
      );
      return;
    }

    // Navigate correctly based on the 'source' field
    if (meal.containsKey('source') && meal['source'] == 'users_recipes') {
      // Navigate to user-created recipe details
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeDetailPageUser(
            recipeId: meal['recipeId'],
            username: widget.username,
          ),
        ),
      );
    } else {
      // Navigate to public recipe details
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeDetailPage(
            recipeId: meal['recipeId'],
            username: widget.username,
          ),
        ),
      );
    }
  }

  void _showStarredDaysDialog() async {
    List<Map<String, dynamic>> starredDays = [];

    //  Fetch all starred days
    var querySnapshot = await FirebaseFirestore.instance
        .collection('planner')
        .doc(widget.username)
        .collection('weeks')
        .where('occasion', isNotEqualTo: '')
        .get();

    for (var doc in querySnapshot.docs) {
      String dateKey = doc.id;
      DateTime date = DateFormat('yyyy-MM-dd').parse(dateKey);
      String formattedDate = DateFormat('EEEE, dd MMM yyyy').format(date);
      String occasion = doc.data()['occasion'];

      starredDays.add({
        'dateKey': dateKey,
        'formattedDate': formattedDate,
        'occasion': occasion,
      });
    }

    //  Show Dialog with Starred Days List
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Starred Days"),
          content: starredDays.isEmpty
              ? Text("No starred days found.")
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: starredDays.map((day) {
                    return ListTile(
                      leading: Icon(Icons.star, color: Colors.yellow[700]),
                      title: Text(day['formattedDate']),
                      subtitle: Text(day['occasion']),
                      onTap: () {
                        //  Jump to Selected Starred Day
                        Navigator.pop(context);
                        setState(() {
                          startOfWeek = _getStartOfWeek(
                              DateFormat('yyyy-MM-dd').parse(day['dateKey']));
                        });
                        _fetchPlannerData();
                      },
                    );
                  }).toList(),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime endOfWeek = startOfWeek.add(Duration(days: 6));
    DateTime today = DateTime.now();
    String todayKey = DateFormat('yyyy-MM-dd').format(today);

    return Scaffold(
      appBar: AppBar(
          title: Text("My Meal Planner"),
          backgroundColor: const Color.fromARGB(255, 137, 174, 124),
          automaticallyImplyLeading: false,
          actions: [
            Row(
              children: [
                //  Toggle Minimal View Mode
                IconButton(
                  icon: SizedBox(
                    width: 50,
                    height: 50,
                    child: _isMinimalView
                        ? Image.asset('assets/images/weekly.png')
                        : Image.asset('assets/images/day.png'),
                  ),
                  iconSize: 24,
                  onPressed: () {
                    setState(() {
                      _isMinimalView = !_isMinimalView;

                      //  When entering minimal view, show only today
                      if (_isMinimalView) {
                        startOfWeek = _getStartOfWeek(DateTime.now());
                        _fetchPlannerData();
                      }
                    });
                  },
                ),

                // ⭐Show Starred Days List
                IconButton(
                  icon: Icon(Icons.star, color: Colors.yellow[700]),
                  iconSize: 40,
                  onPressed: () => _showStarredDaysDialog(),
                ),
              ],
            ),
          ]),
      body: Column(
        children: [
          if (!_isMinimalView)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                      icon: Icon(Icons.arrow_left),
                      onPressed: () => _changeWeek(-1)),
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Text(
                      "${DateFormat('dd MMM yyyy').format(startOfWeek)} - ${DateFormat('dd MMM yyyy').format(endOfWeek)}",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  IconButton(
                      icon: Icon(Icons.arrow_right),
                      onPressed: () => _changeWeek(1)),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _isMinimalView ? 1 : 7,
              itemBuilder: (context, index) {
                DateTime day = _isMinimalView
                    ? today
                    : startOfWeek.add(Duration(days: index));
                String dateKey = DateFormat('yyyy-MM-dd').format(day);

                List<dynamic> meals = plannerData[dateKey]?['meals'] ?? [];
                String occasion = plannerData[dateKey]?['occasion'] ?? "";

                if (day.isBefore(today) &&
                    meals.isEmpty &&
                    occasion.isEmpty &&
                    dateKey != todayKey) {
                  return SizedBox.shrink();
                }

                print(
                    "Rendering UI for: ${DateFormat('dd MMM yyyy').format(day)}, Data: ${plannerData[dateKey]}");

                return _isMinimalView
                    ? _buildMinimalDailyMealView(
                        day, meals, occasion) // ✅ Different UI for minimal mode
                    : _buildDailyMealView(day, meals, occasion);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          CustomNavBar(currentIndex: 3, username: widget.username),
    );
  }

  Widget _buildMinimalDailyMealView(
      DateTime day, List<dynamic> meals, String occasion) {
    String dateKey = DateFormat('yyyy-MM-dd').format(day);
    String formattedDate =
        DateFormat('EEEE, dd MMMM yyyy').format(day); // e.g. "Tuesday, 06 May"
    bool hasOccasion = occasion.isNotEmpty;

    Map<String, List<Map<String, dynamic>>> groupedMeals = {
      "Breakfast": [],
      "Lunch": [],
      "Dinner": [],
      "Snacks": [],
    };

    for (var meal in meals) {
      String mealType = meal['type'] ?? "";
      if (groupedMeals.containsKey(mealType)) {
        groupedMeals[mealType]!.add(meal);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //  Date Title
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),

          // Occasion
          if (hasOccasion)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                "Occasion: $occasion",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),

          // Meal Groups
          ...groupedMeals.entries
              .where((entry) => entry.value.isNotEmpty)
              .map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //  Meal Type Header
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 5),
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getMealTypeColor(entry.key),
                    ),
                  ),
                ),

                // Meals List
                Card(
                  margin: EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Column(
                      children: entry.value.map((meal) {
                        //  Safely extract image
                        String imageUrl =
                            (meal['image'] is List && meal['image'].isNotEmpty)
                                ? meal['image'][0]
                                : (meal['image'] is String
                                    ? meal['image']
                                    : 'https://via.placeholder.com/50');

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              // Meal Image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageUrl,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(Icons.broken_image, size: 50),
                                ),
                              ),
                              SizedBox(width: 15),

                              //  Meal Name
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _onMealTap(meal),
                                  child: Text(
                                    meal['name'].length > 16
                                        ? meal['name'].substring(0, 16) + "..."
                                        : meal['name'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),

                              //  Edit Meal
                              IconButton(
                                icon: Icon(Icons.edit,
                                    color: Colors.blue, size: 24),
                                onPressed: () => _editMealType(dateKey, meal),
                              ),

                              //  Delete Meal
                              IconButton(
                                icon: Icon(Icons.delete,
                                    color: Colors.red, size: 24),
                                onPressed: () => _deleteMeal(dateKey, meal),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),

          //  Footer Buttons
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    hasOccasion ? Icons.star : Icons.star_border,
                    color: hasOccasion ? Colors.yellow[700] : Colors.grey,
                    size: 36,
                  ),
                  onPressed: () => _showOccasionDialog(day),
                ),
                SizedBox(width: 15),
                IconButton(
                  icon: Icon(Icons.add_circle_outline,
                      color: Colors.green, size: 36),
                  onPressed: () => _showMealSelectionDialog(day),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyMealView(
      DateTime day, List<dynamic> meals, String occasion) {
    bool hasOccasion = occasion.isNotEmpty;
    String dateKey = DateFormat('yyyy-MM-dd').format(day);
    DateTime today = DateTime.now();
    bool isToday = dateKey == DateFormat('yyyy-MM-dd').format(today);
    bool isPastDay = day.isBefore(today.subtract(Duration(days: 1)));

    //  Group meals by type
    Map<String, List<Map<String, dynamic>>> groupedMeals = {
      "Breakfast": [],
      "Lunch": [],
      "Dinner": [],
      "Snacks": [],
    };

    for (var meal in meals) {
      String mealType = meal['type'] ?? "";
      if (groupedMeals.containsKey(mealType)) {
        groupedMeals[mealType]!.add(meal);
      }
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isToday ? Colors.green[100] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE dd MMM').format(day),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isToday ? Colors.green[800] : Colors.black,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        hasOccasion ? Icons.star : Icons.star_border,
                        color: hasOccasion
                            ? Colors.yellow[700]
                            : isPastDay
                                ? Colors.grey
                                : Colors.yellow,
                        size: 30,
                      ),
                      onPressed:
                          isPastDay ? null : () => _showOccasionDialog(day),
                      iconSize: 32,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: isPastDay ? Colors.grey : Colors.green,
                        size: 30,
                      ),
                      onPressed: isPastDay
                          ? null
                          : () => _showMealSelectionDialog(day),
                      iconSize: 32,
                    ),
                  ],
                ),
              ],
            ),
            if (hasOccasion)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  "Occasion: $occasion",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700]),
                ),
              ),
            SizedBox(height: 5),
            ...groupedMeals.entries
                .where((entry) => entry.value.isNotEmpty)
                .map((entry) {
              return Card(
                margin: EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getMealTypeColor(entry.key),
                        ),
                      ),
                      SizedBox(height: 5),
                      ...entry.value.map((meal) {
                        String imageUrl =
                            (meal['image'] is List && meal['image'].isNotEmpty)
                                ? meal['image'][0]
                                : (meal['image'] is String
                                    ? meal['image']
                                    : 'https://via.placeholder.com/50');

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageUrl,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(Icons.broken_image, size: 50),
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _onMealTap(meal),
                                  child: Text(
                                    meal['name'].length > 16
                                        ? meal['name'].substring(0, 16) + "..."
                                        : meal['name'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit,
                                    color: isPastDay
                                        ? Colors.grey
                                        : const Color.fromARGB(
                                            255, 48, 143, 90)),
                                onPressed: isPastDay
                                    ? null
                                    : () => _editMealType(dateKey, meal),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete,
                                    color:
                                        isPastDay ? Colors.grey : Colors.red),
                                onPressed: isPastDay
                                    ? null
                                    : () => _deleteMeal(dateKey, meal),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
