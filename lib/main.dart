import 'package:org_wallet/models/user_login.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/services/connectivity_service.dart';
import 'package:org_wallet/services/membership_validation_service.dart';
import 'package:org_wallet/screens/splash_screen.dart';

import 'package:org_wallet/theme/app_theme.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();
  Hive.registerAdapter(UserLoginAdapter());
  await Hive.openBox<UserLogin>('userLogin');
  runApp(const OrgWalletApp());
}

class OrgWalletApp extends StatelessWidget {
  const OrgWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()..initialize()),
        ChangeNotifierProvider(create: (_) => MembershipValidationService()),
      ],
      child: Builder(
        builder: (context) {
          final mediaQueryData = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQueryData.copyWith(textScaleFactor: 0.8),
            child: MaterialApp(
              title: 'Org Wallet',
              theme: AppTheme.lightTheme,
              themeMode: ThemeMode.light,
              debugShowCheckedModeBanner: false,
              home: const SplashScreen(),
            ),
          );
        },
      ),
    );
  }
}
