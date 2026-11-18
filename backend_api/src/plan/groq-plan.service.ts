import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';
import { GroqDebugFile } from './groq-debug.js';
import type { CreatePlanDto } from './dto/create-plan.dto.js';
import type { DailyTargetDto } from './dto/meal-plan-response.dto.js';
import { buildPlanPrompt } from './gemini.service.js';
import {
  planRepairInstructions,
  type PlanValidationIssue,
} from './plan-diagnostics.js';

export class GroqContentError extends Error {
  constructor(readonly code: 'INVALID_JSON' | 'INCOMPLETE_OUTPUT') {
    super(
      code === 'INVALID_JSON'
        ? 'Groq trả JSON không hợp lệ'
        : 'Groq trả kết quả rỗng hoặc chưa hoàn tất',
    );
  }
}

export class GroqRequestError extends Error {
  constructor(readonly status: number) {
    // Never include provider response bodies: they may echo profile data.
    super(`Groq HTTP ${status}`);
  }
}

@Injectable()
export class GroqPlanService {
  readonly providerName = 'groq' as const;
  readonly budget: { perCallMs: number; totalMs: number };
  readonly enabled: boolean;
  private readonly key: string;
  private readonly model: string;
  private readonly debug: GroqDebugFile;
  private readonly traces = new WeakMap<object, string>();

  constructor(config: ConfigService) {
    const provider = config.get<string>('PLAN_AI_PROVIDER') || 'groq';
    if (!['gemini', 'groq'].includes(provider))
      throw new Error('PLAN_AI_PROVIDER phải là gemini hoặc groq');
    this.enabled = provider === 'groq';
    this.key = config.get<string>('GROQ_API_KEY')?.trim() || '';
    this.model = config.get<string>('GROQ_MODEL') || 'openai/gpt-oss-120b';
    this.debug = new GroqDebugFile(
      config.get<string>('NODE_ENV') !== 'production' &&
        config.get<string>('GROQ_DEBUG_RESPONSES') === 'true',
      this.key,
    );
    const readMs = (name: string, fallback: number) => {
      const value = Number(config.get<string>(name) || fallback);
      if (!Number.isInteger(value) || value <= 0)
        throw new Error(`${name} phải là số nguyên dương`);
      return value;
    };
    const perCallMs = readMs('GROQ_TIMEOUT_MS', 60_000);
    this.budget = {
      perCallMs,
      totalMs: Math.max(perCallMs, readMs('GROQ_TOTAL_TIMEOUT_MS', 90_000)),
    };
  }

  get isConfigured(): boolean {
    return Boolean(this.key);
  }

  async debugValidation(
    raw: unknown,
    details: Record<string, unknown>,
  ): Promise<void> {
    await this.debug.write({
      event: 'validation',
      trace:
        typeof raw === 'object' && raw !== null
          ? this.traces.get(raw)
          : undefined,
      ...details,
    });
  }

  async generatePlanContent(
    profile: CreatePlanDto,
    target: DailyTargetDto,
    feedbackNote: string | undefined,
    timeoutMs: number,
    repair: readonly PlanValidationIssue[] = [],
  ): Promise<unknown> {
    return this.generateJson(
      buildPlanPrompt(profile, target, feedbackNote) +
        planRepairInstructions(repair),
      timeoutMs,
    );
  }

  async generateJson(
    prompt: string,
    timeoutMs: number = this.budget.perCallMs,
  ): Promise<unknown> {
    if (!this.key) throw new Error('GROQ_API_KEY chưa được cấu hình');
    const trace = randomUUID();
    try {
      const response = await fetch(
        'https://api.groq.com/openai/v1/chat/completions',
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${this.key}`,
            'Content-Type': 'application/json',
          },
          signal: AbortSignal.timeout(timeoutMs),
          body: JSON.stringify({
            model: this.model,
            messages: [{ role: 'user', content: prompt }],
            response_format: { type: 'json_object' },
            reasoning_effort: 'low',
            max_completion_tokens: 7000,
          }),
        },
      );
      const responseText = await response.text();
      await this.debug.write({
        event: 'groq_response',
        trace,
        model: this.model,
        status: response.status,
        body: responseText,
      });
      if (!response.ok) throw new GroqRequestError(response.status);
      const body = JSON.parse(responseText) as {
        choices?: { finish_reason?: string; message?: { content?: string } }[];
      };
      const choice = body.choices?.[0];
      if (choice?.finish_reason !== 'stop' || !choice.message?.content)
        throw new GroqContentError('INCOMPLETE_OUTPUT');
      try {
        const parsed: unknown = JSON.parse(choice.message.content);
        if (typeof parsed === 'object' && parsed !== null)
          this.traces.set(parsed, trace);
        await this.debug.write({
          event: 'ai_content',
          trace,
          finish_reason: choice.finish_reason,
          content: choice.message.content,
          parsed,
        });
        return parsed;
      } catch {
        throw new GroqContentError('INVALID_JSON');
      }
    } catch (error) {
      await this.debug.write({
        event: 'groq_error',
        trace,
        name: error instanceof Error ? error.name : 'Unknown',
        message: error instanceof Error ? error.message : 'Unknown error',
      });
      if (
        error instanceof Error &&
        ['TimeoutError', 'AbortError'].includes(error.name)
      ) {
        const timeout = new Error(`Groq không phản hồi sau ${timeoutMs} ms`);
        timeout.name = 'TimeoutError';
        throw timeout;
      }
      throw error;
    }
  }
}
