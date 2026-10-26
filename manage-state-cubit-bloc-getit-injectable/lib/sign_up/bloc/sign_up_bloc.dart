import 'package:flutter_bloc/flutter_bloc.dart';

import '../sign_up_repository.dart';
import '../sign_up_state.dart';
import 'sign_up_event.dart';

export 'sign_up_event.dart';

/// Bloc version: the UI adds event objects, and a handler registered with
/// `on<Event>` turns each one into new states.
///
///     context.read<SignUpBloc>().add(SignUpEmailChanged('a@b.com'));
///
/// More code than [SignUpCubit], but every change is a named, traceable
/// event. That helps with logging and analytics, and with controlling timing
/// (debouncing, dropping duplicate submits) through event transformers.
class SignUpBloc extends Bloc<SignUpEvent, SignUpState> {
  SignUpBloc(this._repository) : super(const SignUpState()) {
    on<SignUpNameChanged>(
      (event, emit) =>
          emit(state.copyWith(name: event.name, status: SubmissionStatus.idle)),
    );
    on<SignUpEmailChanged>(
      (event, emit) => emit(
        state.copyWith(email: event.email, status: SubmissionStatus.idle),
      ),
    );
    on<SignUpPasswordChanged>(
      (event, emit) => emit(
        state.copyWith(password: event.password, status: SubmissionStatus.idle),
      ),
    );
    on<SignUpTermsChanged>(
      (event, emit) => emit(
        state.copyWith(
          acceptedTerms: event.accepted,
          status: SubmissionStatus.idle,
        ),
      ),
    );
    on<SignUpSubmitted>(_onSubmitted);
    on<SignUpReset>((event, emit) => emit(const SignUpState()));
  }

  final SignUpRepository _repository;

  Future<void> _onSubmitted(
    SignUpSubmitted event,
    Emitter<SignUpState> emit,
  ) async {
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
}
