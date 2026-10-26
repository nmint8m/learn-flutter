import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

/// The app-wide get_it container. Ask it for an object with `getIt<Type>()`.
final getIt = GetIt.instance;

/// Registers every class annotated with `@injectable`, `@lazySingleton`, etc.
///
/// The body is generated: `getIt.init` lives in `injection.config.dart`, which
/// `build_runner` writes. After changing an annotation or a constructor of an
/// annotated class, regenerate it:
///
///     dart run build_runner build
///
/// [environment] picks which `@Environment` registrations are included (see
/// `repository_module.dart`).
@InjectableInit()
void configureDependencies({String environment = Environment.dev}) =>
    getIt.init(environment: environment);
