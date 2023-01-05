//+------------------------------------------------------------------+
//|                                                      Liberty.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

#include <WinUser32.mqh>

extern ENUM_TIMEFRAMES higher_timeframe = PERIOD_H4;
extern bool Enable_MA_Closing = false;                // Enable MA Closing Detection
extern double MA_Closing_AverageCandleSize_Ratio = 2; // MA closing ratio in Average Candle Size
extern int MA_Closing_Delay = 2;                      // Number of higher TF candles should wait
extern string _separator2 = "===================";    // ===== Order Settings =====
extern double RiskPercent = 1;
extern double TakeProfitRatio = 3;
// extern double StoplossGapInPip = 2;
extern double StopLossGapInAverageCandleSize = 0.2;
extern double AverageCandleSizeRatio = 2.25;
extern int AverageCandleSizePeriod = 40;
extern int PendingsExpirationMinutes = 120;
extern int MagicNumber = 1111;
extern string CommentText = "";
extern string _separator3 = "==================="; // ===== Lower TF Settings =====
extern bool OnlyMaCandleBreaks = true;             // Shohld candle break MA?
extern string _separator5 = "==================="; // ===== Test & Simulation =====
extern bool EnableSimulation = false;
extern int ActiveSignalForTest = 0;

enum OrderEnvironment
{
  ENV_NONE,
  ENV_BUY,
  ENV_SELL
};

enum MaDirection
{
  MA_NONE,
  MA_UP,
  MA_DOWN
};

struct LowMaChangeResult
{
  MaDirection dir;
  int lastChangeShift;

  LowMaChangeResult()
  {
  }
};

struct SignalResult
{
  int maChangeShift;  // Noghteye taghir
  int highestShift;   // Agar sell hast balatarin noghte ghable vorod
  int lowestShift;    // Agar buy hast payintarin noghte ghable vorod
  int moveDepthShift; // Cheghadr move zade
  SignalResult() {}
};

struct HigherTFCrossCheckResult
{
  OrderEnvironment orderEnvironment;
  datetime crossTime;
  double crossOpenPrice;
  int crossCandleShift;
  ENUM_TIMEFRAMES crossCandleShiftTimeframe;
  bool found;
  int crossCandleHigherTfShift;

  HigherTFCrossCheckResult()
  {
    found = false;
    crossCandleHigherTfShift = -1;
  }
};

struct OrderInfoResult
{
  double slPrice;
  double tpPrice;
  double orderPrice;        // Final decision
  double pendingOrderPrice; // Calculated pending price
  double originalPrice;     // Original price before any decision
  bool pending;
  bool valid;
  OrderInfoResult()
  {
    slPrice = -1;
    tpPrice = -1;
    orderPrice = -1;
    pendingOrderPrice = -1;
    originalPrice = -1;
    pending = false;
    valid = false;
  }
};
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  //---
  EventSetTimer(2);
  //---
  return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  //---
  EventKillTimer();
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  //---

  runStrategy1(_Symbol, PERIOD_M5, higher_timeframe);
}
//+------------------------------------------------------------------+
void OnTimer()
{
  OnTick();
}

void runStrategy1(string symbol, ENUM_TIMEFRAMES lowTF, ENUM_TIMEFRAMES highTF)
{
  HigherTFCrossCheckResult maCross = findHigherTimeFrameMACross(symbol, highTF);
  if (maCross.found)
  {

    const bool canCheckSignals = proccessOrders(symbol, maCross.crossTime);

    if (!canCheckSignals)
    {
      return;
    }

    int firstAreaTouchShift = findAreaTouch(symbol, highTF, maCross.orderEnvironment, maCross.crossCandleShift, PERIOD_CURRENT);

    if (firstAreaTouchShift > 0 && maCross.orderEnvironment != ENV_NONE)
    {
      SignalResult signals[];
      listSignals(signals, symbol, lowTF, maCross.orderEnvironment, firstAreaTouchShift);

      if (EnableSimulation)
      {
        simulate(symbol, lowTF, maCross, firstAreaTouchShift, signals);
        drawVLine(maCross.crossCandleShift, "Order_" + IntegerToString(maCross.crossCandleShift), clrBlanchedAlmond);
      }

      int signalsCount = ArraySize(signals);
      if (signalsCount > 0)
      {
        int lastSignalIndex = signalsCount - 1;
        SignalResult lastSignal = signals[lastSignalIndex];
        // Validate Signal
        OrderInfoResult orderCalculated = signalToOrderInfo(symbol, lowTF, maCross.orderEnvironment, lastSignal);
        orderCalculated = validateOrderDistance(symbol, lowTF, maCross.orderEnvironment, signals, lastSignalIndex);
        if (lastSignal.maChangeShift >= 0 && lastSignal.maChangeShift <= 2 && orderCalculated.valid)
        {
          // open signal
          if (!orderCalculated.pending)
          {
            if (maCross.orderEnvironment == ENV_SELL)
            {
              orderCalculated.orderPrice = MarketInfo(symbol, MODE_BID);
            }
            else if (maCross.orderEnvironment == ENV_BUY)
            {
              orderCalculated.orderPrice = MarketInfo(symbol, MODE_ASK);
            }
            orderCalculated.pending = false;
          }

          Print("Is Pending = ", orderCalculated.pending);

          Order(symbol, maCross.orderEnvironment, orderCalculated);

          drawVLine(0, "Order_" + IntegerToString(lastSignal.maChangeShift), clrOrange);
          // breakPoint();
        }
      }
    }
  }
}

HigherTFCrossCheckResult findHigherTimeFrameMACross(string symbol, ENUM_TIMEFRAMES higherTF)
{
  HigherTFCrossCheckResult result;

  result.found = false;
  result.orderEnvironment = ENV_NONE;

  for (int i = 0; i < Bars - 1; i++)
  {

    int actualShift = getShift(symbol, higherTF, i);

    if (actualShift < 0)
      Print("Shift Error");

    double MA5_current = getMA(symbol, higherTF, 5, actualShift);
    double MA5_prev = getMA(symbol, higherTF, 5, actualShift + 1);

    double MA10_current = getMA(symbol, higherTF, 10, actualShift);
    double MA10_prev = getMA(symbol, higherTF, 10, actualShift + 1);

    // Only Current TimeFrame data
    int higherTFBeginningInCurrentPeriod = i + (int)(higherTF / Period()) - 1;
    datetime currentShiftTime = iTime(symbol, PERIOD_CURRENT, higherTFBeginningInCurrentPeriod);
    double price = iOpen(symbol, PERIOD_CURRENT, higherTFBeginningInCurrentPeriod);

    result.crossOpenPrice = price;
    result.crossTime = currentShiftTime;
    result.crossCandleShift = higherTFBeginningInCurrentPeriod;
    result.crossCandleShiftTimeframe = (ENUM_TIMEFRAMES)Period();
    result.crossCandleHigherTfShift = actualShift;

    if (MA5_prev > MA10_prev && MA5_current < MA10_current)
    {
      // SELL
      // Alert("Sell");

      result.orderEnvironment = ENV_SELL;
      result.found = true;
      break;
    }
    else if (MA5_prev < MA10_prev && MA5_current > MA10_current)
    {
      // BUY
      // Alert(MA5_current);
      result.orderEnvironment = ENV_BUY;
      result.found = true;
      break;
    }
  }

  // last validation
  if (result.found && Enable_MA_Closing)
  {
    double MA5_current = iMA(symbol, higherTF, 5, 0, MODE_SMA, PRICE_CLOSE, 0); // getMA(symbol, higherTF, 5, 0);
    double MA5_prev = iMA(symbol, higherTF, 5, 0, MODE_SMA, PRICE_CLOSE, 1);    // getMA(symbol, higherTF, 5, 1);

    double MA10_current = iMA(symbol, higherTF, 10, 0, MODE_SMA, PRICE_CLOSE, 0); // getMA(symbol, higherTF, 10, 0);
    double MA10_prev = iMA(symbol, higherTF, 10, 0, MODE_SMA, PRICE_CLOSE, 1);    // getMA(symbol, higherTF, 10, 1);

    const bool buyValidation = (MA5_current > MA10_current);
    const bool sellValidation = (MA5_current < MA10_current);

    if (MA5_current > MA10_current)
    {
      result.orderEnvironment = ENV_BUY;
    }
    else if (MA5_current < MA10_current)
    {
      result.orderEnvironment = ENV_SELL;
    }
    else
    {
      result.orderEnvironment = ENV_NONE;
    }

    // If more than two higher TF candle passed
    // We will check how close the MAs are
    // If closer than defined ratio, then it will change the environment to NONE
    if (result.crossCandleHigherTfShift > MA_Closing_Delay)
    {
      const double averageCandle = averageCandleSize(symbol, PERIOD_M5, 0, AverageCandleSizePeriod);
      const double distanceRatio = averageCandle * MA_Closing_AverageCandleSize_Ratio;
      const double MAsDistance = MathAbs(MA10_current - MA5_current);

      if (MAsDistance <= distanceRatio)
      {
        result.orderEnvironment = ENV_NONE;
      }
    }
  }

  return result;
}

bool isAreaTouched(string symbol, ENUM_TIMEFRAMES higherTF, OrderEnvironment orderEnv, int shift, ENUM_TIMEFRAMES lower_tf)
{
  int actualHigherShift = getShift(symbol, higherTF, shift);

  if (actualHigherShift >= 0)
  {
    double h4_ma5 = getMA(symbol, higherTF, 5, actualHigherShift);
    if (orderEnv == ENV_SELL)
    {
      double m5_high = iHigh(symbol, lower_tf, shift);
      if (m5_high >= h4_ma5)
      {
        return true;
      }
    }

    if (orderEnv == ENV_BUY)
    {
      double m5_low = iLow(symbol, lower_tf, shift);
      if (m5_low <= h4_ma5)
      {
        return true;
      }
    }
  }
  return false;
}

int findAreaTouch(string symbol, ENUM_TIMEFRAMES higherTF, OrderEnvironment orderEnv, int scanLimitShift, ENUM_TIMEFRAMES lower_tf)
{

  for (int i = scanLimitShift; i >= 0; i--)
  {
    bool touched = isAreaTouched(symbol, higherTF, orderEnv, i, lower_tf);
    if (touched)
    {
      return i;
    }
  }

  return -1;
}

void listLowMaDirChanges(int &list[], string symbol, ENUM_TIMEFRAMES lowTF, OrderEnvironment orderEnv, int firstAreaTouchShift)
{
  MaDirection maAnswer = MA_NONE;
  if (orderEnv == ENV_SELL)
  {
    maAnswer = MA_DOWN;
  }
  else if (orderEnv == ENV_BUY)
  {
    maAnswer = MA_UP;
  }

  int itemCount = 0;

  // We check if the first touch itself has the condition of a signal or not
  if (firstAreaTouchShift >= 1)
  {
    LowMaChangeResult firstTouchMa = getLowerMaDirection(symbol, lowTF, firstAreaTouchShift - 1);
    bool isSignal = (orderEnv == ENV_SELL && firstTouchMa.dir == MA_DOWN) || (orderEnv == ENV_BUY && firstTouchMa.dir == MA_UP);
    if (isSignal)
    {
      itemCount++;
      ArrayResize(list, itemCount, 1000);
      list[0] = firstAreaTouchShift;
    }
  }

  for (int i = firstAreaTouchShift - 1; i > 0; i--)
  {
    LowMaChangeResult maResult = getLowerMaDirection(symbol, lowTF, i, firstAreaTouchShift + 1);
    if (maResult.dir == maAnswer)
    {

      // Baraye inke motmaen shavim taghire rang/jahate sahih anjam shode ast
      LowMaChangeResult maPrevResult = getLowerMaDirection(symbol, lowTF, i + 1, firstAreaTouchShift + 1);
      LowMaChangeResult maNextResult = getLowerMaDirection(symbol, lowTF, i - 1, firstAreaTouchShift + 1);
      if (maPrevResult.dir != maAnswer && maNextResult.dir == maAnswer)
      {
        // To azvoid adding redundant data
        int lastChangePoint = itemCount > 0 ? list[itemCount - 1] : -1;
        if (maResult.lastChangeShift != lastChangePoint && maResult.lastChangeShift <= firstAreaTouchShift)
        {
          itemCount++;
          ArrayResize(list, itemCount, 1000);
          list[itemCount - 1] = maResult.lastChangeShift;
        }
      }
    }
  }
}

LowMaChangeResult getLowerMaDirection(string symbol, ENUM_TIMEFRAMES lower_tf, int startFromShift = 1, int scanRange = 200)
{
  const int VALUE_UP = 1;
  const int VALUE_DOWN = 2;
  const int VALUE_NULL = -1;
  const int VALUE_BOTH = 3;
  const int limit = scanRange + startFromShift;
  double LineUp[], LineDown[];
  ArrayResize(LineUp, limit, 1000);
  ArrayFill(LineUp, 0, limit - 1, -1);
  ArrayResize(LineDown, limit, 1000);
  ArrayFill(LineDown, 0, limit - 1, -1);

  int lastLine = 1;

  int i = limit - 2;

  LowMaChangeResult result;
  result.dir = MA_NONE;
  result.lastChangeShift = -1;

  // Before current candle means the change in color is being fixed
  while (i >= startFromShift)
  {
    double MA_0 = getMA(symbol, lower_tf, 10, i),
           MA_2 = getMA(symbol, lower_tf, 10, i + 1);

    int lastLineTemp = lastLine;
    if (MA_0 > MA_2)
    {
      LineUp[i] = VALUE_UP;
      LineUp[i + 1] = VALUE_BOTH;
      lastLine = 1;
    }

    if (MA_0 < MA_2)
    {
      LineDown[i] = VALUE_DOWN;
      LineDown[i + 1] = VALUE_BOTH;
      lastLine = 2;
    }

    // intersection
    if (lastLine == 1)
    {
      LineUp[i] = VALUE_BOTH;
      LineDown[i] = VALUE_NULL;
    }
    else
    {
      LineDown[i] = VALUE_BOTH;
      LineUp[i] = VALUE_NULL;
    }

    i--;
  }

  if (LineUp[startFromShift] != VALUE_NULL && LineDown[startFromShift] == VALUE_NULL)
  {
    result.dir = MA_UP;
  }

  if (LineUp[startFromShift] == VALUE_NULL && LineDown[startFromShift] != VALUE_NULL)
  {
    result.dir = MA_DOWN;
  }

  int lineToScan = LineUp[startFromShift] == VALUE_NULL ? 1 : 2;

  for (int j = startFromShift; j < limit; j++)
  {
    if (lineToScan == 1 && LineUp[j] != VALUE_NULL && LineDown[j] == VALUE_NULL)
    {
      // result.dir = MA_DOWN;
      if (OnlyMaCandleBreaks)
      {
        for (int k = j; k >= startFromShift; k--)
        {
          double MA_10 = getMA(symbol, lower_tf, 10, k);
          double open = iOpen(symbol, lower_tf, k);
          double close = iClose(symbol, lower_tf, k);
          if (close < MA_10 && LineUp[startFromShift] == VALUE_NULL && LineDown[startFromShift] != VALUE_NULL)
          {
            result.lastChangeShift = k; // - 2;
            break;
          }
        }

        if (result.lastChangeShift > -1)
        {
          break;
        }
      }
      else
      {
        result.lastChangeShift = j - 2;
        break;
      }
    }

    if (lineToScan == 2 && LineDown[j] != VALUE_NULL && LineUp[j] == VALUE_BOTH)
    {
      // result.dir = MA_UP;
      if (OnlyMaCandleBreaks)
      {
        for (int k = j; k >= startFromShift; k--)
        {
          double MA_10 = getMA(symbol, lower_tf, 10, k);
          double open = iOpen(symbol, lower_tf, k);
          double close = iClose(symbol, lower_tf, k);
          if (close > MA_10 && LineUp[k] != VALUE_NULL && LineDown[k] == VALUE_NULL)
          {
            result.lastChangeShift = k; // - 2;
            break;
          }
        }

        if (result.lastChangeShift > -1)
        {
          break;
        }
      }
      else
      {
        result.lastChangeShift = j - 1;
        break;
      }
    }
  }

  // if (lastChangeShift > -1)
  // {
  //   datetime time = iTime(_Symbol, PERIOD_CURRENT, lastChangeShift);
  //   double price = iOpen(_Symbol, PERIOD_CURRENT, lastChangeShift);
  //   drawCross(time, price);
  // }
  return result;
}

bool checkLowerMaBreak(string symbol, ENUM_TIMEFRAMES lower_tf, OrderEnvironment orderEnv)
{
  double MA_10 = getMA(symbol, lower_tf, 10, 0);
  int mode = orderEnv == ENV_BUY ? MODE_ASK : MODE_BID;
  double price = MarketInfo(symbol, mode);

  bool buyMaBreak = (orderEnv == ENV_BUY && price > MA_10);

  bool sellMaBreak = (orderEnv == ENV_SELL && price < MA_10);

  return buyMaBreak || sellMaBreak;
}

void listSignals(SignalResult &list[], string symbol, ENUM_TIMEFRAMES lowTF, OrderEnvironment orderEnv, int firstAreaTouchShift)
{
  int maDirChangeList[];
  listLowMaDirChanges(maDirChangeList, symbol, lowTF, orderEnv, firstAreaTouchShift);
  int listSize = ArraySize(maDirChangeList);

  ArrayResize(list, listSize, 1000);

  for (int i = 0; i < listSize; i++)
  {
    SignalResult item;
    item.maChangeShift = maDirChangeList[i];
    item.highestShift = -1;
    item.lowestShift = -1;
    item.moveDepthShift = -1;

    // Find Highest/Lowest candle that belongs to the move as part of the signal
    // 2 vahed check mikonim

    int candleCountBetween = MathAbs(firstAreaTouchShift - item.maChangeShift) + 1;

    if (orderEnv == ENV_SELL)
    {
      item.highestShift = iHighest(symbol, lowTF, MODE_HIGH, candleCountBetween, item.maChangeShift);
    }
    else if (orderEnv == ENV_BUY)
    {
      item.lowestShift = iLowest(symbol, lowTF, MODE_HIGH, candleCountBetween, item.maChangeShift);
    }

    // Find Move Depth

    // 2 vahed check mishavad ta balatarin ya payintarin noghteye ehtemalie akhir peyda shavad
    int maChangePoint = maDirChangeList[i];
    int depthCandle1 = -1;
    int depthCandle2 = -1;
    int nextMaChangePoint1 = i < listSize - 1 ? maDirChangeList[i + 1] : 0;
    int currentToNextCount1 = MathAbs(maChangePoint - nextMaChangePoint1);
    int nextMaChangePoint2 = i < listSize - 2 ? maDirChangeList[i + 2] : 0;
    int currentToNextCount2 = MathAbs(maChangePoint - nextMaChangePoint2);
    if (orderEnv == ENV_SELL)
    {
      depthCandle1 = iLowest(symbol, lowTF, MODE_LOW, currentToNextCount1, nextMaChangePoint1);
      double price1 = iLow(symbol, lowTF, depthCandle1);
      depthCandle2 = iLowest(symbol, lowTF, MODE_LOW, currentToNextCount2, nextMaChangePoint2);
      double price2 = iLow(symbol, lowTF, depthCandle2);
      item.moveDepthShift = price2 < price1 ? depthCandle2 : depthCandle1;
    }
    else if (orderEnv == ENV_BUY)
    {
      depthCandle1 = iHighest(symbol, lowTF, MODE_HIGH, currentToNextCount1, nextMaChangePoint1);
      double price1 = iHigh(symbol, lowTF, depthCandle1);
      depthCandle2 = iHighest(symbol, lowTF, MODE_HIGH, currentToNextCount2, nextMaChangePoint2);
      double price2 = iHigh(symbol, lowTF, depthCandle2);
      item.moveDepthShift = price2 > price1 ? depthCandle2 : depthCandle1;
    }

    list[i] = item;
  }
}

OrderInfoResult calculeOrderPlace(string symbol, ENUM_TIMEFRAMES tf, OrderEnvironment orderEnv, int signalShift, int highestLowestShift, double price)
{
  OrderInfoResult orderInfo;

  double highestLowestPrice = (orderEnv == ENV_SELL)
                                  ? iHigh(symbol, tf, highestLowestShift)
                                  : iLow(symbol, tf, highestLowestShift);

  double averageCandle = averageCandleSize(symbol, tf, signalShift, AverageCandleSizePeriod);
  double scaledCandleSize = averageCandle * AverageCandleSizeRatio;
  // Print("scaledCandleSize = ", scaledCandleSize * (MathPow(10, _Digits - 1)), "  averageCandle = ", averageCandle * (MathPow(10, _Digits - 1)));

  // double gapSizeInPoint = pipToPoint(symbol, StoplossGapInPip);
  double gapSizeInPoint = averageCandle * StopLossGapInAverageCandleSize;

  orderInfo.originalPrice = price;

  if (orderEnv == ENV_SELL)
  {
    orderInfo.slPrice = highestLowestPrice + gapSizeInPoint;

    double stopLossToScaledCandleSize = orderInfo.slPrice - scaledCandleSize;
    orderInfo.pending = (price < stopLossToScaledCandleSize);

    orderInfo.orderPrice = orderInfo.pending ? stopLossToScaledCandleSize : price;
    orderInfo.pendingOrderPrice = stopLossToScaledCandleSize;
    double priceSlDistance = MathAbs(orderInfo.orderPrice - orderInfo.slPrice);
    orderInfo.tpPrice = orderInfo.orderPrice - (priceSlDistance * TakeProfitRatio);
  }
  else if (orderEnv == ENV_BUY)
  {
    orderInfo.slPrice = highestLowestPrice - gapSizeInPoint;

    double stopLossToScaledCandleSize = orderInfo.slPrice + scaledCandleSize;
    orderInfo.pending = (price > stopLossToScaledCandleSize);

    orderInfo.orderPrice = orderInfo.pending ? stopLossToScaledCandleSize : price;
    orderInfo.pendingOrderPrice = stopLossToScaledCandleSize;
    double priceSlDistance = MathAbs(orderInfo.orderPrice - orderInfo.slPrice);
    orderInfo.tpPrice = orderInfo.orderPrice + (priceSlDistance * TakeProfitRatio);
  }

  return orderInfo;
}

OrderInfoResult signalToOrderInfo(string symbol, ENUM_TIMEFRAMES tf, OrderEnvironment orderEnv, SignalResult &signal, bool useVirtualPrice = true)
{
  OrderInfoResult orderCalculated;
  if (orderEnv == ENV_SELL && signal.highestShift > -1)
  {
    double price = useVirtualPrice ? iLow(symbol, tf, signal.maChangeShift) : MarketInfo(symbol, MODE_BID);
    orderCalculated = calculeOrderPlace(symbol, tf, orderEnv, signal.maChangeShift, signal.highestShift, price);
  }
  else if (orderEnv == ENV_BUY && signal.lowestShift > -1)
  {
    double price = useVirtualPrice ? iHigh(symbol, tf, signal.maChangeShift) : MarketInfo(symbol, MODE_ASK);
    orderCalculated = calculeOrderPlace(symbol, tf, orderEnv, signal.maChangeShift, signal.lowestShift, price);
  }
  return orderCalculated;
}

OrderInfoResult validateOrderDistance(string symbol, ENUM_TIMEFRAMES tf, OrderEnvironment orderEnv, SignalResult &signals[], int signalIndexToValidate)
{

  OrderInfoResult indexOrderInfo = signalToOrderInfo(symbol, tf, orderEnv, signals[signalIndexToValidate]);

  if (signalIndexToValidate > 0)
  {
    // Find highest/lowest entry price in the past
    OrderInfoResult mostValidEntry = signalToOrderInfo(symbol, tf, orderEnv, signals[0]);
    int place = 0;
    for (int i = 0; i < signalIndexToValidate; i++)
    {
      SignalResult item = signals[i];
      OrderInfoResult signalOrderInfo = signalToOrderInfo(symbol, tf, orderEnv, item);

      if (orderEnv == ENV_SELL && signalOrderInfo.originalPrice > mostValidEntry.originalPrice)
      {
        mostValidEntry = signalOrderInfo;
        place = i;
      }
      else if (orderEnv == ENV_BUY && signalOrderInfo.originalPrice < mostValidEntry.originalPrice)
      {
        mostValidEntry = signalOrderInfo;
        place = i;
      }
    }

    if (mostValidEntry.orderPrice > -1)
    {
      bool isValidPriceDistance = (orderEnv == ENV_SELL && indexOrderInfo.originalPrice > mostValidEntry.tpPrice) || (orderEnv == ENV_BUY && indexOrderInfo.originalPrice < mostValidEntry.tpPrice);

      // if (signalIndexToValidate == ActiveSignalForTest)
      // {
      //   SignalResult item = signals[place];
      //   drawVLine(item.maChangeShift, IntegerToString(item.maChangeShift), clrRed);

      //   SignalResult sg = signals[signalIndexToValidate];
      //   drawHLine(mostValidEntry.orderPrice, "orderPrice" + IntegerToString(sg.maChangeShift), C'226,195,43');
      //   Print("Order Price = ", indexOrderInfo.orderPrice, " mostTP = ", mostValidEntry.tpPrice, " isValidPriceDistance = ", isValidPriceDistance);
      // }

      // If it is in a valid distance to first entry we will consider that entry as a pending order and replace with current one
      if (isValidPriceDistance)
      {
        // If the highest/lowest found previous signal has higher/lower slPrice will replace it with current signal order info
        bool shohldReplaceOrderInfo = (orderEnv == ENV_SELL && mostValidEntry.slPrice > indexOrderInfo.slPrice) || (orderEnv == ENV_BUY && mostValidEntry.slPrice < indexOrderInfo.slPrice);
        if (shohldReplaceOrderInfo)
        {
          indexOrderInfo = mostValidEntry;
        }
        indexOrderInfo.pending = true;
        indexOrderInfo.valid = true;
      }
    }
    else
    {
      // If nothing found the order itself is valid whatever calculated
      indexOrderInfo.valid = true;
    }
  }
  else
  {
    // if index = 0, the first signal is always valid
    indexOrderInfo.valid = true;
  }

  return indexOrderInfo;
}

double averageCandleSize(string symbol, ENUM_TIMEFRAMES tf, int startShift, int period)
{
  double sum = 0;
  period = startShift == 0 ? period : period + 1;
  int limit = startShift + period;
  for (int i = startShift; i < limit; i++)
  {
    double close = iHigh(symbol, tf, i);
    double open = iLow(symbol, tf, i);

    sum += MathAbs(open - close);
  }

  return (double)(sum / period) /* * (MathPow(10, _Digits-1))*/;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getMA(string symbol, ENUM_TIMEFRAMES timeframe, int periodMA, int shift, bool convertShift = false)
{
  int actualShift = convertShift ? getShift(symbol, timeframe, shift) : shift;

  if (actualShift < 0)
    return -1;

  return iMA(symbol, timeframe, periodMA, 0, MODE_SMA, PRICE_CLOSE, actualShift);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int getShift(string symbol, ENUM_TIMEFRAMES timeframe, int shift)
{
  datetime candleTimeCurrent = iTime(symbol, PERIOD_CURRENT, shift);
  int actualShift = iBarShift(symbol, timeframe, candleTimeCurrent);

  return actualShift;
}

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

int Order(string symbol, OrderEnvironment orderEnv, OrderInfoResult &orderInfo, string comment = "")
{

  int expiration = 0;

  int OP = 0;

  if (orderEnv == ENV_BUY)
  {
    OP = orderInfo.pending ? OP_BUYLIMIT : OP_BUY;
  }
  else if (orderEnv == ENV_SELL)
  {
    OP = orderInfo.pending ? OP_SELLLIMIT : OP_SELL;
  }
  else
  {
    return -1;
  }

  const int digits = (int)MarketInfo(symbol, MODE_DIGITS);
  double price = NormalizeDouble(orderInfo.orderPrice, digits);

  double SL = NormalizeDouble(orderInfo.slPrice, digits);

  double TP = NormalizeDouble(orderInfo.tpPrice, digits);

  if (orderInfo.pending)
  {
    expiration = ((int)TimeCurrent()) + (60 * PendingsExpirationMinutes);
  }

  double LotSize = GetLotSize(symbol, RiskPercent, price, SL);

  return OrderSend(
      symbol,
      OP,
      LotSize,
      price,
      3,
      SL,
      TP,
      comment != "" ? comment : CommentText,
      MagicNumber,
      expiration,
      Green);
}

bool proccessOrders(string symbol, datetime crossTime)
{
  int total = OrdersTotal();
  for (int pos = 0; pos < total; pos++)
  {
    if (OrderSelect(pos, SELECT_BY_POS) == false)
      continue;

    if (symbol == OrderSymbol())
    {
      int orderTime = (int)OrderOpenTime();
      int cross_Time = (int)crossTime;
      if (orderTime < cross_Time)
      {
        int OP = OrderType();
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

        return true;
      }

      return false;
    }
    // FileWrite(handle, OrderTicket(), OrderOpenPrice(), OrderOpenTime(), OrderSymbol(), OrderLots());
  }

  return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

void drawVLine(int shift, string id = "", double clr = clrAqua)
{
  datetime time = iTime(_Symbol, PERIOD_CURRENT, shift);
  double price = iOpen(_Symbol, PERIOD_CURRENT, shift);

  string id2 = "liberty_v_" + id;

  // ObjectDelete(id2);
  ObjectCreate(id2, OBJ_VLINE, 0, time, price);
  ObjectSet(id2, OBJPROP_COLOR, clr);
}

void drawHLine(double price, string id = "", double clr = clrAqua)
{
  datetime time = iTime(_Symbol, PERIOD_CURRENT, 0);

  string id2 = "liberty_h_" + id;

  // ObjectDelete(id2);
  ObjectCreate(id2, OBJ_HLINE, 0, time, price);
  ObjectSet(id2, OBJPROP_COLOR, clr);
}

void drawArrowObj(int shift, bool up = true, string id = "", double clr = clrAqua)
{
  datetime time = iTime(_Symbol, PERIOD_CURRENT, shift);
  double price = up ? iLow(_Symbol, PERIOD_CURRENT, shift) : iHigh(_Symbol, PERIOD_CURRENT, shift);
  const double increment = Point() * 100;
  price = up ? price - increment : price + increment;
  int obj = up ? OBJ_ARROW_UP : OBJ_ARROW_DOWN;

  string id2 = "liberty_arrow_" + id;

  // ObjectDelete(id2);
  ObjectCreate(id2, obj, 0, time, price);
  ObjectSet(id2, OBJPROP_COLOR, clr);
  ObjectSetInteger(0, id2, OBJPROP_WIDTH, 5);
}

void drawValidationObj(int shift, bool up = true, bool valid = true, string id = "", double clr = C'9,255,9')
{
  datetime time = iTime(_Symbol, PERIOD_CURRENT, shift);
  double price = up ? iLow(_Symbol, PERIOD_CURRENT, shift) : iHigh(_Symbol, PERIOD_CURRENT, shift);
  const double increment = Point() * 200;
  price = up ? price - increment : price + increment;
  int obj = valid ? OBJ_ARROW_CHECK : OBJ_ARROW_STOP;

  string id2 = "liberty_validation_" + id;

  // ObjectDelete(id2);
  ObjectCreate(id2, obj, 0, time, price);
  ObjectSet(id2, OBJPROP_COLOR, clr);
  ObjectSetInteger(0, id2, OBJPROP_WIDTH, 5);
}

//+------------------------------------------------------------------+

void deleteObjectsAll()
{
  ObjectsDeleteAll(0, "liberty_arrow_");
  ObjectsDeleteAll(0, "liberty_v_");
  ObjectsDeleteAll(0, "liberty_h_");
  ObjectsDeleteAll(0, "liberty_validation_");
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

void simulate(string symbol, ENUM_TIMEFRAMES tf, HigherTFCrossCheckResult &maCross, int firstAreaTouchShift, SignalResult &signals[])
{
  deleteObjectsAll();
  int listSize = ArraySize(signals);
  for (int i = 0; i < listSize; i++)
  {
    SignalResult item = signals[i];

    OrderInfoResult orderCalculated;

    double hsColor = C'60,167,17';
    double lsColor = C'249,0,0';
    double orderColor = clrAqua;
    double depthOfMoveColor = C'207,0,249';

    const int active = ActiveSignalForTest;

    if (i == active)
    {
      lsColor = C'255,230,6';
      orderColor = clrGreen;
      depthOfMoveColor = C'249,0,0';
      drawVLine(item.maChangeShift, IntegerToString(item.maChangeShift) + "test", orderColor);
    }

    // drawVLine(item.moveDepthShift, IntegerToString(item.moveDepthShift), depthOfMoveColor);

    if (maCross.orderEnvironment == ENV_SELL && item.highestShift > -1)
    {
      // drawArrowObj(item.highestShift, false, IntegerToString(item.highestShift), hsColor);

      double virtualPrice = iLow(_Symbol, PERIOD_CURRENT, item.maChangeShift);
      orderCalculated = calculeOrderPlace(_Symbol, PERIOD_CURRENT, maCross.orderEnvironment, item.maChangeShift, item.highestShift, virtualPrice);
    }
    else if (maCross.orderEnvironment == ENV_BUY && item.lowestShift > -1)
    {
      // drawArrowObj(item.lowestShift, true, IntegerToString(item.lowestShift), lsColor);

      double virtualPrice = iHigh(_Symbol, PERIOD_CURRENT, item.maChangeShift);
      orderCalculated = calculeOrderPlace(_Symbol, PERIOD_CURRENT, maCross.orderEnvironment, item.maChangeShift, item.lowestShift, virtualPrice);
    }

    drawArrowObj(item.maChangeShift, maCross.orderEnvironment == ENV_BUY, IntegerToString(item.maChangeShift), orderColor);

    // drawVLine(item.lowestShift, IntegerToString(item.lowestShift), C'207,249,0');

    orderCalculated = validateOrderDistance(_Symbol, PERIOD_CURRENT, maCross.orderEnvironment, signals, i);

    drawValidationObj(item.maChangeShift, maCross.orderEnvironment == ENV_BUY, orderCalculated.valid, IntegerToString(item.maChangeShift), orderCalculated.valid ? C'9,255,9' : C'249,92,92');

    if (i == active)
    {
      string id = IntegerToString(i);
      drawHLine(orderCalculated.orderPrice, "_order_" + id, orderCalculated.pending ? C'245,46,219' : C'0,191,73');
      drawHLine(orderCalculated.slPrice, "_sl_" + id, C'255,5,5');
      drawHLine(orderCalculated.tpPrice, "_tp_" + id, C'0,119,255');
    }
  }
}