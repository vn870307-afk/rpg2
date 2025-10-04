// lib/screens/game_screen.dart

import 'package:flutter/material.dart';
import 'package:rpg/controllers/game_controller.dart';
import 'package:rpg/models/player.dart'; 
import 'package:rpg/screens/main_screen.dart';
import 'package:rpg/screens/attribute_allocation_screen.dart';
import 'package:rpg/widgets/fillIn_answer_field.dart';
import 'package:rpg/models/battle_log_entry.dart'; // <-- 【新增】

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
  
  // 【動畫控制器和動畫】
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  // ===== 戰鬥紀錄顏色規則 (已移除舊的 Map 和 getLogColor) =====
  
  // 【新增結構化 Log Widget 構建函式】
  Widget _buildLogEntry(BattleLogEntry entry) {
    final color = entry.getColor(); // 使用模型內部定義的顏色
    final messageWithIcon = entry.toString(); // 使用模型內部定義的圖示 + 訊息

    // 如果是「答對」或「答錯」 Log，我們可以在旁邊添加「詳解」按鈕
    if (entry.type == LogType.correctAnswer || entry.type == LogType.incorrectAnswer) {
      // 這裡您可以根據需要添加「詳解」彈窗，但由於您沒有提供完整的題目資料，
      // 我暫時先用統一的 Log 格式，未來您可以擴展這個邏輯來處理詳解。
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        messageWithIcon,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
    );
  }


  @override
  void initState() {
    super.initState();
    _setOnDeath();
    widget.game.addListener(_handleGameUpdate);
    
    // 【初始化動畫控制器】
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true); 

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    loaded = true;
  }
  
  void _handleGameUpdate() {
    // 確保日誌滾動在畫面更新後發生
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
    // 【釋放動畫資源】
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
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(opacity: animation, child: child);
                        },
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
  
  // 【輔助方法：建構屬性文字，比較最終值與理想基礎值】
  Widget _buildStatText(String name, num currentValue, num idealBaseValue, {bool isPercent = false}) {
    final diff = (currentValue - idealBaseValue); 
    
    // 確保差異值顯示為 0.0 時不顯示括號
    if (diff.abs() < 0.01) {
      return Text(
        "$name: ${currentValue.toStringAsFixed(1)}${isPercent ? '%' : ''}",
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      );
    }
    
    final sign = diff >= 0 ? '+' : '';
    final diffText = ' ($sign${diff.toStringAsFixed(1)})';
    
    // 決定顏色 (正增益綠色，負懲罰紅色)
    Color diffColor;
    if (diff > 0) {
      diffColor = Colors.green;
    } else if (diff < 0) {
      // 負數值（例如 SAN 懲罰/Debuff）顯示為紅色
      diffColor = Colors.red;
    } else {
      diffColor = const Color.fromARGB(159, 104, 97, 1);
    }

    return Text.rich(
      TextSpan(
        text: "$name: ${currentValue.toStringAsFixed(1)}${isPercent ? '%' : ''}",
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        children: [
          TextSpan(
            text: diffText,
            style: TextStyle(color: diffColor, fontSize: 12),
          ),
        ],
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
    const double battleLogHeight = 250.0 + 32.0; 
    
    // 【計算是否有未分配點數】
    final bool hasUnallocatedPoints = widget.player.unallocatedPoints > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("RPG Demo", style: TextStyle(color: Colors.black,fontSize: 16,)),
        backgroundColor: const Color.fromARGB(255, 200, 190, 120),
        elevation: 2,
        toolbarHeight: 40.0, 
      ),
      backgroundColor: const Color.fromARGB(255, 230, 224, 224),
      body: Stack(
        children: [
          // 1. 【主內容區塊】
          Positioned.fill(
            bottom: battleLogHeight, 
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 玩家屬性區
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: const Color.fromARGB(255, 212, 193, 165),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 頂部資訊 (血量、等級、經驗值)
                              Wrap(
                                spacing: 16,
                                runSpacing: 4,
                                children: [
                                  Text("血量: ${widget.player.hp} / ${widget.player.maxhp}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  Text("等級: ${widget.player.lv}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  Text("經驗值: ${widget.player.exp}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8), 

                              // 【✨ 戰鬥能力值 (已修正：使用正確的理想基礎值進行比較)】
                              Wrap(
                                spacing: 16,
                                runSpacing: 4,
                                children: [
                                  // 攻擊
                                  _buildStatText("攻擊", widget.player.atk, widget.player.getUnmodifiedAtk()),
                                  // 防禦
                                  _buildStatText("防禦", widget.player.def, widget.player.getUnmodifiedDef()),
                                  // 迴避率
                                  _buildStatText("迴避率", widget.player.agi, widget.player.getUnmodifiedAgi(), isPercent: true),
                                  // 暴擊率
                                  _buildStatText("暴擊率", widget.player.ct, widget.player.getUnmodifiedCt(), isPercent: true),
                                  // 速度
                                  _buildStatText("速度", widget.player.spd, widget.player.getUnmodifiedSpd(), isPercent: true),
                                  // 洞察力
                                  _buildStatText("洞察力", widget.player.ins, widget.player.getUnmodifiedIns(), isPercent: true),
                                  // 特殊事件
                                  _buildStatText("特殊事件", widget.player.SupportEvent, widget.player.getUnmodifiedSupportEvent(), isPercent: true),
                                  // SAN值不需要顯示變化
                                  Text("SAN值: ${widget.player.SAN.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              
                              const SizedBox(height: 5),
                              
                              // 【分配能力點按鈕區 - 帶動畫提醒】
                              Row(
                                children: [
                                  ScaleTransition(
                                    scale: hasUnallocatedPoints ? _scaleAnimation : const AlwaysStoppedAnimation(1.0),
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => AttributeAllocationScreen(player: widget.player)),
                                        );
                                        setState(() {});
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                                        minimumSize: const Size(80, 30), 
                                        backgroundColor: hasUnallocatedPoints ? Colors.deepOrangeAccent : Colors.grey.shade300,
                                        foregroundColor: hasUnallocatedPoints ? Colors.white : Colors.black,
                                        elevation: hasUnallocatedPoints ? 8 : 2,
                                      ),
                                      child: const Text("分配能力點", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  
                                  const SizedBox(width: 12),
                                  
                                  // 剩餘點數顯示
                                  Text(
                                    hasUnallocatedPoints 
                                      ? "(剩餘可分配: ${widget.player.unallocatedPoints}!)"
                                      : "(剩餘可分配: ${widget.player.unallocatedPoints})",
                                    style: TextStyle(
                                      fontSize: 12, 
                                      fontWeight: FontWeight.bold,
                                      color: hasUnallocatedPoints ? Colors.red : Colors.black,
                                    )
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // 事件區
                  Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10),

                        // 故事事件 (保持不變)
                        if (event.type == "story") ...[
                          Text(event.text ?? "",
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          if (event.options != null && event.options!.isNotEmpty)
                            ...List.generate(event.options!.length, (i) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: ElevatedButton(
                                  onPressed: () => setState(() => widget.game.selectStoryOption(i)),
                                  child: Text(event.options![i], style: const TextStyle(fontSize: 12)),
                                ),
                              );
                            })
                          else
                            ElevatedButton(
                              onPressed: () => setState(() => widget.game.nextEvent()),
                              child: const Text("繼續", style: TextStyle(fontSize: 12)),
                            ),
                        ]

                        // 怪物事件
                        else if (event.type == "monster" && monster != null) ...[
                          Text("遇到怪物: ${monster.name}",
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text("怪物 HP: ${monster.hp}", style: const TextStyle(fontSize: 14)),
                          Text("ATK: ${monster.atk}", style: const TextStyle(fontSize: 14)),
                          
                          // 【✨ 修正點：將邏輯判斷直接寫入 TextStyle】
                          Text(
                            "回合: ${monster.turnCounter}", 
                            style: TextStyle(
                              fontSize: 14,
                              // 判斷是否只剩 1 回合
                              fontWeight: monster.turnCounter <= 1 ? FontWeight.w900 : FontWeight.normal,
                              color: monster.turnCounter <= 1 ? Colors.red : Colors.black, // 使用紅色提醒
                            ),
                          ),
                          
                          const SizedBox(height: 20),

                          if (event.question != null) ...[
                            Text(event.question!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            if (event.answerKeys != null && event.answerKeys!.isNotEmpty)
                              // 多欄填空題
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
                            else if (event.options != null && event.options!.isNotEmpty)
                              // 選擇題
                              ...List.generate(event.options!.length, (i) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
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
                                    child: Text(event.options![i], style: const TextStyle(fontSize: 12)),
                                  ),
                                );
                              })
                          ],
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // 2. 底部固定戰鬥紀錄區
          Positioned(
            bottom: 0, 
            left: 0,
            right: 0,
            height: battleLogHeight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent, width: 2),
                ),
                padding: const EdgeInsets.all(12),
                child: AnimatedBuilder(
                  animation: widget.game,
                  builder: (context, _) {
                    // 自動滾到底部 (已將主要滾動邏輯移至 _handleGameUpdate 以優化)
                    return ListView.builder(
                      controller: _logScrollController,
                      itemCount: widget.game.battleLog.length,
                      itemBuilder: (context, index) {
                        // 【替換為新的結構化日誌顯示】
                        return _buildLogEntry(widget.game.battleLog[index]);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}