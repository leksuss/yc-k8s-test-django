# Django Site

Докеризированный сайт на Django для экспериментов с Kubernetes.

Внутри контейнера Django приложение запускается с помощью Nginx Unit, не путать с Nginx. Сервер Nginx Unit выполняет сразу две функции: как веб-сервер он раздаёт файлы статики и медиа, а в роли сервера-приложений он запускает Python и Django. Таким образом Nginx Unit заменяет собой связку из двух сервисов Nginx и Gunicorn/uWSGI. [Подробнее про Nginx Unit](https://unit.nginx.org/).

Работающая версия сайта находится по адресу: [edu-insane-perlman.sirius-k8s.dvmn.org](edu-insane-perlman.sirius-k8s.dvmn.org).

Страничка с выделенными ресурсами: [https://sirius-env-registry.website.yandexcloud.net/edu-insane-perlman.html](https://sirius-env-registry.website.yandexcloud.net/edu-insane-perlman.html).

## Как задеплоить код в облачном Kubernetes Яндекс.облака

Манифесты и скрипты по деплою dev-версии находятся в папке `deploy/yc-sirius/dev-insane-perlman/`, в которую надо перейти:
```shell
cd deploy/yc-sirius/dev-insane-perlman/
```

### Сборка приложения

Для сборки и отправки в репозитарий [hub.docker.com](hub.docker.com) необходимо запустить следующий скрипт:
```shell
bash build.sh
```
По умолчанию данный скрипт создает и отправляет образ проекта последнего коммита в docker registry. 
Если надо отправить образ проекта другой версии, необходимо переключиться на нужный коммит и явно указать его хэш в аргументах к скрипту:
```shell
git checkout <short_commit_hash>
bash build.sh <short_commit_hash>
```

### Установка secrets - переменных окружения и SSL сертификата

#### Установка рутового SSL сертификата для подключения к Postgres
Для верификации сервера при шифровании соединения необходимо поместить в secrets рутовый сертификат Яндекса. 
Для этого его необоходимо сначала [скачать](https://yandex.cloud/ru/docs/managed-postgresql/operations/connect#linux-macos_1) со страницы справки. 
Затем поместить в secrets:
```shell
kubectl create secret generic yandex-root-cert --from-file=<путь к root.crt>
```

#### Переменные окружения
В репо уже есть подготовленный пример файла ресурса `secrets_example.yaml`, куда надо прописать следующие данные:
 - данные для подключения к Postgresql: `DB_LOGIN`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT` и `DB_NAME`. Путь к сертификату `root.crt` менять не надо. 
 - необходимо генерировать случайную строку для переменной `SECRET_KEY` и задать `DEBUG` режим.
 - указать в списке `ALLOWED_HOSTS` ваш домен. По умолчанию там уже прописан служебный домен [edu-insane-perlman.sirius-k8s.dvmn.org](edu-insane-perlman.sirius-k8s.dvmn.org) для DEV-окружения.

После подготовки манифеста с секретами необходимо создать ресурс:
```shell
mv secrets_example.yaml secrets.yaml
kubectl apply -f secrets.yaml
```

### Запуск приложения

Перед запуском приложения нужно применить миграции. Для применения миграций к базе при обновлении приложения используется следующая команда:
```shell
kubectl apply -f job_migrate.yaml
```

Для запуска приложения нужно создать объект Deployment:
```shell
kubectl apply -f deployment.yaml
```

