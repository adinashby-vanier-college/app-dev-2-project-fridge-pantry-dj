import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class NutripalScreen extends StatefulWidget {
  const NutripalScreen({super.key});

  @override
  State<NutripalScreen> createState() => _NutripalScreenState();
}

class _NutripalScreenState extends State<NutripalScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  Map<String, dynamic>? _recipeData;
  bool _hasInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized) {
      _initializeScreen();
      _hasInitialized = true;
    }
  }

  void _initializeScreen() {
    final arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments is Map<String, dynamic> &&
        arguments['fromRecipeViewer'] == true) {
      _recipeData = arguments;
      _showRecipeAnalysisOptions();
    } else {
      _showMainMenuOptions();
    }
  }

  void _showRecipeAnalysisOptions() {
    if (_recipeData == null) return;

    final recipeName = _recipeData!['recipeName'] ?? 'Unknown Recipe';

    setState(() {
      _messages.add(
        ChatMessage(
          text:
              'Hi! I see you want to analyze "$recipeName". What would you like to know?',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });

    // Show quick action buttons after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _showQuickActionsForRecipe();
      }
    });
  }

  void _showMainMenuOptions() {
    setState(() {
      _messages.add(
        ChatMessage(
          text:
              'Hello! I\'m NutriPal, your AI nutritionist. How can I help you with your nutrition today?',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });

    // Show general quick action buttons after a short delay
  }

  void _showQuickActionsForRecipe() {
    // This would show quick action buttons for recipe analysis
    // For now, we'll simulate it by adding suggested messages
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? predefinedMessage]) async {
    final message = predefinedMessage ?? _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(text: message, isUser: true, timestamp: DateTime.now()),
      );
      _isLoading = true;
    });

    if (predefinedMessage == null) {
      _messageController.clear();
    }
    _scrollToBottom();

    try {
      final aiResponse = await _getAIResponse(message);

      setState(() {
        _messages.add(
          ChatMessage(
            text: aiResponse,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                'Sorry, there was an error processing your request. Please try again.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  String _buildRecipeContext() {
    if (_recipeData == null) return '';

    final recipeName = _recipeData!['recipeName'] ?? '';
    final ingredientMap =
        _recipeData!['ingredientMap'] as Map<String, String>? ?? {};
    final category = _recipeData!['category'] ?? '';

    String context = 'I am analyzing a recipe called "$recipeName"';
    if (category.isNotEmpty) context += ' (Category: $category)';
    context += '. The ingredients with their quantities are:\n';

    ingredientMap.forEach((ingredient, quantity) {
      context += '- $quantity $ingredient\n';
    });

    return context;
  }

  String _formatIngredientsForCalculation(String userMessage) {
    if (_recipeData == null) {
      return userMessage;
    }

    // Check if message is asking for any nutritional calculation
    final nutritionKeywords = [
      'calorie',
      'nutrition',
      'protein',
      'carb',
      'fat',
      'vitamin',
      'mineral',
      'breakdown',
      'calculate',
    ];
    final lowerMessage = userMessage.toLowerCase();
    bool isNutritionQuery = nutritionKeywords.any(
      (keyword) => lowerMessage.contains(keyword),
    );

    if (!isNutritionQuery) {
      return userMessage;
    }

    final ingredientMap =
        _recipeData!['ingredientMap'] as Map<String, String>? ?? {};

    String enhancedMessage =
        userMessage + '\n\nIngredient details for calculation:\n';
    ingredientMap.forEach((ingredient, quantity) {
      enhancedMessage += '- $quantity $ingredient\n';
    });

    return enhancedMessage;
  }

  String _formatAIResponse(String response) {
    // Normalize line endings
    String formatted = response.replaceAll('\r\n', '\n');

    // Replace common encoding issues
    formatted = formatted
        .replaceAll('â¢', '•')
        .replaceAll('â€¢', '•')
        .replaceAll('âœ"', '✓');

    formatted = formatted.replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '');

    return formatted.trim();
  }

  Future<String> _getAIResponse(String userMessage) async {
    try {
      final String apiKey = dotenv.env['DEEPSEEK_API_KEY'] ?? '';
      const String apiUrl = 'https://api.deepseek.com/chat/completions';

      String systemPrompt = '''You are NutriPal, a nutrition chatbot.

          Rules:
          - Use bullet points starting with "*" for lists
          - Keep responses under 100 words  
          - Use grams only
          - Example format: "Total: 450 calories"
          - Example: "Protein: 20g, Carbs: 30g, Fat: 25g"''';

      String userMessageWithContext = userMessage;
      if (_recipeData != null) {
        systemPrompt +=
            '\n\nYou are analyzing a specific recipe. When calculating nutrition, use exact ingredient quantities provided. Format all ingredient lists and nutritional data with bullet points for easy reading.';
        userMessageWithContext =
            _buildRecipeContext() +
            _formatIngredientsForCalculation(userMessage);
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $apiKey',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'model': 'deepseek-chat',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userMessageWithContext},
          ],
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        String rawResponse =
            data['choices'][0]['message']['content'] ??
            'Sorry, I could not process your request.';
        return _formatAIResponse(rawResponse);
      } else {
        return 'Sorry, there was an error connecting to NutriPal AI. Please try again.';
      }
    } catch (e) {
      return 'Sorry, there was an error processing your request. Please check your internet connection and try again.';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
              // Header section
              Container(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                          Text(
                            _recipeData != null
                                ? 'Recipe Analysis'
                                : 'NutriPal',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF364958),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),

                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Image.asset('assets/nutri.png'),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _recipeData != null
                            ? 'Analyzing "${_recipeData!['recipeName']}" for nutrition'
                            : 'Meet NutriPal - Your personal AI Nutritionist',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF364958),
                        ),
                      ),
                    ),

                    // Quick action buttons for recipe analysis
                    if (_recipeData != null)
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8,
                        ),
                        height: 36,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildQuickActionButton(
                                'Calculate Calories',
                                Icons.calculate,
                                () => _sendMessage(
                                  'Calculate the total calories for this recipe',
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildQuickActionButton(
                                'Nutritional Breakdown',
                                Icons.pie_chart,
                                () => _sendMessage(
                                  'Give me the nutritional breakdown including protein, carbs, and fats',
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildQuickActionButton(
                                'Health Rating',
                                Icons.health_and_safety,
                                () => _sendMessage(
                                  'Rate this recipe\'s healthiness and suggest improvements',
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildQuickActionButton(
                                'Serving Size',
                                Icons.restaurant,
                                () => _sendMessage(
                                  'What should be the ideal serving size for this recipe?',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // chat area
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _messages.length + (_isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length && _isLoading) {
                              return _buildLoadingMessage();
                            }
                            return _buildMessage(_messages[index]);
                          },
                        ),
                      ),
                      _buildMessageInput(),
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

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6BB3A8).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF6BB3A8)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF364958),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(12.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? const Color(0xFF6BB3A8) : Colors.grey[200],
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingMessage() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF6BB3A8),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'NutriPal is thinking...',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: _recipeData != null
                    ? 'Ask about this recipe\'s nutrition...'
                    : 'Ask about nutrition...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Color(0xFF6BB3A8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(
                    color: Color(0xFF6BB3A8),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF6BB3A8),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
