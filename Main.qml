import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt.labs.platform

ApplicationWindow {
    id: window
    visible: true
    width: 800
    height: 600
    title: "シンプルテキストエディタ" + (currentFile ? " - " + currentFile : "") + (isModified ? "*" : "")

    property string currentFile: ""
    property bool isModified: false

    Connections {
        target: backend
        function onFileOpened(path, content) {
            currentFile = path
            textArea.text = content
            isModified = false
        }
        function onFileSaved(path) {
            currentFile = path
            isModified = false
        }
    }

    FileDialog {
        id: openDialog
        title: "ファイルを開く"
        nameFilters: ["テキストファイル (*.txt)", "すべてのファイル (*)"]
        onAccepted: {
            backend.openFile(openDialog.file)
        }
    }

    FileDialog {
        id: saveDialog
        title: "名前を付けて保存"
        nameFilters: ["テキストファイル (*.txt)", "すべてのファイル (*)"]
        fileMode: FileDialog.SaveFile
        onAccepted: {
            backend.saveFile(saveDialog.file, textArea.text)
        }
    }

    MenuBar {
        Menu {
            title: "ファイル"
            MenuItem {
                text: "開く"
                shortcut: StandardKey.Open
                onTriggered: openDialog.open()
            }
            MenuItem {
                text: "保存"
                shortcut: StandardKey.Save
                onTriggered: {
                    if (currentFile === "") {
                        saveDialog.open()
                    } else {
                        backend.saveFile(currentFile, textArea.text)
                    }
                }
            }
            MenuItem {
                text: "名前を付けて保存"
                shortcut: StandardKey.SaveAs
                onTriggered: saveDialog.open()
            }
            MenuSeparator {}
            MenuItem {
                text: "終了"
                shortcut: StandardKey.Quit
                onTriggered: Qt.quit()
            }
        }
        Menu {
            title: "編集"
            MenuItem {
                text: "元に戻す"
                shortcut: StandardKey.Undo
                onTriggered: textArea.undo()
            }
            MenuItem {
                text: "やり直し"
                shortcut: StandardKey.Redo
                onTriggered: textArea.redo()
            }
            MenuSeparator {}
            MenuItem {
                text: "切り取り"
                shortcut: StandardKey.Cut
                onTriggered: textArea.cut()
            }
            MenuItem {
                text: "コピー"
                shortcut: StandardKey.Copy
                onTriggered: textArea.copy()
            }
            MenuItem {
                text: "貼り付け"
                shortcut: StandardKey.Paste
                onTriggered: textArea.paste()
            }
        }
    }

    ScrollView {
        anchors.fill: parent
        TextArea {
            id: textArea
            wrapMode: TextArea.Wrap
            selectByMouse: true
            persistentSelection: true
            onTextChanged: isModified = true

            DropArea {
                anchors.fill: parent
                onEntered: function(drag) {
                    drag.accepted = drag.hasUrls
                }
                onDropped: function(drag) {
                    if (drag.hasUrls) {
                        backend.openFile(drag.urls[0])
                    }
                }
            }
        }
    }
}
