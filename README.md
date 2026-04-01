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

---

## 📸 Screenshots

### 🧭 Manage simulators in one place

Get a unified control center to view, filter, boot, and manage your available iOS simulators from a single interface.

![Manage simulators in one place](<Screenshots/manage simulators in one place.png>)

### 📦 Add files with ease to your simulator

Quickly push files into simulator containers and streamline data setup workflows for testing and debugging.

![Add files with ease to your simulator](<Screenshots/add files with ease to your simulator.png>)

### 🔎 Search apps and files across all simulators

Instantly find installed apps and related files using fast cross-simulator search by name, bundle ID, and other metadata.

![Search apps and files across all simulators](<Screenshots/search apps and files accross all  of your simulators.png>)

### 🧪 Testing toolkit for realistic scenarios

Simulate real-world conditions with controls for localization, battery percentage overrides, and other test-focused utilities.

![Testing toolkit capable of changing localisation, overriding battery percentage and more](<Screenshots/testing toolkit capable of changing localisation, overriding battery percentage and more.png>)

### 📜 Watch logs of a specific simulator

Track and inspect simulator logs in real time to debug behavior faster and keep QA sessions focused.

![Watch logs of certain simulator](<Screenshots/watch logs of certain simulator.png>)
