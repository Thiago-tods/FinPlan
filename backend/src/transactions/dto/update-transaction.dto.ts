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

export class UpdateTransactionDto {
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
  @IsIn(['income', 'expense'])
  type?: 'income' | 'expense';

  @IsOptional()
  @IsIn([
    'salary',
    'freelance',
    'investment',
    'food',
    'housing',
    'transportation',
    'health',
    'education',
    'entertainment',
    'shopping',
    'bills',
    'taxes',
    'other',
  ])
  category?:
    | 'salary'
    | 'freelance'
    | 'investment'
    | 'food'
    | 'housing'
    | 'transportation'
    | 'health'
    | 'education'
    | 'entertainment'
    | 'shopping'
    | 'bills'
    | 'taxes'
    | 'other';

  @IsOptional()
  @IsUUID('4')
  accountId?: string;

  @IsOptional()
  @IsDateString()
  transactionDate?: string;

  @IsOptional()
  @IsDateString()
  dueDate?: string;

  @IsOptional()
  @IsIn(['pending', 'completed', 'cancelled'])
  status?: 'pending' | 'completed' | 'cancelled';

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  notes?: string;
}