// lib/models/battle_log_entry.dart

import 'package:flutter/material.dart';

/// 戰鬥日誌的類型，用於決定顯示的顏色和圖示
enum LogType {
  playerAttack, // 玩家攻擊怪物
  damageTaken, // 玩家承受傷害
  correctAnswer, // 答對題目
  incorrectAnswer, // 答錯題目
  reward, // 獲得獎勵/升級
  penalty, // 受到懲罰/Debuff (例如 SAN 懲罰, 特殊事件損失)
  info, // 一般提示訊息 (例如回合提醒, 洞察力提示, 迴避)
  story, // 故事文本/事件選項
  system, // 遊戲系統訊息 (例如死亡, 章節結束, 錯誤)
}

class BattleLogEntry {
  final LogType type;
  final String message;
  final Map<String, dynamic>? data; // 可選的附加資料 (例如傷害值, 獎勵內容)

  BattleLogEntry({
    required this.type,
    required this.message,
    this.data,
  });

  /// 輔助方法：根據 LogType 取得顏色
  Color getColor() {
    switch (type) {
      case LogType.playerAttack:
        return Colors.redAccent;
      case LogType.damageTaken:
        return Colors.orange;
      case LogType.correctAnswer:
        return Colors.lightGreenAccent;
      case LogType.incorrectAnswer:
        return Colors.red;
      case LogType.reward:
        return Colors.white; // 獎勵或升級，用醒目的白色
      case LogType.penalty:
        return Colors.yellow; // 懲罰/Debuff
      case LogType.info:
        return Colors.cyan; // 提示訊息 (如題目, 洞察力)
      case LogType.story:
        return const Color.fromARGB(169, 178, 255, 89); // 故事/選項
      case LogType.system:
        return Colors.yellow; // 系統警告/死亡
      default:
        return Colors.grey.shade300;
    }
  }

  /// 輔助方法：根據 LogType 取得前綴圖示
  String getIcon() {
    switch (type) {
      case LogType.playerAttack:
        return "⚔️";
      case LogType.damageTaken:
        return "💔";
      case LogType.correctAnswer:
        return "✅";
      case LogType.incorrectAnswer:
        return "❌";
      case LogType.reward:
        return "✨";
      case LogType.penalty:
        return "⚠️";
      case LogType.info:
        return "💡";
      case LogType.story:
        return "📜";
      case LogType.system:
        return "⚙️";
      default:
        return "💬";
    }
  }

  /// 格式化輸出：圖示 + 訊息
  @override
  String toString() => "${getIcon()} $message";
}