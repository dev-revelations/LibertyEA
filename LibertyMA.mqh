
const int MA_MAX_LENGTH = 1000;

void initLibertyMA(double &maBuffer[], string symbol, ENUM_TIMEFRAMES TimeFrame, int PERIOD, ENUM_MA_METHOD Method, ENUM_APPLIED_PRICE AppliedPrice)
{

    int currentTFBars = iBars(symbol, Period())/2;

    int bars1 = iBars(symbol, TimeFrame),
        start1 = bars1 - 1,
        limit1 = iBarShift(symbol, TimeFrame, iTime(symbol, Period(), currentTFBars - 1));

    if (start1 > limit1 && limit1 != -1)
        start1 = limit1;

    ArrayResize(maBuffer, currentTFBars*2, currentTFBars*2);
    ArrayInitialize(maBuffer, EMPTY_VALUE);

    //----
    //	3... 2... 1... GO!
    for (int i = start1; i >= 0; i--)
    {
        int shift1 = i;

        if (TimeFrame < Period())
            shift1 = iBarShift(symbol, TimeFrame, iTime(symbol, Period(), i));

        int time1 = (int) iTime(symbol, TimeFrame, shift1),
            shift2 = iBarShift(symbol, 0, time1);

        double ma = iMA(symbol, TimeFrame, PERIOD, 0, Method, AppliedPrice, shift1);

        //----
        //	old (closed) candles
        if (shift1 >= 1)
        {
            maBuffer[shift2] = ma;
        }

        //----
        //	current candle
        if ((TimeFrame >= Period() && shift1 <= 1) || (TimeFrame < Period() && (shift1 == 0 || shift2 == 1)))
        {
            maBuffer[shift2] = ma;
        }

        //----
        //	linear interpolatior for the number of intermediate bars, between two higher timeframe candles.
        int n = 1;
        if (TimeFrame > Period())
        {
            int shift2prev = iBarShift(symbol, 0, iTime(symbol, TimeFrame, shift1 + 1));

            if (shift2prev != -1 && shift2prev != shift2)
                n = shift2prev - shift2;
        }

        //----
        //	apply interpolation
        double factor = 1.0 / n;
        if (shift1 >= 1)
        {
            if (maBuffer[shift2 + n] != EMPTY_VALUE && maBuffer[shift2] != EMPTY_VALUE)
            {
                for (int k = 1; k < n; k++)
                {
                    maBuffer[shift2 + k] = k * factor * maBuffer[shift2 + n] + (1.0 - k * factor) * maBuffer[shift2];
                }
            }
        }

        //----
        //	current candle
        if (shift1 == 0)
        {
            if (maBuffer[shift2 + n] != EMPTY_VALUE && maBuffer[shift2] != EMPTY_VALUE)
            {
                for (int k = 1; k < n; k++)
                {
                    maBuffer[shift2 + k] = k * factor * maBuffer[shift2 + n] + (1.0 - k * factor) * maBuffer[shift2];
                }
            }
        }

        // Render the continuation
        if (i == 0 && shift2 > 0)
        {

            shift2 = 0;

            ma = iMA(symbol, TimeFrame, PERIOD, 0, Method, AppliedPrice, 0);

            /*
               Candle 0 MA shibe nahayie khat ra tayiin mikonad
               banabarin bayad zaribi ra be an ezafe ya kam konim ta shibe ghabele pishbini ra rasm konad
               diffRation zaribe ekhtelafe MA jari ba MA n(om) ast, zarbdar tedade candlehaye beyne anha yani (n)

               (MA[n] - MA[current]) * n
            */
            double diffRatio = MathAbs(maBuffer[n] - ma) * n;

            if (maBuffer[n] < ma)
            {
                maBuffer[0] = ma + diffRatio;
            }
            else if (maBuffer[n] > ma)
            {
                maBuffer[0] = ma - diffRatio;
            }
            else
            {
                maBuffer[0] = ma;
            }

            factor = 1.0 / n;

            if (maBuffer[shift2 + n] != EMPTY_VALUE && maBuffer[shift2] != EMPTY_VALUE)
            {
                for (int k = 1; k < n; k++)
                {
                    maBuffer[shift2 + k] = k * factor * maBuffer[shift2 + n] + (1.0 - k * factor) * maBuffer[shift2];
                }
            }
        }
    }
}