import 'package:cuota/core/providers.dart';
import 'package:cuota/features/account/data/http_account_repository.dart';
import 'package:cuota/features/account/domain/account.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final changePasswordProvider = Provider<ChangePassword>(
  (ref) => ChangePassword(HttpAccountRepository(
    client: ref.watch(httpClientProvider),
    certsDir: ref.watch(appPathsProvider).certsDir,
  )),
);
