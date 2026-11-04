
import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module.js';
import { PrismaModule } from '../prisma/prisma.module.js';

import { PayableBillsController } from './payable-bills.controller.js';
import { PayableBillsService } from './payable-bills.service.js';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [PayableBillsController],
  providers: [PayableBillsService],
  exports: [PayableBillsService],
})
export class PayableBillsModule {}
