// lib/screens/game_screen.dart

import 'package:flutter/material.dart';
import 'package:rpg/controllers/game_controller.dart';
import 'package:rpg/models/player.dart';
import 'package:rpg/screens/main_screen.dart';
import 'package:rpg/screens/attribute_allocation_screen.dart';
import 'package:rpg/widgets/fillIn_answer_field.dart';
import 'package:rpg/models/battle_log_entry.dart';

class GameScreen extends StatefulWidget {
  final GameController game;
  final Player player;
  final VoidCallback onGameOver;

  const GameScreen({
    super.key,
    required this.game,
    required this.player,
    required this.onGameOver,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  bool loaded = false;
  final ScrollController _logScrollController = ScrollController();

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setOnDeath();
    widget.game.addListener(_handleGameUpdate);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    loaded = true;
  }

  void _handleGameUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
    setState(() {});
  }

  @override
  void dispose() {
    widget.game.removeListener(_handleGameUpdate);
    _logScrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _setOnDeath() {
    widget.game.player.onDeath = () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text("💀 遊戲結束"),
              content: const Text("你的 HP 歸零了！"),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                            FadeTransition(opacity: animation, child: child),
                        transitionDuration: const Duration(milliseconds: 500),
                      ),
                    );
                  },
                  child: const Text("回到主畫面"),
                ),
              ],
            );
          },
        );
      });
    };
  }

  Widget _buildLogEntry(BattleLogEntry entry) {
    final color = entry.getColor();
    final messageWithIcon = entry.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        messageWithIcon,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontFamily: 'KaiTi', // 假設您引入了楷體或水墨風格字體
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final event = widget.game.currentEvent;
    final monster = event.type == "monster" ? widget.game.currentMonster : null;
    final bool hasUnallocatedPoints = widget.player.unallocatedPoints > 0;
        
    // 新增：定義容器寬度常數，方便計算選項寬度
    final double questionContainerWidth = MediaQuery.of(context).size.width * 0.85;
    const double questionContainerPadding = 12.0;


    return Scaffold(
      // 整體背景色調：淡雅的灰白或淺藍綠，模擬宣紙
      backgroundColor: const Color.fromARGB(255, 245, 245, 240), // 淺米白，宣紙色
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ====================== 玩家屬性區 ======================
              Container(
                padding: const EdgeInsets.all(8),
                // 水墨風格的淡雅底色
                color: const Color.fromARGB(255, 220, 225, 230), 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        Text("血量: ${widget.player.hp} / ${widget.player.maxhp}",
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 50, 50, 50))),
                        Text("等級: ${widget.player.lv}",
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 50, 50, 50))),
                        Text("經驗值: ${widget.player.exp}",
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 50, 50, 50))),
                        Text("SAN值: ${widget.player.SAN.toStringAsFixed(1)}%",
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 50, 50, 50))),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        ScaleTransition(
                          scale: hasUnallocatedPoints ? _scaleAnimation : const AlwaysStoppedAnimation(1.0),
                          child: ElevatedButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AttributeAllocationScreen(player: widget.player),
                                ),
                              );
                              setState(() {});
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: const Size(80, 30),
                              backgroundColor:
                                  hasUnallocatedPoints ? const Color.fromARGB(255, 150, 50, 50) : const Color.fromARGB(255, 180, 180, 180), // 暗紅或深灰
                              foregroundColor: Colors.white,
                              elevation: hasUnallocatedPoints ? 8 : 2,
                            ),
                            child: const Text("能力值", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "(剩餘可分配: ${widget.player.unallocatedPoints})",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: hasUnallocatedPoints ? const Color.fromARGB(255, 150, 50, 50) : const Color.fromARGB(255, 50, 50, 50),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ====================== 戰鬥紀錄區 ======================
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 30, 30, 30), // 更深的墨色背景
                  borderRadius: BorderRadius.circular(8), // 圓角可以小一點
                  border: Border.all(color: const Color.fromARGB(255, 100, 100, 100), width: 1), // 細膩的邊框
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8),
                child: AnimatedBuilder(
                  animation: widget.game,
                  builder: (context, _) {
                    return ListView.builder(
                      controller: _logScrollController,
                      itemCount: widget.game.battleLog.length,
                      itemBuilder: (context, index) {
                        return _buildLogEntry(widget.game.battleLog[index]);
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // ====================== 事件區 (Story Event) ======================
              if (event.type == "story") ...[
                Text(event.text ?? "",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 50, 50, 50))),
                const SizedBox(height: 20),
                if (event.options != null && event.options!.isNotEmpty)
                  ...List.generate(event.options!.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ElevatedButton(
                        onPressed: () => setState(() => widget.game.selectStoryOption(i)),
                        // 水墨風格按鈕
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent, // 透明背景
                          foregroundColor: const Color.fromARGB(255, 50, 50, 50), // 墨色文字
                          side: const BorderSide(color: Color.fromARGB(255, 100, 100, 100), width: 1), // 細邊框
                          elevation: 0, // 無陰影
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(event.options![i], style: const TextStyle(fontSize: 14, fontFamily: 'KaiTi')),
                      ),
                    );
                  })
                else
                  ElevatedButton(
                    onPressed: () => setState(() => widget.game.nextEvent()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 120, 120, 120), // 墨色按鈕
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("繼續", style: TextStyle(fontSize: 14, fontFamily: 'KaiTi')),
                  ),
              ] 
              
              // ====================== 事件區 (Monster Event) ======================
              else if (event.type == "monster" && monster != null) ...[
                // 【✨ 水墨風格的怪物卡片】
                Container(
                  width: double.infinity, // 使用定義的寬度
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    // 模擬水墨暈染的漸層
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color.fromARGB(255, 230, 230, 225), // 淺灰白
                        const Color.fromARGB(255, 200, 200, 195), // 較深灰白
                      ],
                    ),
                    // 模擬畫作的邊框與陰影
                    border: Border.all(color: const Color.fromARGB(255, 80, 80, 80), width: 1.5), // 淺墨色邊框
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 5,
                        offset: const Offset(3, 3), 
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(monster.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w900, color: Color.fromARGB(255, 40, 40, 40), fontFamily: 'KaiTi')), // 墨色字體
                        
                        const Divider(height: 20, thickness: 1.5, indent: 30, endIndent: 30, color: Color.fromARGB(255, 150, 150, 150)), // 淺墨線條

                        // ✨ 使用 Wrap/Row 將屬性顯示在一行
                        Wrap(
                          alignment: WrapAlignment.center, // 讓屬性居中顯示
                          spacing: 18, // 屬性之間的水平間距
                          children: [
                            Text("HP: ${monster.hp}", 
                                style: const TextStyle(fontSize: 16, color: Color.fromARGB(255, 60, 120, 60), fontWeight: FontWeight.bold, fontFamily: 'KaiTi')), // 綠色墨
                            
                            Text("ATK: ${monster.atk}", 
                                style: const TextStyle(fontSize: 16, color: Color.fromARGB(255, 60, 60, 120), fontWeight: FontWeight.bold, fontFamily: 'KaiTi')), // 藍色墨
                            
                            Text(
                              "回合: ${monster.turnCounter}",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: monster.turnCounter <= 1 ? FontWeight.w900 : FontWeight.bold,
                                color: monster.turnCounter <= 1 ? const Color.fromARGB(255, 150, 50, 50) : const Color.fromARGB(255, 40, 40, 40), // 鮮紅或墨色
                                fontFamily: 'KaiTi',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),

                // 【✨ 水墨風格的作答區外框 (問題 + 答案/選項)】
                if (event.question != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(questionContainerPadding),
                    decoration: BoxDecoration(
                      // 柔和的宣紙漸層
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.fromARGB(255, 250, 250, 245), // 淺宣紙色
                          Color.fromARGB(255, 240, 240, 230), // 稍深宣紙色
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color.fromARGB(255, 80, 80, 80), width: 1.5), // 墨色邊框
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 5,
                          offset: const Offset(3, 3), 
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // 問題文字
                       
                        
                        // 填空題 (假設 ZiWeiFillInAnswerField 內部也調整了風格)
                        if (event.answerKeys != null && event.answerKeys!.isNotEmpty)
                          ZiWeiFillInAnswerField(
                            event: event,
                            onSubmit: (answer) {
                              widget.game.answerEvent(answer);
                              setState(() {
                                if (widget.game.currentMonster?.isDead ?? false) {
                                  widget.game.nextEvent();
                                } else {
                                  widget.game.assignRandomQuestionToMonster();
                                }
                              });
                            },
                          )
                        
                        // 選擇題 (一行兩選項)
                        else if (event.options != null && event.options!.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: List.generate(event.options!.length, (i) {
                              // 計算每個選項的寬度
                              final buttonWidth =
                                  (questionContainerWidth - questionContainerPadding * 2 - 8) / 2;
                                  
                              return SizedBox(
                                width: buttonWidth,
                                child: ElevatedButton(
                                  onPressed: () {
                                    widget.game.answerEvent(i);
                                    setState(() {
                                      if (widget.game.currentMonster?.isDead ?? false) {
                                        widget.game.nextEvent();
                                      } else {
                                        widget.game.assignRandomQuestionToMonster();
                                      }
                                    });
                                  },
                                  // 水墨風格按鈕
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent, // 透明背景
                                    foregroundColor: const Color.fromARGB(255, 50, 50, 50), // 墨色文字
                                    side: const BorderSide(color: Color.fromARGB(255, 100, 100, 100), width: 1), // 細邊框
                                    elevation: 0, // 無陰影
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text(event.options![i],
                                      style: const TextStyle(fontSize: 12, fontFamily: 'KaiTi'), // 水墨風格字體
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              );
                            }),
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}