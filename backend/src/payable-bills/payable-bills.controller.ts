
import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';

import { CurrentUser } from '../auth/current-user.decorator.js';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';

import { CreatePayableBillDto } from './dto/create-payable-bill.dto.js';
import { UpdatePayableBillDto } from './dto/update-payable-bill.dto.js';
import { PayPayableBillDto } from './dto/pay-payable-bill.dto.js';
import { PayableBillsService } from './payable-bills.service.js';

interface AuthenticatedUser {
  userId: string;
  email: string;
}

@Controller('payable-bills')
@UseGuards(JwtAuthGuard)
export class PayableBillsController {
  constructor(
    private readonly payableBillsService: PayableBillsService,
  ) {}

  @Post()
  create(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreatePayableBillDto,
  ) {
    return this.payableBillsService.create(user.userId, dto);
  }

  @Get()
  findAll(@CurrentUser() user: AuthenticatedUser) {
    return this.payableBillsService.findAll(user.userId);
  }

  @Get(':id')
  findOne(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.payableBillsService.findOne(user.userId, id);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdatePayableBillDto,
  ) {
    return this.payableBillsService.update(user.userId, id, dto);
  }

  @Post(':id/pay')
  pay(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: PayPayableBillDto,
  ) {
    return this.payableBillsService.pay(user.userId, id, dto);
  }

  @Delete(':id')
  remove(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.payableBillsService.remove(user.userId, id);
  }
}
