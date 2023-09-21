# Snapshooter

Reaper snapshots plugin

```
Installation:
Reapack > Synchronize Packages
Reapack > Browse packages
```

![snapshooter.gif](doc/snapshooter.gif)

Snapshooter allows to create param snapshots and recall or write them to the playlist creating patch morphs.
Different from SWS snapshots, only the params changed are written to the playlist as automation points.

Features:
  * Stores and retrieves FX params
  * Stores and retrieves mixer states for track Volume, Pan, Mute and Sends
  * Writes only changed params by diffing the current state and selected snapshot
  * Transition snapshots using tween and ease functions
  * Tested with hundreds of params with minimal overhead
  * Writes transitions into time selection from current state to snapshot

Tips:
  * Use time selection to write transitions from current state to snapshot
  * Set global automation to _READ_ to save current song snapshot
  * Set global automation to other value than _READ_ to save snapshots from mixer state
  * If params are not writing make sure they have a different current value from the snapshots
  * Use time selections to write transitions into playlist
