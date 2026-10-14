import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manage_state_cubit_bloc/sign_up/cubit/sign_up_cubit.dart';
import 'package:manage_state_cubit_bloc/sign_up/sign_up_repository.dart';
import 'package:manage_state_cubit_bloc/sign_up/sign_up_state.dart';

const _repository = SignUpRepository(delay: Duration.zero);

const _validForm = SignUpState(
  name: 'Kayla',
  email: 'kayla@example.com',
  password: 'secret123',
  acceptedTerms: true,
);

void main() {
  group('SignUpCubit', () {
    test('starts with an empty form', () {
      expect(SignUpCubit(_repository).state, const SignUpState());
    });

    blocTest<SignUpCubit, SignUpState>(
      'updates the email when it changes',
      build: () => SignUpCubit(_repository),
      act: (cubit) => cubit.emailChanged('a@b.com'),
      expect: () => [const SignUpState(email: 'a@b.com')],
    );

    blocTest<SignUpCubit, SignUpState>(
      'shows all errors instead of submitting an invalid form',
      build: () => SignUpCubit(_repository),
      act: (cubit) => cubit.submit(),
      expect: () => [const SignUpState(showAllErrors: true)],
    );

    blocTest<SignUpCubit, SignUpState>(
      'goes submitting -> success for a valid form',
      build: () => SignUpCubit(_repository),
      seed: () => _validForm,
      act: (cubit) => cubit.submit(),
      expect: () => [
        _validForm.copyWith(status: SubmissionStatus.submitting),
        _validForm.copyWith(status: SubmissionStatus.success),
      ],
    );

    blocTest<SignUpCubit, SignUpState>(
      'goes submitting -> failure when the email is taken',
      build: () => SignUpCubit(_repository),
      seed: () => _validForm.copyWith(email: 'taken@example.com'),
      act: (cubit) => cubit.submit(),
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

    blocTest<SignUpCubit, SignUpState>(
      'reset clears the form',
      build: () => SignUpCubit(_repository),
      seed: () => _validForm.copyWith(status: SubmissionStatus.success),
      act: (cubit) => cubit.reset(),
      expect: () => [const SignUpState()],
    );
  });

  group('SignUpState validation', () {
    test('rejects a short password and one without a number', () {
      expect(
        const SignUpState(password: 'abc1').passwordError,
        'Use at least 8 characters',
      );
      expect(
        const SignUpState(password: 'abcdefgh').passwordError,
        'Include at least one number',
      );
      expect(const SignUpState(password: 'abcdefg1').passwordError, isNull);
    });

    test('rejects a malformed email', () {
      expect(
        const SignUpState(email: 'kayla@').emailError,
        'Enter a valid email',
      );
    });

    test('a complete form is valid', () {
      expect(_validForm.isValid, isTrue);
      expect(_validForm.copyWith(acceptedTerms: false).isValid, isFalse);
    });
  });
}
