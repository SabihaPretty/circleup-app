import 'package:flutter/material.dart';
import '../../core/access_control.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../main/main_shell.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class MonthItem {
  final int value;
  final String name;

  const MonthItem(this.value, this.name);
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool loading = false;

  String identityMode = 'email';
  bool verificationSent = false;
  bool verificationVerified = false;

  final nameController = TextEditingController();
  final nicknameController = TextEditingController();
  final birthYearController = TextEditingController(text: '2000');
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final verificationCodeController = TextEditingController();

  int selectedMonth = 1;
  int selectedDay = 1;
  String? verificationToken;

  final months = const [
    MonthItem(1, 'January'),
    MonthItem(2, 'February'),
    MonthItem(3, 'March'),
    MonthItem(4, 'April'),
    MonthItem(5, 'May'),
    MonthItem(6, 'June'),
    MonthItem(7, 'July'),
    MonthItem(8, 'August'),
    MonthItem(9, 'September'),
    MonthItem(10, 'October'),
    MonthItem(11, 'November'),
    MonthItem(12, 'December'),
  ];

  @override
  void dispose() {
    nameController.dispose();
    nicknameController.dispose();
    birthYearController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    verificationCodeController.dispose();
    super.dispose();
  }

  int get birthYear => int.tryParse(birthYearController.text.trim()) ?? 2000;

  int get maxDay => DateTime(birthYear, selectedMonth + 1, 0).day;

  String get emailOrPhone {
    if (identityMode == 'email') return emailController.text.trim();
    return phoneController.text.trim();
  }

  String get autoAgeGroup {
    return AccessControl.calculateAgeGroupFromDate(
      birthYear: birthYear,
      birthMonth: selectedMonth,
      birthDay: selectedDay,
    );
  }

  int get autoAge {
    return AccessControl.calculateAge(
      birthYear: birthYear,
      birthMonth: selectedMonth,
      birthDay: selectedDay,
    );
  }

  bool get requiresVerification {
    return autoAgeGroup == 'adult' || autoAgeGroup == 'senior';
  }

  bool get emailValid {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
        .hasMatch(emailController.text.trim());
  }

  bool get phoneValid {
    final clean = phoneController.text.trim().replaceAll(RegExp(r'[\s-]'), '');
    return RegExp(r'^\+?[0-9]{10,15}$').hasMatch(clean);
  }

  bool get identityValid => identityMode == 'email' ? emailValid : phoneValid;

  bool get passwordValid => passwordController.text.trim().length >= 6;

  bool get confirmPasswordValid {
    return passwordController.text.trim() ==
        confirmPasswordController.text.trim();
  }

  String get birthDateText {
    final month = selectedMonth.toString().padLeft(2, '0');
    final day = selectedDay.toString().padLeft(2, '0');
    return '$birthYear-$month-$day';
  }

  int get passwordScore {
    final password = passwordController.text;
    var score = 0;

    if (password.length >= 6) score++;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=]').hasMatch(password)) score++;

    return score;
  }

  String get passwordStrengthLabel {
    if (passwordController.text.isEmpty) return 'Empty';
    if (passwordController.text.length < 6) return 'Too short';
    if (passwordScore <= 2) return 'Weak';
    if (passwordScore <= 4) return 'Medium';
    return 'Strong';
  }

  Color get passwordStrengthColor {
    if (passwordController.text.length < 6) return Colors.red;
    if (passwordScore <= 2) return Colors.red;
    if (passwordScore <= 4) return AppTheme.warning;
    return AppTheme.success;
  }

  double get passwordStrengthValue {
    if (passwordController.text.isEmpty) return 0;
    return (passwordScore / 6).clamp(0.0, 1.0);
  }

  void resetVerification() {
    verificationSent = false;
    verificationVerified = false;
    verificationToken = null;
    verificationCodeController.clear();
  }

  void fixSelectedDay() {
    final lastDay = maxDay;

    if (selectedDay > lastDay) {
      selectedDay = lastDay;
    }
  }

  Future<void> sendVerificationCode() async {
    if (!identityValid) {
      showMessage(identityMode == 'email'
          ? 'Enter a valid email address.'
          : 'Enter a valid phone number.');
      return;
    }

    if (!passwordValid) {
      showMessage('Password must be at least 6 characters.');
      return;
    }

    setState(() => loading = true);

    try {
      final result = await ApiService.post('/auth/send-verification', {
        'emailOrPhone': emailOrPhone,
        'birthYear': birthYear,
        'birthMonth': selectedMonth,
        'birthDay': selectedDay,
      });

      verificationSent = result['requiresVerification'] == true;
      verificationVerified = false;
      verificationToken = null;
      verificationCodeController.clear();

      if (!mounted) return;
      setState(() => loading = false);

      showMessage(result['message'] ?? 'Verification code sent.');
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showMessage('Verification send failed: $e');
    }
  }

  Future<void> verifyCode() async {
    if (!verificationSent) {
      showMessage('Send verification code first.');
      return;
    }

    if (verificationCodeController.text.trim().isEmpty) {
      showMessage('Enter verification code.');
      return;
    }

    setState(() => loading = true);

    try {
      final result = await ApiService.post('/auth/verify-code', {
        'emailOrPhone': emailOrPhone,
        'code': verificationCodeController.text.trim(),
      });

      verificationToken = result['verificationToken'];
      verificationVerified = true;

      if (!mounted) return;
      setState(() => loading = false);

      showMessage('Verification successful.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        verificationVerified = false;
        verificationToken = null;
      });
      showMessage('Invalid or expired verification code.');
    }
  }

  Future<void> register() async {
    if (nameController.text.trim().isEmpty) {
      showMessage('Full name is required.');
      return;
    }

    if (!identityValid) {
      showMessage(identityMode == 'email'
          ? 'Enter a valid email address.'
          : 'Enter a valid phone number.');
      return;
    }

    if (!passwordValid) {
      showMessage('Password must be at least 6 characters.');
      return;
    }

    if (!confirmPasswordValid) {
      showMessage('Password and confirm password do not match.');
      return;
    }

    if (requiresVerification && !verificationVerified) {
      showMessage('Please verify your email or phone before creating account.');
      return;
    }

    setState(() => loading = true);

    try {
      final result = await ApiService.post('/auth/register', {
        'name': nameController.text.trim(),
        'nickname': nicknameController.text.trim(),
        'emailOrPhone': emailOrPhone,
        'password': passwordController.text.trim(),
        'birthYear': birthYear,
        'birthMonth': selectedMonth,
        'birthDay': selectedDay,
        'birthDate': birthDateText,
        'verificationToken': verificationToken,
      });

      AppSession.setAuth(
        Map<String, dynamic>.from(result['user']),
        result['token'],
      );

      if (!mounted) return;
      setState(() => loading = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showMessage('Register failed: $e');
    }
  }

  Future<void> login() async {
    if (!identityValid) {
      showMessage(identityMode == 'email'
          ? 'Enter a valid email address.'
          : 'Enter a valid phone number.');
      return;
    }

    if (passwordController.text.trim().isEmpty) {
      showMessage('Password is required.');
      return;
    }

    setState(() => loading = true);

    try {
      final result = await ApiService.post('/auth/login', {
        'emailOrPhone': emailOrPhone,
        'password': passwordController.text.trim(),
      });

      if (result['requiresTwoStep'] == true) {
        if (!mounted) return;
        setState(() => loading = false);
        showTwoStepDialog(result['identifier']);
        showMessage(result['message'] ?? 'Login verification code sent.');
        return;
      }

      AppSession.setAuth(
        Map<String, dynamic>.from(result['user']),
        result['token'],
      );

      if (!mounted) return;
      setState(() => loading = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showMessage('Login failed: $e');
    }
  }

  Future<void> verifyTwoStepLogin(String identifier, String code) async {
    if (code.trim().isEmpty) {
      showMessage('Enter login verification code.');
      return;
    }

    setState(() => loading = true);

    try {
      final result = await ApiService.post('/auth/login-2fa/verify', {
        'emailOrPhone': identifier,
        'code': code.trim(),
      });

      AppSession.setAuth(
        Map<String, dynamic>.from(result['user']),
        result['token'],
      );

      if (!mounted) return;
      setState(() => loading = false);

      Navigator.pop(context);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showMessage('Two-step verification failed.');
    }
  }

  void showTwoStepDialog(String identifier) {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text('Two-Step Verification'),
          content: TextField(
            controller: codeController,
            keyboardType: TextInputType.number,
            decoration: inputDecoration(
              label: 'Login Code',
              icon: Icons.verified,
              hint: 'Enter code',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                codeController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final code = codeController.text.trim();
                verifyTwoStepLogin(identifier, code);
              },
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );
  }

  void showForgotPasswordSheet() {
    final resetCodeController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmNewPasswordController = TextEditingController();

    bool sent = false;
    bool verified = false;
    String? resetToken;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> sendResetCode() async {
              if (!identityValid) {
                showMessage('Enter your email or phone first.');
                return;
              }

              try {
                final result = await ApiService.post('/auth/password/forgot-send', {
                  'emailOrPhone': emailOrPhone,
                });

                setSheetState(() => sent = true);
                showMessage(result['message'] ?? 'Reset code sent.');
              } catch (e) {
                showMessage('Reset code send failed: $e');
              }
            }

            Future<void> verifyResetCode() async {
              if (resetCodeController.text.trim().isEmpty) {
                showMessage('Enter reset code.');
                return;
              }

              try {
                final result = await ApiService.post('/auth/password/forgot-verify', {
                  'emailOrPhone': emailOrPhone,
                  'code': resetCodeController.text.trim(),
                });

                resetToken = result['verificationToken'];
                setSheetState(() => verified = true);
                showMessage('Code verified.');
              } catch (e) {
                showMessage('Invalid reset code.');
              }
            }

            Future<void> resetPassword() async {
              if (newPasswordController.text.length < 6) {
                showMessage('New password must be at least 6 characters.');
                return;
              }

              if (newPasswordController.text != confirmNewPasswordController.text) {
                showMessage('New password and confirm password do not match.');
                return;
              }

              try {
                final result = await ApiService.post('/auth/password/reset', {
                  'emailOrPhone': emailOrPhone,
                  'verificationToken': resetToken,
                  'newPassword': newPasswordController.text,
                  'confirmPassword': confirmNewPasswordController.text,
                });

                showMessage(result['message'] ?? 'Password reset successful.');
                if (mounted) Navigator.pop(context);
              } catch (e) {
                showMessage('Password reset failed: $e');
              }
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  top: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Recover Password',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use your verified email or phone number to reset your password.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 14),
                    identityModeSelector(),
                    const SizedBox(height: 12),
                    identityInput(),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: sendResetCode,
                      icon: const Icon(Icons.send),
                      label: const Text('Send Reset Code'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: resetCodeController,
                      keyboardType: TextInputType.number,
                      enabled: sent,
                      decoration: inputDecoration(
                        label: 'Reset Code',
                        icon: Icons.pin,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: sent ? verifyResetCode : null,
                      icon: const Icon(Icons.verified),
                      label: const Text('Verify Reset Code'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      enabled: verified,
                      decoration: inputDecoration(
                        label: 'New Password',
                        icon: Icons.lock_reset,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmNewPasswordController,
                      obscureText: true,
                      enabled: verified,
                      decoration: inputDecoration(
                        label: 'Confirm New Password',
                        icon: Icons.lock,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: verified ? resetPassword : null,
                      icon: const Icon(Icons.save),
                      label: const Text('Reset Password'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  InputDecoration inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xfff8fafc),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget identityModeSelector() {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            selected: identityMode == 'email',
            avatar: const Icon(Icons.email, size: 18),
            label: const Text('Email'),
            onSelected: (_) {
              setState(() {
                identityMode = 'email';
                resetVerification();
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ChoiceChip(
            selected: identityMode == 'phone',
            avatar: const Icon(Icons.phone, size: 18),
            label: const Text('Phone'),
            onSelected: (_) {
              setState(() {
                identityMode = 'phone';
                resetVerification();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget identityInput() {
    if (identityMode == 'email') {
      return TextField(
        controller: emailController,
        keyboardType: TextInputType.emailAddress,
        onChanged: (_) => setState(resetVerification),
        decoration: inputDecoration(
          label: 'Email Address',
          icon: Icons.email,
          hint: 'name@example.com',
        ),
      );
    }

    return TextField(
      controller: phoneController,
      keyboardType: TextInputType.phone,
      onChanged: (_) => setState(resetVerification),
      decoration: inputDecoration(
        label: 'Phone Number',
        icon: Icons.phone,
        hint: '+8801XXXXXXXXX',
      ),
    );
  }

  Widget passwordStrengthBox() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: passwordStrengthColor.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: passwordStrengthColor.withOpacity(.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password strength: $passwordStrengthLabel',
            style: TextStyle(
              color: passwordStrengthColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: passwordStrengthValue,
              minHeight: 9,
              backgroundColor: passwordStrengthColor.withOpacity(.15),
              valueColor: AlwaysStoppedAnimation<Color>(passwordStrengthColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Minimum 6 characters. Strong: uppercase, lowercase, number and symbol.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget verificationBox() {
    if (!requiresVerification) {
      return Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppTheme.success.withOpacity(.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          'Kids and teen accounts do not need verification.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: verificationVerified
            ? AppTheme.success.withOpacity(.08)
            : AppTheme.warning.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: verificationVerified
              ? AppTheme.success.withOpacity(.18)
              : AppTheme.warning.withOpacity(.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            verificationVerified
                ? 'Verification completed'
                : 'Verification required',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: loading ? null : sendVerificationCode,
            icon: const Icon(Icons.send),
            label: Text('Send ${identityMode == 'email' ? 'Email' : 'Phone'} Code'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: verificationCodeController,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              setState(() {
                verificationVerified = false;
                verificationToken = null;
              });
            },
            decoration: inputDecoration(
              label: 'Verification Code',
              icon: Icons.pin,
              hint: 'Enter 6-digit code',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: loading || !verificationSent ? null : verifyCode,
            icon: const Icon(Icons.verified),
            label: const Text('Verify Code'),
          ),
        ],
      ),
    );
  }

  Widget birthDatePicker() {
    final days = List<int>.generate(maxDay, (index) => index + 1);

    return Column(
      children: [
        TextField(
          controller: birthYearController,
          keyboardType: TextInputType.number,
          onChanged: (_) {
            setState(() {
              fixSelectedDay();
              resetVerification();
            });
          },
          decoration: inputDecoration(
            label: 'Birth Year',
            icon: Icons.cake,
            hint: 'Example: 2000',
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<int>(
                value: selectedMonth,
                decoration: inputDecoration(
                  label: 'Birth Month',
                  icon: Icons.calendar_month,
                ),
                items: months.map((month) {
                  return DropdownMenuItem<int>(
                    value: month.value,
                    child: Text(month.name),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedMonth = value;
                    fixSelectedDay();
                    resetVerification();
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: selectedDay,
                decoration: inputDecoration(
                  label: 'Date',
                  icon: Icons.today,
                ),
                items: days.map((day) {
                  return DropdownMenuItem<int>(
                    value: day,
                    child: Text('$day'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedDay = value;
                    resetVerification();
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget autoAgePreview() {
    final ageGroup = autoAgeGroup;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffeef2ff),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${AccessControl.ageGroupLabel(ageGroup)} mode will be applied automatically.\nAge: $autoAge • ${AccessControl.accessDescription(ageGroup)}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ageGroup = autoAgeGroup;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.97),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          gradient: AppTheme.mainGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isLogin ? 'CircleUp Login' : 'Create CircleUp Account',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.dark,
                                ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Age-based safe social platform',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (!isLogin) ...[
                        TextField(
                          controller: nameController,
                          decoration: inputDecoration(
                            label: 'Full Name',
                            icon: Icons.person,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: nicknameController,
                          decoration: inputDecoration(
                            label: 'Nickname',
                            icon: Icons.badge,
                          ),
                        ),
                        const SizedBox(height: 14),
                        birthDatePicker(),
                        const SizedBox(height: 14),
                        autoAgePreview(),
                        const SizedBox(height: 14),
                      ],
                      identityModeSelector(),
                      const SizedBox(height: 14),
                      identityInput(),
                      const SizedBox(height: 14),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        onChanged: (_) => setState(() {}),
                        decoration: inputDecoration(
                          label: 'Password',
                          icon: Icons.lock,
                        ),
                      ),
                      const SizedBox(height: 10),
                      passwordStrengthBox(),
                      if (!isLogin) ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: true,
                          onChanged: (_) => setState(() {}),
                          decoration: inputDecoration(
                            label: 'Confirm Password',
                            icon: Icons.lock_outline,
                          ),
                        ),
                        const SizedBox(height: 14),
                        verificationBox(),
                      ],
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: loading ? null : (isLogin ? login : register),
                        icon: loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(isLogin ? Icons.login : Icons.person_add),
                        label: Text(
                          isLogin
                              ? 'Secure Login'
                              : 'Create $ageGroup Account',
                        ),
                      ),
                      if (isLogin)
                        TextButton(
                          onPressed: loading ? null : showForgotPasswordSheet,
                          child: const Text('Forgot password?'),
                        ),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () {
                                setState(() {
                                  isLogin = !isLogin;
                                  resetVerification();
                                });
                              },
                        child: Text(
                          isLogin
                              ? 'New user? Create secure account'
                              : 'Already have account? Login',
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
    );
  }
}
