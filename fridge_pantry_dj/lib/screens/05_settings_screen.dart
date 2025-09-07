import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static String get _googleApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController postcodeController = TextEditingController();
  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final TextEditingController addressController = TextEditingController();
  String originalAddress = '';
  List<Map<String, dynamic>> _addressSuggestions = [];
  bool _showAddressSuggestions = false;

  String originalName = '';
  String originalEmail = '';
  String originalPostcode = '';

  bool _isEditingInfo = false;
  bool _isChangingPassword = false;
  bool _isLoading = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _showDeletePassword = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      originalName = user.displayName ?? 'User';
      originalEmail = user.email ?? '';

      // Load postcode and address from Firebase
      try {
        final database = FirebaseDatabase.instance;
        final userRef = database.ref('users/${user.uid}');
        final snapshot = await userRef.get();

        if (snapshot.exists) {
          final userData = snapshot.value as Map<dynamic, dynamic>;
          originalPostcode = userData['postcode'] ?? '';
          originalAddress = userData['address'] ?? '';
        }
      } catch (e) {
        originalPostcode = '';
        originalAddress = '';
      }
    } else {
      originalName = 'Hello World';
      originalEmail = 'hello@world.com';
      originalPostcode = '';
      originalAddress = '';
    }

    nameController.text = originalName;
    emailController.text = originalEmail;
    postcodeController.text = originalPostcode;
    addressController.text = originalAddress;

    if (mounted) setState(() {});
  }

  void _toggleEditInfo() {
    setState(() {
      if (_isEditingInfo) {
        nameController.text = originalName;
        emailController.text = originalEmail;
        postcodeController.text = originalPostcode;
        addressController.text = originalAddress;
      }
      _isEditingInfo = !_isEditingInfo;
      _isChangingPassword = false;
      _showAddressSuggestions = false;
    });
  }

  void _toggleChangePassword() {
    setState(() {
      _isChangingPassword = !_isChangingPassword;
      _isEditingInfo = false;

      currentPasswordController.clear();
      newPasswordController.clear();
      confirmPasswordController.clear();
    });
  }

  Future<void> _saveUserInfo() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update display name if changed
        if (nameController.text.trim() != originalName) {
          await user.updateDisplayName(nameController.text.trim());
        }

        // Update email if changed
        if (emailController.text.trim() != originalEmail) {
          await user.verifyBeforeUpdateEmail(emailController.text.trim());
        }

        if (!_isValidCanadianPostalCode(postcodeController.text)) {
          _showErrorMessage('Please enter a valid Canadian postal code.');
          setState(() => _isLoading = false);
          return;
        }

        // Save address and postal code to Firebase
        final database = FirebaseDatabase.instance;
        final userRef = database.ref('users/${user.uid}');
        await userRef.update({
          'address': addressController.text.trim(),
          'postcode': originalPostcode.trim(), // auto-filled postal code
        });

        // Update local originals for future edits
        setState(() {
          originalName = nameController.text.trim();
          originalEmail = emailController.text.trim();
          originalAddress = addressController.text.trim();
          originalPostcode = postcodeController.text.trim();
          _isEditingInfo = false;
          _showAddressSuggestions = false;
        });

        _showSuccessMessage('Profile updated successfully!');
      }
    } on FirebaseAuthException catch (e) {
      _showErrorMessage('Failed to update profile: ${e.message}');
    } catch (e) {
      _showErrorMessage('An error occurred while updating profile');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    if (newPasswordController.text != confirmPasswordController.text) {
      _showErrorMessage('New passwords do not match');
      return;
    }

    if (newPasswordController.text.length < 6) {
      _showErrorMessage('New password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPasswordController.text,
        );
        await user.reauthenticateWithCredential(credential);

        await user.updatePassword(newPasswordController.text);

        setState(() => _isChangingPassword = false);
        currentPasswordController.clear();
        newPasswordController.clear();
        confirmPasswordController.clear();

        _showSuccessMessage('Password changed successfully!');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        _showErrorMessage('Current password is incorrect');
      } else {
        _showErrorMessage('Failed to change password: ${e.message}');
      }
    } catch (e) {
      _showErrorMessage('An error occurred while changing password');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await _showConfirmationDialog(
      'Logout',
      'Are you sure you want to logout?',
    );

    if (shouldLogout) {
      try {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      } catch (e) {
        _showErrorMessage('Failed to logout');
      }
    }
  }

  Future<void> _deleteAccount() async {
    final shouldDelete = await _showConfirmationDialog(
      'Delete Account',
      'Are you sure you want to permanently delete your account? This action cannot be undone.',
      isDestructive: true,
    );
    //Ask password when deleting
    if (shouldDelete) {
      final password = await _showPasswordDialog();
      if (password != null) {
        setState(() => _isLoading = true);
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            // Re-authenticate before deleting
            final credential = EmailAuthProvider.credential(
              email: user.email!,
              password: password,
            );
            await user.reauthenticateWithCredential(credential);

            // Delete user from FBRD
            final database = FirebaseDatabase.instance;
            final userRef = database.ref('users/${user.uid}');
            await userRef.remove();

            await user.delete();

            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            }
          }
        } on FirebaseAuthException catch (e) {
          if (e.code == 'wrong-password') {
            _showErrorMessage('Incorrect password');
          } else {
            _showErrorMessage('Failed to delete account: ${e.message}');
          }
        } catch (e) {
          _showErrorMessage('An error occurred while deleting account');
        } finally {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<bool> _showConfirmationDialog(
    String title,
    String content, {
    bool isDestructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color.fromARGB(255, 235, 253, 251),
            title: Text(
              title,
              style: const TextStyle(
                fontFamily: 'NunitoSans',
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3D36),
              ),
            ),
            content: Text(
              content,
              style: const TextStyle(
                fontFamily: 'NunitoSans',
                color: Color(0xFF1E3D36),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color.fromARGB(255, 146, 148, 148)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  isDestructive ? 'Delete' : 'Confirm',
                  style: TextStyle(
                    color: isDestructive
                        ? Colors.red[700]
                        : const Color.fromARGB(255, 20, 170, 165),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _showPasswordDialog() async {
    final TextEditingController passwordController = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFD1E8E5),
          title: const Text(
            'Enter Password',
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3D36),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter password to delete account:',
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  color: Color(0xFF1E3D36),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: !_showDeletePassword,
                decoration: InputDecoration(
                  hintText: 'Password',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showDeletePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: const Color(0xFF1E3D36),
                    ),
                    onPressed: () {
                      setDialogState(() {
                        _showDeletePassword = !_showDeletePassword;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _showDeletePassword = false;
                Navigator.pop(context);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF5EAAA8)),
              ),
            ),
            TextButton(
              onPressed: () {
                _showDeletePassword = false;
                Navigator.pop(context, passwordController.text);
              },
              child: Text(
                'Confirm',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF5EAAA8),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red[600]),
    );
  }

  Future<List<Map<String, dynamic>>> _getAddressSuggestions(
    String input,
  ) async {
    if (input.length < 3 || _googleApiKey.isEmpty) return [];

    // Get the postal code to use as a filter
    final postcode = postcodeController.text.trim().toUpperCase();
    String searchQuery = input;

    // If postal code is entered, include it in the search for better filtering
    if (postcode.isNotEmpty) {
      searchQuery = '$input, $postcode, Canada';
    } else {
      searchQuery = '$input, Canada';
    }

    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(searchQuery)}'
        '&components=country:ca'
        '&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          List<Map<String, dynamic>> suggestions = predictions
              .map(
                (prediction) => {
                  'description': prediction['description'],
                  'place_id': prediction['place_id'],
                },
              )
              .toList();

          // Filter suggestions by postal code if one is entered
          if (postcode.isNotEmpty) {
            suggestions = suggestions.where((suggestion) {
              final description = suggestion['description']
                  .toString()
                  .toUpperCase();
              return description.contains(postcode);
            }).toList();
          }

          return suggestions;
        }
      }
    } catch (e) {
      debugPrint('Error fetching address suggestions: $e');
    }
    return [];
  }

  void _onAddressChanged(String value) async {
    if (value.length >= 3) {
      final suggestions = await _getAddressSuggestions(value);
      setState(() {
        _addressSuggestions = suggestions;
        _showAddressSuggestions = suggestions.isNotEmpty;
      });
    } else {
      setState(() {
        _addressSuggestions = [];
        _showAddressSuggestions = false;
      });
    }
  }

  Future<String?> _getPostalCodeFromPlaceId(String placeId) async {
    if (_googleApiKey.isEmpty) return null;

    final url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=address_component&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final components = data['result']['address_components'] as List;
        final postalCodeComponent = components.firstWhere(
          (comp) => (comp['types'] as List).contains('postal_code'),
          orElse: () => null,
        );
        if (postalCodeComponent != null) {
          return postalCodeComponent['long_name'] as String;
        }
      }
    } catch (e) {
      debugPrint('Error fetching postal code: $e');
    }
    return null;
  }

  void _selectAddressSuggestion(Map<String, dynamic> suggestion) async {
    // Set the address text
    setState(() {
      addressController.text = suggestion['description'];
      _showAddressSuggestions = false;
      _addressSuggestions = [];
    });

    // Fetch postal code from Google Place API
    final postalCode = await _getPostalCodeFromPlaceId(suggestion['place_id']);
    if (postalCode != null) {
      setState(() {
        originalPostcode = postalCode; // store for saving
        postcodeController.text = postalCode; // display in the UI immediately
      });
      debugPrint('Auto-filled postal code: $postalCode');
    }
  }

  void _onPostcodeChanged(String value) {
    // Clear address suggestions when postal code changes
    setState(() {
      _showAddressSuggestions = false;
      _addressSuggestions = [];
    });

    // If address field has content, refresh suggestions with new postal code
    if (addressController.text.isNotEmpty && value.length >= 6) {
      _onAddressChanged(addressController.text);
    }
  }

  bool _isValidCanadianPostalCode(String postalCode) {
    // Canadian postal code format: A1A 1A1 (with or without space)
    final regex = RegExp(r'^[A-Za-z]\d[A-Za-z]\s?\d[A-Za-z]\d$');
    return regex.hasMatch(postalCode.trim());
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    postcodeController.dispose();
    addressController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

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
              // Enhanced top bar matching MainMenuScreen style
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
                            'Settings',
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
                      // Welcome message matching MainMenuScreen style
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
                            Text(
                              'Hey, ${originalName.isEmpty ? 'User' : originalName}!',
                              style: const TextStyle(
                                fontFamily: 'NunitoSans',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E3D36),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Manage Your Account',
                              style: TextStyle(
                                fontFamily: 'NunitoSans',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF2D5A54).withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // User Information Section
                      if (_isEditingInfo) ...[
                        _buildEditInfoSection(),
                      ] else ...[
                        _buildInfoDisplaySection(),
                      ],

                      const SizedBox(height: 16),

                      // Change Password Section
                      if (_isChangingPassword) ...[
                        _buildChangePasswordSection(),
                      ] else ...[
                        _buildPasswordButton(),
                      ],

                      const SizedBox(height: 20),

                      // Account Actions Section
                      _buildAccountActionsSection(),
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

  Widget _buildInfoDisplaySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF5EAAA8).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5EAAA8).withOpacity(0.15),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF5EAAA8).withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF5EAAA8).withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.person,
                  size: 20,
                  color: Color(0xFF5EAAA8),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Personal Information',
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D5A54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Name', nameController.text),
          _buildInfoRow('Email', emailController.text),
          _buildInfoRow(
            'Address',
            addressController.text.isEmpty
                ? 'Not set'
                : '${addressController.text} ${postcodeController.text.isNotEmpty ? '(${postcodeController.text})' : ''}',
          ),
          _buildInfoRow('Postcode', postcodeController.text),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _toggleEditInfo,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit Information'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5EAAA8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontFamily: 'NunitoSans',
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E3D36),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'NunitoSans',
                color: Color(0xFF1E3D36),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit Personal Information',
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3D36),
            ),
          ),
          const SizedBox(height: 20),

          // Name field
          _buildEditField('NAME', nameController),
          const SizedBox(height: 16),

          // Email field
          _buildEditField('EMAIL', emailController),
          const SizedBox(height: 20),

          // Address field with autocomplete
          const Text(
            'ADDRESS',
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3D36),
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 8),

          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFB8D4E3),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: addressController,
                  onChanged: _onAddressChanged,
                  style: const TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 16,
                    color: Color(0xFF1E3D36),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    hintText: 'Enter your address',
                  ),
                ),
              ),
              if (_showAddressSuggestions && _addressSuggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _addressSuggestions.length > 5
                        ? 5
                        : _addressSuggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _addressSuggestions[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          suggestion['description'],
                          style: const TextStyle(
                            fontFamily: 'NunitoSans',
                            fontSize: 14,
                            color: Color(0xFF1E3D36),
                          ),
                        ),
                        onTap: () => _selectAddressSuggestion(suggestion),
                      );
                    },
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          _buildEditFieldWithCallback('POSTCODE', postcodeController, (value) {
            _onPostcodeChanged(value); // call when user types
          }),
          const SizedBox(height: 16),

          // Save and Cancel buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveUserInfo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5EAAA8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _toggleEditInfo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[400],
                    foregroundColor: const Color(0xFF1E3D36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3D36),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFB8D4E3),
            borderRadius: BorderRadius.circular(25),
          ),
          child: TextField(
            controller: controller,
            onChanged: (value) => setState(() {}),
            style: const TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 16,
              color: Color(0xFF1E3D36),
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditFieldWithCallback(
    String label,
    TextEditingController controller,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3D36),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFB8D4E3),
            borderRadius: BorderRadius.circular(25),
          ),
          child: TextField(
            controller: controller,
            onChanged: (value) {
              setState(() {}); // updates UI if needed
              onChanged(value); // callback
            },
            style: const TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 16,
              color: Color(0xFF1E3D36),
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Security',
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3D36),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _toggleChangePassword,
            icon: const Icon(Icons.lock_outline, size: 18),
            label: const Text('Change Password'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5EAAA8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangePasswordSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Change Password',
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3D36),
            ),
          ),
          const SizedBox(height: 20),

          // Current password field
          _buildPasswordField(
            'CURRENT PASSWORD',
            currentPasswordController,
            fieldType: 'current',
          ),

          // New password field
          _buildPasswordField(
            'NEW PASSWORD',
            newPasswordController,
            fieldType: 'new',
          ),

          // Confirm new password field
          _buildPasswordField(
            'CONFIRM NEW PASSWORD',
            confirmPasswordController,
            fieldType: 'confirm',
          ),
          const SizedBox(height: 20),

          // Change and Cancel buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5EAAA8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Change Password'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _toggleChangePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[400],
                    foregroundColor: const Color(0xFF1E3D36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller, {
    String? fieldType,
  }) {
    bool showPassword = false;
    VoidCallback toggleVisibility = () {};

    // toogle password visibility
    switch (fieldType) {
      case 'current':
        showPassword = _showCurrentPassword;
        toggleVisibility = () =>
            setState(() => _showCurrentPassword = !_showCurrentPassword);
        break;
      case 'new':
        showPassword = _showNewPassword;
        toggleVisibility = () =>
            setState(() => _showNewPassword = !_showNewPassword);
        break;
      case 'confirm':
        showPassword = _showConfirmPassword;
        toggleVisibility = () =>
            setState(() => _showConfirmPassword = !_showConfirmPassword);
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3D36),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFB8D4E3),
            borderRadius: BorderRadius.circular(25),
          ),
          child: TextField(
            controller: controller,
            obscureText: !showPassword,
            style: const TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 16,
              color: Color(0xFF1E3D36),
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  showPassword ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF1E3D36),
                ),
                onPressed: toggleVisibility,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountActionsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Actions',
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3D36),
            ),
          ),
          const SizedBox(height: 16),

          // Logout button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Delete account button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _deleteAccount,
              icon: const Icon(Icons.delete_forever, size: 18),
              label: const Text('Delete Account'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
