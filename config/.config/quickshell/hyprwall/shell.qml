import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell.Wayland
import QtQuick.Layouts

PanelWindow {
    id: main
    
    // Configuración Fullscreen EXACTAMENTE como Rofi style-3
    implicitHeight: Screen.height
    implicitWidth: Screen.width
    
    color: "transparent"
    
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "hyprwall"

    Component.onCompleted: {
        Quickshell.execDetached(["bash", Quickshell.shellPath("cache.sh"), Quickshell.shellDir])
    }

    FileView {
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: configs
            property string wallpaper_path
            property string cache_path
            property string border_color
        }
    }

    // Estado de la aplicación
    property string currentView: "colors" // "colors" o "wallpapers"
    property string selectedColor: ""

    // Fondo oscuro con transparencia (Hyprland aplicará el blur vía namespace hyprwall)
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
    }

    // Contenedor principal (Padding idéntico a Rofi style-3)
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 160 
        anchors.leftMargin: 225
        anchors.rightMargin: 225
        anchors.bottomMargin: 100
        spacing: 60

        // Inputbar (Buscador)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            Layout.maximumWidth: 900
            Layout.alignment: Qt.AlignHCenter
            color: Qt.rgba(0, 0, 0, 0.25)
            radius: 16
            border.color: searchBar.activeFocus ? configs.border_color : Qt.rgba(255, 255, 255, 0.1)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 30
                anchors.rightMargin: 20
                
                Text {
                    text: currentView === "colors" ? "🎨" : "🖼️"
                    font.pixelSize: 26
                    color: configs.border_color
                }

                TextField {
                    id: searchBar
                    Layout.fillWidth: true
                    placeholderText: currentView === "colors" ? "Selecciona un color..." : ("Buscando en " + selectedColor + "...")
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 22
                    color: "white"
                    background: null
                    focus: true
                    
                    onTextChanged: grid.currentIndex = 0
                    
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            if (currentView === "wallpapers") {
                                currentView = "colors"
                                searchBar.text = ""
                            } else {
                                Qt.quit()
                            }
                        }
                    }
                }
                
                Text {
                    visible: currentView === "wallpapers"
                    text: "[ESC para volver]"
                    color: Qt.rgba(255, 255, 255, 0.4)
                    font.pixelSize: 14
                }
            }
        }

        // GridView (Listview style)
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: currentView === "colors" ? parent.width / 5 : parent.width / 7
            cellHeight: cellWidth * (currentView === "colors" ? 0.6 : 0.8)
            clip: true
            focus: true
            currentIndex: 0

            // Modelo dinámico según la vista
            model: currentView === "colors" ? colorModel : wallpaperModel

            ListModel {
                id: colorModel
                ListElement { name: "Blue"; icon: "🟦"; folder: "blue" }
                ListElement { name: "Cyan"; icon: "💧"; folder: "cyan" }
                ListElement { name: "Green"; icon: "🟩"; folder: "green" }
                ListElement { name: "Monochrome"; icon: "🏁"; folder: "monochrome" }
                ListElement { name: "Orange"; icon: "🟧"; folder: "orange" }
                ListElement { name: "Pink"; icon: "🌸"; folder: "pink" }
                ListElement { name: "Purple"; icon: "🟪"; folder: "purple" }
                ListElement { name: "Red"; icon: "🟥"; folder: "red" }
                ListElement { name: "Yellow"; icon: "🟨"; folder: "yellow" }
                ListElement { name: "Others"; icon: "📁"; folder: "others" }
            }

            FolderListModel {
                id: wallpaperModel
                folder: "file://" + configs.wallpaper_path + "/" + selectedColor.toLowerCase()
                showDirs: false
                nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif"]
                sortField: FolderListModel.Name
            }

            delegate: Item {
                width: grid.cellWidth
                height: grid.cellHeight
                
                property bool isCurrent: index === grid.currentIndex
                // Filtrado simple por texto
                visible: {
                    const searchTerm = searchBar.text.toLowerCase()
                    if (currentView === "colors") {
                        return name.toLowerCase().includes(searchTerm)
                    } else {
                        return fileName.toLowerCase().includes(searchTerm)
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 12
                    radius: 15
                    color: isCurrent ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
                    border.width: isCurrent ? 2 : 0
                    border.color: configs.border_color
                    
                    Behavior on color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 15

                        // Contenido visual (Icono para colores, Thumbnail para wallpapers)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Qt.rgba(255, 255, 255, 0.03)
                            radius: 10
                            clip: true

                            // Vista de Colores
                            Text {
                                visible: currentView === "colors"
                                anchors.centerIn: parent
                                text: model.icon
                                font.pixelSize: 64
                            }

                            // Vista de Wallpapers
                            Image {
                                visible: currentView === "wallpapers"
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                source: currentView === "wallpapers" ? ("file://" + configs.cache_path + fileName) : ""
                                opacity: isCurrent ? 1.0 : 0.8
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                
                                // Fallback a la imagen original si no hay thumbnail
                                onStatusChanged: {
                                    if (status === Image.Error && currentView === "wallpapers") {
                                        source = filePath
                                    }
                                }
                            }
                        }

                        // Texto
                        Text {
                            Layout.fillWidth: true
                            text: currentView === "colors" ? name : fileName
                            color: isCurrent ? configs.border_color : "white"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: currentView === "colors" ? 18 : 12
                            font.bold: isCurrent
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideMiddle
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        grid.currentIndex = index
                        main.handleAction()
                    }
                    onEntered: grid.currentIndex = index
                }
            }

            function handleAction() {
                if (currentView === "colors") {
                    selectedColor = colorModel.get(currentIndex).folder
                    currentView = "wallpapers"
                    searchBar.text = ""
                    grid.currentIndex = 0
                } else {
                    const path = wallpaperModel.get(currentIndex, "filePath")
                    if (path) {
                        Quickshell.execDetached(["bash", Quickshell.shellPath("commands.sh"), path])
                        Qt.quit()
                    }
                }
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Right) grid.moveCurrentIndexRight()
                else if (event.key === Qt.Key_Left) grid.moveCurrentIndexLeft()
                else if (event.key === Qt.Key_Down) grid.moveCurrentIndexDown()
                else if (event.key === Qt.Key_Up) grid.moveCurrentIndexUp()
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) handleAction()
                else if (event.key === Qt.Key_Escape) {
                    if (currentView === "wallpapers") {
                        currentView = "colors"
                        searchBar.text = ""
                    } else {
                        Qt.quit()
                    }
                }
            }
        }
    }
}
