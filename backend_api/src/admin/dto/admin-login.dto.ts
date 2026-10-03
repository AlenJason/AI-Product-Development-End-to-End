import { ApiProperty } from '@nestjs/swagger';
import { IsString, Length } from 'class-validator';

export class AdminLoginDto {
  @ApiProperty({ example: 'admin' })
  @IsString()
  @Length(1, 64)
  username: string;

  // Giới hạn độ dài: scrypt chạy trên mọi mật khẩu gửi lên, không cho gửi chuỗi khổng lồ.
  @ApiProperty({ example: '••••••••••••' })
  @IsString()
  @Length(1, 200)
  password: string;
}

export class AdminLoginResponseDto {
  @ApiProperty({ description: 'Token của trang quản trị — không dùng được cho API người dùng' })
  access_token: string;

  @ApiProperty({ example: 28800, description: 'Số giây tới khi token hết hạn' })
  expires_in: number;
}

export class AdminSessionDto {
  @ApiProperty({ example: 'admin' })
  username: string;
}
