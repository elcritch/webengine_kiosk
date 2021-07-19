import QtQuick 2.11
import QtQuick.Window 2.2
import QtQuick.VirtualKeyboard 2.3
import QtQuick.VirtualKeyboard.Settings 2.2
import QtWebEngine 1.7

Window {
    id: window
    visible: true
    title: qsTr("Hello World")

    Item {
        id: appContainer
        width: Screen.width < Screen.height ? parent.height : parent.width
        height: Screen.width < Screen.height ? parent.width : parent.height
        anchors.centerIn: parent
        rotation: Screen.width < Screen.height ? 90 : 0

        WebEngineView {
            id: webview
            anchors.fill: parent
            url: 'about:blank'
            objectName: "web"

            property bool enableContextMenu

            Component.onCompleted: console.log("From QML: ",this) // prints the root object

            onContextMenuRequested: {
                if (!enableContextMenu)
                    request.accepted = true
            }
        } 

        InputPanel {
            id: inputPanel
            z: 89
            y: appContainer.height
            anchors.left: parent.left
            anchors.right: parent.right
            states: State {
                name: "visible"
                /*  The visibility of the InputPanel can be bound to the Qt.inputMethod.visible property,
                    but then the handwriting input panel and the keyboard input panel can be visible
                    at the same time. Here the visibility is bound to InputPanel.active property instead,
                    which allows the handwriting panel to control the visibility when necessary.
                */
                when: inputPanel.active
                PropertyChanges {
                    target: inputPanel
                    y: appContainer.height - inputPanel.height
                }
            }
            transitions: Transition {
                id: inputPanelTransition
                from: ""
                to: "visible"
                reversible: true
                enabled: !VirtualKeyboardSettings.fullScreenMode
                ParallelAnimation {
                    NumberAnimation {
                        properties: "y"
                        duration: 250
                        easing.type: Easing.InOutQuad
                    }
                }
            }
            Binding {
                target: InputContext
                property: "animating"
                value: inputPanelTransition.running
            }
        }

        Binding {
            target: VirtualKeyboardSettings
            property: "fullScreenMode"
            value: appContainer.height > 0 && (appContainer.width / appContainer.height) > (16.0 / 9.0)
        }
    }
}