# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Flatris is a real-time 1v1 competitive multiplayer Tetris-like web game. When a player clears lines, those blocks transfer to the opponent. Built with React/Redux/Next.js on the frontend and Express/Socket.io on the backend, with Flow static types throughout.

## Commands

```bash
yarn dev:server        # Start backend on port 4000 (run in one terminal)
yarn dev:client        # Start Next.js frontend on port 3000 (run in another)
yarn dev:server:watch  # Dev server with nodemon auto-reload

yarn build             # Production build (next build web)
yarn start             # Production server (combined frontend + backend)

yarn test              # Flow type check + ESLint + Jest (--maxWorkers=4)
yarn test:watch        # Jest in watch mode
yarn lint              # ESLint only
yarn format            # Prettier on .js and .css files

yarn cosmos            # Component explorer UI for isolated component dev
```

To run a single test file: `npx jest path/to/file.test.js`

## Architecture

```
/shared    Isomorphic code shared by both client and server
/web       Next.js frontend (React, Redux)
/server    Express + Socket.io backend
/scripts   Build utilities
```

### /shared — The Core

This is the most important directory. All game logic lives here so it runs identically on server and client.

- `shared/reducers/game.js` — The authoritative game reducer (~18KB). All game state transitions run through this pure function.
- `shared/types/` — Flow types for every state shape and action (`state.js`, `actions.js`, `api.js`)
- `shared/constants/` — Grid dimensions, tetromino shapes, drop speeds, timeouts
- `shared/utils/grid.js` — Pure functions: collision detection, rotation, line clearing

### /web — Frontend

- `web/pages/` — Next.js pages. `index.js` = dashboard, `join.js` = in-game view
- `web/reducers/` — App-level Redux reducers (`curUser`, `games`, `curGame`, `backfills`, `stats`)
- `web/actions/` — Thunk action creators (`game.js`, `game-frame.js`, `global.js`)
- `web/components/` — React components; game logic triggers happen in `socket/` and `effects/` subdirs
- `web/store.js` — Redux store config with thunk and devtools
- Each page's `getInitialProps` runs SSR; Redux state is initialized server-side and hydrated on the client

### /server — Backend

- `server/db.js` — In-memory store (users, sessions, games, gameActions). No persistent DB.
- `server/socket.js` — Socket.io event handlers; broadcasts game actions to room subscribers
- `server/api.js` — REST routes: `GET /game/:id`, `POST /game`, `POST /auth`, `POST /backfill`
- `server/firebase.js` — Optional Firebase Realtime DB for global stats (skipped if credentials missing)

## Key Patterns

### Deterministic Action Architecture

Every game action carries `actionId`, `prevActionId`, `userId`, `gameId`. Actions describe *intent* (e.g., `MOVE_LEFT`), not outcomes. The same action processed by the shared reducer on server and client must produce identical state. This determinism is what makes multiplayer sync reliable.

### Action Backfilling

When a client connects to an ongoing game, it may be missing actions. It requests the gap via `POST /backfill`, which returns all actions in a player's range. If backfill fails, the client resets and refetches game state fresh.

### Real-time Sync

- WebSocket (Socket.io) carries game actions between players in real time
- Clients join Socket.io rooms keyed by `gameId`
- A keep-alive heartbeat marks games as active; games without heartbeats are cleaned up
- If server detects an action produces a different outcome than expected, it broadcasts a sync event

### SSR + Redux Hydration

`getInitialProps` in each page calls the server API, populates Redux state server-side, then serializes it into `__NEXT_DATA__` for client hydration. Auth is cookie-based, read in `addCurUserToState`.

## CI/CD — Azure DevOps Pipeline

This project has an Azure DevOps pipeline connected to the GitHub repo. Key notes:

- Use `yarn`, not `npm` — the lockfile is `yarn.lock` and the `test` script calls `yarn` internally.
- **Node.js 17+ requires `NODE_OPTIONS=--openssl-legacy-provider`** on the build step. Next.js 7 uses webpack 4 which relies on MD4 hashing dropped in OpenSSL 3. Without this flag, `yarn build` will fail with `ERR_OSSL_EVP_UNSUPPORTED`.

Working pipeline snippet:

```yaml
- script: |
    yarn install
    yarn build
  displayName: 'yarn install and build'
  env:
    NODE_OPTIONS: --openssl-legacy-provider
```

## Type System

Flow is used throughout — not TypeScript. Run `yarn test` to include Flow checking. The types in `shared/types/` are the source of truth for data shapes. When adding new actions or state fields, update the Flow types there first.
