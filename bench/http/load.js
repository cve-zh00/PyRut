import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  stages: [{ duration: "20s", target: 50 }],
};

// http_reqs......................: 225178  11258.120375/s
//
//  iteration_duration.............: avg=886.41µs min=126.83µs med=891.25µs max=2.9ms  p(90)=1.48ms p(95)=1.56ms
const BASE_URL = "http://0.0.0.0:8000";

export default function () {
  // RUT válido para probar
  const rut = "21049615-7";

  const response = http.get(`${BASE_URL}/persona-c/${rut}`);

  check(response, {
    "status is 200": (r) => r.status === 200,
    "response time < 500ms": (r) => r.timings.duration < 500,
    "contains message": (r) => r.json("message") === "Hello World",
  });
}
