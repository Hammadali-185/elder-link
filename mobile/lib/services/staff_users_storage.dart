import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Local multi-user staff accounts (JSON list under [keyStaffUsers]).
/// Session is [keyCurrentStaffId] + [staff_logged_in]; profile/password live in JSON only.
class StaffUser {
  /// Immutable stable id (UUID). Never change after creation.
  final String id;
  final String username;
  final String password;
  final String name;
  final String avatar;

  const StaffUser({
    required this.id,
    required this.username,
    required this.password,
    required this.name,
    required this.avatar,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'password': password,
        'name': name,
        'avatar': avatar,
      };

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    return StaffUser(
      id: (json['id'] as String? ?? '').trim(),
      username: (json['username'] as String? ?? '').trim(),
      password: (json['password'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      avatar: (json['avatar'] as String? ?? 'male').trim(),
    );
  }

  StaffUser copyWith({
    String? id,
    String? username,
    String? password,
    String? name,
    String? avatar,
  }) {
    return StaffUser(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
    );
  }
}

class StaffUsersStorage {
  static const String keyStaffUsers = 'staff_users';
  static const String keyCustomAvatars = 'staff_user_custom_avatars';
  static const String keyCurrentStaffId = 'current_staff_id';
  /// Legacy session pointer (username). Migrated to [keyCurrentStaffId] then removed.
  static const String keyCurrentStaffUsername = 'current_staff_username';

  static const Uuid _uuid = Uuid();

  static String newStaffUserId() => _uuid.v4();

  static List<StaffUser> _decodeUsers(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => StaffUser.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((u) => u.username.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String? readCurrentStaffId(SharedPreferences prefs) {
    return prefs.getString(keyCurrentStaffId)?.trim();
  }

  /// Loads [staff_users], assigns missing ids, migrates avatar map to user ids, session pointer, cleans obsolete prefs.
  static Future<List<StaffUser>> getUsers(SharedPreferences prefs) async {
    await migrateLegacyIfNeeded(prefs);
    var list = _decodeUsers(prefs.getString(keyStaffUsers));
    list = await ensureAllUsersHaveIds(prefs, list);
    await migrateCustomAvatarMapKeysToUserIds(prefs, list);
    await migrateSessionPointerToStaffId(prefs, list);
    await migrateObsoleteFlatKeys(prefs, list);
    return list;
  }

  /// Re-keys `staff_user_custom_avatars` from username → stable user [id] (one-time upgrade).
  static Future<void> migrateCustomAvatarMapKeysToUserIds(
    SharedPreferences prefs,
    List<StaffUser> users,
  ) async {
    if (users.isEmpty) return;
    final m = _loadCustomAvatarMap(prefs);
    if (m.isEmpty) return;
    final next = <String, dynamic>{};
    for (final entry in m.entries) {
      final k = entry.key.toString().trim();
      if (k.isEmpty) continue;
      if (users.any((u) => u.id == k)) {
        next[k] = entry.value;
        continue;
      }
      StaffUser? match;
      for (final u in users) {
        if (u.username == k) {
          match = u;
          break;
        }
      }
      if (match != null) {
        next[match.id] = entry.value;
      } else {
        next[k] = entry.value;
      }
    }
    final a = jsonEncode(m);
    final b = jsonEncode(next);
    if (a != b) {
      await _saveCustomAvatarMap(prefs, next);
    }
  }

  /// Persists a new UUID for any row missing `id` (upgrade from pre-id JSON).
  static Future<List<StaffUser>> ensureAllUsersHaveIds(
    SharedPreferences prefs,
    List<StaffUser> users,
  ) async {
    var changed = false;
    final next = <StaffUser>[];
    for (final u in users) {
      if (u.id.isEmpty) {
        changed = true;
        next.add(u.copyWith(id: newStaffUserId()));
      } else {
        next.add(u);
      }
    }
    if (changed) {
      await saveUsers(prefs, next);
    }
    return changed ? next : users;
  }

  /// Maps legacy username-based session keys to [keyCurrentStaffId], then drops old key.
  static Future<void> migrateSessionPointerToStaffId(
    SharedPreferences prefs,
    List<StaffUser> users,
  ) async {
    if (users.isEmpty) return;
    final loggedIn = prefs.getBool('staff_logged_in') ?? false;
    if (!loggedIn) {
      await prefs.remove(keyCurrentStaffUsername);
      return;
    }

    final existingId = readCurrentStaffId(prefs);
    if (existingId != null &&
        existingId.isNotEmpty &&
        users.any((u) => u.id == existingId)) {
      await prefs.remove(keyCurrentStaffUsername);
      return;
    }

    String? uname = prefs.getString(keyCurrentStaffUsername)?.trim();
    if (uname == null || uname.isEmpty) {
      uname = prefs.getString('staff_username')?.trim();
    }
    if (uname != null &&
        uname.isNotEmpty &&
        usernameExists(users, uname)) {
      final u = users.firstWhere((e) => e.username == uname);
      await prefs.setString(keyCurrentStaffId, u.id);
    }
    await prefs.remove(keyCurrentStaffUsername);
  }

  static Future<void> migrateObsoleteFlatKeys(
    SharedPreferences prefs,
    List<StaffUser> users,
  ) async {
    if (users.isEmpty) return;

    await prefs.remove('staff_password');

    final loggedIn = prefs.getBool('staff_logged_in') ?? false;
    final id = readCurrentStaffId(prefs);
    if (loggedIn &&
        id != null &&
        id.isNotEmpty &&
        users.any((u) => u.id == id)) {
      await prefs.remove('staff_username');
      await prefs.remove('staff_name');
      await prefs.remove('staff_avatar');
    }
  }

  static Future<void> saveUsers(
    SharedPreferences prefs,
    List<StaffUser> users,
  ) async {
    await prefs.setString(
      keyStaffUsers,
      jsonEncode(users.map((e) => e.toJson()).toList()),
    );
  }

  /// If JSON list is empty but legacy `staff_username` / `staff_password` exist,
  /// seed one [StaffUser] and persist (keeps backward compatibility).
  static Future<void> migrateLegacyIfNeeded(SharedPreferences prefs) async {
    final existing = _decodeUsers(prefs.getString(keyStaffUsers));
    if (existing.isNotEmpty) return;

    final u = prefs.getString('staff_username')?.trim();
    final p = prefs.getString('staff_password');
    final n = prefs.getString('staff_name')?.trim();
    final a = prefs.getString('staff_avatar') ?? 'male';

    if (u == null || u.isEmpty || p == null || p.isEmpty) return;

    final user = StaffUser(
      id: newStaffUserId(),
      username: u,
      password: p.trim(),
      name: (n == null || n.isEmpty) ? u : n,
      avatar: a,
    );
    await saveUsers(prefs, [user]);
    if (user.avatar == 'custom') {
      await copyGlobalCustomAvatarToUser(prefs, user.id);
    }
  }

  static bool usernameExists(List<StaffUser> users, String username) {
    final t = username.trim();
    return users.any((u) => u.username == t);
  }

  static StaffUser? findByCredentials(
    List<StaffUser> users,
    String username,
    String password,
  ) {
    final u = username.trim();
    final p = password.trim();
    for (final user in users) {
      if (user.username == u && user.password == p) return user;
    }
    return null;
  }

  /// Current session user from [staff_users], keyed by [keyCurrentStaffId]. Does not mutate prefs.
  static Future<StaffUser?> resolveCurrentUser(SharedPreferences prefs) async {
    await prefs.reload();
    if (!(prefs.getBool('staff_logged_in') ?? false)) return null;
    final users = await getUsers(prefs);
    final id = readCurrentStaffId(prefs);
    if (id == null || id.isEmpty) return null;
    final idx = users.indexWhere((u) => u.id == id);
    if (idx < 0) return null;
    return users[idx];
  }

  /// Clears staff session flags/pointer only (accounts unchanged).
  static Future<void> clearInvalidStaffSession(SharedPreferences prefs) async {
    await prefs.setBool('staff_logged_in', false);
    await prefs.remove(keyCurrentStaffId);
    await prefs.remove(keyCurrentStaffUsername);
  }

  /// If `staff_logged_in` is set but session cannot be resolved, clears session and returns null.
  static Future<StaffUser?> validateSessionOrReturnUser(
    SharedPreferences prefs,
  ) async {
    await prefs.reload();
    if (!(prefs.getBool('staff_logged_in') ?? false)) return null;
    final user = await resolveCurrentUser(prefs);
    if (user != null) return user;
    await clearInvalidStaffSession(prefs);
    return null;
  }

  static Map<String, dynamic> _loadCustomAvatarMap(SharedPreferences prefs) {
    final s = prefs.getString(keyCustomAvatars);
    if (s == null || s.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(s) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveCustomAvatarMap(
    SharedPreferences prefs,
    Map<String, dynamic> m,
  ) async {
    await prefs.setString(keyCustomAvatars, jsonEncode(m));
  }

  /// Stores global picked image under the user's stable [staffUserId] (not username).
  static Future<void> copyGlobalCustomAvatarToUser(
    SharedPreferences prefs,
    String staffUserId,
  ) async {
    final key = staffUserId.trim();
    if (key.isEmpty) return;
    final path = prefs.getString('staff_avatar_image_path');
    final b64 = prefs.getString('staff_avatar_image_base64');
    final m = _loadCustomAvatarMap(prefs);
    if (path != null && path.isNotEmpty) {
      m[key] = {'path': path};
      await _saveCustomAvatarMap(prefs, m);
    } else if (b64 != null && b64.isNotEmpty) {
      m[key] = {'base64': b64};
      await _saveCustomAvatarMap(prefs, m);
    }
  }

  static Future<Map<String, dynamic>> getUserAvatarPreview(
    SharedPreferences prefs,
    StaffUser user,
  ) async {
    if (user.avatar == 'custom') {
      final m = _loadCustomAvatarMap(prefs);
      final entry = m[user.id];
      if (entry is Map) {
        final path = entry['path'] as String?;
        final b64 = entry['base64'] as String?;
        return {
          'type': 'custom',
          'imagePath': path,
          'imageBase64': b64,
        };
      }
      return {'type': 'custom', 'imagePath': null, 'imageBase64': null};
    }
    if (user.avatar == 'female') {
      return {'type': 'female', 'imagePath': null, 'imageBase64': null};
    }
    return {'type': 'male', 'imagePath': null, 'imageBase64': null};
  }

  static Future<void> restoreUserCustomAvatarToGlobal(
    SharedPreferences prefs,
    String staffUserId,
  ) async {
    final key = staffUserId.trim();
    final m = _loadCustomAvatarMap(prefs);
    final entry = m[key];
    if (entry is! Map) {
      await prefs.remove('staff_avatar_image_path');
      await prefs.remove('staff_avatar_image_base64');
      return;
    }
    final path = entry['path'] as String?;
    final b64 = entry['base64'] as String?;
    if (path != null && path.isNotEmpty) {
      await prefs.setString('staff_avatar_image_path', path);
      await prefs.remove('staff_avatar_image_base64');
    } else if (b64 != null && b64.isNotEmpty) {
      await prefs.setString('staff_avatar_image_base64', b64);
      await prefs.remove('staff_avatar_image_path');
    } else {
      await prefs.remove('staff_avatar_image_path');
      await prefs.remove('staff_avatar_image_base64');
    }
  }

  static Future<void> logoutSession(SharedPreferences prefs) async {
    await prefs.setBool('staff_logged_in', false);
    await prefs.remove(keyCurrentStaffId);
    await prefs.remove(keyCurrentStaffUsername);
    await prefs.remove('staff_password');
  }

  /// Session: stable user id + logged-in flag only.
  static Future<void> applySession(
    SharedPreferences prefs,
    StaffUser user,
  ) async {
    await prefs.setString(keyCurrentStaffId, user.id);
    await prefs.setBool('staff_logged_in', true);
    await prefs.remove(keyCurrentStaffUsername);
    await prefs.remove('staff_password');
    await prefs.remove('staff_username');
    await prefs.remove('staff_name');
    await prefs.remove('staff_avatar');

    if (user.avatar == 'custom') {
      await restoreUserCustomAvatarToGlobal(prefs, user.id);
    } else {
      await prefs.remove('staff_avatar_image_path');
      await prefs.remove('staff_avatar_image_base64');
    }
  }

  static Future<String?> addUser(
    SharedPreferences prefs,
    StaffUser user,
  ) async {
    final users = await getUsers(prefs);
    if (usernameExists(users, user.username)) {
      return 'Username already taken';
    }
    final toAdd =
        user.id.trim().isEmpty ? user.copyWith(id: newStaffUserId()) : user;
    users.add(toAdd);
    await saveUsers(prefs, users);
    return null;
  }

  static Future<void> updateUserPassword(
    SharedPreferences prefs,
    String username,
    String newPassword,
  ) async {
    final users = await getUsers(prefs);
    final idx = users.indexWhere((u) => u.username == username.trim());
    if (idx < 0) return;
    users[idx] = users[idx].copyWith(password: newPassword.trim());
    await saveUsers(prefs, users);
  }

  static Future<void> updateUserAvatar(
    SharedPreferences prefs,
    String username,
    String avatar,
  ) async {
    final users = await getUsers(prefs);
    final idx = users.indexWhere((u) => u.username == username.trim());
    if (idx < 0) return;
    users[idx] = users[idx].copyWith(avatar: avatar);
    await saveUsers(prefs, users);
  }

  static Future<void> syncCustomAvatarForCurrentUser(
    SharedPreferences prefs,
  ) async {
    final user = await resolveCurrentUser(prefs);
    if (user == null) return;
    await copyGlobalCustomAvatarToUser(prefs, user.id);
    await updateUserAvatar(prefs, user.username, 'custom');
  }

  static Future<String?> updateUserProfile(
    SharedPreferences prefs, {
    required String oldUsername,
    required String newName,
    required String newUsername,
  }) async {
    final users = await getUsers(prefs);
    final idx = users.indexWhere((u) => u.username == oldUsername.trim());
    if (idx < 0) return 'Account not found';

    final nu = newUsername.trim();
    final nn = newName.trim();
    if (nu.isEmpty) return 'Username is required';

    if (nu != oldUsername.trim() && usernameExists(users, nu)) {
      return 'Username already taken';
    }

    final old = users[idx];
    users[idx] = StaffUser(
      id: old.id,
      username: nu,
      password: old.password,
      name: nn.isEmpty ? nu : nn,
      avatar: old.avatar,
    );
    await saveUsers(prefs, users);

    final sessionId = readCurrentStaffId(prefs);
    if (sessionId != null && sessionId == old.id) {
      await applySession(prefs, users[idx]);
    }
    return null;
  }
}
