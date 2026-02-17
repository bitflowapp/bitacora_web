import 'outbox_store.dart';

Future<void> initSyncLayer() async {
  await OutboxStore.instance.init();
}
