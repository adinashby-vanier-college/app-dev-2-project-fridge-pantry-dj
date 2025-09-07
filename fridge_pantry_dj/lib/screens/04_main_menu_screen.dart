import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// This screen shows the main menu with buttons to different features
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  User? user;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    // Listen for auth state changes to update user info
    FirebaseAuth.instance.authStateChanges().listen((User? updatedUser) {
      if (mounted) {
        setState(() {
          user = updatedUser;
        });
      }
    });
  }

  //refresh user data
  void _refreshUserData() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      currentUser.reload().then((_) {
        setState(() {
          user = FirebaseAuth.instance.currentUser;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Enhanced background gradient with more sophisticated colors
    final bgGradient = const LinearGradient(
      colors: [
        Color(0xFFF0F9F7), // Very light mint
        Color(0xFFE6F7F1), // Light mint
        Color(0xFFB8E6D3), // Soft green
        Color(0xFF7DD3C0), // Medium teal
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: [0.0, 0.3, 0.7, 1.0],
    );

    // List of menu items with colorful icons and descriptions
    final menuItems = [
      _MenuItem(
        'Add Ingredients',
        Icons.add_circle,
        '/add-ingredients',
        const Color(0xFF4CAF50),
        'Track your pantry',
      ),
      _MenuItem(
        'Recipe Mixer',
        Icons.restaurant_menu,
        '/recipe-mixer',
        const Color(0xFFFF9800),
        'Mix & match recipes',
      ),
      _MenuItem(
        'NutriPal',
        Icons.favorite,
        '/nutripal',
        const Color(0xFFE91E63),
        'Health & nutrition',
      ),
      _MenuItem(
        'Groceries Around You',
        Icons.location_on,
        '/shop-around',
        const Color(0xFF2196F3),
        'Find nearby stores',
      ),
      _MenuItem(
        'Saved Recipes',
        Icons.bookmark,
        '/recipe-saved',
        const Color(0xFF795548),
        'View your saved recipes',
      ),
      _MenuItem(
        'Settings',
        Icons.tune,
        '/settings',
        const Color(0xFF607D8B),
        'App preferences',
      ),
    ];

    Future<void> signOut() async {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Compact header optimized for space
              Container(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    // Enhanced top bar with centered title and right-aligned logout
                    Row(
                      children: [
                        // Left spacer for balance
                        const SizedBox(width: 44),
                        // Centered title
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
                                'Main Menu',
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
                        // Right-aligned logout button with better design
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFE53935).withOpacity(0.1),
                                const Color(0xFFD32F2F).withOpacity(0.15),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE53935).withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE53935).withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                              BoxShadow(
                                color: Colors.white.withOpacity(0.8),
                                blurRadius: 6,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.logout_rounded,
                              color: Color(0xFFD32F2F),
                              size: 20,
                            ),
                            tooltip: 'Sign out',
                            onPressed: signOut,
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Compact welcome message
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
                            user?.displayName != null &&
                                    user!.displayName!.isNotEmpty
                                ? 'Hey, ${user!.displayName}! 👋'
                                : 'Hey there! 👋',
                            style: const TextStyle(
                              fontFamily: 'NunitoSans',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E3D36),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'What would you like to do today?',
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
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Fixed grid layout that fits perfectly on screen
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableHeight = constraints.maxHeight;
                      final itemHeight = (availableHeight - 20) / 3;
                      final itemWidth = (constraints.maxWidth - 8) / 2;
                      final aspectRatio = itemWidth / itemHeight;

                      return GridView.builder(
                        physics:
                            const BouncingScrollPhysics(), // allows scrolling with bounce
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: aspectRatio.clamp(0.75, 1.2),
                        ),
                        itemCount: menuItems.length,
                        itemBuilder: (context, i) {
                          final item = menuItems[i];
                          return AnimatedContainer(
                            duration: Duration(milliseconds: 150 + (i * 75)),
                            child: Material(
                              elevation: 0,
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  if (item.route == '/settings') {
                                    await Navigator.pushNamed(
                                      context,
                                      item.route,
                                    );
                                    _refreshUserData();
                                  } else {
                                    Navigator.pushNamed(context, item.route);
                                  }
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: item.color.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: item.color.withOpacity(0.15),
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
                                  child: LayoutBuilder(
                                    builder: (context, itemConstraints) {
                                      final isCompact =
                                          itemConstraints.maxHeight < 120;
                                      return Padding(
                                        padding: EdgeInsets.all(
                                          isCompact ? 8 : 12,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(
                                                isCompact ? 8 : 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: item.color.withOpacity(
                                                  0.15,
                                                ),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: item.color.withOpacity(
                                                    0.3,
                                                  ),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Icon(
                                                item.icon,
                                                size: isCompact ? 20 : 24,
                                                color: item.color,
                                              ),
                                            ),
                                            SizedBox(height: isCompact ? 6 : 8),
                                            Flexible(
                                              child: Text(
                                                item.title,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontFamily: 'NunitoSans',
                                                  fontSize: isCompact ? 11 : 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(
                                                    0xFF2D5A54,
                                                  ),
                                                  height: 1.1,
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: isCompact ? 2 : 3),
                                            Flexible(
                                              child: Text(
                                                item.description,
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontFamily: 'NunitoSans',
                                                  fontSize: isCompact ? 8 : 9,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(
                                                    0xFF2D5A54,
                                                  ).withOpacity(0.7),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper class to store each menu item's info
class _MenuItem {
  final String title;
  final IconData icon;
  final String route;
  final Color color;
  final String description;

  _MenuItem(this.title, this.icon, this.route, this.color, this.description);
}
