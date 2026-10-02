import assert from "node:assert/strict";
import test from "node:test";
import { markDemoDates, refreshDemoDates } from "../app/demo-dates.ts";

const old = [{ id: "sample", deadline: "2026-10-03", plannedDate: "2026-10-02" }];
const fresh = [{ id: "sample", deadline: "2026-11-04", plannedDate: "2026-11-03" }];

test("sample dates follow the current opening day without resetting progress", () => {
  const saved = markDemoDates(old).map(task => ({ ...task, progress: 75 }));
  assert.deepEqual(refreshDemoDates(saved, fresh)[0], {
    ...fresh[0], progress: 75, demoDates: { deadline: fresh[0].deadline, plannedDate: fresh[0].plannedDate },
  });
});

test("manual dates and user-created tasks are preserved", () => {
  const saved = markDemoDates(old).map(task => ({ ...task, deadline: "2026-12-20" }));
  const result = refreshDemoDates(saved, fresh)[0];
  assert.equal(result.deadline, "2026-12-20");
  assert.equal(result.plannedDate, fresh[0].plannedDate);
  const custom = { id: "custom", deadline: "2026-01-01" };
  assert.deepEqual(refreshDemoDates([custom], fresh), [custom]);
});

test("legacy sample cohort migrates while individually changed dates remain", () => {
  const saved = [...old, { id: "second", deadline: "2026-10-10", plannedDate: "2026-12-20" }];
  const templates = [...fresh, { id: "second", deadline: "2026-11-11", plannedDate: "2026-11-05" }];
  const result = refreshDemoDates(saved, templates);
  assert.equal(result[0].deadline, fresh[0].deadline);
  assert.equal(result[1].deadline, "2026-11-11");
  assert.equal(result[1].plannedDate, "2026-12-20");
  assert.deepEqual(refreshDemoDates(result, templates), result);
});
