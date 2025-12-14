import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Open box for books (using Map storage)
  await Hive.openBox('books');
  
  runApp(
    const ProviderScope(
      child: EbookReaderApp(),
    ),
  );
}
