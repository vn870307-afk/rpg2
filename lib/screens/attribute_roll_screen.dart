import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:rpg/controllers/game_controller.dart';
import 'package:rpg/models/player.dart';
import 'package:rpg/models/story_event.dart';
import 'package:rpg/screens/game_screen.dart';

class AttributeRollScreen extends StatefulWidget {
  final Function(Player) onPlayerReady;

  const AttributeRollScreen({super.key, required this.onPlayerReady});

  @override
  State<AttributeRollScreen> createState() => _AttributeRollScreenState();
}

class _AttributeRollScreenState extends State<AttributeRollScreen>
    with SingleTickerProviderStateMixin {
  late Player player;
  final Random random = Random();
  bool rolling = false;

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    player = Player(str: 0, vit: 0, intt: 0, dex: 0, cha: 0, luk: 0);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _rollAttributes();
  }

  void _rollAttributes() async {
    if (rolling) return;

    rolling = true;
    int totalPoints = 12;
    int ticks = 0;
    int maxTicks = 2; // 只骰三次

    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      ticks++;

      setState(() {
        // 均衡隨機分配
        List<int> attrs = List.filled(6, 0);
        int remaining = totalPoints;

        for (int i = 0; i < attrs.length; i++) {
          int maxForAttr = remaining - (attrs.length - i - 1); // 保留至少 1 點給剩餘屬性
          attrs[i] = Random().nextInt(maxForAttr + 1);
          remaining -= attrs[i];
        }

        // 剩餘點隨機加回屬性
        while (remaining > 0) {
          int idx = Random().nextInt(attrs.length);
          attrs[idx]++;
          remaining--;
        }

        // 更新玩家屬性
        player.str = attrs[0];
        player.vit = attrs[1];
        player.intt = attrs[2];
        player.dex = attrs[3];
        player.cha = attrs[4];
        player.luk = attrs[5];
        // 新增：擲完骰子後，hp 直接回滿最大血量
        player.hp = player.maxhp;
      });

      _controller.forward(from: 0);

      if (ticks >= maxTicks) {
        timer.cancel();
        rolling = false;
      }
    });
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("擲骰分配基礎能力值", style: TextStyle(color: Colors.black)),
        backgroundColor: const Color.fromARGB(255, 200, 190, 180), // 稍深灰米色
        elevation: 2,
      ),
      backgroundColor: const Color.fromARGB(255, 230, 224, 224),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  "你的基礎能力值分配如下：",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _buildAnimatedAttribute("力量 (STR)", player.str),
                _buildAnimatedAttribute("堅毅 (VIT)", player.vit),
                _buildAnimatedAttribute("智力 (INT)", player.intt),
                _buildAnimatedAttribute("敏捷 (DEX)", player.dex),
                _buildAnimatedAttribute("魅力 (CHA)", player.cha),
                _buildAnimatedAttribute("幸運 (LUK)", player.luk),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _rollAttributes,
                      child: const Text("重新擲骰"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (!rolling) widget.onPlayerReady(player);
                      },
                      child: const Text("確認"),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedAttribute(String name, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontSize: 16)),
          ScaleTransition(
            scale: _animation,
            child: Text(
              value.toString(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
