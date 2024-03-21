# Django Site

Докеризированный сайт на Django для экспериментов с Kubernetes.

Внутри контейнера Django приложение запускается с помощью Nginx Unit, не путать с Nginx. Сервер Nginx Unit выполняет сразу две функции: как веб-сервер он раздаёт файлы статики и медиа, а в роли сервера-приложений он запускает Python и Django. Таким образом Nginx Unit заменяет собой связку из двух сервисов Nginx и Gunicorn/uWSGI. [Подробнее про Nginx Unit](https://unit.nginx.org/).

## Как подготовить окружение к локальной разработке

Код в репозитории полностью докеризирован, поэтому для запуска приложения вам понадобится Docker. Инструкции по его установке ищите на официальных сайтах:

- [Get Started with Docker](https://www.docker.com/get-started/)

Вместе со свежей версией Docker к вам на компьютер автоматически будет установлен Docker Compose. Дальнейшие инструкции будут его активно использовать.

## Как запустить сайт для локальной разработки

Запустите базу данных и сайт:

```shell
$ docker compose up
```

В новом терминале, не выключая сайт, запустите несколько команд:

```shell
$ docker compose run --rm web ./manage.py migrate  # создаём/обновляем таблицы в БД
$ docker compose run --rm web ./manage.py createsuperuser  # создаём в БД учётку суперпользователя
```

Готово. Сайт будет доступен по адресу [http://127.0.0.1:8080](http://127.0.0.1:8080). Вход в админку находится по адресу [http://127.0.0.1:8000/admin/](http://127.0.0.1:8000/admin/).

## Как вести разработку

Все файлы с кодом django смонтированы внутрь докер-контейнера, чтобы Nginx Unit сразу видел изменения в коде и не требовал постоянно пересборки докер-образа -- достаточно перезапустить сервисы Docker Compose.

### Как обновить приложение из основного репозитория

Чтобы обновить приложение до последней версии подтяните код из центрального окружения и пересоберите докер-образы:

``` shell
$ git pull
$ docker compose build
```

После обновлении кода из репозитория стоит также обновить и схему БД. Вместе с коммитом могли прилететь новые миграции схемы БД, и без них код не запустится.

Чтобы не гадать заведётся код или нет — запускайте при каждом обновлении команду `migrate`. Если найдутся свежие миграции, то команда их применит:

```shell
$ docker compose run --rm web ./manage.py migrate
…
Running migrations:
  No migrations to apply.
```

### Как добавить библиотеку в зависимости

В качестве менеджера пакетов для образа с Django используется pip с файлом requirements.txt. Для установки новой библиотеки достаточно прописать её в файл requirements.txt и запустить сборку докер-образа:

```sh
$ docker compose build web
```

Аналогичным образом можно удалять библиотеки из зависимостей.

## Переменные окружения

Образ с Django считывает настройки из переменных окружения:

`SECRET_KEY` -- обязательная секретная настройка Django. Это соль для генерации хэшей. Значение может быть любым, важно лишь, чтобы оно никому не было известно. [Документация Django](https://docs.djangoproject.com/en/3.2/ref/settings/#secret-key).

`DEBUG` -- настройка Django для включения отладочного режима. Принимает значения `TRUE` или `FALSE`. [Документация Django](https://docs.djangoproject.com/en/3.2/ref/settings/#std:setting-DEBUG).

`ALLOWED_HOSTS` -- настройка Django со списком разрешённых адресов. Если запрос прилетит на другой адрес, то сайт ответит ошибкой 400. Можно перечислить несколько адресов через запятую, например `127.0.0.1,192.168.0.1,site.test`. [Документация Django](https://docs.djangoproject.com/en/3.2/ref/settings/#allowed-hosts).

`DATABASE_URL` -- адрес для подключения к базе данных PostgreSQL. Другие СУБД сайт не поддерживает. [Формат записи](https://github.com/jacobian/dj-database-url#url-schema).


## Как запустить dev-версию используя Kubernetes

[Установите](https://kubernetes.io/ru/docs/tasks/tools/install-minikube/) `minikube`, запустите его командой:
```shell
$ minikube start
```

### Создание образа и загрузка его в кластер

```shell
minikube image build -t myapp backend_main_django
```

### Запуск Postgres в кластере Kubernetes

Перед запуском приложения нужно запустить базу данных Postgres. Для её запуска в кластере kubernetes можно воспользоваться helm, [установив](https://helm.sh/docs/intro/install/) его.
Далее устанавливаем Postgres:
```shell
helm install postgres bitnami/postgresql
```

Чтобы подключиться к Postgres с локальной машины для того, чтобы создать пользователя и базу данных, можно воспользоваться следующими командами:
```shell
export POSTGRES_PASSWORD=$(kubectl get secret --namespace default postgres-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)
kubectl run postgres-postgresql-client --rm --tty -i --restart='Never' --namespace default --image docker.io/bitnami/postgresql:16.2.0-debian-12-r8 --env="PGPASSWORD=$POSTGRES_PASSWORD" \
      --command -- psql --host postgres-postgresql -U postgres -d postgres -p 5432
```

После создания БД и пользователя нужно узнать IP адрес, по которому Postgres доступен в кластере. Для этого определяем эндпоинт созданного сервиса:
```shell
kubectl describe service postgres-postgresql | grep Endpoints
```
Полученный IP адрес, а также данные для подключения к БД необходимо внести в файл с секретами (см. ниже).

Это валидно для варианта запуска minikube с использованием драйвера Docker. Если драйвер virtualbox, можно использовать доменное имя `postgres-postgresql.default.svc.cluster.local`

### Переменные среды и чувствительные данные

В репозитории есть пример файла `env_vars_example.yaml`, в котором нужно заполнить значение переменной `DEBUG`. Этот файл описывает объект `ConfigMap`.
А в примере файла с секретами `env_secrets_example.yaml` нужно прописать `SECRET_KEY` и `DATABASE_URL`. Этот файл описывает объект `Secret`.

Затем необходимо создать объекты `ConfigMap` и `Secret`, указав путь к файлам, которые были созданы на основе примеров данных выше:
```shell
$ kubectl apply -f kubernetes/env_vars.yaml
$ kubectl apply -f kubernetes/env_secrets.yaml
```

Перед запуском приложения нужно применить миграции. Для применения миграций к базе при обновлении приложения используется следующая команда:
```shell
kubectl apply -f kubernetes/job_migrate.yaml
```

После чего запускаем наше приложение через создание объекта `Deployment`:
```shell
kubectl apply -f kubernetes/project.yaml
```

Для проброса портов вам нужно также запустить следующую команду:
```shell
kubectl port-forward svc/project-service 8080:80
```

После чего приложение будет доступно из браузера по адресу `127.0.0.1:8080`

### Подключение доменного имени через ingress-контроллер

Включаем ingress и ingress-dns:
```shell
minikube addons enable ingress
minikube addons enable ingress-dns
```

Доменное имя прописывается:
1) в файле `kubernetes/ingress.yaml` (параметр `host`)
2) в созданном ранее файле переменных окружения `kubernetes/env_vars.yaml` (параметр `ALLOWED_HOSTS`, для django).
3) в локальном DNS (файле `/etc/hosts` для linux-based ОС и `C:\Windows\System32\drivers\etc\hosts` для Windows). Если вы используете драйвер docker, домен должен резолвится в IP `127.0.0.1`. Если используется virtualbox, домен должен резолвится в ip адрес виртуалки, где запущен minikube. Его можно узнать, набрав команду `minikube ip`.
По умолчанию в файлах репозитория уже прописан домен `star-burger.test`. В случае с файлом `hosts` вам нужно это сделать самостоятельно. При желании вы можете поменять домен на любой другой.

Создаем новый объект ingress с нашими настройками:
```shell
kubectl apply -f kubernetes/ingress.yaml
```

В случае если вы используете драйвер docker, необходимо пробросить наше приложение из докера на хостовую машину запустив команду ниже.
Если у вас все еще запущен port-forwarding с портами 8080:80, то его следует остановить `ctrl+z`, т.к. данная команда также осуществляет проброс порта, но на другой порт.
```shell
sudo kubectl port-forward svc/project-service 80:80
```
Из-за того, что пробрасывается 80 порт, необходимо запускать команду используя sudo.
После всего этого наше приложение будет отвечать по доменному имени в браузере на 80 порту.

### Очистка сессий в Django

Для периодической очистки сессий в Django необходимо создать объект `CronJob`, манифест которого находится в соответствующем файле:
```shell
kubectl apply -f kubernetes/cronjobs.yaml
```
По умолчанию установлена очистка сессий раз в месяц. Можно это переопределить через параметр `schedule`. Если необходимо вручную запустить очистку, можно воспользоваться следующей командой:
```shell
kubectl create job --from=cronjob/django-clearsessions-once django-clearsessions-once
```
