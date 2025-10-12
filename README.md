# Ejector

Ejector is a macOS application that helps you manage processes using external volumes. It allows you to identify and terminate processes that are preventing you from ejecting external drives.

## Features

- Lists all external volumes connected to your Mac
- Shows processes that are using a selected volume
- Allows you to terminate processes to safely eject the volume

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

1. Launch Ejector from your Applications folder
2. Select an external volume from the list
3. View the processes that are using the volume
4. Select the processes you want to terminate
5. Click "End Processes" to terminate the selected processes
6. Once all processes are terminated, you can safely eject the volume

## Building from Source

The application is built using Swift and the Cocoa framework. To build from source:

```bash
./build.sh
```

This script compiles the Swift source files and creates an application bundle in your `~/Applications` folder.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Apple's Cocoa framework
- The Swift programming language
