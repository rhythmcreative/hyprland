import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Qt.labs.folderlistmodel
import Qt.labs.platform
import QtQuick.Shapes
import QtQuick.Effects
import QtQml.Models

import Quickshell
import Quickshell.Io
import Quickshell.Widgets

import Quickshell.Wayland
import QtMultimedia

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window
            required property var modelData
            screen: modelData

            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"
            implicitWidth: screen.width
            implicitHeight: screen.height
            MouseArea {
                anchors.fill: parent

                onClicked: mouse => {
                    var p = panel.mapFromItem(this, mouse.x, mouse.y);

                    if (p.x < 0 || p.y < 0 || p.x > panel.width || p.y > panel.height) {
                        Qt.quit();
                    }
                }
            }

            property string defaultBaseFolder: StandardPaths.writableLocation(StandardPaths.PicturesLocation) + "/Wallpapers"

            property string defaultStaticWallpaperFolder: StandardPaths.writableLocation(StandardPaths.PicturesLocation) + "/Wallpapers"

            property string defaultThumbFolder: String(StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace(/^file:\/\//, "") + "/.cache/quickshell-wallpaper-thumbs"

            property string baseFolder: defaultBaseFolder
            property string staticWallpaperFolder: defaultStaticWallpaperFolder
            property string thumbFolder: defaultThumbFolder
            property string ffmpegPath: "/usr/bin/ffmpeg"

            property bool anyHovered: false
            property bool keyboardNavigation: true
            property int targetIndexTracker: 0
            property bool isInitialLoad: true
            property string lastWallpaperPath: ""
            property var thumbQueue: []
            property var thumbBatchQueue: []
            Timer {
                id: thumbBatchTimer
                interval: 500
                running: false
                repeat: false
                onTriggered: {
                    if (thumbBatchQueue.length === 0) return;
                    let batch = thumbBatchQueue.join("\n");
                    thumbBatchQueue = [];
                    let proc = Qt.createQmlObject('import Quickshell.Io; Process {}', window);
                    proc.command = ["/bin/bash", "-c", "echo '" + batch.replace(/'/g, "'\\''") + "' | /home/rhythmcreative/.local/bin/batch-thumbnails.sh"];
                    proc.startDetached();
                }
            }
            property var validThumbs: new Set()
            property bool showHelp: false
            property bool showMatureContent: false
            property bool isMatureContentTriggered: false
            property string toggleMatureContentKey: ""
            property bool showFavorite: false
            property bool showStatic: true
            property bool showDynamic: true
            property bool showPlaylist: false
            property var dynamicIndexes: []
            property var staticIndexes: []
            property int preCommandIndex: -1
            property string preCommandPath: ""
            property bool wasInCommandMode: false
            property bool suppressTextHandler: false
            property var favorites: []
            property string settingsPath: ""
            property string sortMode: "default"
            property bool sortDescending: false
            property var usageMap: ({})
            property bool enableGifPreview: true
            property string statusMessage: ""
            property var suggestions: []
            property int suggestionIndex: -1
            property string filterTag: ""
            property var playlist: []
            property int playlistInterval: 30
            property bool playlistActive: false
            property bool playlistShuffle: false
            property real playlistLastApplied: 0
            property var renamedTitles: ({})
            property string pendingScrollPath: ""
            property int hoveredIndex: -1
            property int previousHoveredIndex: -1
            property int previousCurrentIndex: -1
            property real cardWidth: 200
            property real cardHeight: 360
            property real cardScale: 1.2
            property real cardSpacing: 20
            
            FileView {
                id: pathCompleteFileView
                blockLoading: true
                onLoaded: {
                    let lines = text().trim().split("\n").filter(l => l.length > 0);
                    Qt.callLater(() => {
                        window.suggestions = [];
                        window.suggestions = lines;
                        window.suggestionIndex = lines.length > 0 ? 0 : -1;
                    });
                }
            }

            Process {
                id: pathCompleteProcess
            }

            Timer {
                id: pathCompleteTimer
                interval: 150
                repeat: false
                onTriggered: {
                    pathCompleteFileView.path = "";
                    pathCompleteFileView.path = "file:///tmp/qs-path-complete.txt";
                    pathCompleteFileView.reload();
                }
            }

            Process {
                id: wallpaperProcess
            }
            Process {
                id: thumbProcess
                onExited: window.drainThumbQueue()
            }

            Process {
                id: writeProcess
            }
            Process {
                id: workshopidProcess
            }
            Process {
                id: deleteFolderProcess
            }

            Process {
                id: initSettingsProcess
            }

            Process {
                id: playlistDaemon
                Component.onCompleted: {
                    let home = stripFileScheme(StandardPaths.writableLocation(StandardPaths.HomeLocation));
                    command = ["/bin/bash", "-c", `pgrep -fx 'bash.*wallpaper-playlist.sh' > /dev/null || { nohup ${shQuote(home + "/.local/bin/wallpaper-playlist.sh")} > /dev/null 2>&1 & disown; }`];
                    startDetached();
                }
            }

            ListModel {
                id: masterModel
            }

            FileView {
                id: sharedFileView

                property var loadCallback: null
                onLoaded: {
                    if (loadCallback) {
                        loadCallback(text().trim());
                        loadCallback = null;
                    }
                }
            }

            FileView {
                id: settingsFile
                path: settingsPath
                blockLoading: true
            }

            Timer {
                id: statusMessageTimer
                interval: 2500
                repeat: false
                onTriggered: window.statusMessage = ""
            }

            SequentialAnimation {
                id: filterAnimation

                NumberAnimation {
                    target: listView
                    property: "opacity"
                    to: 0
                    duration: 240
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.5, 0.5, 0.75, 1.0, 1, 1]
                }

                ScriptAction {
                    script: {
                        listView.interactive = false;
                        filterWallpapers();
                    }
                }

                NumberAnimation {
                    target: listView
                    property: "opacity"
                    to: 1
                    duration: 240
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.5, 0.5, 0.75, 1.0, 1, 1]
                }

                ScriptAction {
                    script: {
                        listView.interactive = true;
                        if (window.pendingScrollPath !== "") {
                            let target = window.pendingScrollPath;
                            window.pendingScrollPath = "";
                            for (let i = 0; i < filteredModel.count; i++) {
                                if (stripFileScheme(filteredModel.get(i).folder).replace(/\/$/, "") === target) {
                                    listView.currentIndex = i;
                                    Qt.callLater(() => listView.positionViewAtIndex(i, ListView.Center));
                                    break;
                                }
                            }
                        }
                    }
                }
            }

            function shQuote(s) {
                return "'" + String(s).replace(/'/g, "'\\''") + "'";
            }

            function shJoin(parts) {
                return parts.map(shQuote).join(" ");
            }

            function setHoveredIndex(newIndex) {
                if (hoveredIndex === newIndex)
                    return

                previousHoveredIndex = hoveredIndex
                hoveredIndex = newIndex
            }

            function clearHoveredIndex(oldIndex) {
                if (hoveredIndex === oldIndex)
                    hoveredIndex = -1
            }

            function updateSuggestions(input) {
                let raw = input.trim();
                let lower = raw.toLowerCase();
                suggestions = [];
                suggestionIndex = -1;

                if (raw === "")
                    return;
                if (lower.startsWith(":tag")) {
                    let partial = lower.replace(":tag", "").trim();
                    let allTags = getUniqueTags();
                    suggestions = allTags.filter(t => t.startsWith(partial) && t !== partial).map(t => ":tag " + t);
                    suggestionIndex = suggestions.length > 0 ? 0 : -1;
                    hoverItem = "";
                    return;
                }

                if (raw.startsWith(":") && !raw.includes(" ")) {
                    let matureSuggestion = ":" + toggleMatureContentKey;
                    let commands = [":static", ":dynamic", ":favorite", matureSuggestion, ":gif", ":rename", ":playlist", ":playlistshuffle", ":playlist clear", ":width", ":height", ":spacing", ":scale", ":random", ":randomstatic", ":randomfav", ":export", ":setfolder", ":setstatic", ":setthumb", ":setffmpeg", ":clearcache", ":reload", ":tag", ":id", ":open", ":sort default", ":sort name", ":sort recent", ":sort favorite", ":sort random", ":help"];
                    suggestions = commands.filter(c => c.startsWith(lower) && c !== lower);
                    suggestionIndex = suggestions.length > 0 ? 0 : -1;
                    return;
                }

                let pathCommands = [":setfolder ", ":sf ", ":setstatic ", ":ss ", ":setthumb ", ":st ", ":setffmpeg "];
                let isPathCmd = pathCommands.some(p => lower.startsWith(p));
                if (isPathCmd) {
                    let spaceIdx = raw.indexOf(" ");
                    let partial = raw.substring(spaceIdx + 1);
                    if (partial.length > 0) {
                        let cmd;
                        if (partial.endsWith("/")) {
                            cmd = "find " + shQuote(partial) + " -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sed 's|$|/|' | head -20 > /tmp/qs-path-complete.txt";
                        } else {
                            let lastSlash = partial.lastIndexOf("/");
                            let dir = lastSlash >= 0 ? partial.substring(0, lastSlash + 1) : "/";
                            let base = lastSlash >= 0 ? partial.substring(lastSlash + 1) : partial;
                            cmd = "find " + shQuote(dir) + " -maxdepth 1 -mindepth 1 -type d -iname " + shQuote("*" + base + "*") + " 2>/dev/null | sed 's|$|/|' | head -20 > /tmp/qs-path-complete.txt";
                        }
                        pathCompleteProcess.command = ["/bin/bash", "-c", cmd];
                        pathCompleteProcess.startDetached();
                        pathCompleteTimer.restart();
                    } else {
                        window.suggestions = [];
                    }
                    return;
                }
            }

            function acceptSuggestion(accepted) {
                let raw = searchInput.text.trim();
                let pathCommands = [":setfolder ", ":sf ", ":setstatic ", ":ss ", ":setthumb ", ":st ", ":setffmpeg "];
                let matchedCmd = pathCommands.find(p => raw.toLowerCase().startsWith(p));
                window.suppressTextHandler = true;
                if (matchedCmd) {
                    let cmdPart = raw.substring(0, raw.indexOf(" ") + 1);
                    searchInput.text = cmdPart + accepted;
                    window.suppressTextHandler = false;
                    searchInput.cursorPosition = searchInput.text.length;
                    window.suggestions = [];
                    window.suggestionIndex = -1;
                    if (accepted.endsWith("/")) {
                        Qt.callLater(() => updateSuggestions(searchInput.text));
                    }
                } else {
                    searchInput.text = accepted;
                    window.suppressTextHandler = false;
                    searchInput.cursorPosition = searchInput.text.length;
                    window.suggestions = [];
                    window.suggestionIndex = -1;
                    filterWallpapersAnimation();
                }
            }

            function getUniqueTags() {
                let tags = new Set();
                for (let i = 0; i < masterModel.count; i++) {
                    let raw = masterModel.get(i).tags;
                    try {
                        let arr = JSON.parse(raw || "[]");
                        arr.forEach(t => tags.add(t));
                    } catch (e) {}
                }
                return Array.from(tags).sort();
            }

            function showStatus(msg) {
                window.statusMessage = msg;
                statusMessageTimer.restart();
            }

            function stripFileScheme(path) {
                return String(path).replace(/^file:\/\//, "");
            }

            function getWallpaperInfo(folderPath, callback) {
                let jsonPath = folderPath + "/project.json";
                var xhr = new XMLHttpRequest();
                xhr.open("GET", jsonPath);
                xhr.onreadystatechange = function () {
                    if (xhr.readyState === XMLHttpRequest.DONE) {
                        try {
                            let json = JSON.parse(xhr.responseText);
                            callback({
                                title: String(json.title || "Untitled"),
                                preview: json.preview || json.file || "",
                                contentrating: json.contentrating || "Everyone",
                                tags: Array.isArray(json.tags) ? json.tags.map(t => String(t).toLowerCase()) : []
                            });
                        } catch (e) {
                            let cleanPath = stripFileScheme(folderPath);
                            callback({
                                title: cleanPath.split("/").pop(),
                                preview: ""
                            });
                        }
                    }
                };
                xhr.send();
            }

            function getCurrentFilteredItem() {
                if (listView.currentIndex < 0 || listView.currentIndex >= filteredModel.count)
                    return null;

                return filteredModel.get(listView.currentIndex);
            }

            function applyWallpaper(item) {
                if (!item || !item.folder)
                    return;
                var folder = stripFileScheme(item.folder).replace(/\/$/, "");
                let now = Date.now();
                window.usageMap[folder] = now;
                var home = stripFileScheme(StandardPaths.writableLocation(StandardPaths.HomeLocation));
                var scriptPath = item.isStatic ? home + "/.local/bin/wallpaper-apply-static.sh" : home + "/.local/bin/wallpaper-apply.sh";

                console.log("Applying wallpaper:", folder);

                let args = ["/bin/bash", scriptPath,];

                if (!item.isStatic) {
                    let cleanFolder = stripFileScheme(item.folder).replace(/\/$/, "");
                    let fullPath = item.preview && item.preview !== "" ? cleanFolder + "/" + item.preview : cleanFolder;

                    let hash = Qt.md5(fullPath);

                    args.push("--hash", hash);
                    args.push("--thumb-folder", window.thumbFolder);
                }
                args.push(folder);

                wallpaperProcess.command = args;
                wallpaperProcess.startDetached();

                window.lastWallpaperPath = folder;
                saveSettings();
            }

            function queueThumbnail(filePath) {
                let clean = stripFileScheme(filePath).replace(/\/$/, "");
                let hash = Qt.md5(clean);
                window.validThumbs.add(hash);
                
                thumbBatchQueue.push(hash + "|" + clean);
                thumbBatchTimer.restart();
                
                return window.thumbFolder + "/" + hash + ".jpg";
            }

            function drainThumbQueue() {
                // Obsoleto, pero mantenemos la firma por compatibilidad si se llama desde otro lado
            }

            function cleanupThumbnails(validSet) {
                if (validSet.size === 0)
                    return;

                let hashes = Array.from(validSet).join("|");
                let qThumbFolder = shQuote(window.thumbFolder);

                let cmd = `
                    shopt -s nullglob
                    for file in ${qThumbFolder}/*.jpg; do
                        name=$(basename "$file" .jpg)
                        if [[ ! "$name" =~ ^(${hashes})$ ]]; then
                            rm -- "$file"
                        fi
                    done
                `;

                thumbQueue.push(cmd);
                drainThumbQueue();
            }

            function loadSettings(callback) {
                let settingsPath = Qt.resolvedUrl("settings.json");

                sharedFileView.loadCallback = function (data) {
                    try {
                        let json = JSON.parse(data.trim());
                        window.showMatureContent = !!json.showMatureContent;
                        window.toggleMatureContentKey = json.toggleMatureContentKey || "sus";
                        if (!window.toggleMatureContentKey || window.toggleMatureContentKey.trim() === "")
                            window.toggleMatureContentKey = "sus";
                        window.cardWidth = json.width || 200;
                        window.cardHeight = json.height || 360;
                        window.cardSpacing = json.spacing || 20;
                        window.cardScale = json.scale || 1.2;
                        window.playlist = json.playlist || [];
                        window.playlistInterval = json.playlistInterval || 30;
                        window.playlistActive = !!json.playlistActive;
                        window.playlistShuffle = !!json.playlistShuffle;
                        window.showPlaylist = !!json.showPlaylist;
                        window.playlistLastApplied = json.playlistLastApplied || 0;
                        window.enableGifPreview = json.enableGifPreview !== false;
                        window.sortMode = json.sortMode || "default";
                        window.sortDescending = !!json.sortDescending;
                        window.showStatic = !!json.showStatic;
                        window.showDynamic = !!json.showDynamic;
                        window.showFavorite = !!json.showFavorite;
                        window.lastWallpaperPath = json.lastWallpaper || "";
                        window.baseFolder = json.baseFolder || window.defaultBaseFolder;
                        window.staticWallpaperFolder = json.staticWallpaperFolder || window.defaultStaticWallpaperFolder;
                        window.thumbFolder = json.thumbFolder || window.defaultThumbFolder;
                        window.ffmpegPath = json.ffmpegPath || "/usr/bin/ffmpeg";
                        window.filterTag = json.filterTag || "";
                        window.renamedTitles = json.renamedTitles || {};
                        window.favorites = json.favorites || [];
                        window.usageMap = json.usageMap || {};
                    } catch (e) {
                        console.warn("Failed to parse settings:", e);
                        window.showMatureContent = false;
                        window.cardWidth = 200;
                        window.cardHeight = 360;
                        window.cardSpacing = 20;
                        window.cardScale = 1.2;
                        window.favorites = [];
                        window.playlist = [];
                        window.playlistActive = false;
                        window.playlistShuffle = false;
                        window.showPlaylist = false;
                        window.playlistInterval = 30;
                        window.playlistLastApplied = 0;
                        window.renamedTitles = ({});
                        window.usageMap = ({});
                        window.toggleMatureContentKey = "sus";
                        window.enableGifPreview = true;
                        window.sortMode = "default";
                        window.sortDescending = false;
                        window.filterTag = "";
                        window.baseFolder = window.defaultBaseFolder;
                        window.staticWallpaperFolder = window.defaultStaticWallpaperFolder;
                        window.thumbFolder = window.defaultThumbFolder;
                        window.ffmpegPath = "/usr/bin/ffmpeg";
                    }
                    if (callback)
                        callback();
                };

                sharedFileView.path = settingsPath;
            }

            function saveSettings() {
                let settingsPath = stripFileScheme(Qt.resolvedUrl("settings.json"));

                let jsonStr = JSON.stringify({
                    showMatureContent: window.showMatureContent,
                    toggleMatureContentKey: window.toggleMatureContentKey,
                    width: window.cardWidth,
                    height: window.cardHeight,
                    spacing: window.cardSpacing,
                    scale: window.cardScale,
                    playlist: window.playlist,
                    playlistInterval: window.playlistInterval,
                    playlistActive: window.playlist.length > 0 && window.playlistActive,
                    playlistShuffle: window.playlistShuffle,
                    playlistLastApplied: window.playlistLastApplied,
                    showPlaylist: window.showPlaylist,
                    enableGifPreview: window.enableGifPreview,
                    sortMode: window.sortMode,
                    sortDescending: window.sortDescending,
                    showStatic: window.showStatic,
                    showDynamic: window.showDynamic,
                    showFavorite: window.showFavorite,
                    lastWallpaper: window.lastWallpaperPath,
                    baseFolder: stripFileScheme(window.baseFolder),
                    staticWallpaperFolder: stripFileScheme(window.staticWallpaperFolder),
                    thumbFolder: window.thumbFolder,
                    ffmpegPath: window.ffmpegPath,
                    filterTag: window.filterTag,
                    renamedTitles: window.renamedTitles,
                    favorites: window.favorites,
                    usageMap: window.usageMap
                });

                writeProcess.command = [
                    "/bin/bash",
                    "-c",
                    "printf %s " + shQuote(jsonStr) + " > " + shQuote(settingsPath)
                ];
                writeProcess.startDetached();
            }

            function reloadWallpapers() {
                window.anyHovered = false
                window.hoveredIndex = -1
                window.previousHoveredIndex = -1
                window.previousCurrentIndex = -1
                if (window.keyboardNavigation)
                window.keyboardNavigation = true
                masterModel.clear();
                filteredModel.clear();
                window.validThumbs.clear();
                window.thumbQueue = [];
                scanWallpapers();
            }

            function getFilteredCandidates() {
                let candidates = [];
                for (let i = 0; i < masterModel.count; i++) {
                    let item = masterModel.get(i);
                    let allowedContent = window.showMatureContent || (item.contentrating !== "Mature" && item.contentrating !== "Questionable");
                    let matchesFavorite = !window.showFavorite || item.isFavorite;
                    let matchesStatic = !window.showStatic || item.isStatic;
                    let matchesDynamic = !window.showDynamic || !item.isStatic;
                    let itemTags = [];
                    try {
                        itemTags = JSON.parse(item.tags || "[]");
                    } catch (e) {}
                    let matchesTag = window.filterTag === "" || itemTags.some(t => t === window.filterTag.toLowerCase());
                    let matchesPlaylist = !window.showPlaylist || window.playlist.indexOf(stripFileScheme(item.folder).replace(/\/$/, "")) !== -1;
                    if (allowedContent && matchesFavorite && matchesStatic && matchesDynamic && matchesTag && matchesPlaylist)
                        candidates.push(item);
                }
                return candidates;
            }

            Shortcut {
                sequences: ["Return", "Enter"]
                onActivated: {
                    window.suggestions = [];
                    window.suggestionIndex = -1;
                    if (window.showHelp) {
                        window.showHelp = false;
                        return;
                    }
                    let rawCmd = searchInput.text.trim();
                    let cmd = rawCmd.toLowerCase();
                    let expectedPrefix = ":";
                    let matureCmd = expectedPrefix + window.toggleMatureContentKey.toLowerCase();

                    if (cmd === ":help" || cmd === ":h") {
                        window.showHelp = true;
                        filterWallpapersAnimation();
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        searchDebounceTimer.stop();
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd.startsWith(":setffmpeg ")) {
                        let newPath = rawCmd.replace(/^:setffmpeg\s+/i, "").trim();
                        let fileName = newPath.split("/").pop();
                        let badChars = /[\n\r\t"'`]/.test(newPath);

                        if (newPath === "" || !newPath.startsWith("/") || fileName !== "ffmpeg" || badChars) {
                            showStatus("Error! ffmpeg path must be a clean absolute path ending in /ffmpeg");
                            window.suppressTextHandler = true;
                            searchInput.text = "";
                            window.suppressTextHandler = false;
                            searchDebounceTimer.stop();
                            listView.forceActiveFocus();
                            return;
                        }

                        window.ffmpegPath = newPath;
                        saveSettings();
                        filterWallpapersAnimation();
                        showStatus("Set ffmpeg path as: " + newPath);

                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        searchDebounceTimer.stop();
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd.startsWith(":rename") || cmd.startsWith(":rn")) {
                        let item = window.preCommandPath !== "" ? window.preCommandPath : (getCurrentFilteredItem() ? stripFileScheme(getCurrentFilteredItem().folder).replace(/\/$/, "") : "");
                        if (item !== "") {
                            let newName = rawCmd.replace(/^:(rename|rn)\s*/i, "").trim();
                            if (newName === "") {
                                delete window.renamedTitles[item];
                                window.renamedTitles = Object.assign({}, window.renamedTitles);
                            } else {
                                window.renamedTitles[item] = newName;
                                window.renamedTitles = Object.assign({}, window.renamedTitles);
                            }
                            for (let i = 0; i < masterModel.count; i++) {
                                let mItem = masterModel.get(i);
                                if (stripFileScheme(mItem.folder).replace(/\/$/, "") === item) {
                                    if (newName === "") {
                                        masterModel.setProperty(i, "title", mItem.originalTitle || item.split("/").pop());
                                    } else {
                                        masterModel.setProperty(i, "title", newName);
                                    }
                                    break;
                                }
                            }
                            saveSettings();
                            filterWallpapersAnimation();
                            showStatus(newName === "" ? "Name cleared" : "Renamed to: " + newName);
                        }
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd === ":playlistshuffle" || cmd === ":pls") {
                        window.playlistShuffle = !window.playlistShuffle;
                        saveSettings();
                        filterWallpapersAnimation();
                        showStatus(window.playlistShuffle ? "Playlist shuffle on" : "Playlist shuffle off");
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        listView.forceActiveFocus();
                        return;
                    }
                    if (cmd === ":playlist" || cmd === ":pl") {
                        window.showPlaylist = !window.showPlaylist;
                        saveSettings();
                        filterWallpapersAnimation();
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd === ":playlist clear" || cmd === ":playlist c" || cmd === ":pl clear" || cmd === ":pl c") {
                        window.playlist = [];
                        window.playlistActive = false;
                        window.showPlaylist = false;
                        saveSettings();
                        showStatus("Playlist cleared");
                        filterWallpapersAnimation();
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd.startsWith(":playlist ")) {
                        let mins = parseInt(rawCmd.replace(/^:playlist\s+/i, "").trim());
                        if (!isNaN(mins) && mins > 0) {
                            window.playlistInterval = mins;
                            saveSettings();
                            filterWallpapersAnimation();
                            showStatus("Playlist interval set to " + mins + " minutes");
                        }
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd.startsWith(":width ")) {
                        let width = parseInt(rawCmd.replace(/^:width\s+/i, "").trim());
                        if (!isNaN(width) && width > 0) {
                            width = Math.max(100, Math.min(1000, width));
                            window.cardWidth = width;
                            saveSettings();
                            filterWallpapersAnimation();
                            showStatus("Wallpaper cards width set to " + width + " px");
                        }
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd.startsWith(":height ")) {
                        let height = parseInt(rawCmd.replace(/^:height\s+/i, "").trim());
                        if (!isNaN(height) && height > 0) {
                            height = Math.max(100, Math.min(600, height));
                            window.cardHeight = height;
                            saveSettings();
                            filterWallpapersAnimation();
                            showStatus("Wallpaper cards height set to " + height + " px");
                        }
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd.startsWith(":scale ")) {
                        let scale = parseFloat(rawCmd.replace(/^:scale\s+/i, "").trim());
                        if (!isNaN(scale) && scale > 0) {
                            window.cardScale = scale;
                            saveSettings();
                            filterWallpapersAnimation();
                            showStatus("Wallpaper cards scale set to " + scale + "x");
                        }
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd.startsWith(":spacing ")) {
                        let spacing = parseInt(rawCmd.replace(/^:spacing\s+/i, "").trim());
                        if (!isNaN(spacing) && spacing > 0) {
                            window.cardSpacing = spacing;
                            saveSettings();
                            filterWallpapersAnimation();
                            showStatus("Wallpaper cards spacing set to " + spacing + "px");
                        }
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd === matureCmd) {
                        window.isMatureContentTriggered = true;
                        window.showMatureContent = !window.showMatureContent;
                        saveSettings();
                        filterWallpapersAnimation();
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        searchDebounceTimer.stop();
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd === ":static" || cmd === ":s") {
                        window.showStatic = !window.showStatic;
                        if (window.showStatic)
                            window.showDynamic = false;
                        saveSettings();
                        filterWallpapersAnimation();
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        searchDebounceTimer.stop();
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd === ":dynamic" || cmd === ":d") {
                        window.showDynamic = !window.showDynamic;
                        if (window.showDynamic)
                            window.showStatic = false;
                        saveSettings();
                        filterWallpapersAnimation();
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        searchDebounceTimer.stop();
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd === ":favorite" || cmd === ":f") {
                        window.showFavorite = !window.showFavorite;
                        saveSettings();
                        filterWallpapersAnimation();
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        searchDebounceTimer.stop();
                        listView.forceActiveFocus();
                        return;
                    }
                    if (cmd === ":clearcache" || cmd === ":cc") {
                        deleteFolder(window.thumbFolder);
                        window.validThumbs.clear();
                        window.thumbQueue = [];
                        reloadWallpapers();
                        showStatus("Cleared cache");
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd === ":reload" || cmd === ":rl") {
                        reloadWallpapers();
                        showStatus("Reloaded wallpapers");
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd === ":random" || cmd === ":r") {
                        let candidates = getFilteredCandidates().filter(item => !item.isStatic);
                        if (candidates.length > 0) {
                            let pick = candidates[Math.floor(Math.random() * candidates.length)];
                            applyWallpaper(pick);
                            window.pendingScrollPath = stripFileScheme(pick.folder).replace(/\/$/, "");
                            window.preCommandPath = window.pendingScrollPath;
                            window.wasInCommandMode = false;
                            window.suppressTextHandler = true;
                            searchInput.text = "";
                            window.suppressTextHandler = false;
                            filterWallpapersAnimation();
                            listView.forceActiveFocus();
                            showStatus("Applied random wallpaper");
                        }
                        return;
                    }

                    if (cmd === ":randomstatic" || cmd === ":rs") {
                        let candidates = getFilteredCandidates().filter(item => item.isStatic);
                        if (candidates.length > 0) {
                            let pick = candidates[Math.floor(Math.random() * candidates.length)];
                            applyWallpaper(pick);
                            window.pendingScrollPath = stripFileScheme(pick.folder).replace(/\/$/, "");
                            window.preCommandPath = window.pendingScrollPath;
                            window.wasInCommandMode = false;
                            window.suppressTextHandler = true;
                            searchInput.text = "";
                            window.suppressTextHandler = false;
                            filterWallpapersAnimation();
                            listView.forceActiveFocus();
                            showStatus("Applied random static wallpaper");
                        }
                        return;
                    }

                    if (cmd === ":randomfav" || cmd === ":rf") {
                        let candidates = getFilteredCandidates().filter(item => item.isFavorite);
                        if (candidates.length > 0) {
                            let pick = candidates[Math.floor(Math.random() * candidates.length)];
                            applyWallpaper(pick);
                            window.pendingScrollPath = stripFileScheme(pick.folder).replace(/\/$/, "");
                            window.preCommandPath = window.pendingScrollPath;
                            window.wasInCommandMode = false;
                            window.suppressTextHandler = true;
                            searchInput.text = "";
                            window.suppressTextHandler = false;
                            filterWallpapersAnimation();
                            listView.forceActiveFocus();
                            showStatus("Applied random favorite wallpaper");
                        }
                        return;
                    }

                    if (cmd.startsWith(":export") || cmd.startsWith(":ex")) {
                        let arg = rawCmd.replace(/^:(export|ex)\s*/i, "").trim().toLowerCase();

                        let exportItems = getFilteredCandidates().filter(item => {
                            if (item.isStatic)
                                return false;
                            if (arg === "")
                                return true;
                            let title = (item.title || "").toLowerCase();
                            let folderName = item.folder.split("/").pop().toLowerCase();
                            return title.indexOf(arg) !== -1 || folderName.indexOf(arg) !== -1;
                        });

                        let lines = exportItems.map(item => {
                            let id = stripFileScheme(item.folder).replace(/\/$/, "").split("/").pop().replace(/-1$/, "");
                            return "https://steamcommunity.com/sharedfiles/filedetails/?id=" + id;
                        }).join("\n");

                        let exportPath = stripFileScheme(Qt.resolvedUrl("exported-wallpapers.txt"));
                        writeProcess.command = [
                            "/bin/bash",
                            "-c",
                            "printf %s " + shQuote(lines) + " > " + shQuote(exportPath)
                        ];
                        writeProcess.startDetached();
                        showStatus("Exported " + exportItems.length + " wallpapers to export.txt");
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        filterWallpapersAnimation();
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd.startsWith(":setfolder ") || cmd.startsWith(":sf ")) {
                        let newPath = rawCmd.replace(/^:(setfolder|sf)\s+/i, "").trim();

                        if (newPath !== "") {
                            window.baseFolder = newPath;
                            saveSettings();
                            reloadWallpapers();
                            showStatus("Dynamic folder set as: " + newPath);
                        }

                        searchInput.text = "";
                        searchDebounceTimer.stop();
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd.startsWith(":setstatic ") || cmd.startsWith(":ss ")) {
                        let newPath = rawCmd.replace(/^:(setstatic|ss)\s+/i, "").trim();

                        if (newPath !== "") {
                            window.staticWallpaperFolder = newPath;
                            saveSettings();
                            reloadWallpapers();
                            showStatus("Static folder set as: " + newPath);
                        }

                        searchInput.text = "";
                        searchDebounceTimer.stop();
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd.startsWith(":setthumb ") || cmd.startsWith(":st ")) {
                        let newPath = rawCmd.replace(/^:(setthumb|st)\s+/i, "").trim();

                        if (newPath !== "" && newPath !== window.thumbFolder) {
                            let oldPath = window.thumbFolder;
                            window.thumbQueue = [];
                            window.thumbFolder = newPath;
                            saveSettings();
                            reloadWallpapers();
                            deleteFolder(oldPath);
                            showStatus("Thumbnail folder set as: " + newPath);
                        }

                        searchInput.text = "";
                        searchDebounceTimer.stop();
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd.startsWith(":sort ")) {
                        let mode = cmd.replace(":sort ", "").trim();

                        if (mode === "d")
                            mode = "default";
                        else if (mode === "n")
                            mode = "name";
                        else if (mode === "r")
                            mode = "recent";
                        else if (mode === "f")
                            mode = "favorite";

                        if (["default", "name", "recent", "favorite", "random"].includes(mode)) {
                            if (window.sortMode === mode) {
                                window.sortDescending = !window.sortDescending;
                            } else {
                                window.sortMode = mode;
                                window.sortDescending = false;
                            }
                            saveSettings();
                            filterWallpapersAnimation();
                        }

                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        searchDebounceTimer.stop();
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd === ":open" || cmd === ":o") {
                        let path = window.preCommandPath !== "" ? window.preCommandPath.replace(/\/$/, "").split("/").pop() : window.lastWallpaperPath.replace(/\/$/, "").split("/").pop();
                        let id = path.replace(/\/$/, "").split("/").pop().replace(/-1$/, "");
                        if (id && /^\d+$/.test(id)) {
                            workshopidProcess.command = ["/bin/bash", "-c", `xdg-open "steam://url/CommunityFilePage/${id}"`];
                            workshopidProcess.startDetached();
                        }
                        filterWallpapersAnimation();
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd === ":id") {
                        let path = window.preCommandPath !== "" ? window.preCommandPath : window.lastWallpaperPath;
                        if (path !== "") {
                            let id = path.replace(/\/$/, "").split("/").pop();
                            workshopidProcess.command = ["/bin/bash", "-c", `printf '%s' "${id}" | wl-copy`];
                            workshopidProcess.startDetached();
                        }
                        filterWallpapersAnimation();
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd === ":gif") {
                        window.enableGifPreview = !window.enableGifPreview;
                        saveSettings();
                        filterWallpapersAnimation();
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd.startsWith(":tag ")) {
                        let tag = rawCmd.replace(/^:tag\s+/i, "").trim().toLowerCase();
                        window.filterTag = window.filterTag === tag ? "" : tag;
                        saveSettings();
                        filterWallpapersAnimation();
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        searchDebounceTimer.stop();
                        listView.forceActiveFocus();
                        return;
                    }

                    if (cmd === ":tag") {
                        window.filterTag = "";
                        saveSettings();
                        filterWallpapersAnimation();
                        window.suppressTextHandler = true;
                        searchInput.text = "";
                        window.suppressTextHandler = false;
                        searchDebounceTimer.stop();
                        listView.forceActiveFocus();
                        return;
                    }
                    applyWallpaper(getCurrentFilteredItem());
                }
            }

           function deleteFolder(path) {
                let cleanPath = stripFileScheme(path).replace(/\/$/, "");
                let allowed = stripFileScheme(window.thumbFolder).replace(/\/$/, "");

                if (cleanPath !== allowed) {
                    console.log("Refusing to delete non-thumb folder:", cleanPath);
                    return;
                }

                deleteFolderProcess.command = ["/bin/bash", "-c", "rm -rf -- " + shQuote(cleanPath)];
                deleteFolderProcess.startDetached();
            }

            Process {
                id: staticFinder
                onExited: {
                    staticWallpaperFile.reload();
                }
            }

            FileView {
                id: staticWallpaperFile
                path: "file:///tmp/wallpapers.json"
                onLoaded: {
                    var content = text().trim();
                    if (content.length > 0) {
                        try {
                            var files = JSON.parse(content);
                            console.log("Found static files:", files.length);
                            for (var i = 0; i < files.length; i++) {
                                var filePath = files[i];
                                if (!filePath) continue;
                                
                                queueThumbnail(filePath);
                                var displayTitle = window.renamedTitles[filePath] || filePath.split("/").pop();
                                masterModel.append({
                                    folder: "file://" + filePath,
                                    title: displayTitle,
                                    originalTitle: filePath.split("/").pop(),
                                    isStatic: true,
                                    isFavorite: window.favorites.includes(filePath),
                                    tags: "[]"
                                });
                            }
                        } catch (e) {
                            console.log("Error parsing wallpaper JSON:", e);
                        }
                    }
                    Qt.callLater(() => {
                        cleanupThumbnails(window.validThumbs);
                    });
                    filterWallpapers();
                    
                    Qt.callLater(() => {
                        initialFadeIn.start();
                        window.isInitialLoad = false;
                    });
                }
            }

            function scanWallpapers() {
                masterModel.clear();
                console.log("Scanning dynamic wallpapers:", baseFolder);

                var folders = Qt.createQmlObject('import Qt.labs.folderlistmodel; FolderListModel {}', window);
                folders.folder = "file://" + baseFolder;
                folders.showDirs = true;
                folders.showFiles = false;

                folders.onStatusChanged.connect(function () {
                    if (folders.status !== FolderListModel.Ready)
                        return;

                    for (let i = 0; i < folders.count; i++) {
                        let folderPath = folders.get(i, "filePath");
                        let cleanPath = stripFileScheme(folderPath);

                        masterModel.append({
                            folder: folderPath,
                            title: "Error! Fix project file.",
                            originalTitle: "",
                            preview: "",
                            isStatic: false,
                            isFavorite: window.favorites.includes(cleanPath),
                            tags: "[]",
                            hash: Qt.md5(cleanPath)
                        });

                        let index = masterModel.count - 1;

                        getWallpaperInfo(folderPath, function (data) {
                            let cleanPath = stripFileScheme(folderPath);
                            let displayTitle = window.renamedTitles[cleanPath] || data.title;
                            masterModel.setProperty(index, "title", displayTitle);
                            masterModel.setProperty(index, "originalTitle", data.title);
                            masterModel.setProperty(index, "preview", data.preview);
                            masterModel.setProperty(index, "contentrating", data.contentrating || "Everyone");
                            masterModel.setProperty(index, "tags", JSON.stringify(data.tags || []));

                            if (data.preview && data.preview !== "") {
                                let fullPath = stripFileScheme(folderPath) + "/" + data.preview;
                                queueThumbnail(fullPath);
                            }
                        });
                    }
                    filterWallpapers();
                });

                console.log("Scanning static wallpapers:", staticWallpaperFolder);
                staticFinder.command = ["/home/rhythmcreative/.local/bin/list-wallpapers-json.sh", staticWallpaperFolder];
                staticFinder.running = true;
            }
            Component.onCompleted: {
                let path = Qt.resolvedUrl("settings.json").toString().replace(/^file:\/\//, "");
                let dir = path.replace(/\/[^\/]*$/, "");
                window.settingsPath = path;
                initSettingsProcess.command = ["/bin/bash", "-c", `mkdir -p "${dir}" && [ -f "${path}" ] || echo '{}' > "${path}"`];
                initSettingsProcess.startDetached();
                Qt.callLater(() => {
                    loadSettings(function () {
                        scanWallpapers();
                    });
                });
            }

            function filterWallpapersAnimation() {
                if (window.isInitialLoad) {
                    filterWallpapers();
                    return;
                }

                if (filterAnimation.running) {
                    filterAnimation.stop();
                }

                filterAnimation.start();
            }

            function filterWallpapers() {
                
                window.anyHovered = false
                window.hoveredIndex = -1
                window.previousHoveredIndex = -1
                window.previousCurrentIndex = -1
                listView.lastCurrentIndex = -1
                if (window.keyboardNavigation)
                window.keyboardNavigation = true

                var rawFilter = searchInput.text.trim();
                let wasInCommandMode = window.wasInCommandMode;
                let enteringCommand = rawFilter.startsWith(":");
                let leavingCommand = !enteringCommand && wasInCommandMode;

                if (enteringCommand && !window.wasInCommandMode) {
                    let item = getCurrentFilteredItem();
                    if (item) {
                        window.preCommandIndex = listView.currentIndex;
                        window.preCommandPath = stripFileScheme(item.folder).replace(/\/$/, "");
                    }
                }
                if (enteringCommand) {
                    filteredModel.clear();

                    window.dynamicIndexes = [];
                    window.staticIndexes = [];

                    Qt.callLater(() => listView.currentIndex = -1);

                    window.wasInCommandMode = true;
                    return;
                }
                var filter = rawFilter.toLowerCase();
                var previousItem = getCurrentFilteredItem();
                var previousFolder = previousItem ? stripFileScheme(previousItem.folder).replace(/\/$/, "") : "";

                var newIndex = -1;
                let items = [];

                for (var i = 0; i < masterModel.count; i++) {
                    var item = masterModel.get(i);
                    var title = (item.title || "").toLowerCase();
                    var folderName = item.folder.split("/").pop().toLowerCase();

                    var matchesText = filter === "" || title.indexOf(filter) !== -1 || folderName.indexOf(filter) !== -1;

                    var allowedContent = window.showMatureContent || (item.contentrating !== "Mature" && item.contentrating !== "Questionable");
                    var matchesFavorite = !window.showFavorite || item.isFavorite;
                    var matchesStatic = !window.showStatic || item.isStatic;
                    var matchesDynamic = !window.showDynamic || !item.isStatic;
                    var itemTags = [];
                    try {
                        itemTags = JSON.parse(item.tags || "[]");
                    } catch (e) {}
                    var matchesTag = window.filterTag === "" || (item.tags && item.tags.indexOf(window.filterTag.toLowerCase()) !== -1);
                    var matchesPlaylist = !window.showPlaylist || window.playlist.indexOf(stripFileScheme(item.folder).replace(/\/$/, "")) !== -1;
                    if (matchesText && allowedContent && matchesFavorite && matchesStatic && matchesDynamic && matchesTag && matchesPlaylist) {
                        items.push({
                            folder: item.folder,
                            title: item.title,
                            preview: item.preview,
                            isStatic: item.isStatic,
                            isFavorite: item.isFavorite,
                            contentrating: item.contentrating,
                            tags: item.tags || "[]"
                        });
                    }
                }

                if (window.showPlaylist) {
                    items.sort((a, b) => {
                        let aIdx = window.playlist.indexOf(stripFileScheme(a.folder).replace(/\/$/, ""));
                        let bIdx = window.playlist.indexOf(stripFileScheme(b.folder).replace(/\/$/, ""));
                        return aIdx - bIdx;
                    });
                } else if (window.sortMode === "default") {
                    let dynamicItems = [];
                    let staticItems = [];

                    for (let item of items) {
                        if (item.isStatic)
                            staticItems.push(item);
                        else
                            dynamicItems.push(item);
                    }

                    dynamicItems.sort((a, b) => {
                        let aName = a.folder.split("/").pop();
                        let bName = b.folder.split("/").pop();

                        let aId = parseInt(aName);
                        let bId = parseInt(bName);

                        if (isNaN(aId) || isNaN(bId))
                            return aName.localeCompare(bName);

                        return aId - bId;
                    });

                    staticItems.sort((a, b) => {
                        let aName = a.folder.split("/").pop();
                        let bName = b.folder.split("/").pop();
                        return aName.localeCompare(bName);
                    });

                    items = dynamicItems.concat(staticItems);
                    if (window.sortDescending)
                        items.reverse();
                } else if (window.sortMode === "name") {
                    items.sort((a, b) => (a.title || "").localeCompare(b.title || ""));
                    if (window.sortDescending)
                        items.reverse();
                } else if (window.sortMode === "recent") {
                    items.sort((a, b) => {
                        let ta = window.usageMap[stripFileScheme(a.folder).replace(/\/$/, "")] || 0;
                        let tb = window.usageMap[stripFileScheme(b.folder).replace(/\/$/, "")] || 0;
                        return tb - ta;
                    });
                    if (window.sortDescending)
                        items.reverse();
                } else if (window.sortMode === "favorite") {
                    items.sort((a, b) => {
                        if (a.isFavorite === b.isFavorite)
                            return 0;
                        return b.isFavorite ? 1 : -1;
                    });
                    if (window.sortDescending)
                        items.reverse();
                } else if (window.sortMode === "random") {
                    for (let i = items.length - 1; i > 0; i--) {
                        let j = Math.floor(Math.random() * (i + 1));
                        let tmp = items[i];
                        items[i] = items[j];
                        items[j] = tmp;
                    }
                    if (window.sortDescending)
                        items.reverse();
                }

                for (let i = filteredModel.count - 1; i >= 0; i--) {
                    let found = false;
                    for (let j = 0; j < items.length; j++) {
                        if (items[j].folder === filteredModel.get(i).folder) {
                            found = true;
                            break;
                        }
                    }
                    if (!found)
                        filteredModel.remove(i);
                }

                for (let i = 0; i < items.length; i++) {
                    let currentPos = -1;
                    for (let j = 0; j < filteredModel.count; j++) {
                        if (filteredModel.get(j).folder === items[i].folder) {
                            currentPos = j;
                            break;
                        }
                    }
                    if (currentPos === -1) {
                        filteredModel.insert(i, items[i]);
                    } else if (currentPos !== i) {
                        filteredModel.move(currentPos, i, 1);
                    }
                }

                if (previousFolder !== "") {
                    for (let i = 0; i < filteredModel.count; i++) {
                        let modelPath = stripFileScheme(filteredModel.get(i).folder).replace(/\/$/, "");
                        if (modelPath === previousFolder) {
                            newIndex = i;
                            break;
                        }
                    }
                }

                if (leavingCommand && !window.isMatureContentTriggered && window.preCommandPath !== "") {
                    let target = window.preCommandPath;

                    for (let i = 0; i < filteredModel.count; i++) {
                        let modelPath = stripFileScheme(filteredModel.get(i).folder).replace(/\/$/, "");

                        if (modelPath === target) {
                            newIndex = i;
                            break;
                        }
                    }
                }

                if (window.pendingScrollPath !== "") {
                    let target = window.pendingScrollPath;
                    for (let i = 0; i < filteredModel.count; i++) {
                        let modelPath = stripFileScheme(filteredModel.get(i).folder).replace(/\/$/, "");
                        if (modelPath === target) {
                            newIndex = i;
                            break;
                        }
                    }
                }

                window.dynamicIndexes = [];
                window.staticIndexes = [];
                for (let i = 0; i < filteredModel.count; i++) {
                    let item = filteredModel.get(i);
                    if (item.isStatic)
                        window.staticIndexes.push(i);
                    else
                        window.dynamicIndexes.push(i);
                }

                if ((window.isInitialLoad || window.isMatureContentTriggered) && window.lastWallpaperPath) {
                    for (let i = 0; i < filteredModel.count; i++) {
                        let modelPath = stripFileScheme(filteredModel.get(i).folder);
                        if (modelPath === window.lastWallpaperPath) {
                            newIndex = i;
                            break;
                        }
                    }
                    window.isMatureContentTriggered = false;
                }

                if (newIndex === -1 && filteredModel.count > 0)
                    newIndex = 0;

                if (newIndex !== -1) {
                    window.targetIndexTracker = newIndex;
                    Qt.callLater(() => {
                        if (listView.count === 0)
                            return;
                        listView.currentIndex = newIndex;

                        Qt.callLater(() => {
                            listView.positionViewAtIndex(newIndex, ListView.Center);
                        });
                    });
                }
                window.wasInCommandMode = enteringCommand;
            }

            ListModel {
                id: filteredModel
            }

            Rectangle {
                id: panel

                property real widthScale: screen.width / 1920
                property real heightScale: screen.height / 1200

                property real panelWidthMultiplier: 8.25 * widthScale
                property real panelHeightMultiplier: 1.3889 * heightScale
                property real panelMinWidth: 825 * widthScale
                property real panelMinHeight: 200 * heightScale
                property real panelMaxWidth: 1650 * widthScale
                property real panelMaxHeight: 800 * heightScale

                width: Math.max(
                    panelMinWidth,
                    Math.min(panelMaxWidth, cardWidth * panelWidthMultiplier)
                )

                height: Math.max(
                    panelMinHeight,
                    Math.min(panelMaxHeight, cardHeight * panelHeightMultiplier)
                )

                Behavior on width {
                        enabled: !isInitialLoad
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
                        }
                    }
                Behavior on height {
                        enabled: !isInitialLoad
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
                        }
                    }

                radius: 20
                color: Theme.background
                border.color: Theme.border
                anchors.centerIn: parent
                clip: true

                FocusScope {
                    id: keyScope
                    anchors.fill: parent
                    focus: true
                    Component.onCompleted: listView.forceActiveFocus()

                    Keys.onPressed: event => {
                        if (event.matches(StandardKey.Paste)) {
                            searchInput.visible = true;
                            Qt.callLater(() => {
                                searchInput.forceActiveFocus();
                                searchInput.paste();
                            });

                            event.accepted = true;
                            return;
                        }

                        if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
                            let item = getCurrentFilteredItem();
                            if (!item)
                                return;
                            let path = stripFileScheme(item.folder);

                            for (let i = 0; i < masterModel.count; i++) {
                                let mItem = masterModel.get(i);
                                if (stripFileScheme(mItem.folder) === path) {
                                    mItem.isFavorite = !mItem.isFavorite;

                                    if (mItem.isFavorite) {
                                        if (!window.favorites.includes(path))
                                            window.favorites.push(path);
                                    } else {
                                        let idx = window.favorites.indexOf(path);
                                        if (idx !== -1)
                                            window.favorites.splice(idx, 1);
                                    }

                                    saveSettings();
                                    break;
                                }
                            }

                            item.isFavorite = !item.isFavorite;
                            event.accepted = true;
                            return;
                        }

                        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) {
                            if (!(event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier))) {
                                return;
                            }
                        }
                        if (!searchInput.activeFocus && !window.showHelp && event.key !== Qt.Key_Backspace && event.key !== Qt.Key_Escape && event.key !== Qt.Key_Tab && event.text.length > 0) {
                            searchInput.visible = true;
                            searchInput.forceActiveFocus();
                            searchInput.text = event.text;
                            searchInput.cursorPosition = 1;
                            event.accepted = true;
                        }
                    }

                    TextField {
                        id: searchInput
                        width: 300
                        height: 35
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter

                        visible: true
                        opacity: (text.length > 0 || activeFocus) ? 1 : 0

                        focus: false
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.background
                        z: 1

                        Timer {
                            id: searchDebounceTimer
                            interval: 250
                            repeat: false
                            onTriggered: {
                                filterWallpapersAnimation();
                                if (searchInput.text.length === 0) {
                                    listView.forceActiveFocus();
                                }
                            }
                        }

                        background: Rectangle {
                            radius: 15
                            color: Theme.background
                            border.width: 1
                            border.color: Theme.border
                        }

                        Keys.forwardTo: [listView]

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.5, 0.5, 0.75, 1.0, 1, 1]
                            }
                        }

                        onTextChanged: {
                            if (window.suppressTextHandler)
                                return;
                            let isCommand = text.trim().startsWith(":");
                            let wasCommand = window.wasInCommandMode;
                            updateSuggestions(text);
                            if (isCommand && !wasCommand) {
                                searchDebounceTimer.stop();
                                filterWallpapersAnimation();
                            } else if (!isCommand) {
                                searchDebounceTimer.restart();
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: false
                        enabled: window.suggestions.length > 0
                        z: 19
                        propagateComposedEvents: true
                        onClicked: {
                            window.suggestions = [];
                            window.suggestionIndex = -1;
                        }
                    }

                    Rectangle {
                        id: autocompleteDropdown
                        visible: window.suggestions.length > 0 && searchInput.activeFocus
                        anchors.top: searchInput.bottom
                        anchors.topMargin: 6
                        anchors.horizontalCenter: searchInput.horizontalCenter
                        width: 300
                        height: Math.min(window.suggestions.length, 6) * 32
                        radius: 15
                        color: Theme.background
                        border.color: Theme.border
                        border.width: 1
                        z: 20
                        clip: true

                        ListView {
                            id: suggestionList
                            anchors.fill: parent
                            model: window.suggestions
                            boundsBehavior: Flickable.StopAtBounds
                            currentIndex: window.suggestionIndex
                            property string hoverItem: ""
                            property bool hoverLocked: false
                            clip: true

                            onCurrentIndexChanged: {
                                if (currentIndex >= 0) {
                                    positionViewAtIndex(currentIndex, ListView.Contain);
                                }
                            }

                            onModelChanged: {
                                suggestionList.hoverItem = "";
                                suggestionList.hoverLocked = false;
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                propagateComposedEvents: true
                                onWheel: wheel => {
                                    suggestionList.hoverItem = "";
                                    suggestionList.hoverLocked = true;

                                    let newIndex = window.suggestionIndex;

                                    if (newIndex < 0)
                                        newIndex = 0;

                                    if (wheel.angleDelta.y > 0)
                                        newIndex--;
                                    else
                                        newIndex++;

                                    newIndex = Math.max(0, Math.min(window.suggestions.length - 1, newIndex));

                                    window.suggestionIndex = newIndex;
                                }
                            }

                            delegate: Rectangle {
                                id: suggestionDelegate
                                width: autocompleteDropdown.width
                                height: 32
                                radius: 15
                                color: (suggestionList.hoverItem !== "") ? (modelData === suggestionList.hoverItem ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.1) : "transparent") : (index === suggestionList.currentIndex ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.1) : "transparent")

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 200
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    text: {
                                        let s = modelData.endsWith("/") ? modelData.slice(0, -1) : modelData;
                                        return s.split("/").pop() + (modelData.endsWith("/") ? "/" : "");
                                    }
                                    color: Theme.text
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    width: parent.width - 24
                                    opacity: (suggestionList.hoverItem !== "") ? (modelData === suggestionList.hoverItem ? 1 : 0.7) : (index === window.suggestionIndex ? 1 : 0.7)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onPositionChanged: {
                                        suggestionList.hoverLocked = false;
                                    }

                                    onEntered: {
                                        if (!suggestionList.hoverLocked) {
                                            suggestionList.hoverItem = modelData;
                                            window.suggestionIndex = index;
                                        }
                                    }

                                    onExited: {
                                        if (suggestionList.hoverItem === modelData) {
                                            suggestionList.hoverItem = "";
                                        }
                                    }

                                    onClicked: acceptSuggestion(modelData)
                                }
                            }
                        }
                    }

                    Text {
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 1000
                        height: 35
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 13
                        color: Theme.text
                        opacity: (searchInput.text.length > 0 || searchInput.activeFocus) ? 0 : 0.5
                        elide: Text.ElideRight
                        z: 1

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
                            }
                        }

                        text: {
                            if (window.statusMessage !== "")
                                return window.statusMessage;
                            let parts = [];
                            if (window.showFavorite)
                                parts.push(" Favorites");
                            if (window.showStatic)
                                parts.push(" Static");
                            if (window.showDynamic)
                                parts.push(" Dynamic");
                            if (window.showMatureContent && !showStatic)
                                parts.push(" NSFW");
                            if (window.playlistActive) {
                                parts.push("󰐑 Playlist " + (window.showPlaylist ? "only " : "") + window.playlist.length + (window.playlistShuffle ? " " : ""));
                            } else if (window.playlist.length > 0) {
                                parts.push(" Playlist " + (window.showPlaylist ? "only " : "") + window.playlist.length + (window.playlistShuffle ? " " : ""));
                            } else if (window.showPlaylist) {
                                parts.push(" Playlist only");
                            }
                            if (window.sortMode !== "default" && window.sortMode !== "random")
                                parts.push("Sort: " + window.sortMode + (window.sortDescending ? " ↓" : " ↑"));
                            if (window.sortMode == "random")
                                parts.push("Sort: " + window.sortMode);
                            if (window.filterTag !== "")
                                parts.push("⌗ " + window.filterTag);
                            if (!window.enableGifPreview)
                                parts.push(" No gif");
                            return parts.length > 0 ? parts.join("  |  ") : " ";
                        }
                    }

                    Rectangle {
                        id: clipContainer
                        anchors.fill: parent
                        anchors.margins: 45
                        anchors.topMargin: 0
                        anchors.bottomMargin: 0
                        color: "transparent"
                        clip: true
                        z: 0

                        ListView {
                            id: listView
                            opacity: 0
                            anchors.fill: parent
                            anchors.topMargin: 90
                            anchors.bottomMargin: 90
                            orientation: ListView.Horizontal
                            spacing: cardSpacing
                            model: filteredModel
                            cacheBuffer: 300
                            highlightMoveDuration: 300
                            boundsBehavior: Flickable.StopAtBounds
                            highlightFollowsCurrentItem: true
                            highlight: Item {}
                            preferredHighlightBegin: (width / 2) - (window.cardWidth / 2)
                            preferredHighlightEnd: (width / 2) - (window.cardWidth / 2)
                            highlightRangeMode: ListView.StrictlyEnforceRange

                            NumberAnimation {
                                id: initialFadeIn
                                target: listView
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: 240
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.5, 0.5, 0.75, 1.0, 1, 1]
                            }

                            property int lastCurrentIndex: -1

                            onCurrentIndexChanged: {
                                if (window.keyboardNavigation) {
                                    window.previousCurrentIndex = lastCurrentIndex
                                    lastCurrentIndex = currentIndex
                                }
                            }

                            delegate: Item {
                                id: delegateRoot
                                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                anchors.verticalCenterOffset: 20
                                property real baseWidth: window.cardWidth
                                property real baseHeight: window.cardHeight
                                property real activeScale: window.cardScale
                                property real sideOffset: (baseWidth * activeScale - baseWidth) / 2
                                property int activeIndex: window.keyboardNavigation ? listView.currentIndex : window.hoveredIndex
                                property bool hoverMode: !window.keyboardNavigation && window.hoveredIndex !== -1
                                property bool hoverActive: hoverMode && index === window.hoveredIndex
                                property bool active: window.keyboardNavigation ? index === activeIndex : hoverActive

                              
                                width: baseWidth
                                height: baseHeight

                                property real itemOffset: {
                                    if (activeIndex === -1)
                                        return 0

                                    if (index < activeIndex)
                                        return -sideOffset
                                    if (index > activeIndex)
                                        return sideOffset
                                    return 0
                                }

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 600
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
                                    }
                                }

                                property bool isVisibleOnScreen: delegateRoot.ListView.view ? (x + width > ListView.view.contentX && x < ListView.view.contentX + ListView.view.width) : false

                                property int playlistPosition: {
                                    let path = folder ? stripFileScheme(folder).replace(/\/$/, "") : "";
                                    return window.playlist.indexOf(path);
                                }
                                property bool inPlaylist: playlistPosition !== -1
                                property int lastValidPosition: 0

                                onPlaylistPositionChanged: {
                                    if (playlistPosition !== -1)
                                        lastValidPosition = playlistPosition;
                                }

                        
                                Item {
                                    id: scaleContainer
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: baseWidth
                                    height: baseHeight
                                    scale: active ? activeScale : 1
                                    transformOrigin: Item.Center
                                    x: itemOffset

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 600
                                            easing.type: Easing.BezierSpline
                                            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
                                        }
                                    }

                                    Behavior on x {
                                        NumberAnimation {
                                            duration: 600
                                            easing.type: Easing.BezierSpline
                                            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
                                        }
                                    }
                                

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Theme.background
                                        radius: 15
                                        antialiasing: true

                                        Item {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            layer.enabled: isVisibleOnScreen
                                            layer.effect: MultiEffect {
                                                maskEnabled: true
                                                maskSource: ShaderEffectSource {
                                                    sourceItem: Rectangle {
                                                        width: scaleContainer.width
                                                        height: scaleContainer.height
                                                        radius: 15
                                                        color: "black"
                                                        antialiasing: true
                                                    }
                                                }
                                            }

                                            Loader {
                                                id: previewLoader
                                                anchors.fill: parent

                                                property string normalizedPath: folder ? folder.replace(/\/$/, "") : ""
                                                property bool isGif: window.enableGifPreview && preview && preview.toLowerCase().endsWith(".gif")

                                                sourceComponent: isGif ? animatedPreview : staticPreview

                                                Component {
                                                    id: staticPreview
                                                    Image {
                                                        id: staticImg
                                                        anchors.fill: parent
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                        smooth: true
                                                        cache: true
                                                        sourceSize.width: scaleContainer.width
                                                        sourceSize.height: scaleContainer.height
                                                        source: {
                                                            if (!previewLoader.normalizedPath)
                                                                return "";
                                                            let fullPath;
                                                            if (preview && preview !== "")
                                                                fullPath = previewLoader.normalizedPath + "/" + preview;
                                                            else if (isStatic)
                                                                fullPath = previewLoader.normalizedPath;
                                                            else
                                                                return "";
                                                            let hash = Qt.md5(fullPath);
                                                            return "file://" + window.thumbFolder + "/" + hash + ".jpg";
                                                        }

                                                        onStatusChanged: {
                                                            if (status === Image.Ready)
                                                                fadeIn.start();
                                                        }
                                                        NumberAnimation {
                                                            id: fadeIn
                                                            target: staticImg
                                                            property: "opacity"
                                                            from: 0
                                                            to: 1
                                                            duration: 200
                                                            easing.type: Easing.BezierSpline
                                                            easing.bezierCurve: [0.5, 0.5, 0.75, 1.0, 1, 1]
                                                        }
                                                    }
                                                }

                                                Component {
                                                    id: animatedPreview
                                                    AnimatedImage {
                                                        id: animImg
                                                        anchors.fill: parent
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                        smooth: true
                                                        cache: true
                                                        playing: isVisibleOnScreen
                                                        source: previewLoader.normalizedPath !== "" ? "file://" + previewLoader.normalizedPath + "/" + preview : ""

                                                        onStatusChanged: {
                                                            if (status === AnimatedImage.Ready)
                                                                fadeIn.start();
                                                        }
                                                        NumberAnimation {
                                                            id: fadeIn
                                                            target: animImg
                                                            property: "opacity"
                                                            from: 0
                                                            to: 1
                                                            duration: 200
                                                            easing.type: Easing.BezierSpline
                                                            easing.bezierCurve: [0.5, 0.5, 0.75, 1.0, 1, 1]
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: active ? 33 : 0
                                            color: Theme.background
                                            radius: 15
                                            opacity: active ? 1 : 0
                                            visible: true

                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 300
                                                    easing.type: Easing.BezierSpline
                                                    easing.bezierCurve: [0.5, 0.5, 0.75, 1.0, 1, 1]
                                                }
                                            }

                                            Behavior on height {
                                                NumberAnimation {
                                                    duration: 300
                                                    easing.type: Easing.BezierSpline
                                                    easing.bezierCurve: [0.5, 0.5, 0.75, 1.0, 1, 1]
                                                }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: title
                                                color: Theme.text
                                                width: parent.width - 20
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                                font.pixelSize: 13
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"
                                            border.width: 1
                                            border.color: Theme.background
                                            radius: 15
                                            antialiasing: true
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"
                                            border.width: 2
                                            border.color: Theme.border
                                            radius: 15
                                            antialiasing: true
                                            opacity: active ? 1 : 0
                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 300
                                                    easing.type: Easing.BezierSpline
                                                    easing.bezierCurve: [0.5, 0.5, 0.75, 1.0, 1, 1]
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        opacity: delegateRoot.inPlaylist ? 1 : 0
                                        anchors.centerIn: parent
                                        anchors.topMargin: 10
                                        anchors.leftMargin: 10
                                        width: baseWidth
                                        height: baseHeight
                                        radius: 15
                                        color: Theme.background
                                        border.width: active ? 2 : 1
                                        border.color: active ? Theme.border : Theme.background
                                        Behavior on border.color {
                                            ColorAnimation {
                                                duration: 300
                                            }
                                        }
                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 300
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: [0.5, 0.5, 0.75, 1.0, 1, 1]
                                            }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: String(delegateRoot.lastValidPosition + 1)
                                            color: Theme.border
                                            font.pixelSize: 100
                                            font.weight: Font.Medium
                                        }
                                    }
                                }


                                    Item {
                                        id: favContainer
                                        width: 30
                                        height: 30
                                        scale: active ? cardScale : 1.0
                                        property int offsetX: active ? cardScale * 15 : 15
                                        property int offsetY: active ? cardScale * 10 : 10
                                        x: scaleContainer.x + baseWidth * (1 + scaleContainer.scale) / 2 - width - offsetX
                                        y: baseHeight * (1 - scaleContainer.scale) / 2 + offsetY
                                        property bool mouseOverFav: false
                                        z: 20

                                        Behavior on scale {
                                            NumberAnimation {
                                            duration: 300
                                            easing.type: Easing.BezierSpline
                                            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
                                            }
                                        }

                                        Behavior on offsetX {
                                            NumberAnimation {
                                            duration: 300
                                            easing.type: Easing.BezierSpline
                                            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
                                            }
                                        }

                                        Behavior on offsetY {
                                            NumberAnimation {
                                            duration: 300
                                            easing.type: Easing.BezierSpline
                                            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: favContainer.mouseOverFav = true
                                            onExited: favContainer.mouseOverFav = false
                                            onClicked: {
                                                let path = window.stripFileScheme(model.folder);

                                                for (let i = 0; i < masterModel.count; i++) {
                                                    let mItem = masterModel.get(i);
                                                    if (window.stripFileScheme(mItem.folder) === path) {
                                                        mItem.isFavorite = !mItem.isFavorite;

                                                        if (mItem.isFavorite) {
                                                            if (!window.favorites.includes(path))
                                                                window.favorites.push(path);
                                                        } else {
                                                            let idx = window.favorites.indexOf(path);
                                                            if (idx !== -1)
                                                                window.favorites.splice(idx, 1);
                                                        }

                                                        window.saveSettings();
                                                        break;
                                                    }
                                                }
                                                model.isFavorite = !model.isFavorite;
                                            }
                                        }

                                        Text {
                                            text: ""
                                            color: Theme.border
                                            font.pixelSize: 28
                                            anchors.fill: parent
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            opacity: model.isFavorite ? 1 : 0
                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 300
                                                    easing.type: Easing.BezierSpline
                                                    easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
                                                }
                                            }
                                        }

                                        Text {
                                            text: "♥"
                                            color: Theme.border
                                            font.pixelSize: 28
                                            anchors.fill: parent
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            opacity: (!model.isFavorite && (model.isFavorite || favContainer.mouseOverFav)) ? 1 : 0
                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 500
                                                    easing.type: Easing.BezierSpline
                                                    easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
                                                }
                                            }
                                        }
                                    }

                                MouseArea {
                                    id: scaleMouseArea
                                    anchors.centerIn: delegateRoot
                                    width: active ? cardScale * baseWidth : baseWidth
                                    height: active ? cardScale * baseHeight : baseHeight
                                    hoverEnabled: true
                                    propagateComposedEvents: true
                                    acceptedButtons: Qt.LeftButton
                                    z: 1
                                    onEntered: {
                                        window.anyHovered = true
                                        window.setHoveredIndex(index)
                                    }

                                    onExited: {
                                        window.anyHovered = false
                                        if (!favContainer.mouseOverFav)
                                            Qt.callLater(() => window.clearHoveredIndex(index))
                                    }
                                    onDoubleClicked: {
                                        if (!(mouse.modifiers & Qt.ShiftModifier)) {
                                            applyWallpaper(model);
                                        }
                                    }
                                    onClicked: mouse => {
                                        if (mouse.modifiers & Qt.ShiftModifier) {
                                            let path = stripFileScheme(model.folder).replace(/\/$/, "");
                                            let idx = window.playlist.indexOf(path);
                                            if (idx === -1) {
                                                window.playlist = [...window.playlist, path];
                                                if (showPlaylist) {
                                                    filterWallpapersAnimation();
                                                }
                                            } else {
                                                window.playlist = window.playlist.filter((_, i) => i !== idx);
                                                if (showPlaylist) {
                                                    filterWallpapersAnimation();
                                                }
                                            }
                                            if (window.playlist.length === 0) {
                                                window.playlistActive = false;
                                            }
                                            saveSettings();
                                        }
                                    }

                                    onWheel: function (wheel) {
                                        window.keyboardNavigation = false;
                                        if (wheel.angleDelta.y > 0)
                                            listView.currentIndex = Math.max(0, listView.currentIndex - 1);
                                        else
                                            listView.currentIndex = Math.min(listView.count - 1, listView.currentIndex + 1);
                                    }
                                }
                            }

                            Keys.onTabPressed: event => {
                                if (window.suggestions.length > 0) {
                                    let selectedItem = "";

                                    if (suggestionList.hoverItem !== "") {
                                        selectedItem = suggestionList.hoverItem;
                                    } else if (window.suggestionIndex >= 0) {
                                        selectedItem = window.suggestions[window.suggestionIndex];
                                    }

                                    if (selectedItem !== "") {
                                        acceptSuggestion(selectedItem);
                                    }

                                    event.accepted = true;
                                }
                            }
                            Keys.onEscapePressed: event => {
                                if (window.showHelp) {
                                    window.showHelp = false;
                                    window.suggestions = [];
                                    window.suggestionIndex = -1;
                                    listView.forceActiveFocus();
                                    event.accepted = true;
                                    return;
                                }
                                if (window.suggestions.length > 0) {
                                    window.suggestions = [];
                                    window.suggestionIndex = -1;
                                    event.accepted = true;
                                    return;
                                }
                                Qt.quit();
                            }

                            Keys.onUpPressed: event => {
                                if (window.suggestions.length > 0) {
                                    suggestionList.hoverItem = "";
                                    suggestionList.hoverLocked = true;

                                    let newIndex = window.suggestionIndex;
                                    if (newIndex < 0)
                                        newIndex = 0;

                                    window.suggestionIndex = Math.max(0, newIndex - 1);
                                    event.accepted = true;
                                }
                            }

                            Keys.onDownPressed: event => {
                                if (window.suggestions.length > 0) {
                                    suggestionList.hoverItem = "";
                                    suggestionList.hoverLocked = true;

                                    let newIndex = window.suggestionIndex;
                                    if (newIndex < 0)
                                        newIndex = 0;

                                    window.suggestionIndex = Math.min(window.suggestions.length - 1, newIndex + 1);
                                    event.accepted = true;
                                }
                            }

                            Keys.onLeftPressed: event => {
                                window.keyboardNavigation = true;
                                listView.currentIndex = Math.max(0, listView.currentIndex - 1);
                            }

                            Keys.onRightPressed: event => {
                                window.keyboardNavigation = true;
                                listView.currentIndex = Math.min(listView.count - 1, listView.currentIndex + 1);
                            }

                            Keys.onReturnPressed: event => {
                                if (window.showHelp) {
                                    window.showHelp = false;
                                    return;
                                }
                                if (window.playlist.length > 0) {
                                    window.playlistActive = !window.playlistActive;
                                    if (window.playlistActive) {
                                        window.playlistLastApplied = 0;
                                    }
                                    saveSettings();
                                    showStatus(window.playlistActive ? "Playlist started · " + window.playlist.length + " wallpapers · every " + window.playlistInterval + "m" : "Playlist stopped");
                                    return;
                                }
                                applyWallpaper(getCurrentFilteredItem());
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: window.showHelp
                    z: 9
                    onClicked: window.showHelp = false
                }

                Rectangle {
                    id: helpPopup
                    visible: opacity > 0
                    opacity: window.showHelp ? 1 : 0
                    anchors.centerIn: parent
                    width: 605
                    height: 472
                    radius: 14
                    color: Theme.background90
                    border.color: Theme.border
                    border.width: 1
                    z: 10

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onWheel: event => event.accepted = true
                    }

                    Text {
                        id: helpTitle
                        anchors.top: parent.top
                        anchors.topMargin: 24
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Commands"
                        color: Theme.text
                        font.pixelSize: 25
                        font.weight: Font.Medium
                    }

                    Text {
                        id: helpFooter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Esc / Enter to close"
                        color: Theme.text
                        font.pixelSize: 12
                        opacity: 0.4
                    }

                    ListView {
                        anchors.top: helpTitle.bottom
                        anchors.bottom: helpFooter.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 24
                        anchors.topMargin: 12
                        anchors.bottomMargin: 12
                        boundsBehavior: Flickable.StopAtBounds

                        MouseArea {
                            hoverEnabled: true
                        }

                        clip: true
                        spacing: 0

                        model: [
                            {
                                cmd: ":static          |  :s",
                                desc: "Toggle static wallpapers"
                            },
                            {
                                cmd: ":dynamic         |  :d",
                                desc: "Toggle dynamic wallpapers"
                            },
                            {
                                cmd: ":favorite        |  :f",
                                desc: "Toggle favorites filter"
                            },
                            {
                                cmd: "Customizeable    |  :sus",
                                desc: "Toggle Mature content filter"
                            },
                            {
                                cmd: ":rename <name>   |  :rn ",
                                desc: "Renames highlighted wallpaper"
                            },
                            {
                                cmd: ":rename          |  :rn ",
                                desc: "Removes the current rename."
                            },
                            {
                                cmd: ":gif             |    ",
                                desc: "Toggle animated gif preview"
                            },
                            {
                                cmd: ":playlist<mins>  |  :pl",
                                desc: "Set playlist interval in minutes"
                            },
                            {
                                cmd: ":playlist        |  :pl",
                                desc: "Toggle playlist filter"
                            },
                            {
                                cmd: ":playlistshuffle |  :pls",
                                desc: "Makes playlist random"
                            },
                            {
                                cmd: "Shift+Click      |    ",
                                desc: "Add/remove wallpaper from playlist"
                            },
                            {
                                cmd: "Shift+Enter      |    ",
                                desc: "Start/stop playlist when items added"
                            },
                            {
                                cmd: ":width           |    ",
                                desc: "Set wallpaper cards width"
                            },
                            {
                                cmd: ":height          |    ",
                                desc: "Set wallpaper cards height"
                            },
                            {
                                cmd: ":spacing         |    ",
                                desc: "Set wallpaper cards spacing"
                            },
                            {
                                cmd: ":scale           |    ",
                                desc: "Set selected wallpapers scale"
                            },
                            {
                                cmd: ":random          |  :r",
                                desc: "Apply a random dynamic wallpaper"
                            },
                            {
                                cmd: ":randomstatic    |  :rs",
                                desc: "Apply a random static wallpaper"
                            },
                            {
                                cmd: ":randomfav       |  :rf",
                                desc: "Apply a random favorited wallpaper"
                            },
                            {
                                cmd: ":export <filter> |  :ex",
                                desc: "Export filtered wallpaper as steam URLs"
                            },
                            {
                                cmd: ":setfolder       |  :sf",
                                desc: "Set dynamic wallpapers folder"
                            },
                            {
                                cmd: ":setstatic       |  :ss",
                                desc: "Set static wallpapers folder"
                            },
                            {
                                cmd: ":setthumb        |  :st",
                                desc: "Set thumbnail cache folder"
                            },
                            {
                                cmd: ":setffmpeg       |     ",
                                desc: "Set ffmpeg path"
                            },
                            {
                                cmd: ":clearcache      |  :cc",
                                desc: "Clear thumbnail cache and regenerate"
                            },
                            {
                                cmd: ":reload          |  :rl",
                                desc: "Reload wallpaper folders"
                            },
                            {
                                cmd: ":open            |  :o ",
                                desc: "Open workshop for highlighted wallpaper"
                            },
                            {
                                cmd: ":id              |     ",
                                desc: "Copy highlighted wallpapers id"
                            },
                            {
                                cmd: ":tag <name>      |     ",
                                desc: "Filter by tag"
                            },
                            {
                                cmd: ":tag             |     ",
                                desc: "Clear tag filter"
                            },
                            {
                                cmd: ":sort            |     ",
                                desc: "Sorts wallpapers"
                            },
                            {
                                cmd: "Sort Arguments   |",
                                desc: "default, name, recent, favorite, random"
                            },
                            {
                                cmd: "Sort Shortcuts   |",
                                desc: "d,       n,    r,      f,"
                            },
                            {
                                cmd: ":help            |   :h",
                                desc: "Show this help"
                            }
                        ]

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 36
                            radius: 6

                            color: index % 2 === 0 ? "transparent" : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.04)

                            Row {
                                anchors.fill: parent
                                anchors.margins: 8

                                Text {
                                    width: 220
                                    text: modelData.cmd
                                    color: Theme.text
                                    font.pixelSize: 13
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    text: modelData.desc
                                    color: Theme.text
                                    font.pixelSize: 13
                                    opacity: 0.6
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: (window.wasInCommandMode ? "Command Mode" : "No wallpapers found")
                    visible: listView.count === 0 && !isInitialLoad
                    color: Theme.text
                    font.pixelSize: 24
                }
            }
        }
    }
}
