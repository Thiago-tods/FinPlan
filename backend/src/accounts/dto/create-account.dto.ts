
import { Type } from 'class-transformer';
import {
  IsIn,
  IsNumber,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class CreateAccountDto {
  @IsString()
  @MinLength(2, {
    message: 'O nome do banco deve ter pelo menos 2 caracteres.',
  })
  @MaxLength(100)
  bankName: string;

  @IsString()
  @MinLength(2, {
    message: 'O apelido deve ter pelo menos 2 caracteres.',
  })
  @MaxLength(50)
  nickname: string;

  @IsIn(['checking', 'savings', 'payment', 'investment'], {
    message: 'Informe um tipo de conta válido.',
  })
  type: 'checking' | 'savings' | 'payment' | 'investment';

  @Type(() => Number)
  @IsNumber(
    { maxDecimalPlaces: 2 },
    { message: 'O saldo inicial deve ser um número com até 2 casas decimais.' },
  )
  @Min(-9999999999999.99)
  @Max(9999999999999.99)
  initialBalance: number;
}
