import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manage_state_cubit_bloc/sign_up/bloc/sign_up_bloc.dart';
import 'package:manage_state_cubit_bloc/sign_up/sign_up_repository.dart';
import 'package:manage_state_cubit_bloc/sign_up/sign_up_state.dart';

const _repository = SignUpRepository(delay: Duration.zero);

const _validForm = SignUpState(
  name: 'Kayla',
  email: 'kayla@example.com',
  password: 'secret123',
  acceptedTerms: true,
);

// The same scenarios as sign_up_cubit_test.dart, driven by events instead of
// method calls. The expected states are identical.
void main() {
  group('SignUpBloc', () {
    test('starts with an empty form', () {
      expect(SignUpBloc(_repository).state, const SignUpState());
    });

    blocTest<SignUpBloc, SignUpState>(
      'updates fields from change events',
      build: () => SignUpBloc(_repository),
      act: (bloc) => bloc
        ..add(const SignUpNameChanged('Kayla'))
        ..add(const SignUpTermsChanged(true)),
      expect: () => [
        const SignUpState(name: 'Kayla'),
        const SignUpState(name: 'Kayla', acceptedTerms: true),
      ],
    );

    blocTest<SignUpBloc, SignUpState>(
      'shows all errors instead of submitting an invalid form',
      build: () => SignUpBloc(_repository),
      act: (bloc) => bloc.add(const SignUpSubmitted()),
      expect: () => [const SignUpState(showAllErrors: true)],
    );

    blocTest<SignUpBloc, SignUpState>(
      'goes submitting -> success for a valid form',
      build: () => SignUpBloc(_repository),
      seed: () => _validForm,
      act: (bloc) => bloc.add(const SignUpSubmitted()),
      expect: () => [
        _validForm.copyWith(status: SubmissionStatus.submitting),
        _validForm.copyWith(status: SubmissionStatus.success),
      ],
    );

    blocTest<SignUpBloc, SignUpState>(
      'goes submitting -> failure when the email is taken',
      build: () => SignUpBloc(_repository),
      seed: () => _validForm.copyWith(email: 'taken@example.com'),
      act: (bloc) => bloc.add(const SignUpSubmitted()),
      expect: () => [
        _validForm.copyWith(
          email: 'taken@example.com',
          status: SubmissionStatus.submitting,
        ),
        _validForm.copyWith(
          email: 'taken@example.com',
          status: SubmissionStatus.failure,
          errorMessage: 'That email is already registered.',
        ),
      ],
    );

    blocTest<SignUpBloc, SignUpState>(
      'ignores a second submit while the first is in progress',
      build: () => SignUpBloc(_repository),
      seed: () => _validForm,
      act: (bloc) => bloc
        ..add(const SignUpSubmitted())
        ..add(const SignUpSubmitted()),
      expect: () => [
        _validForm.copyWith(status: SubmissionStatus.submitting),
        _validForm.copyWith(status: SubmissionStatus.success),
      ],
    );
  });
}
