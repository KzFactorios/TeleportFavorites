# Teleport Entry Points Test Suite Plan

Status: SAVED_NOT_EXECUTED  
Flag: REVIEW_LATER  
Saved At: 2026-04-09 23:56:16 -06:00

This document records the planned test coverage work for teleport entry points.
It is intentionally not implemented yet.

## Planned Spec Files

- `tests/specs/teleport_entrypoint_spec.lua`
- `tests/specs/custom_input_dispatcher_teleport_spec.lua`
- `tests/specs/slot_interaction_handlers_teleport_spec.lua`
- `tests/specs/control_fave_bar_history_modal_teleport_spec.lua`
- `tests/specs/control_tag_editor_teleport_spec.lua`

## Planned Coverage

- `core/control/teleport_entrypoint.lua`
  - invalid player / invalid gps behavior
  - action trace lifecycle (`action_name`, `action_id`, end flags)
  - profiler section behavior (`section_name`)
  - success/failure result contracts
  - `silent_already_at_target` suppression handling
  - callback safety for `on_success` and `on_failure`
  - protected behavior when strategy call throws

- `core/events/custom_input_dispatcher.lua`
  - favorite hotkey routing behavior
  - history navigation routing behavior
  - cross-surface history short-circuit behavior

- `core/control/slot_interaction_handlers.lua`
  - left-click favorite teleport behavior
  - invalid/blank GPS protection behavior
  - history modal refresh callback behavior

- `core/control/control_fave_bar.lua`
  - history modal item teleport behavior
  - validation guards (index/history/gps)
  - pointer update callback behavior

- `core/control/control_tag_editor.lua`
  - tag editor teleport button behavior
  - input validation guards
  - close-editor behavior after teleport attempt

## Execution Note

Do not implement until explicitly requested.
Next trigger phrase: "execute the teleport test plan".
