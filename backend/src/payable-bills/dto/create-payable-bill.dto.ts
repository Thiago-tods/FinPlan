import { Type } from 'class-transformer';
import {
  IsDateString,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class CreatePayableBillDto {
  @IsString()
  @MinLength(2)
  @MaxLength(150)
  @Matches(/\S/, {
    message: 'A descrição não pode estar vazia.',
  })
  description: string;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  @Max(9999999999999.99)
  amount: number;

  @IsIn([
    'housing',
    'utilities',
    'food',
    'transport',
    'health',
    'education',
    'subscriptions',
    'taxes',
    'other',
  ], {
    message: 'Informe uma categoria válida.',
  })
  category:
    | 'housing'
    | 'utilities'
    | 'food'
    | 'transport'
    | 'health'
    | 'education'
    | 'subscriptions'
    | 'taxes'
    | 'other';

  @IsDateString()
  dueDate: string;

  @IsOptional()
  @IsDateString()
  discountDeadline?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  @Max(9999999999999.99)
  discountAmount?: number;

  @IsOptional()
  @IsUUID('4')
  accountId?: string;

  @IsOptional()
  @IsUUID('4')
  linkedPendingTransactionId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  notes?: string;
}
