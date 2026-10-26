// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:manage_state_cubit_bloc/di/repository_module.dart' as _i726;
import 'package:manage_state_cubit_bloc/sign_up/cubit/sign_up_cubit.dart'
    as _i744;
import 'package:manage_state_cubit_bloc/sign_up/sign_up_repository.dart'
    as _i696;

const String _dev = 'dev';
const String _test = 'test';

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final repositoryModule = _$RepositoryModule();
    gh.lazySingleton<_i696.SignUpRepository>(
      () => repositoryModule.repository,
      registerFor: {_dev},
    );
    gh.lazySingleton<_i696.SignUpRepository>(
      () => repositoryModule.instantRepository,
      registerFor: {_test},
    );
    gh.factory<_i744.SignUpCubit>(
      () => _i744.SignUpCubit(gh<_i696.SignUpRepository>()),
    );
    return this;
  }
}

class _$RepositoryModule extends _i726.RepositoryModule {}
