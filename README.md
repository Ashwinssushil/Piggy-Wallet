# Piggy Wallet - Flutter Personal Finance App

A comprehensive Flutter application for personal finance management with transaction tracking, authentication, and data visualization.

## 📱 App Versions

This repository contains two versions of the Piggy Wallet app:

### Piggy_v1.0.0
- Basic wallet functionality
- Transaction management (add, view, delete)
- Balance calculation
- Dark theme UI
- Local database storage with SQLite
- Export functionality

### Piggy_v1.0.1
- Enhanced authentication system
- Improved user interface
- Additional security features
- Extended transaction management
- Better data persistence
- Enhanced settings and customization

## 🚀 Features

- **Transaction Management**: Add, view, edit, and delete financial transactions
- **Balance Tracking**: Real-time balance calculation and display
- **Authentication**: Secure login system (v1.0.1)
- **Dark Theme**: Modern dark UI design
- **Data Export**: Export transaction data
- **Cross-Platform**: Runs on Android, iOS, Web, Windows, macOS, and Linux
- **Local Storage**: SQLite database for offline functionality

## 🛠️ Technologies Used

- **Flutter**: Cross-platform mobile development framework
- **Dart**: Programming language
- **SQLite**: Local database storage
- **Material Design**: UI components and theming

## 📦 Dependencies

Key packages used in the project:
- `sqflite`: SQLite database
- `intl`: Internationalization and date formatting
- `file_picker`: File selection functionality
- `printing`: PDF generation and printing
- `path_provider`: File system paths

## 🏗️ Project Structure

```
Piggy-wallet/
├── Piggy_v1.0.0/          # Version 1.0.0
│   ├── lib/
│   │   ├── main.dart       # Main application entry
│   │   ├── database.dart   # Database helper
│   │   └── settings.dart   # Settings screen
│   ├── android/            # Android platform files
│   ├── ios/               # iOS platform files
│   ├── web/               # Web platform files
│   └── pubspec.yaml       # Dependencies
│
├── Piggy_v1.0.1/          # Version 1.0.1
│   ├── lib/
│   │   ├── main.dart       # Main application entry
│   │   ├── home.dart       # Home screen
│   │   ├── login.dart      # Authentication
│   │   ├── database.dart   # Enhanced database
│   │   ├── auth_service.dart # Authentication service
│   │   └── settings.dart   # Enhanced settings
│   └── ...                # Platform files
│
└── README.md              # This file
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / VS Code
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Ashwinssushil/Piggy-wallet.git
   cd Piggy-wallet
   ```

2. **Choose a version to run**
   ```bash
   # For version 1.0.0
   cd Piggy_v1.0.0
   
   # OR for version 1.0.1
   cd Piggy_v1.0.1
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

### Building for Production

```bash
# Android APK
flutter build apk --release

# iOS (requires macOS and Xcode)
flutter build ios --release

# Web
flutter build web --release

# Windows (requires Windows)
flutter build windows --release
```

## 📱 Screenshots

*Screenshots will be added soon*

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**Ashwin S Sushil**
- GitHub: [@Ashwinssushil](https://github.com/Ashwinssushil)

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Material Design for UI guidelines
- SQLite for reliable local storage
- All contributors and testers

## 📞 Support

If you have any questions or need help, please open an issue in this repository.

---

⭐ Star this repository if you found it helpful!