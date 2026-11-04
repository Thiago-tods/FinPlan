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

export class UpdatePayableBillDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(150)
  @Matches(/\S/, {
    message: 'A descrição não pode estar vazia.',
  })
  description?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  @Max(9999999999999.99)
  amount?: number;

  @IsOptional()
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
  ])
  category?:
    | 'housing'
    | 'utilities'
    | 'food'
    | 'transport'
    | 'health'
    | 'education'
    | 'subscriptions'
    | 'taxes'
    | 'other';

  @IsOptional()
  @IsDateString()
  dueDate?: string;

  @IsOptional()
  @IsDateString()
  discountDeadline?: string | null;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  @Max(9999999999999.99)
  discountAmount?: number | null;

  @IsOptional()
  @IsUUID('4')
  accountId?: string | null;

  @IsOptional()
  @IsUUID('4')
  linkedPendingTransactionId?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  notes?: string;
}
