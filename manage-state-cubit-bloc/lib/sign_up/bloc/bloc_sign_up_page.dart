import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../sign_up_repository.dart';
import '../sign_up_state.dart';
import '../view/sign_up_form_view.dart';
import 'sign_up_bloc.dart';

class BlocSignUpPage extends StatelessWidget {
  const BlocSignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Same wiring as the Cubit page: BlocProvider creates and closes the Bloc,
    // and BlocBuilder rebuilds on every new state.
    return BlocProvider(
      create: (context) => SignUpBloc(context.read<SignUpRepository>()),
      child: BlocBuilder<SignUpBloc, SignUpState>(
        builder: (context, state) {
          final bloc = context.read<SignUpBloc>();
          // The difference: each callback adds an event instead of calling a
          // method.
          return SignUpFormView(
            state: state,
            onNameChanged: (value) => bloc.add(SignUpNameChanged(value)),
            onEmailChanged: (value) => bloc.add(SignUpEmailChanged(value)),
            onPasswordChanged: (value) =>
                bloc.add(SignUpPasswordChanged(value)),
            onTermsChanged: (value) => bloc.add(SignUpTermsChanged(value)),
            onSubmit: () => bloc.add(const SignUpSubmitted()),
            onReset: () => bloc.add(const SignUpReset()),
          );
        },
      ),
    );
  }
}
