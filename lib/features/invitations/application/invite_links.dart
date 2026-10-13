import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
