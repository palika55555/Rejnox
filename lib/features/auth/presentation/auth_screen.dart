import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/rejnox_mark.dart';
import '../../../core/widgets/tm_card.dart';
import '../domain/auth_models.dart';
import 'auth_controller.dart';

/// Prihlásenie alebo registrácia (podľa [register]).
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.register = false});

  final bool register;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.member;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authControllerProvider.notifier);
    try {
      if (widget.register) {
        await auth.register(
          email: _email.text.trim(),
          password: _password.text,
          displayName: _name.text.trim(),
          role: _role,
        );
      } else {
        await auth.login(email: _email.text.trim(), password: _password.text);
      }
      // Po úspechu presmeruje router.
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final register = widget.register;
    return AppBackground(
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: _GlowingMark()),
                        const SizedBox(height: 18),
                        Text(
                          'REJNOX',
                          textAlign: TextAlign.center,
                          style: text.headlineMedium!.copyWith(
                            letterSpacing: 10,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'LEPŠÍ POHYB. SILNEJŠÍ TY.',
                          textAlign: TextAlign.center,
                          style: text.labelSmall!.copyWith(letterSpacing: 3),
                        ),
                        const SizedBox(height: 32),
                        TmCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                register ? 'VYTVOR SI ÚČET' : 'VITAJ SPÄŤ',
                                style: text.headlineMedium,
                              ),
                              const SizedBox(height: 18),
                              if (register) ...[
                                TextFormField(
                                  controller: _name,
                                  textInputAction: TextInputAction.next,
                                  textCapitalization: TextCapitalization.words,
                                  autofillHints: const [AutofillHints.name],
                                  decoration: const InputDecoration(
                                    labelText: 'Meno',
                                  ),
                                  validator: (v) {
                                    final name = (v ?? '').trim();
                                    return name.isEmpty || name.length > 60
                                        ? 'Zadaj meno (najviac 60 znakov).'
                                        : null;
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  labelText: 'E-mail',
                                ),
                                validator: (v) =>
                                    RegExp(
                                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                    ).hasMatch((v ?? '').trim())
                                    ? null
                                    : 'Zadaj platný e-mail.',
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _password,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                autofillHints: [
                                  register
                                      ? AutofillHints.newPassword
                                      : AutofillHints.password,
                                ],
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Heslo',
                                  helperText: register
                                      ? 'Aspoň 8 znakov.'
                                      : null,
                                ),
                                validator: (v) {
                                  final length = (v ?? '').length;
                                  if (length == 0) return 'Zadaj heslo.';
                                  if (register && (length < 8 || length > 72)) {
                                    return 'Heslo musí mať 8 až 72 znakov.';
                                  }
                                  return null;
                                },
                              ),
                              if (register) ...[
                                const SizedBox(height: 16),
                                const SectionLabel('Ako budeš appku používať?'),
                                const SizedBox(height: 8),
                                _RolePicker(
                                  selected: _role,
                                  onChanged: (role) =>
                                      setState(() => _role = role),
                                ),
                              ],
                              if (_error != null) ...[
                                const SizedBox(height: 14),
                                Text(
                                  _error!,
                                  style: text.bodyMedium!.copyWith(
                                    color: Plate.red.color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              PrimaryButton(
                                label: _busy
                                    ? 'Chvíľu strpenia…'
                                    : register
                                    ? 'Vytvoriť účet'
                                    : 'Prihlásiť sa',
                                onPressed: _busy ? null : _submit,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => context.go(
                                  register ? '/login' : '/register',
                                ),
                          child: Text(
                            register
                                ? 'Už mám účet. Prihlásiť sa'
                                : 'Nemám účet. Zaregistrovať sa',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.selected, required this.onChanged});

  final UserRole selected;
  final ValueChanged<UserRole> onChanged;

  static const _options = [
    (
      role: UserRole.member,
      label: 'Cvičím',
      icon: Icons.fitness_center_rounded,
    ),
    (role: UserRole.trainer, label: 'Som tréner', icon: Icons.sports_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        for (final option in _options) ...[
          if (option != _options.first) const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              button: true,
              selected: option.role == selected,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onChanged(option.role),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: option.role == selected
                        ? AppColors.accent.withValues(alpha: 0.12)
                        : AppColors.bg.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: option.role == selected
                          ? AppColors.accent
                          : AppColors.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        option.icon,
                        size: 20,
                        color: option.role == selected
                            ? AppColors.accent
                            : AppColors.muted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option.label,
                        style: text.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Logo s fialovou žiarou za ním.
class _GlowingMark extends StatelessWidget {
  const _GlowingMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            AppColors.violet.withValues(alpha: 0.45),
            AppColors.violet.withValues(alpha: 0),
          ],
        ),
      ),
      child: const RejnoxMark(width: 96),
    );
  }
}
