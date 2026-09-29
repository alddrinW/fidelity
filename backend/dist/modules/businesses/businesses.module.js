"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.BusinessesModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const businesses_service_1 = require("./businesses.service");
const businesses_controller_1 = require("./businesses.controller");
const business_entity_1 = require("../../database/entities/business.entity");
const business_category_entity_1 = require("../../database/entities/business-category.entity");
const loyalty_card_entity_1 = require("../../database/entities/loyalty-card.entity");
const scan_entity_1 = require("../../database/entities/scan.entity");
const reward_entity_1 = require("../../database/entities/reward.entity");
const profile_entity_1 = require("../../database/entities/profile.entity");
let BusinessesModule = class BusinessesModule {
};
exports.BusinessesModule = BusinessesModule;
exports.BusinessesModule = BusinessesModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([
                business_entity_1.Business,
                business_category_entity_1.BusinessCategory,
                loyalty_card_entity_1.LoyaltyCard,
                scan_entity_1.Scan,
                reward_entity_1.Reward,
                profile_entity_1.Profile,
            ]),
        ],
        controllers: [businesses_controller_1.BusinessesController],
        providers: [businesses_service_1.BusinessesService],
        exports: [businesses_service_1.BusinessesService],
    })
], BusinessesModule);
//# sourceMappingURL=businesses.module.js.map