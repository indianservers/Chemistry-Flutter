import 'package:flutter/material.dart';

Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String initial,
  required String confirm,
  int maxLength = 80,
}) => showDialog<String>(
  context: context,
  builder: (context) => _TextPrompt(
    title: title,
    initial: initial,
    confirm: confirm,
    maxLength: maxLength,
  ),
);

class _TextPrompt extends StatefulWidget {
  final String title, initial, confirm;
  final int maxLength;
  const _TextPrompt({
    required this.title,
    required this.initial,
    required this.confirm,
    required this.maxLength,
  });
  @override
  State<_TextPrompt> createState() => _PromptState();
}

class _PromptState extends State<_TextPrompt> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initial,
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.title),
    content: TextField(
      controller: controller,
      autofocus: true,
      maxLength: widget.maxLength,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final value = controller.text.trim();
          if (value.isNotEmpty) {
            Navigator.pop(context, value);
          }
        },
        child: Text(widget.confirm),
      ),
    ],
  );
}
