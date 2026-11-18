import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: 'minh@vku.edu.vn' })
  @IsEmail({}, { message: 'Email không hợp lệ.' })
  @MaxLength(320)
  email: string;

  @ApiProperty({ example: 'matkhau123' })
  @IsString()
  @IsNotEmpty({ message: 'Vui lòng nhập mật khẩu.' })
  @MaxLength(100)
  password: string;
}

