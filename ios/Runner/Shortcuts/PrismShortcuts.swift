import AppIntents

@available(iOS 16.0, *)
struct PrismShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: GetPrismWallpaperIntent(),
      phrases: [
        "Get a wallpaper from \(.applicationName)",
        "Get a \(.applicationName) wallpaper"
      ]
    )
  }
}
