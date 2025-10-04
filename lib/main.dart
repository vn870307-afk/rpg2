import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rpg/controllers/game_controller.dart';
import 'package:rpg/models/player.dart';
import 'package:rpg/models/story_event.dart';
import 'package:rpg/screens/game_screen.dart';
import 'package:rpg/screens/main_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final Player player = Player();
  final GameController game = GameController(player: Player());

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RPG Demo',
      home: MainScreen(),
    );
  }
}
