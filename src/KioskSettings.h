#ifndef KIOSKSETTINGS_H
#define KIOSKSETTINGS_H

#include <QUrl>
#include <QColor>
#include <unistd.h>

class QCoreApplication;

struct KioskSettings
{
    explicit KioskSettings(const QCoreApplication &app);

    QString dataDir;
    bool clearCache;
    QUrl homepage;
    bool fullscreen;
    int width;
    int height;
    int monitor;
    QString opengl;
    bool proxyEnabled;
    bool proxySystem;
    QString proxyHostname;
    quint16 proxyPort;
    QString proxyUsername;
    QString proxyPassword;
    bool stayOnTop;
    bool progress;
    bool scaleWithDPI;
    double pageScale;

    bool soundsEnabled;
    QUrl windowClickedSound;
    QUrl linkClickedSound;

    bool hideCursor;
    bool javascriptEnabled;
    bool javascriptCanOpenWindows;
    bool debugKeysEnabled;

    uid_t uid;
    gid_t gid;

    qreal zoomFactor;

    QString blankImage;
    QColor backgroundColor;
    QString httpAcceptLanguage;
    QString httpUserAgent;
};

#endif // KIOSKSETTINGS_H
