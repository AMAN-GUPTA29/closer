import 'package:closer/core/models/group_type.dart';
import 'package:closer/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  group('CloserButton', () {
    testWidgets('calls onPressed when enabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        themed(CloserButton(label: 'Share', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Share'));
      expect(taps, 1);
    });

    testWidgets('is disabled and shows a spinner while loading', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        themed(
          CloserButton(
            label: 'Share',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(CloserButton));
      expect(taps, 0);
    });

    testWidgets('exposes button semantics with its label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themed(const CloserButton(label: 'Go', onPressed: null)),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Go')),
        matchesSemantics(label: 'Go', isButton: true, hasEnabledState: true),
      );
      handle.dispose();
    });
  });

  testWidgets('CloserIconButton has a tooltip and a 48dp target', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      themed(
        Center(
          child: CloserIconButton(
            icon: Icons.add,
            semanticLabel: 'Create',
            size: 36,
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    expect(find.byTooltip('Create'), findsOneWidget);
    expect(tester.getSize(find.byType(CloserIconButton)).width, 48);
    await tester.tap(find.byType(CloserIconButton));
    expect(taps, 1);
  });

  testWidgets('disabled CloserIconButton is visibly dimmed', (tester) async {
    await tester.pumpWidget(
      themed(
        const Center(
          child: CloserIconButton(
            icon: Icons.add,
            semanticLabel: 'Create',
            onPressed: null,
          ),
        ),
      ),
    );
    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(CloserIconButton),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, lessThan(1));
  });

  testWidgets('ErrorState retry invokes the callback', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      themed(ErrorState(message: 'Could not load', onRetry: () => retries++)),
    );
    expect(find.text('Could not load'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('ErrorState.offline explains the offline state', (tester) async {
    await tester.pumpWidget(themed(const ErrorState.offline()));
    expect(find.text('You are offline'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('EmptyState renders title, message and action', (tester) async {
    await tester.pumpWidget(
      themed(
        EmptyState(
          icon: Icons.photo,
          title: 'No memories yet',
          message: 'Share your first photo.',
          action: CloserButton(label: 'Share', onPressed: () {}),
        ),
      ),
    );
    expect(find.text('No memories yet'), findsOneWidget);
    expect(find.text('Share your first photo.'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  group('showConfirmationDialog', () {
    Future<bool?> open(WidgetTester tester, String tapLabel) async {
      bool? result;
      await tester.pumpWidget(
        themed(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showConfirmationDialog(
                  context,
                  title: 'Leave group?',
                  message: 'You will lose access.',
                  confirmLabel: 'Leave',
                  destructive: true,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Leave group?'), findsOneWidget);
      await tester.tap(find.text(tapLabel));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('resolves true on confirm', (tester) async {
      expect(await open(tester, 'Leave'), isTrue);
    });

    testWidgets('resolves false on cancel', (tester) async {
      expect(await open(tester, 'Cancel'), isFalse);
    });
  });

  testWidgets('InviteCodeCard copies the raw code', (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    var copied = false;
    await tester.pumpWidget(
      themed(InviteCodeCard(code: 'CLOSER783', onCopied: () => copied = true)),
    );
    expect(find.text('C L O S E R 7 8 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Copy invite code'));
    await tester.pump();
    expect(clipboard, 'CLOSER783');
    expect(copied, isTrue);
    expect(find.text('Invite code copied'), findsOneWidget);
  });

  testWidgets('UpgradeCard disables purchase when unavailable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      themed(
        SingleChildScrollView(
          child: UpgradeCard(
            groupName: 'Our Family',
            onUpgrade: () => taps++,
            unavailableReason: 'Purchases are not available yet.',
          ),
        ),
      ),
    );
    expect(find.text('Keep every memory from this group'), findsOneWidget);
    expect(find.text('Purchases are not available yet.'), findsOneWidget);
    await tester.tap(find.text('Upgrade this group'));
    expect(taps, 0);
  });

  testWidgets('GroupCard announces its summary and handles taps', (
    tester,
  ) async {
    var taps = 0;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      themed(
        GroupCard(
          name: 'My Love',
          type: GroupType.couple,
          memberCount: 2,
          activity: '182 days together',
          isPremium: true,
          onTap: () => taps++,
        ),
      ),
    );
    expect(
      find.bySemanticsLabel(RegExp('My Love, Couple group, 2 members')),
      findsOneWidget,
    );
    await tester.tap(find.byType(GroupCard));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('MilestoneCard shows highlight and respects reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: themed(
          const SingleChildScrollView(
            child: MilestoneCard(
              highlight: '100',
              highlightCaption: 'days together',
              title: 'A hundred days',
              dateLabel: 'Apr 12, 2024',
              theme: MilestoneTheme.heart,
            ),
          ),
        ),
      ),
    );
    // With reduced motion the intro animation is already complete.
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('100 days together'), findsOneWidget);
    expect(find.text('A hundred days'), findsOneWidget);
  });

  testWidgets('PhotoViewer pages through photos and closes', (tester) async {
    await tester.pumpWidget(
      themed(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => PhotoViewer.show(
              context,
              items: const [
                PhotoViewerItem(caption: 'First'),
                PhotoViewerItem(caption: 'Second'),
              ],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('First'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Close photo'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsNothing);
  });
}
