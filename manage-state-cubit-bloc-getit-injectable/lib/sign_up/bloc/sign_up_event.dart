/// Everything that can happen to the form, as event objects.
///
/// `sealed` means the compiler knows the full list of events, and nothing
/// outside this file can add new ones.
sealed class SignUpEvent {
  const SignUpEvent();
}

final class SignUpNameChanged extends SignUpEvent {
  const SignUpNameChanged(this.name);
  final String name;
}

final class SignUpEmailChanged extends SignUpEvent {
  const SignUpEmailChanged(this.email);
  final String email;
}

final class SignUpPasswordChanged extends SignUpEvent {
  const SignUpPasswordChanged(this.password);
  final String password;
}

final class SignUpTermsChanged extends SignUpEvent {
  const SignUpTermsChanged(this.accepted);
  final bool accepted;
}

final class SignUpSubmitted extends SignUpEvent {
  const SignUpSubmitted();
}

final class SignUpReset extends SignUpEvent {
  const SignUpReset();
}
