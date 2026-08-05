import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/data/models/barangay.dart';
import 'package:vcroad/data/models/user.dart';
import 'package:vcroad/presentation/providers/user.dart';
import 'package:vcroad/data/repositories/image.dart';
import 'package:vcroad/presentation/shared/dialogs/loading.dart';
import 'package:vcroad/core/utils/input/input_style.dart';
import 'package:vcroad/core/utils/input/input_validation.dart';
import 'package:vcroad/core/utils/responsive/responsive.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/presentation/shared/dialogs/confirmation.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/core/utils/format/text.dart';
import 'package:vcroad/presentation/features/profile/widgets/badges.dart';
import 'package:vcroad/presentation/shared/widgets/barangay_dropdown.dart';

class ProfileDetails extends StatefulWidget {
  const ProfileDetails({super.key});

  @override
  State<ProfileDetails> createState() => _ProfileDetailsState();
}

class _ProfileDetailsState extends State<ProfileDetails> {
  bool _editing = false;
  final _formKey = GlobalKey<FormState>();
  late final UserDetails _originalUser;
  Future<String?>? _avatarFuture;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _houseNoCtrl;
  final ValueNotifier<bool> _saving = ValueNotifier(false);
  final ValueNotifier<bool> _hasChanges = ValueNotifier(false);
  final FocusNode _streetFocus = FocusNode();
  final FocusNode _houseFocus = FocusNode();
  Barangay? _selectedBarangay;

  @override
  void initState() {
    super.initState();
    _originalUser = context.read<UserProvider>().user!;
    final user = _originalUser;
    _phoneCtrl = TextEditingController(text: user.phoneNumber);
    _streetCtrl = TextEditingController(text: user.street);
    _houseNoCtrl = TextEditingController(text: user.houseNumber);
    _selectedBarangay = user.barangay;
    for (final c in [_phoneCtrl, _streetCtrl, _houseNoCtrl]) {
      c.addListener(_computeDirty);
    }
    // Warm the URL cache so the selfie can render promptly on the profile.
    ImageService.prefetchDownloadUrls([user.selfiePath]);
    final isAdmin =
        user.role == UserRole.admin || user.role == UserRole.sysadmin;
    if (!isAdmin) {
      _avatarFuture = ImageService.getDownloadUrlCached(user.selfiePath);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _streetCtrl.dispose();
    _houseNoCtrl.dispose();
    _saving.dispose();
    _hasChanges.dispose();
    _streetFocus.dispose();
    _houseFocus.dispose();
    super.dispose();
  }

  void _computeDirty() {
    final user = _originalUser;
    final dirty =
        _phoneCtrl.text.trim() != user.phoneNumber ||
        _streetCtrl.text.trim() != user.street ||
        _houseNoCtrl.text.trim() != user.houseNumber ||
        (_selectedBarangay?.name != user.barangay.name);
    if (_hasChanges.value != dirty) _hasChanges.value = dirty;
  }

  void _resetToOriginal() {
    final user = _originalUser;
    _phoneCtrl.text = user.phoneNumber;
    _streetCtrl.text = user.street;
    _houseNoCtrl.text = user.houseNumber;
    _selectedBarangay = user.barangay;
    _hasChanges.value = false;
  }

  /// Returns true when it is safe to leave (nothing dirty or discard confirmed).
  Future<bool> _confirmDiscardChanges() async {
    if (!_hasChanges.value) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ConfirmationDialog(
        title: 'Discard changes?',
        message: 'You have unsaved changes. Leaving now will discard them.',
        confirmText: 'Discard',
        cancelText: 'Keep editing',
      ),
    );
    return confirmed == true;
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
    final maxWidth = info.isDesktop ? 640.0 : double.infinity;

    return PopScope(
      canPop: !_editing || !_hasChanges.value,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final leave = await _confirmDiscardChanges();
          if (!context.mounted) return;
          if (leave) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
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
                errorBuilder: (_, _, _) => Icon(
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
              _buildHeader(info, user, avatarSize, maxWidth),
              // Content area
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: _editing
                        ? _buildEditBody(context, info)
                        : _buildViewBody(context, info, user),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    ResponsiveInfo info,
    UserDetails user,
    double avatarSize,
    double maxWidth,
  ) {
    const String brandAsset = 'assets/images/vcroad.webp';
    final isAdmin =
        user.role == UserRole.admin || user.role == UserRole.sysadmin;

    Widget avatarWidget;
    if (isAdmin) {
      avatarWidget = Image.asset(
        brandAsset,
        width: avatarSize,
        height: avatarSize,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          Icons.person,
          size: avatarSize * 0.5,
          color: Colors.grey.shade400,
        ),
      );
    } else {
      avatarWidget = FutureBuilder<String?>(
        future: _avatarFuture,
        builder: (_, snap) => ImageService.buildCachedAvatar(
          imageUrl: snap.data,
          radius: avatarSize / 2,
          placeholderAsset: brandAsset,
          cacheWidth: avatarSize.toInt(),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        left: info.scale(16),
        right: info.scale(16),
        top: info.scale(16),
        bottom: info.scale(28),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            children: [
              Semantics(
                label: 'Profile photo',
                image: true,
                child: RepaintBoundary(
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: ClipOval(child: avatarWidget),
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
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              SelectableText(
                user.email,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: info.scaleFont(14),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  RoleBadge(role: user.role),
                  if (user.isVerified)
                    const VerificationBadge()
                  else
                    const UnverifiedBadge(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewBody(
    BuildContext context,
    ResponsiveInfo info,
    UserDetails user,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: info.horizontalPadding,
        vertical: info.scale(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader(title: 'Contact Information'),
          _DetailRowWithIcon(
            icon: Icons.phone,
            label: 'Phone',
            value: _orDash(user.phoneNumber),
            info: info,
            selectable: true,
          ),
          SizedBox(height: info.scale(24)),
          const _SectionHeader(title: 'Address'),
          _DetailRowWithIcon(
            icon: Icons.home,
            label: 'Street',
            value: _orDash(TextFormat.titleCase(user.street)),
            info: info,
          ),
          _DetailRowWithIcon(
            icon: Icons.location_city,
            label: 'House Number',
            value: _orDash(TextFormat.titleCase(user.houseNumber)),
            info: info,
          ),
          _DetailRowWithIcon(
            icon: Icons.place,
            label: 'Barangay',
            value: _orDash(TextFormat.locality(user.barangay.name)),
            info: info,
          ),
          SizedBox(height: info.scale(32)),
          SizedBox(
            width: double.infinity,
            height: info.scale(50),
            child: OutlinedButton(
              onPressed: () => setState(() => _editing = true),
              style: _outlinedPrimaryStyle(context, info),
              child: Text(
                'Edit',
                style: TextStyle(
                  fontSize: info.scaleFont(16),
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditBody(BuildContext context, ResponsiveInfo info) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: info.horizontalPadding,
              vertical: info.scale(24),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionHeader(title: 'Contact Information'),
                  _buildInputField(
                    icon: Icons.phone,
                    controller: _phoneCtrl,
                    label: 'Phone',
                    hint: '09XXXXXXXXX',
                    keyboardType: TextInputType.phone,
                    validator: validatePhone,
                    info: info,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _streetFocus.requestFocus(),
                    autofocus: true,
                  ),
                  SizedBox(height: info.scale(24)),
                  const _SectionHeader(title: 'Address'),
                  _buildInputField(
                    icon: Icons.home,
                    controller: _streetCtrl,
                    label: 'Street',
                    validator: (v) => validateRequired(v, fieldName: 'Street'),
                    info: info,
                    focusNode: _streetFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _houseFocus.requestFocus(),
                  ),
                  SizedBox(height: info.scale(16)),
                  _buildInputField(
                    icon: Icons.location_city,
                    controller: _houseNoCtrl,
                    label: 'House Number',
                    validator: (v) =>
                        validateRequired(v, fieldName: 'House number'),
                    info: info,
                    focusNode: _houseFocus,
                    textInputAction: TextInputAction.done,
                  ),
                  SizedBox(height: info.scale(16)),
                  _buildBarangayField(info),
                  SizedBox(height: info.scale(16)),
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: info.scale(16),
                        color: colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: info.scale(8)),
                      Expanded(
                        child: Text(
                          'Name and email are read-only. Contact support to update them.',
                          style: TextStyle(
                            fontSize: info.scaleFont(12),
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: info.scale(8)),
                ],
              ),
            ),
          ),
        ),
        _buildActionBar(context, info),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context, ResponsiveInfo info) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outline)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: info.horizontalPadding,
        vertical: info.scale(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: info.scale(50),
              child: OutlinedButton(
                onPressed: () async {
                  final discard = await _confirmDiscardChanges();
                  if (!discard || !mounted) return;
                  _resetToOriginal();
                  setState(() => _editing = false);
                },
                style: _outlinedPrimaryStyle(context, info),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: info.scaleFont(16),
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: info.scale(12)),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: info.scale(50),
              child: ValueListenableBuilder<bool>(
                valueListenable: _hasChanges,
                builder: (_, dirty, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: _saving,
                    builder: (_, saving, _) {
                      return ElevatedButton(
                        onPressed: (!dirty || saving) ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
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
                                'Save Changes',
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
          ),
        ],
      ),
    );
  }

  ButtonStyle _outlinedPrimaryStyle(BuildContext context, ResponsiveInfo info) {
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton.styleFrom(
      side: BorderSide(color: colorScheme.primary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: colorScheme.surface,
      padding: EdgeInsets.symmetric(vertical: info.scale(12)),
    );
  }

  Widget _buildInputField({
    required IconData icon,
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    required ResponsiveInfo info,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
    bool autofocus = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: info.scale(16),
        vertical: info.scale(4),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: info.scale(24)),
          SizedBox(width: info.scale(12)),
          Expanded(
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onFieldSubmitted: onFieldSubmitted,
              autofocus: autofocus,
              autocorrect: keyboardType != TextInputType.phone,
              enableSuggestions: keyboardType != TextInputType.phone,
              style: TextStyle(
                fontSize: info.scaleFont(15),
                color: Colors.white,
              ),
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                border: InputBorder.none,
                // Keep the field visually flat — we use the container background.
                filled: false,
                labelStyle: TextStyle(
                  fontSize: info.scaleFont(13),
                  color: Colors.white70,
                ),
                hintStyle: TextStyle(
                  fontSize: info.scaleFont(14),
                  color: Colors.white70,
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

  Widget _buildBarangayField(ResponsiveInfo info) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: info.scale(16),
        vertical: info.scale(6),
      ),
      child: Row(
        children: [
          Icon(Icons.place, color: Colors.white, size: info.scale(24)),
          SizedBox(width: info.scale(12)),
          Expanded(
            child: BarangayDropdownField(
              value: _selectedBarangay,
              decoration: InputDecoration(
                border: InputBorder.none,
                filled: true,
                fillColor: AppColors.primary,
                hintText: 'Select barangay',
                hintStyle: TextStyle(color: Colors.white70),
                contentPadding: EdgeInsets.symmetric(horizontal: info.scale(8)),
              ),
              onChanged: (b) {
                setState(() => _selectedBarangay = b);
                _computeDirty();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: context.scaleFont(14),
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: context.scale(8)),
        Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
        SizedBox(height: context.scale(16)),
      ],
    );
  }
}

class _DetailRowWithIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ResponsiveInfo info;
  final bool selectable;

  const _DetailRowWithIcon({
    required this.icon,
    required this.label,
    required this.value,
    required this.info,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(
      fontSize: info.scaleFont(12),
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );
    final valueStyle = TextStyle(
      fontSize: info.scaleFont(15),
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w500,
    );

    return Semantics(
      readOnly: true,
      child: Container(
        margin: EdgeInsets.only(bottom: info.scale(12)),
        padding: EdgeInsets.all(info.scale(16)),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary, size: info.scale(24)),
            SizedBox(width: info.scale(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: labelStyle),
                  SizedBox(height: info.scale(4)),
                  if (selectable)
                    SelectableText(value, style: valueStyle, maxLines: 2)
                  else
                    Text(
                      value,
                      style: valueStyle,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _orDash(String value) => value.trim().isEmpty ? '—' : value;
