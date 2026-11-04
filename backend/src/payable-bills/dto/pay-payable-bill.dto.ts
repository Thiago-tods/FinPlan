import { IsDateString, IsIn, IsOptional, IsUUID } from 'class-validator';

export class PayPayableBillDto {
  @IsOptional()
  @IsUUID('4', {
    message: 'Informe um ID de conta bancária válido.',
  })
  accountId?: string;

  @IsOptional()
  @IsDateString({}, {
    message: 'Informe uma data de pagamento válida.',
  })
  paidAt?: string;

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
}