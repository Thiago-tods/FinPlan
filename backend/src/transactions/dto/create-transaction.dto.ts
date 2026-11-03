import { Type } from 'class-transformer';
import {
  IsDateString,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
  Matches,
} from 'class-validator';

export class CreateTransactionDto {
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

  @IsIn(['income', 'expense'], {
    message: 'Informe um tipo de transação válido.',
  })
  type: 'income' | 'expense';

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
  ], {
    message: 'Informe uma categoria válida.',
  })
  category:
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

  @IsUUID('4', {
    message: 'Informe um ID de conta válido.',
  })
  accountId: string;

  @IsDateString({}, {
    message: 'Informe uma data de transação válida.',
  })
  transactionDate: string;

  @IsOptional()
  @IsDateString({}, {
    message: 'Informe uma data de vencimento válida.',
  })
  dueDate?: string;

  @IsOptional()
  @IsIn(['pending', 'completed', 'cancelled'], {
    message: 'Informe um status válido.',
  })
  status?: 'pending' | 'completed' | 'cancelled';

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  notes?: string;
}