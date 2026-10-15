# Образ для упражнения 02: статический сайт через встроенный http.server.
FROM python:3.13-slim
WORKDIR /srv
COPY site/ /srv/
EXPOSE 8000
CMD ["python", "-m", "http.server", "8000"]
