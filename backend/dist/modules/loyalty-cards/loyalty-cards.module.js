"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.LoyaltyCardsModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const loyalty_cards_service_1 = require("./loyalty-cards.service");
const loyalty_cards_controller_1 = require("./loyalty-cards.controller");
const loyalty_card_entity_1 = require("../../database/entities/loyalty-card.entity");
const business_entity_1 = require("../../database/entities/business.entity");
const scan_entity_1 = require("../../database/entities/scan.entity");
const reward_entity_1 = require("../../database/entities/reward.entity");
const reward_transfer_history_entity_1 = require("../../database/entities/reward-transfer-history.entity");
let LoyaltyCardsModule = class LoyaltyCardsModule {
};
exports.LoyaltyCardsModule = LoyaltyCardsModule;
exports.LoyaltyCardsModule = LoyaltyCardsModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([
                loyalty_card_entity_1.LoyaltyCard,
                business_entity_1.Business,
                scan_entity_1.Scan,
                reward_entity_1.Reward,
                reward_transfer_history_entity_1.RewardTransferHistory,
            ]),
        ],
        controllers: [loyalty_cards_controller_1.LoyaltyCardsController],
        providers: [loyalty_cards_service_1.LoyaltyCardsService],
        exports: [loyalty_cards_service_1.LoyaltyCardsService],
    })
], LoyaltyCardsModule);
//# sourceMappingURL=loyalty-cards.module.js.map