# CIS Mapper

A Flutter mobile application for mapping cybersecurity tools to CIS (Center for Internet Security) Controls and Safeguards. This app helps security professionals and organizations identify which tools can be used to implement specific CIS Controls, making security compliance planning more accessible and efficient.

## Overview

CIS Mapper provides an intuitive mobile interface to explore the relationships between cybersecurity tools and CIS Controls v8 Safeguards. The application features two main views:

- **Mapper View**: Browse security tools and safeguards with filtering capabilities
- **Aggregator View**: Visualize coverage gaps using an interactive heatmap to see which safeguards are covered by your selected tools

## Features

### Mapper View
- **By Control**: View CIS Controls grouped by control number with associated safeguards
- **By Tool**: Browse security tools and see which safeguards they address
- **Advanced Filtering**:
  - Filter by Implementation Group (IG1, IG2, IG3)
  - Filter by Tier (1-6)
  - Filter by K-12 Education Use
  - Filter by Cost ($, $$, $$$, $$$$)
- **Search**: Full-text search across tools and safeguards
- **Detailed Information**: View tool descriptions, rationale for mappings, and safeguard details

### Aggregator View
- **Coverage Heatmap**: Visual grid showing safeguard coverage
- **Multi-Tool Selection**: Select multiple tools to analyze combined coverage
- **Gap Analysis**: Identify which safeguards lack tool coverage
- **Interactive Cells**: Tap any cell to see which selected tools cover that safeguard

### Data Integration
- Fetches data dynamically from the [CIS-Tool-Mapping](https://github.com/MidwestCyberLLC/CIS-Tool-Mapping) repository
- Real-time loading status indicators
- AI analysis disclaimer to ensure users understand the source of mappings

## Screenshots

*(Screenshots coming soon)*

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0 <4.0.0)
- Android SDK (for Android deployment)
- iOS development tools (for iOS deployment, macOS only)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/MidwestCyberLLC/CIS-Mapper-App.git
cd CIS-Mapper-App
```

2. Install dependencies:
```bash
flutter pub get
```

3. Generate launcher icons (optional):
```bash
flutter pub run flutter_launcher_icons
```

4. Run the app:
```bash
flutter run
```

### Building for Production

#### Android
```bash
flutter build apk --release
```
The APK will be located at: `build/app/outputs/flutter-apk/app-release.apk`

#### iOS
```bash
flutter build ios --release
```

## Data Sources

This application fetches data from three JSON files hosted in the [CIS-Tool-Mapping](https://github.com/MidwestCyberLLC/CIS-Tool-Mapping) repository:

- **safeguards.json**: CIS Controls v8 Safeguards with metadata (IG, Tier, Control Number)
- **tools.json**: Cybersecurity tools with descriptions, cost, and education use indicators
- **mapping.json**: Relationships between tools and safeguards with rationale

## Architecture

### Project Structure
```
lib/
└── main.dart          # Main application file containing all views and logic

assets/
└── icon/
    └── cis_mapper.png # Application icon

android/               # Android-specific configuration
```

### Key Components

- **Models**: `Tool`, `Safeguard`, `Mapping`, `CISData`
- **Views**:
  - `HomeScreen`: Main navigation and data loading
  - `MapperView`: Control and tool browsing interface
  - `AggregatorView`: Coverage heatmap visualization
- **Widgets**:
  - `ControlCard`: Expandable control grouping
  - `SafeguardItem`: Individual safeguard with mapped tools
  - `ToolCard`: Tool details with covered safeguards
  - `_HeatmapCell`: Interactive coverage visualization

## Technology Stack

- **Framework**: Flutter 3.x
- **Language**: Dart
- **HTTP Client**: http package (^1.1.0)
- **UI**: Material Design 3
- **State Management**: StatefulWidget with setState

## Contributing

Contributions are welcome! Here's how you can help:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Areas for Contribution
- Add more comprehensive filtering options
- Improve UI/UX design
- Add export functionality (PDF, CSV)
- Implement offline mode with local caching
- Add unit and integration tests
- Improve accessibility features
- Add iOS-specific optimizations

## Disclaimer

The tools and mappings listed in this application are the result of AI-assisted analysis. It is your responsibility to evaluate and determine if a tool successfully meets the needs of your organization and properly implements the associated CIS Controls.

## Related Projects

- [CIS-Tool-Mapping](https://github.com/MidwestCyberLLC/CIS-Tool-Mapping) - Data repository for tool-to-safeguard mappings

## License

This project is provided as-is for educational and professional use.

## Authors

- **Midwest Cyber LLC** - [GitHub](https://github.com/MidwestCyberLLC)

## Acknowledgments

- [Center for Internet Security (CIS)](https://www.cisecurity.org/) for CIS Controls v8
- Flutter team for the excellent cross-platform framework
- Contributors to the CIS-Tool-Mapping data repository

## Support

For issues, questions, or suggestions, please open an issue on the [GitHub repository](https://github.com/MidwestCyberLLC/CIS-Mapper-App/issues).

---

Built with Flutter by [Midwest Cyber LLC](https://github.com/MidwestCyberLLC)
