import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class GoogleLoginDto {
  @ApiProperty({
    description: 'Google ID Token lấy từ google_sign_in. Chế độ AUTH_MODE=mock nhận "mock:<email>".',
    example: 'mock:sv@vku.edu.vn',
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(4096)
  id_token: string;
}
