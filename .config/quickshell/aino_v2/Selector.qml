import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell.Wayland
import QtQuick.Layouts
import Qt.labs.platform

PanelWindow {
    id: window
    
    implicitHeight: Screen.height
    implicitWidth: Screen.width
    
    color: "transparent"
    
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "hyprwall" 

    // Background Dim
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4)
        
        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
        }
    }

    // Main App State
    property string selectedCategory: "ALL"
    property var categories: ["ALL", "Blue", "Cyan", "Green", "Monochrome", "Orange", "Others", "Pink", "Purple", "Red", "Yellow"]

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 80
        anchors.bottomMargin: 80
        spacing: 40

        // Header + Search + Categories
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 25
            
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "WALLPAPER SELECTOR"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 28
                font.bold: true
                font.letterSpacing: 6
                color: "white"
                opacity: 0.8
            }

            // Search Bar (Style Rofi)
            Rectangle {
                id: searchBox
                Layout.preferredWidth: 650
                Layout.preferredHeight: 65
                Layout.alignment: Qt.AlignHCenter
                color: Qt.rgba(0, 0, 0, 0.3)
                radius: 16
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.border : Qt.rgba(255, 255, 255, 0.1)
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    
                    Text { text: "🔍"; font.pixelSize: 22; color: Theme.border }
                    
                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        placeholderText: "Search wallpapers..."
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        color: "white"
                        background: null
                        focus: true
                        
                        onTextChanged: listView.currentIndex = 0
                    }
                }
            }

            // Category Bar
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12
                
                Repeater {
                    model: categories
                    delegate: Button {
                        id: catBtn
                        text: modelData
                        flat: true
                        
                        contentItem: Text {
                            text: catBtn.text
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            font.bold: selectedCategory === modelData
                            color: selectedCategory === modelData ? "white" : Qt.rgba(255, 255, 255, 0.4)
                            horizontalAlignment: Text.AlignHCenter
                        }
                        
                        background: Rectangle {
                            implicitWidth: 95
                            implicitHeight: 32
                            color: selectedCategory === modelData ? Theme.border : Qt.rgba(255, 255, 255, 0.05)
                            radius: 8
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        
                        onClicked: {
                            selectedCategory = modelData
                            listView.currentIndex = 0
                        }
                    }
                }
            }
        }

        // Horizontal Carousel (Aino-Chan Style)
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            spacing: 35
            clip: false
            focus: true
            snapMode: ListView.SnapToItem
            preferredHighlightBegin: parent.width / 2 - 175
            preferredHighlightEnd: parent.width / 2 + 175
            highlightRangeMode: ListView.ApplyRange
            
            model: FolderListModel {
                id: folderModel
                folder: "file://" + StandardPaths.writableLocation(StandardPaths.PicturesLocation) + "/Wallpapers"
                nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif"]
                showDirs: false
            }

            delegate: Item {
                id: delegateRoot
                height: 480
                
                // Visibility Logic (Search + Category)
                visible: {
                    const nameMatch = fileName.toLowerCase().includes(searchInput.text.toLowerCase())
                    const catMatch = selectedCategory === "ALL" || fileName.toLowerCase().includes(selectedCategory.toLowerCase())
                    return nameMatch && catMatch
                }
                
                // When filtered out, set width to 0 to collapse space
                width: visible ? 350 : 0
                Behavior on width { NumberAnimation { duration: 250 } }

                property bool isCurrent: index === listView.currentIndex

                Rectangle {
                    id: card
                    anchors.centerIn: parent
                    width: isCurrent ? 350 : 280
                    height: isCurrent ? 480 : 380
                    radius: 25
                    color: Theme.background
                    border.width: isCurrent ? 4 : 1
                    border.color: isCurrent ? Theme.border : Qt.rgba(255, 255, 255, 0.1)
                    clip: true
                    
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

                    Image {
                        anchors.fill: parent
                        anchors.margins: 4
                        source: "file://" + filePath
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: isCurrent ? 1.0 : 0.4
                        
                        // Fallback for rounded corners without complex effects
                        // We use the parent card's radius + clip: true
                    }
                    
                    // Title Overlay
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 80
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.8) }
                        }
                        visible: isCurrent
                        
                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 40
                            text: fileName
                            color: "white"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: listView.currentIndex = index
                    onClicked: applyCurrent()
                }
            }
            
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Right) listView.moveCurrentIndexRight()
                else if (event.key === Qt.Key_Left) listView.moveCurrentIndexLeft()
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) applyCurrent()
                else if (event.key === Qt.Key_Escape) Qt.quit()
            }
        }
    }

    function applyCurrent() {
        const path = folderModel.get(listView.currentIndex, "filePath")
        if (path) {
            const cleanPath = path.toString().replace(/^file:\/\//, "")
            Quickshell.execDetached(["bash", "/home/rhythmcreative/.config/quickshell/hyprwall/commands.sh", cleanPath])
            Qt.quit()
        }
    }
}
