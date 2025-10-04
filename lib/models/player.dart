import 'dart:math';
import 'package:flutter/material.dart';

class Player {
  // ===== 基礎能力值 =====
  int hp;
  int exp;
  int lv;
  int unallocatedPoints;

  int str;
  int vit;
  int intt;
  int dex;
  int cha;
  int luk;
  int sanBase;

  static const int totalPoints = 12;
  VoidCallback? onDeath;

  // ===== 暫時 Debuff 狀態 =====
  Map<String, int> tempDebuff = {};     // 屬性減值
  Map<String, int> debuffDuration = {}; // 屬性減值持續回合數

  Player({
    this.hp = 100,
    this.exp = 0,
    this.lv = 1,
    this.unallocatedPoints = 0,
    this.str = 0,
    this.vit = 0,
    this.intt = 0,
    this.dex = 0,
    this.cha = 0,
    this.luk = 0,
    this.sanBase = 90,
  }) {
    rollDiceForStats();
  }

  // ===== 實際值（包含暫時 Debuff） =====
  int getEffective(String stat) {
    int baseValue;
    switch (stat) {
      case "str": baseValue = str; break;
      case "vit": baseValue = vit; break;
      case "intt": baseValue = intt; break;
      case "dex": baseValue = dex; break;
      case "cha": baseValue = cha; break;
      case "luk": baseValue = luk; break;
      case "sanBase": baseValue = sanBase; break;
      default: baseValue = 0; break;
    }
    return baseValue - (tempDebuff[stat] ?? 0);
  }

  // ===== 動態戰鬥能力值 (getter, 自動吃 Debuff) =====
  int get maxhp => 100 + (getEffective("str") * 1.5).round() + getEffective("vit") * 2;
  num get atk => 40 + getEffective("str") * 2 + getEffective("intt") * 1.5;
  num get def => getEffective("vit") * 1.5;
  num get agi => 10 + getEffective("cha") * 1.2 + getEffective("luk") * 1.2;
  num get ct  => 10 + getEffective("luk") * 2 + getEffective("dex") * 1.5;
  num get spd => 10 + getEffective("dex") * 1.5;
  num get ins => 30 + getEffective("intt") * 2;
  num get SupportEvent => 20 + getEffective("cha") * 2;
  int get SAN => sanBase +
      (getEffective("vit") * 0.2).round() +
      (getEffective("intt") * 0.2).round() +
      (getEffective("str") * 0.2).round();

  // 【✨ 新增：未被 Debuff 影響的戰鬥能力值】
  num getUnmodifiedAtk() => 40 + str * 2 + intt * 1.5;
  num getUnmodifiedDef() => vit * 1.5;
  num getUnmodifiedAgi() => 10 + cha * 1.2 + luk * 1.2;
  num getUnmodifiedCt() => 10 + luk * 2 + dex * 1.5;
  num getUnmodifiedSpd() => 10 + dex * 1.5;
  num getUnmodifiedIns() => 30 + intt * 2;
  num getUnmodifiedSupportEvent() => 20 + cha * 2;
  // ----------------------------------------------------

  // ===== 隨機初始分配 =====
  void rollDiceForStats() {
    int remainingPoints = totalPoints;
    List<String> stats = ["str", "vit", "intt", "dex", "cha", "luk"];
    Random rng = Random();

    str = vit = intt = dex = cha = luk = 0;

    while (remainingPoints > 0) {
      String stat = stats[rng.nextInt(stats.length)];
      int roll = rng.nextInt(3) + 1;
      roll = roll > remainingPoints ? remainingPoints : roll;
      remainingPoints -= roll;

      switch (stat) {
        case "str": str += roll; break;
        case "vit": vit += roll; break;
        case "intt": intt += roll; break;
        case "dex": dex += roll; break;
        case "cha": cha += roll; break;
        case "luk": luk += roll; break;
      }
    }
  }

  // ===== 奬勵 =====
  void applyReward(Map<String, dynamic>? reward) {
    if (reward == null) return;
    // HP 獎勵限制在 maxHp
    hp += ((reward["hp"] ?? 0) as num).toInt();
    if (hp > maxhp) hp = maxhp;
    exp += (reward["exp"] ?? 0) as int;
    str += (reward["str"] ?? 0) as int;
    vit += (reward["vit"] ?? 0) as int;
    intt += (reward["intt"] ?? 0) as int;
    dex += (reward["dex"] ?? 0) as int;
    cha += (reward["cha"] ?? 0) as int;
    luk += (reward["luk"] ?? 0) as int;
    sanBase += (reward["SAN"] ?? 0) as int;
    if (sanBase < 0) sanBase = 0;

    // 檢查升級
    while (exp >= 100) {
      exp -= 100;
      lv++;
      unallocatedPoints += 5;
    }

    // ===== 檢查死亡 =====
    if (hp <= 0) {
      hp = 0;
      if (onDeath != null) onDeath!();
    }
  }

  // ===== 暫時 Debuff =====
  void applyTempDebuff(Map<String, int> debuff, int turns) {
    debuff.forEach((key, value) {
      tempDebuff[key] = (tempDebuff[key] ?? 0) + value;
      debuffDuration[key] = turns;
    });
  }

  void updateDebuff() {
    List<String> toRemove = [];
    debuffDuration.forEach((key, value) {
      debuffDuration[key] = value - 1;
      if (debuffDuration[key]! <= 0) {
        tempDebuff.remove(key);
        toRemove.add(key);
      }
    });
    for (var key in toRemove) {
      debuffDuration.remove(key);
    }
  }

  // ===== 分配點數 =====
  void allocatePoints({
    int strPoints = 0,
    int vitPoints = 0,
    int inttPoints = 0,
    int dexPoints = 0,
    int chaPoints = 0,
    int lukPoints = 0,
  }) {
    int total = strPoints + vitPoints + inttPoints + dexPoints + chaPoints + lukPoints;
    if (total > unallocatedPoints) {
      return;
    }

    str += strPoints;
    vit += vitPoints;
    intt += inttPoints;
    dex += dexPoints;
    cha += chaPoints;
    luk += lukPoints;

    unallocatedPoints -= total;
  }
}
