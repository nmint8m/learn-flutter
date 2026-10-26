import 'package:flutter_test/flutter_test.dart';
// Only Environment: injectable also exports a `test` annotation, which would
// clash with flutter_test's test() function.
import 'package:injectable/injectable.dart' show Environment;
import 'package:manage_state_cubit_bloc/di/injection.dart';
import 'package:manage_state_cubit_bloc/sign_up/cubit/sign_up_cubit.dart';
import 'package:manage_state_cubit_bloc/sign_up/sign_up_repository.dart';

void main() {
  // get_it is global, so clear it after each test.
  tearDown(getIt.reset);

  group('configureDependencies', () {
    test('dev environment uses the 1-second fake repository', () {
      configureDependencies(environment: Environment.dev);

      expect(getIt<SignUpRepository>().delay, const Duration(seconds: 1));
    });

    test('test environment uses the instant repository', () {
      configureDependencies(environment: Environment.test);

      expect(getIt<SignUpRepository>().delay, Duration.zero);
    });

    test('@lazySingleton returns the same repository every time', () {
      configureDependencies(environment: Environment.test);

      expect(
        identical(getIt<SignUpRepository>(), getIt<SignUpRepository>()),
        isTrue,
      );
    });

    test('@injectable returns a new Cubit every time', () async {
      configureDependencies(environment: Environment.test);

      final first = getIt<SignUpCubit>();
      final second = getIt<SignUpCubit>();
      expect(identical(first, second), isFalse);

      await first.close();
      await second.close();
    });

    test('a test can swap in its own repository', () async {
      configureDependencies(environment: Environment.test);
      const custom = SignUpRepository(delay: Duration(milliseconds: 5));
      getIt
        ..unregister<SignUpRepository>()
        ..registerSingleton<SignUpRepository>(custom);

      expect(getIt<SignUpRepository>(), same(custom));
    });
  });
}
