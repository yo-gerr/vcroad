import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vcroad/data/models/barangay.dart';
import 'package:vcroad/core/utils/input/input_style.dart';
import 'package:vcroad/core/utils/input/input_validation.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/constants/password_policy.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/presentation/shared/widgets/barangay_dropdown.dart';

class CreateAdminDialog extends StatefulWidget {
  const CreateAdminDialog({super.key});

  @override
  State<CreateAdminDialog> createState() => _CreateAdminDialogState();
}

class _CreateAdminDialogState extends State<CreateAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _suffixCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _houseNumberCtrl = TextEditingController();

  Barangay? _selectedBarangay;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _suffixCtrl.dispose();
    _phoneCtrl.dispose();
    _streetCtrl.dispose();
    _houseNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedBarangay == null) {
      // Use centralized snackbar util for consistent styling
      SnackbarUtils.showWarning(context, 'Please select a barangay');
      return;
    }

    setState(() => _isLoading = true);

    final result = {
      'email': _emailCtrl.text.trim(),
      'password': _passwordCtrl.text,
      'userDetails': {
        'firstName': _firstNameCtrl.text.trim(),
        'middleName': _middleNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'suffix': _suffixCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'street': _streetCtrl.text.trim(),
        'houseNumber': _houseNumberCtrl.text.trim(),
        'barangay': _selectedBarangay!.toJson(includePolygons: false),
      },
    };

    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: info.isDesktop ? 600 : double.infinity,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: EdgeInsets.all(info.scale(20)),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      size: info.scale(28),
                      color: AppColors.primary,
                    ),
                    SizedBox(width: info.scale(12)),
                    Expanded(
                      child: Text(
                        'Create Admin Account',
                        style: TextStyle(
                          fontSize: info.scaleFont(20),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                SizedBox(height: info.scale(8)),
                Text(
                  'Admin accounts are verified by default and do not require ID capture.',
                  style: TextStyle(
                    fontSize: info.scaleFont(13),
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: info.scale(20)),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Email
                        InputStyles.fieldLabel('Email'),
                        SizedBox(height: info.scale(4)),
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: InputStyles.decoration(
                            label: 'Email',
                            prefixIcon: const Icon(
                              Icons.email,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          validator: validateEmail,
                        ),
                        SizedBox(height: info.scale(12)),

                        // Password
                        InputStyles.fieldLabel('Password'),
                        SizedBox(height: info.scale(4)),
                        TextFormField(
                          controller: _passwordCtrl,
                          decoration: InputStyles.decoration(
                            label: 'Password',
                            prefixIcon: const Icon(
                              Icons.lock,
                              size: 20,
                              color: Colors.white,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.white,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          validator: (v) => validatePassword(
                            v,
                            minLength: PasswordPolicy.minLength,
                          ),
                        ),
                        SizedBox(height: info.scale(12)),

                        // First Name
                        InputStyles.fieldLabel('First Name'),
                        SizedBox(height: info.scale(4)),
                        TextFormField(
                          controller: _firstNameCtrl,
                          decoration: InputStyles.decoration(
                            label: 'First Name',
                          ),
                          style: const TextStyle(color: Colors.white),
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              validateName(v, fieldName: 'First Name'),
                        ),
                        SizedBox(height: info.scale(12)),

                        // Middle Name
                        InputStyles.fieldLabel('Middle Name (Optional)'),
                        SizedBox(height: info.scale(4)),
                        TextFormField(
                          controller: _middleNameCtrl,
                          decoration: InputStyles.decoration(
                            label: 'Middle Name',
                          ),
                          style: const TextStyle(color: Colors.white),
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty) {
                              return validateName(v, fieldName: 'Middle Name');
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: info.scale(12)),

                        // Last Name
                        InputStyles.fieldLabel('Last Name'),
                        SizedBox(height: info.scale(4)),
                        TextFormField(
                          controller: _lastNameCtrl,
                          decoration: InputStyles.decoration(
                            label: 'Last Name',
                          ),
                          style: const TextStyle(color: Colors.white),
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              validateName(v, fieldName: 'Last Name'),
                        ),
                        SizedBox(height: info.scale(12)),

                        // Suffix
                        InputStyles.fieldLabel('Suffix (Optional)'),
                        SizedBox(height: info.scale(4)),
                        TextFormField(
                          controller: _suffixCtrl,
                          decoration: InputStyles.decoration(
                            label: 'Suffix',
                            hint: 'Jr., Sr., III',
                          ),
                          style: const TextStyle(color: Colors.white),
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.next,
                        ),
                        SizedBox(height: info.scale(12)),

                        // Phone
                        InputStyles.fieldLabel('Phone Number'),
                        SizedBox(height: info.scale(4)),
                        TextFormField(
                          controller: _phoneCtrl,
                          decoration: InputStyles.decoration(
                            label: 'Phone Number',
                            hint: '09XXXXXXXXX',
                          ),
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          inputFormatters: InputStyles.phoneInputFormatters,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          validator: validatePhone,
                        ),
                        SizedBox(height: info.scale(12)),

                        // Barangay
                        InputStyles.fieldLabel('Barangay'),
                        SizedBox(height: info.scale(4)),
                        BarangayDropdownField(
                          value: _selectedBarangay,
                          onChanged: (v) =>
                              setState(() => _selectedBarangay = v),
                        ),
                        SizedBox(height: info.scale(12)),

                        // Street
                        InputStyles.fieldLabel('Street'),
                        SizedBox(height: info.scale(4)),
                        TextFormField(
                          controller: _streetCtrl,
                          decoration: InputStyles.decoration(label: 'Street'),
                          style: const TextStyle(color: Colors.white),
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              validateRequired(v, fieldName: 'Street'),
                        ),
                        SizedBox(height: info.scale(12)),

                        // House Number
                        InputStyles.fieldLabel('House Number'),
                        SizedBox(height: info.scale(4)),
                        TextFormField(
                          controller: _houseNumberCtrl,
                          decoration: InputStyles.decoration(
                            label: 'House Number',
                          ),
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          validator: (v) =>
                              validateRequired(v, fieldName: 'House Number'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: info.scale(20)),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Cancel create admin',
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size.fromHeight(info.scale(48)),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(fontSize: info.scaleFont(14)),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: info.scale(12)),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Create admin account',
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size.fromHeight(info.scale(48)),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: info.scale(20),
                                  height: info.scale(20),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Create Admin',
                                  style: TextStyle(
                                    fontSize: info.scaleFont(14),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
