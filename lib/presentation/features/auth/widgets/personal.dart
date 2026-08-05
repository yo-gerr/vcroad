import 'package:flutter/material.dart';
import 'package:vcroad/data/models/barangay.dart';
import 'package:vcroad/core/utils/input/input_style.dart';
import 'package:vcroad/core/utils/input/input_validation.dart';
import 'package:vcroad/presentation/features/auth/widgets/agreement.dart';
import 'package:vcroad/presentation/shared/widgets/barangay_dropdown.dart';

class PersonalInfo extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final Map<String, TextEditingController> controllers;
  final Barangay? selectedBarangay;
  final ValueChanged<Barangay?> onBarangayChanged;
  final Map<String, FocusNode> focusNodes;

  // Tracks user agreement to terms and privacy policy
  final bool agreed;
  final ValueChanged<bool> onAgreedChanged;

  const PersonalInfo({
    super.key,
    required this.formKey,
    required this.controllers,
    required this.selectedBarangay,
    required this.onBarangayChanged,
    required this.focusNodes,
    required this.agreed,
    required this.onAgreedChanged,
  });

  @override
  State<PersonalInfo> createState() => _PersonalInfoState();
}

class _PersonalInfoState extends State<PersonalInfo> {
  /// Returns an InputDecoration for text fields with label and optional hint.
  InputDecoration _decoration(String label, {String? hint}) {
    return InputStyles.baseDecoration.copyWith(
      labelText: label,
      hintText: hint,
      hintStyle: hint != null ? TextStyle(color: Colors.grey.shade500) : null,
      floatingLabelBehavior: FloatingLabelBehavior.never,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Form(
        key: widget.formKey,
        autovalidateMode: AutovalidateMode.onUnfocus,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // First Name input field
                InputStyles.fieldLabel('First Name'),
                const SizedBox(height: 4),
                TextFormField(
                  controller: widget.controllers['firstName'],
                  focusNode: widget.focusNodes['firstName'],
                  decoration: _decoration('First Name'),
                  style: InputStyles.labelStyle,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.givenName],
                  validator: (val) =>
                      validateName(val, fieldName: 'First Name'),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      widget.focusNodes['middleName']?.requestFocus(),
                ),
                const SizedBox(height: 8),

                // Middle Name input field (optional)
                InputStyles.fieldLabel('Middle Name (Optional)'),
                const SizedBox(height: 4),
                TextFormField(
                  controller: widget.controllers['middleName'],
                  focusNode: widget.focusNodes['middleName'],
                  decoration: _decoration('Middle Name'),
                  style: InputStyles.labelStyle,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.middleName],
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      return validateName(val, fieldName: 'Middle Name');
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      widget.focusNodes['lastName']?.requestFocus(),
                ),
                const SizedBox(height: 8),

                // Last Name input field
                InputStyles.fieldLabel('Last Name'),
                const SizedBox(height: 4),
                TextFormField(
                  controller: widget.controllers['lastName'],
                  focusNode: widget.focusNodes['lastName'],
                  decoration: _decoration('Last Name'),
                  style: InputStyles.labelStyle,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.familyName],
                  validator: (val) => validateName(val, fieldName: 'Last Name'),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      widget.focusNodes['suffix']?.requestFocus(),
                ),
                const SizedBox(height: 8),

                // Suffix input field (optional)
                InputStyles.fieldLabel('Suffix (Optional)'),
                const SizedBox(height: 4),
                TextFormField(
                  controller: widget.controllers['suffix'],
                  focusNode: widget.focusNodes['suffix'],
                  decoration: _decoration('Suffix', hint: 'e.g. Jr., Sr., III'),
                  style: InputStyles.labelStyle,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      widget.focusNodes['phoneNumber']?.requestFocus(),
                ),
                const SizedBox(height: 8),

                // Phone Number input field
                InputStyles.fieldLabel('Phone Number'),
                const SizedBox(height: 4),
                TextFormField(
                  controller: widget.controllers['phoneNumber'],
                  focusNode: widget.focusNodes['phoneNumber'],
                  decoration: _decoration('Phone Number', hint: '09XXXXXXXXX'),
                  style: InputStyles.labelStyle,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  validator: validatePhone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: InputStyles.phoneInputFormatters,
                  onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                ),
                const SizedBox(height: 8),

                // Barangay dropdown
                InputStyles.fieldLabel('Barangay'),
                const SizedBox(height: 4),
                BarangayDropdownField(
                  value: widget.selectedBarangay,
                  onChanged: widget.onBarangayChanged,
                ),
                const SizedBox(height: 8),

                // Street input field
                InputStyles.fieldLabel('Street'),
                const SizedBox(height: 4),
                TextFormField(
                  controller: widget.controllers['street'],
                  focusNode: widget.focusNodes['street'],
                  decoration: _decoration('Street'),
                  style: InputStyles.labelStyle,
                  keyboardType: TextInputType.streetAddress,
                  textCapitalization: TextCapitalization.words,
                  validator: (val) =>
                      validateRequired(val, fieldName: 'Street'),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      widget.focusNodes['houseNumber']?.requestFocus(),
                ),
                const SizedBox(height: 8),

                // House Number input field
                InputStyles.fieldLabel('House Number'),
                const SizedBox(height: 4),
                TextFormField(
                  controller: widget.controllers['houseNumber'],
                  focusNode: widget.focusNodes['houseNumber'],
                  decoration: _decoration('House Number'),
                  style: InputStyles.labelStyle,
                  keyboardType: TextInputType.number,
                  validator: (val) =>
                      validateRequired(val, fieldName: 'House Number'),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                ),

                const SizedBox(height: 16),

                // Agreement checkbox (critical gate)
                AgreementCheckbox(
                  initialValue: widget.agreed,
                  onChanged: widget.onAgreedChanged,
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
