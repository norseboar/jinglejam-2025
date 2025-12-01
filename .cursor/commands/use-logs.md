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

1. Run the helper script and pass the number of lines you want to see:

   ```
   pwsh -File .\tools\godot-log-tail.ps1 200
   ```

   - Omit the final argument to default to 100 lines.
   - Pass any positive integer to change the tail size.

2. Review the log output printed to the console. Errors or warnings near the bottom usually matter most.

3. (Optional) Pipe or redirect the command output if you need to save it:

   ```
   pwsh -File .\tools\godot-log-tail.ps1 500 > .\tmp\godot-log-snippet.txt
   ```

## Notes

- The script reads `%APPDATA%\Godot\app_userdata\jinglejam-2025\logs\godot.log`. Launch the game at least once so the file exists.
- The command will fail fast with a helpful error message if the log is missing or if the line count argument is invalid.

