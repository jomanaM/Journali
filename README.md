# Journali

Journali is a SwiftUI diary for iPhone. It stores entries locally so they remain available after you close and reopen the app.

## Run in Xcode

1. Open `Journali.xcodeproj` in Xcode 15 or later.
2. Select the **Journali** scheme and an iPhone simulator running iOS 17 or later.
3. Press **⌘R** to build and run.

To run on your iPhone, select a development team for the Journali target under **Signing & Capabilities**. Set a unique bundle identifier if Xcode asks for one.

The microphone in the search bar uses Apple’s on-device speech recognition. Voice search needs a device and language that support on-device recognition, plus permission to use the microphone and recognize speech.

## Find the MVVM pieces

| Layer | Where to look | Responsibility |
| --- | --- | --- |
| Model | `JournalEntry` in `JournalData.swift` | Holds an entry’s title, text, date, and bookmark status. |
| View | `JournalHomeView.swift` and `JournalEditorView.swift` | Display the list and editor, collect input, and forward actions. |
| ViewModel | `JournalViewModel` in `JournalData.swift` | Publishes entry and search state, computes the visible list, and coordinates saving, bookmarking, and deleting. |

`JournaliApp.swift` starts the app. `JournalStyle.swift` defines shared visual styling. The editor keeps a draft while you type and passes it to the view model when you save. Local storage writes the saved entries to a file in the app’s Application Support folder.
