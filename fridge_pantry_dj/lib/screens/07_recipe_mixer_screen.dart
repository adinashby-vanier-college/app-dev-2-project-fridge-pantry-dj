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
  bool isLoadingPantry = false;
  String? pantryLoadError;

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
      for (String ingredient in userIngredients) {
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
        recipes = uniqueRecipes.values.toList(); // no limit
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
          content: Text('ðŸŽµ Surprise recipe loaded!'),
          backgroundColor: Color(0xFF9BCF53),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No recipes available to surprise you ðŸ˜”'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }

    setState(() {
      isLoading = false;
    });
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
          child: Column(
            children: [
              // Enhanced top bar (matching SavedRecipesScreen)
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
                            'Recipe Mixer',
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

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Your Pantry Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF795548).withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF795548).withOpacity(0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(0.8),
                              blurRadius: 8,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF4CAF50,
                                    ).withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.kitchen,
                                    size: 16,
                                    color: Color(0xFF4CAF50),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Your Pantry',
                                  style: TextStyle(
                                    fontFamily: 'NunitoSans',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2D5A54),
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
                                    '${userIngredients.length} items',
                                    style: const TextStyle(
                                      fontFamily: 'NunitoSans',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (userIngredients.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF795548,
                                        ).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.kitchen_outlined,
                                        size: 32,
                                        color: Color(0xFF795548),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No ingredients found',
                                      style: TextStyle(
                                        fontFamily: 'NunitoSans',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E3D36),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Please add ingredients first',
                                      style: TextStyle(
                                        fontFamily: 'NunitoSans',
                                        fontSize: 12,
                                        color: const Color(
                                          0xFF2D5A54,
                                        ).withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Wrap(
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Surprise Me Button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF9BCF53).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9BCF53), Color(0xFF7AB83F)],
                            ),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isLoading ? null : _surpriseMe,
                              borderRadius: BorderRadius.circular(25),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
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
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Loading indicator or recipes
                      if (isLoading || isLoadingPantry)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
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
                          ),
                        )
                      else if (recipes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No recipes found',
                                  style: TextStyle(
                                    fontFamily: 'NunitoSans',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E3D36),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try adding different ingredients or check your pantry',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'NunitoSans',
                                    fontSize: 14,
                                    color: const Color(
                                      0xFF2D5A54,
                                    ).withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        // Recipe count header
                        Row(
                          children: [
                            const Text(
                              'Recipe Results',
                              style: TextStyle(
                                fontFamily: 'NunitoSans',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
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
                                '${recipes.length} found',
                                style: const TextStyle(
                                  fontFamily: 'NunitoSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Recipe Results (smaller cards)
                        ...recipes.map((recipe) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF795548).withOpacity(0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF795548,
                                  ).withOpacity(0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.8),
                                  blurRadius: 8,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Recipe image (smaller)
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF795548,
                                        ).withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: recipe['strMealThumb'] != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Image.network(
                                              recipe['strMealThumb'],
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return Container(
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFF795548,
                                                        ).withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: const Icon(
                                                        Icons.restaurant,
                                                        color: Color(
                                                          0xFF795548,
                                                        ),
                                                        size: 24,
                                                      ),
                                                    );
                                                  },
                                            ),
                                          )
                                        : Container(
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF795548,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.restaurant,
                                              color: Color(0xFF795548),
                                              size: 24,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Recipe details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          recipe['strMeal'] ?? 'Unknown Recipe',
                                          style: const TextStyle(
                                            fontFamily: 'NunitoSans',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF2D5A54),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),

                                        // Matching ingredients
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
                                                      const Icon(
                                                        Icons
                                                            .check_circle_outline,
                                                        size: 14,
                                                        color: Color(
                                                          0xFF4CAF50,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${matchingIngredients.length} matches',
                                                        style: const TextStyle(
                                                          fontFamily:
                                                              'NunitoSans',
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                            0xFF4CAF50,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  if (matchingIngredients
                                                      .isNotEmpty)
                                                    Text(
                                                      matchingIngredients.join(
                                                        ", ",
                                                      ),
                                                      style: const TextStyle(
                                                        fontFamily:
                                                            'NunitoSans',
                                                        fontSize:
                                                            10, // smaller lettering
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        color: Color(
                                                          0xFF4CAF50,
                                                        ),
                                                      ),
                                                    ),
                                                  const SizedBox(height: 8),
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            const Color(
                                                              0xFF5EAAA8,
                                                            ),
                                                        foregroundColor:
                                                            Colors.white,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                15,
                                                              ),
                                                        ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 8,
                                                            ),
                                                      ),
                                                      onPressed: () {
                                                        Navigator.pushNamed(
                                                          context,
                                                          '/recipe-viewer',
                                                          arguments: {
                                                            'recipeId':
                                                                recipe['idMeal'],
                                                          },
                                                        );
                                                      },
                                                      child: const Text(
                                                        'View Recipe',
                                                        style: TextStyle(
                                                          fontFamily:
                                                              'NunitoSans',
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            } else {
                                              return const SizedBox(
                                                height: 16,
                                                child: Center(
                                                  child: SizedBox(
                                                    width: 12,
                                                    height: 12,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Color(
                                                            0xFF5EAAA8,
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],

                      const SizedBox(height: 24),

                      // Navigation buttons
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFB8D4E3,
                                    ).withOpacity(0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
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
                                  'Edit Pantry',
                                  style: TextStyle(
                                    fontFamily: 'NunitoSans',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF9BCF53,
                                    ).withOpacity(0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
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
