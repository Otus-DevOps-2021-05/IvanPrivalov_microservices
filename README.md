# IvanPrivalov_microservices
IvanPrivalov microservices repository

# Домашнее задание №15
____

## Устройство GitLab CI. Построение процесса непрерывной поставки.

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


# Домашнее задание №14
____

## Docker: сети, docker-compose

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
