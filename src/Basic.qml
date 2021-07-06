import QtQuick 2.11
import QtQuick.Window 2.2
import QtQuick.VirtualKeyboard 2.3
import QtQuick.VirtualKeyboard.Settings 2.2
import QtWebEngine 1.7

Window {
    id: window
    visible: true
    title: qsTr("Hello World")

    WebEngineView {
        id: webview
        anchors.fill: parent
        url: 'https://www.google.com'
    }

    Rectangle {
        height: 10
        width: 10
        color: "green"
    }

    Component.onCompleted: {
        VirtualKeyboardSettings.fullScreenMode = true;
    }
}