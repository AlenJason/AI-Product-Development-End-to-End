import { Logger, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import type { DataSource, Repository } from 'typeorm';
import { createMemoryDataSource } from '../../test/memory-data-source.js';
import { PlanRecord } from '../database/entities/plan-record.entity.js';
import { User } from '../database/entities/user.entity.js';
import type { MealPlanResponseDto } from '../plan/dto/meal-plan-response.dto.js';
import { HISTORY_LIMIT, HistoryService } from './history.service.js';

const fakePlan = (targetCalories = 1800): MealPlanResponseDto =>
  ({ plan_id: randomUUID(), daily_target: { target_calories: targetCalories }, days: [] }) as unknown as MealPlanResponseDto;

describe('HistoryService', () => {
  let dataSource: DataSource;
  let plans: Repository<PlanRecord>;
  let service: HistoryService;
  let an: User;
  let binh: User;

  beforeEach(async () => {
    dataSource = await createMemoryDataSource();
    plans = dataSource.getRepository(PlanRecord);
    service = new HistoryService(plans);
    const users = dataSource.getRepository(User);
    an = await users.save(users.create({ google_sub: 'mock:an@vku.edu.vn', email: 'an@vku.edu.vn', name: 'an' }));
    binh = await users.save(users.create({ google_sub: 'mock:binh@vku.edu.vn', email: 'binh@vku.edu.vn', name: 'binh' }));
  });

  afterEach(async () => {
    vi.restoreAllMocks();
    await dataSource.destroy();
  });

  it('saves a plan and returns it unchanged', async () => {
    const plan = fakePlan(1624);
    expect(await service.save(an.id, plan)).toBe(true);
    await expect(service.findOne(an.id, plan.plan_id)).resolves.toEqual(plan);
    expect(await service.list(an.id)).toEqual({
      plans: [{ id: plan.plan_id, created_at: expect.stringMatching(/^\d{4}-\d{2}-\d{2}T.*Z$/), target_calories: 1624 }],
    });
  });

  it('returns false instead of throwing when the database refuses the plan', async () => {
    const error = vi.spyOn(Logger.prototype, 'error').mockImplementation(() => undefined);
    expect(await service.save(randomUUID(), fakePlan())).toBe(false); // user không tồn tại → vi phạm khoá ngoại
    expect(error).toHaveBeenCalledTimes(1);
    expect(await plans.count()).toBe(0);
  });

  it(`lists at most ${HISTORY_LIMIT} plans, newest first`, async () => {
    const base = Date.parse('2026-09-01T00:00:00.000Z');
    await plans.insert(
      Array.from({ length: HISTORY_LIMIT + 5 }, (_, index) => ({
        id: randomUUID(),
        user_id: an.id,
        target_calories: 1500 + index,
        plan_json: fakePlan(),
        created_at: new Date(base + index * 1000),
      })),
    );
    const { plans: listed } = await service.list(an.id);
    expect(listed).toHaveLength(HISTORY_LIMIT);
    expect(listed[0]).toMatchObject({ target_calories: 1500 + HISTORY_LIMIT + 4, created_at: new Date(base + (HISTORY_LIMIT + 4) * 1000).toISOString() });
    expect(listed.at(-1)?.target_calories).toBe(1505);
  });

  it('keeps plans saved within the same second in creation order', async () => {
    const first = fakePlan(1500);
    const second = fakePlan(1600);
    await service.save(an.id, first);
    await new Promise((resolve) => setTimeout(resolve, 5));
    await service.save(an.id, second);
    expect((await service.list(an.id)).plans.map((plan) => plan.id)).toEqual([second.plan_id, first.plan_id]);
  });

  it("never shows one user's plans to another", async () => {
    const plan = fakePlan();
    await service.save(an.id, plan);
    expect(await service.list(binh.id)).toEqual({ plans: [] });
    await expect(service.findOne(binh.id, plan.plan_id)).rejects.toBeInstanceOf(NotFoundException);
  });

  it('answers an unknown id with 404', async () => {
    await expect(service.findOne(an.id, randomUUID())).rejects.toBeInstanceOf(NotFoundException);
  });
});
