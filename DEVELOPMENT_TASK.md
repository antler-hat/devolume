# Task: Refactor Ejector App for External Drive Ejection

## Description

The goal of this task is to refocus the Ejector app to specifically solve the problem of safely ejecting external drives. The app should, when run, attempt to eject all external volumes that do not have any processes using them. If there are processes using any external volume, the app should present a unified interface listing all such processes (across all volumes) in a single table, allowing the user to end those processes and then eject the drives. The UI and logic should be updated to streamline this workflow and provide clear feedback to the user.

## Task List

- [ ] Refactor app launch to enumerate all external volumes and their processes.
  - On startup, the app should scan for all external volumes and, for each, determine if any processes are using them.
- [ ] Attempt to eject all volumes with no processes using them.
  - For each external volume with no open processes, attempt to eject it immediately.
- [ ] Aggregate all processes using any external volume into a single list.
  - For volumes that cannot be ejected due to open processes, collect all such processes into a single data structure.
- [ ] Refactor process table UI to show all processes with a "Volume" column.
  - Present a single table listing all processes using any external volume, with columns for Volume, Process Name, and PID, and a checkbox for each.
- [ ] Implement checkbox/button logic as described.
  - All checkboxes should be auto-selected. If all are selected, the button should say "End processes and eject". If not all are selected, it should say "End processes".
- [ ] Implement process termination and post-termination ejection logic.
  - When the user ends processes, kill the selected processes. If all processes are selected, attempt to eject all affected volumes after termination.
- [ ] Add error handling and user feedback for ejection failures.
  - If ejection fails for any volume, provide a clear error or warning to the user.

## Notes

- Use either DiskArbitration (native) or `diskutil eject` (shell command) for ejection.
- Use `lsof` to discover processes using each volume.
- The app should no longer require the user to select a volume before seeing processes; it acts on all external volumes at once.
- The UI should be clear and user-friendly, with all relevant information in a single view when processes are present.
