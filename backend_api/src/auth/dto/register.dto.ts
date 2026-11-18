import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterDto {
  @ApiProperty({ example: 'minh@vku.edu.vn' })
  @IsEmail({}, { message: 'Email không hợp lệ.' })
  @MaxLength(320)
  email: string;

  @ApiProperty({ example: 'Công Minh' })
  @IsString()
  @MinLength(1, { message: 'Họ tên không được để trống.' })
  @MaxLength(200)
  name: string;

  @ApiProperty({ example: 'matkhau123' })
  @IsString()
  @MinLength(6, { message: 'Mật khẩu tối thiểu 6 ký tự.' })
  @MaxLength(100)
  password: string;
}

