import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { RestrictionsDto } from './dto/restrictions.dto.js';
import { ExerciseTag } from './enums/exercise.enum.js';
import { parsePlanStructure } from './plan-validation.js';
import { filterPlanByRestrictions, findRestrictionViolations } from './restriction-filter.js';
import { findAvoidedIngredient, matchRestrictions } from './restriction-matcher.js';

const { plan: sample } = parsePlanStructure(
  JSON.parse(readFileSync(fileURLToPath(new URL('./data/sample-plan.json', import.meta.url)), 'utf-8')),
);
if (!sample) throw new Error('sample-plan.json không hợp lệ');
const match = (values: Partial<RestrictionsDto>) => matchRestrictions(Object.assign(new RestrictionsDto(), values));

describe('filterPlanByRestrictions', () => {
  it('returns the plan untouched when nothing is recognised', () => {
    expect(filterPlanByRestrictions(sample, match({})).plan).toBe(sample);
  });

  it('replaces meals with a recognised allergen, keeping their calories', () => {
    const avoid = match({ allergies: 'hải sản, trứng' });
    const { plan, incomplete } = filterPlanByRestrictions(sample, avoid);
    expect(incomplete).toBe(false);
    for (const [d, day] of plan.days.entries()) {
      for (const [m, meal] of day.meals.entries()) {
        expect(findAvoidedIngredient(meal, avoid.avoidIngredients)).toBeNull();
        expect(meal.calories).toBe(sample.days[d].meals[m].calories);
      }
    }
  });

  it('replaces or drops exercises that load an injured area', () => {
    const { plan } = filterPlanByRestrictions(sample, match({ injuries: 'đau gối, cổ tay' }));
    const tags = plan.days.flatMap((day) => day.workout.exercises.flatMap((exercise) => exercise.tags));
    expect(tags).not.toContain(ExerciseTag.JUMPING);
    expect(tags).not.toContain(ExerciseTag.KNEELING);
    expect(tags).not.toContain(ExerciseTag.WRIST_LOAD);
    expect(plan.days.every((day) => day.workout.exercises.length > 0)).toBe(true);
  });

  it('is deterministic for the same restrictions', () => {
    const avoid = match({ allergies: 'hải sản' });
    expect(filterPlanByRestrictions(sample, avoid)).toEqual(filterPlanByRestrictions(sample, avoid));
  });
});

describe('findRestrictionViolations', () => {
  it('names the day and meal type but never the matched keyword (#12)', () => {
    const violations = findRestrictionViolations(sample.days, match({ allergies: 'hải sản', injuries: 'đau gối' }));
    expect(violations).toContain('Ngày 3 lunch: có nguyên liệu người dùng cần tránh');
    expect(violations).toContain('Ngày 1: có động tác không phù hợp chấn thương đã khai');
    expect(violations.join('\n')).not.toMatch(/mắm|jumping|kneeling|gối/);
  });
});
