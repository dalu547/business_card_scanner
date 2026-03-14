import 'package:flutter/material.dart';
import 'models/card_contact.dart';
import 'screens/home_screen.dart';

class BusinessCardScannerApp extends StatefulWidget {
  const BusinessCardScannerApp({super.key});

  @override
  State<BusinessCardScannerApp> createState() => _BusinessCardScannerAppState();
}

class _BusinessCardScannerAppState extends State<BusinessCardScannerApp> {
  final List<CardContact> _contacts = <CardContact>[];

  void addContact(CardContact contact) {
    setState(() {
      _contacts.insert(0, contact);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Business Card Scanner Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: HomeScreen(
        contacts: _contacts,
        onSaveContact: addContact,
      ),
    );
  }
}
