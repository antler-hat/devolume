# Ejector

Ejector is a macOS utility that helps you safely remove external drives. It automatically ejects any drives that are ready to go and highlights the processes that still have files open so you can address them quickly.

## Download

You can download the latest version of Ejector from the [Releases page](https://github.com/antler-hat/ejector/releases).

## Features

- Scans every mounted external volume on launch
- Automatically ejects drives with no blocking processes
- Shows a checklist of all blocking processes in a single table with drive context
- Lets you terminate selected processes and retries the ejection flow

## How It Works

When you open Ejector, it automatically scans all connected external drives:
- Drives that are safe to remove are ejected immediately.
- Drives still in use show up in a list with the apps or processes using them.
- You can choose which processes to end, and Ejector will retry the ejection automatically.

## Why Ejector?

Manually ejecting drives can be frustrating when macOS says “The disk wasn’t ejected because one or more programs may be using it.”  
Ejector solves this by showing you exactly which processes are blocking your drives and letting you close them safely.

## Building from Source

The application is built using Swift and the Cocoa framework. To build from source:

```bash
chmod +x build.sh
./build.sh
```

This script compiles the Swift sources, assembles an app bundle under `build/`, and replaces any existing install at `~/Applications/Ejector.app`.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
