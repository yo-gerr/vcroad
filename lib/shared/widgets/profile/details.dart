import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad_v2/shared/models/barangay.dart';
import 'package:vcroad_v2/shared/models/user.dart';
import 'package:vcroad_v2/shared/providers/user.dart';
import 'package:vcroad_v2/shared/services/barangay.dart';
import 'package:vcroad_v2/shared/services/image.dart';
import 'package:vcroad_v2/shared/utils/dialog/loading.dart';
import 'package:vcroad_v2/shared/utils/input/dropdown_style.dart';
import 'package:vcroad_v2/shared/utils/input/input_style.dart';
import 'package:vcroad_v2/shared/utils/input/input_validation.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/utils/snackbar/snackbar.dart';
import 'package:vcroad_v2/shared/utils/format/text.dart';

class ProfileDetails extends StatefulWidget {
  const ProfileDetails({super.key});

  @override
  State<ProfileDetails> createState() => _ProfileDetailsState();
}

class _ProfileDetailsState extends State<ProfileDetails> {
  bool _editing = false;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _houseNoCtrl;
  late final TextEditingController _barangaySearchController;
  final ValueNotifier<bool> _saving = ValueNotifier(false);
  final ValueNotifier<bool> _hasChanges = ValueNotifier(false);
  Barangay? _selectedBarangay;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().user!;
    _phoneCtrl = TextEditingController(text: user.phoneNumber);
    _streetCtrl = TextEditingController(text: user.street);
    _houseNoCtrl = TextEditingController(text: user.houseNumber);
    _barangaySearchController = TextEditingController();
    _selectedBarangay = user.barangay;
    for (final c in [_phoneCtrl, _streetCtrl, _houseNoCtrl]) {
      c.addListener(_computeDirty);
    }
    ImageService.prefetchDownloadUrls([user.selfiePath]);
    BarangayService().loadBarangays();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _streetCtrl.dispose();
    _houseNoCtrl.dispose();
    _barangaySearchController.dispose();
    _saving.dispose();
    _hasChanges.dispose();
    super.dispose();
  }

  void _computeDirty() {
    final user = context.read<UserProvider>().user!;
    final dirty =
        _phoneCtrl.text.trim() != user.phoneNumber ||
        _streetCtrl.text.trim() != user.street ||
        _houseNoCtrl.text.trim() != user.houseNumber ||
        (_selectedBarangay?.name != user.barangay.name);
    if (_hasChanges.value != dirty) _hasChanges.value = dirty;
  }

  Future<void> _save() async {
    if (_saving.value) return;
    if (!_formKey.currentState!.validate()) return;

    final userProvider = context.read<UserProvider>();
    final user = userProvider.user!;
    final phone = _phoneCtrl.text.trim();
    final street = TextFormat.titleCase(_streetCtrl.text.trim());
    final house = TextFormat.titleCase(_houseNoCtrl.text.trim());
    final brgy = _selectedBarangay ?? user.barangay;

    if (phone == user.phoneNumber &&
        street == user.street &&
        house == user.houseNumber &&
        brgy.name == user.barangay.name) {
      SnackbarUtils.showInfo(context, 'No changes to save.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingDialog(message: 'Saving changes...'),
    );
    _saving.value = true;

    try {
      final uid = user.userId;
      final payload = <String, dynamic>{
        'phoneNumber': phone,
        'street': street,
        'houseNumber': house,
        'barangay': {
          'name': brgy.name,
          if (brgy.district != null) 'district': brgy.district,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(payload, SetOptions(merge: true));

      userProvider.updateUser(
        user.copyWith(
          phoneNumber: phone,
          street: street,
          houseNumber: house,
          barangay: brgy,
          updatedAt: DateTime.now(),
        ),
      );

      if (mounted) {
        Navigator.of(context).pop();
        SnackbarUtils.showSuccess(context, 'Profile updated.');
        _hasChanges.value = false;
        setState(() => _editing = false);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        SnackbarUtils.showError(context, 'Failed to save: $e');
      }
    } finally {
      _saving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final user = context.select<UserProvider, UserDetails?>((p) => p.user);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final avatarSize = info.scale(160, mobileFactor: 0.75, tabletFactor: 0.85);
    final cachedUrl = ImageService.peekCachedUrl(user.selfiePath);

    Widget avatar(String? url) {
      const String brandAsset = 'assets/images/vcroad.webp';
      return ImageService.buildCachedAvatar(
        imageUrl: url,
        radius: avatarSize / 2,
        placeholderAsset: brandAsset,
        cacheWidth: avatarSize.toInt(),
      );
    }

    final maxWidth = info.isDesktop ? 640.0 : double.infinity;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001278),
        title: Text(
          'Profile Details',
          style: TextStyle(color: Colors.white, fontSize: info.scaleFont(18)),
        ),
        centerTitle: true,
        leading: Semantics(
          label: 'Back',
          button: true,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
            padding: EdgeInsets.all(info.scale(8)),
            iconSize: info.scale(32),
            icon: Image.asset(
              'assets/icons/return.webp',
              width: info.scale(24),
              height: info.scale(24),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: info.scale(24),
              ),
            ),
          ),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header with avatar and name
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF001278),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.only(
                left: info.scale(16),
                right: info.scale(16),
                top: info.scale(16),
                bottom: info.scale(32),
              ),
              child: Column(
                children: [
                  RepaintBoundary(
                    child: Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: ClipOval(
                        child:
                            (user.role == UserRole.admin ||
                                user.role == UserRole.sysadmin)
                            // Admins/sysadmins: always show brand asset
                            ? Image.asset(
                                'assets/images/vcroad.webp',
                                width: avatarSize,
                                height: avatarSize,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.person,
                                  size: avatarSize * 0.5,
                                  color: Colors.grey.shade400,
                                ),
                              )
                            // Regular users: prefer cached selfie, otherwise fetch it
                            : (cachedUrl != null
                                  ? avatar(cachedUrl)
                                  : FutureBuilder<String?>(
                                      future: ImageService.getDownloadUrlCached(
                                        user.selfiePath,
                                      ),
                                      builder: (_, snap) => avatar(snap.data),
                                    )),
                      ),
                    ),
                  ),
                  SizedBox(height: info.scale(16)),
                  Text(
                    TextFormat.titleCase(user.fullName),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: info.scaleFont(20),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // Content area
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: context.horizontalPadding,
                      vertical: info.scale(24),
                    ),
                    child: !_editing
                        ? _buildViewMode(context, info, user)
                        : _buildEditMode(context, info, user),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewMode(BuildContext context, dynamic info, UserDetails user) {
    return Column(
      children: [
        _DetailRowWithIcon(
          icon: Icons.person,
          label: 'Name',
          value: TextFormat.titleCase(user.fullName),
          info: info,
        ),
        _DetailRowWithIcon(
          icon: Icons.phone,
          label: 'Phone',
          value: user.phoneNumber,
          info: info,
        ),
        _DetailRowWithIcon(
          icon: Icons.email,
          label: 'Email',
          value: user.email,
          info: info,
        ),
        _DetailRowWithIcon(
          icon: Icons.home,
          label: 'Street',
          value: TextFormat.titleCase(user.street),
          info: info,
        ),
        _DetailRowWithIcon(
          icon: Icons.location_city,
          label: 'House Number',
          value: TextFormat.titleCase(user.houseNumber),
          info: info,
        ),
        _DetailRowWithIcon(
          icon: Icons.place,
          label: 'Barangay',
          value: TextFormat.locality(user.barangay.name),
          info: info,
        ),
        SizedBox(height: info.scale(32)),
        SizedBox(
          width: double.infinity,
          height: info.scale(50),
          child: OutlinedButton(
            onPressed: () => setState(() => _editing = true),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF001278)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: info.scale(12)),
            ),
            child: Text(
              'Edit',
              style: TextStyle(
                fontSize: info.scaleFont(16),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF001278),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditMode(BuildContext context, dynamic info, UserDetails user) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _DetailRowWithIcon(
            icon: Icons.person,
            label: 'Name',
            value: TextFormat.titleCase(user.fullName),
            info: info,
          ),
          SizedBox(height: info.scale(16)),
          _buildInputField(
            icon: Icons.phone,
            controller: _phoneCtrl,
            label: 'Phone',
            hint: '09XXXXXXXXX',
            keyboardType: TextInputType.phone,
            validator: validatePhone,
            info: info,
          ),
          SizedBox(height: info.scale(16)),
          _DetailRowWithIcon(
            icon: Icons.email,
            label: 'Email',
            value: user.email,
            info: info,
          ),
          SizedBox(height: info.scale(16)),
          _buildInputField(
            icon: Icons.home,
            controller: _streetCtrl,
            label: 'Street',
            validator: (v) => validateRequired(v, fieldName: 'Street'),
            info: info,
          ),
          SizedBox(height: info.scale(16)),
          _buildInputField(
            icon: Icons.location_city,
            controller: _houseNoCtrl,
            label: 'House Number',
            validator: (v) => validateRequired(v, fieldName: 'House number'),
            info: info,
          ),
          SizedBox(height: info.scale(16)),
          _buildBarangayField(info),
          SizedBox(height: info.scale(32)),
          SizedBox(
            width: double.infinity,
            height: info.scale(50),
            child: ValueListenableBuilder<bool>(
              valueListenable: _hasChanges,
              builder: (_, dirty, __) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _saving,
                  builder: (_, saving, __) {
                    return ElevatedButton(
                      onPressed: (!dirty || saving) ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF001278),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey.shade400,
                      ),
                      child: saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Update information',
                              style: TextStyle(
                                fontSize: info.scaleFont(16),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required IconData icon,
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    required dynamic info,
  }) {
    final brandBlue = const Color(0xFF001278);
    final editing = _editing;

    return Container(
      decoration: BoxDecoration(
        color: editing ? brandBlue : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: editing ? Colors.transparent : Colors.grey.shade300,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: info.scale(16),
        vertical: info.scale(4),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: editing ? Colors.white : brandBlue,
            size: info.scale(24),
          ),
          SizedBox(width: info.scale(12)),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              style: TextStyle(
                fontSize: info.scaleFont(15),
                color: editing ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                border: InputBorder.none,
                // Keep the field visually flat — we use the container background.
                filled: false,
                labelStyle: TextStyle(
                  fontSize: info.scaleFont(13),
                  color: editing ? Colors.white70 : Colors.grey.shade600,
                ),
                hintStyle: TextStyle(
                  fontSize: info.scaleFont(14),
                  color: editing ? Colors.white70 : Colors.grey.shade400,
                ),
                floatingLabelBehavior: FloatingLabelBehavior.auto,
                contentPadding: EdgeInsets.symmetric(vertical: info.scale(12)),
              ),
              inputFormatters: keyboardType == TextInputType.phone
                  ? InputStyles.phoneInputFormatters
                  : null,
              validator: validator,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarangayField(dynamic info) {
    final svc = BarangayService();
    return FutureBuilder<void>(
      future: svc.loadBarangays(),
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final items = svc.barangayDropdownItems;
        final brandBlue = const Color(0xFF001278);
        final editing = _editing;

        return Container(
          decoration: BoxDecoration(
            color: editing ? brandBlue : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: editing ? Colors.transparent : Colors.grey.shade300,
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: info.scale(16),
            vertical: info.scale(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.place,
                color: editing ? Colors.white : const Color(0xFF001278),
                size: info.scale(24),
              ),
              SizedBox(width: info.scale(12)),
              Expanded(
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : DropdownButtonFormField2<Barangay>(
                        value: _selectedBarangay,
                        decoration: InputDecoration(
                          labelText: 'Barangay',
                          border: InputBorder.none,
                          // fill the inner input when in editing mode so selected value block matches container
                          filled: editing,
                          fillColor: editing ? brandBlue : Colors.white,
                          labelStyle: TextStyle(
                            fontSize: info.scaleFont(13),
                            color: editing
                                ? Colors.white70
                                : Colors.grey.shade600,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: info.scale(8),
                          ),
                        ),
                        style: TextStyle(
                          fontSize: info.scaleFont(15),
                          color: editing ? Colors.white : Colors.black87,
                        ),
                        isExpanded: true,
                        // Enable searchable dropdown (uses dropdown_button2's search support).
                        dropdownSearchData: DropdownSearchData<Barangay>(
                          searchController: _barangaySearchController,
                          searchInnerWidgetHeight: info.scale(56).toInt(),
                          searchInnerWidget: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: info.scale(8),
                            ),
                            child: TextFormField(
                              controller: _barangaySearchController,
                              decoration: InputDecoration(
                                hintText: 'Search barangay...',
                                hintStyle: TextStyle(
                                  fontSize: info.scaleFont(13),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: info.scale(12),
                                  vertical: info.scale(10),
                                ),
                              ),
                              style: TextStyle(
                                fontSize: info.scaleFont(14),
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          // Efficient string match (case-insensitive)
                          searchMatchFn: (item, searchValue) {
                            final name = item.value?.name ?? '';
                            return name.toLowerCase().contains(
                              searchValue.toLowerCase(),
                            );
                          },
                        ),
                        items: items.map((item) {
                          return DropdownMenuItem<Barangay>(
                            value: item.value,
                            child: Container(
                              // menu item background follows editing state (brand blue when editing)
                              color: editing ? brandBlue : Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: info.scale(8),
                              ),
                              height: DropdownStyles.dropdownItemHeight,
                              alignment: Alignment.centerLeft,
                              child: DefaultTextStyle(
                                style: TextStyle(
                                  fontSize: info.scaleFont(15),
                                  color: editing
                                      ? Colors.white
                                      : Colors.black87,
                                  fontFamily: 'Poppins',
                                ),
                                child: Text(item.value?.name ?? ''),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (b) {
                          _selectedBarangay = b;
                          _computeDirty();
                        },
                        validator: (v) => v == null || v.name.trim().isEmpty
                            ? 'Barangay is required'
                            : null,
                        dropdownStyleData: DropdownStyleData(
                          maxHeight: 300,
                          decoration: BoxDecoration(
                            color: editing ? brandBlue : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        iconStyleData: IconStyleData(
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: editing
                                ? Colors.white
                                : const Color(0xFF001278),
                          ),
                          iconSize: info.scale(24),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRowWithIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final dynamic info;

  const _DetailRowWithIcon({
    required this.icon,
    required this.label,
    required this.value,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: info.scale(12)),
      padding: EdgeInsets.all(info.scale(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF001278), size: info.scale(24)),
          SizedBox(width: info.scale(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: info.scaleFont(12),
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: info.scale(4)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: info.scaleFont(15),
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
