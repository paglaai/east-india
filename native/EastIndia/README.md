# East India

East India is a native macOS practice simulator for computer-delivered English
exams. This first build includes the timed exam flow, reading and writing
screens, question flags, passage highlights, and automatic local session
recovery.

## Open and run

Open `Package.swift` in Xcode on a Mac, select the `EastIndia` executable
scheme, and run it. The app uses only Apple frameworks and does not need a
server, account, or network connection.

This source package cannot be compiled or previewed in the Linux project
environment. Build and run it with Xcode on macOS.

## Local session recovery

Session state is encoded as JSON in the app's local `UserDefaults` store. It is
saved immediately after answers and other edits, and at least every five
seconds while a timed section is active. The saved timer deadline uses an
absolute date, so closing and reopening the app does not pause the exam clock.

Use **Start over** on the completion screen to clear the saved session.
