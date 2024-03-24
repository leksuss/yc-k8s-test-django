# Как задеплоить код
Для запуска приложения нужно создать объект Deployment и дать к нему доступ через порт, указанный в service:
```shell
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```