# Jamf Printer Manager

![GitHub release (latest by date)](https://img.shields.io/github/v/release/jamf/jamf-printer-manager?display_name=tag) ![GitHub all releases](https://img.shields.io/github/downloads/jamf/jamf-printer-manager/total)  ![GitHub latest release](https://img.shields.io/github/downloads/jamf/jamf-printer-manager/latest/total)
 ![GitHub issues](https://img.shields.io/github/issues-raw/jamf/jamf-printer-manager) ![GitHub closed issues](https://img.shields.io/github/issues-closed-raw/jamf/jamf-printer-manager) ![GitHub pull requests](https://img.shields.io/github/issues-pr-raw/jamf/jamf-printer-manager) ![GitHub closed pull requests](https://img.shields.io/github/issues-pr-closed-raw/jamf/jamf-printer-manager)

macOS App to upload printer configurations to Jamf Pro

## Installation
The Jamf Printer Manager app is available in the [Releases](https://github.com/jamf/jamf-printer-manager/releases/latest) section of this repository. Unzip the .zip archive and copy the application to your Applications folder. 


## Using Jamf Printer Manager
Please review the [Jamf Printer Manager User's Guide](https://github.com/jamf/jamf-printer-manager/blob/main/Jamf%20Printer%20Manager.pdf) prior to use. 

## Build
To build Jamf Printer Manager locally, clone it from the repository

```bash
git clone https://github.com/jamf/jamf-printer-manager.git
```

`cd` into your local directory

```bash
cd <path_to_printer_manager_directory>
```

Build using Xcode

```bash
xcodebuild -scheme "Jamf Printer Manager"
``` 

`cd` into the Release folder

```bash
cd build/Release
```

Run the built .app

## Contributing

Pull requests will be reviewed for incorporation into the app. 
