import 'package:flutter/material.dart';

import '../../core/models/group_type.dart';
import '../../core/theme/closer_icons.dart';
import '../../core/theme/closer_theme.dart';
import '../../core/widgets/widgets.dart';

/// Debug-only catalogue of the design-system components with sample data,
/// used to review visuals on a device. Not registered in release builds.
class ComponentGalleryScreen extends StatelessWidget {
  const ComponentGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: CloserSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: context.text.titleLarge),
          const SizedBox(height: CloserSpacing.md),
          child,
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Components')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(CloserSpacing.gutter),
          children: [
            section(
              'Buttons',
              Column(
                children: [
                  CloserButton(label: 'Share Photo', onPressed: () {}),
                  const SizedBox(height: CloserSpacing.sm),
                  const CloserButton(
                    label: 'Loading',
                    isLoading: true,
                    onPressed: null,
                  ),
                  const SizedBox(height: CloserSpacing.sm),
                  CloserButton.secondary(
                    label: 'Copy Code',
                    icon: const Icon(CloserIcons.copy),
                    onPressed: () {},
                  ),
                  const SizedBox(height: CloserSpacing.sm),
                  CloserButton(
                    label: 'Delete group',
                    variant: CloserButtonVariant.danger,
                    onPressed: () {},
                  ),
                  const SizedBox(height: CloserSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CloserIconButton(
                        icon: CloserIcons.notifications,
                        semanticLabel: 'Notifications',
                        showBadge: true,
                        onPressed: () {},
                      ),
                      CloserIconButton(
                        icon: CloserIcons.plus,
                        semanticLabel: 'Create',
                        filled: true,
                        onPressed: () {},
                      ),
                      CloserIconButton(
                        icon: CloserIcons.settings,
                        semanticLabel: 'Settings',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            section(
              'Avatars',
              const Row(
                children: [
                  MemberAvatar(name: 'Alex Kim', size: 48),
                  SizedBox(width: CloserSpacing.md),
                  AvatarStack(
                    names: ['Alex Kim', 'Emma Rose', 'Jake Lee', 'Mom', 'Dad'],
                  ),
                ],
              ),
            ),
            section(
              'Group cards',
              Column(
                children: [
                  GroupCard(
                    name: 'My Love',
                    type: GroupType.couple,
                    memberCount: 2,
                    activity: '182 days together',
                    isPremium: true,
                    onTap: () {},
                  ),
                  const SizedBox(height: CloserSpacing.sm),
                  GroupCard(
                    name: 'Our Family',
                    type: GroupType.family,
                    memberCount: 5,
                    activity: '18 new memories',
                    placeholderVariant: 1,
                    onTap: () {},
                  ),
                  const SizedBox(height: CloserSpacing.sm),
                  GroupCard(
                    name: 'Travel Crew',
                    type: GroupType.friends,
                    memberCount: 4,
                    activity: 'New photo 2h ago',
                    placeholderVariant: 3,
                    onTap: () {},
                  ),
                ],
              ),
            ),
            section(
              'Memory card',
              MemoryCard(
                caption: 'Our first holiday together',
                location: 'Sardinia, Italy',
                uploaderName: 'Emma Rose',
                dateLabel: 'Jul 30, 2024',
                isPinned: true,
                placeholderVariant: 2,
                heroTag: 'gallery-memory',
                onTap: () => PhotoViewer.show(
                  context,
                  items: const [
                    PhotoViewerItem(
                      caption: 'Our first holiday together',
                      subtitle: 'Sardinia, Italy · Jul 30, 2024',
                      heroTag: 'gallery-memory',
                      placeholderVariant: 2,
                    ),
                    PhotoViewerItem(
                      caption: 'A random Tuesday',
                      placeholderVariant: 0,
                    ),
                  ],
                ),
              ),
            ),
            section(
              'Milestone cards',
              const Column(
                children: [
                  MilestoneCard(
                    highlight: '100',
                    highlightCaption: 'days together',
                    title: 'A hundred days of little moments',
                    dateLabel: 'Apr 12, 2024',
                    theme: MilestoneTheme.heart,
                    isPinned: true,
                  ),
                  SizedBox(height: CloserSpacing.md),
                  MilestoneCard(
                    title: 'Family Reunion',
                    dateLabel: 'Dec 22, 2024',
                    description: 'Everyone under one roof again.',
                    theme: MilestoneTheme.celebration,
                  ),
                ],
              ),
            ),
            section(
              'Invite code',
              const InviteCodeCard(
                code: 'CLOSER783',
                caption: 'Share this code or link with your partner.',
              ),
            ),
            section(
              'Upgrade',
              Column(
                children: [
                  UpgradeCard(groupName: 'My Love', onUpgrade: () {}),
                  const SizedBox(height: CloserSpacing.md),
                  const UpgradeCard(
                    groupName: 'Our Family',
                    onUpgrade: null,
                    unavailableReason:
                        'Purchases are not available in this build yet.',
                  ),
                ],
              ),
            ),
            section(
              'Widget previews',
              const Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: WidgetPreviewCard(
                          groupName: 'My Love',
                          groupType: GroupType.couple,
                          subtitle: '182 days',
                        ),
                      ),
                      SizedBox(width: CloserSpacing.md),
                      Expanded(
                        child: WidgetPreviewCard(
                          groupName: 'Our Family',
                          groupType: GroupType.family,
                          subtitle: '5 members',
                          placeholderVariant: 1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: CloserSpacing.md),
                  WidgetPreviewCard(
                    groupName: 'Travel Crew',
                    groupType: GroupType.friends,
                    subtitle: 'New memory · 2h ago',
                    size: WidgetPreviewSize.wide,
                    placeholderVariant: 3,
                  ),
                ],
              ),
            ),
            section(
              'States',
              Column(
                children: [
                  const SizedBox(height: 120, child: LoadingState()),
                  SizedBox(
                    height: 320,
                    child: ErrorState.offline(onRetry: () {}),
                  ),
                  const OfflineBanner(),
                  const SizedBox(height: CloserSpacing.md),
                  Builder(
                    builder: (context) => CloserButton.secondary(
                      label: 'Show confirmation dialog',
                      onPressed: () => showConfirmationDialog(
                        context,
                        title: 'Leave My Love?',
                        message:
                            'You will lose access to this group\'s photos.',
                        confirmLabel: 'Leave group',
                        destructive: true,
                      ),
                    ),
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
