import 'package:flutter/material.dart';
import 'package:rpg/controllers/game_controller.dart';
import 'package:rpg/models/player.dart';
import 'package:rpg/screens/game_screen.dart';
import 'package:rpg/screens/attribute_roll_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late GameController game;
  late Player player;
  bool started = false; // 防止重複 push

  @override
  void initState() {
    super.initState();
    // 確保 build 完再開始遊戲
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!started) {
        started = true;
        _startNewGame();
      }
    });
  }

  void _startNewGame() {
    player = Player();
    game = GameController(player: player);

    // 推骰子畫面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttributeRollScreen(
          onPlayerReady: (rolledPlayer) async {
            player = rolledPlayer;
            game.player = player;

            // 載入章節
            await game.loadChapter('assets/chapters/chapter1/index.json');

            if (!mounted) return;

            // 開啟 GameScreen
            _openGameScreen();
          },
        ),
      ),
    );
  }

  void _openGameScreen() {
    // 使用 pushReplacement，避免返回後又回到 MainScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          game: game,
          player: player,
          onGameOver: () {
            // 遊戲死亡後重啟 MainScreen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainScreen()),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("RPG Demo")),
      body: const Center(
        child: Text("歡迎來到 RPG Demo！"),
      ),
    );
  }
}
