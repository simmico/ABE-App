import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';
import '../../../../core/utils/input_sanitiser.dart';

/// Welcome, Sign In, and Registration screen for Aqeelah's Beauty Empire (ABE).
///
/// Built to the Warm Luxury ("Dusty Rose & Alabaster Studio") specification
/// using UK/South African English and zero em-dashes.
class WelcomeAuthScreen extends StatefulWidget {
  const WelcomeAuthScreen({
    super.key,
    required this.onAuthenticated,
    required this.onBrowseFeedDirectly,
  });

  final void Function({
    required String fullName,
    required String email,
    required bool isNewRegistration,
  }) onAuthenticated;

  final VoidCallback onBrowseFeedDirectly;

  @override
  State<WelcomeAuthScreen> createState() => _WelcomeAuthScreenState();
}

class _WelcomeAuthScreenState extends State<WelcomeAuthScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isRegisterMode = true;
  String? _statusMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitForm() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final cleanName = _isRegisterMode
        ? InputSanitiser.sanitiseText(_nameController.text, maxLength: 100)
        : 'ABE Member';
    final cleanEmail =
        InputSanitiser.sanitiseText(_emailController.text, maxLength: 140);

    setState(() {
      _statusMessage = null;
    });

    widget.onAuthenticated(
      fullName: cleanName.isEmpty ? 'ABE Member' : cleanName,
      email: cleanEmail,
      isNewRegistration: _isRegisterMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: BrandConfig.bgCream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildBrandHeader(textTheme),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: BrandConfig.surfaceCard,
                      borderRadius:
                          BorderRadius.circular(BrandConfig.largeCardRadius),
                      border: Border.all(color: BrandConfig.borderWarm),
                      boxShadow: BrandConfig.softCardShadow,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildModeSwitcher(),
                          const SizedBox(height: 24),
                          if (_isRegisterMode) ...<Widget>[
                            TextFormField(
                              key: const Key('auth_full_name_field'),
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                hintText: 'e.g. Zanele Ndlovu',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) {
                                final clean = InputSanitiser.sanitiseText(
                                  value ?? '',
                                  maxLength: 100,
                                );
                                if (clean.length < 2) {
                                  return 'Please enter your full name.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            key: const Key('auth_email_field'),
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'you@example.co.za',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: (value) {
                              final clean = InputSanitiser.sanitiseText(
                                value ?? '',
                                maxLength: 140,
                              );
                              if (!clean.contains('@') || !clean.contains('.')) {
                                return 'Please enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('auth_password_field'),
                            controller: _passwordController,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submitForm(),
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              hintText: 'Minimum 8 characters',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().length < 8) {
                                return 'Password must be at least 8 characters.';
                              }
                              return null;
                            },
                          ),
                          if (_statusMessage != null) ...<Widget>[
                            const SizedBox(height: 12),
                            Text(
                              _statusMessage!,
                              style: textTheme.bodyMedium?.copyWith(
                                color: BrandConfig.errorTerracotta,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          ElevatedButton(
                            key: const Key('auth_submit_button'),
                            onPressed: _submitForm,
                            child: Text(
                              _isRegisterMode
                                  ? 'Continue to Role & City Setup'
                                  : 'Sign In to Studio',
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            key: const Key('auth_browse_feed_button'),
                            onPressed: widget.onBrowseFeedDirectly,
                            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                            label: const Text(
                              'Explore CPT & JHB Visual Contracts',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSafetyAssuranceBanner(textTheme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader(TextTheme textTheme) {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: BrandConfig.blushSoft,
            borderRadius: BorderRadius.circular(BrandConfig.pillRadius),
            border: Border.all(color: BrandConfig.borderWarm),
          ),
          child: const Text(
            'CAPE TOWN (CPT) • JOHANNESBURG (JHB)',
            style: TextStyle(
              fontFamily: BrandConfig.bodyFontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: BrandConfig.roseDark,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          BrandConfig.appName,
          textAlign: TextAlign.center,
          style: textTheme.displayMedium,
        ),
        const SizedBox(height: 8),
        Text(
          BrandConfig.tagline,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildModeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BrandConfig.bgCream,
        borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
        border: Border.all(color: BrandConfig.borderWarm),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _ModeTabButton(
              key: const Key('auth_tab_register'),
              label: 'Create Account',
              isSelected: _isRegisterMode,
              onTap: () => setState(() => _isRegisterMode = true),
            ),
          ),
          Expanded(
            child: _ModeTabButton(
              key: const Key('auth_tab_sign_in'),
              label: 'Sign In',
              isSelected: !_isRegisterMode,
              onTap: () => setState(() => _isRegisterMode = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyAssuranceBanner(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandConfig.blushSoft,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(color: BrandConfig.borderWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.verified_user_outlined,
            color: BrandConfig.sageSuccess,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              BrandConfig.venueSafetyStatement,
              style: textTheme.bodyMedium?.copyWith(
                color: BrandConfig.espresso,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  const _ModeTabButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? BrandConfig.surfaceCard : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: BrandConfig.bodyFontFamily,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? BrandConfig.espresso : BrandConfig.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
