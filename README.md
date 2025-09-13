# Intune Log Reader for Windows

## Overview

Intune Log Reader provides real-time analysis and monitoring of Microsoft Intune Management Extension logs on Windows systems.

## Features

- **Automated Log Parsing**: Processes Windows Intune log format automatically
- **Smart Categorization**: Organizes logs into Device, Applications, Configurations, Compliance, Sync Status
- **Error Pattern Detection**: Identifies recurring error patterns and frequency
- **Professional Dashboard**: Real-time statistics and category breakdown
- **Advanced Search**: Filter by log level, component, timestamp, message content
- **Export Functions**: CSV export and detailed report generation
- **Live Monitoring**: Real-time log updates (when available)

## Installation

### Method 1: Windows Installer (Recommended)
1. Download `IntuneLogReader_Setup_v1.0.exe` from releases
2. Run installer with administrator privileges
3. Follow installation wizard
4. Launch from Desktop shortcut or Start Menu

### Method 2: Portable Version
1. Download and extract release ZIP
2. Navigate to `release` folder
3. Run `intune_log_reader_windows.exe`

## Log Sources

Automatically loads from: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`

Supported log files:
- AgentExecutor.log
- AppActionProcessor.log
- AppWorkload.log
- DeviceHealthMonitoring.log
- HealthScripts.log
- IntuneManagementExtension.log

## Usage

1. **Launch Application**: Start from Desktop or Start Menu
2. **Load Logs**: Click refresh icon to auto-load all Intune logs
3. **Navigate Categories**: Use sidebar to filter by log category
4. **Analyze Errors**: Review Top Error Patterns on Dashboard
5. **Export Data**: Use Export menu for CSV or detailed reports
6. **Search Logs**: Use search bar within each category

## Technical Stack

- **Framework**: Flutter 3.35.3
- **Language**: Dart 3.9.2
- **Platform**: Windows Desktop
- **Build**: Release optimized

### Build Commands
```bash
flutter pub get
flutter build windows --release
```

### Project Structure
```
lib/
├── models/           # Data models (LogEntry, LogCategory)
├── services/         # Core services (LogFileService, LogCategorizationService)
├── views/           # UI components (CategoryView)
└── main.dart        # Application entry point
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

**Somesh Pathak**
- GitHub: [@pathaksomesh06](https://github.com/pathaksomesh06)
