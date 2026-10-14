import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/routing/routes.dart';
import '../../groups/application/group_providers.dart';
import '../domain/invitation_models.dart';

/// Incoming app links. Overridden with an empty stream in tests.
final incomingLinksProvider = Provider<Stream<Uri>>(
  (ref) => AppLinks().uriLinkStream,
);

/// Extracts the invitation token from `com.closerapp.closer://invite?t=…`.
/// Other links (e.g. Supabase auth callbacks) return null and are left to
/// their own handlers.
String? inviteSecretFromUri(Uri uri) {
  if (uri.scheme != InviteCodes.scheme || uri.host != InviteCodes.host) {
    return null;
  }
  final token = uri.queryParameters['t'];
  if (token != null && token.isNotEmpty) return token;
  final code = uri.queryParameters['code'];
  if (code != null && InviteCodes.looksLikeCode(code)) {
    return InviteCodes.normalize(code);
  }
  return null;
}

/// Group id from a widget/notification link `com.closerapp.closer://group/<id>`.
String? groupIdFromUri(Uri uri) {
  if (uri.scheme != InviteCodes.scheme || uri.host != 'group') return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length != 1) return null;
  final id = segments.single;
  return RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id) ? id : null;
}

/// Listens for invite links and stores the secret as a pending invite; the
/// router then opens the Join screen once the user is signed in.
class InviteLinkListener extends ConsumerStatefulWidget {
  const InviteLinkListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<InviteLinkListener> createState() => _InviteLinkListenerState();
}

class _InviteLinkListenerState extends ConsumerState<InviteLinkListener> {
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(incomingLinksProvider).listen(
      (uri) {
        final secret = inviteSecretFromUri(uri);
        if (secret != null) {
          ref.read(pendingInviteProvider.notifier).set(secret);
          return;
        }
        final groupId = groupIdFromUri(uri);
        if (groupId != null) {
          // Signed-out users are redirected to Welcome by the router.
          ref.read(routerProvider).push(Routes.group(groupId));
        }
      },
      // A malformed link must never crash the app.
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
