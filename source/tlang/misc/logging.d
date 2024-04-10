module tlang.misc.logging;

public enum DebugType
{
    INFO,
    WARNING,
    ERROR,
    DEBUG
}


// TODO: setup static logger here
import gogga;
// TODO: May want gshared if it must be cross-thread module init
// as we would have many static fields init'd per thread then
// (would need a corresponding ghsraed field)

// import dlog.core;

private GoggaLogger logger;
static this()
{
    logger = new GoggaLogger();
    logger.mode(GoggaMode.RUSTACEAN);

    import dlog.basic : Level;
    logger.setLevel(Level.DEBUG);

    import dlog.basic : FileHandler;
    import std.stdio : stdout;
    logger.addHandler(new FileHandler(stdout));
}



// TODO: Change to actually use error, etc. directkly on GoggaLogger
public void gprintln(messageT)(messageT message, DebugType debugType = DebugType.INFO)
{
    if(debugType == DebugType.DEBUG)
    {
        logger.dbg(message);
    }
    else if(debugType == DebugType.INFO)
    {
        logger.info(message);
    }
    else if(debugType == DebugType.WARNING)
    {
        logger.warn(message);
    }
    else
    {
        logger.error(message);
    }
}