enum OrderEnvironment
{
    ENV_NONE,
    ENV_BUY,
    ENV_SELL,
    ENV_BOTH
};

enum MaDirection
{
    MA_NONE,
    MA_UP,
    MA_DOWN
};

enum StrategyStatus
{
    STRATEGY_STATUS_LOCKED,
    STRATEGY_STATUS_CHECKING_SIGNALS,
    STRATEGY_STATUS_IMMEDIATE_BUY,
    STRATEGY_STATUS_PENDING_BUY,
    STRATEGY_STATUS_IMMEDIATE_SELL,
    STRATEGY_STATUS_PENDING_SELL
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
    SignalResult()
    {
        maChangeShift = -1;
        highestShift = -1;
        lowestShift = -1;
        moveDepthShift = -1;
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
    double averageCandleSize;
    OrderInfoResult()
    {
        slPrice = -1;
        tpPrice = -1;
        orderPrice = -1;
        pendingOrderPrice = -1;
        originalPrice = -1;
        pending = false;
        valid = false;
        averageCandleSize = -1;
    }
};

struct StrategyResult
{
    StrategyStatus status;
    OrderInfoResult orderInfo;
    string symbol;
    HigherTFCrossCheckResult maCross;

    StrategyResult()
    {
        status = STRATEGY_STATUS_LOCKED;
        symbol = "";
    }
};

struct MA_Array
{
    double MA[];
};

struct GroupStruct
{
    string symbols[];
    string active_symbol_buy;
    string active_symbol_sell;
    int symbols_count;
    int bars[];
    StrategyResult active_strategy_buy;
    StrategyResult active_strategy_sell;
    MA_Array MA5[];
    MA_Array MA10[];
    int groupIndex;

    GroupStruct()
    {
        active_symbol_buy = "";
        active_symbol_sell = "";
        symbols_count = 0;
        groupIndex = -1;
    }
};

////////////////////////////////// Variables & Constants ///////////////////////////////

const int PRIORITY_LIST_MAX = 10;
StrategyResult BUY_PRIORITY_CHECK_LIST[10];
StrategyResult SELL_PRIORITY_CHECK_LIST[10];
int priority_index_buy = 0;
int priority_index_sell = 0;

///////////////////////////////////// Helper Functions ///////////////////////////
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

// StrategyResult getOrderPriorityOption(int OP, int index)
// {
//     return OP == OP_BUY ? BUY_PRIORITY_CHECK_LIST[index] : SELL_PRIORITY_CHECK_LIST[index];
// }

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
StrategyResult getPrioritizedOrderStrategyResult(int OP)
{
    int targetCount = orderPriorityListLength(OP);
    // Print("Prioriti List Type: ", OP == OP_BUY ? "Buy" : "Sell");
    return OP == OP_BUY ? prioritizeOrders(BUY_PRIORITY_CHECK_LIST, targetCount) : prioritizeOrders(SELL_PRIORITY_CHECK_LIST, targetCount);
}

StrategyResult prioritizeOrders(StrategyResult &list[], int count)
{
    StrategyResult result;

    // This means we only have one immediate option and should return
    if (count == 1)
    {
        return list[0];
    }

    /* Olaviatha:
        1- Immediate be pending tarjih dade mishavad
        2- Beyne 2 immediate olaviat ba moredi ast ke stoplosse kuchecktari dashte bashad
    */

    for (int i = 0; i < count; i++)
    {
        StrategyResult item = list[i];
        if (item.orderInfo.valid)
        {
            if (result.symbol == "")
            {
                result = item;
                continue;
            }
            else
            {
                Print(item.symbol, " From Prioritization List");

                // One is immediate
                if (result.orderInfo.pending && !item.orderInfo.pending)
                {
                    result = item;
                    continue;
                }

                // Both are immediate or both are pendings
                if ((!result.orderInfo.pending && !item.orderInfo.pending) /* || (result.orderInfo.pending && item.orderInfo.pending) */)
                {
                    // Check mikonim har kodam stoplosseshan chanta average candle size ast?
                    const double currentSlSize = MathAbs(result.orderInfo.orderPrice - result.orderInfo.slPrice) / result.orderInfo.averageCandleSize;
                    const double itemSlSize = MathAbs(item.orderInfo.orderPrice - item.orderInfo.slPrice) / item.orderInfo.averageCandleSize;
                    if (itemSlSize > currentSlSize)
                    {
                        result = item;
                        continue;
                    }
                }
            }
        }
    }

    return result;
}
