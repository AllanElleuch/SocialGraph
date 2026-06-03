import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_graph/services/quest_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuestStore', () {
    test('load returns empty ledger when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = QuestStore(prefs: prefs);

      expect(await store.load(), isEmpty);
    });

    test('claim records the reward and persists it', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = QuestStore(prefs: prefs);

      final ledger = await store.claim('2026-06-01:touchBase', 30);
      expect(ledger['2026-06-01:touchBase'], 30);

      // A fresh store over the same prefs sees the persisted claim.
      final reloaded = await QuestStore(prefs: prefs).load();
      expect(reloaded['2026-06-01:touchBase'], 30);
      expect(QuestStore.totalXp(reloaded), 30);
    });

    test('claiming the same key twice does not double-count', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = QuestStore(prefs: prefs);

      await store.claim('2026-06-01:touchBase', 30);
      final ledger = await store.claim('2026-06-01:touchBase', 999);

      expect(ledger['2026-06-01:touchBase'], 30); // original reward kept
      expect(QuestStore.totalXp(ledger), 30);
    });

    test('totalXp sums every claimed reward', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = QuestStore(prefs: prefs);

      await store.claim('2026-06-01:touchBase', 30);
      await store.claim('2026-06-01:newFace', 25);
      final ledger = await store.claim('2026-06-08:busyBee', 60);

      expect(QuestStore.totalXp(ledger), 115);
    });

    test('corrupt payload degrades to an empty ledger', () async {
      SharedPreferences.setMockInitialValues({
        QuestStore.storageKey: 'not-json',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = QuestStore(prefs: prefs);

      expect(await store.load(), isEmpty);
    });
  });
}
