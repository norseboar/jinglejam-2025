# use-logs

Quick instructions for dumping the tail of the Godot log from any shell session.

## When to Use

- Need to inspect the most recent Godot output without opening the editor
- Want to share log context while reporting or debugging an issue
- After running the game when you need to confirm signals, errors, or warnings

## Prerequisites

- Using PowerShell (`pwsh` or Windows PowerShell)
- Repository root is the current working directory

## Steps

1. Run PowerShell's built-in `Get-Content` command with the `-Tail` parameter:

   ```
   Get-Content "$env:APPDATA\Godot\app_userdata\jinglejam-2025\logs\godot.log" -Tail 200
   ```

   - Replace `200` with any positive integer to change the number of lines.
   - Default to 100 lines if you omit the `-Tail` parameter (shows entire file).

2. Review the log output printed to the console. Errors or warnings near the bottom usually matter most.

3. (Optional) Pipe or redirect the command output if you need to save it:

   ```
   Get-Content "$env:APPDATA\Godot\app_userdata\jinglejam-2025\logs\godot.log" -Tail 500 > .\tmp\godot-log-snippet.txt
   ```

## Notes

- The command reads `%APPDATA%\Godot\app_userdata\jinglejam-2025\logs\godot.log`. Launch the game at least once so the file exists.
- `Get-Content -Tail` is a built-in PowerShell cmdlet, so no custom script is needed.

