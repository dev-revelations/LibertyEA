//+------------------------------------------------------------------+
//|                                                      Liberty.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

extern ENUM_TIMEFRAMES higher_timeframe = PERIOD_H4;

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

struct HigherTFCrossCheckResult
{
  OrderEnvironment orderEnvironment;
  datetime crossTime;
  double crossOpenPrice;
  int crossCandleShift;
  ENUM_TIMEFRAMES crossCandleShiftTimeframe;
  bool found;

  HigherTFCrossCheckResult()
  {
  }
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  //---

  //---
  return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  //---
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  //---

  // HigherTFCrossCheckResult maCross = findHigherTimeFrameMACross(_Symbol, higher_timeframe);
  // if (maCross.found)
  // {
  //   int areaTouchShift = findAreaTouch(_Symbol, higher_timeframe, maCross.orderEnvironment, maCross.crossCandleShift, PERIOD_CURRENT);

  //   if (areaTouchShift >= 0)
  //   {
  //     datetime time = iTime(_Symbol, PERIOD_CURRENT, areaTouchShift);
  //     double price = iOpen(_Symbol, PERIOD_CURRENT, areaTouchShift);
  //     drawCross(time, price);
  //   }
  // }
  MaDirection maDir = checkLowerMaChange(_Symbol, PERIOD_CURRENT);
  Print("MaDir = " + (maDir == MA_UP ? "UP" : "Down"));
}
//+------------------------------------------------------------------+

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
    result.crossCandleShiftTimeframe = Period();

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

MaDirection checkLowerMaChange(string symbol, ENUM_TIMEFRAMES lower_tf, int scanRange = 200)
{
  const int limit = scanRange + 1;
  double LineUp[200], LineDown[200];
  ArrayResize(LineUp, limit);
  ArrayFill(LineUp, 0, limit - 1, -1);
  ArrayResize(LineDown, limit);
  ArrayFill(LineDown, 0, limit - 1, -1);

  int lastLine = 1;

  int i = limit - 2;
  // int limit = ;

  MaDirection result = MA_NONE;
  int lastChangeShift = -1;

  // Before current candle means the change in color is being fixed
  while (i >= 1)
  {
    double MA_0 = getMA(symbol, lower_tf, 10, i),
           MA_2 = getMA(symbol, lower_tf, 10, i + 1);

    int lastLineTemp = lastLine;
    if (MA_0 >= MA_2)
    {
      LineUp[i] = MA_0;
      LineUp[i + 1] = MA_2;
      lastLine = 1;
    }

    if (MA_0 <= MA_2)
    {
      LineDown[i] = MA_0;
      LineDown[i + 1] = MA_2;
      lastLine = 2;
    }

    if (lastLine == 1)
    {
      LineUp[i] = MA_0;
    }
    else
    {
      LineDown[i] = MA_0;
    }

    i--;
  }

  if (LineUp[1] != -1 && LineDown[1] == -1)
  {
    result = MA_UP;
  }

  if (LineUp[1] == -1 && LineDown[1] != -1)
  {
    result = MA_DOWN;
  }

  // int lineToScan = LineUp[1] == -1 ? 1 : 2;

  // for (int j = 1; j < limit; j++)
  // {
  //   if (lineToScan == 1 && LineUp[j] != -1)
  //   {
  //     result = MA_DOWN;
  //     lastChangeShift = j;
  //     break;
  //   }

  //   if (lineToScan == 2 && LineDown[j] != -1)
  //   {
  //     result = MA_UP;
  //     lastChangeShift = j;
  //     break;
  //   }
  // }

  // if (lastChangeShift > -1)
  // {
  //   datetime time = iTime(_Symbol, PERIOD_CURRENT, lastChangeShift);
  //   double price = iOpen(_Symbol, PERIOD_CURRENT, lastChangeShift);
  //   drawCross(time, price);
  // }
  return result;
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
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
