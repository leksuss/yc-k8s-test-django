## Как запустить dev-версию используя Kubernetes установленный в Minikube локально

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
