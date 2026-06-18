import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../api/agent_client.dart';
import '../db/mobile_database.dart';
import '../models/pc_connection.dart';

/// Overridden in `main()` once the DB is open.
final mobileDbProvider = Provider<MobileDatabase>(
  (ref) => throw UnimplementedError('mobileDbProvider must be overridden'),
);

final agentClientProvider = Provider<AgentClient>((ref) {
  final client = AgentClient();
  ref.onDispose(client.close);
  return client;
});

/// All paired PCs, with add/remove.
class PcsNotifier extends AsyncNotifier<List<PcConnection>> {
  MobileDatabase get _db => ref.read(mobileDbProvider);

  @override
  Future<List<PcConnection>> build() => _db.getAll();

  Future<void> add(PcConnection pc) async {
    await _db.upsert(pc);
    state = await AsyncValue.guard(_db.getAll);
  }

  Future<void> remove(String id) async {
    await _db.delete(id);
    state = await AsyncValue.guard(_db.getAll);
  }

  Future<void> markConnected(PcConnection pc) async {
    await _db.upsert(pc.copyWith(lastConnectedAt: DateTime.now()));
    state = await AsyncValue.guard(_db.getAll);
  }
}

final pcsProvider = AsyncNotifierProvider<PcsNotifier, List<PcConnection>>(PcsNotifier.new);

/// App list for a given PC (re-fetched when invalidated).
final appsForPcProvider =
    FutureProvider.family<List<AppListItem>, PcConnection>((ref, pc) async {
  final client = ref.watch(agentClientProvider);
  return client.listApps(pc);
});
