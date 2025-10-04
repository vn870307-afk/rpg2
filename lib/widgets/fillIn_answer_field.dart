import 'package:flutter/material.dart';
import 'package:rpg/models/ziwei_player_answer.dart';
import 'package:rpg/models/story_event.dart';

class ZiWeiFillInAnswerField extends StatefulWidget {
  final StoryEvent event;
  final void Function(ZiWeiPlayerAnswer) onSubmit;

  const ZiWeiFillInAnswerField({
    super.key,
    required this.event,
    required this.onSubmit,
  });

  @override
  State<ZiWeiFillInAnswerField> createState() => _ZiWeiFillInAnswerFieldState();
}

class _ZiWeiFillInAnswerFieldState extends State<ZiWeiFillInAnswerField> {
  late List<String?> selectedValues;
  late List<String> fieldTypes;
  late String displayTemplate;

  @override
  void initState() {
    super.initState();
    _initFields();
  }

  /// 🔑 初始化或重置欄位（新題目）
  void _initFields() {
    final result = widget.event.detectFieldTypesAndTemplate();
    displayTemplate = result['template'] as String;
    fieldTypes = List<String>.from(result['types'] as List);
    selectedValues = List.filled(fieldTypes.length, null);
    widget.event.template = displayTemplate;
  }

  /// 提交答案
  void _submitAnswer() {
    if (selectedValues.any((v) => v == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("請完成所有填空")),
      );
      return;
    }

    widget.onSubmit(ZiWeiPlayerAnswer(selectedValues.cast<String>()));
    // 提交後重置欄位，等待下一題
    setState(() {
      _initFields();
    });
  }

  @override
  Widget build(BuildContext context) {
    final parts = displayTemplate.split("___");
    final blanks = fieldTypes.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: List.generate(parts.length + blanks, (i) {
            if (i.isEven) {
              return Text(
                parts[i ~/ 2],
                style: const TextStyle(fontSize: 18),
              );
            } else {
              final blankIndex = i ~/ 2;
              if (blankIndex >= selectedValues.length || blankIndex >= fieldTypes.length) {
                return const SizedBox();
              }

              final options = _getOptionsForBlank(blankIndex);

              return SizedBox(
                width: 100,
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: selectedValues[blankIndex],
                  hint: const Text("選擇"),
                  items: options.map((opt) {
                    return DropdownMenuItem(
                      value: opt,
                      child: Text(opt),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedValues[blankIndex] = val;
                    });
                  },
                ),
              );
            }
          }),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _submitAnswer,
          child: const Text("提交答案"),
        ),
      ],
    );
  }

  List<String> _getOptionsForBlank(int index) {
    final type = fieldTypes[index];
    switch (type) {
      case "palace":
        return widget.event.palaceOptions ?? [];
      case "hua":
        return widget.event.huaOptions ?? [];
      default:
        return widget.event.options ?? [];
    }
  }
}
