#include "Kiosk.h"
#include "KioskView.h"
#include "KioskProgress.h"
#include "ElixirComs.h"
#include "KioskSounds.h"
#include "StderrPipe.h"

#include <QNetworkProxy>
#include <QWebEngineSettings>
#include <QApplication>
#include <QLabel>
#include <QMetaObject>
#include <QMessageBox>

#include <QtQml>
#include <QtQml/QQmlProperty>
#include <QtWebEngineWidgets/QWebEngineView>

Kiosk::Kiosk(const KioskSettings *settings, QObject *parent) :
    QObject(parent),
    settings_(settings),
    coms_(nullptr),
    view_(nullptr),
    loadingPage_(false),
    showPageWhenDone_(true),
    theGoodWindow_(nullptr)
{
    // Set up the UI
    player_ = settings->soundsEnabled ? new KioskSounds(this) : nullptr;
    qApp->installEventFilter(this);
}

void Kiosk::init()
{
    if (settings_->proxyEnabled) {
        if (settings_->proxySystem) {
            QNetworkProxyFactory::setUseSystemConfiguration(true);
        } else {
            QNetworkProxy proxy;
            proxy.setType(QNetworkProxy::HttpProxy);
            proxy.setHostName(settings_->proxyHostname);
            proxy.setPort(settings_->proxyPort);
            if (!settings_->proxyUsername.isEmpty()) {
                proxy.setUser(settings_->proxyUsername);
                proxy.setPassword(settings_->proxyPassword);
            }
            QNetworkProxy::setApplicationProxy(proxy);
        }
    }

    if (settings_->hideCursor)
        QApplication::setOverrideCursor(Qt::BlankCursor);

    // Set up communication with Elixir
    coms_ = new ElixirComs(this);
    connect(coms_, SIGNAL(messageReceived(KioskMessage)), SLOT(handleRequest(KioskMessage)));

    // Take over stderr
    stderrPipe_ = new StderrPipe(this);
    connect(stderrPipe_, SIGNAL(inputReceived(QByteArray)), SLOT(handleStderr(QByteArray)));

}

void Kiosk::setView(QQuickItem *exview) {
    // Start the browser up
    view_ = exview;
    qDebug() << "SET VIEW: " << view_ << " with: " << exview << "\n";
    setContextMenuPolicy(settings_->contextMenu);
    setBackgroundColor(settings_->backgroundColor);

    QObject::connect(view_, SIGNAL(loadingChanged), this, SLOT(onLoadingChanged));

    goToUrl(settings_->homepage);
}

void Kiosk::goToUrl(const QUrl &url)
{
    QQmlProperty::write(view_, "url", url);
}

void Kiosk::runJavascript(const QString &program)
{
    QMetaObject::invokeMethod(view_, "runJavaScript", Q_ARG(QString, program));
}

void Kiosk::reload()
{
    QMetaObject::invokeMethod(view_, "reload");
}

void Kiosk::goBack()
{
    QMetaObject::invokeMethod(view_, "goBack");
}

void Kiosk::setBackgroundColor(const QColor color)
{
    QMetaObject::invokeMethod(view_, "backgroundColor", Q_ARG(QColor, color));
}

void Kiosk::goForward()
{
    QMetaObject::invokeMethod(view_, "goForward");
}

void Kiosk::stopLoading()
{
    QMetaObject::invokeMethod(view_, "stop");
}

void Kiosk::setContextMenuPolicy(bool enable)
{
    QQmlProperty::write(view_, "enableContextMenu", enable);
}

void Kiosk::handleRequest(const KioskMessage &message)
{
    switch (message.type()) {
    case KioskMessage::GoToURL:
        goToUrl(QUrl(QString::fromUtf8(message.payload())));
        break;

    case KioskMessage::RunJavascript:
        runJavascript(QString::fromUtf8(message.payload()));
        break;

    case KioskMessage::Blank:
        // window_->setBrowserVisible(message.payload().at(0) == 0);
        break;

    case KioskMessage::Reload:
        reload();
        break;

    case KioskMessage::GoBack:
        goBack();
        break;

    case KioskMessage::GoForward:
        goForward();
        break;

    case KioskMessage::StopLoading:
        stopLoading();
        break;

    case KioskMessage::SetZoom:
    {
        qreal zoom = message.payload().toDouble();
        if (zoom <= 0.01)
            zoom = 0.01;
        else if (zoom > 10.0)
            zoom = 10.0;

        break;
    }

    default:
        qFatal("Unknown message from Elixir: %d", message.type());
    }
}

static bool isInputEvent(QEvent *event)
{
    switch (event->type()) {
        case QEvent::TabletPress:
        case QEvent::TabletRelease:
        case QEvent::TabletMove:
        case QEvent::MouseButtonPress:
        case QEvent::MouseButtonRelease:
        case QEvent::MouseButtonDblClick:
        case QEvent::MouseMove:
        case QEvent::TouchBegin:
        case QEvent::TouchUpdate:
        case QEvent::TouchEnd:
        case QEvent::TouchCancel:
        case QEvent::ContextMenu:
        case QEvent::KeyPress:
        case QEvent::KeyRelease:
        case QEvent::Wheel:
            // qDebug() << "input event: " << event->type();
            return true;
        default:
            return false;
    }
}

bool Kiosk::eventFilter(QObject *object, QEvent *event)
{
    Q_UNUSED(object);

    // See https://bugreports.qt.io/browse/QTBUG-43602 for mouse events
    // seemingly not working with QWebEngineView.
    switch (event->type()) {
    case QEvent::MouseButtonPress:
        if (player_)
            player_->play(settings_->windowClickedSound);
        break;

    default:
        break;
    }

    return false;
}

void Kiosk::onLoadingChanged(QObject *loadRequest)
{
    qDebug() << "WebEngineLoadRequest: " << loadRequest << "\n";
}

void Kiosk::handleWakeup()
{
    coms_->send(KioskMessage::wakeup());
}

void Kiosk::handleRenderProcessTerminated(QWebEnginePage::RenderProcessTerminationStatus status, int exitCode)
{
    coms_->send(KioskMessage::browserCrashed(status, exitCode));
}

void Kiosk::handleStderr(const QByteArray &line)
{
    coms_->send(KioskMessage::consoleLog(line));
}

void Kiosk::urlChanged(const QUrl &url)
{
    coms_->send(KioskMessage::urlChanged(url));

    // This is the real link clicked
    if (player_)
        player_->play(settings_->linkClickedSound);
}

void Kiosk::elixirMessageReceived(const QString &messageStr)
{
    coms_->send(KioskMessage::channelMessage(messageStr));
}
