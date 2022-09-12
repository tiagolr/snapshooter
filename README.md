# Snapshooter

Snapshots plugin for cockos Reaper DAW

Snapshooter allows to create param snapshots and recall them or write them to the playlist creating patch morphs. Different from SWS snapshots, only the diffing of params on snapshot and current view is written to the playlist.

#### Instalation
```
install rtk package 
clone snapshooter into Reaper/Scripts
open snapshooter from inside reaper
```

Features:
  * Stores and retrieves FX params
  * Stores and retries mixer states for track Volume, Pan, Mute and Sends
  * Writes snapshots diffing from current state into the playlist creating patch morphs
  * recalls param values from snapshots into project timeline
  * tested with dozens of tracks and hundreds of params with minimal cpu load and linear overhead cost
