import 'persistence.dart';

Future<Persistence> openPlatformPersistence() async => MemoryPersistence();
