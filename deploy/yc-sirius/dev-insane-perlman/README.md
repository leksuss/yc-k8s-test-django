# Как задеплоить код в облачном Kubernetes яндекс.облака

Манифесты и скрипты по деплою dev-версии находятся в папке `deploy/yc-sirius/dev-insane-perlman/`, в которую надо перейти:
```shell
cd deploy/yc-sirius/dev-insane-perlman/
```

## Сборка приложения

Для сборки и отправки в репозитарий hub.docker.com необходимо запустить следующий скрипт 
```shell
bash deply.sh
```
По умолчанию данный скрипт создает и отправляет образ проекта последнего коммита. Если надо отправить образ проекта другой версии, необходимо переключиться на нужный коммит и явно указать его хэш в аргументах к скрипту:
```shell
git checkout <short_commit_hash>
bash deply.sh <short_commit_hash>
```

## Подключение к PostgreSQL

### Установка рутового SSL сертификата
Для верификации сервера при шифровании соединения необходимо поместить в secrets рутовый сертификат Яндекса. 
Для этого его необоходимо сначала [скачать](https://yandex.cloud/ru/docs/managed-postgresql/operations/connect#linux-macos_1) со страницы справки. 
Затем поместить в secrets:
```shell
kubectl create secret generic yandex-root-cert --from-file=<путь к root.crt>
```

## Запуск приложения

Для запуска приложения нужно создать объект Deployment и дать к нему доступ через порт, указанный в service:
```shell
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```




