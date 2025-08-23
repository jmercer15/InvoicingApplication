# InvoicingApplication

A comprehensive iOS invoicing application built with SwiftUI and SwiftData, designed for NDIS service providers and small businesses.

## Features

### 📅 Calendar & Session Management
- Multi-view calendar (Month, Week, Timeline, Agenda)
- Session creation and management
- Travel charge automation
- Recurring session support
- External calendar integration

### 💰 Invoicing & Billing
- NDIS billing automation
- Custom invoice templates
- Invoice generation and management
- Tax reporting (BAS)
- Expense tracking

### 👥 Client & Relationship Management
- Client database with detailed profiles
- Service assignments
- Payee management
- Plan manager tracking
- Bulk operations

### 🗺️ Location Services
- Travel charge calculation
- MMM zone integration
- Geocoding services
- Map integration

### ⚙️ Settings & Configuration
- Company profile management
- NDIS billing settings
- Data import/export
- Travel charge automation settings

## Technology Stack

- **Frontend**: SwiftUI
- **Data Persistence**: SwiftData
- **Architecture**: MVVM with modular feature-based structure
- **Dependencies**: Core Location, EventKit, MapKit
- **Build System**: Xcode

## Project Structure

```
InvoicingApplication/
├── Core/                    # App core and configuration
├── Features/               # Feature modules
│   ├── Calendar/          # Calendar and session management
│   ├── Dashboard/         # Analytics and metrics
│   ├── Invoices/          # Invoice generation
│   ├── NDIS/             # NDIS-specific features
│   ├── Relationships/     # Client and entity management
│   ├── Settings/         # App configuration
│   └── Tax/              # Tax and expense management
├── Models/                # Data models and entities
├── Services/              # Business logic and external services
├── Components/            # Reusable UI components
├── Shared/               # Shared assets and utilities
└── Utilities/            # Helper functions and extensions
```

## Getting Started

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0 or later
- macOS 14.0 or later (for development)

### Installation
1. Clone the repository
2. Open `InvoicingApplication.xcodeproj` in Xcode
3. Build and run the project

### Configuration
- Configure your company details in Settings
- Set up NDIS billing settings if applicable
- Import your client and service data

## Development

### Code Style
- Follow SwiftUI best practices
- Use MVVM architecture pattern
- Implement proper error handling
- Add comprehensive documentation

### Testing
- Unit tests for business logic
- UI tests for critical user flows
- Integration tests for data persistence

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is proprietary software. All rights reserved.

## Support

For support and questions, please contact the development team.
