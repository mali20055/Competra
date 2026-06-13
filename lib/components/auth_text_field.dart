import 'package:flutter/material.dart';

/// Auth ekranlarında kullanılan, üstte etiketli ve sol ikonlu form alanı.
///
/// Şifre alanları için [isPassword] `true` verilip [obscure] /
/// [onToggleObscure] ile göster/gizle düğmesi gösterilir. Hata mesajları
/// [TextFormField] tarafından alanın altında tema hata rengiyle gösterilir.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.obscure = false,
    this.onToggleObscure,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: isPassword && obscure,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            suffixIcon: isPassword
                ? IconButton(
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    tooltip: obscure ? 'Göster' : 'Gizle',
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
