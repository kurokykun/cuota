import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the app is showing instead of the current profile.
enum AppPage { profile, changePassword, logs }

final appPageProvider =
    NotifierProvider<AppPageController, AppPage>(AppPageController.new);

class AppPageController extends Notifier<AppPage> {
  @override
  AppPage build() => AppPage.profile;

  void open(AppPage page) => state = page;

  void close() => state = AppPage.profile;
}
