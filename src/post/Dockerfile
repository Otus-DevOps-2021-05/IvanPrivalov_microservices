# FROM python:3.6.0-alpine
FROM ubuntu:18.04

WORKDIR /app
COPY . /app

RUN apt update -y && apt install -y python3-pip
RUN pip3 install -r requirements.txt

# RUN apk --no-cache --update add build-base && \
#     pip install -r /app/requirements.txt && \
#     apk del build-base

ENV POST_DATABASE_HOST post_db
ENV POST_DATABASE posts

ENTRYPOINT ["python3", "post_app.py"]
