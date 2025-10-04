// lib/story_event.dart

class StoryEvent {
  final String id;
  final String type; // "story", "multiple_choice", "input", "stat_check"
  final String? text;       // 故事敘述
  String? questionType;
  String? question;   // 題目

  String? template; // 填空題模板
  List<String>? answerKeys; // 填空題答案
  List<String>? palaceOptions; // 宮位選項
  List<String>? huaOptions; // 四化選項
  List<String>? options; // 選項

  List<String>? distractors; // 干擾選項（多選題才用）
  dynamic answer;     // 正確答案
  final Map<String, dynamic>? reward; // 獎勵 (ex: {"exp": 10})
  final Map<String, dynamic>? penalty; // 懲罰 (ex: {"hp": -10})
  final List<Map<String, dynamic>>? optionsReward; // 選項對應獎勵
  final List<Map<String, dynamic>>? optionsPenalty; // 選項對應懲罰
  final String? monsterId;
  final List<String>? nextEventIds;
  final Map<String, dynamic>? check;

  StoryEvent({
    required this.id,
    required this.type,
    this.questionType,
    this.text,
    this.question,
    this.template,
    this.answerKeys,
    this.palaceOptions,
    this.huaOptions,
    this.options,
    this.distractors,
    this.answer,
    this.reward,
    this.penalty,
    this.optionsReward,
    this.optionsPenalty,
    this.monsterId,
    this.nextEventIds,
    this.check,
  });

  factory StoryEvent.fromJson(Map<String, dynamic> json) {
    return StoryEvent(
      id: (json['id'] ?? 'unknown').toString(),
      type: (json['type'] ?? 'story').toString(),
      questionType: json['questionType']?.toString(),
      text: (json['text'] ?? '').toString(),
      question: (json['question'] ?? '').toString(),
      template: json['template']?.toString(),
      answerKeys: json['answerKeys'] != null
          ? List<String>.from((json['answerKeys'] as List).map((e) => e.toString()))
          : [],
      palaceOptions: ["命宮","兄弟宮","夫妻宮","子女宮","財帛宮","疾厄宮","遷移宮","交友宮","官祿宮","田宅宮","福德宮","父母宮"],
      huaOptions: ['祿','權','科','忌'],
      options: json['options'] != null
          ? List<String>.from((json['options'] as List).map((e) => e.toString()))
          : [],
      distractors: (json['distractors'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      answer: json['answer'] ?? '',
      reward: json['reward'] ?? {},
      penalty: json['penalty'] ?? {},
      optionsReward: json['optionsReward'] != null
          ? List<Map<String, dynamic>>.from(
              (json['optionsReward'] as List)
                  .map((e) => Map<String, dynamic>.from(e)))
          : [],
      optionsPenalty: json['optionsPenalty'] != null
          ? List<Map<String, dynamic>>.from(
              (json['optionsPenalty'] as List)
                  .map((e) => Map<String, dynamic>.from(e)))
          : [],
      monsterId: json['monsterId'],
      nextEventIds: (json['nextEventIds'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      check: json['check'] != null ? Map<String, dynamic>.from(json['check']) : null,
    );
  }
  /// 🔑 生成填空模板並返回每格的類型
  Map<String, dynamic> detectFieldTypesAndTemplate() {
    String textToProcess = template ?? '';
    List<String> types = [];

    if (textToProcess.isEmpty) return {'template': '', 'types': types};

    final palaceList = palaceOptions ?? [];
    final huaList = huaOptions ?? [];

    // 合併所有詞，標記類型
    final Map<String, String> wordTypeMap = {};
    for (var p in palaceList) wordTypeMap[p] = 'palace';
    for (var h in huaList) wordTypeMap[h] = 'hua';

    // 將所有詞按長度降序，避免部分匹配
    final allWords = wordTypeMap.keys.toList()..sort((a,b) => b.length.compareTo(a.length));

    final RegExp reg = RegExp(allWords.map(RegExp.escape).join('|'));

    int offset = 0;
    final matches = reg.allMatches(textToProcess).toList();
    StringBuffer buffer = StringBuffer();

    int lastIndex = 0;
    for (final m in matches) {
      buffer.write(textToProcess.substring(lastIndex, m.start));
      buffer.write('___');
      types.add(wordTypeMap[m.group(0)!]!);
      lastIndex = m.end;
    }
    buffer.write(textToProcess.substring(lastIndex));

    return {'template': buffer.toString(), 'types': types};
  }
  bool get hasHighRiskOption => check != null && options != null && options!.isNotEmpty;
}
