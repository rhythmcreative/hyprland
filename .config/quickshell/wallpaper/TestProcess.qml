import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    Process {
        id: proc
        command: ["ls", "/"]
        stdout: Io.pipe
        Component.onCompleted: running = true
        onExited: {
            console.log("Stdout read:", stdout.read());
        }
    }
}
