import 'dart:io';

import 'package:path/path.dart' as p;

String fixturePath(String name) {
  return p.normalize(
    p.join(Directory.current.path, 'test', 'fixtures', name),
  );
}

Directory fixtureDir(String name) => Directory(fixturePath(name));
