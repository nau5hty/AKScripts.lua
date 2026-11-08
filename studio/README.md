# AKScripts Studio Dummy Launcher

This is a **Roblox Studio test feature**, not an executor/loadstring feature. It launches only a test dummy that you own and tag.

## Setup

1. In your own Roblox Studio experience, create a dummy model in Workspace named `TestDummy`.
2. Make sure the model has a `HumanoidRootPart`.
3. Use Studio's Tag Editor to add the `LaunchDummy` tag to that model.
4. Copy `AKDummyHandler.server.lua` into a Script under `ServerScriptService`.
5. Copy `AKDummyLauncher.client.lua` into a LocalScript under `StarterPlayer > StarterPlayerScripts`.
6. Play-test the experience.

The server creates the `AKLaunchDummy` RemoteEvent automatically if it does not already exist. It checks the tag, distance, and a per-player cooldown before applying the launch impulse.

This feature does not target or fling other players and cannot be activated by adding it to the public client loader alone.
