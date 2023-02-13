void drawCross(datetime time, double price)
{
    // if(IsTesting())
    //   {
    string id1 = "khat_h";
    string id2 = "khat_v";

    ObjectDelete(id1);
    ObjectCreate(id1, OBJ_HLINE, 0, time, price);
    ObjectSet(id1, OBJPROP_COLOR, clrAqua);

    ObjectDelete(id2);
    ObjectCreate(id2, OBJ_VLINE, 0, time, price);
    ObjectSet(id2, OBJPROP_COLOR, clrAqua);
    //  }
}

void drawVLine(long chartId, int shift, string id = "", int clr = clrAqua)
{
    string symbol = ChartSymbol(chartId);
    datetime time = iTime(symbol, lower_timeframe, shift);
    double price = iOpen(symbol, lower_timeframe, shift);

    string id2 = "liberty_v_" + IntegerToString(chartId) + "_" + id;

    // ObjectDelete(id2);
    ObjectCreate(chartId, id2, OBJ_VLINE, 0, time, price);
    ObjectSetInteger(chartId, id2, OBJPROP_COLOR, clr);
}

void drawHLine(long chartId, double price, string id = "", int clr = clrAqua)
{
    string symbol = ChartSymbol(chartId);
    datetime time = iTime(symbol, lower_timeframe, 0);

    string id2 = "liberty_h_" + IntegerToString(chartId) + "_" + id;

    // ObjectDelete(id2);
    ObjectCreate(chartId, id2, OBJ_HLINE, 0, time, price);
    ObjectSetInteger(chartId, id2, OBJPROP_COLOR, clr);
}

void drawArrowObj(long chartId, int shift, bool up = true, string id = "", int clr = clrAqua)
{
    string symbol = ChartSymbol(chartId);
    datetime time = iTime(symbol, lower_timeframe, shift);
    double price = up ? iLow(symbol, lower_timeframe, shift) : iHigh(symbol, lower_timeframe, shift);
    const double increment = MarketInfo(symbol, MODE_POINT) * 100;
    price = up ? price - increment : price + increment;
    int obj = up ? OBJ_ARROW_UP : OBJ_ARROW_DOWN;

    string id2 = "liberty_arrow_" + IntegerToString(chartId) + "_" + id;

    // ObjectDelete(id2);
    ObjectCreate(chartId, id2, obj, 0, time, price);
    ObjectSetInteger(chartId, id2, OBJPROP_COLOR, clr);
    ObjectSetInteger(chartId, id2, OBJPROP_WIDTH, 5);
}

void drawValidationObj(long chartId, int shift, bool up = true, bool valid = true, string id = "", int clr = C'9,255,9')
{
    string symbol = ChartSymbol(chartId);
    datetime time = iTime(symbol, lower_timeframe, shift);
    double price = up ? iLow(symbol, lower_timeframe, shift) : iHigh(symbol, lower_timeframe, shift);
    const double increment = MarketInfo(symbol, MODE_POINT) * 200;
    price = up ? price - increment : price + increment;
    int obj = valid ? OBJ_ARROW_CHECK : OBJ_ARROW_STOP;

    string id2 = "liberty_validation_" + IntegerToString(chartId) + "_" + id;

    // ObjectDelete(id2);
    ObjectCreate(chartId, id2, obj, 0, time, price);
    ObjectSetInteger(chartId, id2, OBJPROP_COLOR, clr);
    ObjectSetInteger(chartId, id2, OBJPROP_WIDTH, 5);
}

long findSymbolChart(string symbol)
{
    long chartId = ChartFirst();

    while (chartId > 0)
    {
        if (ChartSymbol(chartId) == symbol)
        {
            return chartId;
        }
        chartId = ChartNext(chartId);
    }

    return -1;
}
//+------------------------------------------------------------------+

void deleteObjectsAll(long chartId)
{
    ObjectsDeleteAll(chartId, "liberty_arrow_", 0);
    ObjectsDeleteAll(chartId, "liberty_v_", 0);
    ObjectsDeleteAll(chartId, "liberty_h_", 0);
    ObjectsDeleteAll(chartId, "liberty_validation_", 0);
    // ObjectsDeleteAll(0, OBJ_ARROW_DOWN);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
void breakPoint()
{
    if (IsVisualMode() && IsTesting())
    {
        keybd_event(19, 0, 0, 0);
        Sleep(100);
        keybd_event(19, 0, 2, 0);
    }
}

void simulate(string symbol, ENUM_TIMEFRAMES low_tf, int groupIndex)
{
    if (EnableSimulation)
    {

        if (symbol != "")
        {
            long chartId = findSymbolChart(symbol);
            if (chartId > 0)
            {

                HigherTFCrossCheckResult maCross = findHigherTimeFrameMACross(symbol, higher_timeframe);
                if (maCross.found)
                {
                    deleteObjectsAll(chartId);
                    drawVLine(chartId, maCross.crossCandleShift, "Order_" + IntegerToString(maCross.crossCandleShift), clrBlanchedAlmond);

                    int firstAreaTouchShift = findAreaTouch(symbol, higher_timeframe, maCross.orderEnvironment, maCross.crossCandleShift, low_tf);

                    if (firstAreaTouchShift > 0 && maCross.orderEnvironment != ENV_NONE)
                    {

                        SignalResult signals[];
                        listSignals(signals, symbol, low_tf, maCross.orderEnvironment, firstAreaTouchShift);

                        int listSize = ArraySize(signals);
                        for (int i = 0; i < listSize; i++)
                        {
                            SignalResult item = signals[i];

                            OrderInfoResult orderCalculated;

                            double hsColor = C'60,167,17';
                            double lsColor = C'249,0,0';
                            int orderColor = clrAqua;
                            double depthOfMoveColor = C'207,0,249';

                            const int active = ActiveSignalForTest;

                            if (i == active)
                            {
                                lsColor = C'255,230,6';
                                orderColor = clrGreen;
                                depthOfMoveColor = C'249,0,0';
                                drawVLine(chartId, item.maChangeShift, IntegerToString(item.maChangeShift) + "test", orderColor);
                            }

                            // drawVLine(item.moveDepthShift, IntegerToString(item.moveDepthShift), depthOfMoveColor);

                            if (maCross.orderEnvironment == ENV_SELL && item.highestShift > -1)
                            {
                                // drawArrowObj(item.highestShift, false, IntegerToString(item.highestShift), hsColor);

                                double virtualPrice = iLow(symbol, low_tf, item.maChangeShift);
                                orderCalculated = calculeOrderPlace(symbol, low_tf, maCross.orderEnvironment, item.maChangeShift, item.highestShift, virtualPrice);
                            }
                            else if (maCross.orderEnvironment == ENV_BUY && item.lowestShift > -1)
                            {
                                // drawArrowObj(item.lowestShift, true, IntegerToString(item.lowestShift), lsColor);

                                double virtualPrice = iHigh(symbol, low_tf, item.maChangeShift);
                                orderCalculated = calculeOrderPlace(symbol, low_tf, maCross.orderEnvironment, item.maChangeShift, item.lowestShift, virtualPrice);
                            }

                            drawArrowObj(chartId, item.maChangeShift, maCross.orderEnvironment == ENV_BUY, IntegerToString(item.maChangeShift), orderColor);

                            // drawVLine(item.lowestShift, IntegerToString(item.lowestShift), C'207,249,0');

                            int validIndex = findMostValidSignalIndex(symbol, low_tf, maCross.orderEnvironment, signals);
                            SignalResult mostValidSignal = signals[validIndex];
                            drawVLine(chartId, mostValidSignal.maChangeShift, "most_valid_" + IntegerToString(validIndex), clrBlueViolet);
                            orderCalculated = validateOrderDistance(symbol, low_tf, maCross.orderEnvironment, firstAreaTouchShift, -1, signals, i, false);
                            SignalResult validatedSignalItem = signals[i];
                            // Try to find an invalid order before last signal
                            // for (int sIdx = 0; sIdx < i; sIdx++)
                            // {
                            //     OrderInfoResult validatedOrder = validateOrderDistance(symbol, low_tf, maCross.orderEnvironment, firstAreaTouchShift, signals, sIdx);
                            //     if (validatedOrder.valid == false)
                            //     {
                            //         orderCalculated.valid = false;
                            //         break;
                            //     }
                            // }

                            int validationColor = orderCalculated.valid ? C'9,255,9' : C'249,92,92';
                            if (!orderCalculated.valid && validatedSignalItem.valid)
                            {
                                validationColor = C'249,194,92';
                            }
                            drawValidationObj(chartId, item.maChangeShift, maCross.orderEnvironment == ENV_BUY, item.valid || validatedSignalItem.valid, IntegerToString(item.maChangeShift), validationColor);

                            if (i == active && ShowTP_SL)
                            {
                                string id = IntegerToString(i);
                                drawHLine(chartId, orderCalculated.orderPrice, "_order_" + id, orderCalculated.pending ? C'245,46,219' : C'0,191,73');
                                drawHLine(chartId, orderCalculated.slPrice, "_sl_" + id, C'255,5,5');
                                drawHLine(chartId, orderCalculated.tpPrice, "_tp_" + id, C'0,119,255');
                            }
                        }
                    }
                }
            }
        }
    }
    else if (ClearObjects)
    {
        long chartId = findSymbolChart(symbol);
        deleteObjectsAll(chartId);
    }
}

void orderLinesSimulation()
{
    if (EnableSimulation && ShowLinesForOpenedOrders)
    {
        int total = OrdersTotal();
        for (int pos = 0; pos < total; pos++)
        {
            if (OrderSelect(pos, SELECT_BY_POS) == false)
                continue;

            long chartId = findSymbolChart(OrderSymbol());
            if (chartId > 0)
            {
                int openShift = iBarShift(OrderSymbol(), lower_timeframe, OrderOpenTime());
                drawVLine(chartId, openShift, "active_order_open_" + IntegerToString(openShift), C'10,203,155');
            }
        }

        int i, hstTotal = OrdersHistoryTotal();
        for (i = 0; i < hstTotal; i++)
        {
            //---- check selection result
            if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) == false)
            {
                continue;
            }

            long chartId = findSymbolChart(OrderSymbol());
            if (chartId > 0)
            {
                int openShift = iBarShift(OrderSymbol(), lower_timeframe, OrderOpenTime());
                drawVLine(chartId, openShift, "history_order_open_" + IntegerToString(openShift), isOpPending(OrderType()) ? C'135,97,1' : C'255,230,0');
            }
        }
    }
}