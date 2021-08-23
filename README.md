# IvanPrivalov_microservices
IvanPrivalov microservices repository

# Домашнее задание №13
____

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

# Домашнее задание №12
____

## В ДЗ сделано:
____

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
