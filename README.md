# Ejector

Ejector is a macOS utility that helps you safely remove external drives. It automatically ejects any drives that are ready to go and highlights the processes that still have files open so you can address them quickly.

## Features

- Scans every mounted external volume on launch
- Automatically ejects drives with no blocking processes
- Aggregates all blocking processes in a single table with drive context
- Lets you terminate selected processes and retries the ejection flow

## Requirements

- macOS 10.13 or later
- Administrator privileges (for terminating processes)

## Installation

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/ejector.git
   cd ejector
   ```

2. Build the application:
   ```
   chmod +x build.sh
   ./build.sh
   ```

3. The application will be installed to `~/Applications/Ejector.app`

## Usage

1. Launch Ejector from your Applications folder.
2. The app will immediately scan and eject any external drives that are safe to remove.
3. If some drives are still in use, you'll see a single list of the blocking processes along with the volume each one is using.
4. Leave the processes you want to terminate selected and click **End processes**.
5. When all blocking processes are gone, Ejector automatically retries the ejection and confirms when every selected drive is safe to unplug.

## Building from Source

The application is built using Swift and the Cocoa framework. To build from source:

```bash
./build.sh
```

This script compiles the Swift sources, assembles an app bundle under `build/`, and replaces any existing install at `~/Applications/Ejector.app`.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Apple's Cocoa framework
- The Swift programming language
