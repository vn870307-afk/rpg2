class GameStats {
  int totalDamage = 0;        // 總輸出傷害
  int highestDamage = 0;      // 單次最高傷害
  int totalHealing = 0;       // 回復總量
  int totalDamageTaken = 0;   // 受到傷害
  int totalTurns = 0;         // 回合數
  int monstersKilled = 0;     // 擊殺數
  int totalQuestions = 0;     // 題目總數
  int correctAnswers = 0;     // 答題正確數

  double get accuracy =>
      totalQuestions == 0 ? 0 : (correctAnswers / totalQuestions) * 100;

  void reset() {
    totalDamage = 0;
    highestDamage = 0;
    totalHealing = 0;
    totalDamageTaken = 0;
    totalTurns = 0;
    monstersKilled = 0;
    totalQuestions = 0;
    correctAnswers = 0;
  }

  Map<String, dynamic> toMap() => {
        "🗡️ 總輸出傷害": totalDamage,
        "💥 單次最高傷害": highestDamage,
        "❤️ 回復總量": totalHealing,
        "🩸 受到傷害": totalDamageTaken,
        "⚔️ 擊殺怪物數": monstersKilled,
        "🔁 回合數": totalTurns,
        "🧮 答題正確率": "${accuracy.toStringAsFixed(1)}%",
      };
}
