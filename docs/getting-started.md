# Getting started

## Install

```bash
dart pub global activate pubdiagnose
```

Requires Dart SDK ^3.5.

## First diagnosis

```bash
cd path/to/your/package
pubdoctor check
```

Useful follow-ups:

```bash
pubdoctor why <package>
pubdoctor conflicts
pubdoctor imports
pubdoctor unused
```

## Library usage

```dart
import 'package:pubdiagnose/pubdiagnose.dart';

final ws = await PubDoctor.load('.');
print(ws.check().summary);
```

See [commands.md](commands.md) for the full CLI.
