/** 
 * Logging routines
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.misc.logging;

import gogga;
import gogga.extras;

/** 
 * The logger instance
 * shared amongst a single
 * thread (TLS)
 */
private GoggaLogger logger;

/**
 * Initializes a logger instance
 * per thread (TLS)
 */
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

// Bring in helper methods
mixin LoggingFuncs!(logger);