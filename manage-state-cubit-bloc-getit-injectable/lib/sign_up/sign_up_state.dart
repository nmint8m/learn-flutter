import 'package:equatable/equatable.dart';

enum SubmissionStatus { idle, submitting, success, failure }

/// The form state, shared by [SignUpCubit] and [SignUpBloc].
///
/// Both use exactly the same state class. The only difference between them is
/// how the UI asks for a change: a Cubit exposes methods, a Bloc receives
/// events.
///
/// It extends [Equatable] so two states with the same values are equal. That
/// lets the Cubit/Bloc skip emitting a state identical to the current one, and
/// makes tests easy to write.
class SignUpState extends Equatable {
  const SignUpState({
    this.name = '',
    this.email = '',
    this.password = '',
    this.acceptedTerms = false,
    this.showAllErrors = false,
    this.status = SubmissionStatus.idle,
    this.errorMessage,
  });

  final String name;
  final String email;
  final String password;
  final bool acceptedTerms;

  /// Becomes true after the user taps "Sign up" with invalid input, so errors
  /// appear even on fields they never typed in.
  final bool showAllErrors;

  final SubmissionStatus status;

  /// Set only when [status] is [SubmissionStatus.failure].
  final String? errorMessage;

  // Validation lives on the state as getters, so it can never get out of sync
  // with the values.

  String? get nameError {
    if (name.trim().isEmpty) return 'Name is required';
    if (name.trim().length < 2) return 'Name is too short';
    return null;
  }

  String? get emailError {
    if (email.trim().isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim())) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? get passwordError {
    if (password.isEmpty) return 'Password is required';
    if (password.length < 8) return 'Use at least 8 characters';
    if (!password.contains(RegExp(r'\d'))) return 'Include at least one number';
    return null;
  }

  String? get termsError => acceptedTerms ? null : 'You must accept the terms';

  bool get isValid =>
      nameError == null &&
      emailError == null &&
      passwordError == null &&
      termsError == null;

  bool get isSubmitting => status == SubmissionStatus.submitting;

  /// Note: [errorMessage] is not carried over. Any change clears it unless a
  /// new one is passed in.
  SignUpState copyWith({
    String? name,
    String? email,
    String? password,
    bool? acceptedTerms,
    bool? showAllErrors,
    SubmissionStatus? status,
    String? errorMessage,
  }) {
    return SignUpState(
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      showAllErrors: showAllErrors ?? this.showAllErrors,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    name,
    email,
    password,
    acceptedTerms,
    showAllErrors,
    status,
    errorMessage,
  ];
}
