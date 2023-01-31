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
    double absoluteSlPrice;
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
        absoluteSlPrice = -1;
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
    int barsHigher[];
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
int minuteTimer = 0;

/////////////////////////////////// Symbol Groups Data Structures///////////////////////////////////////////

string GROUPS_STR[] = {
    "EURUSD GBPUSD AUDUSD NZDUSD",
    "USDCHF GBPCHF CADCHF EURCHF NZDCHF AUDCHF",
    "USDJPY EURJPY GBPJPY NZDJPY AUDJPY CHFJPY CADJPY",
    "USDCAD EURCAD GBPCAD AUDCAD NZDCAD",
    "EURNZD GBPNZD AUDNZD",
    "EURAUD GBPAUD",
    "EURGBP",
    "XAUUSD"};

const ushort SYMBOL_SEPARATOR = ' ';
GroupStruct GROUPS[];
int GROUPS_LENGTH = 0;

///////////////////////////////////// Helper Functions ///////////////////////////
int getMagicNumber(int groupIndex)
{
    string magicString = IntegerToString(MagicNumber);
    magicString += IntegerToString(getSessionNumber(TimeCurrent()));
    magicString += IntegerToString(groupIndex);

    return (int)StringToInteger(magicString);
}

void debug(string msg)
{
    Alert(msg);
    Print(msg);
    SendNotification(msg);
}
