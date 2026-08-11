# PubDoctor LSP

`pubdoctor lsp` exposes a minimal JSON-RPC 2.0 server over stdio using
**Content-Length** framing (same transport as the Language Server Protocol).

## Transport

Each message:

```text
Content-Length: <N>\r\n
\r\n
<JSON body of N bytes>
```

## Lifecycle

1. Client sends `initialize`
2. Client uses `pubdoctor/*` methods
3. Client sends `shutdown`, then `exit`

## Methods

| Method | Params | Result |
|--------|--------|--------|
| `initialize` | `{}` | capabilities + serverInfo |
| `shutdown` | `{}` | `null` |
| `exit` | `{}` | (no response) |
| `pubdoctor/inspect` | `{}` | workspace/capability inspection JSON |
| `pubdoctor/check` | `{ "offline": true }` | health report summary + diagnostics |
| `pubdoctor/explain` | `{ "target": "PD1001" }` or `{ "package": "http" }` | diagnostic or package explanation |
| `pubdoctor/why` | `{ "package": "collection" }` | dependency path analysis |

## Example

```bash
pubdoctor lsp --project .
```

Programmatic use:

```dart
final server = PubDoctorLspServer(workspacePath: '.');
await server.serve(input: stdin, output: stdout.write);
await server.close();
```
