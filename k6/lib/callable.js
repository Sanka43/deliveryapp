// Thin wrapper around k6's http module that speaks the Firebase "callable
// function" protocol: POST {"data": ...}, Authorization: Bearer <idToken>,
// response {"result": ...} on success or {"error": {...}} on failure.
import http from 'k6/http';
import { check } from 'k6';
import { BASE_URL } from '../config.js';

/**
 * @param {string} name - deployed function name, e.g. "quoteRideFares"
 * @param {object} data - the callable's `data` payload
 * @param {string=} idToken - Firebase Auth ID token; omit for public callables
 * @param {(res: object, body: object) => Record<string, () => boolean>=} extraChecks
 */
export function callCallable(name, data, idToken, extraChecks) {
  const headers = { 'Content-Type': 'application/json' };
  if (idToken) {
    headers.Authorization = `Bearer ${idToken}`;
  }
  const res = http.post(`${BASE_URL}/${name}`, JSON.stringify({ data }), {
    headers,
    tags: { name },
  });

  let body = {};
  try {
    const parsed = JSON.parse(res.body);
    if (parsed && typeof parsed === 'object') {
      body = parsed;
    }
  } catch (e) {
    // non-JSON / empty response (e.g. a timeout or a cold-start HTML error
    // page) — body stays {}
  }

  const checks = {
    [`${name}: status 200`]: () => res.status === 200,
    [`${name}: no error`]: () => !body.error,
  };
  if (extraChecks) {
    Object.assign(checks, extraChecks(res, body));
  }
  check(res, checks);

  if (body.error) {
    console.error(`${name} error: ${JSON.stringify(body.error)}`);
  }

  return { res, result: body.result, error: body.error };
}
