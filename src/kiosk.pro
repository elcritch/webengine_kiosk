QT       = core gui network widgets multimedia webenginewidgets webengine virtualkeyboard qml quick 

CONFIG += console link_pkgconfig c++11 force_debug_info 
CONFIG -= app_bundle

TARGET = kiosk
TEMPLATE = app

OTHER_FILES += \
    Basic.qml 

SOURCES += main.cpp\
    ElixirJsChannel.cpp \
    KioskSettings.cpp \
    ElixirComs.cpp \
    KioskMessage.cpp \
    Kiosk.cpp \
    KioskWindow.cpp \
    KioskProgress.cpp \
    KioskSounds.cpp \
    StderrPipe.cpp

HEADERS  += \
    ElixirJsChannel.h \
    KioskSettings.h \
    ElixirComs.h \
    KioskMessage.h \
    Kiosk.h \
    KioskWindow.h \
    KioskProgress.h \
    KioskSounds.h \
    StderrPipe.h

RESOURCES += \
    ui.qrc

# The following line requires $INSTALL_ROOT to be set to $MIX_APP_PATH when
# calling "make install". See $MIX_APP_PATH/obj/Makefile.
target.path = /priv

INSTALLS += target

