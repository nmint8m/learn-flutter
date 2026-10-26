import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../sign_up_repository.dart';
import '../sign_up_state.dart';

/// Cubit version: the UI calls plain methods, and each method calls [emit]
/// with the next state.
///
///     context.read<SignUpCubit>().emailChanged('a@b.com');
///
/// Less code than a Bloc, and the right choice for most forms.
///
/// `@injectable` registers this class with get_it as a factory: every
/// `getIt<SignUpCubit>()` returns a new Cubit. The generator reads the
/// constructor and fills in the [SignUpRepository] argument from get_it.
/// The annotation changes nothing when you call the constructor yourself, so
/// the Cubit tab still builds it by hand.
@injectable
class SignUpCubit extends Cubit<SignUpState> {
  SignUpCubit(this._repository) : super(const SignUpState());

  final SignUpRepository _repository;

  // Editing any field also moves the status back to idle, which clears an
  // earlier failure message.

  void nameChanged(String name) =>
      emit(state.copyWith(name: name, status: SubmissionStatus.idle));

  void emailChanged(String email) =>
      emit(state.copyWith(email: email, status: SubmissionStatus.idle));

  void passwordChanged(String password) =>
      emit(state.copyWith(password: password, status: SubmissionStatus.idle));

  void termsChanged(bool accepted) => emit(
    state.copyWith(acceptedTerms: accepted, status: SubmissionStatus.idle),
  );

  Future<void> submit() async {
    if (state.isSubmitting) return;
    if (!state.isValid) {
      emit(state.copyWith(showAllErrors: true));
      return;
    }

    emit(state.copyWith(status: SubmissionStatus.submitting));
    try {
      await _repository.signUp(
        name: state.name.trim(),
        email: state.email.trim(),
        password: state.password,
      );
      emit(state.copyWith(status: SubmissionStatus.success));
    } on EmailTakenException catch (e) {
      emit(
        state.copyWith(
          status: SubmissionStatus.failure,
          errorMessage: e.message,
        ),
      );
    }
  }

  void reset() => emit(const SignUpState());
}
