import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class PantryService {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Save pantry items to Firebase
  static Future<void> savePantryItems(List<String> pantryItems) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _database.child('users/${user.uid}/pantry').set(pantryItems);
      } catch (e) {
        throw Exception('Failed to save pantry items: $e');
      }
    }
  }

  // Load pantry items from Firebase
  static Future<List<String>> loadPantryItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final snapshot = await _database
            .child('users/${user.uid}/pantry')
            .get();
        if (snapshot.exists) {
          final List<dynamic> items = snapshot.value as List<dynamic>;
          return items.cast<String>();
        }
      } catch (e) {
        throw Exception('Failed to load pantry items: $e');
      }
    }
    return [];
  }
}
