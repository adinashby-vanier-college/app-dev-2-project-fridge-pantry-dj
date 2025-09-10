import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ShopAroundScreen extends StatefulWidget {
  const ShopAroundScreen({super.key});

  @override
  State<ShopAroundScreen> createState() => _ShopAroundScreenState();
}

class _ShopAroundScreenState extends State<ShopAroundScreen> {
  final TextEditingController _postalCodeController = TextEditingController();
  List<Map<String, dynamic>> _places = [];
  bool showGroceries = true;
  bool showRestaurants = true;
  int selectedRadius = 2000;
  bool _isLoading = false;
  String? _errorMessage;

  // google map api (remove before git add) also implement .env
  static String get _googleApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
  }

  Future<void> _searchPlaces() async {
    final postalCode = _postalCodeController.text.trim();
    if (postalCode.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your postal code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _places = [];
    });

    try {
      // POSTCODE
      final coordinates = await _geocodePostalCode(postalCode);
      if (coordinates == null) {
        setState(() {
          _errorMessage = 'Invalid postal';
          _isLoading = false;
        });
        return;
      }

      final List<Map<String, dynamic>> allPlaces = [];

      // Groceru checker
      if (showGroceries) {
        final groceries = await _searchNearbyPlaces(
          coordinates['lat'],
          coordinates['lng'],
          'grocery_or_supermarket',
        );
        allPlaces.addAll(groceries);
      }

      // Restaurant CHeker
      if (showRestaurants) {
        final restaurants = await _searchNearbyPlaces(
          coordinates['lat'],
          coordinates['lng'],
          'restaurant',
        );
        allPlaces.addAll(restaurants);
      }

      setState(() {
        _places = allPlaces;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching places: $e';
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _geocodePostalCode(String postalCode) async {
    final encodedPostalCode = Uri.encodeComponent(postalCode);
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=$encodedPostalCode&components=country:CA'
        '&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      debugPrint('Geocoding URL: $url');
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return {'lat': location['lat'], 'lng': location['lng']};
        } else {
          debugPrint('Geocoding failed. Status: ${data['status']}');
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _searchNearbyPlaces(
    double lat,
    double lng,
    String type,
  ) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=$lat,$lng'
        '&radius=$selectedRadius'
        '&type=$type'
        '&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Map<String, dynamic>> places = [];

        if (data['status'] == 'OK') {
          final results = data['results'] as List;

          for (int i = 0; i < results.length && i < 15; i++) {
            final place = results[i];
            places.add({
              'name': place['name'] ?? 'Unknown Place',
              'rating': place['rating']?.toDouble() ?? 0.0,
              'vicinity': place['vicinity'] ?? '',
              'type': type == 'grocery_or_supermarket'
                  ? 'Grocery'
                  : 'Restaurant',
              'place_id': place['place_id'],
              'price_level': place['price_level'] ?? 0,
            });
          }
        }
        return places;
      } else {
        debugPrint('Places API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error calling Places API: $e');
      return [];
    }
  }

  void _onCheckboxChanged(String type, bool value) {
    setState(() {
      if (type == 'groceries') showGroceries = value;
      if (type == 'restaurants') showRestaurants = value;
    });
  }

  @override
  void dispose() {
    _postalCodeController.dispose();
    super.dispose();
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
              // App Bar
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
                      'Shop Around',
                      style: TextStyle(
                        fontFamily: 'Pacifico',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3D36),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Postal UI area Input
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _postalCodeController,
                  decoration: InputDecoration(
                    labelText: 'Enter Postal Code',
                    hintText: 'e.g., H3H 2N8',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.8),
                    suffixIcon: IconButton(
                      onPressed: _searchPlaces,
                      icon: const Icon(Icons.search),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Text(
                      'Radius: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<int>(
                      value: selectedRadius,
                      onChanged: (value) {
                        setState(() {
                          selectedRadius = value!;
                        });
                      },
                      items: const [
                        DropdownMenuItem(value: 1000, child: Text('1 km')),
                        DropdownMenuItem(value: 2000, child: Text('2 km')),
                        DropdownMenuItem(value: 5000, child: Text('5 km')),
                        DropdownMenuItem(value: 10000, child: Text('10 km')),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: showGroceries,
                      onChanged: (value) =>
                          _onCheckboxChanged('groceries', value!),
                    ),
                    const Text('Groceries'),
                    const SizedBox(width: 16),
                    Checkbox(
                      value: showRestaurants,
                      onChanged: (value) =>
                          _onCheckboxChanged('restaurants', value!),
                    ),
                    const Text('Restaurants'),
                  ],
                ),
              ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Searching nearby places...'),
                          ],
                        ),
                      )
                    : _places.isEmpty
                    ? const Center(
                        child: Text('No places found. Try New postal code.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _places.length,
                        itemBuilder: (context, index) {
                          final place = _places[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: place['type'] == 'Grocery'
                                    ? Colors.green
                                    : Colors.orange,
                                child: Icon(
                                  place['type'] == 'Grocery'
                                      ? Icons.shopping_cart
                                      : Icons.restaurant,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                place['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(place['vicinity']),
                                  Row(
                                    children: [
                                      Text('${place['type']} • '),
                                      if (place['rating'] > 0) ...[
                                        const Icon(
                                          Icons.star,
                                          size: 16,
                                          color: Colors.amber,
                                        ),
                                        Text(
                                          ' ${place['rating'].toStringAsFixed(1)}',
                                        ),
                                      ] else
                                        const Text('No rating'),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: place['price_level'] > 0
                                  ? Text('\$' * place['price_level'])
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
