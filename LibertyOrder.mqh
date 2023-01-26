/////////////////////////// Order Helpers ///////////////////////////

double pipToPoint(string symbol, double pipValue)
{
    double digits = MarketInfo(symbol, MODE_DIGITS);
    return pipValue * (MathPow(0.1, digits - 1));
}

double GetLotSize(string symbol, double riskPercent, double price, double slPrice)
{
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double symbolPoints = MathPow(0.1, digits - 1);
    double slPoints = (MathAbs(price - slPrice) / symbolPoints) * (MathPow(0.1, digits - 1));

    double risk = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE) * (riskPercent / 100), 2);

    double ticksize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickvalue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotstep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

    double moneyPerLotstep = slPoints / ticksize * tickvalue * lotstep;
    double lots = MathFloor(risk / moneyPerLotstep) * lotstep;

    lots = MathMin(lots, SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX));
    lots = MathMax(lots, SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN));

    return lots;
}

int Order(string symbol, OrderEnvironment orderEnv, OrderInfoResult &orderInfo, int magicNumber, string comment = "")
{
    int expiration = 0;

    int OP = 0;

    const int digits = (int)MarketInfo(symbol, MODE_DIGITS);

    double price = NormalizeDouble(orderInfo.orderPrice, digits);

    if (orderEnv == ENV_BUY)
    {
        // By default it set to buy
        OP = OP_BUY;
        double marketPrice = MarketInfo(symbol, MODE_ASK);

        if (orderInfo.pending)
        {
            OP = marketPrice > price ? OP_BUYLIMIT : OP_BUYSTOP;
        }
        else
        {
            // Make sure price matches the market price
            price = NormalizeDouble(marketPrice, digits);
        }
    }
    else if (orderEnv == ENV_SELL)
    {
        // By default it set to sell
        OP = OP_SELL;
        double marketPrice = MarketInfo(symbol, MODE_BID);

        if (orderInfo.pending)
        {
            OP = marketPrice < price ? OP_SELLLIMIT : OP_SELLSTOP;
        }
        else
        {
            // Make sure price matches the market price
            price = NormalizeDouble(marketPrice, digits);
        }
    }
    else
    {
        return -1;
    }

    double SL = NormalizeDouble(orderInfo.slPrice, digits);

    double TP = NormalizeDouble(orderInfo.tpPrice, digits);

    if (orderInfo.pending)
    {
        expiration = ((int)TimeCurrent()) + (60 * PendingsExpirationMinutes);
    }

    double LotSize = GetLotSize(symbol, RiskPercent, price, SL);

    if (OP == OP_BUY || OP == OP_SELL)
        debug(symbol + " Opening Immediate " + (OP == OP_BUY ? "Buy" : "Sell"));

    return OrderSend(
        symbol,
        OP,
        LotSize,
        price,
        3,
        SL,
        TP,
        comment != "" ? comment : CommentText,
        magicNumber,
        expiration,
        Green);
}

bool isOpPending(int op)
{
    return op == OP_SELLLIMIT || op == OP_BUYLIMIT || op == OP_SELLSTOP || op == OP_BUYSTOP;
}

string getOpName(int OP)
{
    switch (OP)
    {
    case OP_BUY:
        return "BUY";
    case OP_SELL:
        return "SELL";
    case OP_BUYSTOP:
        return "BUY_STOP";
    case OP_BUYLIMIT:
        return "BUY_LIMIT";
    case OP_SELLSTOP:
        return "SELL_STOP";
    case OP_SELLLIMIT:
        return "SELL_LIMIT";
    default:
        return "NONE";
    }
}
