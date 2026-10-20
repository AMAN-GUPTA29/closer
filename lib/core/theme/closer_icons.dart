import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The single icon vocabulary for Keeploom.
///
/// Lucide (ISC licence) supplies the outline UI glyphs. Lucide has no filled
/// glyphs, so the few solid accents (heart, pin, star, check) use Material's
/// rounded set, which matches Lucide's rounded stroke caps. Use these names
/// instead of reaching for either library directly.
abstract final class CloserIcons {
  // Navigation (active state = same glyph, coloured by the theme)
  static const IconData home = LucideIcons.house;
  static const IconData homeActive = LucideIcons.house;
  static const IconData journal = LucideIcons.bookHeart;
  static const IconData journalActive = LucideIcons.bookHeart;
  static const IconData add = LucideIcons.circlePlus;
  static const IconData addActive = LucideIcons.circlePlus;
  static const IconData notifications = LucideIcons.bell;
  static const IconData notificationsActive = LucideIcons.bell;
  static const IconData profile = LucideIcons.user;
  static const IconData profileActive = LucideIcons.user;

  // Actions
  static const IconData back = LucideIcons.arrowLeft;
  static const IconData forward = LucideIcons.arrowRight;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData close = LucideIcons.x;
  static const IconData plus = LucideIcons.plus;
  static const IconData more = LucideIcons.ellipsis;
  static const IconData copy = LucideIcons.copy;
  static const IconData share = LucideIcons.share2;
  static const IconData link = LucideIcons.link;
  static const IconData camera = LucideIcons.camera;
  static const IconData gallery = LucideIcons.image;
  static const IconData calendar = LucideIcons.calendar;
  static const IconData settings = LucideIcons.settings;
  static const IconData signOut = LucideIcons.logOut;
  static const IconData trash = LucideIcons.trash2;
  static const IconData edit = LucideIcons.pencil;
  static const IconData retry = LucideIcons.rotateCw;
  static const IconData pin = LucideIcons.pin;
  static const IconData pinFilled = Icons.push_pin_rounded;
  static const IconData clock = LucideIcons.clock;

  // Form
  static const IconData email = LucideIcons.mail;
  static const IconData lock = LucideIcons.lock;
  static const IconData user = LucideIcons.user;
  static const IconData atSign = LucideIcons.atSign;
  static const IconData eye = LucideIcons.eye;
  static const IconData eyeOff = LucideIcons.eyeOff;

  // Group types & moments
  static const IconData heart = Icons.favorite_rounded;
  static const IconData heartOutline = LucideIcons.heart;
  static const IconData friends = LucideIcons.users;
  static const IconData family = LucideIcons.usersRound;
  static const IconData members = LucideIcons.users;
  static const IconData invite = LucideIcons.userPlus;
  static const IconData sparkle = LucideIcons.sparkles;
  static const IconData crown = LucideIcons.crown;
  static const IconData confetti = LucideIcons.partyPopper;
  static const IconData cake = LucideIcons.cake;
  static const IconData trip = LucideIcons.plane;
  static const IconData graduation = LucideIcons.graduationCap;
  static const IconData star = Icons.star_rounded;
  static const IconData starOutline = LucideIcons.star;
  static const IconData widgets = LucideIcons.layoutGrid;
  static const IconData phone = LucideIcons.smartphone;
  static const IconData appearance = LucideIcons.palette;
  static const IconData sun = LucideIcons.sun;
  static const IconData moon = LucideIcons.moon;

  // Status
  static const IconData success = Icons.check_circle_rounded;
  static const IconData warning = LucideIcons.circleAlert;
  static const IconData offline = LucideIcons.wifiOff;
  static const IconData help = LucideIcons.circleHelp;
  static const IconData privacy = LucideIcons.shieldCheck;
  static const IconData document = LucideIcons.fileText;
  static const IconData mailSent = LucideIcons.send;
}
