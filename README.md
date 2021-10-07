# IvanPrivalov_microservices
IvanPrivalov microservices repository

## CI/CD в Kubernetes

<details>
  <summary>Решение</summary>

### План:

- Работа с Helm
- Развертывание Gitlab в Kubernetes
- Запуск CI/CD конвейера в Kubernetes

### Helm

Установка:

```shell

sudo curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

```

Добавим репо:

```shell

helm repo add stable https://charts.helm.sh/stable && helm repo add incubator https://charts.helm.sh/incubator && helm repo add harbor https://helm.goharbor.io && helm repo update

```

Установим Ingress:

```shell

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.44.0/deploy/static/provider/cloud/deploy.yaml

```

### Charts

Chart для компонентов ui, comment, post приложения:

```shell

.
├── comment
│   ├── Chart.yaml
│   ├── templates
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── values.yaml
├── post
│   ├── Chart.yaml
│   ├── templates
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── values.yaml
└── ui
    ├── Chart.yaml
    ├── templates
    │   ├── deployment.yaml
    │   ├── ingress.yaml
    │   └── service.yaml
    └── values.yaml

```

Добавим Helper-ы.

Helper - это написанная нами функция. В функции описывается, как правило, сложная логика. Шаблоны этих функция распологаются в файле _helpers.tpl

Структура становится следующая:

```shell

.
├── comment
│   ├── Chart.yaml
│   ├── templates
│   │   ├── deployment.yaml
│   │   ├── _helpers.tpl
│   │   └── service.yaml
│   └── values.yaml
├── post
│   ├── Chart.yaml
│   ├── templates
│   │   ├── deployment.yaml
│   │   ├── _helpers.tpl
│   │   └── service.yaml
│   └── values.yaml
└── ui
    ├── Chart.yaml
    ├── templates
    │   ├── deployment.yaml
    │   ├── _helpers.tpl
    │   ├── ingress.yaml
    │   └── service.yaml
    └── values.yaml

```

### Управление зависимостями.

С помощью механизма управления зависимостями создадим единый Chart reddit, который объединит наши компоненты.

Загрузим зависимости:

```shell

helm dep update

```

Структура станет следующей:

```shell

reddit
├── charts
│   ├── comment-1.0.0.tgz
│   ├── mongodb-7.8.10.tgz
│   ├── post-1.0.0.tgz
│   └── ui-1.0.0.tgz
├── Chart.yaml
├── requirements.lock
├── requirements.yaml
└── values.yaml

```

Установим наше приложение:

```shell

kubectl create ns dev
helm upgrade --install --namespace=dev --wait reddit-release reddit/

$ kubectl get ingress -n dev
NAME                CLASS    HOSTS   ADDRESS           PORTS   AGE
reddit-release-ui   <none>   *       178.154.222.206   80      71s

$ kubectl get pods -n dev
NAME                                   READY   STATUS    RESTARTS   AGE
reddit-test-comment-5c884b6fff-2zv2d   1/1     Running   0          40s
reddit-test-comment-5c884b6fff-bpdmq   1/1     Running   0          40s
reddit-test-comment-5c884b6fff-btkwg   1/1     Running   0          40s
reddit-test-mongodb-bb985f44d-rftnh    1/1     Running   0          40s
reddit-test-post-6b58f9b58d-6t2xp      1/1     Running   0          40s
reddit-test-post-6b58f9b58d-ckqqj      1/1     Running   0          40s
reddit-test-post-6b58f9b58d-t67p9      1/1     Running   0          40s
reddit-test-ui-644f46774b-bvkq6        1/1     Running   0          40s
reddit-test-ui-644f46774b-vv95x        1/1     Running   0          40s
reddit-test-ui-644f46774b-wnfvr        1/1     Running   0          40s

```

### GitLab + Kubernetes

Поднимем k8s и установим nginx ingress

```shell

cd kubernetes/k8s-terraform/
terraform apply
yc managed-kubernetes cluster get-credentials k8s-cluster --external --force
kubectl config current-context
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.44.0/deploy/static/provider/cloud/deploy.yaml

```

Установим GitLab:

```shell

helm repo add gitlab https://charts.gitlab.io

helm fetch gitlab/gitlab-omnibus --version 0.1.37 --untar

cd gitlab-omnibus

helm install gitlab . -f values.yaml

```

Запуск проекта.

Локально создана директория Gitlab_ci со следующей структурой каталогов.

```shell

Gitlab_ci
├── comment
├── post
├── reddit-deploy
└── ui

```

Перенес исходные коды сервиса ui в Gitlab_ci/ui

```shell

tree
├── build_info.txt
├── config.ru
├── docker_build.sh
├── Dockerfile
├── Dockerfile_v1
├── Gemfile
├── Gemfile.lock
├── helpers.rb
├── middleware.rb
├── newfile
├── ui_app.rb
├── VERSION
└── views
    ├── create.haml
    ├── index.haml
    ├── layout.haml
    └── show.haml

```

Настроен CI для компонентов reddit app и для деплоя приложения.

</details>

## Kubernetes 3 (Networks, Storages.)

<details>
  <summary>Решение</summary>

### LoadBalancer

Настроим соответствующим образом Service UI

ui-service.yml:

```shell

---
apiVersion: v1
kind: Service
metadata:
  name: ui
  labels:
    app: reddit
    component: ui
spec:
  type: LoadBalancer
  ports:
  - port: 80
    nodePort: 32092
    protocol: TCP
    targetPort: 9292
  selector:
    app: reddit
    component: ui

```

Настроим соответствующим образом Service UI

```shell

kubectl apply -f ./kubernetes/reddit/ui-service.yml -n dev

```

Проверим:

```shell

kubectl get service -n dev --selector component=ui

otus@otus-VirtualBox:~/Desktop/IvanPrivalov_microservices$ kubectl get service -n dev --selector component=ui
NAME   TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)        AGE
ui     LoadBalancer   10.96.134.193   178.154.205.67   80:32092/TCP   4m54s


```

Наш адрес: http://178.154.205.67:80

### Ingress

Основные задачи, решаемые с помощью Ingress'ов:

- Организация единой точки входа в приложения снаружи
- Обеспечение балансировки трафика
- Терминация SSL
- Виртуальный хостинг на основе имен и т. д.

Установим Ingress:

```shell

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.34.1/deploy/static/provider/cloud/deploy.yaml

```

```shell

kubectl get pods -n ingress-nginx

NAME                                        READY   STATUS      RESTARTS   AGE
ingress-nginx-admission-create-2gq4h        0/1     Completed   0          2m10s
ingress-nginx-admission-patch-v4trm         0/1     Completed   1          2m10s
ingress-nginx-controller-7d7999cdf6-mxcgw   1/1     Running     0          2m20s

```

![image 5](https://github.com/Otus-DevOps-2021-05/IvanPrivalov_microservices/blob/kubernetes-3/kubernetes/screens/k8s_5.png)

Создадим Ingress для сервиса UI

ui-ingress.yml:

```shell

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ui
spec:
  backend:
    serviceName: ui
    servicePort: 80

```

Применим конфиг:

```shell

kubectl apply -f ./kubernetes/reddit/ui-ingress.yml -n dev

otus@otus-VirtualBox:~/Desktop/IvanPrivalov_microservices$ kubectl apply -f ./kubernetes/reddit/ui-ingress.yml -n dev
ingress.extensions/ui created

kubectl get ingress -n dev

NAME   CLASS    HOSTS   ADDRESS         PORTS   AGE
ui     <none>   *       130.193.39.62   80      5m27s

```

### Secret

Теперь давайте защитим наш сервис с помощью TLS.

Для начала вспомним IngressIP:

```shell

$ kubectl get ingress -n dev

NAME   CLASS    HOSTS   ADDRESS         PORTS   AGE
ui     <none>   *       130.193.39.62   80      24m

```

Далее подготовим сертификат используя IP как CN

```shell

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=130.193.39.62"

Generating a RSA private key
.......................................+++++
.................................+++++
writing new private key to 'tls.key'
-----

```

И загрузит сертификат в кластер kubernetes

```shell

kubectl create secret tls ui-ingress --key tls.key --cert tls.crt -n dev

secret/ui-ingress created

```

Проверить можно командой:

```shell

kubectl describe secret ui-ingress -n dev

Name:         ui-ingress
Namespace:    dev
Labels:       <none>
Annotations:  <none>

Type:  kubernetes.io/tls

Data
====
tls.crt:  1123 bytes
tls.key:  1704 bytes

```

### TLS Termination

Теперь настроим Ingress на прием только HTTPS траффика

ui-ingress.yml

```shell

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ui
  annotations:
    kubernetes.io/ingress.allow-http: "false"
spec:
  tls:
  - secretName: ui-ingress
  backend:
    serviceName: ui
    servicePort: 9292

```

Применим:

```shell

kubectl apply -f ./kubernetes/reddit/ui-ingress.yml -n dev

ingress.extensions/ui configured

```

Иногда протокол HTTP может не удалиться у существующего Ingress правила, тогда нужно его вручную удалить и пересоздать

```shell

$ kubectl delete ingress ui -n dev
$ kubectl apply -f ./kubernetes/reddit/ui-ingress.yml -n dev

```

![image 6](https://github.com/Otus-DevOps-2021-05/IvanPrivalov_microservices/blob/kubernetes-3/kubernetes/screens/k8s_6.png)

### Задание со *

Опишите создаваемый объект Secret в виде Kubernetes-манифеста.

Создал манифест tls-secret.yml

```shell

apiVersion: v1
kind: Secret
metadata:
  name: ui-ingress
type: kubernetes.io/tls
data:
  tls.crt:

  tls.key:

```

Добавил в ui-ingress.yml обьект Secret

```shell

---
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: ui
    annotations:
      kubernetes.io/ingress.allow-http: "false"
  spec:
    tls:
      - secretName: ui-ingress
    rules:
    - http:
        paths:
        - path: "/"
          pathType: Prefix
          backend:
            service:
              name: ui
              port:
                number: 9292

```

### Network Policy

Имя кластера:

```shell

$ yc container cluster list
+----------------------+-------------+---------------------+---------+---------+-----------------------+---------------------+
|          ID          |    NAME     |     CREATED AT      | HEALTH  | STATUS  |   EXTERNAL ENDPOINT   |  INTERNAL ENDPOINT  |
+----------------------+-------------+---------------------+---------+---------+-----------------------+---------------------+
| catrd4rvg5cav24bqqur | k8s-cluster | 2021-09-30 07:40:07 | HEALTHY | RUNNING | https://62.84.116.228 | https://10.128.0.28 |
+----------------------+-------------+---------------------+---------+---------+-----------------------+---------------------+

```

Создадим NetworkPolicy.

mongo-network-policy.yml:

```shell

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-db-traffic
  labels:
    app: reddit
spec:
  podSelector:
    matchLabels:
      app: reddit
      component: mongo
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: reddit
          component: comment

```

Применяем политику:

```shell

$ kubectl apply -f ./kubernetes/reddit/mongo-network-policy.yml -n dev

networkpolicy.networking.k8s.io/deny-db-traffic created

```

Обновил mongo-network-policy.yml так, чтобы post-сервис дошел до базы данных.

```shell

---
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: deny-db-traffic
    labels:
      app: reddit
  spec:
    podSelector:
      matchLabels:
        app: reddit
        component: mongo
    policyTypes:
      - Ingress
    ingress:
    - from:
      - podSelector:
          matchLabels:
            app: reddit
            component: comment
      - podSelector:
          matchLabels:
            app: reddit
            component: post

```

Применяем политику:

```shell

$ kubectl apply -f ./kubernetes/reddit/mongo-network-policy.yml -n dev

networkpolicy.networking.k8s.io/deny-db-traffic created

```

### Хранилище для базы

Основной Stateful сервис в нашем приложении - это базы данных MongoDB. В текущий момент она запускается в виде Deployment и хранит данные в стандартных Docker
Volume-ах.

Это имеет несколько проблем:

- При удалении POD-а удаляется и Volume
- Потерям Nod'ы с mongo грозит потерей данных
- Запуск базы на другой ноде запускает новый экземпляр данных

### PersitentVolume

Cоздадим диск в ya.cloud командой:

```shell

yc compute disk create \
--name k8s \
--size 4 \
--description "disk for k8s"

id: fhmcfarojp7vehcc7om3
folder_id: b1gfroh2tett7b3hdn78
created_at: "2021-09-30T10:04:24Z"
name: k8s
description: disk for k8s
type_id: network-hdd
zone_id: ru-central1-a
size: "4294967296"
block_size: "4096"
status: READY
disk_placement_policy: {}

$ yc compute disk list
+----------------------+------+-------------+---------------+--------+----------------------+--------------+
|          ID          | NAME |    SIZE     |     ZONE      | STATUS |     INSTANCE IDS     | DESCRIPTION  |
+----------------------+------+-------------+---------------+--------+----------------------+--------------+
| fhmcfarojp7vehcc7om3 | k8s  |  4294967296 | ru-central1-a | READY  |                      | disk for k8s |
+----------------------+------+-------------+---------------+--------+----------------------+--------------+

```

Создадим PV в ya.cloud

mongo-volume.yml:

```shell

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mongo-pv
spec:
  capacity:
    storage: 4Gi
  accessModes:
    - ReadWriteOnce
  csi:
    driver: disk-csi-driver.mks.ycloud.io
    fsType: ext4
    volumeHandle: fhmcfarojp7vehcc7om3

```

Выполним:

```shell

$ kubectl apply -f ./kubernetes/reddit/mongo-volume.yml -n dev

persistentvolume/mongo-pv created

```

Создадим PVC

mongo-claim.yml:

```shell

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongo-pvc
spec:
  storageClassName: ""
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 4Gi
  volumeName: mongo-pv

```

Выполним:

```shell

$ kubectl apply -f ./kubernetes/reddit/mongo-claim.yml -n dev

persistentvolumeclaim/mongo-pvc created

```

Добавим volume в mongo-deployment.yml

```shell

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongo
  labels:
    app: reddit
    component: mongo
    comment-db: "true"
    post-db: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: reddit
      component: mongo
  template:
    metadata:
      name: mongo
      labels:
        app: reddit
        component: mongo
        comment-db: "true"
        post-db: "true"
    spec:
      containers:
      - image: mongo:3.2
        name: mongo
        volumeMounts:
        - name: mongo-persistent-storage
          mountPath: /data/db
      volumes:
        - name: mongo-persistent-storage
          persistentVolumeClaim:
            claimName:  mongo-pvc

```

Выполним:

```shell

$ kubectl apply -f ./kubernetes/reddit/mongo-deployment.yml -n dev

deployment.apps/mongo configured

```

Создадим пост:

![image 7](https://github.com/Otus-DevOps-2021-05/IvanPrivalov_microservices/blob/kubernetes-3/kubernetes/screens/k8s_7.png)

Удалим deployment:

```shell

$ kubectl delete deploy mongo -n dev

deployment.apps "mongo" deleted

```

![image 8](https://github.com/Otus-DevOps-2021-05/IvanPrivalov_microservices/blob/kubernetes-3/kubernetes/screens/k8s_8.png)

Снова создадим деплой mongo:

```shell

$ kubectl apply -f ./kubernetes/reddit/mongo-deployment.yml -n dev

deployment.apps/mongo configured

```

![image 9](https://github.com/Otus-DevOps-2021-05/IvanPrivalov_microservices/blob/kubernetes-3/kubernetes/screens/k8s_9.png)

Наш пост на месте.

</details>

## Kubernetes 2 (Запуск кластера и приложения. Модель безопасности)

<details>
  <summary>Решение</summary>

### Разворачиваем Kubernetes локально

```shell

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubectl

```

### Установка Minikube

```shell

curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
sudo dpkg -i minikube_latest_amd64.deb

```

Запустим Minikube-кластер (весрия 1.19.7):

```shell

minikube start --kubernetes-version 1.19.7

```

Minikube-кластер развернут.

```shell

otus@otus-VirtualBox:~$ kubectl get nodes
NAME       STATUS   ROLES    AGE   VERSION
minikube   Ready    master   43s   v1.19.7

```

### Запуск приложения

Запуск приложения в kubernetes необходимо описать в YAML-манифестах.
Вся конфигурация находится в каталоге ./kubernetes/reddit.

Запустим на кластере minikube:

```shell

kubectl apply -f kubernetes/reddit/

```

По-умолчанию все сервисы имеют тип ClusterIP - это значит, что сервис располагается на внутреннем диапазоне IP-адресов кластера. Снаружи до него нет доступа. Тип NodePort - на каждой ноде кластера открывает порт из диапазона 30000-32767 и переправляет трафик с этого порта на тот, который указан в targetPort Pod.

Опишем порт в ui-service.yml:

```shell

spec:
  type: NodePort
  ports:
  - nodePort: 32092
    port: 9292
    protocol: TCP
    targetPort: 9292
  selector:
    app: reddit
    component: ui

```

Проверим:

```shell

minikube service ui

|-----------|------|-------------|---------------------------|
| NAMESPACE | NAME | TARGET PORT |            URL            |
|-----------|------|-------------|---------------------------|
| default   | ui   |        9292 | http://192.168.49.2:32092 |
|-----------|------|-------------|---------------------------|
🎉  Opening service default/ui in default browser...

minikube service list

|-------------|------------|--------------|---------------------------|
|  NAMESPACE  |    NAME    | TARGET PORT  |            URL            |
|-------------|------------|--------------|---------------------------|
| default     | comment    | No node port |
| default     | comment-db | No node port |
| default     | kubernetes | No node port |
| default     | mongodb    | No node port |
| default     | post       | No node port |
| default     | post-db    | No node port |
| default     | ui         |         9292 | http://192.168.49.2:32092 |
| kube-system | kube-dns   | No node port |
|-------------|------------|--------------|---------------------------|

```

![image 1](https://github.com/Otus-DevOps-2021-05/IvanPrivalov_microservices/blob/kubernetes-2/kubernetes/screens/k8s_1.png)


### Dashboard

Зайдем в Dashboard:

```shell

minikube service kubernetes-dashboard -n kube-system

```

В самом Dashboard можно:

- Отслеживать состояние кластера и рабочих нагрузок в нем
- Создавать новые объекты (загружать YAML-файлы)
- Удалять и изменять объекты (кол-во реплик, YAML-файлы)
- Отслеживать логи в POD-ах
- При включении Heapster-аддона смотреть нагрузку на POD-ах
- и т. д.

### Namespace

Отделим среду для разработки приложения от всего остального кластера. Для этого создадим Namespace dev-namespace:

```shell

---
apiVersion: v1
kind: Namespace
metadata:
  name: dev

```

Создаем Namespace и запустем приложение в нем:

```shell

kubectl apply -f dev-namespace.yml
kubectl apply -n dev -f kubernetes/reddit/

```

Проверим результат:

```shell

minikube service ui -n dev

```

![image 2](https://github.com/Otus-DevOps-2021-05/IvanPrivalov_microservices/blob/kubernetes-2/kubernetes/screens/k8s_2.png)

### Yandex Cloud Managed Service for kubernetes

Создаем кластер и группу хостов. Подключаемся к кластеру:

```shell

yc managed-kubernetes cluster get-credentials test-cluster --external

```

Проверим подключение к нашему кластеру:

```shell

kubectl config current-context
yc-test-cluster

```

Запустим наше приложение в K8s.

Создадим dev namespace:

```shell

kubectl apply -f ./kubernetes/reddit/dev-namespace.yml

```

Задеплоим наше приложение:

```shell

kubectl apply -f ./kubernetes/reddit/ -n dev

otus@otus-VirtualBox:~/Desktop/IvanPrivalov_microservices$ kubectl apply -f ./kubernetes/reddit/ -n dev
deployment.apps/comment created
service/comment-db created
service/comment created
namespace/dev unchanged
deployment.apps/mongo created
service/mongodb created
deployment.apps/post created
service/post-db created
service/post created
deployment.apps/ui created
service/ui created

```

Проверим развернулись ли наши поды:

```shell

kubectl get pods -n dev

otus@otus-VirtualBox:~/Desktop/IvanPrivalov_microservices$ kubectl get pods -n dev
NAME                      READY   STATUS    RESTARTS   AGE
comment-f8db99cc4-jx9hh   1/1     Running   0          3m9s
comment-f8db99cc4-rh7qc   1/1     Running   0          3m9s
comment-f8db99cc4-sm7q2   1/1     Running   0          3m9s
mongo-6b9fcfd49f-4dbs9    1/1     Running   0          3m8s
post-68f884b866-chv2r     1/1     Running   0          3m8s
post-68f884b866-dxskq     1/1     Running   0          3m8s
post-68f884b866-f7tzb     1/1     Running   0          3m8s
ui-6bc94db77c-2n8gt       1/1     Running   0          3m8s
ui-6bc94db77c-ckjrg       1/1     Running   0          3m8s
ui-6bc94db77c-w6g8r       1/1     Running   0          3m8s

```

Определим по какому адресу обратимся к нашему кластеру:

```shell

kubectl get nodes -o wide

otus@otus-VirtualBox:~/Desktop/IvanPrivalov_microservices$ kubectl get nodes -o wide
NAME                        STATUS   ROLES    AGE   VERSION    INTERNAL-IP   EXTERNAL-IP       OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
cl1otcitojcuav607tq5-ikec   Ready    <none>   14m   v1.19.10   10.128.0.12   178.154.203.75    Ubuntu 20.04.2 LTS   5.4.0-74-generic   docker://20.10.7
cl1otcitojcuav607tq5-ubep   Ready    <none>   14m   v1.19.10   10.128.0.22   178.154.205.145   Ubuntu 20.04.2 LTS   5.4.0-74-generic   docker://20.10.7

```

и порт публикации:

```shell

kubectl describe service ui -n dev | grep NodePort

otus@otus-VirtualBox:~/Desktop/IvanPrivalov_microservices$ kubectl describe service ui -n dev | grep NodePort
Type:                     NodePort
NodePort:                 <unset>  32093/TCP

```

![image 3](https://github.com/Otus-DevOps-2021-05/IvanPrivalov_microservices/blob/kubernetes-2/kubernetes/screens/k8s_3.png)

### Разверните Kubernetes-кластер в Yandex cloud с помощью Terraform

Настройки Terraform для развертывания K8S на Yandex Сloud находятся kubernetes\k8s-terraform.

Запуск:

```shell

cd ./kubernetes/k8s-terraform

terraform init

terraform aplly

```

Проверим результат:

```shell

yc managed-kubernetes cluster get-credentials k8s-cluster --external

kubectl config current-context
yc-k8s-cluster

```

И запустим приложение:

```shell

cd ../..
kubectl apply -f ./kubernetes/reddit/dev-namespace.yml
kubectl apply -f ./kubernetes/reddit/ -n dev
kubectl get pods -n dev

otus@otus-VirtualBox:~/Desktop/IvanPrivalov_microservices$ kubectl get pods -n dev
NAME                      READY   STATUS    RESTARTS   AGE
comment-f8db99cc4-8g2d4   1/1     Running   0          3m2s
comment-f8db99cc4-c2nls   1/1     Running   0          3m2s
comment-f8db99cc4-vfdfz   1/1     Running   0          3m2s
mongo-6b9fcfd49f-bjsnh    1/1     Running   0          3m2s
post-68f884b866-2lj4j     1/1     Running   0          3m1s
post-68f884b866-8bg6c     1/1     Running   0          3m1s
post-68f884b866-j2l99     1/1     Running   0          3m1s
ui-6bc94db77c-9b24n       1/1     Running   0          3m1s
ui-6bc94db77c-ch48h       1/1     Running   0          3m1s
ui-6bc94db77c-x7qpd       1/1     Running   0          3m1s

kubectl get nodes -o wide

otus@otus-VirtualBox:~/Desktop/IvanPrivalov_microservices$ kubectl get nodes -o wide
NAME                        STATUS   ROLES    AGE     VERSION    INTERNAL-IP   EXTERNAL-IP       OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
cl1hh42o2998dfbupaim-afec   Ready    <none>   7m50s   v1.19.10   10.128.0.13   178.154.240.237   Ubuntu 20.04.2 LTS   5.4.0-74-generic   docker://20.10.7
cl1hh42o2998dfbupaim-ivox   Ready    <none>   7m43s   v1.19.10   10.128.0.28   62.84.112.235     Ubuntu 20.04.2 LTS   5.4.0-74-generic   docker://20.10.7

```

Приложение доступно по адресу http://178.154.240.237:32093/

![image 4](https://github.com/Otus-DevOps-2021-05/IvanPrivalov_microservices/blob/kubernetes-2/kubernetes/screens/k8s_4.png)

</details>

## Kubernetes 1

<details>
  <summary>Решение</summary>

## Создание примитивов

Создал файл в kubernetes/reddit/post-deployment.yml:

```shell

apiVersion: apps/v1
kind: Deployment
metadata:
  name: post-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: post
  template:
    metadata:
      name: post
      labels:
        app: post
    spec:
      containers:
      - image: chromko/post
        name: post

```

Аналогично создаем:

- ui-deployment.yml
- comment-deployment.yml
- mongo-deployment.yml

## Установка k8s при помощи утилиты kubeadm

Создаем 2 ноды Ubuntu 18:

```shell

yc compute instance create \
  --name master \
  --zone ru-central1-a \
  --network-interface subnet-name=otus-ru-central1-a,nat-ip-version=ipv4 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1804-lts,size=40 \
  --memory=4 \
  --cores=4 \
  --ssh-key ~/.ssh/id_rsa.pub

yc compute instance create \
  --name worker \
  --zone ru-central1-a \
  --network-interface subnet-name=otus-ru-central1-a,nat-ip-version=ipv4 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1804-lts,size=40 \
  --memory=4 \
  --cores=4 \
  --ssh-key ~/.ssh/id_rsa.pub

```

Устанавливаем: docker v=19.03 и k8s v=1.19:

```shell

sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io kubelet kubeadm kubectl

sudo apt-get install docker-ce=5:19.03.15~3-0~ubuntu-bionic docker-ce-cli=5:19.03.15~3-0~ubuntu-bionic containerd.io kubelet=1.19.14-00 kubeadm=1.19.14-00 kubectl=1.19.14-00

```

Поднимем кластер k8s с помощью kubeadm:

```shell

kubeadm init --apiserver-cert-extra-sans=178.154.204.64 --apiserver-advertise-address=0.0.0.0 --control-plane-endpoint=178.154.204.64 --pod-network-cidr=10.244.0.0/16

```

Послу успешной установки получим пример команды для добавления worker ноды в кластер:

```shell

kubeadm join 178.154.204.64:6443 --token affw0g.fdckmh8digy48n9e \
    --discovery-token-ca-cert-hash sha256:3c01bf311db86349eb128a3d461f14b09811f8032e97e11391dd17e58c458588

```

Создадим конфиг файл для пользователя на мастер ноде:

```shell

mkdir $HOME/.kube/
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $USER $HOME/.kube/config

```

Проверим наши ноды:

```shell

root@fhmch8e4qjpi9o55vrj2:~# kubectl get nodes
NAME                   STATUS     ROLES    AGE     VERSION
fhm7j2sia4bub0vp6ss0   NotReady   <none>   3m36s   v1.19.14
fhmch8e4qjpi9o55vrj2   NotReady   master   4m13s   v1.19.14

```

Ноды находятся в статусе NotReady, посмотрим состояние ноды:

```shell

kubectl describe node fhm7j2sia4bub0vp6ss0

NetworkReady=false reason:NetworkPluginNotReady message:docker: network plugin is not ready: cni config uninitialized

```

Не установлен сетевой плагин. Установим сетевой плагин calico:

```shell

curl https://docs.projectcalico.org/manifests/calico.yaml -O

раскомментируем переменную CALICO_IPV4POOL_CIDR в манифесте и установить для нее значение init: 10.244.0.0/16

kubectl apply -f calico.yaml

```

Проверим состояние нод:

```shell

root@fhmch8e4qjpi9o55vrj2:~# kubectl get nodes
NAME                   STATUS   ROLES    AGE   VERSION
fhm7j2sia4bub0vp6ss0   Ready    <none>   15m   v1.19.14
fhmch8e4qjpi9o55vrj2   Ready    master   16m   v1.19.14

```

Запустим один из манифестов нашего приложения и убедимся, что он применяется:

```shell

kubectl apply -f post-deployment.yml

NAME                              READY   STATUS              RESTARTS   AGE
post-deployment-799c77ffb-mvgpr   0/1     ContainerCreating   0          20s

```

## Установка кластера k8s с помощью terraform и ansible

- В каталоге kubernetes созданы каталоги terraform и ansible. В данных каталогах созданы манифесты.

- Terraform динамически создает необходимое количество нод.

- Ansible с помощью ролей разворачивает Kubernetes кластер.

- Версии k8s и docker зафиксированы через переменные на 1.19 и 19.03 соответсвенно.

- В Terraform настроен provisioner для автоматического разворачивания кластера через ansible-playbook.

```shell

cd ./kubernetes/terraform
terraform init
terraform plan
terraform apply

```

Подключимся к master и проверим состояние нод:

```shell

ssh ubuntu@178.154.254.67

ubuntu@fhmbsupuro805qiu3etr:~$ kubectl get nodes
NAME                   STATUS   ROLES    AGE     VERSION
fhmbsupuro805qiu3etr   Ready    master   4m17s   v1.19.14
fhmqce4m84fj6t84gc2p   Ready    <none>   83s     v1.19.14

```

</details>


## Логирование и распределенная трассировка

<details>
  <summary>Решение</summary>

- Логирование Docker-контейнеров
- Сбор неструктурированных логов
- Визуализация логов
- Сбор структурированных логов
- Распределенный трейсинг

### Описание

1. Создал инстанс в Yandex Cloud c помощью docker-machine:

```shell

yc compute instance create \
  --name logging \
  --zone ru-central1-a \
  --network-interface subnet-name=otus-ru-central1-a,nat-ip-version=ipv4 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1804-lts,size=15 \
  --memory=4 \
  --ssh-key ~/.ssh/id_rsa.pub

docker-machine create \
  --driver generic \
  --generic-ip-address=178.154.254.210 \
  --generic-ssh-user yc-user \
  --generic-ssh-key ~/.ssh/id_rsa \
  logging

# перейти в окружение docker хоста
eval $(docker-machine env docker-host)

```

2. Собрал новые образы сервисов reddit с функционалом логгирования, а также fluentd

3. Описал сервисы в docker-compose:

docker-compose.yml - сервисы приложения reddit

```shell

version: '3.3'
services:

  post_db:
    env_file: .env
    image: mongo:${MONGODB_VERSION}
    environment:
      - ZIPKIN_ENABLED=${ZIPKIN_ENABLED}
    volumes:
      - post_db:/data/db
    networks:
      back_net:
        aliases:
          - post_db
          - comment_db

  ui:
    env_file: .env
#    build: ./ui
#    image: ${USER_NAME}/ui:${UI_VERSION}
    image: ${USER_NAME}/ui:logging
    environment:
      - ZIPKIN_ENABLED=${ZIPKIN_ENABLED}
    ports:
      - ${UI_HOST_PORT}:${UI_CONTAINER_PORT}/tcp
    logging:
      driver: "fluentd"
      options:
        fluentd-address: localhost:24224
        tag: service.ui
    networks:
      - front_net

  post:
    env_file: .env
#    build: ./post-py
#    image: ${USER_NAME}/post:${POST_VERSION}
    image: ${USER_NAME}/post:logging
    environment:
      - POST_DATABASE_HOST=post_db
      - POST_DATABASE=posts
      - ZIPKIN_ENABLED=${ZIPKIN_ENABLED}
    depends_on:
      - post_db
    ports:
      - "5000:5000"
    logging:
      driver: "fluentd"
      options:
        fluentd-address: localhost:24224
        tag: service.post
    networks:
      - front_net
      - back_net

  comment:
    env_file: .env
#    build: ./comment
#    image: ${USER_NAME}/comment:${COMMENT_VERSION}
    image: ${USER_NAME}/comment:logging
    environment:
      - ZIPKIN_ENABLED=${ZIPKIN_ENABLED}
    networks:
      - front_net
      - back_net

volumes:

  post_db:

networks:

  front_net:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: ${FRONT_NET_SUBNET}

  back_net:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: ${BACK_NET_SUBNET}

```

docker-compose-logging.yml - сервисы логгирования:

- elasticsearch
- kibana
- fluentd
- zipkin

```shell

version: '3'
services:

  zipkin:
    env_file: .env
    image: openzipkin/zipkin:2.21.0
    ports:
      - "9411:9411"
    networks:
      - front_net
      - back_net

  fluentd:
    env_file: .env
    image: ${USER_NAME}/fluentd
    ports:
      - "24224:24224"
      - "24224:24224/udp"
    networks:
      - front_net
      - back_net

  elasticsearch:
    env_file: .env
    image: elasticsearch:7.4.0
    environment:
      - ELASTIC_CLUSTER=false
      - CLUSTER_NODE_MASTER=true
      - CLUSTER_MASTER_NODE_NAME=es01
      - discovery.type=single-node
    expose:
      - 9200
    ports:
      - "9200:9200"
    networks:
      - front_net
      - back_net

  kibana:
    env_file: .env
    image: kibana:7.4.0
    ports:
      - "5601:5601"
    networks:
      - front_net
      - back_net

networks:
  front_net:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: ${FRONT_NET_SUBNET}
  back_net:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: ${BACK_NET_SUBNET}

```

### Запуск

```shell

cd docker
eval "(docker-machine env logging)"
docker-compose -f docker-compose-logging.yml up -d
docker-compose -f docker-compose.yml up -d
docker-compose -f docker-compose-logging.yml -f docker-compose.yml ps

otus@otus-VirtualBox:~/Desktop/IvanPrivalov_microservices/docker$ docker-compose -f docker-compose-logging.yml -f docker-compose.yml ps
         Name                       Command               State                                          Ports
------------------------------------------------------------------------------------------------------------------------------------------------------
docker_comment_1         puma                             Up
docker_elasticsearch_1   /usr/local/bin/docker-entr ...   Up      0.0.0.0:9200->9200/tcp,:::9200->9200/tcp, 9300/tcp
docker_fluentd_1         tini -- /bin/entrypoint.sh ...   Up      0.0.0.0:24224->24224/tcp,:::24224->24224/tcp,
                                                                  0.0.0.0:24224->24224/udp,:::24224->24224/udp, 5140/tcp
docker_kibana_1          /usr/local/bin/dumb-init - ...   Up      0.0.0.0:5601->5601/tcp,:::5601->5601/tcp
docker_post_1            python3 post_app.py              Up      0.0.0.0:5000->5000/tcp,:::5000->5000/tcp
docker_post_db_1         docker-entrypoint.sh mongod      Up      27017/tcp
docker_ui_1              puma                             Up      0.0.0.0:9292->9292/tcp,:::9292->9292/tcp
docker_zipkin_1          /busybox/sh run.sh               Up      9410/tcp, 0.0.0.0:9411->9411/tcp,:::9411->9411/tcp

```

Проверка:

- kibana - http://178.154.254.210:5601
- zipkin - http://178.154.254.210:9411

</details>

## Введение в мониторинг. Системы мониторинга (Prometheus)

<details>
  <summary>Решение</summary>

1. Prometheus: запуск, конфигурация, Web UI
2. Мониторинг состояния микросервисов
3. Сбор метрик хоста с использованием экспортера

### Подготовка

1. Создал инcтсанс в Yandex Cloud, проинициализировал на нем docker:

```shell

yc compute instance create \
  --name gitlab-ci-vm \
  --zone ru-central1-a \
  --network-interface subnet-name=otus-ru-central1-a,nat-ip-version=ipv4 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1804-lts,size=15 \
  --memory 4GB \
  --ssh-key ~/.ssh/id_rsa.pub

docker-machine create \
  --driver generic \
  --generic-ip-address=178.154.206.97 \
  --generic-ssh-user yc-user \
  --generic-ssh-key ~/.ssh/id_rsa \
  docker-host

# перейти в окружение docker хоста
eval $(docker-machine env docker-host)

```

2. Запустил Prometheus в контейнере для проверки:

```shell

docker run --rm -p 9090:9090 -d --name prometheus  prom/prometheus

```

3. Переупорядчил структуру директорий:

- Создал каталог ./docker и перенес в него каталог docker-monolith и файлы docker-compose.*, .env (переименовал .env.example).
В нем будем запускать микросервисы в docker-compose.
- Cоздал каталог ./monitoring/prometheus c файлами: Dockerfile, prometheus.yml.
В нем будем собирать образ Prometheus.

### Сборка образов

4. Собрал образы микросервисов с healthckeck-ми:

Сборка сервисов reddit с помощью скриптов:

```shell

export USER_NAME=privalovip # добавляем префикс для образа

/src/ui      $ bash docker_build.sh
/src/post-py $ bash docker_build.sh
/src/comment $ bash docker_build.sh

```

Сборка Prometheus из Dockerfile:

```shell

cd ./monitoring/prometheus
docker build -t $USER_NAME/prometheus .

```

Dockerfile

```shell

FROM prom/prometheus:v2.1.0
ADD prometheus.yml /etc/prometheus/

```

Конфигурация Prometheus происходит через файлы конфигурации и опции командной строки. В monitoring/prometheus создаем файл prometheus.yml:

```shell

---
global:
  scrape_interval: '5s'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets:
        - 'localhost:9090'

  - job_name: 'ui'
    static_configs:
      - targets:
        - 'ui:9292'

  - job_name: 'comment'
    static_configs:
      - targets:
        - 'comment:9292'

```

Prometheus поднимаем совместно с микросервисами. В docker/docker-compose.yml опишем новый сервис:

```shell

services:

...

  prometheus:
    image: ${USER_NAME}/prometheus
    ports:
      - 9090:9090
    volumes:
      - prometheus_data:/prometheus
    command:
    # Передаем доп параметры вкомандной строке
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention=1d' # Задаем время хранения метрик в 1 день
    networks:
      - front_net
      - back_net
...

  volumes:
    prometheus_data:

```

Изменим build образов наших микросервисом на уже подготовленные образы через скрипт docker_build.sh:

```shell

  #build: ./ui
  #image: ${USERNAME}/ui:${UI_TAG}

  image: ${USER_NAME}/ui

```

Поднимаем сервисы. Поскольку в предыдущих заданиях был использован docker-compose.override.yml, то игнорируем его при запуске:

```shell

docker-compose -f docker-compose.yml up -d

```

Убедимся, что сервисы (контейнеры) поднялись:

```shell

docker-compose ps

       Name                      Command               State                    Ports
-------------------------------------------------------------------------------------------------------
docker_comment_1      puma                             Up
docker_post_1         python3 post_app.py              Up
docker_post_db_1      docker-entrypoint.sh mongod      Up      27017/tcp
docker_prometheus_1   /bin/prometheus --config.f ...   Up      0.0.0.0:9090->9090/tcp,:::9090->9090/tcp
docker_ui_1           puma                             Up      0.0.0.0:9292->9292/tcp,:::9292->9292/tcp

```

## Exporters

Экспортер похож на вспомогательного агента для сбора метрик.

В ситуациях, когда мы не можем реализовать отдачу метрик Prometheus в коде приложения, мы можем использовать экспортер, который будет транслировать метрики приложения или системы в формате доступном для чтения Prometheus.

Для сбора информации о работе Docker хоста и представления этой информации в Prometheus воспользуемся Node exporter.

Определим ещё один сервиc в docker/docker-compose.yml:

```shell

node-exporter:
  image: prom/node-exporter:v0.15.2
  user: root
  volumes:
    - /proc:/host/proc:ro
    - /sys:/host/sys:ro
    - /:/rootfs:ro
  command:
    - '--path.procfs=/host/proc'
    - '--path.sysfs=/host/sys'
    - '--collector.filesystem.ignored-mount-points="^/(sys|proc|dev|host|etc)($$|/)"'
  networks:
    - front_net
    - back_net

```

И в monitoring/prometheus/prometheus.yml добавим job для node exporter:

```shell

- job_name: 'node'
  static_configs:
    - targets:
      - 'node-exporter:9100'

```

Соберем новый Docker образ для Prometheus:

```shell

cd monitoring/prometheus

docker build -t $USER_NAME/prometheus .

```

Пересоздадим сервисы:

```shell

cd ../../docker/
docker-compose down
docker-compose -f docker-compose.yml up -d

```

Убедимся, что список endpoint-ов Prometheus появился ещё один endpoint - node.

![image 1](https://github.com/Otus-DevOps-2021-05/IvanPrivalov_microservices/blob/monitoring-1/monitoring/Screenshot_4.png)

Добавим нагрузки на Docker Host и проверм:

```shell

docker-machine ssh docker-host

yes > /dev/null

```

![image 2](https://github.com/Otus-DevOps-2021-05/IvanPrivalov_microservices/blob/monitoring-1/monitoring/Screenshot_5.png)

## Обазы в DockerHub

```shell

docker login
Login Succeeded


docker push $USER_NAME/ui
docker push $USER_NAME/comment
docker push $USER_NAME/post
docker push $USER_NAME/prometheus

```

Ссылка на DockerHub: https://hub.docker.com/u/privalovip

# Задания со *

## MongoDB Exporter

Соберем Docker образ нашего mongodb_exporter через monitoring/mongodb-exporter/Dockerfile

```shell

FROM alpine:3.14

WORKDIR /tmp/mongodb
RUN   apk update \
  &&   apk --no-cache add ca-certificates wget \
  &&   update-ca-certificates

RUN wget https://github.com/percona/mongodb_exporter/releases/download/v0.20.7/mongodb_exporter-0.20.7.linux-amd64.tar.gz && \
    tar xvzf mongodb_exporter-0.20.7.linux-amd64.tar.gz && \
    cp mongodb_exporter-0.20.7.linux-amd64/mongodb_exporter /usr/local/bin/. && \
    rm -rf /tmp/mongodb

WORKDIR /

EXPOSE 9216

CMD ["mongodb_exporter"]

```

Далее добавим наш экпортер в monitoring/prometheus/prometheus.yml:

```shell

  - job_name: 'mongodb'
    static_configs:
      - targets:
        - 'mongodb-exporter:9216'

```

и docker/docker-compose.yml:

```shell

  mongodb-exporter:
    image: ${USER_NAME}/mongodb-exporter
    environment:
      MONGODB_URI: mongodb://post_db:27017
    networks:
      - back_net

```

Соберем заново наши образы и контейнеры:

```shell

cd monitoring/mongodb-exporter
docker build -t $USER_NAME/mongodb-exporter .

cd monitoring/prometheus
docker build -t $USER_NAME/prometheus .

cd ../../docker/
docker-compose down
docker-compose -f docker-compose.yml up -d

```

![image 3](https://github.com/Otus-DevOps-2021-05/IvanPrivalov_microservices/blob/monitoring-1/monitoring/Screenshot_6.png)

# Удалим ресурсы:

```shell

docker-compose down
yc compute instance delete docker-host

```

</details>

## Устройство GitLab CI. Построение процесса непрерывной поставки.

<details>
  <summary>Решение</summary>

1. Создал инстанс для gitlab через Web-консоль Yandex Cloud.

```shell

yc compute instance create \
  --name gitlab-ci-vm \
  --zone ru-central1-a \
  --network-interface subnet-name=otus-ru-central1-a,nat-ip-version=ipv4 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1804-lts,size=50 \
  --memory 4GB \
  --ssh-key ~/.ssh/id_rsa.pub

```

2. Установим docker и docker-compose

```shell

cd gitlab-ci/ansible/
ansible-playbook docker_playbook.yml

```

3. Установка GitLab-CE. Подключимся к хосту и создадим необходимые каталоги:

```shell

ssh yc-user@62.84.113.255
sudo mkdir -p /srv/gitlab/config /srv/gitlab/data /srv/gitlab/logs
cd /srv/gitlab
sudo touch docker-compose.yml

```

sudo vim docker-compose.yml

```shell

web:
  image: 'gitlab/gitlab-ce:latest'
  restart: always
  hostname: 'localhost'
  environment:
    GITLAB_OMNIBUS_CONFIG:
      external_url 'http://62.84.113.255'
  ports:
    - '80:80'
    - '443:443'
    - '2222:22'
  volumes:
    - '/srv/gitlab/config:/etc/gitlab'
    - '/srv/gitlab/logs:/var/log/gitlab'
    - '/srv/gitlab/data:/var/opt/gitlab'

```

4. Запустим gitlab через docker-compose:

```shell

sudo docker-compose up -d

```

проверим доступность: http://62.84.113.255

5. Для выполнения push с локального хоста в gitlab добавил remote:

```shell

git remote add gitlab http://62.84.113.255/homework/example.git
git push gitlab gitlab-ci-1

```

6. Создание раннеров. Добавил раннер на инстансе:

```shell

ssh yc-user@62.84.113.255

docker run -d --name gitlab-runner --restart always -v /srv/gitlabrunner/config:/etc/gitlab-runner -v /var/run/docker.sock:/var/run/docker.sock gitlab/gitlab-runner:latest

```

7. Регистрация раннера (указываем url сервера gitlab и токен из Settings -> CI/CD -> Pipelines -> Runners ):

```shell

docker exec -it gitlab-runner gitlab-runner register \
--url http://62.84.113.255/ \
--non-interactive \
--locked=false \
--name DockerRunner \
--executor docker \
--docker-image alpine:latest \
--registration-token gYhPxcY9s5pBQyr6MGYp \
--tag-list "linux,xenial,ubuntu,docker" \
--run-untagged

```

8. Если все успешно, то должен появится новый ранер в Settings -> CI/CD -> Pipelines -> Runners секция Available specific runners и после появления ранера должен выполнится пайплайн.

![image 1](https://github.com/Otus-DevOps-2021-05/IvanPrivalov_microservices/blob/gitlab-ci-1/gitlab-ci/Screenshot_1.png)

9. Добавление Reddit в проект:

```shell

git clone https://github.com/express42/reddit.git && rm -rf ./reddit/.git
git add reddit/
git commit -m "Add reddit app"
git push gitlab gitlab-ci-1

```

10. Добавил файл simpletest.rb с тестами в каталог reddit:

```shell

require_relative './app'
require 'test/unit'
require 'rack/test'

set :environment, :test

class MyAppTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_get_request
    get '/'
    assert last_response.ok?
  end
end

```

11. Добавим библиотеку rack-test в reddit/Gemfile:

```shell

gem 'rack-test'

```

12. Запушим код в GitLab и убедимся, что test_unit_job гоняет тесты.

![image 2](https://github.com/Otus-DevOps-2021-05/IvanPrivalov_microservices/blob/gitlab-ci-1/gitlab-ci/Screenshot_2.png)

13. Добавим в .gitlab-ci.yml новые окружения и условия запусков для ранеров:

```shell

image: ruby:2.4.2

stages:
  - build
  - test
  - review
  - stage
  - production

variables:
  DATABASE_URL: 'mongodb://mongo/user_posts'

before_script:
  - cd reddit
  - bundle install

build_job:
  stage: build
  script:
    - echo 'Building'

test_unit_job:
  stage: test
  services:
    - mongo:latest
  script:
    - ruby simpletest.rb

test_integration_job:
  stage: test
  script:
    - echo 'Testing 2'

deploy_dev_job:
  stage: review
  script:
    - echo 'Deploy'
  environment:
    name: dev
    url: http://dev.example.com

branch review:
  stage: review
  script: echo "Deploy to $CI_ENVIRONMENT_SLUG"
  environment:
    name: branch/$CI_COMMIT_REF_NAME
    url: http://$CI_ENVIRONMENT_SLUG.example.com
  only:
    - branches
  except:
    - master

staging:
  stage: stage
  when: manual
  only:
    - /^\d+\.\d+\.\d+/
  script:
    - echo 'Deploy'
  environment:
    name: stage
    url: http://beta.example.com

production:
  stage: production
  when: manual
  only:
    - /^\d+\.\d+\.\d+/
  script:
    - echo 'Deploy'
  environment:
    name: production
    url: http://example.com

```

14. Для проверки закоммитим файлы с указанием тэга (версии) и запушим в gitlab:

```shell

git add .
git commit -m 'Test ver 2.4.10'
git tag 2.4.10
git push gitlab gitlab-ci-1 --tags

```

![image 3](https://github.com/Otus-DevOps-2021-05/IvanPrivalov_microservices/blob/gitlab-ci-1/gitlab-ci/Screenshot_3.png)

Stage и Production окружения запускаются вручную

</details>

## Docker - 4: сети, docker-compose

<details>
  <summary>Решение</summary>

- Работа с сетями в Docker
- Использование docker-compose
____

### None netwok driver

Внутри контейнера из сетевых интерфейсов существует только loopback. Сетевой стек работает для localhost без возможности контактировать с внешним миром. Подходит для запуска сетевых сервисов внутри контейнера для локальных экспериментов.

Проверка:

```shell

docker run -ti --rm --network none joffotron/docker-net-tools -c ifconfig

lo        Link encap:Local Loopback
          inet addr:127.0.0.1  Mask:255.0.0.0
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)

```

### Host netwok driver

Контейнер использует network namespace (пространство имен) docker-хоста.
Сетевые интерфейсы хоста и контейнера одинаковые.

Проверил сетевые интерфейсы на докер-хосте:

```shell

docker-machine ssh docker-host ifconfig

```

Сравнил интерфейсы в контейнере - они идентичны:

```shell

docker run -ti --rm --network host joffotron/docker-net-tools -c ifconfig

```

### Network namespaces

Network namespaces (простанство имен сетей) обеспечивает изоляюцию сетей в контейнерах.
Проверил создание network namespaces на docker-хосте:

```shell

# Подключился к docker-хосту
docker-machine ssh docker-host

# создал симлинк
sudo ln -s /var/run/docker/netns /var/run/netns

# запустил контейнер в сети none
docker run -ti --rm --network none joffotron/docker-net-tools -c ifconfig

# Проверил network namespaces:
sudo ip netns
# в сети "none" создается свой net-namespace (даже для loopback-интерфейса)
Error: Peer netns reference is invalid.
Error: Peer netns reference is invalid.
cd4afab32317
default

# запустил контейнер в сети "host"
docker run -ti --rm --network host joffotron/docker-net-tools -c ifconfig
# Проверил network namespaces:
sudo ip netns
# в сети host net-namespace не создается (есть только default)
default

```

Попробовал запустить несколько контейнеров с nginx в сети host:

```shell

# Запустил контейнер c nginx
docker run --network host -d nginx  # 4 раза

# проверил запуск
docker ps

CONTAINER ID   IMAGE                    COMMAND                  CREATED          STATUS          PORTS      NAMES
d4e96052caeb   nginx                    "/docker-entrypoint.…"   11 seconds ago   Up 10 seconds              musing_payne


# Вывод: запущен только один контейнер, остальные были остановлены.
# Это связано с тем, что сеть в запускаемых контейнерах, использующих host-драйвер не изолирована.
# Несколько контейнеров c nginx не могут делить одну хостовую сеть (может работать 1 контейнер).

```

### Bridge network driver

- Контейнеры могут взаимодействовать между собой (если они в одной подсети)
- Выходят в интернет через NAT (через интерфейс хоста).
- По-умолчанию создается сеть default-bridge, но она менее функциональна (лучше использовать обычную bridge).

1. Запустил контейнеры и подключил их к подсетям:

```shell

docker kill $(docker ps -q)

# Создадим 2 docker-сети
docker network create back_net --subnet=10.0.2.0/24
docker network create front_net --subnet=10.0.1.0/24

# Запустим контейнеры с алиасами в
docker run -d --network=front_net -p 9292:9292 --name ui  privalovip/ui:1.0
docker run -d --network=back_net --name comment  privalovip/comment:1.0
docker run -d --network=back_net --name post  privalovip/post:1.0
docker run -d --network=back_net --name mongo_db --network-alias=post_db --network-alias=comment_db mongo:latest

# Подключим контейнеры post и comment также к сети front_net
docker network connect front_net post
docker network connect front_net comment

```

2. Исследовал bridge-сеть:

```shell

# Подключился к docker-хосту
docker-machine ssh docker-host
sudo apt-get update && sudo apt-get install bridge-utils

# Проверил bridge-интерфейсы
sudo docker network ls
sudo ifconfig | grep br
br-49b82943d0ae: flags=4099<UP,BROADCAST,MULTICAST>  mtu 1500
        inet 172.18.0.1  netmask 255.255.0.0  broadcast 172.18.255.255
br-752e7d286760: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.0.2.1  netmask 255.255.255.0  broadcast 10.0.2.255
br-7cd0030ce977: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.0.1.1  netmask 255.255.255.0  broadcast 10.0.1.255
        inet 172.17.0.1  netmask 255.255.0.0  broadcast 172.17.255.255
        inet 10.128.0.25  netmask 255.255.255.0  broadcast 10.128.0.255

# Проверил использование NAT контейнерами в iptables:
sudo iptables -nL -t nat

...
Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination
MASQUERADE  all  --  10.0.1.0/24          0.0.0.0/0
MASQUERADE  all  --  10.0.2.0/24          0.0.0.0/0
MASQUERADE  all  --  172.18.0.0/16        0.0.0.0/0
MASQUERADE  all  --  172.17.0.0/16        0.0.0.0/0
MASQUERADE  tcp  --  10.0.1.2             10.0.1.2             tcp dpt:9292
...

# Здесь же видим правило DNAT, отвечающее за перенаправление трафика на адреса конкретных контейнеров
DNAT       tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:9292 to:10.0.1.2:9292

```

## docker-compose

1. Установил последнюю версию docker-compose

2. Описал в docker-compose.yml сборку контейнеров с сетями, алиасами (параметризировал с помощью переменных окружений):

docker-compose.yml

```shell

version: '3.3'

services:

  post_db:
    env_file: .env
    image: mongo:${MONGODB_VERSION}
    volumes:
      - post_db:/data/db
    networks:
      back_net:
        aliases:
          - post_db
          - comment_db

  ui:
    env_file: .env
    build: ./ui
    image: ${USERNAME}/ui:${UI_VERSION}
    ports:
      - ${UI_HOST_PORT}:${UI_CONTAINER_PORT}/tcp
    networks:
      - front_net

  post:
    env_file: .env
    build: ./post-py
    image: ${USERNAME}/post:${POST_VERSION}
    networks:
      - front_net
      - back_net

  comment:
    env_file: .env
    build: ./comment
    image: ${USERNAME}/comment:${COMMENT_VERSION}
    networks:
      - front_net
      - back_net

volumes:
  post_db:

networks:

  front_net:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: ${FRONT_NET_SUBNET}

  back_net:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: ${BACK_NET_SUBNET}

```

В файле .env хранятся значения переменных (вызывается при запуске docker-compose), он скрыт, для запуска воспользуйтесь шаблоном .env.example:

```shell

# порт публикации приложения
UI_HOST_PORT=9292
UI_CONTAINER_PORT=9292

# автор сборки
USERNAME="Ivan"

# версии образов
MONGODB_VERSION=3.2
UI_VERSION=1.0
POST_VERSION=1.0
COMMENT_VERSION=1.0

# подсети
FRONT_NET_SUBNET=10.0.1.0/24
BACK_NET_SUBNET=10.0.2.0/24

```

Запустить приложение:

```shell

docker kill $(docker ps -q) # остановим старые контейнеры docker
docker-compose up -d

```

Проверка:

```shell

docker-compose ps

    Name                  Command             State                    Ports
----------------------------------------------------------------------------------------------
src_comment_1   puma                          Up
src_post_1      python3 post_app.py           Up
src_post_db_1   docker-entrypoint.sh mongod   Up      27017/tcp
src_ui_1        puma                          Up      0.0.0.0:9292->9292/tcp,:::9292->9292/tcp

```

Альтернативный способ запуска:
используем ключ --env-file с указанием пути к файлу .env:

```shell

# удалим из docker-compose.yml строчки "env_file: .env"
docker-compose --env-file .env up -d

```

Приложение доступно по адресу: http://178.154.223.190:9292/

### Изменение базового имени проекта

По-умолчанию имя проекта (префикс) создается из имени каталога, в котором находится проект (в нашем случае src).

Использовать при запуске ключ -p, --project-name NAME, пример:

```shell

docker-compose --project-name reddit up -d

```

### Задание со *

Создайте docker-compose.override.yml для reddit проекта, который позволит:
- Изменять код каждого из приложений, не выполняя сборку образа;
- Запускать puma для ruby приложений в дебаг режиме с двумя воркерами (флаги --debug и -w 2).

Решение

Docker Compose по умолчанию по-очереди читает два файла: docker-compose.yml и docker-compose.override.yml.
В последнем можно хранить переопределения для существующих сервисов или определять новые.

docker-compose.override.yml

```shell

version: '3.3'
services:

  ui:
    env_file: .env
    volumes:
      - ./ui:/app
    command: ["puma", "--debug", "-w", "2"]

  post:
    env_file: .env
    volumes:
      - ./post-py:/app

  comment:
    env_file: .env
    volumes:
      - ./comment:/app
    command: ["puma", "--debug", "-w", "2"]

```

Задан bind mount:

<путь к каталогу приложения на локальном хосте (папка с исходниками проекта)>:<путь к каталогу приложения в контейнере>

Поскольку монтируются папки локального хоста, проверим приложение локально.
Иначе придется копировать файлы проекта на удаленный docker-хост.

Проверяем, что воркеры запущены:

```shell

eval $(docker-machine env --unset) # переключиться на локальный docker
docker-machine ls
docker-compose down # остановить и удалить контейнеры
docker-compose up -d # запустить контейнеры
docker-compose config # проверить конфиг
docker-compose ps
   Name                  Command             State           Ports
----------------------------------------------------------------------------
src_comment_1   puma --debug -w 2             Up
src_post_1      python3 post_app.py           Up
src_post_db_1   docker-entrypoint.sh mongod   Up      27017/tcp
src_ui_1        puma --debug -w 2             Up      0.0.0.0:9292->9292/tcp

```

Проверяем, что можем изменять файлы проекта, не производя билд образа.
На локальном хосте:

```shell

cd src/ui # переходим в каталог приложения ui
touch newfile # создадим новый файл
ls
config.ru        Dockerfile    Gemfile       helpers.rb     newfile  VERSION
docker_build.sh  Dockerfile.1  Gemfile.lock  middleware.rb  ui_app.rb    views

```

Проверяем, что файл отображается в папке приложения в контейнере:

```shell

docker-compose exec ui ls ../app
Dockerfile    Gemfile.lock  docker_build.sh  newfile
Dockerfile.1  VERSION       helpers.rb       ui_app.rb
Gemfile       config.ru     middleware.rb    views

```

Приложение доступно по адресу: http://localhost:9292

</details>

## Docker - 3

<details>
  <summary>Решение</summary>

- описываем и собираем Docker-образ для сервисного приложения;
- оптимизируем Docker-образы;
- запускаем приложение из собранного Docker-образа;

## В ДЗ сделано:
____

1. Скопировал файлы приложения в папку src. Оно разбито на несколько компонентов:

post-py - сервис отвечающий за написание постов;
comment - сервис отвечающий за написание комментариев;
ui - веб-интерфейс, работающий с другими сервисами;

2. Создал Docker-файлы для подготовки образов. Инструкцию ADD заменил на COPY (рекомендовано), заменил образ на python:3.6.14-alpine.

./post-py/Dockerfile

```shell

FROM python:3.6.14-alpine

WORKDIR /app
COPY . /app

RUN apk --no-cache --update add build-base && \
    pip install -r /app/requirements.txt && \
    apk del build-base

ENV POST_DATABASE_HOST post_db
ENV POST_DATABASE posts

ENTRYPOINT ["python3", "post_app.py"]

```

./comment/Dockerfile

```shell
FROM ruby:2.2

RUN apt-get update -qq && apt-get install -y build-essential

ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

COPY Gemfile* $APP_HOME/
RUN bundle install
COPY . $APP_HOME

ENV COMMENT_DATABASE_HOST comment_db
ENV COMMENT_DATABASE comments

CMD ["puma"]
```

./ui/Dockerfile (1-й вариант сборки)

```shell

FROM ruby:2.2
RUN apt-get update -qq && apt-get install -y build-essential

ENV APP_HOME /app
RUN mkdir $APP_HOME

WORKDIR $APP_HOME
ADD Gemfile* $APP_HOME/
RUN bundle install
ADD . $APP_HOME

ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292

CMD ["puma"]

```

3. Подключился к ранее созданному хосту с docker "docker-host" в Yandex Cloud:

```shell

eval $(docker-machine env docker-host) # переходим в окружение "docker-host"
docker-machine ls # проверяем, что хост зарегистрирован и активен
docker rm -f $(docker ps -q) # удалим старые запущенные контейнеры

```

4. Собрал образы с нашими сервисами и скачал готовый образ MongoDB (БД используют сервисы comment и post):

```shell

docker build -t privalovip/post:1.0 ./post-py
docker build -t privalovip/comment:1.0 ./comment
docker build -t privalovip/ui:1.0 ./ui
docker pull mongo:latest

# проверяем создание образов
docker images

```

5. Создал bridge-сеть для контейнеров reddit, т.к. сетевые алиасы не работают в дефолтной сети. Затем запустил контейнеры.

```shell

# создаем сеть
docker network create reddit
docker network ls # проверяем создание сети

# запускаем контейнеры с алиасами
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db mongo:latest
docker run -d --network=reddit --network-alias=post privalovip/post:1.0
docker run -d --network=reddit --network-alias=comment privalovip/comment:1.0
docker run -d --network=reddit -p 9292:9292 privalovip/ui:1.0

# проверяем запуск контейнеров
docker ps

```

Проверяем, что приложение доступно по ссылке http://<Публичный IP "docker-host">:9292

6. Пересоздал Dockerfile для ui с новыми инструкциями:

./ui/Dockerfile (2-й вариант сборки)

```shell

FROM ubuntu:16.04
RUN apt-get update \
    && apt-get install -y ruby-full ruby-dev build-essential \
    && gem install bundler --no-ri --no-rdoc

ENV APP_HOME /app
RUN mkdir $APP_HOME

WORKDIR $APP_HOME
ADD Gemfile* $APP_HOME/
RUN bundle install
ADD . $APP_HOME

ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292

CMD ["puma"]

```

7. Собрал образ ui:2.0, запустил новые копии контейнеров c ui:2.0 вместо ui:1.0

```shell

docker build -t privalovip/ui:2.0 ./ui

docker kill $(docker ps -q) # останавливаем контейнеры

docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db mongo:latest
docker run -d --network=reddit --network-alias=post privalovip/post:1.0
docker run -d --network=reddit --network-alias=comment privalovip/comment:1.0
docker run -d --network=reddit -p 9292:9292 privalovip/ui:2.0

```

Проверяем, что приложение доступно по ссылке http://<Публичный IP "docker-host">:9292
Поскольку контейнер с mongodb был остановлен и пересоздан, комментарии не сохранились.

8. Создал docker volume c именем reddit_db, подключил его к контейнеру с MongoDB, затем запустил новые копии контейнеров:

```shell

# создать volume
docker volume create reddit_db

docker kill $(docker ps -q) # остановим все запущенные контейнеры

docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db -v reddit_db:/data/db mongo:latest
docker run -d --network=reddit --network-alias=post privalovip/post:1.0
docker run -d --network=reddit --network-alias=comment privalovip/comment:1.0
docker run -d --network=reddit -p 9292:9292 privalovip/ui:2.0

```

Проверка: перейдем по ссылке http://<Публичный IP "docker-host">:9292 и добавим пост.
После этого перезапустим копии контейнеров. Посты приложения будут сохранены, т.к. данные БД хранятся на томе.

## Задание со *
____

### Задание 1
____

- Запустите контейнеры с другими сетевыми алиасами
- Адреса для взаимодействия контейнеров задаются через ENV-переменные внутри Dockerfile'ов
- При запуске контейнеров (docker run) задайте им переменные окружения соответствующие новым сетевым алиасам, не пересоздавая образ
- Проверьте работоспособность сервиса

Решение

Добавил ко всем используемым ранее алиасам название reddit_. При изменении сетевых алиасов мы должны переопределить и ENV-переменные Dockerfile с помощью ключа --env, поскольку они отвечают за сетевое взаимодействие контейнеров между собой.

```shell

docker kill $(docker ps -q) # останавливаем контейнеры

docker run -d --network=reddit --network-alias=reddit_post_db --network-alias=reddit_comment_db mongo:latest
docker run -d --network=reddit --network-alias=reddit_post --env POST_DATABASE_HOST=reddit_post_db privalovip/post:1.0
docker run -d --network=reddit --network-alias=reddit_comment --env COMMENT_DATABASE_HOST=reddit_comment_db  privalovip/comment:1.0
docker run -d --network=reddit -p 9292:9292 --env POST_SERVICE_HOST=reddit_post --env COMMENT_SERVICE_HOST=reddit_comment privalovip/ui:1.0

```

### Задание 2
____

- Соберите образ на основе Alpine Linux
- Придумайте еще способы уменьшить размер образа

Решение

Создал Dockerfile_v1 для сервиса ui. Оптимизация размера образа выполняется за cчет опции установки пакетов --no-cache и удаления кэша rm -rf /var/cache/apk/* (если что-то осталось).

```shell

FROM alpine:3.12.4

LABEL Name="Reddit App UI for Alpine"
LABEL Version="1.0"

RUN apk --update add --no-cache \
    ruby-full \
    ruby-dev \
    build-base \
    && gem install bundler:1.17.2 --no-document \
    && rm -rf /var/cache/apk/*

ENV APP_HOME /app
RUN mkdir $APP_HOME

WORKDIR $APP_HOME
COPY Gemfile* $APP_HOME/
RUN bundle install
COPY . $APP_HOME

ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292

CMD ["puma"]

```

Создать образ alpine_ui:1.0 и запустить копии контейнеров, включая alpine_ui:1.0:

```shell

docker build -f ./ui/Dockerfile_v1 -t privalovip/alpine_ui:1.0 ./ui

docker kill $(docker ps -q) # останавливаем контейнеры
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db -v reddit_db:/data/db mongo:latest
docker run -d --network=reddit --network-alias=post privalovip/post:1.0
docker run -d --network=reddit --network-alias=comment privalovip/comment:1.0
docker run -d --network=reddit -p 9292:9292 privalovip/alpine_ui:1.0

```

Проверка

```shell

REPOSITORY             TAG             IMAGE ID       CREATED             SIZE
privalovip/alpine_ui   1.0             74f1ddbbde8f   25 seconds ago      275MB
privalovip/post        1.0             4eb4b9a693cb   41 minutes ago      62MB
privalovip/ui          2.0             546d27a6a4bf   About an hour ago   462MB
privalovip/ui          1.0             b30d50501878   2 hours ago         771MB
privalovip/comment     1.0             8af1dce17979   2 hours ago         769MB

```

```shell

CONTAINER ID   IMAGE                      COMMAND                  CREATED             STATUS             PORTS                                       NAMES
44e8c08df157   privalovip/alpine_ui:1.0   "puma"                   About an hour ago   Up About an hour   0.0.0.0:9292->9292/tcp, :::9292->9292/tcp   priceless_sanderson
af6522b705f3   privalovip/comment:1.0     "puma"                   About an hour ago   Up About an hour                                               relaxed_mclean
fb859ce405c8   privalovip/post:1.0        "python3 post_app.py"    About an hour ago   Up About an hour                                               adoring_maxwell
934b3fcabb66   mongo:latest               "docker-entrypoint.s…"   About an hour ago   Up About an hour   27017/tcp                                   trusting_hertz

```

Проверяем, что приложение доступно по ссылке: http://<Публичный IP "docker-host">:9292
В моем случае: http://178.154.223.190:9292/

</details>

## Docker - 2

<details>
  <summary>Решение</summary>

1. Установил последние версии docker, docker-compose, docker-machine

2. Запустил тестовый контейнер, на основе коммита создал образ otus/ubuntu-tmp-file. Вывод команды docker images записал в файл docker-monolith/docker-1.log. Тамже описал отличие между контейнером и образом на основе вывода комманд:

```shell

 docker inspect <u_container_id>
 docker inspect <u_image_id>

```

3. В Yandex Cloud получил токен и проинициализировал папку Default:

```shell

yc init
...

```

4. В Yandex Cloud создал новый инстанс для docker из образа ubuntu-1804-lts:

```shell

yc compute instance create \
  --name docker-host \
  --zone ru-central1-a \
  --network-interface subnet-name=otus-ru-central1-a,nat-ip-version=ipv4 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1804-lts,size=15 \
  --ssh-key ~/.ssh/id_rsa.pub

```

5. Затем с помощью docker-machine проинициализировал на нем docker, указав публичный IP инстанса. Docker-machine позволяет создать хост c docker-engine и управлять им на локальной или облачной ВМ. В нашем случае мы инициализируем окружение docker на уже созданном инстансе Yandex Cloud.

```shell

docker-machine create \
  --driver generic \
  --generic-ip-address=193.32.218.173 \
  --generic-ssh-user yc-user \
  --generic-ssh-key ~/.ssh/id_rsa \
  docker-host

docker-machine env docker-host
eval $(docker-machine env docker-host)  # переключиться для управления хостом "docker-host" в окружении Yandex Cloud

```

6. Использование docker-machine

```shell

docker-machine --help  # справка
docker-machine create ...  # создать машину с docker

docker-machine ls  # отобразить список зарегистрированных машин с docker
root@otus-VirtualBox:~# docker-machine ls
NAME          ACTIVE   DRIVER    STATE     URL                         SWARM   DOCKER     ERRORS
docker-host   -        generic   Running   tcp://193.32.218.173:2376           v20.10.8

docker-machine <имя машины> status  # проверить состояние машины с docker
docker-machine <имя машины> rm  # удалить машину с docker

eval $(docker-machine env --unset)  # выйти из окружения docker-machine
eval $(docker-machine env <имя машины>)  # переключиться к окружению docker-machine с именем <имя машины>

```

7. Создал Dockerfile c файлами mongod.conf, start.sh, db_config.

Dockerfile:

```shell

FROM ubuntu:18.04

RUN apt-get update
RUN apt-get install -y mongodb-server ruby-full ruby-dev build-essential git ruby-bundler
#RUN gem install bundler
RUN git clone -b monolith https://github.com/express42/reddit.git

COPY mongod.conf /etc/mongod.conf
COPY db_config /reddit/db_config
COPY start.sh /start.sh

RUN cd /reddit && rm Gemfile.lock && bundle install
RUN chmod 0777 /start.sh

CMD ["/start.sh"]

```

8. Собрал образ и запустил контейнер в Yandex Cloud:

```shell

eval $(docker-machine env docker-host)
docker build -t reddit:latest .
docker images -a
docker run --name reddit -d --network=host reddit:latest

```

Проверяем запуск приложения по ссылке: http://<публичный IP>:9292

9. Загрузил образ reddit:latest в docker-hub с названием otus-reddit:1.0:

```shell

docker login  # авторизуемся в docker-hub
docker tag reddit:latest privalovip/otus-reddit:1.0
docker push privalovip/otus-reddit:1.0

```

10. Запустил контейнер из образа в docker-hub на локальном хосте:

```shell

# В отдельной консоли
eval $(docker-machine env --unset) # выходим из окружения docker-machine
docker ps -a  # убедимся, что мы в локальном окружении
docker run --name reddit -d -p 9292:9292 privalovip/otus-reddit:1.0 # запускаем контейнер

```

Проверяем запуск приложения по ссылке: http://localhost:9292

## Задание со *
____

Автоматизируем установку нескольких инстансов docker и запуск в них контейнера с нашим приложением из docker-образа с помощью Packer, Terraform и Ansible.

Требования:

- Нужно реализовать в виде прототипа в директории /docker-monolith/infra
- Поднятие инстансов с помощью Terraform, их количество задается переменной;
- Несколько плейбуков Ansible с использованием динамического инвентори для установки докера и запуска там образа приложения;
- Шаблон пакера, который делает образ с уже установленным Docker.

### Выполнение

1. Создал шаблон Packer для запекания образа в облаке:

docker.json

```shell

{
    "variables": {
           "zone": "ru-central1-a",
           "instance_cores": "2"
       },
    "builders": [
       {
           "type": "yandex",
           "service_account_key_file": "{{user `service_account_key_file`}}",
           "folder_id": "{{user `folder_id`}}",
           "source_image_family": "{{user `source_image_family`}}",
           "image_name": "docker-host-{{timestamp}}",
           "image_family": "ubuntu-docker-host",
           "ssh_username": "ubuntu",
           "platform_id": "standard-v1",
           "zone": "{{user `zone`}}",
           "instance_cores": "{{user `instance_cores`}}",
       "use_ipv4_nat" : "true"
       }
   ],
   "provisioners": [
       {
           "type": "ansible",
           "user": "ubuntu",
           "playbook_file": "{{ pwd }}/ansible/playbooks/install_docker.yml"
       }
   ]
}

```

При создании образа выполняется установка docker c помощью ansible-плейбука:

install_docker.yml

```shell

---
    - hosts: all
      become: true

      tasks:
        - name: Install aptitude using apt
          apt: name=aptitude state=latest update_cache=yes force_apt_get=yes

        - name: Install required system packages
          apt: name={{ item }} state=latest update_cache=yes
          loop: [ 'apt-transport-https', 'ca-certificates', 'curl', 'software-properties-common', 'python3-pip', 'virtualenv', 'python3-setuptools']

        - name: Add Docker GPG apt Key
          apt_key:
            url: https://download.docker.com/linux/ubuntu/gpg
            state: present

        - name: Add Docker Repository
          apt_repository:
            repo: deb https://download.docker.com/linux/ubuntu bionic stable
            state: present

        - name: Update apt and install docker-ce
          apt: update_cache=yes name=docker-ce state=latest

        - name: Install Docker Module for Python
          pip:
            name: docker

```

2. Запустил сборку образа:

```shell

cd docker-monolith/infra
packer validate -var-file=packer/variables.json packer/docker.json
packer build -var-file=packer/variables.json packer/docker.json

```

3. Создал шаблон terraform для развертывания инстансов с docker в облаке из образа packer:

main.yml

```shell

 terraform {
   required_providers {
     yandex = {
       source = "yandex-cloud/yandex"
       version = "0.60.0"
     }
   }
 }

provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}

resource "yandex_compute_instance" "vm-app" {
  count = var.count_instance
  name = "reddit-app-${count.index}"  # назначаем имена инстансам с порядковыми номерами
  zone = var.zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
    }
  }

  network_interface {
    # Указан id подсети default-ru-central1-a
    subnet_id = var.subnet_id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }

}

  # Cоздаем для ansible динамический файл инвентори ../ansible/inventory.ini c ip-адресами инстансов.
  # Генерация происходит на основе шаблона templates/inventory.tpl.
  resource "local_file" "inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl",
    {
      docker_hosts = yandex_compute_instance.vm-app.*.network_interface.0.nat_ip_address
    }
  )
  filename = "../ansible/inventory.ini"

}

```

Количество создаваемых инстансов задаем через переменную в terraform.tfvars:

```shell

variable count_instance {
  # кол-во создаваемых инстансов
  default = "2"
}

```

В процессе выполнения terraform генерирует динамический файл инвентори ../ansible/inventory.ini с IP-адресами инстансов.
Пример:

```shell

[docker_hosts]
178.154.223.217
178.154.222.205

```

Сам файл инвентори создается из шаблона templates/inventory.tpl:

```shell

[docker_hosts]
%{ for ip in docker_hosts ~}
${ip}
%{ endfor ~}

```

4. Создал инстансы через terraform:

```shell

cd docker-monolith/infra/terraform
terraform init # переинициализируем
terraform plan
terraform apply

```

5. Создал ansible-плейбук, который делает пулл загруженного ранее образа из docker-hub и запускает контейнер с нашим приложением.

run_app_in_docker.yml

```shell

---
    - hosts: all
      become: true

      vars:
        default_container_name: reddit
        default_container_image: privalovip/otus-reddit:1.0

      tasks:

        - name: Pull Docker image
          docker_image:
            name: "{{ default_container_image }}"
            source: pull

        - name: Create container
          docker_container:
            name: "{{ default_container_name }}"
            image: "{{ default_container_image }}"
            state: started
            ports:
              - "9292:9292"
          # restart: yes

        - name: Check list of runned containers
          command: docker ps
          register: cont_list

        - debug: msg="{{ cont_list.stdout }}"

```

Запуск плейбука:

```shell

cd docker-monolith/infra/ansible
ansible-playbook playbooks/run_app_in_docker.yml

```

Проверка:

```shell

TASK [debug] *****************************************************************************************************************************************
ok: [178.154.223.217] => {
    "msg": "CONTAINER ID   IMAGE                        COMMAND       CREATED         STATUS         PORTS                    NAMES\n66c7da5dee66   privalovip/otus-reddit:1.0   \"/start.sh\"   5 seconds ago   Up 3 seconds   0.0.0.0:9292->9292/tcp   reddit"
}
ok: [178.154.222.205] => {
    "msg": "CONTAINER ID   IMAGE                        COMMAND       CREATED         STATUS         PORTS                    NAMES\nb7284477bd86   privalovip/otus-reddit:1.0   \"/start.sh\"   5 seconds ago   Up 3 seconds   0.0.0.0:9292->9292/tcp   reddit"
}

PLAY RECAP *******************************************************************************************************************************************
178.154.222.205            : ok=5    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
178.154.223.217            : ok=5    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

```

Проверяем запуск приложения на каждом инстансе по ссылке:
http://<Публичный IP>:9292 (актуальные ip-адреса для проверки находятся в inventory.ini)

</details>
