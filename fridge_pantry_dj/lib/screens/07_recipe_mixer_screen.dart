import 'package:flutter/material.dart';
import '../services/pantry_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';

class RecipeMixerScreen extends StatefulWidget {
  const RecipeMixerScreen({super.key});

  @override
  State<RecipeMixerScreen> createState() => _RecipeMixerScreenState();
}

class _RecipeMixerScreenState extends State<RecipeMixerScreen> {
  // Dietary preference
  Map<String, bool> dietaryPreferences = {
    'Gluten Free': false,
    'Vegan': false,
    'Vegetarian': false,
    'Dairy Free': false,
  };

  bool isLoadingPantry = false;
  String? pantryLoadError;

  //TODO implement dietary requirement filter

  // User ingredients from Add Ingredients page
  List<String> userIngredients = [];

  // Sample recipe results
  List<Map<String, dynamic>> recipes = [];
  bool isLoading = false;
  bool hasReceivedIngredients = false;

  //Gets ingredients passed from the previous screen via route arguments,
  //sets up the user ingredients list, and triggers the initial recipe fetch.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get ingredients passed from Add Ingredients screen
    if (!hasReceivedIngredients) {
      final arguments =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (arguments != null && arguments['pantryIngredients'] != null) {
        setState(() {
          userIngredients = List<String>.from(arguments['pantryIngredients']);
          hasReceivedIngredients = true;
        });

        _fetchRecipesFromAPI();

        // Show success message
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Found ${userIngredients.length} ingredients in your pantry!',
              ),
              backgroundColor: const Color(0xFF5EAAA8),
              duration: const Duration(seconds: 2),
            ),
          );
        });
      } else {
        _loadPantryFromFirebase();
      }
    }
  }

  Future<void> _loadPantryFromFirebase() async {
    setState(() {
      isLoadingPantry = true;
    });

    try {
      List<String> savedPantryList = await PantryService.loadPantryItems();

      if (savedPantryList.isEmpty) {
        // Use default ingredients if no saved data
        savedPantryList = ['Eggs', 'Milk', 'Pork', 'Beef', 'Pasta', 'Tomato'];
      }

      setState(() {
        userIngredients = savedPantryList;
        hasReceivedIngredients = true;
        isLoadingPantry = false;
      });

      _fetchRecipesFromAPI();

      // Show success message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Loaded ${userIngredients.length} ingredients from your pantry!',
              ),
              backgroundColor: const Color(0xFF5EAAA8),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    } catch (e) {
      // Use default ingredients on error
      setState(() {
        userIngredients = ['Eggs', 'Milk', 'Pork', 'Beef', 'Pasta', 'Tomato'];
        hasReceivedIngredients = true;
        isLoadingPantry = false;
        pantryLoadError = e.toString();
      });

      _fetchRecipesFromAPI();

      // Show error message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load pantry: $e'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
    }
  }

  //Makes HTTP requests to TheMealDB API to search for recipes based on the
  //user's first 3 ingredients. Removes duplicate recipes by ID and limits results to 6 recipes.
  Future<void> _fetchRecipesFromAPI() async {
    setState(() {
      isLoading = true;
    });

    try {
      List<Map<String, dynamic>> apiRecipes = [];

      // Search for recipes using user's ingredients
      for (String ingredient in userIngredients.take(3)) {
        // Limit to 3 ingredients to avoid too many API calls
        final response = await http.get(
          Uri.parse(
            'https://www.themealdb.com/api/json/v1/1/filter.php?i=$ingredient',
          ),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['meals'] != null) {
            apiRecipes.addAll(List<Map<String, dynamic>>.from(data['meals']));
          }
        }
      }

      // Remove duplicates based on idMeal
      Map<String, Map<String, dynamic>> uniqueRecipes = {};
      for (var recipe in apiRecipes) {
        uniqueRecipes[recipe['idMeal']] = recipe;
      }

      setState(() {
        recipes = uniqueRecipes.values.take(6).toList(); // Limit to 6 recipes
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching recipes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  //Fetches detailed ingredient list for a specific recipe by making another API call
  Future<List<String>> _getRecipeIngredients(String recipeId) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://www.themealdb.com/api/json/v1/1/lookup.php?i=$recipeId',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['meals'] != null && data['meals'].isNotEmpty) {
          final meal = data['meals'][0];
          List<String> ingredients = [];

          for (int i = 1; i <= 20; i++) {
            final ingredient = meal['strIngredient$i'];
            if (ingredient != null && ingredient.toString().trim().isNotEmpty) {
              ingredients.add(ingredient.toString().trim());
            }
          }

          return ingredients;
        }
      }
    } catch (e) {
      print('Error fetching recipe ingredients: $e');
    }
    return [];
  }

  //Compares recipe ingredients with user's pantry ingredients
  List<String> _getMatchingIngredients(List<String> recipeIngredients) {
    return recipeIngredients
        .where(
          (ingredient) => userIngredients.any(
            (userIngredient) =>
                userIngredient.toLowerCase().contains(
                  ingredient.toLowerCase(),
                ) ||
                ingredient.toLowerCase().contains(userIngredient.toLowerCase()),
          ),
        )
        .toList();
  }

  //Refreshes the recipe list when user clicks "Surprise me" button
  void _surpriseMe() async {
    setState(() {
      isLoading = true;
    });

    await _fetchRecipesFromAPI();

    if (recipes.isNotEmpty) {
      // Pick a random recipe
      final randomIndex = Random().nextInt(recipes.length);
      final randomRecipe = recipes[randomIndex];

      // Navigate to recipe viewer
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/recipe-viewer',
          arguments: {'recipeId': randomRecipe['idMeal']},
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎵 Surprise recipe loaded!'),
          backgroundColor: Color(0xFF9BCF53),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No recipes available to surprise you 😔'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  //Re-fetches recipes when user clicks "Mix Recipes" button.
  void _searchRecipes() async {
    setState(() {
      isLoading = true;
    });

    await _fetchRecipesFromAPI();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFD1E8E5), // Light mint
              Color(0xFFA7E9D0), // Soft green
              Color(0xFF6BB3A8), // Deep teal
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF1E3D36),
                        size: 28,
                      ),
                    ),
                    const Text(
                      'Recipe Mixer',
                      style: TextStyle(
                        fontFamily: 'Pacifico',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3D36),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Your Pantry Ingredients Section
                      Row(
                        children: [
                          const Text(
                            'Your Pantry Ingredients',
                            style: TextStyle(
                              fontFamily: 'NunitoSans',
                              fontSize: 18,
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
                              color: const Color(0xFF9BCF53),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${userIngredients.length}',
                              style: const TextStyle(
                                fontFamily: 'NunitoSans',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3D36),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Display user ingredients
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0x40FFFFFF),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: const Color(0xFF5EAAA8),
                            width: 2,
                          ),
                        ),
                        child: userIngredients.isEmpty
                            ? const Text(
                                'No ingredients received. Please add ingredients first.',
                                style: TextStyle(
                                  fontFamily: 'NunitoSans',
                                  fontSize: 14,
                                  color: Color(0xFF666666),
                                ),
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: userIngredients.map((ingredient) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5EAAA8),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Text(
                                      ingredient,
                                      style: const TextStyle(
                                        fontFamily: 'NunitoSans',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                      const SizedBox(height: 24),

                      // Dietary Requirements Section
                      const Text(
                        'Dietary Requirements',
                        style: TextStyle(
                          fontFamily: 'NunitoSans',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3D36),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dietary checkboxes
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: dietaryPreferences.entries.map((entry) {
                          return FilterChip(
                            label: Text(
                              entry.key,
                              style: TextStyle(
                                fontFamily: 'NunitoSans',
                                fontWeight: FontWeight.w600,
                                color: entry.value
                                    ? Colors.white
                                    : const Color(0xFF1E3D36),
                              ),
                            ),
                            selected: entry.value,
                            onSelected: (selected) {
                              setState(() {
                                dietaryPreferences[entry.key] = selected;
                              });
                            },
                            backgroundColor: const Color(0xFFB8D4E3),
                            selectedColor: const Color(0xFF5EAAA8),
                            checkmarkColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Surprise Me Button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9BCF53), Color(0xFF7AB83F)],
                          ),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: isLoading ? null : _surpriseMe,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.casino,
                                  color: Color(0xFF7AB83F),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Surprise me',
                                style: TextStyle(
                                  fontFamily: 'NunitoSans',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3D36),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Search button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5EAAA8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: isLoading ? null : _searchRecipes,
                          child: const Text(
                            'Mix Recipes 🎵',
                            style: TextStyle(
                              fontFamily: 'NunitoSans',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Loading indicator or recipes
                      if (isLoading || isLoadingPantry)
                        Center(
                          child: Column(
                            children: [
                              const CircularProgressIndicator(
                                color: Color(0xFF5EAAA8),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isLoadingPantry
                                    ? 'Loading your pantry ingredients...'
                                    : 'Mixing your perfect recipes...',
                                style: const TextStyle(
                                  fontFamily: 'NunitoSans',
                                  fontSize: 16,
                                  color: Color(0xFF1E3D36),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (recipes.isEmpty)
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No recipes found with your current ingredients and filters.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'NunitoSans',
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Try removing some dietary filters or adding more ingredients!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'NunitoSans',
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        // Recipe Results
                        Column(
                          children: recipes.map((recipe) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0x80FFFFFF),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black,
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Recipe image
                                    if (recipe['strMealThumb'] != null)
                                      Container(
                                        width: double.infinity,
                                        height: 120,
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          child: Image.network(
                                            recipe['strMealThumb'],
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Container(
                                                    color: Colors.grey[300],
                                                    child: const Icon(
                                                      Icons.image_not_supported,
                                                      size: 32,
                                                      color: Colors.grey,
                                                    ),
                                                  );
                                                },
                                          ),
                                        ),
                                      ),

                                    // Recipe title
                                    Text(
                                      recipe['strMeal'] ?? 'Unknown Recipe',
                                      style: const TextStyle(
                                        fontFamily: 'NunitoSans',
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E3D36),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Category tag (if available)
                                    if (recipe['strCategory'] != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF9BCF53),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          recipe['strCategory'],
                                          style: const TextStyle(
                                            fontFamily: 'NunitoSans',
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E3D36),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 12),

                                    // Matching ingredients section
                                    FutureBuilder<List<String>>(
                                      future: _getRecipeIngredients(
                                        recipe['idMeal'],
                                      ),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          final matchingIngredients =
                                              _getMatchingIngredients(
                                                snapshot.data!,
                                              );

                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Text(
                                                    'Your ingredients:',
                                                    style: TextStyle(
                                                      fontFamily: 'NunitoSans',
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF1E3D36),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF9BCF53,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '${matchingIngredients.length}',
                                                      style: const TextStyle(
                                                        fontFamily:
                                                            'NunitoSans',
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Color(
                                                          0xFF1E3D36,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              if (matchingIngredients
                                                  .isNotEmpty)
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: matchingIngredients.map((
                                                    ingredient,
                                                  ) {
                                                    return Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFF5EAAA8,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons.check,
                                                            size: 12,
                                                            color: Colors.white,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            ingredient,
                                                            style: const TextStyle(
                                                              fontFamily:
                                                                  'NunitoSans',
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                )
                                              else
                                                Text(
                                                  'No matching ingredients found',
                                                  style: TextStyle(
                                                    fontFamily: 'NunitoSans',
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                            ],
                                          );
                                        } else {
                                          return const SizedBox(
                                            height: 20,
                                            child: Center(
                                              child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Color(0xFF5EAAA8),
                                                    ),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    // View Recipe button
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF5EAAA8,
                                          ),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/recipe-viewer',
                                            arguments: {
                                              'recipeId': recipe['idMeal'],
                                            },
                                          );
                                        },
                                        child: const Text(
                                          'View Recipe',
                                          style: TextStyle(
                                            fontFamily: 'NunitoSans',
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                      const SizedBox(height: 24),

                      // Navigation buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB8D4E3),
                                foregroundColor: const Color(0xFF1E3D36),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              onPressed: () => Navigator.pushNamed(
                                context,
                                '/add-ingredients',
                              ),
                              child: const Text(
                                'Add Ingredients',
                                style: TextStyle(
                                  fontFamily: 'NunitoSans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
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
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/main-menu'),
                              child: const Text(
                                'Main Menu',
                                style: TextStyle(
                                  fontFamily: 'NunitoSans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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
