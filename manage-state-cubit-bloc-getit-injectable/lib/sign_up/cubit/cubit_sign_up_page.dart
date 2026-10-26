import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../sign_up_repository.dart';
import '../sign_up_state.dart';
import '../view/sign_up_form_view.dart';
import 'sign_up_cubit.dart';

class CubitSignUpPage extends StatelessWidget {
  const CubitSignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    // BlocProvider creates the Cubit, makes it available to everything below,
    // and closes it automatically when this page is removed.
    return BlocProvider(
      create: (context) => SignUpCubit(context.read<SignUpRepository>()),
      // BlocBuilder rebuilds the form every time the Cubit emits a new state.
      child: BlocBuilder<SignUpCubit, SignUpState>(
        builder: (context, state) {
          // context.read gets the Cubit without listening, which is all a
          // callback needs.
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
