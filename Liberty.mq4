//+------------------------------------------------------------------+
//|                                                      Liberty.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link "https://www.mql5.com"
#property version "1.11"
#property strict

extern bool SingleChart = false;                                         // Single Chart Scan
extern bool EnableEATimer = true;                                        // Enable EA Timer
extern int EATimerSconds = 1;                                            // EA Timer Interval Seconds
extern bool CheckSignalsOnNewCandle = true;                              // Check for signals on new candle openning
extern string _separator1_2 = "======================================="; // ===== Average Candle Size Settings =====
extern int AverageCandleSizePeriod = 40;
extern double PendingThresholdAverageCandleSizeRatio = 2.25;             // Pending Threshold In Average Candle Size Ratio
extern int CustomACSTimeStart = 0;                                       // Custom Pending ACS Start
extern int CustomACSTimeEnd = 7;                                         // Custom Pending ACS End
extern double CustomPendingThresholdAverageCandleSizeRatio = 3.75;       // Custom Time Pending Threshold In Average Candle Size Ratio
extern string _separator1 = "=======================================";   // ===== Higher Timeframe =====
extern ENUM_TIMEFRAMES higher_timeframe = PERIOD_H4;                     // Higher Timeframe
extern int MA_Closing_Delay = 2;                                         // Number of higher TF candles should wait
extern double MA_Touch_Thickness_Ratio = 0.2;                            // Higher MA Touch Thickness Ratio in Average Candle Size
extern double MA_Crossing_Opening_Ratio = 0.5;                           // MA Cross Openning Size Ratio in Average Candle Size
extern double MA_Crossing_Opening_Ratio_Env_Change = 0.2;                // MA Cross Openning Size Ratio For Environment Change in ACS
extern string _separator1_1 = "======================================="; // ===== Lower Timeframe =====
extern ENUM_TIMEFRAMES lower_timeframe = PERIOD_M5;                      // Lower Timeframe (Never select current)
extern bool OnlyMaCandleBreaks = true;                                   // Shohld candle break MA?
extern string _separator2 = "=======================================";   // ===== Order Settings =====
extern int MagicNumber = 1111;
extern double RiskPercent = 1;
extern double TakeProfitRatio = 3;
extern double StopLossGapInAverageCandleSize = 0.2;
// extern double StoplossGapInPip = 2;
extern int PendingsExpirationMinutes = 10000;
extern string CommentText = "";
extern bool EnableBreakEven = true;                                      // Enable Break Even
extern double BreakEvenRatio = 2.65;                                     // Break Even Ratio
extern double BreakEvenGapPip = 2;                                       // Break Even Gap Pip
extern double BuyStopSellStopGapInACS = 0.1;                             // Immediate BuyStop / SellStop Gap in ACS Ratio
extern string _separator4 = "=======================================";   // ===== Sessions (Min = 0 , Max = 24) =====
extern int GMTOffset = 2;                                                // GMT Offset
extern bool EnableTradingSession1 = true;                                // Enable Trading in Session 1
extern int SessionStart1 = 0;                                            // Session Start 1
extern int SessionEnd1 = 17;                                             // Session End 1
extern bool EnableTradingSession2 = false;                               // Enable Trading in Session 2
extern int SessionStart2 = 22;                                           // Session Start 2
extern int SessionEnd2 = 23;                                             // Session End 2
extern bool EnableTradingSession3 = false;                               // Enable Trading in Session 3
extern int SessionStart3 = 22;                                           // Session Start 3
extern int SessionEnd3 = 23;                                             // Session End 3
extern string _separator4_1 = "======================================="; // ===== Custom Groups =====
extern string CustomGroup1 = "TecDE30 F40 UK100 US30 US2000 US500 USTEC";
extern string CustomGroup2 = "XBRUSD";
extern string _separator5 = "======================================="; // ===== Test & Simulation =====
extern bool EnableSimulation = false;
extern bool ClearObjects = false; // Clear Objects If Simulation Is Off
extern int ActiveSignalForTest = 0;
extern bool ShowTP_SL = false;                // Show TP & SL Lines
extern bool ShowLinesForOpenedOrders = false; // Show lines for opened orders

//////////////////////////////////////////////////////////////////////////////
#include <WinUser32.mqh>
#include "Liberty.mqh"
#include "LibertyMA.mqh"
#include "LibertySimulation.mqh"
#include "LibertyOrder.mqh"
#include "LibertySessionTime.mqh"
#include "LibertyPrioritization.mqh"
#include "LibertyOrderManagement.mqh"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  //---
  if (EnableEATimer)
  {
    EventSetTimer(EATimerSconds);
  }
  initializeGroups();
  initializeMAs();
  //---
  return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  //---
  if (EnableEATimer)
  {
    EventKillTimer();
  }
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  //---
  if (!EnableEATimer)
  {
    runEA();
  }
}
//+------------------------------------------------------------------+
void OnTimer()
{
  if (EnableEATimer)
  {
    // OnTick();
    runEA();
  }
}

void runEA()
{
  processOrders();

  orderLinesSimulation();

  if (!IsTradeAllowed())
  {
    return;
  }

  if (minutesPassed())
  {
    initializeMAs();
  }

  if (SingleChart)
  {
    simulate(_Symbol, lower_timeframe, 0);
    runStrategy1(_Symbol, lower_timeframe, higher_timeframe, 0);
  }
  else
  {
    scanSymbolGroups();
  }
}

void scanSymbolGroups()
{
  string activeSymbolsListBuy = "";
  string activeSymbolsListSell = "";

  for (int groupIdx = 0; groupIdx < GROUPS_LENGTH; groupIdx++)
  {

    clearOrderPriorityList();

    GroupStruct group = GROUPS[groupIdx];

    ////////////// Adding Active Symbols to the Comment //////////////

    if (group.active_symbol_buy != "")
    {
      activeSymbolsListBuy += "Group(" + IntegerToString(groupIdx) + ") = " + group.active_symbol_buy + "\n";
    }

    if (group.active_symbol_sell != "")
    {
      activeSymbolsListSell += "Group(" + IntegerToString(groupIdx) + ") = " + group.active_symbol_sell + "\n";
    }

    ////////////// Scanning Symbols In The Current Group //////////////

    for (int symbolIdx = 0; symbolIdx < group.symbols_count; symbolIdx++)
    {
      string symbol = group.symbols[symbolIdx];

      simulate(symbol, lower_timeframe, groupIdx);

      if (IsTesting() && _Symbol != symbol)
      {
        continue;
      }

      if (group.active_symbol_buy != "" && group.active_symbol_sell != "")
      {
        continue;
      }

      if (group.active_symbol_buy == symbol || group.active_symbol_sell == symbol)
      {
        continue;
      }

      // Check for new bars
      if (CheckSignalsOnNewCandle)
      {
        int bars = iBars(symbol, lower_timeframe);
        if (group.bars[symbolIdx] == bars)
        {
          continue;
        }
        else
        {
          group.bars[symbolIdx] = bars;
        }
      }

      RefreshRates();

      StrategyResult result = runStrategy1(symbol, lower_timeframe, higher_timeframe, groupIdx);
      StrategyStatus status = result.status;
      // If for any reason the strategy is locked for the current symbol then we will ignore it
      // In current context it happens when the symbol had profits in pervious sessions and in current crossing
      if (status == STRATEGY_STATUS_LOCKED && group.active_symbol_buy != symbol && group.active_symbol_sell != symbol)
      {
        continue;
      }

      /*
        Agar active symbol ghablan set nashode bud va ya be onvane yek pending set shode bud
        natijeye be dast amade az barresie strategy ra be onvane natijeye candid jahate
        olaviat bandi zakhire mikonim ta morede moghayese ba natayeje ehtemalie digar dar
        gorohe jari gharar begirad
      */
      if ((status == STRATEGY_STATUS_IMMEDIATE_BUY || status == STRATEGY_STATUS_PENDING_BUY))
      {
        if (group.active_symbol_buy == "")
        {
          // group.active_symbol_buy = symbol;
          if (result.orderInfo.valid)
          {
            addOrderPriority(result, OP_BUY);
            debug("Candid added to priority list (BUY)" + symbol);
          }
          else
          {
            debug("Candid WAS NOT VALID for priority list " + symbol);
          }
        }
      }
      else if ((status == STRATEGY_STATUS_IMMEDIATE_SELL || status == STRATEGY_STATUS_PENDING_SELL))
      {
        if (group.active_symbol_sell == "")
        {
          // group.active_symbol_sell = symbol;
          if (result.orderInfo.valid)
          {
            addOrderPriority(result, OP_SELL);
            debug("Candid added to priority list (SELL)" + symbol);
          }
          else
          {
            debug("Candid WAS NOT VALID for priority list " + symbol);
          }
        }
      }
    }

    ////////////// Checking for prioritized candidate order //////////////

    if (group.active_strategy_buy.symbol != "")
      addOrderPriority(group.active_strategy_buy, OP_BUY);

    if (group.active_strategy_sell.symbol != "")
      addOrderPriority(group.active_strategy_sell, OP_SELL);

    openPrioritizedOrdersFor(group, OP_BUY);
    openPrioritizedOrdersFor(group, OP_SELL);

    GROUPS[groupIdx] = group; // Hatman bayad dobare set shavad ta taghirat emal shavad
  }

  Comment(
      "Current Session: " + IntegerToString(getSessionNumber(TimeCurrent())),
      "\nActive Symbols (BUY):\n",
      activeSymbolsListBuy,
      "\nActive Symbols (SELL):\n",
      activeSymbolsListSell);
}

StrategyResult runStrategy1(string symbol, ENUM_TIMEFRAMES lowTF, ENUM_TIMEFRAMES highTF, int groupIndex)
{
  StrategyResult result;
  result.status = STRATEGY_STATUS_LOCKED;
  result.symbol = symbol;
  HigherTFCrossCheckResult maCross = findHigherTimeFrameMACross(symbol, highTF);
  // HigherTFCrossCheckResult virtualMACross = findHigherTimeFrameMACross(symbol, highTF, true);
  if (maCross.found /*&& !virtualMACross.found*/)
  {

    const bool canCheckSignals = !symbolHasProfitInCurrentCrossing(symbol, groupIndex, (int)maCross.crossTime);

    if (canCheckSignals)
    {
      result.status = STRATEGY_STATUS_CHECKING_SIGNALS;
    }
    else
    {
      result.status = STRATEGY_STATUS_LOCKED;
      return result;
    }

    result.maCross = maCross;

    bool isTimeAllowed = TimeFilter(SessionStart1, SessionEnd1) || TimeFilter(SessionStart2, SessionEnd2) || TimeFilter(SessionStart3, SessionEnd3);

    if (isTimeAllowed && isTradingEnabledInCurrentSession())
    {

      int firstAreaTouchShift = findAreaTouch(symbol, highTF, maCross.orderEnvironment, maCross.crossCandleShift, lowTF);

      if (firstAreaTouchShift >= 0 && maCross.orderEnvironment != ENV_NONE)
      {
        SignalResult signals[];
        listSignals(signals, symbol, lowTF, maCross.orderEnvironment, firstAreaTouchShift);

        int signalsCount = ArraySize(signals);
        if (signalsCount > 0)
        {

          OrderInfoResult entry = getSymbolEntry(symbol, lowTF, firstAreaTouchShift, maCross, signals);

          // Preparing the strategy result
          if (maCross.orderEnvironment == ENV_SELL)
          {
            result.status = entry.pending == false ? STRATEGY_STATUS_IMMEDIATE_SELL : STRATEGY_STATUS_PENDING_SELL;
          }
          else if (maCross.orderEnvironment == ENV_BUY)
          {
            result.status = entry.pending == false ? STRATEGY_STATUS_IMMEDIATE_BUY : STRATEGY_STATUS_PENDING_BUY;
          }

          result.orderInfo = entry;

          if (!entry.valid)
            result.status = STRATEGY_STATUS_CHECKING_SIGNALS;

          return result;
        }
      }
    }
  }

  return result;
}

/// @brief Checks for any available tradable signal in the symbol
/// @param symbol
/// @param currentTF
/// @param firstAreaTouchShift
/// @param maCross
/// @param signals
/// @return The order that we can place for the given symbol. If no order found it will return an invalid order.
OrderInfoResult getSymbolEntry(string symbol, ENUM_TIMEFRAMES currentTF, int firstAreaTouchShift, HigherTFCrossCheckResult &maCross, SignalResult &signals[])
{
  OrderInfoResult result;

  double price = maCross.orderEnvironment == ENV_SELL ? MarketInfo(symbol, MODE_BID) : MarketInfo(symbol, MODE_ASK);

  int signalsCount = ArraySize(signals);
  int lastSignalIndex = signalsCount - 1;
  if (signalsCount > 0)
  {
    SignalResult lastSignal = signals[lastSignalIndex];
    // Validate Signal
    OrderInfoResult orderCalculated = signalToOrderInfo(symbol, currentTF, maCross.orderEnvironment, lastSignal);
    // Try to find an invalid order before last signal
    bool foundInvalid = false;
    for (int sIdx = 0; sIdx < lastSignalIndex; sIdx++)
    {
      OrderInfoResult validatedOrder = validateOrderDistance(symbol, currentTF, maCross.orderEnvironment, firstAreaTouchShift, signals, sIdx);
      if (validatedOrder.valid == false)
      {
        orderCalculated.valid = false;
        foundInvalid = true;
        break;
      }
    }

    if (foundInvalid == false)
    {
      orderCalculated = validateOrderDistance(symbol, currentTF, maCross.orderEnvironment, firstAreaTouchShift, signals, lastSignalIndex);
    }

    // If last signal is hapenning now
    if (lastSignal.maChangeShift >= 0 && lastSignal.maChangeShift <= 1 && orderCalculated.valid)
    {
      // open signal
      if (!orderCalculated.pending)
      {
        if (maCross.orderEnvironment == ENV_SELL)
        {
          orderCalculated = calculeOrderPlace(symbol, currentTF, maCross.orderEnvironment, 0, lastSignal.highestShift, MarketInfo(symbol, MODE_BID), false);
          // orderCalculated.orderPrice = ;
        }
        else if (maCross.orderEnvironment == ENV_BUY)
        {
          // orderCalculated.orderPrice = MarketInfo(symbol, MODE_ASK);
          orderCalculated = calculeOrderPlace(symbol, currentTF, maCross.orderEnvironment, 0, lastSignal.lowestShift, MarketInfo(symbol, MODE_ASK), false);
        }
        orderCalculated.pending = false;
      }

      result = orderCalculated;
    }
    else if (lastSignal.maChangeShift > 2 && foundInvalid == false)
    {
      // if last signal is not hapenning now, find the latest valid signal and set a pending order for it
      int latestValidSignalIndex = findMostValidSignalIndex(symbol, currentTF, maCross.orderEnvironment, signals);
      if (latestValidSignalIndex > -1)
      {
        SignalResult latestValidSignal = signals[latestValidSignalIndex];
        int highestShiftBetween = iHighest(symbol, currentTF, MODE_HIGH, latestValidSignal.maChangeShift, 0);
        double high = iHigh(symbol, currentTF, highestShiftBetween);
        int lowestShiftBetween = iLowest(symbol, currentTF, MODE_LOW, latestValidSignal.maChangeShift, 0);
        double low = iLow(symbol, currentTF, lowestShiftBetween);
        OrderInfoResult latestValidOrder = validateOrderDistanceToCurrentCandle(symbol, currentTF, maCross.orderEnvironment, latestValidSignal);
        latestValidOrder.valid = latestValidOrder.valid && (maCross.orderEnvironment == ENV_SELL ? (price > latestValidOrder.tpPrice && high < latestValidOrder.slPrice) : (price < latestValidOrder.tpPrice && low > latestValidOrder.slPrice));
        latestValidOrder.pending = true;
        result = latestValidOrder;
        // drawVLine(findSymbolChart(symbol), latestValidSignal.maChangeShift, "sdfdsf", C'255,210,7');
      }
    }
  }

  return result;
}

HigherTFCrossCheckResult findHigherTimeFrameMACross(string symbol, ENUM_TIMEFRAMES higherTF, bool findVirtualCross = false, double customCrossingOpeningRatio = -1)
{
  HigherTFCrossCheckResult result;

  result.found = false;
  result.orderEnvironment = ENV_NONE;

  // datetime prevHigherTFTime = iTime(symbol, higherTF, 1); // Zamane Candle 4 saate ghabli
  // Current timeframe candle shift in the end of the previous 4 hours
  int beginning = 0; // iBarShift(symbol, lower_timeframe, prevHigherTFTime) - (higherTF / lower_timeframe);
  int end = iBars(symbol, lower_timeframe) - 1;

  if (findVirtualCross)
  {
    datetime currentHigherTFTime = iTime(symbol, higherTF, 0);
    beginning = 0;
    end = iBarShift(symbol, lower_timeframe, currentHigherTFTime);
    // drawVLine(findSymbolChart(symbol), end, "virtual_cross2", C'255,213,0');
  }

  for (int i = beginning; i < end; i++)
  {

    int actualShift = getShift(symbol, higherTF, i);

    if (actualShift < 0)
      debug("Shift Error");

    double MA5_current = findVirtualCross ? getLibertyMA(symbol, 5, i) : getMA(symbol, higherTF, 5, actualShift);
    double MA5_prev = findVirtualCross ? getLibertyMA(symbol, 5, i + 1) : getMA(symbol, higherTF, 5, actualShift + 1);

    double MA10_current = findVirtualCross ? getLibertyMA(symbol, 10, i) : getMA(symbol, higherTF, 10, actualShift);
    double MA10_prev = findVirtualCross ? getLibertyMA(symbol, 10, i + 1) : getMA(symbol, higherTF, 10, actualShift + 1);

    // Only Current TimeFrame data
    datetime higherTFCandleTime = iTime(symbol, higherTF, actualShift);
    int higherTFinLowerCandleShift = iBarShift(symbol, lower_timeframe, higherTFCandleTime, false);
    int higherTFBeginningInCurrentPeriod = findVirtualCross ? i : higherTFinLowerCandleShift; // i + (int)(higherTF / lower_timeframe) - 1;
    datetime currentShiftTime = iTime(symbol, lower_timeframe, higherTFBeginningInCurrentPeriod);
    double price = iOpen(symbol, lower_timeframe, higherTFBeginningInCurrentPeriod);

    result.crossOpenPrice = price;
    result.crossTime = currentShiftTime;
    result.crossCandleShift = higherTFBeginningInCurrentPeriod;
    result.crossCandleShiftTimeframe = (ENUM_TIMEFRAMES)lower_timeframe;
    result.crossCandleHigherTfShift = actualShift;

    if (MA5_prev > MA10_prev && MA5_current < MA10_current)
    {
      // SELL
      // Alert("Sell");

      result.orderEnvironment = ENV_SELL;
      result.found = true;
    }
    else if (MA5_prev < MA10_prev && MA5_current > MA10_current)
    {
      // BUY
      // Alert(MA5_current);
      result.orderEnvironment = ENV_BUY;
      result.found = true;
    }

    /**
     * Checking for visual crossing openning size based on the a ratio of the average candle size
     * Steps:
     * 1- Size dahaneye crossing agar ghabele ghabul bud moshakhasate crossing tayin mishavad
     * 2- Agar size dahaneye crossing ghabele ghabul nabud:
     *    1- Agar crossing dar 4 saate akhir etefagh oftade, result.found=false mishavad va sabr mikonim ta vaziat taghir konad
     *    2- Agar crossing dar 4 saate jari nabud, size dahaneye 4 saate badaz an ra check mikonim, agar ghabele ghabul bud an noghte ra be onvane crossing dar nazar migirim
     * */

    if (result.found)
    {
      if (!findVirtualCross)
      {
        double crossingOpeningRatio = customCrossingOpeningRatio > -1 ? customCrossingOpeningRatio : MA_Crossing_Opening_Ratio;
        double openningSizeRatio = averageCandleSize(symbol, lower_timeframe, i, AverageCandleSizePeriod) * crossingOpeningRatio;
        double openningSize = MathAbs(MA5_current - MA10_current);
        if (openningSize < openningSizeRatio)
        {
          if (actualShift == 0 || actualShift == 1)
          {
            result.orderEnvironment = ENV_NONE;
            result.found = false;
            // debug("Very Small Crossing Openning: " + symbol);
          }
          else if (actualShift > 1)
          {

            // Scan until current time to find the proper cross openning anfle size
            for (int shiftIdx = actualShift - 1; shiftIdx > 1; shiftIdx--)
            {
              higherTFCandleTime = iTime(symbol, higherTF, shiftIdx);
              int crossShiftCurrentPeriod = iBarShift(symbol, lower_timeframe, higherTFCandleTime, false);
              MA5_current = getMA(symbol, higherTF, 5, shiftIdx);
              MA10_current = getMA(symbol, higherTF, 10, shiftIdx);
              openningSize = MathAbs(MA5_current - MA10_current);
              if (openningSize >= openningSizeRatio)
              {
                price = iOpen(symbol, lower_timeframe, crossShiftCurrentPeriod);
                currentShiftTime = iTime(symbol, lower_timeframe, crossShiftCurrentPeriod);
                result.crossOpenPrice = price;
                result.crossCandleHigherTfShift = shiftIdx;
                result.crossCandleShift = crossShiftCurrentPeriod;
                result.crossTime = currentShiftTime;
                result.found = true;
                break;
              }
              // crossShiftCurrentPeriod = (crossShiftCurrentPeriod - (int)(higherTF / lower_timeframe)) + 1;
              // crossShiftCurrentPeriod = crossShiftCurrentPeriod >= 0 ? crossShiftCurrentPeriod : 0;
            }
          }
        }
      }

      break;
    }
  }

  return result;
}

bool isAreaTouched(string symbol, ENUM_TIMEFRAMES higherTF, OrderEnvironment orderEnv, int shift, ENUM_TIMEFRAMES lower_tf)
{
  // int actualHigherShift = getShift(symbol, higherTF, shift);

  // if (actualHigherShift >= 0)
  // {
  double h4_ma5 = getLibertyMA(symbol, 5, shift); // getMA(symbol, higherTF, 5, actualHigherShift);
  double h4_ma5_thickness = averageCandleSize(symbol, lower_tf, shift, AverageCandleSizePeriod) * MA_Touch_Thickness_Ratio;
  if (orderEnv == ENV_SELL)
  {
    h4_ma5 -= h4_ma5_thickness;
    double m5_high = iHigh(symbol, lower_tf, shift);
    if (m5_high >= h4_ma5)
    {
      return true;
    }
  }

  if (orderEnv == ENV_BUY)
  {
    h4_ma5 += h4_ma5_thickness;
    double m5_low = iLow(symbol, lower_tf, shift);
    if (m5_low <= h4_ma5)
    {
      return true;
    }
  }
  // }
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
        result.lastChangeShift = j;
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
        result.lastChangeShift = j;
        break;
      }
    }
  }

  // if (lastChangeShift > -1)
  // {
  //   datetime time = iTime(_Symbol, lower_timeframe, lastChangeShift);
  //   double price = iOpen(_Symbol, lower_timeframe, lastChangeShift);
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

    int candleCountBetween = 10; // MathAbs(firstAreaTouchShift - item.maChangeShift) + 1;

    // Mire akhirtarin taghire range hamjahat ro peyda mikone va az onja tedade candlayi ke
    // bayad baraye peyda kardane balatarin/payintarin noghte begarde ro mohasebe mikone
    for (int step = 3; step < 200; step += 3)
    {
      LowMaChangeResult maDir = getLowerMaDirection(symbol, lowTF, item.maChangeShift + step);
      if ((orderEnv == ENV_SELL && maDir.dir == MA_DOWN) || (orderEnv == ENV_BUY && maDir.dir == MA_UP))
      {
        if (step > candleCountBetween)
        {
          candleCountBetween = step;
        }
        break;
      }
    }

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

OrderInfoResult calculeOrderPlace(string symbol, ENUM_TIMEFRAMES tf, OrderEnvironment orderEnv, int signalShift, int highestLowestShift, double price, bool withPending = true)
{
  OrderInfoResult orderInfo;

  double highestLowestPrice = (orderEnv == ENV_SELL)
                                  ? iHigh(symbol, tf, highestLowestShift)
                                  : iLow(symbol, tf, highestLowestShift);

  int signalTimeHour = TimeHour(iTime(symbol, tf, signalShift));
  int nowTimeHour = TimeHour(TimeCurrent());
  const int acsShift = TimeFilter(CustomACSTimeStart, CustomACSTimeEnd, nowTimeHour) ? 0 : signalShift;
  double averageCandle = averageCandleSize(symbol, tf, acsShift, AverageCandleSizePeriod);
  double pendingThreshold = TimeFilter(CustomACSTimeStart, CustomACSTimeEnd, signalTimeHour) ? CustomPendingThresholdAverageCandleSizeRatio : PendingThresholdAverageCandleSizeRatio;
  double scaledCandleSize = averageCandle * pendingThreshold;

  double gapSizeInPoint = averageCandle * StopLossGapInAverageCandleSize;

  orderInfo.originalPrice = price;

  orderInfo.averageCandleSize = averageCandle;

  double marketAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
  double marketBid = SymbolInfoDouble(symbol, SYMBOL_BID);

  if (orderEnv == ENV_SELL)
  {
    orderInfo.absoluteSlPrice = highestLowestPrice;
    orderInfo.slPrice = highestLowestPrice + gapSizeInPoint;

    double stopLossToScaledCandleSize = orderInfo.slPrice - scaledCandleSize;
    orderInfo.pending = (price < stopLossToScaledCandleSize) && withPending;

    orderInfo.orderPrice = orderInfo.pending ? stopLossToScaledCandleSize : price;
    orderInfo.pendingOrderPrice = stopLossToScaledCandleSize;
    double priceSlDistance = MathAbs(orderInfo.orderPrice - orderInfo.slPrice);
    orderInfo.tpPrice = orderInfo.orderPrice - (priceSlDistance * TakeProfitRatio);

    if (orderInfo.orderPrice <= marketAsk && orderInfo.orderPrice >= marketBid)
    {
      orderInfo.orderPrice = marketBid;
      orderInfo.pending = false;
    }
  }
  else if (orderEnv == ENV_BUY)
  {
    orderInfo.absoluteSlPrice = highestLowestPrice;
    orderInfo.slPrice = highestLowestPrice - gapSizeInPoint;

    double stopLossToScaledCandleSize = orderInfo.slPrice + scaledCandleSize;
    orderInfo.pending = (price > stopLossToScaledCandleSize) && withPending;

    orderInfo.orderPrice = orderInfo.pending ? stopLossToScaledCandleSize : price;
    orderInfo.pendingOrderPrice = stopLossToScaledCandleSize;
    double priceSlDistance = MathAbs(orderInfo.orderPrice - orderInfo.slPrice);
    orderInfo.tpPrice = orderInfo.orderPrice + (priceSlDistance * TakeProfitRatio);

    if (orderInfo.orderPrice <= marketAsk && orderInfo.orderPrice >= marketBid)
    {
      orderInfo.orderPrice = marketAsk;
      orderInfo.pending = false;
    }
  }

  return orderInfo;
}

OrderInfoResult signalToOrderInfo(string symbol, ENUM_TIMEFRAMES tf, OrderEnvironment orderEnv, SignalResult &signal, bool useVirtualPrice = true)
{
  OrderInfoResult orderCalculated;
  if (orderEnv == ENV_SELL && signal.highestShift > -1)
  {
    double low = MathMin(iOpen(symbol, tf, signal.maChangeShift), iClose(symbol, tf, signal.maChangeShift)); // iLow(symbol, tf, signal.maChangeShift)
    double price = useVirtualPrice ? low : MarketInfo(symbol, MODE_BID);
    orderCalculated = calculeOrderPlace(symbol, tf, orderEnv, signal.maChangeShift, signal.highestShift, price);
  }
  else if (orderEnv == ENV_BUY && signal.lowestShift > -1)
  {
    double high = MathMax(iOpen(symbol, tf, signal.maChangeShift), iClose(symbol, tf, signal.maChangeShift)); // iHigh(symbol, tf, signal.maChangeShift)
    double price = useVirtualPrice ? high : MarketInfo(symbol, MODE_ASK);
    orderCalculated = calculeOrderPlace(symbol, tf, orderEnv, signal.maChangeShift, signal.lowestShift, price);
  }
  return orderCalculated;
}

OrderInfoResult validateOrderDistance(string symbol, ENUM_TIMEFRAMES tf, OrderEnvironment orderEnv, int firstAreaTouchShift, SignalResult &signals[], int signalIndexToValidate)
{

  int signalsCount = ArraySize(signals);

  SignalResult signal = signals[signalIndexToValidate];

  OrderInfoResult indexOrderInfo = signalToOrderInfo(symbol, tf, orderEnv, signal);

  if (signalIndexToValidate >= 0)
  {
    // Find highest/lowest entry price in the past
    int mostValidIndex = findMostValidSignalIndex(symbol, tf, orderEnv, signals, signalIndexToValidate);
    SignalResult mostValidEntrySignal = signals[mostValidIndex];
    OrderInfoResult mostValidEntry = signalToOrderInfo(symbol, tf, orderEnv, mostValidEntrySignal);

    if (mostValidEntry.orderPrice > -1 && signalIndexToValidate != mostValidIndex)
    {
      bool isValidPriceDistance = true;
      int candlesCountFromMostValidEntry = MathAbs(mostValidEntrySignal.maChangeShift - signal.maChangeShift);
      const double mostValidBreakevenSize = MathAbs(mostValidEntry.orderPrice - mostValidEntry.slPrice) * BreakEvenRatio;

      if (orderEnv == ENV_SELL)
      {
        int lowestCandleFromMostValid = iLowest(symbol, tf, MODE_LOW, candlesCountFromMostValidEntry, signal.maChangeShift);
        double lowestPrice = iLow(symbol, tf, lowestCandleFromMostValid);
        double mostValidEntryBreakevenPrice = mostValidEntry.orderPrice - mostValidBreakevenSize;
        isValidPriceDistance = (indexOrderInfo.originalPrice > mostValidEntryBreakevenPrice /*mostValidEntry.tpPrice*/) && (lowestPrice > mostValidEntryBreakevenPrice /*mostValidEntry.tpPrice*/);
      }
      else if (orderEnv == ENV_BUY)
      {
        int highestCandleFromMostValid = iHighest(symbol, tf, MODE_HIGH, candlesCountFromMostValidEntry, signal.maChangeShift);
        double highestPrice = iHigh(symbol, tf, highestCandleFromMostValid);
        double mostValidEntryBreakevenPrice = mostValidEntry.orderPrice + mostValidBreakevenSize;
        isValidPriceDistance = (indexOrderInfo.originalPrice < mostValidEntryBreakevenPrice /*mostValidEntry.tpPrice*/) && (highestPrice < mostValidEntryBreakevenPrice /*mostValidEntry.tpPrice*/);
      }

      // if (signalIndexToValidate == ActiveSignalForTest)
      // {
      //   SignalResult item = signals[mostValidIndex];
      //   drawVLine(item.maChangeShift, IntegerToString(item.maChangeShift), clrRed);

      //   SignalResult sg = signals[signalIndexToValidate];
      //   drawHLine(mostValidEntry.orderPrice, "orderPrice" + IntegerToString(sg.maChangeShift), C'226,195,43');
      //   debug("Order Price = ", indexOrderInfo.orderPrice, " mostTP = ", mostValidEntry.tpPrice, " isValidPriceDistance = ", isValidPriceDistance);
      // }

      // If it is in a valid distance to first entry we will consider that entry as a pending order and replace with current one
      if (isValidPriceDistance)
      {
        // If the highest/lowest found previous signal has higher/lower slPrice will replace it with current signal order info
        SignalResult signalToProcess = signal;
        bool shohldReplaceOrderInfo = (orderEnv == ENV_SELL && mostValidEntry.slPrice > indexOrderInfo.slPrice) || (orderEnv == ENV_BUY && mostValidEntry.slPrice < indexOrderInfo.slPrice);
        if (shohldReplaceOrderInfo)
        {
          indexOrderInfo = mostValidEntry;
          signalToProcess = mostValidEntrySignal;
        }

        // Correcting Stoploss place
        if (signalToProcess.maChangeShift != firstAreaTouchShift)
        {

          int startShift = signal.maChangeShift - 2;
          startShift = startShift >= 0 ? startShift : 0;

          if (signalIndexToValidate == signalsCount - 1)
            startShift = 0;

          if (orderEnv == ENV_SELL)
          {
            int highestFromFirstTouch = iHighest(symbol, tf, MODE_HIGH, MathAbs(startShift - firstAreaTouchShift), startShift);
            signalToProcess.highestShift = highestFromFirstTouch;
          }
          else if (orderEnv == ENV_BUY)
          {
            int lowestFromFirstTouch = iLowest(symbol, tf, MODE_LOW, MathAbs(startShift - firstAreaTouchShift), startShift);
            signalToProcess.lowestShift = lowestFromFirstTouch;
          }

          indexOrderInfo = signalToOrderInfo(symbol, tf, orderEnv, signalToProcess);
        }

        indexOrderInfo.valid = true;
      }

      indexOrderInfo.pending = true;
    }
    else
    {
      // If nothing found the order itself is valid whatever calculated
      indexOrderInfo.valid = true;
    }

    if (signalIndexToValidate == mostValidIndex && signal.maChangeShift != firstAreaTouchShift)
    {
      int startShift = signal.maChangeShift - 2;
      startShift = startShift >= 0 ? startShift : 0;

      if (signalIndexToValidate == signalsCount - 1)
        startShift = 0;

      // Correcting Stoploss place
      if (orderEnv == ENV_SELL)
      {
        int highestFromFirstTouch = iHighest(symbol, tf, MODE_HIGH, MathAbs(startShift - firstAreaTouchShift), startShift);
        signal.highestShift = highestFromFirstTouch;
      }
      else if (orderEnv == ENV_BUY)
      {
        int lowestFromFirstTouch = iLowest(symbol, tf, MODE_LOW, MathAbs(startShift - firstAreaTouchShift), startShift);
        signal.lowestShift = lowestFromFirstTouch;
      }

      indexOrderInfo = signalToOrderInfo(symbol, tf, orderEnv, signal);
      // indexOrderInfo.pending = false;
      indexOrderInfo.valid = true;

      signals[signalIndexToValidate] = signal;

      // Validate based on the previous most valid place before current valid one to see if hits the TP
      // This extra check is for the situations that the current signal is itself the most valid entry
      // So we check to see if the previous most valid entry has hit the TP earlier or not
      // If it is touched the TP so we will make it invalid
      if (signalIndexToValidate > 0)
      {
        mostValidIndex = findMostValidSignalIndex(symbol, tf, orderEnv, signals, signalIndexToValidate - 1);
        mostValidEntrySignal = signals[mostValidIndex];
        mostValidEntry = signalToOrderInfo(symbol, tf, orderEnv, mostValidEntrySignal);

        bool isValidPriceDistance = true;
        int candlesCountFromMostValidEntry = MathAbs(mostValidEntrySignal.maChangeShift - signal.maChangeShift);
        const double mostValidBreakevenSize = MathAbs(mostValidEntry.orderPrice - mostValidEntry.slPrice) * BreakEvenRatio;

        if (orderEnv == ENV_SELL)
        {
          int lowestCandleFromMostValid = iLowest(symbol, tf, MODE_LOW, candlesCountFromMostValidEntry, signal.maChangeShift);
          double lowestPrice = iLow(symbol, tf, lowestCandleFromMostValid);
          double mostValidEntryBreakevenPrice = mostValidEntry.orderPrice - mostValidBreakevenSize;
          isValidPriceDistance = (indexOrderInfo.originalPrice > mostValidEntryBreakevenPrice /*mostValidEntry.tpPrice*/) && (lowestPrice > mostValidEntryBreakevenPrice /*mostValidEntry.tpPrice*/);
        }
        else if (orderEnv == ENV_BUY)
        {
          int highestCandleFromMostValid = iHighest(symbol, tf, MODE_HIGH, candlesCountFromMostValidEntry, signal.maChangeShift);
          double highestPrice = iHigh(symbol, tf, highestCandleFromMostValid);
          double mostValidEntryBreakevenPrice = mostValidEntry.orderPrice + mostValidBreakevenSize;
          isValidPriceDistance = (indexOrderInfo.originalPrice < mostValidEntryBreakevenPrice /*mostValidEntry.tpPrice*/) && (highestPrice < mostValidEntryBreakevenPrice /*mostValidEntry.tpPrice*/);
        }

        indexOrderInfo.valid = isValidPriceDistance;
      }
    }
  }
  else
  {
    // if index = 0, the first signal is always valid
    indexOrderInfo.valid = true;
  }

  return indexOrderInfo;
}

OrderInfoResult validateOrderDistanceToCurrentCandle(string symbol, ENUM_TIMEFRAMES tf, OrderEnvironment orderEnv, SignalResult &signal)
{

  // Find highest/lowest entry price in the past
  OrderInfoResult entry = signalToOrderInfo(symbol, tf, orderEnv, signal);

  entry.valid = false;

  if (entry.orderPrice > -1)
  {
    bool isValidPriceDistance = false;
    int candlesCountFromMostValidEntry = MathAbs(signal.maChangeShift + 1);

    if (orderEnv == ENV_SELL)
    {
      int lowestCandleFromMostValid = iLowest(symbol, tf, MODE_LOW, candlesCountFromMostValidEntry, 0);
      double lowestPrice = iLow(symbol, tf, lowestCandleFromMostValid);
      isValidPriceDistance = (lowestPrice > entry.tpPrice);
    }
    else if (orderEnv == ENV_BUY)
    {
      int highestCandleFromMostValid = iHighest(symbol, tf, MODE_HIGH, candlesCountFromMostValidEntry, 0);
      double highestPrice = iHigh(symbol, tf, highestCandleFromMostValid);
      isValidPriceDistance = (highestPrice < entry.tpPrice);
    }

    if (isValidPriceDistance)
    {
      entry.pending = true;
      entry.valid = true;
    }
  }

  return entry;
}

int findMostValidSignalIndex(string symbol, ENUM_TIMEFRAMES tf, OrderEnvironment orderEnv, SignalResult &signals[], int limitIndex = -1)
{
  // Find highest/lowest entry price in the past
  if (limitIndex <= -1)
  {
    limitIndex = ArraySize(signals) - 1;
  }
  SignalResult mostValidEntrySignal = signals[0];
  OrderInfoResult mostValidEntry = signalToOrderInfo(symbol, tf, orderEnv, mostValidEntrySignal);
  int place = 0;
  for (int i = 0; i <= limitIndex; i++)
  {
    SignalResult item = signals[i];
    OrderInfoResult signalOrderInfo = signalToOrderInfo(symbol, tf, orderEnv, item);

    if (orderEnv == ENV_SELL && signalOrderInfo.originalPrice > mostValidEntry.originalPrice)
    {
      mostValidEntrySignal = item;
      mostValidEntry = signalOrderInfo;
      place = i;
    }
    else if (orderEnv == ENV_BUY && signalOrderInfo.originalPrice < mostValidEntry.originalPrice)
    {
      mostValidEntrySignal = item;
      mostValidEntry = signalOrderInfo;
      place = i;
    }
  }

  return place;
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
  datetime candleTimeCurrent = iTime(symbol, lower_timeframe, shift);
  int actualShift = iBarShift(symbol, timeframe, candleTimeCurrent);

  return actualShift;
}

void initializeGroups()
{
  debug("============Initializing Groups==============");
  string groups_str_copy[];
  GROUPS_LENGTH = ArraySize(GROUPS_STR);

  ArrayResize(groups_str_copy, GROUPS_LENGTH);
  ArrayCopy(groups_str_copy, GROUPS_STR, 0, 0, GROUPS_LENGTH);

  if (StringLen(CustomGroup1) > 0)
  {
    GROUPS_LENGTH++;
    ArrayResize(groups_str_copy, GROUPS_LENGTH);
    groups_str_copy[GROUPS_LENGTH - 1] = CustomGroup1;
  }

  if (StringLen(CustomGroup2) > 0)
  {
    GROUPS_LENGTH++;
    ArrayResize(groups_str_copy, GROUPS_LENGTH);
    groups_str_copy[GROUPS_LENGTH - 1] = CustomGroup2;
  }

  ArrayResize(GROUPS, GROUPS_LENGTH);
  for (int i = 0; i < GROUPS_LENGTH; i++)
  {
    string symbolsStr = groups_str_copy[i];
    GroupStruct group;
    group.groupIndex = i;
    StringSplit(symbolsStr, SYMBOL_SEPARATOR, group.symbols);
    group.symbols_count = ArraySize(group.symbols);

    ArrayResize(group.bars, group.symbols_count);
    ArrayFill(group.bars, 0, group.symbols_count, 0);

    ArrayResize(group.barsHigher, group.symbols_count);
    ArrayFill(group.barsHigher, 0, group.symbols_count, 0);

    ArrayResize(group.MA10, group.symbols_count);
    ArrayResize(group.MA5, group.symbols_count);

    for (int symIndex = 0; symIndex < group.symbols_count; symIndex++)
    {
      string sym = group.symbols[symIndex];
      group.barsHigher[symIndex] = iBars(sym, higher_timeframe);
    }

    GROUPS[i] = group;
  }

  syncActiveSymbolOrders();
}

void initializeMAs()
{
  for (int groupIdx = 0; groupIdx < GROUPS_LENGTH; groupIdx++)
  {

    GroupStruct group = GROUPS[groupIdx];

    for (int symbolIdx = 0; symbolIdx < group.symbols_count; symbolIdx++)
    {
      string symbol = group.symbols[symbolIdx];

      // iMA(symbol, higherTF, 5, 0, MODE_SMA, PRICE_CLOSE, 0);
      MA_Array maArr = group.MA5[symbolIdx];
      initLibertyMA(maArr.MA, symbol, higher_timeframe, lower_timeframe, 5, MODE_SMA, PRICE_CLOSE);
      group.MA5[symbolIdx] = maArr;

      maArr = group.MA10[symbolIdx];
      initLibertyMA(maArr.MA, symbol, higher_timeframe, lower_timeframe, 10, MODE_SMA, PRICE_CLOSE);
      group.MA10[symbolIdx] = maArr;
    }

    GROUPS[groupIdx] = group;
  }
}

double getLibertyMA(string symbol, int period, int shift)
{
  if (shift >= 0)
  {
    for (int groupIdx = 0; groupIdx < GROUPS_LENGTH; groupIdx++)
    {

      GroupStruct group = GROUPS[groupIdx];

      for (int symbolIdx = 0; symbolIdx < group.symbols_count; symbolIdx++)
      {
        string sym = group.symbols[symbolIdx];
        if (symbol == sym && iBars(sym, lower_timeframe) > 0)
        {
          switch (period)
          {
          case 5:
            return group.MA5[symbolIdx].MA[shift];
            break;
          case 10:
            return group.MA10[symbolIdx].MA[shift];
            break;

          default:
            return EMPTY_VALUE;
          }
        }
      }
    }
  }

  return EMPTY_VALUE;
}
