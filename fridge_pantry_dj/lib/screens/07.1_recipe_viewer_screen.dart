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
      setState(() {
        error = 'No recipe ID provided';
        isLoading = false;
      });
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
          setState(() {
            recipe = data['meals'][0];
            isLoading = false;
          });
        } else {
          setState(() {
            error = 'Recipe not found';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          error = 'Failed to load recipe';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error loading recipe: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _checkIfFavorited() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments == null || arguments['recipeId'] == null) return;

    final recipeId = arguments['recipeId'];

    final snapshot = await dbRef
        .child('users/${user.uid}/favorites/$recipeId')
        .get();

    setState(() {
      isFavorited = snapshot.exists;
    });
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to bookmark')),
      );
      return;
    }

    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments == null || arguments['recipeId'] == null) return;

    final recipeId = arguments['recipeId'];

    if (isFavorited) {
      // remove favorite
      await dbRef.child('users/${user.uid}/favorites/$recipeId').remove();
      setState(() {
        isFavorited = false;
      });
    } else {
      // save favorite
      await dbRef.child('users/${user.uid}/favorites/$recipeId').set({
        'recipeId': recipeId,
        'title': recipe!['strMeal'],
        'thumbnail': recipe!['strMealThumb'],
        'timestamp': DateTime.now().toIso8601String(),
      });
      setState(() {
        isFavorited = true;
      });
    }
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
            colors: [Color(0xFFD1E8E5), Color(0xFFA7E9D0), Color(0xFF6BB3A8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
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
                      'Recipe',
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
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (recipe!['strMealThumb'] != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.network(
                                  recipe!['strMealThumb'],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            const SizedBox(height: 16),
                            Text(
                              recipe!['strMeal'] ?? 'Unknown Recipe',
                              style: const TextStyle(
                                fontFamily: 'NunitoSans',
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3D36),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _toggleFavorite,
                                  icon: Icon(
                                    isFavorited
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: Colors.white,
                                  ),
                                  label: Text(isFavorited ? 'Saved' : 'Save'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF5EAAA8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Ingredients',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ..._getIngredients().map(
                              (ing) => Text(
                                '${ing['measure']} ${ing['ingredient']}',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Instructions',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ..._getInstructions().asMap().entries.map(
                              (entry) =>
                                  Text('${entry.key + 1}. ${entry.value}'),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5EAAA8),
                                ),
                                child: const Text('Back to Recipes'),
                              ),
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
