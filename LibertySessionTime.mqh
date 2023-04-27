/////////////////////////// Time & Session Helpers ///////////////////////////
int simulationTimer = 0;
int simulationOrderLineTimer = 0;

bool TimeFilter(int start_time, int end_time, int customTimeHour = -1)
{
    int CurrentHour = TimeHour(TimeCurrent());

    if (customTimeHour > -1)
    {
        CurrentHour = customTimeHour;
    }

    start_time = start_time + (GMTOffset);
    end_time = end_time + (GMTOffset);

    if (start_time > end_time)
    {
        if (CurrentHour < start_time && CurrentHour >= end_time)
        {
            return false;
        }
        else
        {
            return true;
        }
    }
    else
    {
        if (CurrentHour >= start_time && CurrentHour < end_time)
        {
            return true;
        }
        else
        {
            return false;
        }
    }
}

bool minutesPassed()
{
    int currentTime = (int)TimeLocal();
    int timePassed = (currentTime - minuteTimer) / 60;

    if (timePassed >= 1)
    {
        minuteTimer = (int)TimeLocal();

        return true;
    }

    return false;
}

bool secondsPassed(int seconds, int &secondsTimer)
{
    int currentTime = (int)TimeLocal();
    int timePassed = (currentTime - secondsTimer);

    if (timePassed >= seconds)
    {
        secondsTimer = (int)TimeLocal();

        return true;
    }

    return false;
}

bool isInSession(int sessionNumber, datetime time)
{
    if (TimeDay(TimeLocal()) == TimeDay(time))
    {
        int timeHour = TimeHour(time);

        int start_time = -1, end_time = -1;

        switch (sessionNumber)
        {
        case 1:
            start_time = SessionStart1 + (GMTOffset);
            end_time = SessionEnd1 + (GMTOffset);
            break;

        case 2:
            start_time = SessionStart2 + (GMTOffset);
            end_time = SessionEnd2 + (GMTOffset);
            break;

        case 3:
            start_time = SessionStart3 + (GMTOffset);
            end_time = SessionEnd3 + (GMTOffset);
            break;

        default:
            break;
        }

        if (timeHour >= start_time && timeHour <= end_time)
        {
            return true;
        }
    }

    return false;
}

int getSessionNumber(datetime time)
{
    if (TimeDay(TimeLocal()) == TimeDay(time))
    {
        int timeHour = TimeHour(time);
        int start_time = -1, end_time = -1;

        start_time = SessionStart1 + (GMTOffset);
        end_time = SessionEnd1 + (GMTOffset);

        if (timeHour >= start_time && timeHour <= end_time)
        {
            return 1;
        }

        start_time = SessionStart2 + (GMTOffset);
        end_time = SessionEnd2 + (GMTOffset);

        if (timeHour >= start_time && timeHour <= end_time)
        {
            return 2;
        }

        start_time = SessionStart3 + (GMTOffset);
        end_time = SessionEnd3 + (GMTOffset);

        if (timeHour >= start_time && timeHour <= end_time)
        {
            return 3;
        }
    }

    return -1;
}

bool isTradingEnabledIn(int session)
{
    switch (session)
    {
    case 1:
        return EnableTradingSession1;
        break;
    case 2:
        return EnableTradingSession2;
        break;
    case 3:
        return EnableTradingSession3;
        break;

    default:
        break;
    }

    return false;
}

bool isTradingEnabledInCurrentSession()
{
    return isTradingEnabledIn(getSessionNumber(TimeCurrent()));
}

bool sessionsEqual(int session1, int session2)
{
    return session1 == session2 && session1 > -1 && session2 > -1;
}
