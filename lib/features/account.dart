import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad_v2/shared/models/user.dart';
import 'package:vcroad_v2/shared/providers/account.dart';
import 'package:vcroad_v2/shared/providers/user.dart';
import 'package:vcroad_v2/shared/utils/search/search.dart';
import 'package:vcroad_v2/shared/utils/snackbar/snackbar.dart';
import 'package:vcroad_v2/shared/widgets/account/create_admin.dart';
import 'package:vcroad_v2/shared/widgets/account/details.dart';
import 'package:vcroad_v2/shared/widgets/account/lists.dart';
import 'package:vcroad_v2/shared/services/barangay.dart';
import 'package:vcroad_v2/shared/models/barangay.dart';
import 'package:vcroad_v2/shared/utils/search/barangay_filter.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/utils/search/filter.dart';

class Account extends StatefulWidget {
  const Account({super.key});

  @override
  State<Account> createState() => _AccountState();
}

class _AccountState extends State<Account> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  // Single shared barangay service instance reused by the inline filter UI.
  final BarangayService _barangayService = BarangayService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the auth/user provider so we react when the signed-in user changes.
    final signedInUser = context.watch<UserProvider>().user;

    // Defer side-effects to post-frame and only when user actually changed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accountProv = context.read<AccountProvider>();
      if (accountProv.currentUser?.userId != signedInUser?.userId) {
        accountProv.currentUser = signedInUser;
        // Load users under the new scope (AccountService will enforce admin scope)
        accountProv.loadUsers();
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF001278),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Account Management',
          style: TextStyle(
            color: Colors.white,
            fontSize: context.responsive.scaleFont(18),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: context.isDesktop ? 1100 : double.infinity,
          ),
          child: Column(
            children: [
              _buildSearchBar(),

              // --- INLINE filter area using BarangayFilter util (replaces local selector functions)
              Consumer<AccountProvider>(
                builder: (context, provider, _) {
                  final responsive = context.responsive;
                  final isAdmin = provider.currentUser?.role == UserRole.admin;

                  // Role chips
                  final roleChips = UserRole.values.map((role) {
                    final label = role == UserRole.sysadmin
                        ? 'Super Admin'
                        : role == UserRole.admin
                        ? 'Barangay Admin'
                        : 'Road User';
                    final color = role == UserRole.sysadmin
                        ? Colors.purple
                        : role == UserRole.admin
                        ? Colors.blue
                        : Colors.teal;
                    return Padding(
                      padding: EdgeInsets.only(right: context.scale(8)),
                      child: FilterChipButton(
                        responsive: responsive,
                        label: label,
                        icon: role == UserRole.sysadmin
                            ? Icons.security
                            : role == UserRole.admin
                            ? Icons.admin_panel_settings
                            : Icons.person,
                        selected: provider.roleFilters.contains(role),
                        color: color,
                        onPressed: () => provider.toggleRoleFilter(role),
                      ),
                    );
                  }).toList();

                  // Status chips
                  final statusList = [
                    'verified',
                    'unverified',
                    'banned',
                    'inactive',
                    'flagged',
                  ];
                  final statusChips = statusList.map((status) {
                    final color = status == 'verified'
                        ? Colors.green
                        : status == 'banned'
                        ? Colors.red
                        : status == 'inactive'
                        ? Colors.amber
                        : status == 'flagged'
                        ? Colors.orange
                        : Colors.grey;
                    return Padding(
                      padding: EdgeInsets.only(right: context.scale(8)),
                      child: FilterChipButton(
                        responsive: responsive,
                        label: status[0].toUpperCase() + status.substring(1),
                        icon: Icons.label,
                        selected: provider.statusFilters.contains(status),
                        color: color,
                        onPressed: () => provider.toggleStatusFilter(status),
                      ),
                    );
                  }).toList();

                  return Container(
                    padding: EdgeInsets.all(context.scale(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: label + BarangayFilter + Clear All
                        Row(
                          children: [
                            Text(
                              'Filters',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: context.scaleFont(16),
                              ),
                            ),
                            const Spacer(),

                            // Barangay filter util (button + dialog / sheet internally)
                            Builder(
                              builder: (ctx) {
                                final up = ctx.watch<UserProvider>();
                                final isAdminOnly =
                                    up.isAdmin && !up.isSysAdmin;
                                if (isAdminOnly) {
                                  final adminBarangayName =
                                      up.user?.barangay.name ?? 'N/A';
                                  // Ensure provider is scoped to admin barangay (defensive, runs after build)
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    final accProv = ctx.read<AccountProvider>();
                                    if (accProv.barangayFilter !=
                                        adminBarangayName) {
                                      accProv.setBarangayFilter(
                                        adminBarangayName,
                                      );
                                    }
                                  });

                                  return Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: context.scale(12),
                                      vertical: context.scale(8),
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: context.scale(14),
                                          color: Colors.grey[700],
                                        ),
                                        SizedBox(width: context.scale(8)),
                                        Text(
                                          adminBarangayName,
                                          style: TextStyle(
                                            fontSize: context.scaleFont(13),
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                // Normal behavior for non-admins
                                return BarangayFilter(
                                  selected: provider.barangayFilter == null
                                      ? null
                                      : Barangay(
                                          name: provider.barangayFilter!,
                                        ),
                                  barangayService: _barangayService,
                                  selectLabel:
                                      provider.barangayFilter ??
                                      'Select Barangay',
                                  showClear: true,
                                  onChanged: (b) async {
                                    final name = b?.name;
                                    provider.setBarangayFilter(name);
                                  },
                                );
                              },
                            ),

                            SizedBox(width: context.scale(8)),
                            // Removed the "Clear All" button next to the barangay filter
                            // to keep the inline filter area minimal.
                          ],
                        ),

                        SizedBox(height: context.scale(12)),

                        // Chips area
                        if (context.isMobile)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                SizedBox(width: context.scale(8)),
                                if (!isAdmin) ...roleChips,
                                SizedBox(width: context.scale(8)),
                                ...statusChips,
                                SizedBox(width: context.scale(8)),
                              ],
                            ),
                          )
                        else
                          Wrap(
                            spacing: context.scale(8),
                            runSpacing: context.scale(8),
                            children: [
                              if (!isAdmin) ...roleChips,
                              ...statusChips,
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),

              const Divider(height: 1),
              Expanded(child: _buildUserList()),
            ],
          ),
        ),
      ),

      // Floating add button — only visible to sysadmin. Uses responsive info to adapt style.
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          // Only show FAB if current user is sysadmin
          if (!userProvider.isSysAdmin) return const SizedBox.shrink();

          return Builder(
            builder: (ctx) {
              final info = ctx.responsive;
              const tooltip = 'Add admin';
              // Use _isLoading to disable FAB while creating admin to avoid repeated calls.
              final isDisabled = _isLoading;
              // On narrow screens use compact FAB, on wide screens use extended label
              if (info.isMobile) {
                return FloatingActionButton(
                  heroTag: 'fab_add_admin',
                  onPressed: isDisabled
                      ? null
                      : () => _showCreateAdminDialog(ctx),
                  tooltip: tooltip,
                  backgroundColor: const Color(0xFF001278),
                  foregroundColor: Colors.white,
                  child: isDisabled
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.add),
                );
              }
              return FloatingActionButton.extended(
                heroTag: 'fab_add_admin',
                onPressed: isDisabled
                    ? null
                    : () => _showCreateAdminDialog(ctx),
                backgroundColor: const Color(0xFF001278),
                foregroundColor: Colors.white,
                icon: isDisabled
                    ? const SizedBox.shrink()
                    : const Icon(Icons.add),
                label: isDisabled
                    ? SizedBox(
                        width: 120,
                        height: 20,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                      )
                    : const Text(
                        'Add admin',
                        style: TextStyle(color: Colors.white),
                      ),
                tooltip: tooltip,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildUserList() {
    return Consumer<AccountProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: context.scale(64),
                  color: Colors.grey.shade400,
                ),
                SizedBox(height: context.scale(16)),
                Text(
                  provider.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: context.scaleFont(14),
                  ),
                ),
                SizedBox(height: context.scale(16)),
                ElevatedButton(
                  onPressed: () => provider.loadUsers(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (provider.users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: context.scale(64),
                  color: Colors.grey.shade400,
                ),
                SizedBox(height: context.scale(16)),
                Text(
                  'No users found',
                  style: TextStyle(
                    fontSize: context.scaleFont(18),
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadUsers(),
          child: ListView.builder(
            itemCount: provider.users.length,
            itemBuilder: (context, index) {
              final user = provider.users[index];
              final avatarUrl = provider.avatarUrls[user.userId];
              return UserListItem(
                key: ValueKey(user.userId),
                user: user,
                avatarUrl: avatarUrl,
                onTap: () => _navigateToDetails(user),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(context.scale(16)),
      child: Search(
        controller: _searchController,
        hint: 'Search by name, email, street, barangay...',
        debounceDuration: const Duration(milliseconds: 300),
        onSearch: (q) => context.read<AccountProvider>().searchUsers(q),
        onClear: () {
          context.read<AccountProvider>().loadUsers();
        },
      ),
    );
  }

  void _navigateToDetails(user) {
    if (user is! UserDetails) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AccountDetailsPage(user: user)));
  }

  Future<void> _showCreateAdminDialog(BuildContext ctx) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: ctx,
      builder: (_) => const CreateAdminDialog(),
    );

    if (result == null || !ctx.mounted) return;

    setState(() => _isLoading = true);

    try {
      // Call the createAdminUser cloud function
      final callable = FirebaseFunctions.instance.httpsCallable(
        'createAdminUser',
      );
      final response = await callable(result);

      if (!ctx.mounted) return;

      SnackbarUtils.showSuccess(
        ctx,
        'Barangay Admin account created: ${response.data['email']}',
      );

      // Reload user list
      ctx.read<AccountProvider>().loadUsers();
    } on FirebaseFunctionsException catch (e) {
      if (!ctx.mounted) return;
      SnackbarUtils.showError(ctx, 'Failed to create admin: ${e.message}');
    } catch (e) {
      if (!ctx.mounted) return;
      SnackbarUtils.showError(ctx, 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
