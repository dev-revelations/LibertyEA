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

  HigherTFCrossCheckResult maCross = findHigherTimeFrameMACross(_Symbol, higher_timeframe);
  if (maCross.found)
  {
    int firstAreaTouchShift = findAreaTouch(_Symbol, higher_timeframe, maCross.orderEnvironment, maCross.crossCandleShift, PERIOD_CURRENT);

    if (firstAreaTouchShift > 0)
    {

      int maDirChangeList[];

      listLowMaDirChanges(maDirChangeList, _Symbol, PERIOD_CURRENT, maCross.orderEnvironment, firstAreaTouchShift);
      int listSize = ArraySize(maDirChangeList);

      ObjectsDeleteAll(0, OBJ_VLINE);

      for (int i = 0; i < listSize; i++)
      {
        int maChangePoint = maDirChangeList[i];
        drawVLine(maChangePoint, IntegerToString(maChangePoint));

        // 2 vahed check mishavad ta balatarin ya payintarin noghteye ehtemalie akhir peyda shavad
        int highestLowestPrice = -1;
        int highestLowestPrice1 = -1;
        int highestLowestPrice2 = -1;
        int nextMaChangePoint1 = i < listSize - 1 ? maDirChangeList[i + 1] : 0;
        int currentToNextCount1 = MathAbs(maChangePoint - nextMaChangePoint1);
        int nextMaChangePoint2 = i < listSize - 2 ? maDirChangeList[i + 2] : 0;
        int currentToNextCount2 = MathAbs(maChangePoint - nextMaChangePoint2);
        if (maCross.orderEnvironment == ENV_SELL)
        {
          highestLowestPrice1 = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, currentToNextCount1, nextMaChangePoint1); // findLow(_Symbol, PERIOD_CURRENT, maChangePoint);
          highestLowestPrice2 = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, currentToNextCount2, nextMaChangePoint2);
          highestLowestPrice = MathMin(highestLowestPrice1, highestLowestPrice2);
        }
        else if (maCross.orderEnvironment == ENV_BUY)
        {
          highestLowestPrice1 = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, currentToNextCount1, nextMaChangePoint1); // findHigh(_Symbol, PERIOD_CURRENT, maChangePoint);
          highestLowestPrice2 = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, currentToNextCount2, nextMaChangePoint2);
          highestLowestPrice = MathMax(highestLowestPrice1, highestLowestPrice2);
        }
        if (highestLowestPrice != -1)
        {
          drawVLine(highestLowestPrice, IntegerToString(highestLowestPrice), clrBlue);
          // Calculate price difference from entrance point
        }
      }
    }
  }
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
        if (maResult.lastChangeShift != lastChangePoint)
        {
          itemCount++;
          ArrayResize(list, itemCount);
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
  const int limit = scanRange + 1;
  double LineUp[], LineDown[];
  ArrayResize(LineUp, limit);
  ArrayFill(LineUp, 0, limit - 1, -1);
  ArrayResize(LineDown, limit);
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
      result.lastChangeShift = j - 1;
      break;
    }

    if (lineToScan == 2 && LineDown[j] != VALUE_NULL && LineUp[j] == VALUE_BOTH)
    {
      // result.dir = MA_UP;
      result.lastChangeShift = j - 1;
      break;
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

void drawVLine(int shift, string id = "", double clr = clrAqua)
{
  datetime time = iTime(_Symbol, PERIOD_CURRENT, shift);
  double price = iOpen(_Symbol, PERIOD_CURRENT, shift);

  string id2 = "liberty_v_" + id;

  // ObjectDelete(id2);
  ObjectCreate(id2, OBJ_VLINE, 0, time, price);
  ObjectSet(id2, OBJPROP_COLOR, clr);
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