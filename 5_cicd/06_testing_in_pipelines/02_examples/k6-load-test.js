// k6 load test — нагрузочное тестирование API
// Запуск: k6 run k6-load-test.js
// В CI: k6 run --out json=results.json k6-load-test.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Кастомные метрики
const errorRate = new Rate('errors');
const apiLatency = new Trend('api_latency');
const requestCount = new Counter('requests');

// Конфигурация теста
export const options = {
  stages: [
    { duration: '1m', target: 10 },   // разогрев: 0 → 10 VU
    { duration: '3m', target: 10 },   // нагрузка: держать 10 VU
    { duration: '1m', target: 50 },   // нарастить до 50
    { duration: '3m', target: 50 },   // держать 50 VU
    { duration: '1m', target: 0 },    // охлаждение
  ],
  thresholds: {
    http_req_duration: ['p95<500'],    // 95% запросов < 500ms
    errors: ['rate<0.01'],             // ошибок < 1%
    http_req_failed: ['rate<0.01'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export default function () {
  // GET /api/users
  const listRes = http.get(`${BASE_URL}/api/users`, {
    headers: { 'Accept': 'application/json' },
    tags: { endpoint: 'list_users' },
  });

  check(listRes, {
    'status is 200': (r) => r.status === 200,
    'response time < 300ms': (r) => r.timings.duration < 300,
    'body is array': (r) => {
      try { return Array.isArray(JSON.parse(r.body)); } catch { return false; }
    },
  });

  errorRate.add(listRes.status !== 200);
  apiLatency.add(listRes.timings.duration);
  requestCount.add(1);

  sleep(1);

  // POST /api/users (только часть VU)
  if (Math.random() < 0.3) {
    const payload = JSON.stringify({
      name: `user-${Date.now()}`,
      email: `test-${Date.now()}@example.com`,
    });

    const createRes = http.post(`${BASE_URL}/api/users`, payload, {
      headers: { 'Content-Type': 'application/json' },
      tags: { endpoint: 'create_user' },
    });

    check(createRes, {
      'create: status 201': (r) => r.status === 201,
    });

    errorRate.add(createRes.status !== 201);
  }

  sleep(Math.random() * 2);
}

export function handleSummary(data) {
  return {
    'k6-summary.json': JSON.stringify(data, null, 2),
  };
}
