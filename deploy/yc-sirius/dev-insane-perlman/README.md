# Как задеплоить код

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


