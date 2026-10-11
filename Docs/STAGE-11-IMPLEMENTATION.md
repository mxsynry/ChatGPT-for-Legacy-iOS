# Stage 11 — compiled framework guided message architecture

Official 2026 binary identifiers previously observed: `CalpicoMessageActionsSheet`, `CalpicoMessageContextMenuInteraction`, `MessageRowContextMenuPart`, `ComposerModelPickerUIKitMenuBuilder`, and `ConversationDraftLifecycleTracker`.

**Implemented in independent source**:
- `MessageRowView.swift`: isolated message layout and long-press context menu; actions injected from screen, not entangled with row rendering.
- Multiline message-edit sheet with destructive history notice, replacing alert text field.
- Draft restoration guard avoids scheduling persistence for a draft loaded during conversation switch.
- Edit action carries original conversation ID and won't regenerate a different chat after a switch.
- App-lock guard for sending.

**Important**: Framework strings are architecture hints, not full reverse-engineered source code; these are independently authored approximations. Official markup, internal view tree and animations remain unknown. No Xcode/device build performed.

**Remaining defects to address**: concurrent voice state UI and keyboard focus; long-thread performance, lazy image decode; model capability filtering; OAuth/OpenAI account; citations metadata/structured results; real device build. No claim of official-client feature parity.
