// k6 — найти максимальную ёмкость сервиса (break point test)
// Запуск: k6 run capacity-k6.js --env BASE_URL=http://localhost:8080

import http from 'k6/http';
import { check } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export const options = {
  // Ступенчатое увеличение нагрузки до break point
  stages: [
    { duration: '2m', target: 10 },
    { duration: '2m', target: 50 },
    { duration: '2m', target: 100 },
    { duration: '2m', target: 200 },
    { duration: '2m', target: 500 },
    { duration: '2m', target: 1000 },  // здесь обычно видно деградацию
    { duration: '2m', target: 0 },     // остывание
  ],
  thresholds: {
    // Алерт когда ломается — не fail test
    'http_req_duration{status:200}': [{ threshold: 'p95<1000', abortOnFail: false }],
    errors: [{ threshold: 'rate<0.1', abortOnFail: false }],
  },
};

export default function () {
  const res = http.get(`${BASE_URL}/api/data`, {
    timeout: '5s',
    tags: { name: 'GetData' },
  });

  const ok = check(res, {
    'status 200': (r) => r.status === 200,
    'latency < 500ms': (r) => r.timings.duration < 500,
  });

  errorRate.add(!ok);
}

// После теста смотреть:
// - При каком VU count начинает расти error rate?
// - При каком VU count p95 latency > 500ms?
// - Это и есть break point — максимальная ёмкость
