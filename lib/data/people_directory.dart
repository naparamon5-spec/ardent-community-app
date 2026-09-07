import 'package:flutter/foundation.dart';

import '../api/api.dart';
import 'mappers.dart';
import 'seed.dart';

/// App-wide cache of the people directory (`GET /users`), mirroring the web
/// client's `state.people`. It lets any screen resolve an `@Full Name` written
/// in free text (a post, a comment) to a real [Person] — so mentions render
/// bold and tap through to a profile — without each widget hitting the API.
///
/// A [ChangeNotifier] so widgets can rebuild once the list finishes loading.
class PeopleDirectory extends ChangeNotifier {
  PeopleDirectory._();

  static final PeopleDirectory instance = PeopleDirectory._();

  List<Person> _people = const [];
  bool _loading = false;
  bool _loaded = false;

  /// Everyone in the directory (empty until [ensureLoaded] resolves).
  List<Person> get people => _people;

  /// Loads the directory once. Safe to call repeatedly — concurrent and repeat
  /// calls are ignored. Non-fatal on error (mentions just stay plain text).
  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    _loading = true;
    try {
      final raw = await Api.instance.users.list();
      _people = raw
          .map(personFromJson)
          .where((p) => p.name.trim().isNotEmpty && p.name != 'Unknown')
          .toList();
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Leave the cache empty; callers fall back to plain text.
    } finally {
      _loading = false;
    }
  }
}
