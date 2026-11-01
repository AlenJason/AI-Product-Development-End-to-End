import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DataSource } from 'typeorm';
import { dataSourceOptions } from '../../database/data-source-options.js';
import { FeedbackReceipt } from '../../database/entities/feedback-receipt.entity.js';
import {
  geminiOff,
  makeProfile,
  samplePlan,
} from '../../../test/plan-fixtures.js';
import { PlanService } from '../plan.service.js';
import { BodyState, Eating, Intensity } from '../enums/feedback.enum.js';
import type { FeedbackDto } from '../dto/adjust-plan.dto.js';
import { FeedbackService } from './feedback.service.js';

describe('durable feedback receipt (real SQLite migration)', () => {
  let db: DataSource, dir: string, dto: FeedbackDto, plans: PlanService;
  const service = () => new FeedbackService(geminiOff, plans, db);
  beforeEach(async () => {
    dir = await mkdtemp(join(tmpdir(), 'smartfit-n05-'));
    db = await new DataSource(
      dataSourceOptions(join(dir, 'receipts.sqlite')),
    ).initialize();
    plans = new PlanService(geminiOff);
    dto = {
      profile: makeProfile(),
      plan: await samplePlan(),
      day_number: 1,
      intensity: Intensity.HARD,
      body_states: [BodyState.NORMAL],
      eating: Eating.ON_PLAN,
    };
  });
  afterEach(async () => {
    vi.restoreAllMocks();
    if (db.isInitialized) await db.destroy();
    await rm(dir, { recursive: true, force: true });
  });
  it('replays exactly the committed response after closing and reopening SQLite', async () => {
    const first = await service().apply(dto);
    await db.destroy();
    db = await new DataSource(
      dataSourceOptions(join(dir, 'receipts.sqlite')),
    ).initialize();
    expect(await service().apply(dto)).toEqual({ ...first, replayed: true });
    expect(await db.getRepository(FeedbackReceipt).count()).toBe(1);
    await expect(
      service().apply({ ...dto, intensity: Intensity.EASY }),
    ).rejects.toMatchObject({ status: 409 });
    await expect(service().apply(dto, 'different-owner')).rejects.toMatchObject(
      { status: 409 },
    );
  });
  it('coalesces simultaneous day-3 requests into one new cycle', async () => {
    dto.day_number = 3;
    const generate = vi.spyOn(plans, 'generatePlan');
    const s = service(),
      results = await Promise.all([s.apply(dto), s.apply(dto), s.apply(dto)]);
    expect(generate).toHaveBeenCalledTimes(1);
    expect(results[1].response).toEqual(results[0].response);
    expect(results[2].response).toEqual(results[0].response);
    expect(results[0].response.plan.plan_id).not.toBe(dto.plan.plan_id);
    expect(await service().apply(dto)).toEqual({
      ...results[0],
      replayed: true,
    });
    expect(generate).toHaveBeenCalledTimes(1);
  });
  it('fences two service instances and rejects a changed payload while processing', async () => {
    dto.day_number = 3;
    const next = await samplePlan();
    let release!: (v: typeof next) => void;
    const generate = vi.spyOn(plans, 'generatePlan').mockImplementation(
      () =>
        new Promise((resolve) => {
          release = resolve;
        }),
    );
    const first = service().apply(dto);
    while (!release) await new Promise((resolve) => setTimeout(resolve, 1));
    await expect(service().apply(dto)).rejects.toMatchObject({ status: 409 });
    await expect(
      service().apply({ ...dto, eating: Eating.OVER }),
    ).rejects.toMatchObject({ status: 409 });
    release(next);
    const result = await first;
    expect(await service().apply(dto)).toEqual({ ...result, replayed: true });
    expect(generate).toHaveBeenCalledTimes(1);
  });
  it('does not publish success when result persistence fails; exact retry remains possible', async () => {
    const repo = db.getRepository(FeedbackReceipt);
    vi.spyOn(repo, 'update').mockRejectedValueOnce(new Error('disk full'));
    await expect(service().apply(dto)).rejects.toMatchObject({ status: 503 });
    expect(await repo.count()).toBe(0);
    expect((await service().apply(dto)).response.plan.plan_id).toBe(
      dto.plan.plan_id,
    );
  });
  it('refuses to run rules or AI if durable claim cannot be written', async () => {
    const generate = vi.spyOn(plans, 'generatePlan');
    vi.spyOn(db, 'query').mockRejectedValueOnce(new Error('disk full'));
    await expect(
      service().apply({ ...dto, day_number: 3 }),
    ).rejects.toMatchObject({ status: 503 });
    expect(generate).not.toHaveBeenCalled();
  });
  it('recovers an abandoned lease with the same request without accepting a different request', async () => {
    await service().apply(dto);
    const repo = db.getRepository(FeedbackReceipt);
    await repo.update(
      { plan_id: dto.plan.plan_id },
      { status: 'processing', result_json: null, lease_until: 0 },
    );
    await expect(
      service().apply({ ...dto, eating: Eating.OVER }),
    ).rejects.toMatchObject({ status: 409 });
    const result = await service().apply(dto);
    expect(result.response.plan.plan_id).toBe(dto.plan.plan_id);
    expect(
      (await repo.findOneByOrFail({ plan_id: dto.plan.plan_id })).status,
    ).toBe('completed');
  });
  it('replays danger warning and preserves non-target days', async () => {
    dto.day_number = 2;
    dto.body_states = [BodyState.DANGER_SIGN];
    dto.eating = Eating.OVER;
    const result = await service().apply(dto);
    expect(result.response.safety_warning).not.toBeNull();
    expect(result.response.plan.days.slice(0, 2)).toEqual(
      dto.plan.days.slice(0, 2),
    );
    expect(result.response.plan.days[2].workout.title).toContain('Nghỉ ngơi');
    expect(await service().apply(dto)).toEqual({ ...result, replayed: true });
  });
});
