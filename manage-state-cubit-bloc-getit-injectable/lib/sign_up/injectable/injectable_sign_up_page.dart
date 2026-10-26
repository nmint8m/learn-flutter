import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../di/injection.dart';
import '../cubit/sign_up_cubit.dart';
import '../sign_up_state.dart';
import '../view/sign_up_form_view.dart';

/// The same Cubit form as [CubitSignUpPage], with one difference: the Cubit
/// comes from get_it.
///
/// Compare the `create:` lines:
///
///     // Cubit tab: build it yourself, passing in what it needs
///     create: (context) => SignUpCubit(context.read<SignUpRepository>()),
///
///     // This tab: get_it builds it, and already knows the repository
///     create: (_) => getIt<SignUpCubit>(),
///
/// get_it creates the object, and BlocProvider still manages its lifetime (it
/// closes the Cubit when the page goes away). That's why SignUpCubit is
/// registered as a factory (`@injectable`) and not a singleton: a closed
/// singleton could not be reused.
class InjectableSignUpPage extends StatelessWidget {
  const InjectableSignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SignUpCubit>(),
      child: BlocBuilder<SignUpCubit, SignUpState>(
        builder: (context, state) {
          final cubit = context.read<SignUpCubit>();
          return SignUpFormView(
            state: state,
            onNameChanged: cubit.nameChanged,
            onEmailChanged: cubit.emailChanged,
            onPasswordChanged: cubit.passwordChanged,
            onTermsChanged: cubit.termsChanged,
            onSubmit: cubit.submit,
            onReset: cubit.reset,
          );
        },
      ),
    );
  }
}
