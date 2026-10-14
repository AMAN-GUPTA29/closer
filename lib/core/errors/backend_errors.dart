import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'app_failure.dart';

/// Friendly text for each `closer:<key>` raised by the database.
String backendMessage(String key) => switch (key) {
  'group_full' => 'This couple group already has two people.',
  'not_a_member' => 'You are not a member of this group anymore.',
  'not_allowed' => 'Only the group owner can do that.',
  'not_authenticated' => 'Please sign in again.',
  'relationship_date_couples_only' =>
    'Only couple groups have a “together since” date.',
  'relationship_date_in_future' => 'The start date can’t be in the future.',
  'invalid_expiry' => 'Choose an expiry between 1 hour and 90 days.',
  'invalid_max_redemptions' => 'Choose between 1 and 100 uses.',
  'invitation_not_found' => 'That invitation no longer exists.',
  'use_leave_group' => 'Use “Leave group” to remove yourself.',
  'upload_incomplete' => 'The photo didn’t finish uploading. Please try again.',
  'upload_expired' => 'This upload expired. Please share the photo again.',
  'photo_not_found' => 'That photo is no longer available.',
  'premium_required' => 'Pinning photos is part of Closer Memories.',
  'taken_in_future' => 'The photo date can’t be in the future.',
  'invalid_cover_photo' => 'Choose a photo from this group.',
  'invalid_milestone' => 'This moment can’t be moved to another group.',
  'invalid_avatar' => 'That profile photo couldn’t be saved. Please try again.',
  'invalid_upload' =>
    'Something went wrong preparing this upload. Please try again.',
  _ => 'Something went wrong. Please try again.',
};

/// Converts any repository error into an [AppFailure]. Never exposes raw
/// server messages, SQL or tokens to the UI.
AppFailure mapBackendError(Object error) {
  if (error is AppFailure) return error;
  if (error is sb.PostgrestException) {
    final match = RegExp(r'closer:([a-z_]+)').firstMatch(error.message);
    if (match != null) {
      final key = match.group(1)!;
      return BackendFailure(backendMessage(key), key: key);
    }
    if (error.code == '42501' || error.code == 'PGRST301') {
      return const PermissionFailure();
    }
    if (error.code == 'PGRST116') {
      return const PermissionFailure(
        'This group isn’t available. You may no longer be a member.',
      );
    }
    return const UnexpectedFailure();
  }
  if (error is sb.StorageException) {
    final status = int.tryParse(error.statusCode ?? '');
    if (status == 403 || status == 401) return const PermissionFailure();
    if (status == 413) {
      return const UnexpectedFailure('This photo is too large to upload.');
    }
    return const UnexpectedFailure(
      'The photo couldn’t be uploaded. Please try again.',
    );
  }
  if (error is SocketException ||
      error is TimeoutException ||
      error is sb.AuthRetryableFetchException) {
    return const NetworkFailure();
  }
  if (error is sb.AuthException) {
    return const AuthFailure('Your session has ended. Please sign in again.');
  }
  return const UnexpectedFailure();
}

/// Runs [body] and rethrows any error as an [AppFailure].
Future<T> guardBackend<T>(Future<T> Function() body) async {
  try {
    return await body();
  } catch (e) {
    throw mapBackendError(e);
  }
}
