import 'package:flutter/material.dart';

import '../sign_up_state.dart';

/// The form UI. It knows nothing about Cubit or Bloc: it draws a
/// [SignUpState] and reports what the user did through callbacks.
///
/// The Cubit page and the Bloc page both use this widget, so the only code
/// that differs between them is how the callbacks are wired up.
class SignUpFormView extends StatelessWidget {
  const SignUpFormView({
    super.key,
    required this.state,
    required this.onNameChanged,
    required this.onEmailChanged,
    required this.onPasswordChanged,
    required this.onTermsChanged,
    required this.onSubmit,
    required this.onReset,
  });

  final SignUpState state;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPasswordChanged;
  final ValueChanged<bool> onTermsChanged;
  final VoidCallback onSubmit;
  final VoidCallback onReset;

  /// Show a field's error once the user has typed in it, or after they tried
  /// to submit. Otherwise the form would open covered in red.
  String? _visibleError(String value, String? error) =>
      state.showAllErrors || value.isNotEmpty ? error : null;

  @override
  Widget build(BuildContext context) {
    if (state.status == SubmissionStatus.success) {
      return _SuccessView(name: state.name.trim(), onReset: onReset);
    }

    final theme = Theme.of(context);
    final enabled = !state.isSubmitting;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          key: const Key('nameField'),
          enabled: enabled,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Name',
            border: const OutlineInputBorder(),
            errorText: _visibleError(state.name, state.nameError),
          ),
          onChanged: onNameChanged,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('emailField'),
          enabled: enabled,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Email',
            border: const OutlineInputBorder(),
            errorText: _visibleError(state.email, state.emailError),
          ),
          onChanged: onEmailChanged,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('passwordField'),
          enabled: enabled,
          obscureText: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Password',
            helperText: 'At least 8 characters, including a number',
            border: const OutlineInputBorder(),
            errorText: _visibleError(state.password, state.passwordError),
          ),
          onChanged: onPasswordChanged,
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          key: const Key('termsCheckbox'),
          enabled: enabled,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: state.acceptedTerms,
          title: const Text('I accept the terms and conditions'),
          subtitle: state.showAllErrors && state.termsError != null
              ? Text(
                  state.termsError!,
                  style: TextStyle(color: theme.colorScheme.error),
                )
              : null,
          onChanged: (value) => onTermsChanged(value ?? false),
        ),
        if (state.status == SubmissionStatus.failure &&
            state.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            state.errorMessage!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('submitButton'),
          onPressed: enabled ? onSubmit : null,
          child: state.isSubmitting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Sign up'),
        ),
        const SizedBox(height: 24),
        Text(
          'Tip: sign up with taken@example.com to see an error.',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.name, required this.onReset});

  final String name;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome, $name!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onReset, child: const Text('Start over')),
          ],
        ),
      ),
    );
  }
}
