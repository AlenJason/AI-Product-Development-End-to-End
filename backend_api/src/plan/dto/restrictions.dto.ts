import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, type TransformFnParams } from 'class-transformer';
import { IsOptional, IsString, MaxLength } from 'class-validator';

export const RESTRICTION_MAX_LENGTH = 300;

const trim = ({ value }: TransformFnParams): unknown => (typeof value === 'string' ? value.trim() : value);

// Văn bản tự do người dùng nhập (BRD FR-1.4). Chỉ gửi kèm request: không lưu, không ghi log (NFR-7).
export class RestrictionsDto {
  @ApiPropertyOptional({ example: 'Hải sản', maxLength: RESTRICTION_MAX_LENGTH })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(RESTRICTION_MAX_LENGTH)
  allergies: string = '';

  @ApiPropertyOptional({ example: 'Đau gối', maxLength: RESTRICTION_MAX_LENGTH })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(RESTRICTION_MAX_LENGTH)
  injuries: string = '';

  @ApiPropertyOptional({ example: '', maxLength: RESTRICTION_MAX_LENGTH })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(RESTRICTION_MAX_LENGTH)
  health_conditions: string = '';
}
