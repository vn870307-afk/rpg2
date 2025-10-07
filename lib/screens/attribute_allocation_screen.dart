import 'package:flutter/material.dart';
import '../models/player.dart';

class AttributeAllocationScreen extends StatefulWidget {
  final Player player;
  const AttributeAllocationScreen({super.key, required this.player});

  @override
  State<AttributeAllocationScreen> createState() => _AttributeAllocationScreenState();
}

class _AttributeAllocationScreenState extends State<AttributeAllocationScreen> {
  late Map<String, int> tempPoints;
  // 英文 key 對應中文名稱
  final Map<String, String> keyToChinese = {
    'STR': '力量',
    'VIT': '堅毅',
    'INT': '智力',
    'DEX': '敏捷',
    'CHA': '魅力',
    'LUK': '幸運',
  };

  @override
  void initState() {
    super.initState();
    tempPoints = {
      'STR': 0,
      'VIT': 0,
      'INT': 0,
      'DEX': 0,
      'CHA': 0,
      'LUK': 0,
    };
  }

  int get remainingPoints {
    int sum = tempPoints.values.reduce((a, b) => a + b);
    return widget.player.unallocatedPoints - sum;
  }

  Map<String, num> calculateBattlePreview() {
    return {
      '血量上限': widget.player.maxhp +
          ((tempPoints['STR']! * 3).round() + tempPoints['VIT']! * 6),
      '攻擊': widget.player.atk + tempPoints['STR']! * 2 + tempPoints['INT']! * 1.5,
      '防禦': widget.player.def + tempPoints['VIT']! * 1.5,
      '迴避率': widget.player.agi + tempPoints['CHA']! * 1.2 + tempPoints['LUK']! * 1.2,
      '暴擊率': widget.player.ct + tempPoints['LUK']! * 2 + tempPoints['DEX']! * 1.5,
      '速度': widget.player.spd + tempPoints['DEX']! * 1.5,
      '洞察力': widget.player.ins + tempPoints['INT']! * 2,
      '特殊事件': widget.player.SupportEvent + tempPoints['CHA']! * 2,
      'SAN值': widget.player.SAN + tempPoints['VIT']! * 0.2 + tempPoints['INT']! * 0.2 + tempPoints['STR']! * 0.2,
    };
  }

  void resetPoints() {
    setState(() {
      tempPoints = {for (var k in tempPoints.keys) k: 0};
    });
  }

  void confirmPoints() {
    widget.player.allocatePoints(
      strPoints: tempPoints['STR']!,
      vitPoints: tempPoints['VIT']!,
      inttPoints: tempPoints['INT']!,
      dexPoints: tempPoints['DEX']!,
      chaPoints: tempPoints['CHA']!,
      lukPoints: tempPoints['LUK']!,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Map<String, num> preview = calculateBattlePreview();

    return Scaffold(
      appBar: AppBar(
        title: Text("分配能力點 (剩餘: $remainingPoints)"),
        backgroundColor: const Color.fromARGB(255, 200, 190, 180),
        elevation: 2,
        toolbarHeight: 30.0,
      ),
      backgroundColor: const Color.fromARGB(255, 230, 224, 224),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 六個基礎能力值
            Expanded(
              child: ListView(
                children: tempPoints.keys.map((key) {
                  int base;
                  switch (key) {
                    case 'STR':
                      base = widget.player.str;
                      break;
                    case 'VIT':
                      base = widget.player.vit;
                      break;
                    case 'INT':
                      base = widget.player.intt;
                      break;
                    case 'DEX':
                      base = widget.player.dex;
                      break;
                    case 'CHA':
                      base = widget.player.cha;
                      break;
                    case 'LUK':
                      base = widget.player.luk;
                      break;
                    default:
                      base = 0;
                  }

                  int increase = tempPoints[key]!;
                  int displayValue = base + increase;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          "${keyToChinese[key]}: $displayValue",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: increase > 0 ? Colors.red : Colors.black,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              onPressed: remainingPoints > 0
                                  ? () {
                                      setState(() {
                                        tempPoints[key] = tempPoints[key]! + 1;
                                      });
                                    }
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove, size: 20),
                              onPressed: increase > 0
                                  ? () {
                                      setState(() {
                                        tempPoints[key] = tempPoints[key]! - 1;
                                      });
                                    }
                                  : null,
                            ),
                            if (increase > 0)
                              Text("+$increase",
                                  style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text("戰鬥能力值預覽",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: preview.entries.map((e) {
                num originalValue;
                switch (e.key) {
                  case '血量上限':
                    originalValue = widget.player.maxhp;
                    break;
                  case '攻擊':
                    originalValue = widget.player.atk;
                    break;
                  case '防禦':
                    originalValue = widget.player.def;
                    break;
                  case '迴避率':
                    originalValue = widget.player.agi;
                    break;
                  case '暴擊率':
                    originalValue = widget.player.ct;
                    break;
                  case '速度':
                    originalValue = widget.player.spd;
                    break;
                  case '洞察力':
                    originalValue = widget.player.ins;
                    break;
                  case '特殊事件':
                    originalValue = widget.player.SupportEvent;
                    break;
                  case 'SAN值':
                    originalValue = widget.player.SAN;
                    break;
                  default:
                    originalValue = 0;
                }
                num diff = e.value - originalValue;
                return Text(
                  "${e.key}: ${e.value.toStringAsFixed(1)}" +
                      (diff > 0 ? " (+${diff.toStringAsFixed(1)})" : ""),
                  style: TextStyle(color: diff > 0 ? Colors.red : Colors.black),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: resetPoints,
                  child: const Text("重置"),
                ),
                ElevatedButton(
                  onPressed: confirmPoints,
                  child: const Text("確認"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
