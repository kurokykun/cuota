import 'package:fluent_ui/fluent_ui.dart';

void showMessage(
  BuildContext context,
  String title, {
  InfoBarSeverity severity = InfoBarSeverity.info,
}) {
  displayInfoBar(context, builder: (context, close) {
    return InfoBar(
      title: Text(title),
      action: IconButton(
        icon: const Icon(
          FluentIcons.clear,
          size: 8,
        ),
        onPressed: close,
      ),
      severity: severity,
    );
  });
}
