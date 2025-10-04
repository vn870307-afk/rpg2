import 'package:flutter/material.dart';
import 'package:rpg/controllers/game_controller.dart';
import 'package:rpg/models/player.dart';
import 'package:rpg/screens/main_screen.dart';
import 'package:rpg/screens/attribute_allocation_screen.dart';
import 'package:rpg/widgets/fillIn_answer_field.dart';

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

class _GameScreenState extends State<GameScreen> {
  bool loaded = false;
  List<String> battleLog = [];
  final ScrollController _logScrollController = ScrollController();
  // ===== 戰鬥紀錄顏色規則 =====
  final Map<String, Color> logColorRules = {
    "造成": Colors.redAccent,      // 玩家攻擊
    "攻擊": Colors.redAccent,
    "怪物": Colors.deepPurple,     // 怪物動作
    "升級": Colors.white,          // 升級
    "獲得": Colors.white,          // 獎勵
    "題目": Colors.white,          // 題目
    "損失": Colors.redAccent,          // 損失
    "特殊事件": Colors.cyan,       // 特殊事件
    "答錯": Colors.orange,         // 答錯
    "答對": Colors.lightGreenAccent,
    "💀": Colors.grey,              // 死亡
  };

  // 根據文字自動選顏色
  Color getLogColor(String text) {
    for (var entry in logColorRules.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }
    return Colors.greenAccent; // 預設顏色
  }


  @override
  void initState() {
    super.initState();
    _setOnDeath();
    loaded = true;
  }
  void addBattleLog(String message) {
    setState(() {
      widget.game.battleLog.add(message);
      if (widget.game.battleLog.length > 20) {
        widget.game.battleLog.removeAt(0);
      }
    });

    // 自動滾動到最新訊息
    if (_logScrollController.hasClients) {
      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
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

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final event = widget.game.currentEvent;
    final monster = event.type == "monster" ? widget.game.currentMonster : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("RPG Demo", style: TextStyle(color: Colors.black)),
        backgroundColor: const Color.fromARGB(255, 200, 190, 120), // 稍深灰米色
        elevation: 2,
      ),
      backgroundColor: const Color.fromARGB(255, 230, 224, 224), // 暗灰色背景
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 玩家屬性區
            Container(
              height: 220, // 或你想要的高度
              padding: const EdgeInsets.all(8),
              color: const Color.fromARGB(255, 212, 193, 165),
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左邊：能力值區
                Expanded(
                  flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 基礎能力值
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text("血量: ${widget.player.hp} / ${widget.player.maxhp}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text("等級: ${widget.player.lv}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text("經驗值: ${widget.player.exp}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(
                        "力量: ${widget.player.str} (${widget.player.getEffective('str') - widget.player.str >= 0 ? '+' : ''}${widget.player.getEffective('str') - widget.player.str})",
                        style: TextStyle(
                          color: widget.player.getEffective('str') - widget.player.str > 0
                              ? Colors.red
                              : widget.player.getEffective('str') - widget.player.str < 0
                                  ? Colors.green
                                  : const Color.fromARGB(159, 104, 97, 1),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "堅毅: ${widget.player.vit} (${widget.player.getEffective('vit') - widget.player.vit >= 0 ? '+' : ''}${widget.player.getEffective('vit') - widget.player.vit})",
                        style: TextStyle(
                          color: widget.player.getEffective('vit') - widget.player.vit > 0
                              ? Colors.red
                              : widget.player.getEffective('vit') - widget.player.vit < 0
                                  ? Colors.green
                                  : const Color.fromARGB(159, 104, 97, 1),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // 智力
                      Text(
                        "智力: ${widget.player.intt} (${widget.player.getEffective('intt') - widget.player.intt >= 0 ? '+' : ''}${widget.player.getEffective('intt') - widget.player.intt})",
                        style: TextStyle(
                          color: widget.player.getEffective('intt') - widget.player.intt > 0
                              ? Colors.red
                              : widget.player.getEffective('intt') - widget.player.intt < 0
                                  ? Colors.green
                                  : const Color.fromARGB(159, 104, 97, 1),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // 敏捷
                      Text(
                        "敏捷: ${widget.player.dex} (${widget.player.getEffective('dex') - widget.player.dex >= 0 ? '+' : ''}${widget.player.getEffective('dex') - widget.player.dex})",
                        style: TextStyle(
                          color: widget.player.getEffective('dex') - widget.player.dex > 0
                              ? Colors.red
                              : widget.player.getEffective('dex') - widget.player.dex < 0
                                  ? Colors.green
                                  : const Color.fromARGB(159, 104, 97, 1),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // 魅力
                      Text(
                        "魅力: ${widget.player.cha} (${widget.player.getEffective('cha') - widget.player.cha >= 0 ? '+' : ''}${widget.player.getEffective('cha') - widget.player.cha})",
                        style: TextStyle(
                          color: widget.player.getEffective('cha') - widget.player.cha > 0
                              ? Colors.red
                              : widget.player.getEffective('cha') - widget.player.cha < 0
                                  ? Colors.green
                                  : const Color.fromARGB(159, 104, 97, 1),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // 幸運
                      Text(
                        "幸運: ${widget.player.luk} (${widget.player.getEffective('luk') - widget.player.luk >= 0 ? '+' : ''}${widget.player.getEffective('luk') - widget.player.luk})",
                        style: TextStyle(
                          color: widget.player.getEffective('luk') - widget.player.luk > 0
                              ? Colors.red
                              : widget.player.getEffective('luk') - widget.player.luk < 0
                                  ? Colors.green
                                  : const Color.fromARGB(159, 104, 97, 1),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                    ],
                  ),
                  const SizedBox(height: 8),
                  // 戰鬥能力值
                  Wrap(
                    spacing: 16,
                    children: [
                      Text("攻擊: ${widget.player.atk.toStringAsFixed(1)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text("防禦: ${widget.player.def.toStringAsFixed(1)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text("迴避率: ${widget.player.agi.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text("暴擊率: ${widget.player.ct.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text("速度: ${widget.player.spd.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text("洞察力: ${widget.player.ins.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text("特殊事件: ${widget.player.SupportEvent.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text("SAN值: ${widget.player.SAN.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: widget.player.unallocatedPoints > 0
                            ? () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => AttributeAllocationScreen(player: widget.player)),
                                );
                                setState(() {});
                              }
                            : null,
                        child: const Text("分配能力點",style: TextStyle(fontSize: 12),),
                      ),
                      const SizedBox(width: 12),
                      Text("(剩餘可分配: ${widget.player.unallocatedPoints})", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // 分配雕紋點區塊
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // 分配雕紋點邏輯
                        },
                        child: const Text("分配雕紋點",style: TextStyle(fontSize: 12),),
                      ),
                      const SizedBox(width: 20),
                      Wrap(
                        spacing: 10, // 水平間距
                        runSpacing: 10, // 垂直間距
                        children: [
                          for (var skill in ['技能1','技能2','技能3','技能4','技能5'])
                            SizedBox(
                              width: 90,  // 固定寬度
                              height: 35, // 固定高度
                              child: ElevatedButton(
                                onPressed: () {
                                  // 點擊技能邏輯
                                },
                                child: Text(skill, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  )
                ],
              ),
            ),
            const Divider(),
            // ===== 戰鬥紀錄區 =====
            Expanded(
              flex: 2,
              child: Container(
                height: 220, // 固定高度 200，可改成你想要的高度
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent, width: 2),
                ),
                padding: const EdgeInsets.all(12),
                child: AnimatedBuilder(
                  animation: widget.game,
                  builder: (context, _) {
                    // 確保每次新增訊息都滾到底
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_logScrollController.hasClients) {
                        _logScrollController.animateTo(
                          _logScrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                    return ListView.builder(
                      controller: _logScrollController,
                      itemCount: widget.game.battleLog.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            widget.game.battleLog[index],
                            style: TextStyle(
                              color: getLogColor(widget.game.battleLog[index]),
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
     ),
            const Divider(),

            // 事件區
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      // 故事事件
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
                                child: Text(event.options![i],style: const TextStyle(fontSize: 12),),
                              ),
                            );
                          })
                        else
                          ElevatedButton(
                            onPressed: () => setState(() => widget.game.nextEvent()),
                            child: const Text("繼續",style: TextStyle(fontSize: 12),),
                          ),
                      ]

                      // 怪物事件
                      else if (event.type == "monster" && monster != null) ...[
                        Text("遇到怪物: ${monster.name}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text("怪物 HP: ${monster.hp}", style: const TextStyle(fontSize: 12)),
                        Text("ATK: ${monster.atk}", style: const TextStyle(fontSize: 12)),
                        Text("回合: ${monster.turnCounter}", style: const TextStyle(fontSize: 12)),
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
                                print("玩家選擇: ${answer.filledValues}");
                                final correct = widget.game.answerEvent(answer);
                                print("答題結果: $correct");
                                setState(() {
                                      // 抽新題目或下一事件
                                      if (widget.game.currentMonster?.isDead ?? false) {
                                        widget.game.nextEvent();
                                      } else {
                                        widget.game.assignRandomQuestionToMonster();
                                      }
                                    });
                              },
                            )
                          else if (event.options != null && event.options!.isNotEmpty)
                            ...List.generate(event.options!.length, (i) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: ElevatedButton(
                                  onPressed: () {
                                    widget.game.answerEvent(i);
                                    setState(() {
                                      // 抽新題目或下一事件
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
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
