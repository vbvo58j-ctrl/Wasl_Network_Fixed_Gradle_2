import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
void main() => runApp(const WaslApp());
class WaslApp extends StatelessWidget {
  const WaslApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'وصل - شبكة محلية', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff087f8c))),
    home: const HomeScreen(),
  );
}