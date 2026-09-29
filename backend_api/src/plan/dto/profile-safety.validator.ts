import {
  type ValidationArguments,
  ValidatorConstraint,
  type ValidatorConstraintInterface,
} from 'class-validator';
import { Gender } from '../enums/gender.enum.js';
import { Goal } from '../enums/goal.enum.js';
import { cutBlockReason, PROFILE_SAFETY_MESSAGES, type SafetyProfile } from '../profile-safety.js';

// `goal = cut` bị từ chối khi thiếu cân hoặc mang thai / cho con bú (BRD FR-1.3, v2.6.0).
@ValidatorConstraint({ name: 'safeGoal' })
export class SafeGoalConstraint implements ValidatorConstraintInterface {
  validate(goal: unknown, args: ValidationArguments): boolean {
    return goal !== Goal.CUT || cutBlockReason(args.object as SafetyProfile) === null;
  }

  defaultMessage(args: ValidationArguments): string {
    return cutBlockReason(args.object as SafetyProfile) ?? '';
  }
}

@ValidatorConstraint({ name: 'pregnancyNeedsFemale' })
export class PregnancyNeedsFemaleConstraint implements ValidatorConstraintInterface {
  validate(value: unknown, args: ValidationArguments): boolean {
    return value !== true || (args.object as SafetyProfile).gender === Gender.FEMALE;
  }

  defaultMessage(): string {
    return PROFILE_SAFETY_MESSAGES.pregnantNotFemale;
  }
}
