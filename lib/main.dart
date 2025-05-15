// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/user_profile_service.dart'; 
import 'screens/role_selection_screen.dart';
import 'screens/auth/auth_options_screen.dart';
import 'screens/auth/login_screen.dart';    
import 'screens/auth/signup_screen.dart';   
import 'screens/official/official_login_screen.dart';
import 'screens/official/official_signup_screen.dart';
import 'screens/official/official_details_entry_screen.dart';
import 'screens/official/official_set_password_screen.dart';
import 'screens/official/official_dashboard_screen.dart'; 
import 'screens/main_app_scaffold.dart'; 
import 'screens/public_dashboard_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 
  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<UserProfileService>(create: (_) => UserProfileService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    TextTheme defaultTextTheme = Theme.of(context).textTheme;
    TextTheme appTextTheme = defaultTextTheme.copyWith(
      displayLarge: defaultTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black),
      displayMedium: defaultTextTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black),
      headlineMedium: defaultTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: Colors.black, fontSize: 26), 
      headlineSmall: defaultTextTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.black, fontSize: 22), 
      titleLarge: defaultTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.black, fontSize: 20),    
      bodyLarge: defaultTextTheme.bodyLarge?.copyWith(color: Colors.black87, fontSize: 16),
      bodyMedium: defaultTextTheme.bodyMedium?.copyWith(color: Colors.black54, fontSize: 14), 
      labelLarge: defaultTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white),
    );

    return MaterialApp(
      title: 'Nivaran',
      theme: ThemeData(
        primaryColor: Colors.black, 
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0, 
          iconTheme: const IconThemeData(color: Colors.black, size: 20), // Standardize icon size
          titleTextStyle: appTextTheme.titleLarge?.copyWith(fontSize: 18), // Slightly smaller AppBar title
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            textStyle: appTextTheme.labelLarge?.copyWith(letterSpacing: 0.5, color: Colors.white),
            minimumSize: const Size(double.infinity, 50), // PDF buttons are slightly less tall
            padding: const EdgeInsets.symmetric(vertical: 12), 
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0), 
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            textStyle: appTextTheme.labelLarge?.copyWith(color: Colors.black),
            minimumSize: const Size(double.infinity, 50),
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: Colors.black, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          )
        ),
        inputDecorationTheme: InputDecorationTheme(
           hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
           filled: true,
           fillColor: Colors.grey[100], 
           contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0), 
           border: OutlineInputBorder(
             borderRadius: BorderRadius.circular(8.0), // Less rounded for text fields
             borderSide: BorderSide(color: Colors.grey[300]!, width: 1.0),
           ),
           enabledBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(8.0),
             borderSide: BorderSide(color: Colors.grey[300]!, width: 1.0),
           ),
           focusedBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(8.0),
             borderSide: const BorderSide(color: Colors.black, width: 1.5), 
           ),
           errorBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(8.0),
             borderSide: BorderSide(color: Colors.red.shade600, width: 1.0),
           ),
           focusedErrorBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(8.0),
             borderSide: BorderSide(color: Colors.red.shade600, width: 1.5),
           ),
           prefixIconColor: Colors.grey[700], // Default color for prefix icons if used
        ),
        textTheme: appTextTheme,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal).copyWith(
          secondary: Colors.teal, // Using teal as accent more consistently
          surface: Colors.white,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const InitialAuthCheck(),
      routes: {
        '/role_selection': (context) => const RoleSelectionScreen(),
        '/auth_options': (context) {
           final args = ModalRoute.of(context)!.settings.arguments as String?;
           return AuthOptionsScreen(userType: args ?? 'citizen');
        },
        
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),

        '/official_login': (context) => const OfficialLoginScreen(),
        '/official_signup': (context) => const OfficialSignupScreen(),
        '/official_details_entry': (context) => const OfficialDetailsEntryScreen(),
        '/official_set_password': (context) => const OfficialSetPasswordScreen(),
        '/official_dashboard':(context) => const OfficialDashboardScreen(),

        '/app': (context) => const MainAppScaffold(), 
        
        '/public_dashboard': (context) => const PublicDashboardScreen(),
      },
    );
  }
}

class InitialAuthCheck extends StatelessWidget {
  const InitialAuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
        return Consumer<UserProfileService>(
      builder: (context, userProfileService, child) {
        final authUser = FirebaseAuth.instance.currentUser;

        if (userProfileService.isLoadingProfile && authUser != null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator(semanticsLabel: "Loading session...")));
        }
        if (userProfileService.currentUserProfile != null && authUser != null) {
       
          if (userProfileService.currentUserProfile!.isOfficial) {
            return const OfficialDashboardScreen();
          }
          return const MainAppScaffold(); // Citizen
        }
        
        return const RoleSelectionScreen();
      },
    );
  }
}