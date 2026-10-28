FROM python:3.12-slim

RUN useradd --uid 10001 --create-home --shell /usr/sbin/nologin appuser

WORKDIR /app

COPY app/ ./

ENV PORT=5000
EXPOSE 5000

USER 10001:10001

CMD ["python", "app.py"]
