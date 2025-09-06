import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class SavedRecipesScreen extends StatefulWidget {
  const SavedRecipesScreen({super.key});

  @override
  State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends State<SavedRecipesScreen> {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> favorites = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    final snapshot = await dbRef.child('users/${user.uid}/favorites').get();

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      favorites = data.entries.map((e) {
        final value = Map<String, dynamic>.from(e.value);
        value['recipeId'] = e.key;
        return value;
      }).toList();
    }

    setState(() {
      isLoading = false;
    });
  }

  void _openRecipe(String recipeId) {
    Navigator.pushNamed(
      context,
      '/recipe-viewer',
      arguments: {'recipeId': recipeId},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Recipes'),
        backgroundColor: const Color(0xFF5EAAA8),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : favorites.isEmpty
          ? const Center(
              child: Text(
                'No saved recipes yet!',
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final recipe = favorites[index];
                return ListTile(
                  leading: recipe['thumbnail'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            recipe['thumbnail'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.restaurant),
                  title: Text(recipe['title'] ?? 'Unknown Recipe'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _openRecipe(recipe['recipeId']),
                );
              },
            ),
    );
  }
}
