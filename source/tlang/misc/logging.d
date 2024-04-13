/** 
 * Logging routines
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.misc.logging;

import gogga;
import gogga.extras;
import dlog.basic : Level, FileHandler;
import std.stdio : stdout;

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

    GoggaMode mode;

    version(DBG_VERBOSE_LOGGING)
    {
        mode = GoggaMode.RUSTACEAN;
    }
    else
    {
        mode = GoggaMode.SIMPLE;
    }

    logger.mode(mode);

    // TODO: In future make this configurable
    logger.setLevel(Level.DEBUG);
    logger.addHandler(new FileHandler(stdout));
}

// Bring in helper methods
mixin LoggingFuncs!(logger);