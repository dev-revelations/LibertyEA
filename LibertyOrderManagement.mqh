/////////////////////////// Order Management Helpers ///////////////////////////
void processOrders()
{
    int total = OrdersTotal();
    for (int pos = 0; pos < total; pos++)
    {
        if (OrderSelect(pos, SELECT_BY_POS) == false)
            continue;

        if (deletePendingIfExceededTPThreshold())
            continue;

        if (deleteSellStopBuyStopIfHitStoploss())
            continue;

        if (deleteOrderIfEnvironmentChanged())
            continue;

        if (EnableBreakEven)
        {
            checkForBreakEven(OrderSymbol(), pos);
        }
        // FileWrite(handle, OrderTicket(), OrderOpenPrice(), OrderOpenTime(), OrderSymbol(), OrderLots());
    }

    syncActiveSymbolOrders();
}

int selectLastHistoryOrderTicketFor(string symbol, int groupIndex)
{
    int i, hstTotal = OrdersHistoryTotal();
    int lastTicket = -1;
    int lastFoundOrderTime = -1;
    for (i = 0; i < hstTotal; i++)
    {
        //---- check selection result
        if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) == false)
        {
            continue;
        }

        if (symbol == OrderSymbol() && OrderMagicNumber() == getMagicNumber(groupIndex) && !isOpPending(OrderType()))
        {
            int orderTime = (int)OrderOpenTime();
            if (orderTime > lastFoundOrderTime)
            {
                lastTicket = OrderTicket();
                lastFoundOrderTime = orderTime;
            }
        }
    }

    return lastTicket;
}

bool symbolHasProfitInCurrentCrossing(string symbol, int groupIndex, int crossTime = -1)
{
    int lastHistoryOrderTicket = selectLastHistoryOrderTicketFor(symbol, groupIndex);

    if ((int)crossTime == -1)
    {
        HigherTFCrossCheckResult maCross = findHigherTimeFrameMACross(symbol, higher_timeframe);
        if (maCross.found)
        {
            crossTime = (int)maCross.crossTime;
        }
    }

    if ((int)crossTime > -1)
    {
        if (lastHistoryOrderTicket > -1 && OrderSelect(lastHistoryOrderTicket, SELECT_BY_TICKET, MODE_HISTORY) == true)
        {
            if (symbol == OrderSymbol() && OrderMagicNumber() == getMagicNumber(groupIndex) && !isOpPending(OrderType()))
            {
                bool hadProfit = OrderProfit() >= 0; // OrderClosePrice() >= OrderTakeProfit();
                if (hadProfit)
                {
                    // Sessione jadid baraye symbole profit dar
                    // bar asase crossinge jadid khahad bud
                    int orderTime = (int)OrderOpenTime();
                    int cross_Time = (int)crossTime;
                    int orderSession = getSessionNumber(OrderOpenTime());
                    int currentSession = getSessionNumber(TimeCurrent());

                    // Already made profit in the current crossing session

                    bool orderHappenedAfterCrossing = orderTime > cross_Time;

                    return orderHappenedAfterCrossing && sessionsEqual(orderSession, currentSession);
                }
            }
        }
    }

    return false;
}

int selectOpenOrderTicketFor(string symbol, int groupIndex, bool finalizedOrdersOnly = false)
{
    int total = OrdersTotal();
    for (int pos = 0; pos < total; pos++)
    {
        if (OrderSelect(pos, SELECT_BY_POS) == false)
            continue;

        bool found = symbol == OrderSymbol() && OrderMagicNumber() == getMagicNumber(groupIndex);

        if (!finalizedOrdersOnly && found)
        {
            return OrderTicket();
        }

        found = found && (OrderType() == OP_BUY || OrderType() == OP_SELL);

        if (finalizedOrdersOnly && found)
        {
            return OrderTicket();
        }
    }

    return -1;
}

bool hasActiveOpenSymbol(int groupIndex, int OP)
{
    int total = OrdersTotal();
    for (int pos = 0; pos < total; pos++)
    {
        if (OrderSelect(pos, SELECT_BY_POS) == false)
            continue;

        int orderGroupIndex = OrderMagicNumber() % 10;

        if (groupIndex == orderGroupIndex && OrderType() == OP)
        {
            return true;
        }
    }

    return false;
}

void checkForBreakEven(string symbol, int orderIndex)
{
    if (OrderSelect(orderIndex, SELECT_BY_POS) == false)
    {
        return;
    }

    int OP = OrderType();
    double SL = OrderStopLoss();
    double orderPrice = OrderOpenPrice();
    double ask = MarketInfo(symbol, MODE_ASK);

    bool applyBreakEven = false;

    if (OP == OP_SELL)
    {
        double priceSlDistance = MathAbs(orderPrice - SL);
        double breakEvenThreshold = orderPrice - (priceSlDistance * BreakEvenRatio);

        applyBreakEven = ask <= breakEvenThreshold && SL > orderPrice;
    }
    else if (OP == OP_BUY)
    {
        double priceSlDistance = MathAbs(orderPrice - SL);
        double breakEvenThreshold = orderPrice + (priceSlDistance * BreakEvenRatio);

        applyBreakEven = ask >= breakEvenThreshold && SL < orderPrice;
    }

    if (applyBreakEven)
    {
        const int digits = (int)MarketInfo(symbol, MODE_DIGITS);
        double newSlPrice = OrderOpenPrice();
        double pipPoint = pipToPoint(symbol, BreakEvenGapPip);
        newSlPrice = (OP == OP_SELL ? newSlPrice - pipPoint : newSlPrice + pipPoint);

        newSlPrice = NormalizeDouble(newSlPrice, digits);

        OrderModify(
            OrderTicket(),     // ticket
            OrderOpenPrice(),  // price
            newSlPrice,        // stop loss
            OrderTakeProfit(), // take profit
            0,                 // expiration
            clrAqua            // color
        );

        debug("============ Breakeven applied(" + symbol + ") ============");

        // breakPoint();
    }
}

bool deletePendingIfExceededTPThreshold()
{
    string symbol = OrderSymbol();
    int OP = OrderType();
    double TP = OrderTakeProfit();
    double ask = MarketInfo(symbol, MODE_ASK);

    bool typeSell = OP == OP_SELLLIMIT || OP == OP_SELLSTOP;
    bool typeBuy = OP == OP_BUYLIMIT || OP == OP_BUYSTOP;

    bool shouldDelete = false;

    if (typeSell)
    {
        shouldDelete = ask <= TP;
    }
    else if (typeBuy)
    {
        shouldDelete = ask >= TP;
    }

    bool couldDelete = false;

    if (shouldDelete)
    {
        couldDelete = OrderDelete(OrderTicket(), clrAzure);
        if (couldDelete)
        {
            debug("Price Exceeded Pending TP Threshold: Deleted Pending For " + symbol);
        }
        else
        {
            debug("Price Exceeded Pending TP Threshold: Could not delete pending for " + symbol);
        }
    }

    return couldDelete;
}

bool deleteSellStopBuyStopIfHitStoploss()
{
    string symbol = OrderSymbol();
    int OP = OrderType();
    double SL = OrderStopLoss();

    bool typeSell = OP == OP_SELLSTOP;
    bool typeBuy = OP == OP_BUYSTOP;

    bool shouldDelete = false;

    if (typeSell)
    {
        double bid = MarketInfo(symbol, MODE_BID);
        shouldDelete = bid >= SL;
    }
    else if (typeBuy)
    {
        double ask = MarketInfo(symbol, MODE_ASK);
        shouldDelete = ask <= SL;
    }

    bool couldDelete = false;

    if (shouldDelete)
    {
        couldDelete = OrderDelete(OrderTicket(), clrAzure);

        string typeStr = typeSell ? "SellStop" : "BuyStop";
        if (couldDelete)
        {
            debug("Price Hit " + typeStr + " SL : Deleted Pending For " + symbol);
        }
        else
        {
            debug("Price Hit " + typeStr + " SL : Could not delete pending for " + symbol);
        }
    }

    return couldDelete;
}

bool deleteOrderIfEnvironmentChanged()
{
    int groupIndex = OrderMagicNumber() % 10;

    string symbol = OrderSymbol();

    if (OrderMagicNumber() == getMagicNumber(groupIndex))
    {
        HigherTFCrossCheckResult maCross = findHigherTimeFrameMACross(symbol, higher_timeframe);
        if (maCross.found && (int)maCross.crossTime > -1)
        {
            int orderTime = (int)OrderOpenTime();
            int cross_Time = (int)maCross.crossTime;

            // Environment avaz shode ?
            int OP = OrderType();

            bool orderTypeDifferentThanCrossEnv = maCross.orderEnvironment == ENV_BUY && (OP == OP_SELL || OP == OP_SELLSTOP || OP == OP_SELLLIMIT);
            orderTypeDifferentThanCrossEnv = orderTypeDifferentThanCrossEnv || (maCross.orderEnvironment == ENV_SELL && (OP == OP_BUY || OP == OP_BUYSTOP || OP == OP_BUYLIMIT));

            if (orderTime < cross_Time || orderTypeDifferentThanCrossEnv /* && !(virtualMACross.found) */)
            {
                if (OP == OP_BUY || OP == OP_SELL)
                {
                    OrderClose(
                        OrderTicket(),                // ticket
                        OrderLots(),                  // volume
                        MarketInfo(symbol, MODE_ASK), // close price
                        3,                            // slippage
                        clrRed                        // color
                    );
                }

                if (OP == OP_BUYLIMIT || OP == OP_SELLLIMIT || OP == OP_BUYSTOP || OP == OP_SELLSTOP)
                {
                    OrderDelete(OrderTicket(), clrAzure);
                }

                debug("Deleting Order Due To Change Of Environment " + symbol);

                return true;
            }
        }
    }
    return false;
}

void syncActiveSymbolOrders()
{
    for (int groupIdx = 0; groupIdx < GROUPS_LENGTH; groupIdx++)
    {
        GroupStruct group = GROUPS[groupIdx];

        if (group.active_symbol_buy != "" && hasActiveTransaction(group.active_symbol_buy, groupIdx) == false)
        {
            debug("Group " + IntegerToString(groupIdx) + " (BUY) Active Symbol Cleard! No Active Transaction " + group.active_symbol_buy);
            group.active_symbol_buy = "";
            StrategyResult sr;
            group.active_strategy_buy = sr;
        }

        if (group.active_symbol_sell != "" && hasActiveTransaction(group.active_symbol_sell, groupIdx) == false)
        {
            debug("Group " + IntegerToString(groupIdx) + " (SELL) Active Symbol Cleard! No Active Transaction" + group.active_symbol_sell);
            group.active_symbol_sell = "";
            StrategyResult sr;
            group.active_strategy_sell = sr;
        }

        // Check to find unset active symbols
        for (int symIndex = 0; symIndex < group.symbols_count; symIndex++)
        {
            string sym = group.symbols[symIndex];

            if (hasActiveTransaction(sym, groupIdx) == true)
            {
                OrderInfoResult orderInfo;
                orderInfo.orderPrice = OrderOpenPrice();
                orderInfo.originalPrice = OrderOpenPrice();
                orderInfo.slPrice = OrderStopLoss();
                orderInfo.tpPrice = OrderTakeProfit();
                orderInfo.pending = isOpPending(OrderType());
                orderInfo.originalPrice = orderInfo.pending ? orderInfo.orderPrice : -1;
                orderInfo.valid = true;

                if (OrderType() == OP_BUY && group.active_symbol_buy == "")
                {
                    debug("Setting Active Symbol During Synchronization " + sym);
                    group.active_symbol_buy = sym;
                    StrategyResult sr;
                    sr.symbol = sym;
                    sr.orderInfo = orderInfo;
                    group.active_strategy_buy = sr;
                }
                else if (OrderType() == OP_SELL && group.active_symbol_sell == "")
                {
                    debug("Setting Active Symbol During Synchronization  " + sym);
                    group.active_symbol_sell = sym;
                    StrategyResult sr;
                    sr.symbol = sym;
                    sr.orderInfo = orderInfo;
                    group.active_strategy_sell = sr;
                }
            }
        }

        // Delete group pendings if we have active symbols
        for (int symIndex = 0; symIndex < group.symbols_count; symIndex++)
        {
            string sym = group.symbols[symIndex];

            if (sym != group.active_symbol_sell && sym != group.active_symbol_buy && selectOpenOrderTicketFor(sym, groupIdx) > -1)
            {
                int OP = OrderType();
                bool shouldDelete = ((OP == OP_BUYSTOP || OP == OP_BUYLIMIT) && group.active_symbol_buy != "");
                shouldDelete = shouldDelete || ((OP == OP_SELLSTOP || OP == OP_SELLLIMIT) && group.active_symbol_sell != "");
                if (shouldDelete)
                {
                    OrderDelete(OrderTicket(), clrAzure);
                    debug("Active Symbol Found - Deleting Pending: Group" + IntegerToString(groupIdx) + " (" + getOpName(OP) + ") " + sym);
                }
            }
        }

        GROUPS[groupIdx] = group;
    }
}

bool hasActiveTransaction(string symbol, int groupIndex)
{
    if (StringLen(symbol) > 0)
    {
        int ticket = selectOpenOrderTicketFor(symbol, groupIndex, true);
        // Has open order
        if (ticket > -1)
        {
            return true;
        }

        // Has profit
        if (symbolHasProfitInCurrentCrossing(symbol, groupIndex))
        {
            return true;
        }
    }

    return false;
}