import 'outbox_store.dart';
import 'sync_coordinator.dart';

Future<void> initSyncLayer() async {
  await OutboxStore.instance.init();
  SyncCoordinator.instance.start();
}
