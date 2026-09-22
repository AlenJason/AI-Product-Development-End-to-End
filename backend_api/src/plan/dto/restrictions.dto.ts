import { IsArray, IsString } from 'class-validator';

export class RestrictionsDto {
  @IsArray()
  @IsString({ each: true })
  allergies: string[] = [];

  @IsArray()
  @IsString({ each: true })
  injuries: string[] = [];
}
