# Fridge & Pantry - Project Report

**Course:** Application Development 2: Final Project Report  
**Date:** September 9, 2025  
**Team Members:**
- Rishard Gulam
- Melissa Bangloy
- Manar Najem

## Project Aim and Description

Fridge & Pantry is a mobile application developed in Flutter that helps users manage their kitchen inventory and discover recipes based on available ingredients. The app combines pantry management with recipe discovery, nutrition tracking with AI, and local grocery store location services to create a comprehensive kitchen companion according to your location.

The primary aim is to reduce food waste by helping users track ingredients and find recipes that utilize what they already have, while providing nutritional insights and convenient grocery shopping options. Our application addresses the common problem of food waste in households by providing an intelligent solution that maximizes the use of existing ingredients while promoting healthy eating habits.


## Functional Requirements

### 1. User Authentication
- User registration and login via email/password with password visibility toggle
- Google Sign-In integration 
- Secure user session management
- Profile management with user information editing capabilities
- Account deletion functionality with password confirmation

### 2. Ingredient Management
- Add ingredients to pantry/fridge inventory with dynamic database storage
- Track ingredient quantities 
- Real-time pantry list updates across all screens
- Remove and modify ingredient entries

### 3. Recipe Discovery
- Generate recipes based on available pantry ingredients using external API
- Recipe mixer functionality that matches pantry items with available recipes
- Sort recipe results based on number of matched ingredients
- "Surprise Me" feature that displays random recipes
- Save favorite recipes with toggle functionality
- View detailed recipe instructions and nutritional information
- Link recipes directly to NutriPal for nutritional analysis

### 4. Nutrition Tracking (NutriPal)
- Analyze nutritional content of meals Using AI
- Track dietary preferences and restrictions by simply asking your NutriPal
- Provide health-focused recipe recommendations accordingly
- Integration with recipe viewer for seamless nutrition analysis
- Your personal AI Nutritionist 

### 5. Location Services
- Find nearby grocery stores and restaurants using Google Maps API
- Check box functionality to allow users to choose between ingredient shopping or dining out or order take away from the surrounding restaurant
- Location-based shopping and dining recommendations
- Google Address API integration for user profile management

### 6. User Interface & Settings
- Customize app preferences and manage account settings
- Uniform design language with modern Flutter components
- Responsive navigation flow across 10+ screens
- Consistent UI/theme across all screens (Settings, Add Ingredients, Recipe Mixer, Recipe Viewer, Saved Recipes)


## Non-Functional Requirements

### Security
- Firebase Authentication for secure user data management
- Encrypted data transmission
- Secure API key management using environment variables
- Password protection for sensitive operations like account deletion

### Usability
- Intuitive user interface with consistent design language
- Responsive design for various screen sizes
- Accessibility features for diverse users
- Clear navigation flow

### Performance
- Asynchronous API calls with proper threading for smooth user experience
- Real-time database updates using Firebase Realtime Database
- Efficient ingredient matching algorithms for recipe discovery
- Optimized image loading and caching


## User Stories

### As a home cook, I want to:
- Track ingredients in my pantry so I know what I have available for cooking
- Find recipes using my existing ingredients to avoid food waste
- Save recipes I like for future reference and easy access
- Get nutritional information about my meals to make informed dietary choices 

### As a busy parent, I want to:
- Quickly see what ingredients I need to buy during grocery trips
- Find healthy recipes for my family
- Locate nearby grocery stores when shopping
- Plan meals based on available ingredients to save time and money
- Get surprise recipe suggestions when I'm out of ideas

### As a health-conscious user, I want to:
- Track the nutritional value of my meals 
- Monitor my eating habits over time
- Get recommendations for healthier alternatives
- Analyze the nutritional content of any recipe before cooking with NutriPal

### As a budget-conscious shopper, I want to:
- Use ingredients I already own before buying new ones to reduce waste
- Find stores with competitive prices nearby using location services
- Reduce food waste by prioritizing recipes with expiring ingredients
- Plan meals efficiently to minimize grocery trips


## Test Cases

### Authentication Testing

#### User Registration
- ✅ Test successful registration with email and password  
- ✅ Verify password visibility toggle functionality

#### User Login
- ✅ Test successful login with valid credentials
- ✅ Test login with invalid credentials 

### Ingredient Management Testing

#### Add Ingredients
- ✅ Test adding new ingredients to pantry 
- ✅ Verify real-time database updates 

#### Pantry List Management
- ✅ Test dynamic pantry list updates across screens
- ✅ Verify ingredient removal functionality
- ✅ Test pantry data persistence

### Recipe Discovery Testing

#### Recipe Mixer
- ✅ Test recipe generation based on available ingredients
- ✅ Verify recipe sorting by ingredient match count
- ✅ Test "Surprise Me" random recipe functionality
- ✅ Verify API integration and error handling

#### Recipe Management
- ✅ Test save/unsave recipe toggle functionality
- ✅ Verify saved recipes persistence
- ✅ Test recipe viewer with detailed instructions
- ✅ Test navigation between recipe screens

### Location Services Testing

#### Google Maps Integration
- ✅ Test nearby store and restaurant discovery
- ✅ Verify location permissions handling
- ✅ Test address API integration for user profiles
- ✅ Verify map functionality and store listings

### UI/UX Testing

#### Navigation Flow
- ✅ Test navigation between all 10+ screens
- ✅ Verify consistent UI theme across all screens


## Individual Roles and Responsibilities 

### Manar Najem (Manar Najem)
**Screens:** Welcome, Login, Register, Main Menu (Screens 1-4)

**Primary Contributions:**
- Created initial project structure with screens/ and assets/ folders, custom fonts, and app logo
- Implemented Welcome Screen with gradient background, frosted glass effects, and navigation buttons
- Developed Login and Register screens with Firebase Authentication and Google Sign-In integration
- Built Main Menu with personalized user greetings, logout functionality, and navigation to all app features
- Established foundational UI design patterns using Pacifico and NunitoSans fonts with consistent theming

**Technical Skills Demonstrated:**
- Flutter project architecture and UI foundation
- Firebase Authentication integration
- Custom UI components with gradient and glass effects
- Navigation flow establishment

### Melissa Bangloy  (melissa0987)
**Screens:** Settings, Add Ingredients, Recipe Mixer, Recipe Viewer (Screens 5-7)

**Primary Contributions:**
- Built comprehensive Settings Screen with profile editing, two-step account deletion, and Firebase integration
- Created Add Ingredients system with smart grid selection, custom input validation, and pantry management
- Developed Recipe Mixer with TheMealDB API integration, smart ingredient matching algorithms, and recipe deduplication
- Implemented Recipe Viewer with instruction processing, rich visual layouts, and comprehensive error handling
- Established complete recipe discovery workflow from ingredient selection to detailed recipe display

**Technical Skills Demonstrated:**
- API integration and data processing
- Complex UI state management
- Algorithm development for ingredient matching
- Robust error handling and user experience optimization

### Rishard Gulam (rmrishard)
**Screens:** NutriPal, Shop Around, Firebase Backend (Screens 8-10)

**Primary Contributions:**
- Established complete Firebase backend with Realtime Database, hosting, and automated deployment pipeline
- Built NutriPal AI chat interface with DeepSeek API integration, dynamic messaging, and auto-scroll functionality
- Developed Shop Around location services with Google Maps API, postal code validation, and dynamic search filters
- Set up GitHub Actions for CI/CD, environment configuration, and production deployment
- Created comprehensive backend architecture supporting real-time data synchronization across all app features

**Technical Skills Demonstrated:**
- Backend architecture and database design
- AI API integration and chat interfaces
- Location services and Google Maps integration
- DevOps and automated deployment systems


## Team Collaboration Summary 

### Key Collaborative Efforts:
- All three members contributed to the authentication system from different angles (backend, frontend, and integration)
- Consistent communication through commit messages and merge conflict resolution
- Clear separation of responsibilities that leveraged each member's strengths
- Successful integration of individual components into a cohesive application


## Technical Implementation Highlights

### Architecture
- **Frontend:** Flutter framework for cross-platform mobile development
- **Backend:** Firebase Authentication and Realtime Database
- **APIs:** TheMealDB API, Google Maps API, Google Address API
- **State Management:** Flutter's built-in state management with real-time database synchronization

### Key Features Implemented
- **Complete Navigation Flow:** 10+ interconnected screens with consistent theming
- **API Integration:** Asynchronous JSON parsing with proper error handling and threading
- **Location Services:** Google Maps integration with place detection and address services
- **Real-time Database:** Firebase Realtime Database for dynamic data synchronization


## Conclusion

The Fridge & Pantry application successfully meets all the requirements of Deliverable 2, providing a comprehensive kitchen management solution. Our team effectively collaborated to create a feature-rich mobile application that addresses real-world problems of food waste and meal planning. The application demonstrates proficiency in modern mobile development practices, API integration, database management, and user experience design.

The project showcases our collective skills in Flutter development, Firebase integration, API consumption, and modern software development practices. Each team member contributed their unique expertise to create a polished, functional application that provides genuine value to users looking to optimize their kitchen management and reduce food waste.