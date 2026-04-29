# Aegis Sync
This repository exposes a root adapter entrypoint so sync verification can be executed from the project root.

## Root adapter integration
- Root path `./adapter.js` re-exports `lumenpath-sync/adapter.js`.
- This allows the original one-liner import path to work without changing directories.

## Verify integration
Run from repository root:

```sh
npm install
npm install --prefix ./lumenpath-sync
PORT=1338 node -e 'import("./adapter.js").then(a => a.default.syncEntry({id:"test-user",token:"test-token"}, "https://nowsecure.nl")).then(r => console.log("syncEntry result:", r))'
```

Expected behavior:
- The command resolves `./adapter.js` successfully.
- The command completes and prints a boolean result from `syncEntry`.
