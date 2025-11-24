import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/models/barangay.dart';
import 'package:vcroad_v2/shared/utils/input/dropdown_style.dart';
import 'package:vcroad_v2/shared/utils/input/input_style.dart';
import 'package:vcroad_v2/shared/utils/input/input_validation.dart';
import 'package:vcroad_v2/shared/widgets/register/agreement.dart';

class PersonalInfo extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final Map<String, TextEditingController> controllers;
  final Barangay? selectedBarangay;
  final ValueChanged<Barangay?> onBarangayChanged;
  final List<DropdownMenuItem<Barangay>> barangayItems;
  final Map<String, FocusNode> focusNodes;

  // NEW
  final bool agreed;
  final ValueChanged<bool> onAgreedChanged;

  const PersonalInfo({
    super.key,
    required this.formKey,
    required this.controllers,
    required this.selectedBarangay,
    required this.onBarangayChanged,
    required this.barangayItems,
    required this.focusNodes,
    // NEW
    required this.agreed,
    required this.onAgreedChanged,
  });

  @override
  State<PersonalInfo> createState() => _PersonalInfoState();
}

class _PersonalInfoState extends State<PersonalInfo> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, {String? hint}) {
    // Use auto floating label for better accessibility on filled fields
    return InputStyles.baseDecoration.copyWith(
      labelText: label,
      hintText: hint,
      hintStyle: hint != null ? TextStyle(color: Colors.grey.shade500) : null,
      floatingLabelBehavior: FloatingLabelBehavior.never,
    );
  }

  String? _validateBarangay(Barangay? barangay) {
    return barangay == null || barangay.name.trim().isEmpty
        ? 'Barangay is required'
        : null;
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
                // --- First Name ---
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

                // --- Middle Name ---
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

                // --- Last Name ---
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

                // --- Suffix (Optional) ---
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

                // --- Phone Number ---
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

                // --- Barangay ---
                InputStyles.fieldLabel('Barangay'),
                const SizedBox(height: 4),
                // If barangayItems is large consider replacing with a searchable typeahead widget.
                DropdownButtonFormField2<Barangay>(
                  value: widget.selectedBarangay,
                  decoration: _decoration(
                    'Barangay',
                  ).copyWith(labelStyle: DropdownStyles.hintTextStyle),
                  style: DropdownStyles.itemTextStyle,
                  isExpanded: true,
                  hint: Text(
                    'Select barangay',
                    style: DropdownStyles.hintTextStyle,
                  ),
                  items: widget.barangayItems.map((item) {
                    return DropdownMenuItem<Barangay>(
                      value: item.value,
                      child: Container(
                        color: DropdownStyles.dropdownBackgroundColor,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        height: DropdownStyles.dropdownItemHeight,
                        alignment: Alignment.centerLeft,
                        child: DefaultTextStyle(
                          style: DropdownStyles.itemTextStyle,
                          child: item.child,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: widget.onBarangayChanged,
                  validator: _validateBarangay,
                  dropdownSearchData: DropdownSearchData(
                    searchController: _searchController,
                    searchInnerWidgetHeight: 50,
                    searchInnerWidget: Container(
                      height: 50,
                      padding: const EdgeInsets.all(8),
                      child: TextFormField(
                        controller: _searchController,
                        style: DropdownStyles.itemTextStyle,
                        decoration: DropdownStyles.searchDecoration,
                      ),
                    ),
                    searchMatchFn: (item, searchValue) {
                      return item.value!.name.toLowerCase().contains(
                        searchValue.toLowerCase(),
                      );
                    },
                  ),
                  menuItemStyleData: const MenuItemStyleData(
                    height: DropdownStyles.dropdownItemHeight,
                  ),
                  dropdownStyleData: DropdownStyleData(
                    maxHeight:
                        DropdownStyles.dropdownItemHeight *
                        DropdownStyles.visibleItemCount,
                    decoration: DropdownStyles.dropdownDecoration,
                  ),
                ),
                const SizedBox(height: 8),

                // --- Street ---
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

                // --- House Number ---
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

                // NEW: Agreement (critical gate)
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
