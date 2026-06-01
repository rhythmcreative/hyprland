import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell.Wayland
import QtQuick.Layouts
import Qt.labs.platform
import QtQuick.Effects

PanelWindow {
    id: window
    
    implicitHeight: Screen.height
    implicitWidth: Screen.width
    
    color: "transparent"
    
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "hyprwall" 

    // Background Dim + Blur effect via namespace
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4)
        
        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
        }
    }

    // Main App State
    property string selectedCategory: "blue"
    property var categories: ["Blue", "Cyan", "Green", "Monochrome", "Orange", "Others", "Pink", "Purple", "Red", "Yellow"]

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 100
        anchors.bottomMargin: 100
        spacing: 50

        // Header Section
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 25
            
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "WALLPAPER SELECTOR"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 32
                font.bold: true
                font.letterSpacing: 8
                color: "white"
                opacity: 0.9
            }

            // Search Bar (Style Rofi)
            Rectangle {
                Layout.preferredWidth: 700
                Layout.preferredHeight: 70
                Layout.alignment: Qt.AlignHCenter
                color: Qt.rgba(0, 0, 0, 0.3)
                radius: 18
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.border : Qt.rgba(255, 255, 255, 0.1)
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 25
                    anchors.rightMargin: 20
                    
                    Text { text: "🔍"; font.pixelSize: 24; color: Theme.border }
                    
                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        placeholderText: "Type to filter " + selectedCategory + " wallpapers..."
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 20
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
                            font.pixelSize: 16
                            font.bold: selectedCategory.toLowerCase() === modelData.toLowerCase()
                            color: selectedCategory.toLowerCase() === modelData.toLowerCase() ? "white" : Qt.rgba(255, 255, 255, 0.4)
                            horizontalAlignment: Text.AlignHCenter
                        }
                        
                        background: Rectangle {
                            implicitWidth: 100
                            implicitHeight: 35
                            color: selectedCategory.toLowerCase() === modelData.toLowerCase() ? Theme.border : Qt.rgba(255, 255, 255, 0.05)
                            radius: 8
                            
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        
                        onClicked: {
                            selectedCategory = modelData.toLowerCase()
                            listView.currentIndex = 0
                        }
                    }
                }
            }
        }

        // Main Carousel
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            spacing: 40
            clip: false // Allow cards to scale outside bounds during transition
            focus: true
            snapMode: ListView.SnapToItem
            preferredHighlightBegin: parent.width / 2 - 200
            preferredHighlightEnd: parent.width / 2 + 200
            highlightRangeMode: ListView.ApplyRange
            
            model: FolderListModel {
                id: folderModel
                folder: "file://" + StandardPaths.writableLocation(StandardPaths.PicturesLocation) + "/Wallpapers/" + selectedCategory
                nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif"]
                showDirs: false
            }

            delegate: Item {
                width: 400
                height: 550
                
                property bool isCurrent: index === listView.currentIndex
                visible: searchInput.text === "" || fileName.toLowerCase().includes(searchInput.text.toLowerCase())
                
                Rectangle {
                    id: card
                    anchors.centerIn: parent
                    width: isCurrent ? 400 : 320
                    height: isCurrent ? 550 : 440
                    radius: 30
                    color: Theme.background
                    border.width: isCurrent ? 5 : 1
                    border.color: isCurrent ? Theme.border : Qt.rgba(255, 255, 255, 0.1)
                    clip: true
                    
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    Behavior on border.color { ColorAnimation { duration: 300 } }

                    Image {
                        id: wpImage
                        anchors.fill: parent
                        anchors.margins: 4
                        source: "file://" + filePath
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: isCurrent ? 1.0 : 0.4
                        Behavior on opacity { NumberAnimation { duration: 400 } }
                    }
                    
                    // Shadow effect for the current card
                    layer.enabled: isCurrent
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Theme.border
                        shadowBlur: 1.0
                        shadowVerticalOffset: 0
                        shadowHorizontalOffset: 0
                    }

                    // Title Overlay
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 100
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.9) }
                        }
                        visible: isCurrent
                        
                        Text {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottomMargin: 25
                            width: parent.width - 60
                            text: fileName
                            color: "white"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 18
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
                if (event.key === Qt.Key_Right || event.key === Qt.Key_L) listView.moveCurrentIndexRight()
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) listView.moveCurrentIndexLeft()
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
    
    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 40
        text: "←  →  TO NAVIGATE  •  ENTER TO APPLY  •  ESC TO CLOSE"
        color: "white"
        opacity: 0.3
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        font.letterSpacing: 4
    }
}
