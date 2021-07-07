#ifndef KIOSK_WINDOW_H
#define KIOSK_WINDOW_H

#include <QWidget>
#include <QtWebEngineCore>
#include <QtWebEngineWidgets/QWebEngineView>


#include "KioskSettings.h"

class Kiosk;
class KioskProgress;

// NOTE: This is not a QMainWindow even though that would make a lot of sense.
//       For unknown reasons, QMainWindow and QWebEngineView interact in some
//       way that makes touch events not work on the Raspberry Pi.

class KioskWindow : public QWidget
{
    Q_OBJECT

public:
    explicit KioskWindow(Kiosk *kiosk, const KioskSettings *settings);
    ~KioskWindow();

    void setView(QWebEngineView *view);
    void setBrowserVisible(bool enabled);

    void showProgress(int percent);
    void hideProgress();

signals:
    void wakeup();

public slots:
    void showBrowser();
    void hideBrowser();

protected:
    void resizeEvent(QResizeEvent *event);

private slots:
    void doRunJavascriptDialog();
    void doGotoURLDialog();

private:
    Kiosk *kiosk_;
    const KioskSettings *settings_;

    KioskProgress *progress_;
    QWebEngineView *view_;

    bool showingBrowser_;
};

#endif // KIOSK_WINDOW_H
