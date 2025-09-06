import 'dart:convert';
import 'package:http/http.dart' as http;

class MealApiService {
  static const String _baseUrl = "https://www.themealdb.com/api/json/v1/1";

  // Fetch all available ingredients from the API
  static Future<List<String>> fetchAllIngredients() async {
    final response = await http.get(Uri.parse('$_baseUrl/list.php?i=list'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List ingredients = data['meals'] ?? [];

      return ingredients
          .map<String>((item) {
            return item['strIngredient'] ?? '';
          })
          .where((ingredient) => ingredient.isNotEmpty)
          .toList();
    } else {
      throw Exception("Failed to load ingredients");
    }
  }

  //
  static Future<List<String>> fetchCommonIngredients() async {
    final allIngredients = await fetchAllIngredients();
    return allIngredients.take(30).toList();
  }

  // Search for ingredients by name
  static Future<List<String>> searchIngredients(String query) async {
    final allIngredients = await fetchAllIngredients();
    return allIngredients
        .where(
          (ingredient) =>
              ingredient.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }
}
