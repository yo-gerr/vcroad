import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad_v2/shared/models/user.dart';
import 'package:vcroad_v2/shared/providers/user.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/widgets/profile/header.dart';
import 'package:vcroad_v2/shared/widgets/profile/activity_badges.dart';
import 'package:vcroad_v2/shared/widgets/profile/setting.dart';

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    final UserDetails? user = context.select<UserProvider, UserDetails?>(
      (p) => p.user,
    );

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final padH = context.horizontalPadding;
    final padV = context.verticalPadding;
    final isUser = user.role == UserRole.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001278),
        elevation: 0,
        title: Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: context.responsive.scaleFont(18),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 800;
            final content = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: padH,
                  vertical: padV * 0.5,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProfileHeader(user: user),
                      // Show activity badges only for regular users.
                      if (isUser) ...[
                        const SizedBox(height: 24),
                        ActivityBadges(user: user, isWide: isWide),
                        const SizedBox(height: 32),
                      ] else
                        // Keep spacing consistent when badges are hidden.
                        const SizedBox(height: 32),
                      AccountSettings(user: user),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            );
            return Center(child: content);
          },
        ),
      ),
    );
  }
}
