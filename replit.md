# East India

A native macOS practice simulator for computer-delivered English exams, with timed sections and automatic local session recovery.

## Run & Operate

- `pnpm --filter @workspace/api-server run dev` — run the API server (port 5000)
- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks and Zod schemas from the OpenAPI spec
- `pnpm --filter @workspace/db run push` — push DB schema changes (dev only)
- Shared API server env: `DATABASE_URL` — Postgres connection string. The native East India app does not require it.

## Stack

- pnpm workspaces, Node.js 24, TypeScript 5.9
- API: Express 5
- DB: PostgreSQL + Drizzle ORM
- Validation: Zod (`zod/v4`), `drizzle-zod`
- API codegen: Orval (from OpenAPI spec)
- Build: esbuild (CJS bundle)

## Where things live

- `native/EastIndia/` — macOS Swift package, opened and run with Xcode on macOS
- `native/EastIndia/Sources/EastIndia/Domain/` — exam phases, questions, and session state
- `native/EastIndia/Sources/EastIndia/Data/` — local session persistence
- `native/EastIndia/Sources/EastIndia/Services/` — exam flow and timer behavior
- `native/EastIndia/Sources/EastIndia/UI/` — SwiftUI screens and AppKit passage highlighting

## Architecture decisions

- The native macOS app is a Swift package under `native/EastIndia`; the pnpm workspace services are not part of its runtime.
- Session state is stored as versioned JSON in local `UserDefaults` for this single-session prototype; no account, server, or database is required.
- Timed sections persist an absolute deadline so closing the app does not pause the exam clock.
- Listening audio is selected locally and copied into Application Support because security-scoped file access from the picker is temporary; its one-play marker is persisted with the session.
- SwiftUI/AppKit compilation and runtime verification require Xcode on macOS; this Linux workspace cannot run the native app.

## Product

Users can practice timed listening, reading, and writing sections, save answers and passage highlights locally, and resume a session without losing time or progress.

## User preferences

_Populate as you build — explicit user instructions worth remembering across sessions._

## Gotchas

_Populate as you build — sharp edges, "always run X before Y" rules._

## Pointers

- See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details
