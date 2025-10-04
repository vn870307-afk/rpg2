import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:rpg/models/player.dart';
import 'package:rpg/models/story_event.dart';
import 'package:rpg/models/ziwei_player_answer.dart';
import 'package:rpg/models/checkSanEffect.dart';
import 'package:flutter/foundation.dart';
import 'package:rpg/models/battle_log_entry.dart';


// ===== Monster Model =====
class Monster {
  final String id;
  final String name;
  int hp;
  final int turns; // 怪物的攻擊間隔
  int turnCounter = 0; // 怪物當前計數器
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

class GameController extends ChangeNotifier{
  Player player;
  late SanEffectChecker sanChecker;
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
  List<StoryEvent> questions = []; // 存題目 JSON
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
  void addStructuredLog(LogType type, String message, {Map<String, dynamic>? data}) {
      final entry = BattleLogEntry(type: type, message: message, data: data);
      battleLog.add(entry);
      // 保持日誌長度限制
      if (battleLog.length > 20) {
        battleLog.removeAt(0);
      }
      // 只有在非測試環境下才通知 UI 更新，避免性能問題
      if (kReleaseMode || kDebugMode) {
        notifyListeners(); 
      }
  }

  // ===== 當前事件/怪物 =====
  StoryEvent get currentEvent {
    // 如果正在支援事件，就回傳支援事件
    if (inSupportEvent && nextSupportEvent != null) {
      return nextSupportEvent!;
    }
    // 否則回傳正常事件
    return events[currentEventIndex];
  }

  Monster? get currentMonster {
    // 只有怪物事件才有怪物
    if (currentEvent.type != "monster") return null;

    // 找對應怪物 ID
    return monsters.firstWhere(
      (m) => m.id == currentEvent.monsterId,
      orElse: () => throw Exception("找不到怪物 ID: ${currentEvent.monsterId}"),
    );
  }

  // ===== 載入章節 =====
  Future<void> loadChapter(String indexPath) async {
    // 1. 讀 index.json
    final indexString = await rootBundle.loadString(indexPath);
    final indexData = json.decode(indexString);

    // 2. route.json
    if (indexData['routes'] != null) {
      final routeString = await rootBundle.loadString(
          'assets/chapters/chapter1/${indexData['routes']}');
      final routeData = json.decode(routeString);

      // route events
      final routeEventsList = (routeData['events'] as List<dynamic>?)
              ?.map((e) => StoryEvent.fromJson(e))
              .toList() ??
          [];
      events.addAll(routeEventsList); // 加到總事件列表

      // monsters
      monsters = (routeData['monsters'] as List<dynamic>?)
              ?.map((m) => Monster.fromJson(m))
              .toList() ??
          [];
    }

    // 3.----- multiple_choice.json -----
    if (indexData['multipleChoice'] != null) {
      final mcString = await rootBundle.loadString(
          'assets/chapters/chapter1/${indexData['multipleChoice']}');
      final mcData = json.decode(mcString);

      List<StoryEvent> mcEvents = [];

      if (mcData is List) {
        // JSON 直接是 array
        mcEvents = mcData.map((e) => StoryEvent.fromJson(e)).toList();
      } else if (mcData is Map && mcData['events'] != null) {
        // JSON 有 events key
        mcEvents = (mcData['events'] as List)
            .map((e) => StoryEvent.fromJson(e))
            .toList();
      } 
      events.addAll(mcEvents);
      questions.addAll(mcEvents);
    }


    // 4.input_question.json 是 array

    // 5.----- support_event.json -----
    if (indexData['supportEvents'] != null) {
      final supportString = await rootBundle.loadString(
          'assets/chapters/chapter1/${indexData['supportEvents']}');
      final supportData = json.decode(supportString);
      supportEvents = (supportData['supportEvents'] as List<dynamic>?)
              ?.map((e) => StoryEvent.fromJson(e))
              .toList() ??
          [];
    }
    
    // 6. Flying_Star.json
    if (indexData['Flying_Star'] != null) {
      final ziweiString = await rootBundle.loadString(
          'assets/chapters/chapter1/${indexData['Flying_Star']}');
      final ziweiData = json.decode(ziweiString);

      if (ziweiData is List) {
        // 在這裡加上 debug print
        final ziweiEvents = ziweiData.map((e) {
          final evt = StoryEvent.fromJson(e);
          return evt;
        }).toList();

        events.addAll(ziweiEvents);
        questions.addAll(ziweiEvents);
      }
    }

    // 7. 初始化
    currentEventIndex = 0;
    // 建立 id → index Map
    eventIdToIndex = {};
    for (int i = 0; i < events.length; i++) {
      eventIdToIndex[events[i].id] = i;
  }
  }

  // ===== 隨機插入支援事件 =====
  StoryEvent? nextSupportEvent; 

  void maybeInsertSupportEvent() {
    if (supportEvents.isEmpty) return;
    if (supportChainCount >= 3) {
      addStructuredLog(LogType.info, "特殊事件已達到連續觸發上限 (3 次)，本次跳過");
      return; // 超過上限就不再觸發
    }

    double chance = player.SupportEvent / 100;
    if (Random().nextDouble() < chance) {
      nextSupportEvent = supportEvents[Random().nextInt(supportEvents.length)];
      inSupportEvent = true;
      supportChainCount++; // 計數 +1
      if (nextSupportEvent!.text != null && nextSupportEvent!.text!.isNotEmpty) {
      addStructuredLog(LogType.story, "特殊事件觸發: ${nextSupportEvent!.text!}");
    }
    }
  }

  bool answerEvent(dynamic userAnswer) {
    final event = currentEvent;
    final monster = currentMonster;
    bool correct = false;

    if (event == null) return false;

    // 🔹 SAN 影響
    final sanResult = sanChecker.checkSanEffect(player);
    if (sanResult != null) {
      addStructuredLog(LogType.penalty, "精神影響: ${sanResult.text}");

      if (sanResult.tempDebuff != null) {
        Map<String, int> temp = {};
        sanResult.tempDebuff!.forEach((k, v) {
          if (k == "hp") {
            player.hp += v;
            if (player.hp < 0) player.hp = 0;
          } else {
            temp[k] = v;
          }
        });
        if (temp.isNotEmpty) {
          player.applyTempDebuff(temp, 999);
        }
      }
    }

    // ===== 判斷答案 =====
    switch (event.questionType) {
      case 'fillin':
        if (userAnswer is ZiWeiPlayerAnswer) {
          final answers = userAnswer.filledValues;
          final keys = event.answerKeys ?? [];

          if (answers.length != keys.length) {
            correct = false;
          } else {
            correct = true;
            for (int i = 0; i < keys.length; i++) {
              if (answers[i].trim() != keys[i].trim()) {
                correct = false;
                break;
              } 
            }
          }
          String displayTemplate = event.template ?? "";
          for (int i = 0; i < keys.length; i++) {
            displayTemplate = displayTemplate.replaceFirst('___', '[${keys[i]}]');
          }
          if(correct == false) {
            addStructuredLog(LogType.incorrectAnswer, "錯誤！");
            addStructuredLog(LogType.correctAnswer, "正確答案： $displayTemplate");
            addStructuredLog(LogType.incorrectAnswer, "玩家答案： $answers");
          } else {
            addStructuredLog(LogType.correctAnswer, "正確！");
            addStructuredLog(LogType.correctAnswer, "正確答案： $displayTemplate");
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

            // ✅/❌ battlelog 根據 correct 判斷
            if (correct) {
              addStructuredLog(LogType.correctAnswer, "正確！");
              addStructuredLog(LogType.correctAnswer, "正確答案：$answerStr");
            } else {
              addStructuredLog(LogType.incorrectAnswer, "錯誤！");
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
    return correct;
  }

  // ===== 玩家攻擊怪物 =====
  void playerAttack() {
    final monster = currentMonster;
    if (!playerTurn || monster == null) return;
    int damage = player.atk.toInt();
    bool isCrit = false;
     // 暴擊判定
    double critRate = player.ct.toDouble(); // 使用 ct 屬性
    double critMultiplier = 1.5; // 暴擊傷害倍率，可自由調整
    if (Random().nextDouble() < critRate / 100) {
      damage = (damage * critMultiplier).toInt();
      isCrit = true;
    }
    // ===== 速度額外出手判定 =====
    double speedChance = pow(player.spd / 100, 2).toDouble(); 
    if (Random().nextDouble() < speedChance) {
      addStructuredLog(LogType.info, "你行動迅捷，壓制敵人行動，怪物回合+1！");
      monster.turnCounter += 1; // 怪物回合數補回去
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
      // 清空玩家選擇，防止舊選項影響下一事件
      selectedOptionIndex = null;
      maybeInsertSupportEvent();
      if (nextSupportEvent == null) {
        // 沒有支援事件就直接進下一事件
        nextEvent(optionIndex: 0);
      } else {
        // 支援事件觸發，currentEventIndex 先不動，等 UI 處理完再跳
      }
    } else {
      monster.turnCounter--;
      if (monster.turnCounter <= 0) {
        monsterAttack();
        monster.turnCounter = monster.turns; // 安全重置
      }
    }
  }


  // ===== 怪物攻擊玩家 =====
  void monsterAttack() {
    if (currentMonster == null) return; // 如果不是怪物事件就跳過
    // 迴避判定
    double evasionChance = player.agi.toDouble(); // 玩家迴避率
    if (Random().nextDouble() * 100 < evasionChance) {
      // 攻擊被迴避
      addStructuredLog(LogType.info, "${currentMonster!.name} 的攻擊被你迴避了！");
      return;
    }
    int damage = currentMonster!.atk;
    int damageTaken = (damage * (100 / (100 + player.def))).round(); // 百分比減傷
    applyReward({"hp": -damageTaken}, isPenalty: true);
    if (player.hp < 0) player.hp = 0;
    addStructuredLog(
      LogType.damageTaken, // 【修改】使用 damageTaken 類型
      "${currentMonster!.name} 對 你 造成 $damageTaken 傷害 剩餘HP=${player.hp}",
      data: {"damage": damageTaken}
    );
  }
  void applyReward(Map<String, dynamic>? reward, {bool isPenalty = false}) {
    if (reward == null || reward.isEmpty) return;

    int oldLv = player.lv;
    player.applyReward(reward);

    // 顯示獎勵細節
    if (isPenalty) {
      // 只有特殊事件才顯示損失訊息
      if (inSupportEvent) {
        addStructuredLog(LogType.penalty, "特殊事件損失: $reward");
      }
    } else {
      addStructuredLog(LogType.reward, "獲得: $reward", data: reward);
    }

    // 升級訊息
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
  // ===== 選擇 story 選項 =====
  void selectStoryOption(int index) {
    final event = currentEvent;
    Random rng = Random();
    selectedOptionIndex = index; // 記錄玩家選擇

    // ✅ 紀錄玩家的選項文字
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
  }
  // ===== 隨機給怪物事件分配題目 =====
  void assignRandomQuestionToMonster() {
    String? fillinHint; // 用來顯示提示文字
    if (currentEvent.type != "monster" || questions.isEmpty) return;
    
    // 隨機抽一題
    final randomEvent = questions[Random().nextInt(questions.length)];
    addStructuredLog(LogType.reward, "題目： ${randomEvent.question}", data: {"isQuestion": true});

    // 將題目掛到當前事件
    currentEvent.question = randomEvent.question;
    currentEvent.answer = randomEvent.answer;
    currentEvent.answerKeys = randomEvent.answerKeys;
    currentEvent.template = randomEvent.template;
    currentEvent.questionType = randomEvent.type;

    // 如果是 multiple_choice 題型且有 distractors
    if (randomEvent.distractors != null && randomEvent.distractors!.isNotEmpty) {
      // 複製 distractors，隨機挑選三個
      final List<String> distractorPool = List<String>.from(randomEvent.distractors!);
      distractorPool.shuffle();

      // 取前三個干擾答案
      final List<String> opts = distractorPool.take(3).toList();

      // 加上正確答案
      opts.add(randomEvent.answer);

      // 打亂四個選項順序
      opts.shuffle();

      // ===== 新增：根據玩家的 INS 來刪掉一個錯誤選項 =====
      double chance = player.ins / 100.0; // 假設 INS 滿分 100
      if (Random().nextDouble() < chance && opts.length > 2) {
        // 找出所有錯誤選項
        List<String> wrongOptions = opts.where((o) => o != randomEvent.answer).toList();
        if (wrongOptions.isNotEmpty) {
          // 隨機刪掉其中一個
          String removed = wrongOptions[Random().nextInt(wrongOptions.length)];
          opts.remove(removed);
          addStructuredLog(LogType.info, "洞察力 觸發提示：刪除了選項 '$removed'");
        }
      }

      currentEvent.options = opts;
    } else {
            double chance = player.ins / 100.0;
           if (Random().nextDouble() < chance) {
              // 假設 currentEvent (StoryEvent) 和 fillinHint 可以在此作用域直接存取
              
              // 檢查是否有答案可以提示
              if (currentEvent.answerKeys != null && currentEvent.answerKeys!.isNotEmpty) {
                  // 獲取所有可用的答案索引
                  List<int> availableIndices = List.generate(
                      currentEvent.answerKeys!.length, (i) => i);
                  
                  final int totalBlanks = availableIndices.length;
                  int allowedMaxHints;

                  // 1. 根據答案總數決定【實際允許的最大提示數】
                  if (totalBlanks <= 2) {
                      // 答案總數為 1 或 2 時，最多只提示 1 個 (防止直接送答案)
                      allowedMaxHints = 1;
                  } else {
                      // 答案總數為 3 個以上時，最多提示 2 個
                      allowedMaxHints = 2; 
                  }
                  
                  // 2. 確定最終要提示的數量 (取允許最大值和實際答案總數的最小值)
                  int hintsToPick = min(allowedMaxHints, totalBlanks); 

                  if (hintsToPick > 0) {
                      List<String> hints = [];

                      // 隨機挑選 hintsToPick 個不重複的答案
                      for (int i = 0; i < hintsToPick; i++) {
                          // 隨機選一個索引在 availableIndices 裡面
                          int pickIndex = Random().nextInt(availableIndices.length);
                          // 得到該答案在 currentEvent.answerKeys! 中的實際索引
                          int answerIndex = availableIndices[pickIndex];
                          
                          // 取得提示答案
                          String hint = currentEvent.answerKeys![answerIndex];
                          hints.add(hint);
                          
                          // 移除已選擇的索引，確保下次不會重複選到
                          availableIndices.removeAt(pickIndex);
                      }

                      String hintMessage;
                      if (hints.length == 2) {
                          hintMessage = "其中兩格答案是 '${hints[0]}' 和 '${hints[1]}'";
                      } else {
                          // hints.length == 1
                          hintMessage = "其中一格答案是 '${hints.first}'";
                      }

                      // 輸出 Log 訊息
                      addStructuredLog(LogType.info, "洞察力 觸發提示：$hintMessage");
                      
                      // 將第一個提示賦值給 fillinHint 供 UI 顯示用
                      fillinHint = hints.first;
                  }
              }
          }
            currentEvent.answerKeys = randomEvent.answerKeys;
          }
  }

  // ===== 下一個事件 =====
    void nextEvent({int optionIndex = 0}) {
      // 如果是支援事件，結束後直接清空支援事件，不回到前一個事件
      if (inSupportEvent) {
        inSupportEvent = false;
        nextSupportEvent = null;
        maybeInsertSupportEvent();
        if (nextSupportEvent != null) {
      // 如果又抽到，直接停留在新的支援事件
          return;
        }
        supportChainCount = 0;
        // 支援事件後的下一個事件就是 currentEventIndex 本身
        // 如果是怪物事件，檢查怪物是否死亡
        final current = currentEvent;
        final next = currentEvent;
        if (next.text != null && next.text!.isNotEmpty) {
                addStructuredLog(LogType.story, next.text!);
            }
        if (current.type == "monster" && currentMonster != null && !currentMonster!.isDead) {    
          currentMonster!.turnCounter = currentMonster!.turns;
          playerTurn = true;
          assignRandomQuestionToMonster();
        }
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
          final next = currentEvent;
          if (next.text != null && next.text!.isNotEmpty) {
            addStructuredLog(LogType.story, next.text!);
          }

          // 怪物事件初始化，若怪物已死就跳過
          if (next.type == "monster" && currentMonster != null && !currentMonster!.isDead) {
            currentMonster!.turnCounter = currentMonster!.turns;
            playerTurn = true;
            assignRandomQuestionToMonster();
      
          }
        }
      } else if (currentEventIndex < events.length - 1) {
        currentEventIndex++;
      } else {
        addStructuredLog(LogType.system, "無下一事件或章節結束");
      }
    }
}