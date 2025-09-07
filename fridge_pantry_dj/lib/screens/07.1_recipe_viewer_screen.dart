import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RecipeViewerScreen extends StatefulWidget {
  const RecipeViewerScreen({super.key});

  @override
  State<RecipeViewerScreen> createState() => _RecipeViewerScreenState();
}

class _RecipeViewerScreenState extends State<RecipeViewerScreen> {
  Map<String, dynamic>? recipe;
  bool isLoading = true;
  String? error;
  bool isFavorited = false;

  final DatabaseReference dbRef = FirebaseDatabase.instance.ref();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRecipe();
    _checkIfFavorited();
  }

  Future<void> _loadRecipe() async {
    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (arguments == null || arguments['recipeId'] == null) {
      if (mounted) {
        setState(() {
          error = 'No recipe ID provided';
          isLoading = false;
        });
      }
      return;
    }

    try {
      final recipeId = arguments['recipeId'];
      final response = await http.get(
        Uri.parse(
          'https://www.themealdb.com/api/json/v1/1/lookup.php?i=$recipeId',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['meals'] != null && data['meals'].isNotEmpty) {
          if (mounted) {
            setState(() {
              recipe = data['meals'][0];
              isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              error = 'Recipe not found';
              isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            error = 'Failed to load recipe';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Error loading recipe: $e';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _checkIfFavorited() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments == null || arguments['recipeId'] == null) return;

    final recipeId = arguments['recipeId'];

    try {
      final snapshot = await dbRef
          .child('users/${user.uid}/favorites/$recipeId')
          .get();

      if (mounted) {
        setState(() {
          isFavorited = snapshot.exists;
        });
      }
    } catch (e) {
      // Handle error silently or log it
      print('Error checking favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to bookmark')),
        );
      }
      return;
    }

    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments == null || arguments['recipeId'] == null) return;

    final recipeId = arguments['recipeId'];

    try {
      if (isFavorited) {
        // remove favorite
        await dbRef.child('users/${user.uid}/favorites/$recipeId').remove();
        if (mounted) {
          setState(() {
            isFavorited = false;
          });
        }
      } else {
        // save favorite
        await dbRef.child('users/${user.uid}/favorites/$recipeId').set({
          'recipeId': recipeId,
          'title': recipe!['strMeal'],
          'thumbnail': recipe!['strMealThumb'],
          'timestamp': DateTime.now().toIso8601String(),
        });
        if (mounted) {
          setState(() {
            isFavorited = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating favorite: $e')));
      }
    }
  }

  void _navigateToNutriPal() {
    if (recipe == null) return;

    // Create ingredient map with proper quantity and ingredient separation
    Map<String, String> ingredientMap = {};

    for (int i = 1; i <= 20; i++) {
      final ingredient = recipe!['strIngredient$i'];
      final measure = recipe!['strMeasure$i'];

      if (ingredient != null && ingredient.toString().trim().isNotEmpty) {
        final cleanIngredient = ingredient.toString().trim();
        final cleanMeasure = measure?.toString().trim() ?? '';

        // Store as "ingredient_name": "quantity"
        ingredientMap[cleanIngredient] = cleanMeasure;
      }
    }

    final recipeData = {
      'recipeName': recipe!['strMeal'] ?? 'Unknown Recipe',
      'ingredientMap': ingredientMap,
      'instructions': _getInstructions(),
      'category': recipe!['strCategory'] ?? 'Unknown',
      'area': recipe!['strArea'] ?? 'Unknown',
      'fromRecipeViewer': true,
    };

    Navigator.pushNamed(context, '/nutripal', arguments: recipeData);
  }

  List<Map<String, String>> _getIngredients() {
    if (recipe == null) return [];

    List<Map<String, String>> ingredients = [];

    for (int i = 1; i <= 20; i++) {
      final ingredient = recipe!['strIngredient$i'];
      final measure = recipe!['strMeasure$i'];

      if (ingredient != null && ingredient.toString().trim().isNotEmpty) {
        ingredients.add({
          'ingredient': ingredient.toString().trim(),
          'measure': measure?.toString().trim() ?? '',
        });
      }
    }

    return ingredients;
  }

  List<String> _getInstructions() {
    if (recipe == null || recipe!['strInstructions'] == null) return [];

    String instructions = recipe!['strInstructions'].toString();

    List<String> steps = instructions
        .split(RegExp(r'[\.\n]'))
        .where((step) => step.trim().isNotEmpty)
        .map((step) => step.trim())
        .where((step) => step.length > 10)
        .toList();

    if (steps.length < 3) {
      steps = instructions
          .split(RegExp(r'(?<=[.!?])\s+'))
          .where((step) => step.trim().isNotEmpty && step.length > 20)
          .map((step) => step.trim())
          .toList();
    }

    if (steps.isEmpty) {
      steps = [instructions.trim()];
    }

    return steps;
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
                            'Recipe',
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

              Expanded(
                child: isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF5EAAA8)),
                            SizedBox(height: 16),
                            Text(
                              'Loading recipe...',
                              style: TextStyle(
                                fontFamily: 'NunitoSans',
                                fontSize: 16,
                                color: Color(0xFF1E3D36),
                              ),
                            ),
                          ],
                        ),
                      )
                    : error != null
                    ? Center(child: Text(error!))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Recipe content with improved styling
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(
                                    0xFF5EAAA8,
                                  ).withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF5EAAA8,
                                    ).withOpacity(0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (recipe!['strMealThumb'] != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image.network(
                                          recipe!['strMealThumb'],
                                          width: double.infinity,
                                          height: 200,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    Text(
                                      recipe!['strMeal'] ?? 'Unknown Recipe',
                                      style: const TextStyle(
                                        fontFamily: 'NunitoSans',
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2D5A54),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Action buttons row with improved styling
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: _toggleFavorite,
                                            icon: Icon(
                                              isFavorited
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            label: Text(
                                              isFavorited ? 'Saved' : 'Save',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontFamily: 'NunitoSans',
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF5EAAA8,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: _navigateToNutriPal,
                                            icon: const Icon(
                                              Icons.calculate,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'Analyze',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontFamily: 'NunitoSans',
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFE91E63,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    // Ingredients section
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF4CAF50,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF4CAF50,
                                          ).withOpacity(0.3),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF4CAF50,
                                                  ).withOpacity(0.15),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.receipt_long,
                                                  size: 16,
                                                  color: Color(0xFF4CAF50),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'Ingredients',
                                                style: TextStyle(
                                                  fontFamily: 'NunitoSans',
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF2D5A54),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          ..._getIngredients().map(
                                            (ing) => Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 2,
                                                  ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          top: 6,
                                                          right: 8,
                                                        ),
                                                    width: 4,
                                                    height: 4,
                                                    decoration:
                                                        const BoxDecoration(
                                                          color: Color(
                                                            0xFF4CAF50,
                                                          ),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      '${ing['measure']} ${ing['ingredient']}',
                                                      style: const TextStyle(
                                                        fontFamily:
                                                            'NunitoSans',
                                                        fontSize: 14,
                                                        color: Color(
                                                          0xFF2D5A54,
                                                        ),
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Instructions section
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF2196F3,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF2196F3,
                                          ).withOpacity(0.3),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF2196F3,
                                                  ).withOpacity(0.15),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.format_list_numbered,
                                                  size: 16,
                                                  color: Color(0xFF2196F3),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'Instructions',
                                                style: TextStyle(
                                                  fontFamily: 'NunitoSans',
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF2D5A54),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          ..._getInstructions().asMap().entries.map(
                                            (entry) => Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 4,
                                                  ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          top: 2,
                                                          right: 12,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF2196F3,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '${entry.key + 1}',
                                                      style: const TextStyle(
                                                        fontFamily:
                                                            'NunitoSans',
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      entry.value,
                                                      style: const TextStyle(
                                                        fontFamily:
                                                            'NunitoSans',
                                                        fontSize: 14,
                                                        color: Color(
                                                          0xFF2D5A54,
                                                        ),
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () => Navigator.pop(context),
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
                                            vertical: 16,
                                          ),
                                        ),
                                        child: const Text(
                                          'Back to Recipes',
                                          style: TextStyle(
                                            fontFamily: 'NunitoSans',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
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
