import 'package:flutter/material.dart';

typedef CredentialSubmitCallback =
    Future<void> Function(String username, String password);

/// The regular Flutter credential form used outside the web platform.
class CredentialLoginForm extends StatefulWidget {
  const CredentialLoginForm({
    required this.busy,
    required this.onSubmit,
    super.key,
  });

  final bool busy;
  final CredentialSubmitCallback onSubmit;

  @override
  State<CredentialLoginForm> createState() => _CredentialLoginFormState();
}

class _CredentialLoginFormState extends State<CredentialLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.busy || !_formKey.currentState!.validate()) return;
    await widget.onSubmit(_usernameController.text, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) => AutofillGroup(
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _usernameController,
            autofillHints: const [AutofillHints.username],
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter your username.'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            autofillHints: const [AutofillHints.password],
            autocorrect: false,
            enableSuggestions: false,
            obscureText: _obscurePassword,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) =>
                value == null || value.isEmpty ? 'Enter your password.' : null,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: widget.busy ? null : _submit,
              child: widget.busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Sign in'),
            ),
          ),
        ],
      ),
    ),
  );
}
