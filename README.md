# Brave Origin Paywall Bypass (YOU DONT NEED NIGHTLY SINCE ITS BUGGY)

A small Windows batch script that unlocks Brave Origin locally by patching the browser profile state.

## How to Use

1. Download and install Brave Origin from:
   https://brave.com/origin/

2. Close Brave Origin if it is running.

3. Download this repository or just `unlock-brave-origin.bat`.

4. Run `unlock-brave-origin.bat`.

5. Start Brave Origin normally.

The script does not patch the Brave Origin binary. It only updates the local `Local State` profile file.

## Notes

- If Brave Origin is reinstalled or the purchase popup comes back, run the batch file again.
- The script auto-detects the usual Brave Origin profile locations.
- You can also pass a custom user-data path as the first argument:

```bat
unlock-brave-origin.bat "C:\Path\To\User Data"
```
