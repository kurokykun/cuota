import 'package:cuota/features/profiles/domain/profile.dart';
import 'package:fluent_ui/fluent_ui.dart';

extension ProfileColorUi on ProfileColor {
  Color get color => switch (this) {
        ProfileColor.yellow => Colors.yellow,
        ProfileColor.orange => Colors.orange,
        ProfileColor.red => Colors.red,
        ProfileColor.magenta => Colors.magenta,
        ProfileColor.purple => Colors.purple,
        ProfileColor.blue => Colors.blue,
        ProfileColor.teal => Colors.teal,
        ProfileColor.green => Colors.green,
        ProfileColor.black => Colors.black,
        ProfileColor.grey => Colors.grey,
      };
}

/// Colors offered by the picker. The others are only kept for old profiles.
const pickableProfileColors = [
  ProfileColor.yellow,
  ProfileColor.orange,
  ProfileColor.red,
  ProfileColor.magenta,
  ProfileColor.purple,
  ProfileColor.blue,
  ProfileColor.teal,
  ProfileColor.green,
];
