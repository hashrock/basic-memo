#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QFile>
#include <QUrl>
#include <QDebug>
#include <QTextStream>
#include <QStringConverter>

class Backend : public QObject
{
    Q_OBJECT
public:
    explicit Backend(QObject *parent = nullptr) : QObject(parent) {}

public slots:
    void openFile(const QUrl &fileUrl) {
        QString path = fileUrl.toLocalFile();
        QFile file(path);
        
        if (!file.open(QIODevice::ReadOnly)) {
            qDebug() << "ファイルを開けませんでした:" << path;
            return;
        }

        QTextStream in(&file);
        in.setAutoDetectUnicode(true);
        QString content = in.readAll();
        file.close();

        emit fileOpened(path, content);
    }

    void saveFile(const QUrl &fileUrl, const QString &content) {
        QString path = fileUrl.toLocalFile();
        QFile file(path);
        
        if (!file.open(QIODevice::WriteOnly)) {
            qDebug() << "ファイルを保存できませんでした:" << path;
            return;
        }

        QTextStream out(&file);
        out.setEncoding(QStringConverter::Utf8);
        out << content;
        file.close();

        emit fileSaved(path);
    }

signals:
    void fileOpened(const QString &path, const QString &content);
    void fileSaved(const QString &path);
};

#include "main.moc"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;

    Backend backend;
    engine.rootContext()->setContextProperty("backend", &backend);

    const QUrl url(u"qrc:/basic-memo/Main.qml"_qs);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
