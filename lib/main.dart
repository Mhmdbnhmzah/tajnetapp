import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/services/notification_service.dart';
import 'core/theme/theme.dart';
import 'features/admin/views/admin_dashboard_screen.dart';
import 'features/admin/viewmodels/admin_viewmodel.dart';
import 'features/auth/viewmodels/auth_viewmodel.dart';
import 'features/auth/views/account_auth_screen.dart';
import 'features/store/views/main_user_dashboard.dart';
import 'features/store/viewmodels/store_viewmodel.dart';
import 'firebase_options.dart';

import 'core/widgets/force_update_screen.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Firebase Cloud Messaging in background (non-blocking offline)
  NotificationService().initialize().catchError((e) {
    debugPrint('NotificationService init error (ignored offline): $e');
  });

  // ✅ Disable all debugPrint logs in production builds to prevent data leaks
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Apply the Tajawal font globally
  GoogleFonts.config.allowRuntimeFetching = true;
  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const TajNetApp());
}

class TajNetApp extends StatelessWidget {
  const TajNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => StoreViewModel()),
        ChangeNotifierProvider(create: (_) => AdminViewModel()),
      ],
      child: MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        title: 'شبكة تاج نت',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        // RTL Support for Arabic
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ar', 'SA'), // Arabic
        ],
        locale: const Locale('ar', 'SA'),
        home: const ForceUpdateGate(child: AuthWrapper()),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        // Mandatory Check: User MUST be logged into a Firebase Account first
        if (!authViewModel.isAppUserLoggedIn) {
          return const AccountAuthScreen();
        }

        // If user is Admin -> Direct to Admin Dashboard
        if (authViewModel.isAdmin) {
          return const AdminDashboardScreen();
        }

        // Regular User Flow: Main User Dashboard with Store as first tab
        return const MainUserDashboard();
      },
    );
  }
}
