import 'package:injectable/injectable.dart';

import '../sign_up/sign_up_repository.dart';

/// A `@module` tells injectable how to build objects it can't build from a
/// constructor on its own.
///
/// [SignUpRepository] needs a `delay` value, and get_it has no `Duration`
/// registered, so we create the repository ourselves. Modules are also how
/// you register classes from other packages (e.g. `Dio`,
/// `SharedPreferences`), since you can't add annotations to their code.
@module
abstract class RepositoryModule {
  /// In the running app (environment `dev`): the 1-second fake request.
  ///
  /// `@lazySingleton` = one shared instance, created the first time something
  /// asks for it.
  @dev
  @lazySingleton
  SignUpRepository get repository => const SignUpRepository();

  /// In tests (environment `test`): the same type, but with no delay, so tests
  /// don't wait. Only one of these two is registered, depending on the
  /// environment passed to `configureDependencies`.
  @test
  @lazySingleton
  SignUpRepository get instantRepository =>
      const SignUpRepository(delay: Duration.zero);
}
