"""Ответ к упражнению 04: Flask-приложение с OpenTelemetry.

pip install flask opentelemetry-sdk opentelemetry-exporter-otlp \
    opentelemetry-instrumentation-flask
python app.py
curl http://localhost:5000/
Endpoint OTLP по умолчанию — http://localhost:4317 (gRPC, без TLS);
переопределяется переменной OTEL_EXPORTER_OTLP_ENDPOINT.
"""

import time

from flask import Flask
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import (
    OTLPSpanExporter,
)
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# service.name — под этим именем сервис появится в Jaeger
# (без него будет unknown_service)
provider = TracerProvider(resource=Resource.create({"service.name": "flask-demo"}))
provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)  # серверный span на каждый запрос


@app.route("/")
def index():
    with tracer.start_as_current_span("handle-index") as span:
        span.set_attribute("user.type", "anonymous")
        result = fetch_data()
        return f"Result: {result}\n"


def fetch_data():
    with tracer.start_as_current_span("fetch-data"):
        time.sleep(0.05)  # имитация запроса в БД
        return "ok"


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
