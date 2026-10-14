/// A fake backend so the example has a real async call to wait on.
///
/// Signing up with `taken@example.com` always fails, so you can see how the
/// Cubit and the Bloc report an error.
class SignUpRepository {
  const SignUpRepository({this.delay = const Duration(seconds: 1)});

  final Duration delay;

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(delay);
    if (email.trim().toLowerCase() == 'taken@example.com') {
      throw const EmailTakenException();
    }
  }
}

class EmailTakenException implements Exception {
  const EmailTakenException();

  String get message => 'That email is already registered.';
}
