import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _usernameController = TextEditingController();

  bool _isEditingUsername = false;
  bool _isSavingUsername = false;
  String? _usernameError;
  String? _currentUsername;

  // Avatar selection state
  String? _currentAvatarKey;      // from Firestore
  String? _selectedAvatarKey;     // what user tapped in the grid
  bool _isSavingAvatar = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  User? get _user => _auth.currentUser;

  // Map avatar key → storage path
  String avatarStoragePath(String avatarKey) {
    switch (avatarKey) {
      case 'madBrain':
        return 'avatars/madBrain.png';
      case 'grinningBrain':
        return 'avatars/grinningBrain.png';
      case 'numbBrain':
        return 'avatars/numbBrain.png';
      case 'defaultBrain':
      default:
        return 'avatars/defaultBrain.png';
    }
  }

  static const List<String> _avatarKeys = [
    'defaultBrain',
    'madBrain',
    'grinningBrain',
    'numbBrain',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: const Center(child: Text('You must be logged in.')),
      );
    }

    final uid = _user!.uid;
    final stream =
    FirebaseFirestore.instance.collection('users').doc(uid).snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),

      // 🔹 Quilt background + foreground content
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image (same as Settings/Achievements)
          Positioned.fill(
            child: Image.asset(
              'assets/images/background2.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              color: Colors.black.withOpacity(0.55),
              colorBlendMode: BlendMode.srcATop,
            ),
          ),

          // Foreground: your original StreamBuilder content
          SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snap.data!.data() ?? {};
                final username =
                (data['username'] as String?)?.trim().isNotEmpty == true
                    ? data['username'] as String
                    : 'User';

                final avatarKey = (data['avatar'] as String?) ?? 'defaultBrain';
                _currentAvatarKey = avatarKey;

                _currentUsername ??= username;
                if (!_isEditingUsername &&
                    _usernameController.text.isEmpty) {
                  _usernameController.text = username;
                }

                final showConfirmAvatar =
                    _selectedAvatarKey != null &&
                        _selectedAvatarKey != _currentAvatarKey;

                return Stack(
                  children: [
                    SingleChildScrollView(
                      padding:
                      const EdgeInsets.fromLTRB(16, 24, 16, 96),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _buildMainAvatar(context, avatarKey),
                          const SizedBox(height: 24),
                          _buildUsernameRow(context, username),
                          const SizedBox(height: 32),
                          _buildAvatarGrid(context, avatarKey),
                        ],
                      ),
                    ),

                    // Confirm avatar button overlay
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      left: 16,
                      right: 16,
                      bottom: showConfirmAvatar ? 24 : -72,
                      child: AnimatedOpacity(
                        duration:
                        const Duration(milliseconds: 200),
                        opacity: showConfirmAvatar ? 1 : 0,
                        child: OutlinedButton(
                          onPressed:
                          (!_isSavingAvatar && showConfirmAvatar)
                              ? _onConfirmAvatar
                              : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(999),
                            ),
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .primary,
                            side: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              width: 1.5,
                            ),
                          ),
                          child: _isSavingAvatar
                              ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                              AlwaysStoppedAnimation<Color>(
                                Theme.of(context)
                                    .colorScheme
                                    .primary,
                              ),
                            ),
                          )
                              : const Text('Confirm'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  // ===== Main avatar image (top) =====

  Widget _buildMainAvatar(BuildContext context, String avatarKey) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tileColor = isDark
        ? Colors.white.withOpacity(0.04)
        : Colors.black.withOpacity(0.03);

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: BorderRadius.circular(32),
            ),
            child: FutureBuilder<String>(
              future: FirebaseStorage.instance
                  .ref()
                  .child(avatarStoragePath(avatarKey))
                  .getDownloadURL(),
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                return ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Image.network(
                    snapshot.data!,
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),
          ),

          // Pencil badge (purely visual for now)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Username row =====

  Widget _buildUsernameRow(BuildContext context, String username) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Username text / field
              _isEditingUsername
                  ? SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _usernameController,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          isDense: true,
                          errorText: _usernameError,
                        ),
                      ),
                    )
                  : Text(
                      username,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

              const SizedBox(width: 12),

              // Edit / Change button
              // Edit / Change button
if (!_isEditingUsername)
  TextButton(
    onPressed: () {
      setState(() {
        _isEditingUsername = true;
        _usernameError = null;
        _usernameController.text = username;
      });
    },
    style: TextButton.styleFrom(
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    ),
    child: const Text('Edit'),
  )
else
  TextButton(
    onPressed:
        _isSavingUsername ? null : () => _handleChangeUsername(username),
    style: TextButton.styleFrom(
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    ),
    child: _isSavingUsername
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Text('Change'),
  ),


              const SizedBox(width: 8),

              // (!) info badge
              GestureDetector(
                onTap: () => _showUsernameInfoDialog(context),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? Colors.white70
                          : const Color(0xFF1E2430).withOpacity(0.7),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1E2430),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_usernameError != null && !_isEditingUsername)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _usernameError!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  // ===== Avatar grid (2x2) =====

  Widget _buildAvatarGrid(BuildContext context, String currentAvatarKey) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tileColor = isDark
        ? Colors.white.withOpacity(0.04)
        : Colors.black.withOpacity(0.03);

    final effectiveSelectedKey =
        _selectedAvatarKey ?? currentAvatarKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Choose your avatar',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _avatarKeys.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,      // 2x2 grid for 4 avatars
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final key = _avatarKeys[index];
            final isSelected = key == effectiveSelectedKey;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedAvatarKey = key;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: FutureBuilder<String>(
                  future: FirebaseStorage.instance
                      .ref()
                      .child(avatarStoragePath(key))
                      .getDownloadURL(),
                  builder: (ctx, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.network(
                        snapshot.data!,
                        fit: BoxFit.contain,
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ===== Username change logic =====

  Future<void> _handleChangeUsername(String oldUsername) async {
    final user = _user;
    if (user == null) return;

    final rawNew = _usernameController.text.trim();
    if (rawNew.isEmpty) {
      setState(() {
        _usernameError = 'Username cannot be empty.';
      });
      return;
    }

    if (rawNew == oldUsername) {
      setState(() {
        _isEditingUsername = false;
        _usernameError = null;
      });
      return;
    }

    final newKey = rawNew.toLowerCase();
    final oldKey = oldUsername.toLowerCase();

    setState(() {
      _isSavingUsername = true;
      _usernameError = null;
    });

    try {
      final usernamesRef =
          FirebaseFirestore.instance.collection('username');

      final newDoc = await usernamesRef.doc(newKey).get();
      if (newDoc.exists && newDoc.data()?['uid'] != user.uid) {
        setState(() {
          _usernameError = 'This username is already taken.';
        });
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      batch.update(userDoc, {'username': rawNew});

      batch.set(
        usernamesRef.doc(newKey),
        {
          'uid': user.uid,
          'username': rawNew,
          'reservedAt': FieldValue.serverTimestamp(),
        },
      );

      if (oldKey != newKey && oldKey.isNotEmpty) {
        batch.delete(usernamesRef.doc(oldKey));
      }

      await batch.commit();

      setState(() {
        _currentUsername = rawNew;
        _isEditingUsername = false;
        _usernameError = null;
      });
    } catch (_) {
      setState(() {
        _usernameError = 'Failed to change username. Please try again.';
      });
    } finally {
      setState(() {
        _isSavingUsername = false;
      });
    }
  }

  // ===== Avatar confirm logic =====

  Future<void> _onConfirmAvatar() async {
    final user = _user;
    if (user == null || _selectedAvatarKey == null) return;
    if (_selectedAvatarKey == _currentAvatarKey) return;

    setState(() {
      _isSavingAvatar = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'avatar': _selectedAvatarKey});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar updated')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update avatar. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAvatar = false;
          _selectedAvatarKey = null; // hide confirm button
        });
      }
    }
  }

  // ===== Username info dialog =====

  void _showUsernameInfoDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color bg =
        isDark ? const Color(0xFF070B12) : theme.cardColor;

    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This will be your displayed username in multiplayer competitions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Got it'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
