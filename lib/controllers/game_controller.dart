// lib/controllers/game_controller.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:rpg/models/player.dart';
import 'package:rpg/models/story_event.dart';
import 'package:rpg/models/ziwei_player_answer.dart';
import 'package:rpg/models/checkSanEffect.dart';
import 'package:flutter/foundation.dart'; // 引入 compute 函式
import 'package:rpg/models/battle_log_entry.dart';

// ===== Monster Model (保持不變) =====
class Monster {
  final String id;
  final String name;
  int hp;
  final int turns; 
  int turnCounter = 0; 
  final List<int> atkRange;
  final bool isBoss;
  final Map<String, dynamic>? reward;

  Monster({
    required this.id,
    required this.name,
    required this.hp,
    required this.turns,
    required this.atkRange,
    this.isBoss = false,
    this.reward,
  }) { turnCounter = turns; }

  factory Monster.fromJson(Map<String, dynamic> json) {
    return Monster(
      id: (json['id'] ?? 'unknown').toString(),
      name: json['name'] ?? '未知怪物',
      hp: json['hp'] is int ? json['hp'] : int.tryParse(json['hp']?.toString() ?? '0') ?? 0,
      turns: json['turns'] is int ? json['turns'] : int.tryParse(json['turns']?.toString() ?? '0') ?? 0,
      atkRange: (json['atk'] as List<dynamic>? ?? [0,0]).map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0).toList(),
      isBoss: json['isBoss'] ?? false,
      reward: json['reward'] ?? {},
    );
  }
  
  int get atk {
    final r = Random();
    return atkRange[0] + r.nextInt(atkRange[1] - atkRange[0] + 1);
  }

  bool get isDead => hp <= 0;

  void takeDamage(int damage) {
    hp -= damage;
    if (hp < 0) hp = 0;
  }
}


// ✨ 【頂層函式：用於在 Isolate 中解析 StoryEvent 列表】
List<StoryEvent> _parseStoryEvents(String jsonString) {
  final jsonMap = json.decode(jsonString);

  if (jsonMap is List) {
    return jsonMap.map((e) => StoryEvent.fromJson(e)).toList();
  } else if (jsonMap is Map && jsonMap['events'] != null) {
    return (jsonMap['events'] as List)
        .map((e) => StoryEvent.fromJson(e))
        .toList();
  } else if (jsonMap is Map && jsonMap['supportEvents'] != null) {
    return (jsonMap['supportEvents'] as List)
        .map((e) => StoryEvent.fromJson(e))
        .toList();
  }
  return [];
}

// ✨ 【頂層函式：用於在 Isolate 中解析 Monster 列表】
List<Monster> _parseMonsters(String jsonString) {
  final jsonMap = json.decode(jsonString);

  if (jsonMap is Map && jsonMap['monsters'] != null) {
    return (jsonMap['monsters'] as List<dynamic>)
        .map((m) => Monster.fromJson(m))
        .toList();
  }
  return [];
}


class GameController extends ChangeNotifier{
  Player player;
  late SanEffectChecker sanChecker;
  Set<String> usedQuestionIds = {}; // 追蹤已抽題目
  // ===== 事件相關 =====
  List<StoryEvent> events = [];
  late Map<String, int> eventIdToIndex;
  int currentEventIndex = 0;
  int supportChainCount = 0;
  int? selectedOptionIndex;

  // ===== 戰鬥顯示 =====
  List<BattleLogEntry> battleLog = [];

  // ===== 怪物相關 =====
  List<Monster> monsters = [];

  bool playerTurn = true;
  bool inSupportEvent = false;

  // ===== 支援事件 =====
  List<StoryEvent> supportEvents = [];

  bool waitingForMonsterAttack = false;

  // ===== 題目列表 =====
  List<StoryEvent> questions = []; 
  
  GameController({required this.player}) {
    sanChecker = SanEffectChecker(sanEffects: [
    SanEffect(severity: "light", text: "你感到輕微的焦慮，智力-1,HP-5。", tempDebuff: {"intt": 1,"hp": -5}),
    SanEffect(severity: "medium", text: "你感到精神混亂，力量-2,敏捷-1,HP-10 。", tempDebuff: {"str": 2, "dex": 1,"hp": -10}),
    SanEffect(severity: "heavy", text: "你陷入極度恐慌，堅毅-3,魅力-2,HP-15。", tempDebuff: {"vit": 3, "cha": -2,"hp": -15}),
  ]);

  // 綁定 Player 的 log 到 battleLog
  player.onDeath = () {
    addStructuredLog(LogType.system, "玩家死亡，遊戲結束");
    notifyListeners();
  };
}

  // 【優化點 1: 移除 notifyListeners()，讓調用者決定何時更新】
  void addStructuredLog(LogType type, String message, {Map<String, dynamic>? data}) {
      final entry = BattleLogEntry(type: type, message: message, data: data);
      battleLog.add(entry);
      if (battleLog.length > 20) {
        battleLog.removeAt(0);
      }
  }

  // ===== 當前事件/怪物 (保持不變) =====
  StoryEvent get currentEvent {
    if (inSupportEvent && nextSupportEvent != null) {
      return nextSupportEvent!;
    }
    return events[currentEventIndex];
  }

  Monster? get currentMonster {
    if (currentEvent.type != "monster") return null;

    return monsters.firstWhere(
      (m) => m.id == currentEvent.monsterId,
      orElse: () => throw Exception("找不到怪物 ID: ${currentEvent.monsterId}"),
    );
  }

  // ===== 載入章節 (使用 Isolate 優化) =====
  Future<void> loadChapter(String indexPath) async {
    // 1. 讀 index.json
    final indexString = await rootBundle.loadString(indexPath);
    final indexData = json.decode(indexString);

    // 2. route.json (使用 Isolate)
    if (indexData['routes'] != null) {
      final routePath = 'assets/chapters/chapter1/${indexData['routes']}';
      final routeString = await rootBundle.loadString(routePath);
      final routeData = await compute(json.decode, routeString); // 📦 Isolate 解碼

      // route events
      final routeEventsList = (routeData['events'] as List<dynamic>?)
              ?.map((e) => StoryEvent.fromJson(e))
              .toList() ?? [];
      events.addAll(routeEventsList); 

      // monsters
      if (routeData['monsters'] is List) {
        final monstersData = json.encode({'monsters': routeData['monsters']}); // 重新打包成 Map
        monsters = await compute(_parseMonsters, monstersData); // 📦 Isolate 解碼
      }
    }

    // 3. multiple_choice.json (使用 Isolate)
    if (indexData['multipleChoice'] != null) {
      final mcPath = 'assets/chapters/chapter1/${indexData['multipleChoice']}';
      final mcString = await rootBundle.loadString(mcPath);
      List<StoryEvent> mcEvents = await compute(_parseStoryEvents, mcString); // 📦 Isolate 解碼
      events.addAll(mcEvents);
      questions.addAll(mcEvents);
    }


    // 5. support_event.json (使用 Isolate)
    if (indexData['supportEvents'] != null) {
      final supportPath = 'assets/chapters/chapter1/${indexData['supportEvents']}';
      final supportString = await rootBundle.loadString(supportPath);
      supportEvents = await compute(_parseStoryEvents, supportString); // 📦 Isolate 解碼
    }
    
    // 6. Flying_Star.json (使用 Isolate)
    if (indexData['Flying_Star'] != null) {
      final ziweiPath = 'assets/chapters/chapter1/${indexData['Flying_Star']}';
      final ziweiString = await rootBundle.loadString(ziweiPath);
      final ziweiEvents = await compute(_parseStoryEvents, ziweiString); // 📦 Isolate 解碼

      events.addAll(ziweiEvents);
      questions.addAll(ziweiEvents);
    }

    // 7. 初始化
    currentEventIndex = 0;
    // 建立 id → index Map
    eventIdToIndex = {};
    for (int i = 0; i < events.length; i++) {
      eventIdToIndex[events[i].id] = i;
    }

    notifyListeners(); // 載入完成，通知 UI 更新
  }

  // ===== 隨機插入支援事件 (保持不變) =====
  StoryEvent? nextSupportEvent; 

  void maybeInsertSupportEvent() {
    if (supportEvents.isEmpty) return;
    if (supportChainCount >= 3) {
      addStructuredLog(LogType.info, "特殊事件已達到連續觸發上限 (3 次)，本次跳過");
      supportChainCount = 0;
      return; 
    }

    double chance = player.SupportEvent / 100;
    if (Random().nextDouble() < chance) {
      nextSupportEvent = supportEvents[Random().nextInt(supportEvents.length)];
      inSupportEvent = true;
      supportChainCount++; 
      if (nextSupportEvent!.text != null && nextSupportEvent!.text!.isNotEmpty) {
        addStructuredLog(LogType.story, "特殊事件觸發: ${nextSupportEvent!.text!}");
      }
    } else {
        supportChainCount = 0; // ✨ 機率失敗，重置！
    }
  }

  // 【優化點 2: 統一狀態更新 - 戰鬥與回答的核心邏輯】
  bool answerEvent(dynamic userAnswer) {
    final event = currentEvent;
    final monster = currentMonster;
    bool correct = false;

    if (event == null) {
      notifyListeners(); 
      return false;
    }

    // 🔹 SAN 影響
    final sanResult = sanChecker.checkSanEffect(player);
    if (sanResult != null) {
      addStructuredLog(LogType.penalty, "精神影響: ${sanResult.text}");

      if (sanResult.tempDebuff != null) {
        Map<String, int> temp = {};
        sanResult.tempDebuff!.forEach((k, v) {
          if (k == "hp") {
            player.hp += v;
            if (player.hp < 0) {
            player.hp = 0;
            if (player.onDeath != null) player.onDeath!(); // ✅ 直接呼叫死亡事件
            }
          } else {
            temp[k] = v;
          }
        });
        if (temp.isNotEmpty) {
          player.applyTempDebuff(temp, 999);
        }
      }
    }

    // ===== 判斷答案 (保持不變) =====
    switch (event.questionType) {
      case 'fillin':
        if (userAnswer is ZiWeiPlayerAnswer) {
          final answers = userAnswer.filledValues;
          final keys = event.answerKeys ?? [];

          double accuracy = 0.0; // 答對比例
          if (answers.length == keys.length) {
            int correctCount = 0;
            for (int i = 0; i < keys.length; i++) {
              if (answers[i].trim() == keys[i].trim()) {
                correctCount++;
              }
            }
            accuracy = correctCount / keys.length;
          }

          correct = accuracy == 1.0; // 完全正確才算正確

          // 組顯示模板
          String displayTemplate = event.template ?? "";
          for (int i = 0; i < keys.length; i++) {
            displayTemplate = displayTemplate.replaceFirst('___', '[${keys[i]}]');
          }

          if (correct) {
            addStructuredLog(LogType.correctAnswer, "正確答案： $displayTemplate");
          } else {
            addStructuredLog(LogType.correctAnswer, "正確答案： $displayTemplate");
            addStructuredLog(LogType.incorrectAnswer, "玩家答案： $answers");

            // ✅ 部分答對造成比例傷害（只扣血，不觸發暴擊或速度加成）
            if (currentMonster != null && accuracy > 0) {
              int partialDamage = (player.atk * accuracy).toInt();
              currentMonster!.takeDamage(partialDamage);
              addStructuredLog(
                LogType.playerAttack,
                "部分答對！對 ${currentMonster!.name} 造成 $partialDamage 傷害 (答對比例: ${(accuracy*100).round()}%)",
                data: {"damage": partialDamage}
              );
            }
          }
        }
        break;


      case 'multiple_choice':
        if (userAnswer is int) {
          if (event.options == null || event.options!.isEmpty || userAnswer >= event.options!.length) {
            correct = false;
          } else {
            final selectedOption = event.options![userAnswer];
            final answerStr = event.answer?.toString().trim() ?? "";
            correct = selectedOption.trim() == answerStr;

            if (correct) {
              addStructuredLog(LogType.correctAnswer, "正確答案：$answerStr");
            } else {
              addStructuredLog(LogType.correctAnswer, "正確答案：$answerStr");
              addStructuredLog(LogType.incorrectAnswer, "玩家答案：$selectedOption");
            }
          }
        } else {
          addStructuredLog(LogType.system, "玩家答案型別錯誤！");
        }
        break;
    }

    // ===== 怪物事件邏輯 =====
    if (monster != null) {
      if (correct) {
        playerAttack();
      } else {
        monster.turnCounter--;
        addStructuredLog(LogType.info, "答錯了！${monster.name} 的回合倒數 -1，剩餘回合: ${monster.turnCounter}");

        if (monster.turnCounter <= 0) {
          monsterAttack();
          monster.turnCounter = monster.turns;
        }
      }
    }

    notifyListeners(); // ✨ 統一在邏輯結束後通知 UI 更新一次
    return correct;
  }

  // ===== 玩家攻擊怪物 (移除 notifyListeners) =====
  void playerAttack() {
    final monster = currentMonster;
    if (!playerTurn || monster == null) return;
    int damage = player.atk.toInt();
    bool isCrit = false;
     // 暴擊判定
    double critRate = player.ct.toDouble(); 
    double critMultiplier = 1.5; 
    if (Random().nextDouble() < critRate / 100) {
      damage = (damage * critMultiplier).toInt();
      isCrit = true;
    }
    // 速度額外出手判定
    double speedChance = pow(player.spd / 100, 2).toDouble(); 
    if (Random().nextDouble() < speedChance) {
      addStructuredLog(LogType.info, "你行動迅捷，壓制敵人行動，怪物回合+1！");
      monster.turnCounter += 1; 
    }
    monster.takeDamage(damage);
     // 戰鬥日誌
    addStructuredLog(
      LogType.playerAttack,
      "你 對 ${monster.name} 造成 $damage 傷害 剩餘HP=${monster.hp}" + (isCrit ? " 💥 暴擊!" : ""),
      data: {"damage": damage, "crit": isCrit});

    if (monster.isDead) {
      addStructuredLog(LogType.system, "${monster.name} 被擊敗！");
      player.tempDebuff.clear();
      player.debuffDuration.clear();
      applyMonsterReward(monster.reward);
      if (player.SAN < 60) {
        int recover = 5 + Random().nextInt(6); // 5~10
        player.sanBase += recover;
        if (player.sanBase > 100) player.sanBase = 100;
        addStructuredLog(LogType.reward, "戰鬥勝利讓你稍微冷靜下來，SAN +$recover。");
      }
      selectedOptionIndex = null;
      maybeInsertSupportEvent();
      if (nextSupportEvent == null) {
        nextEvent(optionIndex: 0);
      } 
    } else {
      monster.turnCounter--;
      if (monster.turnCounter <= 0) {
        // 【優化點 3: 異步延遲呼叫怪物攻擊】
        // 延遲執行，讓 UI 有時間繪製玩家攻擊的 Log
        Future.delayed(const Duration(milliseconds: 300), () { 
          monsterAttack();
          monster.turnCounter = monster.turns; // 安全重置
          notifyListeners(); // 怪物攻擊後需要通知 UI 更新血量和 Log
        });
      }
    }
  }


  // ===== 怪物攻擊玩家 (移除 notifyListeners) =====
  void monsterAttack() {
    if (currentMonster == null) return; 
    // 迴避判定
    double evasionChance = player.agi.toDouble(); 
    if (Random().nextDouble() * 100 < evasionChance) {
      addStructuredLog(LogType.info, "${currentMonster!.name} 的攻擊被你迴避了！");
      return;
    }
    int damage = currentMonster!.atk;
    int damageTaken = (damage * (100 / (100 + player.def))).round(); 
    applyReward({"hp": -damageTaken}, isPenalty: true);
    if (player.hp < 0) player.hp = 0;
    addStructuredLog(
      LogType.damageTaken, 
      "${currentMonster!.name} 對 你 造成 $damageTaken 傷害 剩餘HP=${player.hp}",
      data: {"damage": damageTaken}
    );
  }
  // ... (applyReward, applyMonsterReward 保持不變)
  void applyReward(Map<String, dynamic>? reward, {bool isPenalty = false}) {
    if (reward == null || reward.isEmpty) return;

    int oldLv = player.lv;
    player.applyReward(reward);

    if (isPenalty) {
      if (inSupportEvent) {
        addStructuredLog(LogType.penalty, "特殊事件損失: $reward");
      }
    } else {
      addStructuredLog(LogType.reward, "獲得: $reward", data: reward);
    }

    if (!isPenalty && player.lv > oldLv) {
      addStructuredLog(LogType.reward, "🎉 升級！等級: ${player.lv}", data: {"levelUp": true});
    }
  }


  // ===== Monster / Boss Reward =====
  void applyMonsterReward(Map<String, dynamic>? reward) {
    if (reward == null) return;
    Random rng = Random();
    Map<String, int> gain = {};
    reward.forEach((key, value) {
      if (value is List && value.length == 2) {
        gain[key] = (rng.nextInt(value[1] - value[0] + 1) + value[0]).toInt();
      } else {
        gain[key] = value;
      }
    });

    applyReward(gain, isPenalty: false);
  }
  
  // ===== 選擇 story 選項 (移除 notifyListeners) =====
  void selectStoryOption(int index) {
    final event = currentEvent;
    Random rng = Random();
    selectedOptionIndex = index; 

    if (event.options != null && index < event.options!.length) {
      final chosenText = event.options![index];
      addStructuredLog(LogType.info, "你選擇了：$chosenText");
    }

    // 套用選項對應的 reward
    if (event.optionsReward != null && index < event.optionsReward!.length) {
      Map<String, int> reward = {};
      event.optionsReward![index].forEach((key, value) {
        if (value is List && value.length == 2) {
          reward[key] = (rng.nextInt(value[1] - value[0] + 1) + value[0]).toInt();
        } else {
          reward[key] = value;
        }
      });
      applyReward(reward, isPenalty: false);
    }

    // 套用選項對應的 penalty
    if (event.optionsPenalty != null && index < event.optionsPenalty!.length) {
      Map<String, int> penalty = {};
      event.optionsPenalty![index].forEach((key, value) {
        if (value is List && value.length == 2) {
          penalty[key] = (-(rng.nextInt(value[1] - value[0] + 1) + value[0])).toInt();
        } else {
          penalty[key] = -(value ?? 0);
        }
      });
      applyReward(penalty, isPenalty: true);
    }
 
    nextEvent(optionIndex: index);
    notifyListeners(); // ✨ 統一更新一次
  }
  
  // ===== 隨機給怪物事件分配題目 (保持不變) =====
  void assignRandomQuestionToMonster() {
    String? fillinHint; 
    if (currentEvent.type != "monster" || questions.isEmpty) return;
    final availableQuestions = questions.where((q) => !usedQuestionIds.contains(q.id)).toList();
    if (availableQuestions.isEmpty) return; // 全部用過就跳過
    
    final randomEvent = availableQuestions[Random().nextInt(availableQuestions.length)];
    usedQuestionIds.add(randomEvent.id); // ✅ 記錄已抽過
    
    addStructuredLog(LogType.reward, "題目： ${randomEvent.question}", data: {"isQuestion": true});

    currentEvent.question = randomEvent.question;
    currentEvent.answer = randomEvent.answer;
    currentEvent.answerKeys = randomEvent.answerKeys;
    currentEvent.template = randomEvent.template;
    currentEvent.questionType = randomEvent.type;

    if (randomEvent.distractors != null && randomEvent.distractors!.isNotEmpty) {
      final List<String> distractorPool = List<String>.from(randomEvent.distractors!);
      distractorPool.shuffle();

      final List<String> opts = distractorPool.take(3).toList();
      opts.add(randomEvent.answer);
      opts.shuffle();

      double chance = player.ins / 100.0; 
      if (Random().nextDouble() < chance && opts.length > 2) {
        List<String> wrongOptions = opts.where((o) => o != randomEvent.answer).toList();
        if (wrongOptions.isNotEmpty) {
          String removed = wrongOptions[Random().nextInt(wrongOptions.length)];
          opts.remove(removed);
          addStructuredLog(LogType.info, "洞察力 觸發提示：刪除了選項 '$removed'");
        }
      }

      currentEvent.options = opts;
    } else {
            double chance = player.ins / 100.0;
           if (Random().nextDouble() < chance) {
              
              if (currentEvent.answerKeys != null && currentEvent.answerKeys!.isNotEmpty) {
                  List<int> availableIndices = List.generate(
                      currentEvent.answerKeys!.length, (i) => i);
                  
                  final int totalBlanks = availableIndices.length;
                  int allowedMaxHints;

                  if (totalBlanks <= 2) {
                      allowedMaxHints = 1;
                  } else {
                      allowedMaxHints = 2; 
                  }
                  
                  int hintsToPick = min(allowedMaxHints, totalBlanks); 

                  if (hintsToPick > 0) {
                      List<String> hints = [];

                      for (int i = 0; i < hintsToPick; i++) {
                          int pickIndex = Random().nextInt(availableIndices.length);
                          int answerIndex = availableIndices[pickIndex];
                          
                          String hint = currentEvent.answerKeys![answerIndex];
                          hints.add(hint);
                          
                          availableIndices.removeAt(pickIndex);
                      }

                      String hintMessage;
                      if (hints.length == 2) {
                          hintMessage = "其中兩格答案是 '${hints[0]}' 和 '${hints[1]}'";
                      } else {
                          hintMessage = "其中一格答案是 '${hints.first}'";
                      }

                      addStructuredLog(LogType.info, "洞察力 觸發提示：$hintMessage");
                      
                      fillinHint = hints.first;
                  }
              }
          }
            currentEvent.answerKeys = randomEvent.answerKeys;
          }
  }

  // ===== 下一個事件 (保持不變) =====
    void nextEvent({int optionIndex = 0}) {
      // 判斷是否為支援事件結束
      if (inSupportEvent) {
        inSupportEvent = false;
        nextSupportEvent = null;

        final current = events[currentEventIndex]; // 支援事件前的事件（可能已死怪物）
        int useIndex = selectedOptionIndex ?? 0;

        // 只有當前事件是已擊敗的怪物事件時，才進行強行推進
        if (current.type == "monster" && currentMonster != null && currentMonster!.isDead) {
          // 推進主線
          if (current.nextEventIds != null && current.nextEventIds!.isNotEmpty) {
            final nextId = current.nextEventIds!.length > useIndex
                ? current.nextEventIds![useIndex]
                : current.nextEventIds!.first;

            if (eventIdToIndex.containsKey(nextId)) {
              currentEventIndex = eventIdToIndex[nextId]!;
            } else {
              currentEventIndex++;
            }
          } else if (currentEventIndex < events.length - 1) {
            currentEventIndex++;
          } else {
            addStructuredLog(LogType.system, "無下一事件或章節結束");
          }
        }

        selectedOptionIndex = null;

        // 檢查是否觸發新的支援事件（會自動檢查 supportChainCount < 3）
        maybeInsertSupportEvent();
        if (nextSupportEvent != null) {
          notifyListeners();
          return; // 再次進入特殊事件
        }

        // 顯示推進後的新事件，初始化怪物事件
        final next = events[currentEventIndex];
        if (next.text != null && next.text!.isNotEmpty) {
          addStructuredLog(LogType.story, next.text!);
        }
        if (next.type == "monster" && currentMonster != null && !currentMonster!.isDead) {
          currentMonster!.turnCounter = currentMonster!.turns;
          playerTurn = true;
          assignRandomQuestionToMonster();
        }

        notifyListeners();
        return;
      }

      final current = currentEvent;

      // 怪物沒死，不前進事件
      if (current.type == "monster" && currentMonster != null && !currentMonster!.isDead) {
        return;
      }

      // 正常走分支或下一事件
      int useIndex = optionIndex;
      if (current.nextEventIds != null && current.nextEventIds!.isNotEmpty) {
        final nextId = current.nextEventIds!.length > useIndex
            ? current.nextEventIds![useIndex]
            : current.nextEventIds!.first;

        if (eventIdToIndex.containsKey(nextId)) {
          currentEventIndex = eventIdToIndex[nextId]!;
        } else {
          currentEventIndex++;
        }

        final next = currentEvent;
        if (next.text != null && next.text!.isNotEmpty) {
          addStructuredLog(LogType.story, next.text!);
        }
        if (next.type == "monster" && currentMonster != null && !currentMonster!.isDead) {
          currentMonster!.turnCounter = currentMonster!.turns;
          playerTurn = true;
          assignRandomQuestionToMonster();
        }
      } else if (currentEventIndex < events.length - 1) {
        currentEventIndex++;
        final next = currentEvent;
        if (next.text != null && next.text!.isNotEmpty) {
          addStructuredLog(LogType.story, next.text!);
        }
        if (next.type == "monster" && currentMonster != null && !currentMonster!.isDead) {
          currentMonster!.turnCounter = currentMonster!.turns;
          playerTurn = true;
          assignRandomQuestionToMonster();
        }
      } else {
        addStructuredLog(LogType.system, "無下一事件或章節結束");
      }

      notifyListeners();
    }

}