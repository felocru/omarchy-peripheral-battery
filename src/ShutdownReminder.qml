import QtQuick
import Quickshell
import Quickshell.Io

// Reminder to charge low peripherals while the machine is shutting down.
//
// logind announces every shutdown on the system bus (PrepareForShutdown)
// before user processes are stopped, and the shell is still alive to draw
// when that arrives — so the OSD can carry the reminder through the shutdown
// sequence. It reuses the OSD the stock shutdown notice uses, so it lands in
// the same place whether the shutdown started from the menu, a keybinding,
// the power button or a terminal. With nothing low, the stock notice is left
// untouched.
Item {
  id: root

  // Wired from BatteryService.
  property var devices: []
  property int lowThreshold: 20

  // How long the message stays up — the shutdown usually takes the screen
  // away first.
  property int durationMs: 5000

  readonly property var lowDevices: {
    var list = []
    var values = root.devices || []
    for (var i = 0; i < values.length; i++) {
      var d = values[i]
      if (!d || d.charging) continue
      if (d.pct <= root.lowThreshold) list.push(d)
    }
    return list
  }

  function announce() {
    if (lowDevices.length === 0) return
    // One short line: the OSD elides beyond its measured message width, so
    // the device list would never survive in it.
    osd.command = ["omarchy-osd", "-i", DeviceIcons.summary, "-m",
      "Charge your devices", "-d", String(durationMs)]
    osd.running = true
  }

  Process { id: osd }

  Process {
    id: watcher
    // The filter keeps dbus-monitor's stream to this one signal; logind is
    // the only sender on the system bus.
    command: ["dbus-monitor", "--system",
      "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForShutdown'"]
    running: true
    stdout: SplitParser {
      onRead: function (line) {
        if (line.indexOf("boolean true") !== -1) root.announce()
      }
    }
  }
}
