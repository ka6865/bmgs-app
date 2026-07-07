import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/storage/local_player_store.dart';
import '../../core/widgets/bgms_brand_header.dart';

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  late Future<_MyScreenStateData> _stateFuture;

  @override
  void initState() {
    super.initState();
    _stateFuture = _loadState();
  }

  Future<_MyScreenStateData> _loadState() async {
    final store = LocalPlayerStore(await SharedPreferences.getInstance());
    return _MyScreenStateData(
      store: store,
      recentPlayers: await store.getRecentPlayers(),
      favoritePlayers: await store.getFavoritePlayers(),
    );
  }

  void _refresh() {
    setState(() {
      _stateFuture = _loadState();
    });
  }

  Future<void> _clearRecent(_MyScreenStateData state) async {
    await state.store.clearRecentSearches();
    _refresh();
  }

  Future<void> _removeFavorite(
    _MyScreenStateData state,
    StoredPlayer player,
  ) async {
    await state.store.toggleFavorite(
      player.nickname,
      platform: player.platform,
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const BgmsBrandHeader(
          title: '마이',
          subtitle: '최근 검색, 즐겨찾기, 계정 연결 상태를 관리합니다.',
        ),
        const SizedBox(height: 16),
        // Supabase 초기화 여부에 따라 인증 섹션 분기
        if (!AppConfig.local.canInitializeSupabase)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '로그인 준비 상태',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text('Supabase URL과 anon key가 설정되면 Auth를 연결합니다.'),
                ],
              ),
            ),
          )
        else
          _SupabaseAuthCard(onAuthChanged: _refresh),
        const SizedBox(height: 12),
        FutureBuilder<_MyScreenStateData>(
          future: _stateFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
              );
            }

            final state = snapshot.data;
            if (state == null) {
              return const _InfoCard(
                title: '저장소를 불러오지 못했습니다',
                body: '잠시 후 다시 시도해 주세요.',
              );
            }

            return Column(
              children: [
                _PlayerListCard(
                  title: '최근 검색',
                  emptyText: '최근 검색이 없습니다.',
                  players: state.recentPlayers,
                  action: TextButton.icon(
                    onPressed: state.recentPlayers.isEmpty
                        ? null
                        : () => _clearRecent(state),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('전체 삭제'),
                  ),
                ),
                const SizedBox(height: 12),
                _PlayerListCard(
                  title: '즐겨찾기',
                  emptyText: '즐겨찾기가 없습니다.',
                  players: state.favoritePlayers,
                  trailingBuilder: (player) => IconButton(
                    tooltip: '즐겨찾기 해제',
                    onPressed: () => _removeFavorite(state, player),
                    icon: const Icon(Icons.star),
                  ),
                ),
                const SizedBox(height: 12),
                const _InfoCard(
                  title: '앱 설정',
                  body: '알림, 동기화 설정은 서버 인증 연결 후 활성화됩니다.',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Supabase 인증 카드 (로그인 / 로그아웃 UI)
// ---------------------------------------------------------------------------

class _SupabaseAuthCard extends StatefulWidget {
  const _SupabaseAuthCard({required this.onAuthChanged});

  final VoidCallback onAuthChanged;

  @override
  State<_SupabaseAuthCard> createState() => _SupabaseAuthCardState();
}

class _SupabaseAuthCardState extends State<_SupabaseAuthCard> {
  final _nicknameController = TextEditingController();
  final _pubgNicknameController = TextEditingController();
  bool _loading = false;
  bool _saving = false;
  bool _deleting = false;
  String? _errorMessage;
  String? _successMessage;
  String _pubgPlatform = 'steam';
  _UserProfile? _profile;
  _ActivityStats? _activityStats;
  Future<void>? _profileFuture;
  StreamSubscription<AuthState>? _authSubscription;

  SupabaseClient get _supabase => Supabase.instance.client;

  Session? get _session => _supabase.auth.currentSession;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _profileFuture = _loadProfile();
      });
      widget.onAuthChanged();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _nicknameController.dispose();
    _pubgNicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final session = _session;
    if (session == null) {
      _profile = null;
      _activityStats = null;
      return;
    }

    try {
      final user = session.user;
      final rawProfile = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final metadata = user.userMetadata ?? const <String, dynamic>{};
      final profile = rawProfile == null
          ? _UserProfile.fromUser(user)
          : _UserProfile.fromJson(Map<String, dynamic>.from(rawProfile));
      final normalizedProfile = profile.withFallbacks(metadata, user.email);

      final postRows = await _supabase
          .from('posts')
          .select('id')
          .eq('user_id', user.id);
      final commentRows = await _supabase
          .from('comments')
          .select('id')
          .eq('user_id', user.id);

      var likeCount = 0;
      final postIds = (postRows as List)
          .whereType<Map>()
          .map((item) => item['id'])
          .where((id) => id != null)
          .toList();
      if (postIds.isNotEmpty) {
        final likeRows = await _supabase
            .from('post_likes')
            .select('post_id')
            .inFilter('post_id', postIds);
        likeCount = (likeRows as List).length;
      }

      if (!mounted) return;
      setState(() {
        _profile = normalizedProfile;
        _activityStats = _ActivityStats(
          postCount: (postRows as List).length,
          commentCount: (commentRows as List).length,
          likeCount: likeCount,
        );
        _nicknameController.text = normalizedProfile.nickname;
        _pubgNicknameController.text = normalizedProfile.pubgNickname ?? '';
        _pubgPlatform = normalizedProfile.pubgPlatform ?? 'steam';
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '마이페이지 정보를 불러오지 못했습니다: $error';
      });
    }
  }

  Future<void> _saveProfile() async {
    final session = _session;
    if (session == null) return;
    final nickname = _nicknameController.text.trim();
    if (nickname.length < 2) {
      setState(() {
        _errorMessage = '닉네임을 2자 이상 입력해 주세요.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _supabase
          .from('profiles')
          .update({
            'nickname': nickname,
            'pubg_nickname': _pubgNicknameController.text.trim().isEmpty
                ? null
                : _pubgNicknameController.text.trim(),
            'pubg_platform': _pubgPlatform,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', session.user.id);

      await _loadProfile();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _successMessage = '프로필이 저장되었습니다.';
      });
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = '프로필 저장 실패: $e';
        });
      }
    }
  }

  Future<void> _signInWithKakao() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.kakao,
        redirectTo: AppConfig.local.resolvedAuthRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
        queryParams: const {'access_type': 'offline', 'prompt': 'consent'},
      );
      if (mounted) {
        setState(() => _loading = false);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = '카카오 로그인 중 오류가 발생했습니다.';
        });
      }
    }
  }

  Future<void> _signOut() async {
    setState(() => _loading = true);
    await _supabase.auth.signOut();
    if (mounted) {
      setState(() => _loading = false);
      widget.onAuthChanged();
    }
  }

  Future<void> _deleteAccount() async {
    final session = _session;
    if (session == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('정말로 탈퇴하시겠습니까?'),
        content: const Text(
          '탈퇴 시 프로필 정보는 즉시 파기되고, 작성한 게시글과 댓글은 탈퇴한 사용자 상태로 보존됩니다. 이 작업은 취소할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _deleting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final baseUrl = AppConfig.local.apiBaseUrl.replaceFirst(
        RegExp(r'/$'),
        '',
      );
      await Dio().post<void>(
        '$baseUrl/api/auth/delete-account',
        options: Options(
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        ),
      );
      await _supabase.auth.signOut();
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _profile = null;
        _activityStats = null;
      });
      widget.onAuthChanged();
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : '회원탈퇴 API 실패: ${error.message ?? '알 수 없는 오류'}';
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _errorMessage = message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _errorMessage = '회원탈퇴 중 오류가 발생했습니다: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    if (session != null) {
      return FutureBuilder<void>(
        future: _profileFuture,
        builder: (context, snapshot) {
          final profile = _profile ?? _UserProfile.fromUser(session.user);
          final stats = _activityStats ?? const _ActivityStats.empty();
          final loadingProfile =
              snapshot.connectionState == ConnectionState.waiting;

          return Column(
            children: [
              _ProfileSummaryCard(
                profile: profile,
                email: session.user.email,
                loading: loadingProfile,
                onSignOut: _loading ? null : _signOut,
                onDeleteAccount: _deleting ? null : _deleteAccount,
                deleting: _deleting,
              ),
              const SizedBox(height: 12),
              _ProfileEditorCard(
                nicknameController: _nicknameController,
                pubgNicknameController: _pubgNicknameController,
                pubgPlatform: _pubgPlatform,
                saving: _saving,
                onPlatformChanged: (value) =>
                    setState(() => _pubgPlatform = value),
                onSave: _saveProfile,
              ),
              const SizedBox(height: 12),
              _PubgInsightCard(
                profile: profile,
                onOpenStats: profile.pubgNickname == null
                    ? null
                    : () {
                        context.go(
                          '/stats?nickname=${Uri.encodeComponent(profile.pubgNickname!)}&platform=${profile.pubgPlatform ?? 'steam'}',
                        );
                      },
              ),
              const SizedBox(height: 12),
              _ActivityStatsCard(stats: stats),
              if (_successMessage != null) ...[
                const SizedBox(height: 12),
                _StatusCard(
                  icon: Icons.check_circle_outline,
                  message: _successMessage!,
                  isError: false,
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                _StatusCard(
                  icon: Icons.error_outline,
                  message: _errorMessage!,
                  isError: true,
                ),
              ],
            ],
          );
        },
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '소셜 로그인',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '웹 BGMS와 동일하게 카카오 계정으로 로그인합니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _signInWithKakao,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE500),
                  foregroundColor: Colors.black,
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.chat_bubble_outline),
                label: const Text('카카오 로그인'),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              _StatusCard(
                icon: Icons.error_outline,
                message: _errorMessage!,
                isError: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 공통 위젯
// ---------------------------------------------------------------------------

class _UserProfile {
  const _UserProfile({
    required this.id,
    required this.nickname,
    this.avatarUrl,
    this.role,
    this.pubgNickname,
    this.pubgPlatform,
  });

  final String id;
  final String nickname;
  final String? avatarUrl;
  final String? role;
  final String? pubgNickname;
  final String? pubgPlatform;

  static _UserProfile fromJson(Map<String, dynamic> json) {
    return _UserProfile(
      id: json['id']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '게이머',
      avatarUrl: json['avatar_url']?.toString(),
      role: json['role']?.toString(),
      pubgNickname: _nullableString(json['pubg_nickname']),
      pubgPlatform: _nullableString(json['pubg_platform']) ?? 'steam',
    );
  }

  static _UserProfile fromUser(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    return _UserProfile(
      id: user.id,
      nickname: _metadataName(metadata, user.email),
      avatarUrl: _nullableString(metadata['avatar_url'] ?? metadata['avatar']),
      role: 'user',
      pubgPlatform: 'steam',
    );
  }

  _UserProfile withFallbacks(Map<String, dynamic> metadata, String? email) {
    return _UserProfile(
      id: id,
      nickname: nickname.isEmpty ? _metadataName(metadata, email) : nickname,
      avatarUrl: avatarUrl ?? _nullableString(metadata['avatar_url']),
      role: role ?? 'user',
      pubgNickname: pubgNickname,
      pubgPlatform: pubgPlatform ?? 'steam',
    );
  }

  static String _metadataName(Map<String, dynamic> metadata, String? email) {
    return _nullableString(
          metadata['full_name'] ??
              metadata['user_name'] ??
              metadata['name'] ??
              metadata['nickname'],
        ) ??
        email?.split('@').first ??
        '게이머';
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}

class _ActivityStats {
  const _ActivityStats({
    required this.postCount,
    required this.commentCount,
    required this.likeCount,
  });

  const _ActivityStats.empty() : postCount = 0, commentCount = 0, likeCount = 0;

  final int postCount;
  final int commentCount;
  final int likeCount;
}

class _MyScreenStateData {
  const _MyScreenStateData({
    required this.store,
    required this.recentPlayers,
    required this.favoritePlayers,
  });

  final LocalPlayerStore store;
  final List<StoredPlayer> recentPlayers;
  final List<StoredPlayer> favoritePlayers;
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({
    required this.profile,
    required this.email,
    required this.loading,
    required this.onSignOut,
    required this.onDeleteAccount,
    required this.deleting,
  });

  final _UserProfile profile;
  final String? email;
  final bool loading;
  final VoidCallback? onSignOut;
  final VoidCallback? onDeleteAccount;
  final bool deleting;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loading) const LinearProgressIndicator(),
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundImage: profile.avatarUrl == null
                      ? null
                      : NetworkImage(profile.avatarUrl!),
                  child: profile.avatarUrl == null
                      ? const Icon(Icons.person, size: 32)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.nickname,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email ?? '카카오 계정',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (profile.role != null) ...[
                        const SizedBox(height: 6),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(profile.role!),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('로그아웃'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDeleteAccount,
                    icon: deleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    label: const Text('회원탈퇴'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileEditorCard extends StatelessWidget {
  const _ProfileEditorCard({
    required this.nicknameController,
    required this.pubgNicknameController,
    required this.pubgPlatform,
    required this.saving,
    required this.onPlatformChanged,
    required this.onSave,
  });

  final TextEditingController nicknameController;
  final TextEditingController pubgNicknameController;
  final String pubgPlatform;
  final bool saving;
  final ValueChanged<String> onPlatformChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '계정 정보 최적화',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nicknameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '커뮤니티 활동 닉네임',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pubgNicknameController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'PUBG 인게임 닉네임',
                prefixIcon: Icon(Icons.sports_esports_outlined),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'steam', label: Text('STEAM')),
                ButtonSegment(value: 'kakao', label: Text('KAKAO')),
              ],
              selected: {pubgPlatform},
              onSelectionChanged: (value) => onPlatformChanged(value.first),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('설정 저장하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PubgInsightCard extends StatelessWidget {
  const _PubgInsightCard({required this.profile, required this.onOpenStats});

  final _UserProfile profile;
  final VoidCallback? onOpenStats;

  @override
  Widget build(BuildContext context) {
    final pubgNickname = profile.pubgNickname;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '데이터 인사이트',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (pubgNickname == null)
              const Text('인게임 닉네임을 설정하면 이곳에서 전적 분석으로 바로 이동할 수 있습니다.')
            else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sports_esports),
                title: Text(pubgNickname),
                subtitle: Text((profile.pubgPlatform ?? 'steam').toUpperCase()),
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpenStats,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('상세 전적 분석 보기'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityStatsCard extends StatelessWidget {
  const _ActivityStatsCard({required this.stats});

  final _ActivityStats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '활동 요약',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _StatRow(
              icon: Icons.article_outlined,
              label: '작성한 게시글',
              value: '${stats.postCount}개',
            ),
            _StatRow(
              icon: Icons.mode_comment_outlined,
              label: '작성한 댓글',
              value: '${stats.commentCount}개',
            ),
            _StatRow(
              icon: Icons.favorite_outline,
              label: '받은 좋아요',
              value: '${stats.likeCount}개',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.message,
    required this.isError,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: TextStyle(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerListCard extends StatelessWidget {
  const _PlayerListCard({
    required this.title,
    required this.emptyText,
    required this.players,
    this.action,
    this.trailingBuilder,
  });

  final String title;
  final String emptyText;
  final List<StoredPlayer> players;
  final Widget? action;
  final Widget Function(StoredPlayer player)? trailingBuilder;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 8),
            if (players.isEmpty)
              Text(emptyText)
            else
              ...players.map(
                (player) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(
                    player.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(player.platform),
                  trailing: trailingBuilder?.call(player),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}
