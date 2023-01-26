const int PRIORITY_LIST_MAX = 10;
StrategyResult BUY_PRIORITY_CHECK_LIST[10];
StrategyResult SELL_PRIORITY_CHECK_LIST[10];
int priority_index_buy = 0;
int priority_index_sell = 0;

///////////////////////////////////// Prioritization ///////////////////////////

void clearOrderPriorityList()
{
    StrategyResult strategyDefaultVal;
    for (int i = 0; i < PRIORITY_LIST_MAX; i++)
    {
        BUY_PRIORITY_CHECK_LIST[i] = strategyDefaultVal;
        SELL_PRIORITY_CHECK_LIST[i] = strategyDefaultVal;
    }
    priority_index_buy = 0;
    priority_index_sell = 0;
}

void addOrderPriority(StrategyResult &value, int OP)
{
    if (OP == OP_BUY)
    {
        BUY_PRIORITY_CHECK_LIST[priority_index_buy] = value;
        priority_index_buy++;
    }
    else if (OP == OP_SELL)
    {
        SELL_PRIORITY_CHECK_LIST[priority_index_sell] = value;
        priority_index_sell++;
    }
}

int orderPriorityListLength(int OP)
{
    if (OP == OP_BUY)
    {
        return priority_index_buy;
    }
    else if (OP == OP_SELL)
    {
        return priority_index_sell;
    }

    return -1;
}

// This function reduces 2 lists to one list to be processed
void getPrioritizedOrderStrategyResult(int OP, StrategyResult &prioritizedListResult[])
{
    int targetCount = orderPriorityListLength(OP);
    // Print("Prioriti List Type: ", OP == OP_BUY ? "Buy" : "Sell");
    if (OP == OP_BUY)
    {
        prioritizeOrders(BUY_PRIORITY_CHECK_LIST, targetCount, prioritizedListResult);
    }
    else
    {
        prioritizeOrders(SELL_PRIORITY_CHECK_LIST, targetCount, prioritizedListResult);
    }
}

void prioritizeOrders(StrategyResult &list[], int count, StrategyResult &prioritizedListResult[])
{

    // This means we only have one immediate option and should return
    if (count == 1)
    {
        ArrayResize(prioritizedListResult, 1);
        prioritizedListResult[0] = list[0];
        return;
    }

    /* Olaviatha:
        1- Immediate be pending tarjih dade mishavad
        2- Beyne 2 immediate olaviat ba moredi ast ke stoplosse kuchecktari dashte bashad
    */
    // Looking for immediates and prioritize them
    StrategyResult result;
    bool immediateFound = false;
    for (int i = 0; i < count; i++)
    {
        StrategyResult item = list[i];
        if (item.orderInfo.valid)
        {
            debug(item.symbol + " From Prioritization List");

            // One is immediate
            if (result.orderInfo.pending && !item.orderInfo.pending)
            {
                result = item;
                immediateFound = true;
                continue;
            }

            // Both are immediates
            if ((!result.orderInfo.pending && !item.orderInfo.pending))
            {
                // Check mikonim har kodam stoplosseshan chanta average candle size ast?
                const double currentSlSize = MathAbs(result.orderInfo.orderPrice - result.orderInfo.slPrice) / result.orderInfo.averageCandleSize;
                const double itemSlSize = MathAbs(item.orderInfo.orderPrice - item.orderInfo.slPrice) / item.orderInfo.averageCandleSize;
                if (itemSlSize > currentSlSize)
                {
                    result = item;
                    immediateFound = true;
                    continue;
                }
            }
        }
    }

    if (immediateFound)
    {
        ArrayResize(prioritizedListResult, 1);
        prioritizedListResult[0] = result;
        return;
    }

    ArrayResize(prioritizedListResult, count);
    for (int index = 0; index < count; index++)
    {
        prioritizedListResult[index] = list[index];
    }
}

void openPrioritizedOrdersFor(GroupStruct &group, int OP)
{

    string OP_string = OP == OP_BUY ? "BUY" : "SELL";

    string active_symbol = OP == OP_BUY ? group.active_symbol_buy : group.active_symbol_sell;

    OrderEnvironment env = OP == OP_BUY ? ENV_BUY : ENV_SELL;

    if (orderPriorityListLength(OP) > 0)
    {
        StrategyResult prioritizedList[];
        getPrioritizedOrderStrategyResult(OP, prioritizedList);

        for (int i = 0; i < ArraySize(prioritizedList); i++)
        {
            StrategyResult sr = prioritizedList[i];

            // If Not have an already active transaction or open pending
            bool canOpen = !hasActiveTransaction(sr.symbol, group.groupIndex) && (selectOpenOrderTicketFor(sr.symbol, group.groupIndex) <= 0);

            if (canOpen)
            {
                Order(sr.symbol, env, sr.orderInfo, getMagicNumber(group.groupIndex));
                // call syncing group orders here
                if (hasActiveTransaction(sr.symbol, group.groupIndex) == true)
                {
                    if (OP == OP_BUY)
                    {
                        group.active_symbol_buy = sr.symbol;
                        group.active_strategy_buy = sr;
                    }
                    else if (OP == OP_SELL)
                    {
                        group.active_symbol_sell = sr.symbol;
                        group.active_strategy_sell = sr;
                    }
                }
            }
        }
    }
}
