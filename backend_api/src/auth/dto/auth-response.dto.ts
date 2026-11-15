import { ApiProperty } from '@nestjs/swagger';

export class AuthUserDto {
  @ApiProperty({ format: 'uuid' })
  id: string;

  @ApiProperty({ example: 'sv@vku.edu.vn' })
  email: string;

  @ApiProperty({ example: 'Nguyễn Văn A' })
  name: string;

  @ApiProperty({ required: false })
  profile?: Record<string, unknown> | null;

  @ApiProperty({ required: false })
  latest_plan?: Record<string, unknown> | null;
}

export class AuthResponseDto {
  @ApiProperty({ description: 'JWT của SmartFit; gửi lại qua header Authorization: Bearer <access_token>' })
  access_token: string;

  @ApiProperty({ type: AuthUserDto })
  user: AuthUserDto;
}
