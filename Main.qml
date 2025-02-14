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
    title: "Basic Memo"

    property string currentFile: tabView.children[tabBar.currentIndex] ? tabView.children[tabBar.currentIndex].filePath : ""
    property bool isModified: tabView.children[tabBar.currentIndex] ? tabView.children[tabBar.currentIndex].isModified : false

    Shortcut {
        sequence: StandardKey.New
        onActivated: createNewTab()
    }

    Shortcut {
        sequence: "Ctrl+T"
        onActivated: createNewTab()
    }

    Shortcut {
        sequence: StandardKey.Open
        onActivated: openDialog.open()
    }

    Shortcut {
        sequence: StandardKey.Save
        onActivated: {
            let currentTab = tabView.children[tabBar.currentIndex]
            if (currentTab) {
                if (currentTab.filePath === "") {
                    saveDialog.open()
                } else {
                    backend.saveFile("file://" + currentTab.filePath, currentTab.text)
                }
            }
        }
    }

    Shortcut {
        sequence: StandardKey.SaveAs
        onActivated: saveDialog.open()
    }

    Shortcut {
        sequence: StandardKey.Close
        onActivated: {
            if (tabBar.count > 1) {
                closeCurrentTab()
            }
        }
    }

    Shortcut {
        sequence: StandardKey.Quit
        onActivated: Qt.quit()
    }

    Component {
        id: tabComponent
        Page {
            id: tabPage
            property string filePath: ""
            property alias text: textArea.text
            property bool isModified: false
            property bool isInitializing: true  // 初期化フラグを追加

            ScrollView {
                anchors.fill: parent
                TextArea {
                    id: textArea
                    font.pixelSize: 16
                    wrapMode: TextArea.Wrap
                    selectByMouse: true
                    persistentSelection: true
                    focus: true  // フォーカスを受け取れるようにする
                    onTextChanged: {
                        if (!tabPage.isInitializing) {  // 初期化中は変更フラグを立てない
                            tabPage.isModified = true
                            // タブボタンの状態も更新
                            for (let i = 0; i < tabBar.count; i++) {
                                if (tabView.children[i] === tabPage) {
                                    let button = tabBar.itemAt(i)
                                    if (button) {
                                        button.isModified = true
                                    }
                                    break
                                }
                            }
                        }
                    }

                    Component.onCompleted: {
                        tabPage.isInitializing = false  // 初期化完了
                    }

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
    }

    Component {
        id: tabButtonComponent
        TabButton {
            font.pixelSize: 16
            property string filePath: ""
            property bool isModified: false
            width: Math.min(200, implicitWidth)
            contentItem: Label {
                text: filePath ? filePath.split("/").pop() + (isModified ? "*" : "") : "無題" + (isModified ? "*" : "")
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideMiddle
            }
        }
    }

    function createNewTab(filePath, content) {
        // タブボタンを作成
        let button = tabButtonComponent.createObject(tabBar, {
            filePath: filePath || "",
            isModified: false
        })
        
        // 新しいタブを作成
        let tab = tabComponent.createObject(tabView)
        tab.isInitializing = true  // 初期化フラグを設定
        tab.filePath = filePath || ""
        tab.text = content || ""
        tab.isModified = false
        tab.isInitializing = false  // 初期化完了
        
        // タブを選択
        tabBar.setCurrentIndex(tabBar.count - 1)

        // 新しいタブのTextAreaにフォーカスを移動
        let textArea = tab.children[0].children[0]  // ScrollView -> TextArea
        if (textArea) {
            textArea.forceActiveFocus()
        }
    }

    MessageDialog {
        id: saveConfirmDialog
        title: "保存確認"
        text: "変更を保存しますか？"
        buttons: MessageDialog.Yes | MessageDialog.No | MessageDialog.Cancel

        property var callback: null
        property int tabIndexToClose: -1

        onYesClicked: {
            // Yesが押された場合
            let currentTab = tabView.children[tabIndexToClose]
            if (currentTab.filePath === "") {
                saveDialog.callback = function() {
                    if (callback) callback(true)
                }
                saveDialog.open()
            } else {
                backend.saveFile("file://" + currentTab.filePath, currentTab.text)
                if (callback) callback(true)
            }
        }

        onNoClicked: {
            // Noが押された場合
            if (callback) callback(true)
        }

        onRejected: {
            // Cancelが押された場合
            if (callback) callback(false)
        }
    }

    function closeCurrentTab() {
        if (tabBar.count <= 1) {
            return // 最後のタブは閉じない
        }
        
        let currentIndex = tabBar.currentIndex
        let currentTab = tabView.children[currentIndex]
        
        if (currentTab && currentTab.isModified) {
            saveConfirmDialog.tabIndexToClose = currentIndex
            saveConfirmDialog.callback = function(shouldClose) {
                if (shouldClose) {
                    actuallyCloseTab(currentIndex)
                }
            }
            saveConfirmDialog.open()
        } else {
            actuallyCloseTab(currentIndex)
        }
    }

    function actuallyCloseTab(index) {
        let currentTab = tabView.children[index]
        
        // タブを削除
        if (currentTab) {
            currentTab.destroy()
        }

        // タブボタンを削除
        let buttons = []
        for (let i = 0; i < tabBar.count; i++) {
            if (i !== index) {
                buttons.push(tabBar.itemAt(i))
            }
        }
        
        // TabBarをクリアして再構築
        while (tabBar.count > 0) {
            tabBar.takeItem(0)
        }
        
        buttons.forEach(button => {
            tabBar.addItem(button)
        })
        
        // インデックスを調整
        if (index > 0) {
            tabBar.setCurrentIndex(index - 1)
        } else if (tabBar.count > 0) {
            tabBar.setCurrentIndex(0)
        }

        // 新しくアクティブになったタブのTextAreaにフォーカスを移動
        let newActiveTab = tabView.children[tabBar.currentIndex]
        if (newActiveTab) {
            let textArea = newActiveTab.children[0].children[0]  // ScrollView -> TextArea
            if (textArea) {
                textArea.forceActiveFocus()
            }
        }
    }

    Connections {
        target: backend
        function onFileOpened(path, content) {
            createNewTab(path, content)
        }
        function onFileSaved(path) {
            let currentTab = tabView.children[tabBar.currentIndex]
            if (currentTab) {
                currentTab.isModified = false
                currentTab.filePath = path
                // タブボタンのファイルパスも更新
                let button = tabBar.itemAt(tabBar.currentIndex)
                if (button) {
                    button.filePath = path
                    button.isModified = false
                }
            }
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
            let currentTab = tabView.children[tabBar.currentIndex]
            if (currentTab) {
                backend.saveFile(saveDialog.file, currentTab.text)
            }
        }
    }

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            TabBar {
                id: tabBar
                Layout.fillWidth: true

                // タブバーの空きスペースをダブルクリックで新規タブ
                MouseArea {
                    anchors.fill: parent
                    enabled: true
                    onDoubleClicked: {
                        // クリックされた位置が既存のタブ上でない場合のみ新規タブを作成
                        let clickedTab = false
                        for (let i = 0; i < tabBar.count; i++) {
                            let tab = tabBar.itemAt(i)
                            if (tab && mouseX >= tab.x && mouseX <= tab.x + tab.width) {
                                clickedTab = true
                                break
                            }
                        }
                        if (!clickedTab) {
                            createNewTab()
                        }
                    }
                    z: -1 // タブボタンの下に配置
                }
            }
            Button {
                id: newTabButton
                text: "+"
                implicitWidth: 40
                onClicked: createNewTab()
            }
        }
    }

    MenuBar {
        Menu {
            title: "ファイル"
            MenuItem {
                text: "新規"
                shortcut: StandardKey.New
                onTriggered: createNewTab()
            }
            MenuItem {
                text: "新規タブ"
                shortcut: "Ctrl+T"
                onTriggered: createNewTab()
            }
            MenuItem {
                text: "開く"
                shortcut: StandardKey.Open
                onTriggered: openDialog.open()
            }
            MenuItem {
                text: "保存"
                shortcut: StandardKey.Save
                enabled: tabView.children.length > tabBar.currentIndex
                onTriggered: {
                    let currentTab = tabView.children[tabBar.currentIndex]
                    if (currentTab.filePath === "") {
                        saveDialog.open()
                    } else {
                        backend.saveFile("file://" + currentTab.filePath, currentTab.text)
                    }
                }
            }
            MenuItem {
                text: "名前を付けて保存"
                shortcut: StandardKey.SaveAs
                enabled: tabView.children.length > tabBar.currentIndex
                onTriggered: saveDialog.open()
            }
            MenuSeparator {}
            MenuItem {
                text: "タブを閉じる"
                shortcut: StandardKey.Close
                enabled: tabBar.count > 1
                onTriggered: closeCurrentTab()
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
                enabled: tabView.children.length > tabBar.currentIndex
                onTriggered: {
                    let currentTab = tabView.children[tabBar.currentIndex]
                    if (currentTab) {
                        currentTab.children[0].children[0].undo()
                    }
                }
            }
            MenuItem {
                text: "やり直し"
                shortcut: StandardKey.Redo
                enabled: tabView.children.length > tabBar.currentIndex
                onTriggered: {
                    let currentTab = tabView.children[tabBar.currentIndex]
                    if (currentTab) {
                        currentTab.children[0].children[0].redo()
                    }
                }
            }
            MenuSeparator {}
            MenuItem {
                text: "切り取り"
                shortcut: StandardKey.Cut
                enabled: tabView.children.length > tabBar.currentIndex
                onTriggered: {
                    let currentTab = tabView.children[tabBar.currentIndex]
                    if (currentTab) {
                        currentTab.children[0].children[0].cut()
                    }
                }
            }
            MenuItem {
                text: "コピー"
                shortcut: StandardKey.Copy
                enabled: tabView.children.length > tabBar.currentIndex
                onTriggered: {
                    let currentTab = tabView.children[tabBar.currentIndex]
                    if (currentTab) {
                        currentTab.children[0].children[0].copy()
                    }
                }
            }
            MenuItem {
                text: "貼り付け"
                shortcut: StandardKey.Paste
                enabled: tabView.children.length > tabBar.currentIndex
                onTriggered: {
                    let currentTab = tabView.children[tabBar.currentIndex]
                    if (currentTab) {
                        currentTab.children[0].children[0].paste()
                    }
                }
            }
        }
    }

    StackLayout {
        id: tabView
        anchors.fill: parent
        currentIndex: tabBar.currentIndex
    }

    Component.onCompleted: {
        createNewTab() // 初期タブを作成
    }
}
