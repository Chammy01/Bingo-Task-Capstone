# 🎯 Bingo Task - Gamified Task Manager

[![Godot Engine](https://img.shields.io/badge/Godot-4.x-blue.svg)](https://godotengine.org/)
[![Platform](https://img.shields.io/badge/Platform-Mobile-green.svg)](https://github.com/Chammy01/Bingo-Task-Capstone)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A **Godot 4-based mobile productivity app** that gamifies task management using a bingo board mechanic. Complete tasks, earn coins, unlock music and themes, and collect achievement stamps!

---

## ✨ Features Overview

### 🎯 Bingo Board Task System
- **3x3 grid** of sticky note tiles for your daily tasks
- **Double-tap** to mark tasks as complete
- Visual **checkmark animations** on completion
- Colorful sticky note design with intuitive interface

### ⏱️ Focus Session Timer
- **Start/Pause/Stop** focus sessions
- Earn coins based on session duration with **tiered rewards**:
  - 5+ minutes: Basic coins
  - 15+ minutes: Bonus coins
  - 30+ minutes: Maximum rewards
- Stay focused and get rewarded!

### 🪙 Currency System
- **Earn coins** for completing tasks during focus sessions
- **Bonus coins** for completing rows/columns (BINGO!)
- **Spend coins** in the music shop
- Track your total coin earnings

### 🎵 Music Shop
- **Purchase and unlock** background music tracks
- **Preview tracks** before buying
- Available tracks:
  - DefaultTrack (Free)
  - Japanese Chill (50 coins)
  - Nature Vibes (100 coins)
  - Light Music (150 coins)
  - Autumn Fall (200 coins)
  - Winter Chill (250 coins)

### 📮 Achievement Stamps/Badges
Collect 6 unique stamps:

| Badge | Name | Requirement |
|-------|------|-------------|
| ⭐ | **First Steps** | Complete your first task |
| 🎯 | **First BINGO** | Complete any row or column |
| 🏆 | **BINGO Expert** | Get 3 BINGOs |
| 💰 | **Rich** | Earn 500 coins total |
| 💪 | **Grinder** | Complete 20 tasks |
| 👑 | **Legend** | Unlock all other 5 badges |

### 🎨 Themes
Unlock beautiful background themes with matching decorations:

| Theme | Description |
|-------|-------------|
| Default | Classic notebook look |
| Grass Field | Nature vibes |
| Cloud Sky | Peaceful sky |
| Cherry Blossom | Japanese spring |
| Autumn | Fall foliage |
| Snowy | Winter wonderland |

### 📅 Task Scheduling
- **Calendar integration** to plan tasks for future dates
- Scheduled tasks **auto-load** on the planned day
- Plan ahead and stay organized!

### 🔔 Notifications
- Task reminders
- Deadline warnings
- Progress updates
- Debug mode for testing (Ctrl+Shift+N or 3-finger tap)

### 💾 Persistent Save System
Auto-saves:
- Tasks and completion status
- Progress and statistics
- Coins and badges
- Music library
- Theme preferences
- Settings

---

## 🎮 Debug Shortcuts

### Bingo Board Scene (`board_manager.gd`)

| Key | Action |
|-----|--------|
| `[` | Force unlock all badges (sets stats to max values) |
| `]` | Print current stats (tasks, bingos, coins, badges) |
| `;` | Print all scheduled tasks debug info |
| `'` | Print save file locations |
| `/` | Jump to next day (test scheduled task loading) |
| `.` | Reset to real/current date |

### Stamps Scene (`stamps_scene.gd`)

| Key | Action |
|-----|--------|
| `1-6` | Unlock individual stamp by index |
| `U` | Unlock all stamps |
| `R` | Reset all stamps (lock all) |
| `D` | Print debug info |

---

## 🛠️ Tech Stack

- **Engine**: Godot 4.x
- **Language**: GDScript
- **Target Platform**: Mobile (Android/iOS)
- **Rendering**: GL Compatibility (for mobile support)

---

## 📁 Project Structure

```
Bingo-Task-Capstone/
├── scripts/
│   ├── managers/          # Global manager scripts (autoloads)
│   │   ├── BadgeManager.gd
│   │   ├── CurrencyManager.gd
│   │   ├── MusicManager.gd
│   │   ├── NotificationManager.gd
│   │   ├── SaveManager.gd
│   │   ├── SceneManager.gd
│   │   ├── SessionManager.gd
│   │   ├── SettingsManager.gd
│   │   ├── ThemeManager.gd
│   │   └── ToastManager.gd
│   ├── scenes/            # Scene-specific scripts
│   │   ├── main_menu.gd
│   │   ├── board_manager.gd
│   │   ├── shop_scene.gd
│   │   ├── stamps_scene.gd
│   │   └── base_scene.gd
│   └── ui/                # UI component scripts
│       ├── bingo_tile.gd
│       ├── calendar_2.gd
│       ├── Calendar.gd
│       ├── CalendarPopup.gd
│       ├── confirm_dialog.gd
│       ├── music_item_card.gd
│       ├── music_preview_popup.gd
│       ├── settings_popup.gd
│       ├── task_input_popup.gd
│       ├── TaskInputPopup.gd
│       ├── texture_button.gd
│       ├── toast.gd
│       └── jar.gd
├── scenes/                # .tscn scene files
│   ├── main_menu.tscn
│   ├── bingo_board.tscn
│   ├── ShopScene.tscn
│   ├── StampsScene.tscn
│   ├── BingoTile.tscn
│   ├── CalendarPopup.tscn
│   ├── ConfirmDialog.tscn
│   ├── MusicItemCard.tscn
│   ├── MusicPreviewPopup.tscn
│   ├── SettingsPopup.tscn
│   ├── TaskInputPopup.tscn
│   ├── Toast.tscn
│   └── transition_layer.tscn
├── assets/
│   ├── backgrounds/       # Background images and sprites
│   ├── fonts/             # Font files
│   ├── audio/             # Music and sound effects
│   └── animations/        # Animation sprites
├── shaders/
│   ├── dissolve.gdshader
│   └── dissolve_noise.tres
├── project.godot
├── export_presets.cfg
├── audio_bus_layout.tres
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites
- [Godot Engine 4.x](https://godotengine.org/download) (4.5+ recommended)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Chammy01/Bingo-Task-Capstone.git
   ```

2. **Open in Godot**
   - Launch Godot 4.x
   - Click "Import"
   - Navigate to the cloned folder
   - Select `project.godot`

3. **Run the project**
   - Press F5 or click the Play button
   - The main menu will launch

### Building for Mobile

1. **Configure Export**
   - Go to Project → Export
   - Add Android or iOS preset
   - Configure signing keys (Android) or provisioning profiles (iOS)

2. **Export**
   - Click "Export Project"
   - Choose your output location

---

## 🎓 About

**Bingo Task** is a Capstone Project for STI 2025, demonstrating mobile game development skills using the Godot Engine with a focus on:
- Gamification of productivity tools
- Mobile-first UI/UX design
- Persistent data management
- Audio/visual polish and theming

---

## 📄 License

This project is available under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/Chammy01/Bingo-Task-Capstone/issues).

---

*Made with ❤️ using Godot Engine*