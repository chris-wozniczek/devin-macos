# devin-macos

SwiftUI apps for Apple platforms.

| App | Platforms | Description |
| --- | --- | --- |
| [Battleship](Battleship/) | iOS | WW2-themed online Battleship. Play against another iPhone via Game Center or nearby Wi-Fi/Bluetooth. |
| [Boards](Boards/) | iOS, macOS | Linear/Jira-style project management: projects, kanban board, tasks, subtasks. |

Each app is defined by a `project.yml` and generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
cd Battleship && xcodegen generate && open Battleship.xcodeproj
```
