import 'package:flutter/material.dart';

import '../services/pantry_service.dart';

class AddIngredientsScreen extends StatefulWidget {
  const AddIngredientsScreen({super.key});

  @override
  State<AddIngredientsScreen> createState() => _AddIngredientsScreenState();
}

class _AddIngredientsScreenState extends State<AddIngredientsScreen> {
  final TextEditingController customIngredientController =
      TextEditingController();

  List<String> savedPantryList = []; // Saved in Firebase database
  List<String> tempPantryList = []; // current session

  // Predefined common ingredients
  List<String> commonIngredients = [
    'Chicken',
    'Rice',
    'Eggs',
    'Beef',
    'Pasta',
    'Tomato',
    'Lamb',
    'Carrot',
    'Potato',
    'Cabbage',
    'Milk',
    'Bread',
  ];

  bool isLoading = false;
  bool hasInitialized = false;
  String? loadError;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (loadError != null && hasInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load pantry data: $loadError'),
              backgroundColor: Colors.orange,
            ),
          );
          loadError = null; 
        }
      });
    }
  }

  // Load saved pantry data from Firebase and populate tempPantryList for editing
  void _loadUserData() async {
    setState(() {
      isLoading = true;
    });

    try {
      savedPantryList = await PantryService.loadPantryItems();
      if (savedPantryList.isEmpty) {
        // Set default items if no saved data exists
        savedPantryList = ['Eggs', 'Milk', 'Pork', 'Beef'];
      }
      // Copy saved list to temp list for editing
      tempPantryList = List<String>.from(savedPantryList);
    } catch (e) {
      // On error, use default items
      savedPantryList = ['Eggs', 'Milk', 'Pork', 'Beef'];
      tempPantryList = List<String>.from(savedPantryList);

      // Store error to show later when context is available
      loadError = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          hasInitialized = true;
        });
      }
    }
  }

  // Save pantry data to Firebase
  Future<void> _saveUserData() async {
    try {
      await PantryService.savePantryItems(savedPantryList);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save pantry: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addCustomIngredient() {
    String ingredient = customIngredientController.text.trim();
    if (ingredient.isNotEmpty && !tempPantryList.contains(ingredient)) {
      setState(() {
        // Add to temp pantry for editing
        tempPantryList.add(ingredient);
      });
      customIngredientController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$ingredient added to your pantry!'),
          backgroundColor: const Color(0xFF5EAAA8),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (tempPantryList.contains(ingredient)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This ingredient is already in your pantry!'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _toggleCommonIngredient(String ingredient) {
    setState(() {
      if (tempPantryList.contains(ingredient)) {
        tempPantryList.remove(ingredient);
      } else {
        tempPantryList.add(ingredient);
      }
    });

    String message = tempPantryList.contains(ingredient)
        ? '$ingredient added to your pantry!'
        : '$ingredient removed from your pantry!';
    Color backgroundColor = tempPantryList.contains(ingredient)
        ? const Color(0xFF5EAAA8)
        : Colors.red[400]!;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _removeIngredient(String ingredient) {
    setState(() {
      tempPantryList.remove(ingredient);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$ingredient removed from your pantry!'),
        backgroundColor: Colors.red[400],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _editCommonIngredient(String oldIngredient) {
    TextEditingController editController = TextEditingController(
      text: oldIngredient,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Edit Ingredient',
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3D36),
            ),
          ),
          content: TextField(
            controller: editController,
            style: const TextStyle(
              fontFamily: 'NunitoSans',
              color: Color(0xFF1E3D36),
            ),
            decoration: const InputDecoration(
              hintText: 'Enter ingredient name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                String newIngredient = editController.text.trim();
                if (newIngredient.isNotEmpty &&
                    newIngredient != oldIngredient) {
                  setState(() {
                    int index = commonIngredients.indexOf(oldIngredient);
                    if (index != -1) {
                      commonIngredients[index] = newIngredient;
                    }
                    // Update in temp pantry too if it exists
                    int pantryIndex = tempPantryList.indexOf(oldIngredient);
                    if (pantryIndex != -1) {
                      tempPantryList[pantryIndex] = newIngredient;
                    }
                  });
                }
                Navigator.of(context).pop();
                editController.dispose();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Check if there are unsaved changes
  bool get hasUnsavedChanges {
    if (tempPantryList.length != savedPantryList.length) return true;
    for (String item in tempPantryList) {
      if (!savedPantryList.contains(item)) return true;
    }
    return false;
  }

  // Navigate to Recipe Mixer with pantry ingredients
  void _searchRecipes() async {
    if (tempPantryList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add some ingredients to your pantry first!'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    // Save temp list to Firebase
    savedPantryList = List<String>.from(tempPantryList);

    try {
      await _saveUserData();

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        '/recipe-mixer',
        arguments: {'pantryIngredients': List<String>.from(savedPantryList)},
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save pantry: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    customIngredientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF0F9F7), // Very light mint
              Color(0xFFE6F7F1), // Light mint
              Color(0xFFB8E6D3), // Soft green
              Color(0xFF7DD3C0), // Medium teal
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF5EAAA8)),
                      SizedBox(height: 16),
                      Text(
                        'Loading your pantry...',
                        style: TextStyle(
                          fontFamily: 'NunitoSans',
                          fontSize: 16,
                          color: Color(0xFF1E3D36),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Enhanced top bar
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: Color(0xFF1E3D36),
                                size: 24,
                              ),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.4),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Fridge & Pantry',
                                  style: TextStyle(
                                    fontFamily: 'Pacifico',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E3D36),
                                    shadows: [
                                      Shadow(
                                        color: Colors.white.withOpacity(0.9),
                                        offset: const Offset(1, 1),
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Content Area
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Welcome message
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Edit Your Items',
                                    style: TextStyle(
                                      fontFamily: 'NunitoSans',
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E3D36),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Add ingredients to find perfect recipes',
                                    style: TextStyle(
                                      fontFamily: 'NunitoSans',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(
                                        0xFF2D5A54,
                                      ).withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Custom ingredient input with improved styling
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(
                                    0xFF4CAF50,
                                  ).withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF4CAF50,
                                    ).withOpacity(0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: customIngredientController,
                                      style: const TextStyle(
                                        fontFamily: 'NunitoSans',
                                        fontSize: 15,
                                        color: Color(0xFF1E3D36),
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Type your Ingredients',
                                        hintStyle: TextStyle(
                                          color: Color(0xFF666666),
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 16,
                                        ),
                                      ),
                                      onSubmitted: (_) =>
                                          _addCustomIngredient(),
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF4CAF50,
                                      ).withOpacity(0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(
                                          0xFF4CAF50,
                                        ).withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: IconButton(
                                      onPressed: _addCustomIngredient,
                                      icon: const Icon(
                                        Icons.add,
                                        color: Color(0xFF1E3D36),
                                        size: 24,
                                      ),
                                      padding: const EdgeInsets.all(8),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Common ingredients checklist grid
                            SizedBox(
                              height: 200,
                              child: GridView.builder(
                                physics: const BouncingScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 3,
                                    ),
                                itemCount: commonIngredients.length > 10
                                    ? 10
                                    : commonIngredients.length,
                                itemBuilder: (context, index) {
                                  final ingredient = commonIngredients[index];
                                  final isSelected = tempPantryList.contains(
                                    ingredient,
                                  );

                                  return GestureDetector(
                                    onLongPress: () =>
                                        _editCommonIngredient(ingredient),
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isSelected
                                              ? const Color(0xFF5EAAA8)
                                              : const Color(0xFFB8D4E3),
                                          foregroundColor: const Color(
                                            0xFF1E3D36,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          padding: const EdgeInsets.all(8),
                                        ),
                                        onPressed: () =>
                                            _toggleCommonIngredient(ingredient),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              isSelected
                                                  ? Icons.check_circle
                                                  : Icons.circle_outlined,
                                              size: 16,
                                              color: isSelected
                                                  ? Colors.white
                                                  : const Color(0xFF1E3D36),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                ingredient,
                                                style: TextStyle(
                                                  fontFamily: 'NunitoSans',
                                                  fontSize: 11,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.w600,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : const Color(0xFF1E3D36),
                                                ),
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Your Pantry section
                            Row(
                              children: [
                                const Text(
                                  'Your Pantry',
                                  style: TextStyle(
                                    fontFamily: 'NunitoSans',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3D36),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5EAAA8),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${tempPantryList.length} items',
                                    style: const TextStyle(
                                      fontFamily: 'NunitoSans',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Add unsaved changes indicator
                                if (hasUnsavedChanges)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Unsaved',
                                      style: TextStyle(
                                        fontFamily: 'NunitoSans',
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Pantry items grid with fixed height
                            Container(
                              height: 200, // Fixed height for scrollable area
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: tempPantryList.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No ingredients in your pantry yet.\nSelect from above or add custom ones!',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'NunitoSans',
                                          fontSize: 14,
                                          color: Color(0xFF666666),
                                        ),
                                      ),
                                    )
                                  : GridView.builder(
                                      padding: const EdgeInsets.all(12),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 3,
                                            crossAxisSpacing: 8,
                                            mainAxisSpacing: 8,
                                            childAspectRatio:
                                                2.5,
                                          ),
                                      itemCount: tempPantryList.length,
                                      itemBuilder: (context, index) {
                                        final ingredient =
                                            tempPantryList[index];
                                        return Stack(
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              height: double.infinity,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF5EAAA8),
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                              ),
                                              child: Center(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8.0,
                                                        vertical: 4.0,
                                                      ),
                                                  child: Text(
                                                    ingredient,
                                                    style: const TextStyle(
                                                      fontFamily: 'NunitoSans',
                                                      fontSize:
                                                          10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Remove button for pantry items
                                            Positioned(
                                              top: 2,
                                              right: 2,
                                              child: GestureDetector(
                                                onTap: () => _removeIngredient(
                                                  ingredient,
                                                ),
                                                child: Container(
                                                  width: 16,
                                                  height: 16,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 10,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                            ),
                            const SizedBox(height: 32),

                            // Action buttons
                            Row(
                              children: [
                                // Search Recipe button
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF9BCF53),
                                      foregroundColor: const Color(0xFF1E3D36),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                    onPressed: _searchRecipes,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.search, size: 20),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            hasUnsavedChanges
                                                ? 'Search Recipe'
                                                : 'Search Recipe',
                                            style: const TextStyle(
                                              fontFamily: 'NunitoSans',
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 16),
                                // Cancel button
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[400],
                                      foregroundColor: const Color(0xFF1E3D36),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                    onPressed: () {
                                      // Reset temp list to saved list
                                      setState(() {
                                        tempPantryList = List<String>.from(
                                          savedPantryList,
                                        );
                                      });
                                      Navigator.pop(context);
                                    },
                                    child: Flexible(
                                      child: Text(
                                        hasUnsavedChanges
                                            ? 'Discard Changes'
                                            : 'Cancel',
                                        style: const TextStyle(
                                          fontFamily: 'NunitoSans',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
