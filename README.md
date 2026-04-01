# Simulator Manager

A polished macOS control center for iOS Simulators, built with **SwiftUI* and powered by `xcrun simctl`.
Vibe coded with care for fast iteration and developer flow.

---

## ✨ What this app does

Simulator Manager gives you one place to discover simulators, inspect installed apps, and run day-to-day QA/dev operations without jumping between Terminal commands.

### 🚀 Core capabilities

- **Simulator discovery & filtering** by iOS version, device type, and fuzzy search
- **App indexing across simulators** with fast search by app name, bundle ID, simulator ID, and more
- **App lifecycle actions**: launch, terminate, install, uninstall, reinstall
- **Simulator actions**: boot, shutdown, erase, open in Simulator
- **Data workflows**: open app containers, push files, add photos/videos, browse simulator data folders
- **Testing utilities**: screenshots, video recording, location spoofing (custom + GPX), deep links, push payloads
- **Environment controls**: appearance mode, privacy permissions, status bar overrides, simulator clipboard copy/paste
- **Live logging** with in-app stream, filtering, and export
- **Batch operations** across multiple selected simulators

---

## 🧠 Why it exists

Working with multiple simulators can get noisy fast. This app turns repetitive `simctl` tasks into a clean UI workflow so you can focus on building and testing your app instead of memorizing command flags.

---

## 🏗️ Architecture highlights

The project follows a clear separation of responsibilities inspired by VIPER:

- **View**: SwiftUI screens and components
- **Presenter**: state orchestration, filtering, and user-intent handling
- **Interactor/Services**: simulator and app operations over `simctl`
- **Router**: file dialogs, clipboard, and OS-level navigation

This structure keeps features modular, testable, and easy to evolve.

---

## 🖥️ Platform

- macOS app
- Requires Xcode command-line tools (`xcrun simctl`)
- Best used when multiple iOS simulators are available

---

## 🎯 In short

**Simulator Manager is a modern simulator operations hub for iOS developers and QA engineers who want speed, clarity, and control.**
