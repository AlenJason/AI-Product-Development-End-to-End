import { Gender } from './enums/gender.enum.js';
import { bodyMassIndex, cutBlockReason, PROFILE_SAFETY_MESSAGES } from './profile-safety.js';

const body = (height_cm: number, weight_kg: number, pregnant_or_breastfeeding = false) => ({
  gender: Gender.FEMALE,
  height_cm,
  weight_kg,
  pregnant_or_breastfeeding,
});

describe('cutBlockReason (BRD FR-1.3, v2.6.0)', () => {
  it('blocks cutting when underweight (BMI < 18.5)', () => {
    expect(bodyMassIndex(160, 42)).toBeCloseTo(16.4, 1);
    expect(cutBlockReason(body(160, 42))).toBe(PROFILE_SAFETY_MESSAGES.underweightCut);
  });

  it('compares the unrounded BMI, so 18.46 is still underweight', () => {
    expect(bodyMassIndex(170, 53.35)).toBeCloseTo(18.46, 2);
    expect(cutBlockReason(body(170, 53.35))).toBe(PROFILE_SAFETY_MESSAGES.underweightCut);
    expect(cutBlockReason(body(170, 53.5))).toBeNull();
  });

  it('blocks cutting while pregnant or breastfeeding, whatever the BMI', () => {
    expect(cutBlockReason(body(160, 70, true))).toBe(PROFILE_SAFETY_MESSAGES.pregnantCut);
  });

  it('allows a normal profile and ignores invalid numbers (other validators report them)', () => {
    expect(cutBlockReason(body(168, 62))).toBeNull();
    expect(cutBlockReason(body(Number.NaN, 62))).toBeNull();
  });
});
