import http from 'k6/http';
import { check, sleep } from 'k6';
import { FormData } from 'https://jslib.k6.io/formdata/0.0.2/index.js';

export let options = {
  stages: [
    { duration: '30s', target: 10 },
    { duration: '2m', target: 10 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
  },
};

let pdf = open('./sample.pdf', 'b');

const BASE_URL =
  'http://hummingbird-alb.elb.localhost.localstack.cloud:4566/v1';

export default function () {
  let formData = new FormData();
  formData.append('media', http.file(pdf, 'sample.pdf', 'application/pdf'));

  let uploadRes = http.post(`${BASE_URL}/media`, formData.body(), {
    headers: {
      'Content-Type': 'multipart/form-data; boundary=' + formData.boundary,
    },
  });

  check(uploadRes, {
    'upload succeeded': (r) => r.status === 202,
    'Response contains mediaId': (r) => r.json().mediaId !== undefined,
  });

  let mediaId = uploadRes.json('mediaId');

  sleep(2);

  let summaryBody = JSON.stringify({ style: 'detailed' });

  let summarizeRes = http.post(
    `${BASE_URL}/media/${mediaId}/summarize`,
    summaryBody,
    { headers: { 'Content-Type': 'application/json' } }
  );

  check(summarizeRes, {
    'Summarize trigger status is 202': (r) => r.status === 202,
  });

  let summaryRes;
  const maxAttempts = 10;
  let attempt = 0;
  let success = false;

  sleep(20);

  while (attempt < maxAttempts && !success) {
    summaryRes = http.get(`${BASE_URL}/media/${mediaId}/status`);
    if (summaryRes.json().status === 'SUMMARIZED') {
      success = true;
      break;
    }
    sleep(3);
    attempt++;
  }

  check(summaryRes, {
    'Status check succeeded': (r) => r.status === 200,
    'Media status is SUMMARIZED': (r) => r.json().status === 'SUMMARIZED',
  });

  sleep(1);
}
